import 'notification_models.dart';

/// A tap as the platform reports it (payload still encoded).
class RawNotificationTap {
  const RawNotificationTap({this.id, this.actionId, this.payload, this.fromLaunch = false});

  final int? id;
  final String? actionId;
  final String? payload;
  final bool fromLaunch;
}

/// The small slice of a local-notifications plugin Madar needs. The
/// production implementation wraps flutter_local_notifications
/// ([FlutterLocalNotificationsPlatform]); tests use
/// `FakeNotificationPlatform`.
abstract interface class NotificationPlatform {
  /// Initialises the plugin; [onTap] receives taps while the app runs
  /// (notification body or an action that opens the app).
  Future<void> initialize({required void Function(RawNotificationTap tap) onTap});

  /// The notification that launched the app (cold start), if any.
  Future<RawNotificationTap?> launchTap();

  Future<void> createChannelGroup(String id, String name);
  Future<void> createChannel(NotificationChannelSpec spec);
  Future<void> deleteChannel(String id);

  /// Ids of every channel the app has created.
  Future<List<String>> channelIds();

  /// Schedules [request] with [payload] at `request.at` using [timing].
  /// Throws [ExactAlarmNotPermittedException] when an exact timing is not
  /// permitted.
  Future<void> schedule(NotificationRequest request, String payload, {required NotificationTiming timing});

  /// Shows [request] immediately.
  Future<void> show(NotificationRequest request, String payload);

  /// Cancels a pending or shown notification (stops its sound).
  Future<void> cancel(int id);

  /// The notifications the plugin believes are scheduled. On Android this is
  /// the plugin's own cache, not the system's alarm list – see [armedIds].
  Future<List<PendingNotice>> pending();

  /// Which of [ids] still have an alarm armed with the system, or null when
  /// the platform cannot tell (tests, other platforms).
  ///
  /// [pending] can list alarms that no longer exist: a force stop (by the
  /// user, or by an OEM battery manager / task killer) or a revoked
  /// exact-alarm permission wipes the app's alarms and pending intents but
  /// not the plugin's cache, so a reconcile by payload alone would never
  /// re-arm them.
  Future<Set<int>?> armedIds(Iterable<int> ids);

  /// Ids of the notifications currently shown.
  Future<List<int>> activeIds();

  Future<bool> notificationsEnabled();
  Future<bool> requestNotifications();
  Future<bool> canScheduleExact();
  Future<bool> requestExactAlarms();

  /// Opens the system page for full-screen intents (Android 14+) when not
  /// granted; returns whether it is granted afterwards.
  Future<bool> requestFullScreenIntent();
}

/// Optional, read-only capability of a [NotificationPlatform]: the shown
/// notifications with their content (not just [NotificationPlatform.activeIds]).
/// A platform that cannot tell simply does not implement it;
/// `NotificationService.activeNotices` then falls back to the ids.
abstract interface class ActiveNotificationQuery {
  Future<List<ActiveNotice>> activeNotices();
}
