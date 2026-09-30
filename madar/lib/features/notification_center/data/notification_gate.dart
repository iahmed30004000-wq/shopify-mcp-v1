import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_envelope.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_platform.dart';
import '../domain/center_layout.dart' show GroupOf;
import '../domain/center_models.dart';
import '../domain/center_policy.dart';
import '../domain/describers.dart' show NotificationDescriberRegistry;

/// A request the gate kept from the system (muted or skipped).
@immutable
class HeldRequest {
  const HeldRequest({required this.request, required this.payload, required this.timing, required this.notice});

  final NotificationRequest request;

  /// Exactly the payload the feature scheduled – reported back as pending
  /// so the feature's declarative sync sees it unchanged (no churn).
  final String payload;
  final NotificationTiming timing;
  final CenterNotice notice;
}

@immutable
class _Seen {
  const _Seen(this.request, this.payload, this.timing);

  final NotificationRequest request;
  final String payload;
  final NotificationTiming timing;
}

/// Enforces the notification center's [CenterPolicy] where every feature's
/// notifications pass – the [NotificationPlatform] the shared
/// `NotificationService` schedules through ([GatedNotificationPlatform]) –
/// without any feature knowing about it:
///
/// * **mute** – a request of a muted group due before the mute ends is
///   *held*: kept from the system, yet reported as pending with its exact
///   payload, so the feature's sync sees it unchanged and never re-sends it.
///   Held requests past their moment simply lapse (a mute that ends while
///   Madar is closed never leaves a later alarm unarmed: only moments
///   inside the mute are held). An immediate `show` of a muted group is
///   swallowed and reported on [silenced] (the center lists it).
/// * **skip** – the same, for one firing.
/// * **snooze** – a delivered notification re-armed later under its own id
///   (so its tap still routes to its feature) and hidden from the pending
///   list, so the feature's next sync neither cancels nor duplicates it. A
///   feature that schedules or cancels that id itself takes it back.
///
/// Un-muting (or restoring a skip) re-arms what is still held. The gate
/// starts empty and permissive; the center loads the stored policy into it
/// ([setPolicy]) once the database is open, and a sweep then holds back
/// anything a feature armed in between.
class NotificationGate {
  NotificationGate({GroupOf? groupOf, DateTime Function()? clock})
    : groupOf = groupOf ?? NotificationDescriberRegistry.fallbackGroupOf,
      _clock = clock ?? DateTime.now;

  /// Classifies requests into groups (the describer registry's).
  GroupOf groupOf;
  final DateTime Function() _clock;

  CenterPolicy _policy = CenterPolicy.empty;
  bool _loaded = false;
  GatedNotificationPlatform? _platform;
  final Map<int, HeldRequest> _held = {};
  final LinkedHashMap<int, _Seen> _seen = LinkedHashMap();

  /// What the inner platform had pending at the last look (id → payload).
  final Map<int, String?> _innerPending = {};
  static const int _seenLimit = 800;

  final _silenced = StreamController<CenterNotice>.broadcast();
  final _cancelled = StreamController<CenterNotice>.broadcast();
  final _policyChanges = StreamController<CenterPolicy>.broadcast();

  CenterPolicy get policy => _policy;

  /// The stored policy has been applied ([setPolicy]).
  bool get policyLoaded => _loaded;

  /// A [GatedNotificationPlatform] routes the notification service through
  /// this gate (without it the center can only ask – mutes are not enforced).
  bool get attached => _platform != null;

  /// Immediate notifications a mute kept from the tray.
  Stream<CenterNotice> get silenced => _silenced.stream;

  /// Upcoming notifications a feature cancelled before their moment (so the
  /// center does not later count them as delivered).
  Stream<CenterNotice> get cancelled => _cancelled.stream;

  /// Policy changes the gate made itself (a feature took a snoozed id back).
  Stream<CenterPolicy> get policyChanges => _policyChanges.stream;

  /// The requests held back right now, by id.
  Map<int, HeldRequest> get held => Map.unmodifiable(_held);

  void _attach(GatedNotificationPlatform platform) => _platform = platform;

  DateTime get _now => _clock();

  CenterItemState? _holdOf(CenterNotice n) => _policy.holdOf(n, groupOf(n), now: _now);

  void _remember(NotificationRequest request, String payload, NotificationTiming timing) {
    _seen.remove(request.id);
    _seen[request.id] = _Seen(request, payload, timing);
    while (_seen.length > _seenLimit) {
      _seen.remove(_seen.keys.first);
    }
  }

  void _takeBackSnooze(int id) {
    if (!_policy.snoozed.containsKey(id)) return;
    _policy = _policy.dropSnooze(id);
    _policyChanges.add(_policy);
  }

  /// Applies [policy] (the stored one at start, or an edit): holds back
  /// what it now mutes or skips and re-arms what it no longer does.
  Future<void> setPolicy(CenterPolicy policy) async {
    _policy = policy.pruned(_now);
    _loaded = true;
    await _sweep();
  }

