import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_envelope.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_platform.dart';
import '../domain/builtin_describers.dart' show builtInDescribers;
import '../domain/center_layout.dart' show GroupOf;
import '../domain/center_models.dart';
import '../domain/center_policy.dart';
import '../domain/describers.dart' show NotificationDescriberRegistry;

/// Marks on the payloads the gate itself arms or reports – never on a
/// feature's own. An extra top-level key of Madar's envelope (`"nc"`), so
/// the feature's tap data, the boot guard's `at` / `late` and the lock
/// screen's `ls` read exactly as before:
///
/// * [snooze] – a snooze armed by the center. Hidden from every pending
///   list by the mark alone, so a feature's re-plan never cancels it – also
///   in a new run before the stored policy is loaded.
/// * [rebuilt] – a request rebuilt from what the plugin reported (a restart
///   loses the original: no buttons). A feature's next sync sees it as
///   changed and re-sends its own request, which replaces it.
///
/// A snooze whose feature later planned another firing under the same id
/// (positional ids: the next due reminder takes `of(0)`) moves to one of
/// the center's own ids ([NotificationGate.snoozeIds]) and carries the id
/// it came from under [originKey]: taps are routed with that id, and the
/// center lists it under it.
abstract final class GateMarks {
  static const String key = 'nc';
  static const String originKey = 'nco';
  static const String snooze = 's';
  static const String rebuilt = 'r';

  /// The mark on [payload], or null (a feature's own payload).
  static String? of(String? payload) {
    if (payload == null || !payload.contains('"$key"')) return null;
    final map = _map(payload);
    final mark = map?[key];
    return mark is String ? mark : null;
  }

  /// The feature's id a moved snooze belongs to, or null.
  static int? originOf(String? payload) {
    if (payload == null || !payload.contains('"$originKey"')) return null;
    final origin = _map(payload)?[originKey];
    return origin is int ? origin : null;
  }

  /// [payload] with [mark] (replacing any other).
  static String mark(String? payload, String mark) {
    final map = <String, Object?>{...?_map(payload)}
      ..remove(key)
      ..remove(originKey);
    map[key] = mark;
    return jsonEncode(map);
  }

  /// [payload] as a snooze moved off [origin] (its feature's id).
  static String moved(String? payload, int origin) {
    final map = <String, Object?>{...?_map(mark(payload, snooze))};
    map[originKey] = origin;
    return jsonEncode(map);
  }

  /// [payload] without its marks: exactly what the feature encoded.
  static String? strip(String? payload) {
    if (of(payload) == null && originOf(payload) == null) return payload;
    return jsonEncode(
      <String, Object?>{..._map(payload)!}
        ..remove(key)
        ..remove(originKey),
    );
  }

  static Map<String, Object?>? _map(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final raw = jsonDecode(payload);
      return raw is Map ? Map<String, Object?>.from(raw) : null;
    } on FormatException {
      return null;
    }
  }
}

/// A request the gate kept from the system (muted or skipped).
@immutable
class HeldRequest {
  const HeldRequest({
    required this.request,
    required this.payload,
    required this.timing,
    required this.notice,
    this.rebuilt = false,
  });

  final NotificationRequest request;

  /// Exactly the payload the feature scheduled – reported back as pending
  /// so the feature's declarative sync sees it unchanged (no churn).
  final String payload;
  final NotificationTiming timing;
  final CenterNotice notice;

  /// Rebuilt from what the plugin reported (the original request is from an
  /// earlier run): reported with [GateMarks.rebuilt], so the feature's next
  /// sync re-sends its own request (buttons included).
  final bool rebuilt;

