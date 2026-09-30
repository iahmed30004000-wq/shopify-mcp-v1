import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/notifications/notification_service.dart';
import '../../home/home_providers.dart' show appForegroundProvider;
import '../domain/center_layout.dart';
import '../domain/center_models.dart';
import '../domain/center_policy.dart';
import '../domain/notification_history.dart';
import 'center_hooks.dart';
import 'center_providers.dart';
import 'center_store.dart';
import 'notification_gate.dart';

/// What the notification center shows.
@immutable
class NotificationCenterState {
  NotificationCenterState({
    required this.now,
    this.loaded = false,
    this.upcoming = const [],
    this.recent = const [],
    this.policy = CenterPolicy.empty,
    DateTime? seenAt,
    this.enforced = false,
    this.permitted = true,
  }) : seenAt = seenAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// When the lists were built.
  final DateTime now;

  /// The first look is done (before it, show nothing rather than "empty").
  final bool loaded;

  /// Pending within the next 7 days (muted / skipped / snoozed marked),
  /// soonest first.
  final List<CenterItem> upcoming;

  /// Arrived (tray + history), newest first.
  final List<CenterItem> recent;
  final CenterPolicy policy;

  /// When the Recent tab was last looked at.
  final DateTime seenAt;

  /// Mutes, skips and snoozes really hold notifications back (the
  /// [NotificationGate] is wired into the platform).
  final bool enforced;

  /// Notifications are allowed on the phone.
  final bool permitted;

  late final List<CenterSection> upcomingSections = CenterLayout.sections(upcoming, policy: policy, now: now);
  late final List<CenterSection> recentSections = CenterLayout.sections(recent, policy: policy, now: now);

  /// New notifications (the bell's badge).
  late final int unread = CenterLayout.unread(recent);

  /// Groups muted right now, with the end of their mute.
  late final Map<NotificationGroup, DateTime> mutes = {
    for (final g in NotificationGroup.values) g: ?policy.muteOf(g, now),
  };

  /// Upcoming notifications per group.
  int upcomingIn(NotificationGroup group) => upcoming.where((i) => i.group == group).length;
}

/// Undoes what an action did (the undo toast calls it).
typedef CenterUndo = Future<void> Function();

/// The notification center: keeps its lists in step with the platform and
/// records what arrives – in the background too, so the lead watches it
/// from the app's services (below the database gate):
///
/// * **Upcoming** – every pending notification of the next 7 days, from the
///   platform (through the gate: muted / skipped ones are listed, marked).
/// * **Recent** – what is in the tray and the bounded history
///   ([NotificationHistory], in the key/value store): notifications that
///   arrived (seen in the tray, or gone from the pending list after their
///   moment – unless a feature cancelled them first), were silenced by a
///   mute, opened, answered or snoozed. Taps and button answers are recorded
///   from the notification service's taps stream.
/// * Refreshed on open, on return to the foreground, after every action and
///   at the next notification's moment.
final notificationCenterProvider = NotifierProvider<NotificationCenterController, NotificationCenterState>(
  NotificationCenterController.new,
);

/// The bell's count: new notifications since the Recent tab was last seen.
final notificationUnreadCountProvider = Provider<int>((ref) => ref.watch(notificationCenterProvider).unread);

class NotificationCenterController extends Notifier<NotificationCenterState> {
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _timer;
  NotificationHistory _history = NotificationHistory.empty;
  List<WatchedNotice> _watch = const [];
  DateTime _seenAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _loaded = false;
  bool _watchDirty = false;
  Future<void> _tail = Future.value();
  Future<void>? _queued;

  /// Refreshes are at least this far apart when the timer re-arms itself.
  static const Duration minTimer = Duration(seconds: 5);
  static const Duration maxTimer = Duration(minutes: 30);

  NotificationService get _service => ref.read(notificationServiceProvider);
  NotificationGate get _gate => ref.read(notificationGateProvider);
  DateTime _now() => ref.read(notificationCenterClockProvider)();
  GroupOf get _groupOf => ref.read(notificationDescribersProvider).groupOf;

  NotificationCenterStore? get _store {
    try {
      return ref.read(notificationCenterStoreProvider);
    } catch (_) {
      // No database yet (locked, or a test without one): memory only.
      return null;
    }
  }

