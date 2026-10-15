import 'package:flutter/foundation.dart';

import 'notification_models.dart';
import 'notification_platform.dart';

/// A scheduled notification as [FakeNotificationPlatform] recorded it.
@immutable
class FakeScheduled {
  const FakeScheduled(this.request, this.payload, this.timing);

  final NotificationRequest request;
  final String payload;
  final NotificationTiming timing;
}

/// In-memory [NotificationPlatform] for tests of any feature: records
/// channels, scheduled / shown / cancelled notifications, and lets a test
/// deny exact alarms, fire a tap or simulate a launch notification.
class FakeNotificationPlatform implements NotificationPlatform, ActiveNotificationQuery {
  FakeNotificationPlatform({this.exactAllowed = true, this.enabled = true, this.fullScreenAllowed = true, this.launch});

  bool exactAllowed;
  bool enabled;
  bool fullScreenAllowed;

  /// The notification that "launched" the app (see [launchTap]).
  RawNotificationTap? launch;

  final Map<String, NotificationChannelSpec> channels = {};
  final Map<String, String> groups = {};
  final Map<int, FakeScheduled> scheduled = {};
  final Map<int, FakeScheduled> shown = {};
  final List<int> cancelled = [];
  final List<String> deletedChannels = [];

  /// Every schedule call, in order (re-schedules included).
  final List<FakeScheduled> scheduleLog = [];
  int requestNotificationsCalls = 0;
  int requestExactCalls = 0;
  int requestFullScreenCalls = 0;
  void Function(RawNotificationTap tap)? _onTap;
  bool initialized = false;

  /// Delivers a tap as if the user touched a notification.
  void tap(RawNotificationTap tap) => _onTap?.call(tap);

  @override
  Future<void> initialize({required void Function(RawNotificationTap tap) onTap}) async {
    _onTap = onTap;
    initialized = true;
  }

  @override
  Future<RawNotificationTap?> launchTap() async => launch;

  @override
  Future<void> createChannelGroup(String id, String name) async => groups[id] = name;

  @override
  Future<void> createChannel(NotificationChannelSpec spec) async {
    final existing = channels[spec.id];
    // Like Android: sound / vibration / usage are frozen at creation; only
    // the name and description change later.
    channels[spec.id] = existing == null
        ? spec
        : NotificationChannelSpec(
            id: existing.id,
            name: spec.name,
            description: spec.description,
            importance: existing.importance,
            sound: existing.sound,
            vibrate: existing.vibrate,
            vibrationPattern: existing.vibrationPattern,
            usage: existing.usage,
            showBadge: existing.showBadge,
            groupId: existing.groupId,
          );
  }

  @override
  Future<void> deleteChannel(String id) async {
    channels.remove(id);
    deletedChannels.add(id);
  }

  @override
  Future<List<String>> channelIds() async => channels.keys.toList();

  @override
  Future<void> schedule(NotificationRequest request, String payload, {required NotificationTiming timing}) async {
    if (timing != NotificationTiming.inexactWhileIdle && !exactAllowed) {
      throw const ExactAlarmNotPermittedException();
    }
    final s = FakeScheduled(request, payload, timing);
    scheduled[request.id] = s;
    unarmed.remove(request.id);
    scheduleLog.add(s);
  }

  @override
  Future<void> show(NotificationRequest request, String payload) async {
    shown[request.id] = FakeScheduled(request, payload, request.timing);
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    unarmed.remove(id);
    shown.remove(id);
    cancelled.add(id);
  }

  /// Moves every scheduled notification due at or before [now] to [shown]
  /// (as the alarm would).
  void fireDue(DateTime now) {
    final due = scheduled.values.where((s) => !s.request.at.isAfter(now)).toList();
    for (final s in due) {
      scheduled.remove(s.request.id);
      shown[s.request.id] = s;
    }
  }

  @override
  Future<List<PendingNotice>> pending() async => [
    for (final s in scheduled.values)
      PendingNotice(s.request.id, s.payload, title: s.request.title, body: s.request.body),
  ];

  /// Ids whose alarm the "system" no longer holds although they are still
  /// listed as pending (see [dropArmedAlarms]).
  final Set<int> unarmed = {};

  /// Whether [armedIds] answers (false: like a platform that cannot tell).
  bool reportsArmed = true;

  /// Simulates a force stop / OEM task killer: every alarm is gone from the
  /// system while the plugin's cache (what [pending] reports) keeps them.
  void dropArmedAlarms() => unarmed.addAll(scheduled.keys);

  @override
  Future<Set<int>?> armedIds(Iterable<int> ids) async {
    if (!reportsArmed) return null;
    return {
      for (final id in ids)
        if (scheduled.containsKey(id) && !unarmed.contains(id)) id,
    };
  }

  @override
  Future<List<int>> activeIds() async => shown.keys.toList();

  @override
  Future<List<ActiveNotice>> activeNotices() async => [
    for (final s in shown.values)
      ActiveNotice(
        s.request.id,
        payload: s.payload,
        title: s.request.title,
        body: s.request.body,
        channelId: s.request.channelId,
      ),
  ];

  @override
  Future<bool> notificationsEnabled() async => enabled;

  /// Runs while the notification permission is being asked (e.g. a test
  /// advancing its clock as a person reads the system dialog).
  void Function()? onRequestNotifications;

  @override
  Future<bool> requestNotifications() async {
    requestNotificationsCalls++;
    onRequestNotifications?.call();
    return enabled;
  }

  @override
  Future<bool> canScheduleExact() async => exactAllowed;

  @override
  Future<bool> requestExactAlarms() async {
    requestExactCalls++;
    return exactAllowed;
  }

  @override
  Future<bool> requestFullScreenIntent() async {
    requestFullScreenCalls++;
    return fullScreenAllowed;
  }
}