  /// What the pending list says about it.
  String get reported => rebuilt ? GateMarks.mark(payload, GateMarks.rebuilt) : payload;
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
///   (so its tap still routes to its feature), marked ([GateMarks.snooze])
///   and hidden from the pending list by that mark, so no feature's sync –
///   in this run or the next – cancels or duplicates it. A feature that
///   cancels that id itself takes it back; one that schedules another
///   firing under it (positional ids: the next due reminder takes the id)
///   gets the id, and the snooze moves to one of the center's own ids
///   ([snoozeIds], [GateMarks.moved]) – both arrive, and a tap on the snooze
///   still reaches its feature under the feature's id. A notification whose
///   id already has another firing pending (still to come, or held past its
///   moment by Doze) is not snoozed nor taken out of the tray (that firing
///   would go with it).
///
/// Un-muting (or restoring a skip) re-arms what is still held. A request
/// held from what the plugin reported (after a restart) is marked
/// [GateMarks.rebuilt] until its feature re-sends it ([staleNamespaces]).
///
/// **Fails open.** Every decision runs in a guard: on any error the call
/// goes to the real platform as if there were no gate. Calls that read or
/// change what is armed run one at a time, so a sweep never works from a
/// list a concurrent re-plan has already changed.
class NotificationGate {
  NotificationGate({GroupOf? groupOf, DateTime Function()? clock, this.holdImmediate = true})
    : groupOf = groupOf ?? NotificationDescriberRegistry.fallbackGroupOf,
      _clock = clock ?? DateTime.now;

  /// A gate for a background isolate (the medication tracker's answer
  /// handler): the built-in grouping, immediate notifications never
  /// silenced (a "your answer was not recorded" notice must reach the
  /// user). Load the stored policy with `loadStoredNotificationPolicy`
  /// (never sweeping: another isolate owns what is held).
  factory NotificationGate.background({DateTime Function()? clock}) => NotificationGate(
    groupOf: NotificationDescriberRegistry(builtInDescribers()).groupOf,
    clock: clock,
    holdImmediate: false,
  );

  /// Classifies requests into groups (the describer registry's).
  GroupOf groupOf;
  final DateTime Function() _clock;

  /// Whether an immediate `show` of a muted group is silenced.
  final bool holdImmediate;

  /// How long a call waits for the one before it (a platform call that
  /// never returns must not keep an alarm from ever being scheduled).
  static const Duration lockWait = Duration(seconds: 10);

  /// How long a feature's schedule waits for a snooze under its id to move
  /// off it ([snoozeIds]).
  static const Duration moveWait = Duration(seconds: 3);

  /// The center's own ids – outside every feature's namespace – for a
  /// snooze its feature's re-plan would otherwise replace ([GateMarks.moved]).
  /// Keep them out of `NotificationNamespaces`' blocks.
  static const NotificationNamespace snoozeIds = NotificationNamespaces.center;

  /// The group that decides whether [notice] is held. The adhan and the
  /// medication tracker are pinned to their own groups: a describer a
  /// feature registers (first match wins) can never make a Money mute
  /// silence the adhan or a dose – nor keep a Prayer mute from holding it.
  NotificationGroup _groupFor(CenterNotice notice) =>
      NotificationDescriberRegistry.pinnedGroupOf(notice) ?? groupOf(notice);

  CenterPolicy _policy = CenterPolicy.empty;
  bool _loaded = false;
  GatedNotificationPlatform? _platform;
  final Map<int, HeldRequest> _held = {};
  final LinkedHashMap<int, _Seen> _seen = LinkedHashMap();

  /// Ids held or armed from a rebuilt request, until their feature re-sends
  /// its own.
  final Set<int> _rebuilt = {};

  /// What the inner platform had pending at the last look (id → payload).
  final Map<int, String?> _innerPending = {};

  /// [_innerPending] was read from the platform at least once in this run.
  bool _innerRead = false;
  static const int _seenLimit = 800;
  Future<void> _tail = Future.value();

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

  /// Namespaces with a request the gate rebuilt (held, or re-armed without
  /// its buttons) that its feature has not re-sent yet: re-plan them
  /// (`notificationReplanHooksProvider`) to have the feature's own request
  /// back.
  Set<String> get staleNamespaces => {for (final id in _rebuilt) ?NotificationNamespaces.owning(id)?.name};

  void _attach(GatedNotificationPlatform platform) => _platform = platform;

  DateTime get _now => _clock();

  CenterItemState? _holdOf(CenterNotice n) => _policy.holdOf(n, _groupFor(n), now: _now);

  static void _log(String what, Object error) =>
      // The type only: messages can carry payloads (names of medications).
      debugPrint('NotificationGate: $what failed (${error.runtimeType})');