  @override
  NotificationCenterState build() {
    final service = ref.watch(notificationServiceProvider);
    final gate = ref.watch(notificationGateProvider);
    _subs
      ..add(service.taps.listen(_onTap))
      ..add(gate.silenced.listen(_onSilenced))
      ..add(gate.cancelled.listen(_onCancelled))
      ..add(gate.policyChanges.listen((_) => unawaited(_persistPolicy())));
    final foreground = ref.read(appForegroundProvider);
    void onForeground() {
      if (foreground.value) unawaited(refresh());
    }

    foreground.addListener(onForeground);
    ref.onDispose(() {
      for (final s in _subs) {
        unawaited(s.cancel());
      }
      _subs.clear();
      _timer?.cancel();
      foreground.removeListener(onForeground);
    });
    Future.microtask(refresh);
    return NotificationCenterState(now: _now(), enforced: gate.attached);
  }

  /// Re-reads the platform and the history. Calls made while one runs are
  /// merged into one more run after it.
  Future<void> refresh() => _queued ??= _tail = _tail
      .then((_) {
        _queued = null;
        return _refresh();
      })
      .catchError((Object e, StackTrace s) => debugPrint('NotificationCenter: refresh failed: $e\n$s'));

  /// Reads the stored state once the database is there (until then the
  /// center keeps what it records in memory and merges it in later).
  Future<void> _load(DateTime now) async {
    if (_loaded) return;
    final store = _store;
    if (store == null) return;
    _loaded = true;
    try {
      final stored = await store.history();
      _history = stored.recordAll(_history.entries, now: now).bounded(now);
      _watch = [...await store.watch(), ..._watch];
      _seenAt = await store.seenAt() ?? _seenAt;
      if (!ref.mounted) return;
      final gate = _gate;
      if (!gate.policyLoaded) {
        await gate.setPolicy(await store.policy());
      }
    } catch (e) {
      debugPrint('NotificationCenter: loading its state failed: $e');
    }
  }

  Future<void> _refresh() async {
    if (!ref.mounted) return;
    final now = _now();
    await _load(now);
    if (!ref.mounted) return;
    final service = _service;
    final gate = _gate;
    var pendingRaw = const <PendingNotice>[];
    var activeRaw = const <ActiveNotice>[];
    var permitted = true;
    try {
      pendingRaw = await service.pendingNotices();
    } catch (e) {
      debugPrint('NotificationCenter: pending notifications unavailable: $e');
    }
    try {
      activeRaw = await (gate.activeNotices() ?? service.activeNotices());
    } catch (e) {
      debugPrint('NotificationCenter: shown notifications unavailable: $e');
    }
    try {
      permitted = await service.notificationsEnabled();
    } catch (_) {}
    if (!ref.mounted) return;

    final policy = gate.policy.pruned(now);
    if (policy != gate.policy) {
      await gate.setPolicy(policy);
      if (!ref.mounted) return;
      await _persistPolicy();
    }
    final pending = [
      for (final p in pendingRaw) CenterNotice.fromPayload(p.id, p.payload, title: p.title, body: p.body),
    ];
    final active = [
      for (final a in activeRaw)
        CenterNotice.fromPayload(a.id, a.payload, title: a.title, body: a.body, channelId: a.channelId),
    ];

    // What arrived since the last look: upcoming then, gone now, its moment
    // past (a feature's cancellation was reported by the gate and dropped
    // from the watch) – and whatever is in the tray.
    final pendingKeys = {for (final p in pending) p.key};
    final arrived = <HistoryEntry>[
      for (final w in _watch)
        if (w.notice.at != null && !w.notice.at!.isAfter(now) && !pendingKeys.contains(w.notice.key))
          if (_arrivalOf(w) case final status?) HistoryEntry(notice: w.notice, status: status, recordedAt: now),
      for (final a in active)
        if (a.namespace != null && a.at != null)
          HistoryEntry(notice: a, status: HistoryStatus.delivered, recordedAt: now),
    ];
    final history = _history.recordAll(arrived, now: now).bounded(now);
    final groupOf = _groupOf;
    final upcoming = CenterLayout.upcoming(pending: pending, policy: gate.policy, groupOf: groupOf, now: now);
    final watch = [for (final i in upcoming) WatchedNotice(i.notice, i.state)];
    final recent = CenterLayout.recent(
      history: history,
      active: active,
      policy: gate.policy,
      groupOf: groupOf,
      seenAt: _seenAt,
      now: now,
    );
    if (history != _history) {
      _history = history;
      await _saveHistory();
      if (!ref.mounted) return;
    }
    if (_watchDirty || !listEquals(watch, _watch)) {
      _watch = watch;
      _watchDirty = false;
      await _guard((s) => s.saveWatch(watch));
    }
    if (!ref.mounted) return;
    state = NotificationCenterState(
      now: now,
      loaded: true,
      upcoming: upcoming,
      recent: recent,
      policy: gate.policy,
      seenAt: _seenAt,
      enforced: gate.attached,
      permitted: permitted,
    );
    _armTimer(upcoming, now);
  }