  Future<void> _sweep() async {
    final p = _platform;
    if (p == null) return;
    final now = _now;
    for (final e in [..._held.entries]) {
      final h = e.value;
      final at = h.notice.at;
      if (at == null || !at.isAfter(now)) {
        _held.remove(e.key);
        continue;
      }
      if (_holdOf(h.notice) == null) {
        _held.remove(e.key);
        await p._arm(h.request, h.payload, h.timing);
      }
    }
    final List<PendingNotice> pending;
    try {
      pending = await p.inner.pending();
    } catch (e) {
      debugPrint('NotificationGate: reading pending notifications failed: $e');
      return;
    }
    _innerPending
      ..clear()
      ..addAll({for (final x in pending) x.id: x.payload});
    for (final x in pending) {
      if (_policy.snoozed.containsKey(x.id) || _held.containsKey(x.id)) continue;
      final n = CenterNotice.fromPayload(x.id, x.payload, title: x.title, body: x.body);
      final at = n.at;
      if (at == null || !at.isAfter(now) || _holdOf(n) == null) continue;
      final seen = _seen[x.id];
      final known = seen != null && seen.payload == x.payload;
      final request = known ? seen.request : _reconstruct(n);
      _held[x.id] = HeldRequest(
        request: request,
        payload: x.payload ?? NotificationEnvelope.encode(request),
        timing: known ? seen.timing : request.timing,
        notice: n,
      );
      await p.inner.cancel(x.id);
      _innerPending.remove(x.id);
    }
  }

  NotificationRequest _reconstruct(CenterNotice n) => requestFor(n, now: _now);

  /// A request rebuilt from what the platform reports (after a restart the
  /// original is gone): same id, channel, texts, instant and data – no
  /// buttons (the feature's next re-plan restores those).
  static NotificationRequest requestFor(CenterNotice n, {DateTime? at, required DateTime now}) {
    final ns =
        NotificationNamespaces.byName(n.namespace ?? '') ?? NotificationNamespace(n.namespace ?? 'center', n.id, n.id);
    return NotificationRequest(
      namespace: ns,
      id: n.id,
      channelId: n.channelId ?? 'madar.center.1',
      title: n.title ?? '',
      body: n.body ?? '',
      at: at ?? n.at ?? now,
      data: n.data,
    );
  }

  /// Takes [notice] (shown now) out of the tray and brings it back at
  /// [until] under the same id. False when the platform refused.
  Future<bool> snooze(CenterNotice notice, DateTime until) async {
    final p = _platform;
    if (p == null) return false;
    final seen = _seen[notice.id];
    final base = seen != null && CenterNotice.fromRequest(seen.request).key == notice.key
        ? seen.request
        : _reconstruct(notice);
    final timing = base.timing == NotificationTiming.alarmClock
        ? NotificationTiming.alarmClock
        : NotificationTiming.exactWhileIdle;
    final request = base.copyWith(at: until, timing: timing);
    final payload = NotificationEnvelope.encode(request);
    try {
      await p.inner.cancel(notice.id);
      try {
        await p.inner.schedule(request, payload, timing: timing);
      } on ExactAlarmNotPermittedException {
        await p.inner.schedule(request, payload, timing: NotificationTiming.inexactWhileIdle);
      }
    } catch (e) {
      debugPrint('NotificationGate: snoozing ${notice.key} failed: $e');
      return false;
    }
    _remember(request, payload, timing);
    _innerPending[notice.id] = payload;
    _policy = _policy.snooze(SnoozedNotice(notice: notice, until: until));
    return true;
  }

  /// The shown notifications straight from the platform the gate wraps –
  /// whatever wraps the gate in turn (e.g. a decorator that does not
  /// forward [ActiveNotificationQuery]) – or null when not attached.
  Future<List<ActiveNotice>>? activeNotices() => _platform?.activeNotices();

  /// Cancels a snooze made with [snooze] (the snoozed alarm goes too).
  Future<void> cancelSnooze(int id) async {
    if (!_policy.snoozed.containsKey(id)) return;
    _policy = _policy.dropSnooze(id);
    await _platform?.inner.cancel(id);
    _innerPending.remove(id);
  }

  Future<void> dispose() async {
    await _silenced.close();
    await _cancelled.close();
    await _policyChanges.close();
  }
}

/// The [NotificationPlatform] decorator behind [NotificationGate]. Wire it
/// between the notification service and the real plugin:
///
/// ```dart
/// notificationPlatformProvider.overrideWith(
///   (ref) => GatedNotificationPlatform(realPlatform, ref.watch(notificationGateProvider)),
/// )
/// ```
///
/// Everything but scheduling passes straight through.
class GatedNotificationPlatform implements NotificationPlatform, ActiveNotificationQuery {
  GatedNotificationPlatform(this.inner, this.gate) {
    gate._attach(this);
  }