  /// Runs [body] after the calls before it (at most [lockWait] behind a
  /// stuck one).
  Future<T> _serial<T>(Future<T> Function() body) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    Future<T> run() async {
      try {
        await previous.timeout(lockWait, onTimeout: () {});
      } catch (_) {}
      try {
        return await body();
      } finally {
        done.complete();
      }
    }

    return run();
  }

  void _remember(NotificationRequest request, String payload, NotificationTiming timing) {
    _seen.remove(request.id);
    _seen[request.id] = _Seen(request, payload, timing);
    while (_seen.length > _seenLimit) {
      _seen.remove(_seen.keys.first);
    }
  }

  /// The center's id a snooze of [origin] was moved to, if it is armed (by
  /// the pending list as last read).
  int? _movedSnoozeOf(int origin) {
    for (final e in _innerPending.entries) {
      if (GateMarks.originOf(e.value) == origin && GateMarks.of(e.value) == GateMarks.snooze) return e.key;
    }
    return null;
  }

  /// Its feature took [id] back: the snooze under it goes (and its firing
  /// is reported [cancelled], so the center never counts it as delivered)
  /// – unless it was moved to the center's own id and still arrives.
  void _takeBackSnooze(int id) {
    final s = _policy.snoozed[id];
    if (s == null || _movedSnoozeOf(id) != null) return;
    _policy = _policy.dropSnooze(id);
    if (s.until.isAfter(_now) && !_cancelled.isClosed) _cancelled.add(s.again);
    if (!_policyChanges.isClosed) _policyChanges.add(_policy);
  }

  /// A feature cancelled [id]: it is not held any more, a snooze of it is
  /// taken back, and an upcoming one is reported ([cancelled]).
  void _featureCancelled(int id) {
    final held = _held.remove(id);
    final payload = _innerPending.remove(id);
    _rebuilt.remove(id);
    final snoozeHere = GateMarks.of(payload) == GateMarks.snooze;
    _takeBackSnooze(id);
    final notice = held?.notice ?? (payload == null || snoozeHere ? null : CenterNotice.fromPayload(id, payload));
    final at = notice?.at;
    if (notice != null && at != null && at.isAfter(_now) && !_cancelled.isClosed) _cancelled.add(notice);
  }

  /// A feature is about to schedule [id] while a snooze the center armed
  /// under it is still to come (its re-plan gave the id to another firing:
  /// positional ids). The feature's request goes ahead exactly as before –
  /// only the snooze first moves to one of [snoozeIds], so both arrive.
  /// True when a snooze was moved (it is then not taken back). Never throws.
  ///
  /// Only looks at the plugin when a snooze of [request]'s id is known – or,
  /// once per run before the first look, for the features the center
  /// snoozes: never for the adhan or a dose (the center does not snooze
  /// those, and nothing may hold them back).
  Future<bool> _moveSnoozeOff(NotificationRequest request) async {
    final p = _platform;
    if (p == null) return false;
    final id = request.id;
    final known = _policy.snoozed.containsKey(id) || GateMarks.of(_innerPending[id]) == GateMarks.snooze;
    final pinned =
        request.namespace == NotificationNamespaces.adhan || request.namespace == NotificationNamespaces.meds;
    if (!known && (_innerRead || pinned)) return false;
    try {
      final pending = await p.inner.pending();
      _innerPending
        ..clear()
        ..addAll({for (final e in pending) e.id: e.payload});
      _innerRead = true;
      final x = pending
          .where(
            (e) => e.id == id && GateMarks.of(e.payload) == GateMarks.snooze && GateMarks.originOf(e.payload) == null,
          )
          .firstOrNull;
      final at = x == null ? null : NotificationEnvelope.decode(x.payload).at;
      if (x == null || at == null || !at.isAfter(_now)) return false;
      // Moved already (the service retrying the same request inexactly):
      // never a second copy.
      final ms = at.millisecondsSinceEpoch;
      final already = pending.any(
        (e) =>
            GateMarks.originOf(e.payload) == id &&
            GateMarks.of(e.payload) == GateMarks.snooze &&
            NotificationEnvelope.decode(e.payload).at?.millisecondsSinceEpoch == ms,
      );
      if (!already) {
        final free = _freeSnoozeId({for (final e in pending) e.id, ...await p.inner.activeIds()});
        if (free == null) return false;
        final seen = _seen[id];
        final same = seen != null && seen.payload == x.payload;
        final base = same
            ? seen.request
            : requestFor(
                CenterNotice.fromPayload(id, x.payload, title: x.title, body: x.body),
                now: _now,
                payload: x.payload,
              );
        final copy = base.copyWith(id: free);
        final timing = same ? seen.timing : base.timing;
        final payload = GateMarks.moved(x.payload, id);
        if (!await p._arm(copy, payload, timing)) return false;
        _remember(copy, payload, timing);
      }
      // Exactly one copy: the one under the feature's id goes now (its own
      // request replaces it anyway – or, should that fail, it would sound
      // twice).
      await p.inner.cancel(id);
      _innerPending.remove(id);
      return true;
    } catch (e) {
      _log('moving the snooze of $id', e);
      return false;
    }
  }