  static HistoryStatus? _arrivalOf(WatchedNotice w) => switch (w.state) {
    CenterItemState.muted => HistoryStatus.silenced,
    CenterItemState.skipped => null,
    _ => HistoryStatus.delivered,
  };

  void _armTimer(List<CenterItem> upcoming, DateTime now) {
    _timer?.cancel();
    final next = upcoming.where((i) => i.at.isAfter(now)).firstOrNull;
    var wait = next == null ? maxTimer : next.at.difference(now) + const Duration(seconds: 2);
    if (wait < minTimer) wait = minTimer;
    if (wait > maxTimer) wait = maxTimer;
    _timer = Timer(wait, () {
      if (ref.mounted) unawaited(refresh());
    });
  }

  /// Rebuilds the lists from what is known (no platform round trip).
  void _rebuild() {
    if (!ref.mounted) return;
    final s = state;
    final now = _now();
    state = NotificationCenterState(
      now: now,
      loaded: s.loaded,
      upcoming: s.upcoming,
      recent: CenterLayout.recent(
        history: _history,
        active: [
          for (final i in s.recent)
            if (i.live) i.notice,
        ],
        policy: _gate.policy,
        groupOf: _groupOf,
        seenAt: _seenAt,
        now: now,
      ),
      policy: _gate.policy,
      seenAt: _seenAt,
      enforced: s.enforced,
      permitted: s.permitted,
    );
  }

  // -------------------------------------------------------------------------
  // Recording

  void _onTap(NotificationTap tap) {
    if (tap.namespace == null || tap.id == null) return;
    final now = _now();
    final status = tap.actionId == null ? HistoryStatus.opened : HistoryStatus.acted;
    final notice = CenterNotice.fromTap(tap);
    _history = _history.record(
      HistoryEntry(notice: notice, status: status, actionId: tap.actionId, recordedAt: now),
      now: now,
    );
    unawaited(_saveHistory().then((_) => refresh()));
  }

  void _onSilenced(CenterNotice notice) {
    final now = _now();
    _history = _history.record(
      HistoryEntry(notice: notice, status: HistoryStatus.silenced, recordedAt: now),
      now: now,
    );
    unawaited(_saveHistory().then((_) => refresh()));
  }

  void _onCancelled(CenterNotice notice) {
    final before = _watch.length;
    _watch = [
      for (final w in _watch)
        if (w.notice.key != notice.key) w,
    ];
    if (_watch.length != before) _watchDirty = true;
  }

  /// Records that the user opened [item] from the center.
  Future<void> markOpened(CenterItem item) async {
    if (item.state.isUpcoming) return;
    final now = _now();
    _history = _history.record(
      HistoryEntry(notice: item.notice, status: HistoryStatus.opened, recordedAt: now),
      now: now,
    );
    await _saveHistory();
    _rebuild();
  }

  /// The user looked at the Recent tab: nothing is new any more.
  Future<void> markSeen() async {
    final now = _now();
    if (!now.isAfter(_seenAt)) return;
    _seenAt = now;
    await _guard((s) => s.saveSeenAt(now));
    _rebuild();
  }

  // -------------------------------------------------------------------------
  // Actions

  /// Answers [item] with the button [actionId] through the feature's own
  /// handler ([NotificationActionHandlers]). A notification still in the
  /// tray is taken out first, as its own button would. True when recorded.
  Future<bool> perform(CenterItem item, String actionId) async {
    final handler = ref.read(notificationActionHandlersProvider)[actionId];
    if (handler == null) return false;
    final now = _now();
    if (item.live) await _cancelQuietly(item.id);
    bool ok;
    try {
      ok = await handler(CenterActionRequest(notice: item.notice, actionId: actionId, now: now, live: item.live));
    } catch (e) {
      debugPrint('NotificationCenter: $actionId failed: $e');
      ok = false;
    }
    if (!ref.mounted) return ok;
    if (ok && !item.state.isUpcoming) {
      _history = _history.record(
        HistoryEntry(notice: item.notice, status: HistoryStatus.acted, actionId: actionId, recordedAt: now),
        now: now,
      );
      await _saveHistory();
    }
    await refresh();
    return ok;
  }