  final NotificationPlatform inner;
  final NotificationGate gate;

  Future<void> _arm(NotificationRequest request, String payload, NotificationTiming timing) async {
    try {
      await inner.schedule(request, payload, timing: timing);
    } on ExactAlarmNotPermittedException {
      await inner.schedule(request, payload, timing: NotificationTiming.inexactWhileIdle);
    } catch (e) {
      debugPrint('NotificationGate: re-arming ${request.id} failed: $e');
      return;
    }
    gate._innerPending[request.id] = payload;
  }

  @override
  Future<void> schedule(NotificationRequest request, String payload, {required NotificationTiming timing}) async {
    gate._remember(request, payload, timing);
    gate._takeBackSnooze(request.id);
    final notice = CenterNotice.fromRequest(request);
    if (gate._holdOf(notice) != null) {
      gate._held[request.id] = HeldRequest(request: request, payload: payload, timing: timing, notice: notice);
      if (gate._innerPending.containsKey(request.id)) {
        await inner.cancel(request.id);
        gate._innerPending.remove(request.id);
      }
      return;
    }
    gate._held.remove(request.id);
    await inner.schedule(request, payload, timing: timing);
    gate._innerPending[request.id] = payload;
  }

  @override
  Future<void> show(NotificationRequest request, String payload) async {
    gate._remember(request, payload, request.timing);
    final now = gate._now;
    final notice = CenterNotice.fromRequest(request);
    if (gate.policy.mutes(gate.groupOf(notice), now)) {
      if (!gate._silenced.isClosed) gate._silenced.add(notice);
      return;
    }
    await inner.show(request, payload);
  }

  @override
  Future<void> cancel(int id) async {
    final held = gate._held.remove(id);
    final payload = gate._innerPending.remove(id);
    final snoozed = gate.policy.snoozed.containsKey(id);
    gate._takeBackSnooze(id);
    final notice = held?.notice ?? (payload == null ? null : CenterNotice.fromPayload(id, payload));
    final at = notice?.at;
    if (!snoozed && notice != null && at != null && at.isAfter(gate._now) && !gate._cancelled.isClosed) {
      gate._cancelled.add(notice);
    }
    await inner.cancel(id);
  }

  @override
  Future<List<PendingNotice>> pending() async {
    final list = await inner.pending();
    gate._innerPending
      ..clear()
      ..addAll({for (final p in list) p.id: p.payload});
    final now = gate._now;
    gate._held.removeWhere((_, h) => h.notice.at == null || !h.notice.at!.isAfter(now));
    final hidden = gate.policy.snoozed.keys.toSet();
    return [
      for (final p in list)
        if (!hidden.contains(p.id) && !gate._held.containsKey(p.id)) p,
      for (final h in gate._held.values)
        PendingNotice(h.request.id, h.payload, title: h.request.title, body: h.request.body),
    ];
  }

  @override
  Future<Set<int>?> armedIds(Iterable<int> ids) async {
    final list = ids.toList();
    final held = {
      for (final id in list)
        if (gate._held.containsKey(id)) id,
    };
    final armed = await inner.armedIds([
      for (final id in list)
        if (!held.contains(id)) id,
    ]);
    return armed == null ? null : {...armed, ...held};
  }

  @override
  Future<List<ActiveNotice>> activeNotices() async {
    final i = inner;
    if (i case final ActiveNotificationQuery query) return query.activeNotices();
    return [
      for (final id in await i.activeIds())
        ActiveNotice(
          id,
          payload: gate._seen[id]?.payload,
          title: gate._seen[id]?.request.title,
          body: gate._seen[id]?.request.body,
          channelId: gate._seen[id]?.request.channelId,
        ),
    ];
  }

  @override
  Future<void> initialize({required void Function(RawNotificationTap tap) onTap}) => inner.initialize(onTap: onTap);

  @override
  Future<RawNotificationTap?> launchTap() => inner.launchTap();

  @override
  Future<void> createChannelGroup(String id, String name) => inner.createChannelGroup(id, name);

  @override
  Future<void> createChannel(NotificationChannelSpec spec) => inner.createChannel(spec);

  @override
  Future<void> deleteChannel(String id) => inner.deleteChannel(id);

  @override
  Future<List<String>> channelIds() => inner.channelIds();

  @override
  Future<List<int>> activeIds() => inner.activeIds();

  @override
  Future<bool> notificationsEnabled() => inner.notificationsEnabled();

  @override
  Future<bool> requestNotifications() => inner.requestNotifications();

  @override
  Future<bool> canScheduleExact() => inner.canScheduleExact();

  @override
  Future<bool> requestExactAlarms() => inner.requestExactAlarms();

  @override
  Future<bool> requestFullScreenIntent() => inner.requestFullScreenIntent();
}