  /// The first of [snoozeIds] not in [taken] (pending or shown).
  int? _freeSnoozeId(Set<int> taken) {
    for (var id = snoozeIds.first; id <= snoozeIds.last; id++) {
      if (!taken.contains(id) && !_innerPending.containsKey(id)) return id;
    }
    return null;
  }

  /// The id [notice] is shown under: its own – or, a snooze moved off its
  /// feature's id ([GateMarks.moved]), the center's.
  Future<int> _shownIdOf(GatedNotificationPlatform p, CenterNotice notice) async {
    final ms = notice.at?.millisecondsSinceEpoch;
    // Never snoozed by the center, so never moved: no extra platform call
    // in the way of the adhan's Stop or a dose's answer.
    if (ms == null || NotificationDescriberRegistry.pinnedGroupOf(notice) != null) return notice.id;
    try {
      for (final a in await p.activeNotices()) {
        if (GateMarks.originOf(a.payload) == notice.id &&
            NotificationEnvelope.decode(a.payload).at?.millisecondsSinceEpoch == ms) {
          return a.id;
        }
      }
    } catch (e) {
      _log('reading the tray', e);
    }
    return notice.id;
  }

  /// Applies [policy] (the stored one at start, or an edit): holds back
  /// what it now mutes or skips and re-arms what it no longer does. Without
  /// [sweep] only what is scheduled from now on is held (a background
  /// isolate: what is held lives in the app's own gate).
  Future<void> setPolicy(CenterPolicy policy, {bool sweep = true}) => _serial(() async {
    _policy = policy.pruned(_now);
    _loaded = true;
    if (sweep) await _sweep();
  });

  Future<void> _sweep() async {
    final p = _platform;
    if (p == null) return;
    final now = _now;
    for (final e in [..._held.entries]) {
      try {
        final h = e.value;
        final at = h.notice.at;
        if (at == null || !at.isAfter(now)) {
          _held.remove(e.key);
          _rebuilt.remove(e.key);
          continue;
        }
        if (_holdOf(h.notice) != null) continue;
        _held.remove(e.key);
        final armed = await p._arm(h.request, h.reported, h.timing);
        // Not armed: no longer reported either, so the feature's next sync
        // sees it missing and schedules it itself.
        if (!armed || !h.rebuilt) _rebuilt.remove(e.key);
      } catch (err) {
        _log('re-arming ${e.key}', err);
      }
    }
    final List<PendingNotice> pending;
    try {
      pending = await p.inner.pending();
    } catch (e) {
      _log('reading pending notifications', e);
      return;
    }
    _innerPending
      ..clear()
      ..addAll({for (final x in pending) x.id: x.payload});
    _innerRead = true;
    for (final x in pending) {
      try {
        if (_held.containsKey(x.id) || GateMarks.of(x.payload) == GateMarks.snooze) continue;
        final n = CenterNotice.fromPayload(x.id, x.payload, title: x.title, body: x.body);
        final at = n.at;
        if (at == null || !at.isAfter(now) || _holdOf(n) == null) continue;
        final seen = _seen[x.id];
        final known = seen != null && seen.payload == x.payload;
        final original = GateMarks.strip(x.payload);
        final request = known ? seen.request : requestFor(n, now: now, payload: original);
        _held[x.id] = HeldRequest(
          request: request,
          payload: original ?? NotificationEnvelope.encode(request),
          timing: known ? seen.timing : request.timing,
          notice: n,
          rebuilt: !known,
        );
        if (!known) _rebuilt.add(x.id);
        await p.inner.cancel(x.id);
        _innerPending.remove(x.id);
      } catch (e) {
        // Could not hold it: it stays armed (open), and is not reported twice.
        _held.remove(x.id);
        _log('holding ${x.id}', e);
      }
    }
  }