  /// Takes [item] out of the tray and brings it back after [by]. Returns
  /// when it will arrive again (null when it could not be re-armed).
  Future<DateTime?> snooze(CenterItem item, Duration by) async {
    final now = _now();
    final until = now.add(by);
    final gate = _gate;
    final ok = gate.attached ? await gate.snooze(item.notice, until) : await _snoozeUngated(item.notice, until);
    if (!ok || !ref.mounted) return null;
    _history = _history.record(
      HistoryEntry(notice: item.notice, status: HistoryStatus.snoozed, recordedAt: now),
      now: now,
    );
    await _persistPolicy();
    await _saveHistory();
    await refresh();
    return until;
  }

  /// Without the gate: re-schedule through the service (the feature's next
  /// re-plan may take it back).
  Future<bool> _snoozeUngated(CenterNotice notice, DateTime until) async {
    final service = _service;
    await _cancelQuietly(notice.id);
    final ok = await service.schedule(NotificationGate.requestFor(notice, at: until, now: _now()));
    if (ok) await _gate.setPolicy(_gate.policy.snooze(SnoozedNotice(notice: notice, until: until)));
    return ok;
  }

  /// Cancels the snooze of an upcoming [item] (it will not come back).
  Future<void> cancelSnooze(CenterItem item) async {
    final gate = _gate;
    if (gate.attached) {
      await gate.cancelSnooze(item.id);
    } else {
      await _cancelQuietly(item.id);
      await gate.setPolicy(gate.policy.dropSnooze(item.id));
    }
    await _persistPolicy();
    await refresh();
  }

  /// Keeps one upcoming firing from arriving (listed as skipped).
  Future<CenterUndo> skip(CenterItem item) async {
    await _applyPolicy(_gate.policy.skip(item.notice), cancel: _gate.attached ? null : item.id);
    return () => restore(item);
  }

  /// Lets a skipped firing arrive after all.
  Future<void> restore(CenterItem item) => _applyPolicy(_gate.policy.unskip(item.notice));

  /// Quiets [group] until [until]: nothing of it sounds before then.
  Future<CenterUndo> mute(NotificationGroup group, DateTime until) async {
    final previous = _gate.policy.mutedUntil[group];
    await _applyPolicy(_gate.policy.mute(group, until));
    if (!_gate.attached) {
      // Without the gate the center can only take out what is pending now.
      for (final i in state.upcoming) {
        if (i.group == group && i.state == CenterItemState.muted) await _cancelQuietly(i.id);
      }
    }
    return () async {
      final p = _gate.policy;
      await _applyPolicy(previous == null ? p.unmute(group) : p.mute(group, previous));
    };
  }

  Future<void> unmute(NotificationGroup group) => _applyPolicy(_gate.policy.unmute(group));

  Future<void> _applyPolicy(CenterPolicy policy, {int? cancel}) async {
    await _gate.setPolicy(policy);
    if (cancel != null) await _cancelQuietly(cancel);
    await _persistPolicy();
    await refresh();
  }

  /// Removes [item] from Recent (and from the tray while it is there).
  Future<CenterUndo> dismiss(CenterItem item) => _hide([item]);

  /// "Clear all": every recent notification leaves the list, and Madar's
  /// notifications leave the tray.
  Future<CenterUndo?> clearAll() async {
    final items = state.recent;
    if (items.isEmpty) return null;
    return _hide(items);
  }

  Future<CenterUndo> _hide(List<CenterItem> items) async {
    final now = _now();
    final before = [
      for (final i in items)
        _history[i.key] ?? HistoryEntry(notice: i.notice, status: HistoryStatus.delivered, recordedAt: now),
    ];
    for (final i in items) {
      if (i.live) await _cancelQuietly(i.id);
    }
    _history = _history.recordAll(before, now: now).hide(items.map((i) => i.key));
    await _saveHistory();
    await refresh();
    return () async {
      _history = _history.restore(before);
      await _saveHistory();
      await refresh();
    };
  }

  // -------------------------------------------------------------------------

  Future<void> _cancelQuietly(int id) async {
    try {
      await _service.cancel(id);
    } catch (e) {
      debugPrint('NotificationCenter: cancelling $id failed: $e');
    }
  }

  Future<void> _saveHistory() => _guard((s) => s.saveHistory(_history));

  Future<void> _persistPolicy() async {
    if (!ref.mounted) return;
    final policy = _gate.policy;
    await _guard((s) => s.savePolicy(policy));
  }

  Future<void> _guard(Future<void> Function(NotificationCenterStore store) write) async {
    final store = _store;
    if (store == null) return;
    try {
      await write(store);
    } catch (e) {
      debugPrint('NotificationCenter: saving failed: $e');
    }
  }
}
