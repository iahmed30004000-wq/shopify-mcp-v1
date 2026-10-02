import 'dart:async';

import 'package:flutter/foundation.dart';

import 'notification_envelope.dart';
import 'notification_models.dart';
import 'notification_platform.dart';

/// Madar's local-notification service, shared by every feature (adhan,
/// adhkar reminders, medications…).
///
/// * **Namespaces** – each feature owns a block of ids
///   ([NotificationNamespaces]) and reconciles only that block.
/// * **[sync]** – declarative scheduling: hand it the complete list of
///   notifications a feature wants pending; it cancels what is no longer
///   wanted, leaves identical ones untouched (no alarm churn) and
///   (re)schedules the rest. Safe to call as often as you like.
/// * **Exact alarms** – when exact timing is not permitted the request is
///   scheduled inexactly instead of failing, and the report says so.
/// * **Taps** – [taps] streams taps while the app runs; [takeLaunchTap]
///   returns the notification that cold-started the app (once).
class NotificationService {
  NotificationService(this.platform, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final NotificationPlatform platform;
  final DateTime Function() _clock;

  final _taps = StreamController<NotificationTap>.broadcast();
  Future<void>? _init;
  NotificationTap? _launchTap;
  bool _launchTaken = false;

  /// Taps on notifications (and action buttons that open the app) while the
  /// app is running.
  Stream<NotificationTap> get taps => _taps.stream;

  /// Initialises the plugin and reads the launch notification. Idempotent;
  /// every other method awaits it.
  Future<void> init() => _init ??= _doInit();

  Future<void> _doInit() async {
    try {
      await platform.initialize(onTap: (raw) => _taps.add(_decode(raw)));
      final launch = await platform.launchTap();
      if (launch != null) _launchTap = _decode(launch);
    } catch (e, s) {
      debugPrint('NotificationService.init failed: $e\n$s');
    }
  }

  static NotificationTap _decode(RawNotificationTap raw) =>
      NotificationEnvelope.decode(raw.payload, id: raw.id, actionId: raw.actionId, fromLaunch: raw.fromLaunch);

  /// The notification that launched the app, returned only once (so a hot
  /// restart of the UI never replays it).
  ///
  /// With [where], it is only returned (and taken) when it matches – each
  /// feature claims its own launch notification (the adhan hub its adhans,
  /// the app shell the adhkar reminders …) without swallowing the others'.
  Future<NotificationTap?> takeLaunchTap({bool Function(NotificationTap tap)? where}) async {
    await init();
    final tap = _launchTap;
    if (_launchTaken || tap == null) return null;
    if (where != null && !where(tap)) return null;
    _launchTaken = true;
    return tap;
  }

  // ---------------------------------------------------------------------------
  // Channels

  Future<void> ensureChannelGroup(String id, String name) async {
    await init();
    await platform.createChannelGroup(id, name);
  }

  /// Creates (or renames) [specs]. With [prunePrefix], every existing channel
  /// whose id starts with it and is not in [specs] is deleted – a changed
  /// sound gets a new channel id and the old channel disappears from system
  /// settings.
  Future<void> ensureChannels(List<NotificationChannelSpec> specs, {String? prunePrefix}) async {
    await init();
    for (final spec in specs) {
      await platform.createChannel(spec);
    }
    if (prunePrefix != null) {
      final keep = {for (final s in specs) s.id};
      for (final id in await platform.channelIds()) {
        if (id.startsWith(prunePrefix) && !keep.contains(id)) await platform.deleteChannel(id);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Scheduling

  /// Makes the pending notifications of [namespace] exactly [desired]:
  /// cancels pending ids that are not wanted (or are wanted for a moment
  /// already past), skips identical ones and schedules new / changed ones.
  /// Requests outside [namespace] or with duplicate ids are rejected with an
  /// [ArgumentError] – they would silently overwrite each other. Pending ids
  /// for which [keep] is true are left alone (one-off notifications such as
  /// a snooze, scheduled outside the declarative plan).
  Future<NotificationSyncReport> sync(
    NotificationNamespace namespace,
    List<NotificationRequest> desired, {
    bool Function(int id)? keep,
  }) async {
    await init();
    final wanted = <int, NotificationRequest>{};
    for (final r in desired) {
      if (!namespace.contains(r.id) || r.namespace != namespace) {
        throw ArgumentError.value(r.id, 'desired', 'id outside ${namespace.name}');
      }
      if (wanted.containsKey(r.id)) throw ArgumentError.value(r.id, 'desired', 'duplicate notification id');
      wanted[r.id] = r;
    }
    final now = _clock();
    final pending = {
      for (final p in await platform.pending())
        if (namespace.contains(p.id) && (keep == null || wanted.containsKey(p.id) || !keep(p.id))) p.id: p.payload,
    };

    var scheduled = 0, unchanged = 0, cancelled = 0, past = 0, inexact = 0, failed = 0;
    for (final id in pending.keys) {
      final r = wanted[id];
      if (r == null || !r.at.isAfter(now)) {
        await platform.cancel(id);
        cancelled++;
      }
    }
    final ordered = wanted.values.toList()..sort((a, b) => a.at.compareTo(b.at));
    final payloads = {for (final r in ordered) r.id: NotificationEnvelope.encode(r)};
    // The plugin's pending list is its own cache: make sure what it calls
    // unchanged is still armed with the system (a force stop or an OEM task
    // killer wipes alarms, not the cache).
    final same = [
      for (final r in ordered)
        if (r.at.isAfter(now) && pending[r.id] == payloads[r.id]) r.id,
    ];
    Set<int>? armed;
    if (same.isNotEmpty) {
      try {
        armed = await platform.armedIds(same);
      } catch (e) {
        debugPrint('NotificationService: armed-alarm check failed: $e');
      }
    }
    var rearmed = 0;
    for (final r in ordered) {
      if (!r.at.isAfter(now)) {
        past++;
        continue;
      }
      final payload = payloads[r.id]!;
      if (pending[r.id] == payload) {
        if (armed == null || armed.contains(r.id)) {
          unchanged++;
          continue;
        }
        rearmed++;
      }
      switch (await _schedule(r, payload)) {
        case _Scheduled.exact:
          scheduled++;
        case _Scheduled.inexact:
          scheduled++;
          inexact++;
        case _Scheduled.failed:
          failed++;
      }
    }
    if (rearmed > 0) {
      debugPrint('NotificationService: re-armed $rearmed ${namespace.name} alarm(s) the system had dropped');
    }
    return NotificationSyncReport(
      scheduled: scheduled,
      unchanged: unchanged,
      cancelled: cancelled,
      skippedPast: past,
      inexactFallback: inexact,
      failed: failed,
      rearmed: rearmed,
    );
  }

  /// Schedules one notification (replacing any pending one with its id).
  /// Returns false if it could not be scheduled at all.
  Future<bool> schedule(NotificationRequest request) async {
    await init();
    if (!request.at.isAfter(_clock())) return false;
    return await _schedule(request, NotificationEnvelope.encode(request)) != _Scheduled.failed;
  }

  Future<_Scheduled> _schedule(NotificationRequest r, String payload) async {
    try {
      await platform.schedule(r, payload, timing: r.timing);
      return _Scheduled.exact;
    } on ExactAlarmNotPermittedException {
      if (r.timing == NotificationTiming.inexactWhileIdle) return _Scheduled.failed;
      try {
        await platform.schedule(r, payload, timing: NotificationTiming.inexactWhileIdle);
        return _Scheduled.inexact;
      } catch (e) {
        debugPrint('NotificationService: inexact fallback failed for ${r.id}: $e');
        return _Scheduled.failed;
      }
    } catch (e) {
      debugPrint('NotificationService: scheduling ${r.id} failed: $e');
      return _Scheduled.failed;
    }
  }

  /// Shows [request] now (its [NotificationRequest.at] is ignored).
  Future<void> show(NotificationRequest request) async {
    await init();
    await platform.show(request, NotificationEnvelope.encode(request));
  }

  /// Cancels a pending or shown notification; a shown one stops sounding.
  Future<void> cancel(int id) async {
    await init();
    await platform.cancel(id);
  }

  /// Cancels every pending notification of [namespace].
  Future<int> cancelNamespace(NotificationNamespace namespace) async {
    final report = await sync(namespace, const []);
    return report.cancelled;
  }

  /// The pending notifications of [namespace], decoded, soonest first.
  Future<List<NotificationTap>> pendingIn(NotificationNamespace namespace) async {
    await init();
    final list = [
      for (final p in await platform.pending())
        if (namespace.contains(p.id)) NotificationEnvelope.decode(p.payload, id: p.id),
    ];
    list.sort((a, b) {
      final x = a.at, y = b.at;
      if (x == null || y == null) return (a.id ?? 0).compareTo(b.id ?? 0);
      return x.compareTo(y);
    });
    return list;
  }

  /// Every pending notification (all namespaces, with the title and body
  /// when the platform reports them) – a read-only view for the
  /// notification center. Soonest first by the envelope's instant.
  Future<List<PendingNotice>> pendingNotices() async {
    await init();
    final list = await platform.pending();
    int at(PendingNotice p) => NotificationEnvelope.decode(p.payload).at?.millisecondsSinceEpoch ?? 0;
    final keyed = [for (final p in list) (at(p), p)]
      ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.id.compareTo(b.$2.id));
    return [for (final k in keyed) k.$2];
  }

  /// The notifications currently shown, with their payloads when the
  /// platform can tell ([ActiveNotificationQuery]); otherwise only their ids.
  Future<List<ActiveNotice>> activeNotices() async {
    await init();
    final p = platform;
    if (p case final ActiveNotificationQuery query) return query.activeNotices();
    return [for (final id in await p.activeIds()) ActiveNotice(id)];
  }

  /// Whether notification [id] is currently shown.
  Future<bool> isShown(int id) async {
    await init();
    return (await platform.activeIds()).contains(id);
  }

  // ---------------------------------------------------------------------------
  // Permissions

  Future<bool> notificationsEnabled() async {
    await init();
    return platform.notificationsEnabled();
  }

  Future<bool> requestNotifications() async {
    await init();
    return platform.requestNotifications();
  }

  Future<bool> canScheduleExact() async {
    await init();
    return platform.canScheduleExact();
  }

  Future<bool> requestExactAlarms() async {
    await init();
    return platform.requestExactAlarms();
  }

  Future<bool> requestFullScreenIntent() async {
    await init();
    return platform.requestFullScreenIntent();
  }

  Future<void> dispose() => _taps.close();
}

enum _Scheduled { exact, inexact, failed }