  /// A request rebuilt from what the platform reports (after a restart the
  /// original is gone): same id, channel, texts, instant and data, and –
  /// from [payload], the envelope – full screen and drop-if-late; an alarm
  /// clock for the adhan and full-screen alarms. No buttons: its feature's
  /// next re-plan restores those ([GateMarks.rebuilt]).
  static NotificationRequest requestFor(CenterNotice n, {DateTime? at, required DateTime now, String? payload}) {
    final ns =
        NotificationNamespaces.byName(n.namespace ?? '') ?? NotificationNamespace(n.namespace ?? 'center', n.id, n.id);
    final envelope = GateMarks._map(payload) ?? const {};
    final fullScreen = envelope['ls'] == 1;
    final late = envelope['late'];
    final alarm = fullScreen || ns == NotificationNamespaces.adhan;
    return NotificationRequest(
      namespace: ns,
      id: n.id,
      channelId: n.channelId ?? 'madar.center.1',
      title: n.title ?? '',
      body: n.body ?? '',
      at: at ?? n.at ?? now,
      data: n.data,
      category: fullScreen ? NotificationCategory.alarm : NotificationCategory.reminder,
      timing: alarm ? NotificationTiming.alarmClock : NotificationTiming.exactWhileIdle,
      fullScreen: fullScreen,
      publicOnLockScreen: alarm,
      dropIfLateBy: late is int && late > 0 ? Duration(milliseconds: late) : null,
    );
  }

  /// Whether [id] has a firing other than the one [shown] at – held, or
  /// still pending with the plugin: one still to come, and one past its
  /// moment too (Doze holds exact-while-idle alarms back for minutes; a
  /// cancel by id would take it along). A pending entry without an instant
  /// counts (it cannot be told apart).
  bool _hasOtherFiring(int id, List<PendingNotice> pending, {required DateTime? shown}) {
    final ms = shown?.millisecondsSinceEpoch;
    final held = _held[id];
    if (held != null && (ms == null || held.notice.at?.millisecondsSinceEpoch != ms)) return true;
    for (final x in pending) {
      if (x.id != id) continue;
      final at = NotificationEnvelope.decode(x.payload).at;
      if (at == null || ms == null || at.millisecondsSinceEpoch != ms) return true;
    }
    return false;
  }

  /// Re-arms the snoozes the system dropped (a force stop, an OEM task
  /// killer, a revoked exact-alarm permission) although the plugin still
  /// lists them – hidden from the features' syncs, only the gate can. Uses
  /// the pending list as last read (the center calls it after each look).
  /// Returns how many it re-armed.
  Future<int> rearmDroppedSnoozes() async {
    final p = _platform;
    if (p == null) return 0;
    return _serial(() async {
      try {
        final now = _now;
        final due = <int, String>{
          for (final e in _innerPending.entries)
            if (GateMarks.of(e.value) == GateMarks.snooze &&
                (NotificationEnvelope.decode(e.value).at?.isAfter(now) ?? false))
              e.key: e.value!,
        };
        if (due.isEmpty) return 0;
        final armed = await p.inner.armedIds(due.keys);
        if (armed == null) return 0;
        var count = 0;
        for (final e in due.entries) {
          if (armed.contains(e.key)) continue;
          final seen = _seen[e.key];
          final known = seen != null && seen.payload == e.value;
          final request = known
              ? seen.request
              : requestFor(CenterNotice.fromPayload(e.key, e.value), now: now, payload: e.value);
          if (await p._arm(request, e.value, known ? seen.timing : request.timing)) count++;
        }
        return count;
      } catch (e) {
        _log('re-arming dropped snoozes', e);
        return 0;
      }
    });
  }

  /// Whether the policy keeps [notice] from arriving right now (muted at its
  /// moment, or skipped) – for what presents a notification's moment
  /// without the notification: the adhan hub opens the full-screen adhan at
  /// the exact time while Madar is in the foreground. False on any error
  /// (open).
  bool withholds(CenterNotice notice) {
    try {
      return _holdOf(notice) != null;
    } catch (e) {
      _log('checking ${notice.key}', e);
      return false;
    }
  }

  static bool _sameData(Map<String, Object?> a, Map<String, Object?> b) {
    try {
      return jsonEncode(a) == jsonEncode(b);
    } catch (_) {
      return false;
    }
  }

  /// The request behind [notice] as last seen under [id] (its buttons and
  /// timing), under [notice]'s own id – rebuilt when [id] has carried
  /// another firing since.
  NotificationRequest _requestOf(int id, CenterNotice notice) {
    final seen = _seen[id];
    final ms = notice.at?.millisecondsSinceEpoch;
    if (seen != null && seen.request.at.millisecondsSinceEpoch == ms && _sameData(seen.request.data, notice.data)) {
      return seen.request.copyWith(id: notice.id);
    }
    return requestFor(notice, now: _now);
  }

  /// Takes [notice] (shown now) out of the tray and brings it back at
  /// [until] under the same id. False when the platform refused, or when
  /// that id has another firing pending (snoozing would take it along). A
  /// snooze that arrived on one of the center's own ids ([GateMarks.moved])
  /// is snoozed again on another of them.
  Future<bool> snooze(CenterNotice notice, DateTime until) async {
    final p = _platform;
    if (p == null) return false;
    return _serial(() async {
      try {
        final now = _now;
        if (!until.isAfter(now)) return false;
        final shownId = await _shownIdOf(p, notice);
        final pending = await p.inner.pending();
        final moved = shownId != notice.id;
        if (!moved && _hasOtherFiring(notice.id, pending, shown: notice.at)) return false;
        final base = _requestOf(shownId, notice);
        final timing = base.timing == NotificationTiming.alarmClock
            ? NotificationTiming.alarmClock
            : NotificationTiming.exactWhileIdle;
        if (moved) {
          // Armed first on another of the center's ids, then taken away.
          final free = _freeSnoozeId({for (final e in pending) e.id, ...await p.inner.activeIds()});
          if (free == null) return false;
          final request = base.copyWith(id: free, at: until, timing: timing);
          final payload = GateMarks.moved(NotificationEnvelope.encode(request), notice.id);
          if (!await p._arm(request, payload, timing)) return false;
          await p.inner.cancel(shownId);
          _innerPending.remove(shownId);
          _remember(request, payload, timing);
        } else {
          final request = base.copyWith(at: until, timing: timing);
          final payload = GateMarks.mark(NotificationEnvelope.encode(request), GateMarks.snooze);
          await p.inner.cancel(notice.id);
          if (!await p._arm(request, payload, timing)) {
            // Put it back rather than lose it.
            await p.inner.show(base, NotificationEnvelope.encode(base));
            return false;
          }
          _remember(request, payload, timing);
        }
        _policy = _policy.snooze(SnoozedNotice(notice: notice, until: until));
        return true;
      } catch (e) {
        _log('snoozing ${notice.key}', e);
        return false;
      }
    });
  }

  /// Takes [shown] out of the tray (and stops its sound) – unless its id has
  /// another firing pending, which a cancel would take along: then it stays
  /// (false). Never touches what is held or snoozed.
  Future<bool> removeShown(CenterNotice shown) async {
    final p = _platform;
    if (p == null) return false;
    return _serial(() async {
      try {
        final shownId = await _shownIdOf(p, shown);
        if (shownId == shown.id && _hasOtherFiring(shown.id, await p.inner.pending(), shown: shown.at)) return false;
        await p.inner.cancel(shownId);
        _innerPending.remove(shownId);
        return true;
      } catch (e) {
        _log('removing ${shown.key} from the tray', e);
        return false;
      }
    });
  }

  /// The shown notifications straight from the platform the gate wraps –
  /// whatever wraps the gate in turn (e.g. a decorator that does not
  /// forward [ActiveNotificationQuery]) – or null when not attached.
  Future<List<ActiveNotice>>? activeNotices() => _platform?.activeNotices();

  /// Cancels a snooze made with [snooze] (of the notification with id [id]):
  /// the snoozed alarm goes – only one the gate armed ([GateMarks.snooze]),
  /// under [id] or moved to the center's own ids, never a feature's own
  /// alarm that took the id back meanwhile.
  Future<void> cancelSnooze(int id) => _serial(() async {
    _policy = _policy.dropSnooze(id);
    final p = _platform;
    if (p == null) return;
    try {
      for (final x in await p.inner.pending()) {
        if (GateMarks.of(x.payload) != GateMarks.snooze) continue;
        final origin = GateMarks.originOf(x.payload);
        if (origin == id || (origin == null && x.id == id)) {
          await p.inner.cancel(x.id);
          _innerPending.remove(x.id);
        }
      }
    } catch (e) {
      _log('cancelling the snooze of $id', e);
    }
  });

  /// Undoes a snooze: its alarm goes and [original] is back in the tray as
  /// it was (never silenced: it was there before). False when it could not
  /// be shown again.
  Future<bool> unsnooze(CenterNotice original) async {
    await cancelSnooze(original.id);
    final p = _platform;
    if (p == null) return false;
    try {
      final seen = _seen[original.id];
      final request = seen != null && _sameData(seen.request.data, original.data)
          ? seen.request.copyWith(at: original.at, timing: seen.request.timing)
          : requestFor(original, now: _now);
      final payload = NotificationEnvelope.encode(request);
      _remember(request, payload, request.timing);
      await p.inner.show(request, payload);
      return true;
    } catch (e) {
      _log('showing ${original.key} again', e);
      return false;
    }
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
/// Everything but scheduling passes straight through; scheduling passes
/// through too whenever the gate's own logic fails.
class GatedNotificationPlatform implements NotificationPlatform, ActiveNotificationQuery {
  GatedNotificationPlatform(this.inner, this.gate) {
    gate._attach(this);
  }

  final NotificationPlatform inner;
  final NotificationGate gate;

  /// Schedules [request] on the real platform (inexactly when exact alarms
  /// are not permitted); false when it could not be armed at all.
  Future<bool> _arm(NotificationRequest request, String payload, NotificationTiming timing) async {
    try {
      await inner.schedule(request, payload, timing: timing);
    } on ExactAlarmNotPermittedException {
      try {
        await inner.schedule(request, payload, timing: NotificationTiming.inexactWhileIdle);
      } catch (e) {
        NotificationGate._log('re-arming ${request.id} inexactly', e);
        return false;
      }
    } catch (e) {
      NotificationGate._log('re-arming ${request.id}', e);
      return false;
    }
    gate._innerPending[request.id] = payload;
    return true;
  }

  @override
  Future<void> schedule(NotificationRequest request, String payload, {required NotificationTiming timing}) =>
      gate._serial(() async {
        // A snooze still to come under this id moves to the center's own ids
        // first (the feature's request goes ahead regardless – after at
        // most moveWait, should the plugin not answer).
        try {
          await gate._moveSnoozeOff(request).timeout(NotificationGate.moveWait, onTimeout: () => false);
        } catch (e) {
          NotificationGate._log('keeping the snooze of ${request.id}', e);
        }
        var hold = false;
        try {
          gate._remember(request, payload, timing);
          gate._takeBackSnooze(request.id);
          gate._rebuilt.remove(request.id);
          final notice = CenterNotice.fromRequest(request);
          if (gate._holdOf(notice) != null) {
            gate._held[request.id] = HeldRequest(request: request, payload: payload, timing: timing, notice: notice);
            hold = true;
          } else {
            gate._held.remove(request.id);
          }
        } catch (e) {
          NotificationGate._log('deciding on ${request.id} (passed through)', e);
          gate._held.remove(request.id);
          hold = false;
        }
        if (hold) {
          try {
            // A real schedule replaces what the id has armed: take that out
            // (only if it is really pending – a cancel also clears the tray).
            if ((await inner.pending()).any((p) => p.id == request.id)) await inner.cancel(request.id);
            gate._innerPending.remove(request.id);
            return;
          } catch (e) {
            NotificationGate._log('holding ${request.id} (passed through)', e);
            gate._held.remove(request.id);
          }
        }
        await inner.schedule(request, payload, timing: timing);
        gate._innerPending[request.id] = payload;
      });

  @override
  Future<void> show(NotificationRequest request, String payload) async {
    var silence = false;
    try {
      gate._remember(request, payload, request.timing);
      if (gate.holdImmediate) {
        final notice = CenterNotice.fromRequest(request);
        silence = gate.policy.mutes(gate._groupFor(notice), gate._now);
        if (silence && !gate._silenced.isClosed) gate._silenced.add(notice);
      }
    } catch (e) {
      NotificationGate._log('deciding on ${request.id} (passed through)', e);
      silence = false;
    }
    if (silence) return;
    await inner.show(request, payload);
  }

  @override
  Future<void> cancel(int id) => gate._serial(() async {
    try {
      gate._featureCancelled(id);
    } catch (e) {
      NotificationGate._log('recording the cancel of $id', e);
    }
    await inner.cancel(id);
  });

  @override
  Future<List<PendingNotice>> pending() => gate._serial(() async {
    final list = await inner.pending();
    try {
      return _report(list);
    } catch (e) {
      NotificationGate._log('listing pending notifications (passed through)', e);
      return list;
    }
  });

  List<PendingNotice> _report(List<PendingNotice> list) {
    gate._innerPending
      ..clear()
      ..addAll({for (final p in list) p.id: p.payload});
    gate._innerRead = true;
    final now = gate._now;
    final held = gate._held;
    held.removeWhere((_, h) => h.notice.at == null || !h.notice.at!.isAfter(now));
    gate._rebuilt.removeWhere((id) => !held.containsKey(id) && !gate._innerPending.containsKey(id));
    return [
      for (final p in list)
        if (!held.containsKey(p.id) && GateMarks.of(p.payload) != GateMarks.snooze) p,
      for (final h in held.values)
        PendingNotice(h.request.id, h.reported, title: h.request.title, body: h.request.body),
    ];
  }

  @override
  Future<Set<int>?> armedIds(Iterable<int> ids) => gate._serial(() async {
    final list = ids.toList();
    var held = <int>{};
    try {
      held = {
        for (final id in list)
          if (gate._held.containsKey(id)) id,
      };
    } catch (e) {
      NotificationGate._log('checking held alarms', e);
    }
    final armed = await inner.armedIds([
      for (final id in list)
        if (!held.contains(id)) id,
    ]);
    return armed == null ? null : {...armed, ...held};
  });

  @override
  Future<List<ActiveNotice>> activeNotices() async {
    final i = inner;
    if (i case final ActiveNotificationQuery query) return query.activeNotices();
    final now = gate._now;
    return [
      for (final id in await i.activeIds())
        // What the gate last saw under the id – unless that is a firing
        // still to come (the id was planned again since): a shown
        // notification is then known by its id only.
        if (gate._seen[id] case final seen? when !seen.request.at.isAfter(now))
          ActiveNotice(
            id,
            payload: seen.payload,
            title: seen.request.title,
            body: seen.request.body,
            channelId: seen.request.channelId,
          )
        else
          ActiveNotice(id),
    ];
  }

  /// A tap on a snooze moved to the center's own ids reaches its feature
  /// under the feature's id ([GateMarks.moved]) – the id its tap routing
  /// claims. Anything else passes unchanged.
  static RawNotificationTap _routed(RawNotificationTap raw) {
    try {
      final origin = GateMarks.originOf(raw.payload);
      if (origin == null) return raw;
      return RawNotificationTap(id: origin, actionId: raw.actionId, payload: raw.payload, fromLaunch: raw.fromLaunch);
    } catch (e) {
      NotificationGate._log('routing a tap', e);
      return raw;
    }
  }

  @override
  Future<void> initialize({required void Function(RawNotificationTap tap) onTap}) =>
      inner.initialize(onTap: (raw) => onTap(_routed(raw)));

  @override
  Future<RawNotificationTap?> launchTap() async {
    final raw = await inner.launchTap();
    return raw == null ? null : _routed(raw);
  }

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
