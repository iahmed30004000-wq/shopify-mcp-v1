import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_models.dart';
import 'notification_platform.dart';

/// Background isolate entry for notification actions that do not open the
/// app (e.g. the adhan's "Stop"): the plugin has already cancelled the
/// notification natively (which stops its sound) before this runs, so
/// there is nothing left to do here.
@pragma('vm:entry-point')
void madarNotificationBackgroundTap(NotificationResponse response) {}

/// [NotificationPlatform] on flutter_local_notifications 21 (Android).
///
/// * Scheduling uses `zonedSchedule` in UTC: an alarm is an instant, so
///   daylight-saving and time-zone changes never shift it (prayer times are
///   recomputed for the new zone by the feature's own re-sync).
/// * Channels are created explicitly so their frozen sound / vibration /
///   audio usage are exactly the [NotificationChannelSpec]'s.
/// * On other platforms (desktop tests) every call is a harmless no-op.
class FlutterLocalNotificationsPlatform implements NotificationPlatform {
  FlutterLocalNotificationsPlatform({
    FlutterLocalNotificationsPlugin? plugin,
    this.defaultIcon = 'ic_stat_madar',
    this.backgroundHandler = madarNotificationBackgroundTap,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Runs, in a background isolate, the action buttons that do not open the
  /// app (`NotificationActionSpec.opensApp == false`). Must be a top-level
  /// or static function annotated `@pragma('vm:entry-point')`; one per app
  /// (the plugin keeps a single callback), so an app whose features record
  /// answers in the background passes an entry point that dispatches to
  /// them (e.g. the medication tracker's `medsNotificationBackgroundTap`).
  final DidReceiveBackgroundNotificationResponseCallback backgroundHandler;

  /// Drawable resource of the status-bar icon
  /// (`android/app/src/main/res/drawable/ic_stat_madar.xml`).
  final String defaultIcon;

  final Map<String, NotificationChannelSpec> _channels = {};
  bool _ready = false;

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> initialize({required void Function(RawNotificationTap tap) onTap}) async {
    if (!_android || _ready) return;
    await _plugin.initialize(
      settings: InitializationSettings(android: AndroidInitializationSettings(defaultIcon)),
      onDidReceiveNotificationResponse: (r) => onTap(_raw(r, fromLaunch: false)),
      onDidReceiveBackgroundNotificationResponse: backgroundHandler,
    );
    _ready = true;
  }

  static RawNotificationTap _raw(NotificationResponse r, {required bool fromLaunch}) => RawNotificationTap(
    id: r.id,
    actionId: (r.actionId?.isEmpty ?? true) ? null : r.actionId,
    payload: r.payload,
    fromLaunch: fromLaunch,
  );

  @override
  Future<RawNotificationTap?> launchTap() async {
    if (!_android) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details == null || !details.didNotificationLaunchApp || response == null) return null;
    return _raw(response, fromLaunch: true);
  }

  @override
  Future<void> createChannelGroup(String id, String name) async {
    if (!_android) return;
    await _androidPlugin?.createNotificationChannelGroup(AndroidNotificationChannelGroup(id, name));
  }

  @override
  Future<void> createChannel(NotificationChannelSpec spec) async {
    _channels[spec.id] = spec;
    if (!_android) return;
    await _androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        spec.id,
        spec.name,
        description: spec.description,
        groupId: spec.groupId,
        importance: _importance(spec.importance),
        playSound: spec.sound.kind != NotificationSoundKind.silent,
        sound: _sound(spec.sound),
        enableVibration: spec.vibrate,
        vibrationPattern: spec.vibrate && spec.vibrationPattern != null
            ? Int64List.fromList(spec.vibrationPattern!)
            : null,
        showBadge: spec.showBadge,
        audioAttributesUsage: spec.usage == NotificationAudioUsage.alarm
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
      ),
    );
  }

  @override
  Future<void> deleteChannel(String id) async {
    _channels.remove(id);
    if (!_android) return;
    await _androidPlugin?.deleteNotificationChannel(channelId: id);
  }

  @override
  Future<List<String>> channelIds() async {
    if (!_android) return const [];
    final channels = await _androidPlugin?.getNotificationChannels();
    return [for (final c in channels ?? const <AndroidNotificationChannel>[]) c.id];
  }

  @override
  Future<void> schedule(NotificationRequest request, String payload, {required NotificationTiming timing}) async {
    if (!_android) return;
    try {
      await _plugin.zonedSchedule(
        id: request.id,
        scheduledDate: tz.TZDateTime.from(request.at.toUtc(), tz.UTC),
        notificationDetails: NotificationDetails(android: _details(request)),
        androidScheduleMode: switch (timing) {
          NotificationTiming.alarmClock => AndroidScheduleMode.alarmClock,
          NotificationTiming.exactWhileIdle => AndroidScheduleMode.exactAllowWhileIdle,
          NotificationTiming.inexactWhileIdle => AndroidScheduleMode.inexactAllowWhileIdle,
        },
        title: request.title,
        body: request.body,
        payload: payload,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') throw ExactAlarmNotPermittedException(e.message ?? e.code);
      rethrow;
    }
  }

  @override
  Future<void> show(NotificationRequest request, String payload) async {
    if (!_android) return;
    await _plugin.show(
      id: request.id,
      title: request.title,
      body: request.body,
      notificationDetails: NotificationDetails(android: _details(request)),
      payload: payload,
    );
  }

  AndroidNotificationDetails _details(NotificationRequest r) {
    final channel = _channels[r.channelId];
    final importance = channel?.importance ?? NotificationImportance.high;
    return AndroidNotificationDetails(
      r.channelId,
      channel?.name ?? r.channelId,
      channelDescription: channel?.description,
      importance: _importance(importance),
      priority: switch (importance) {
        NotificationImportance.urgent => Priority.max,
        NotificationImportance.high => Priority.high,
        NotificationImportance.normal => Priority.defaultPriority,
        NotificationImportance.low => Priority.low,
      },
      // Only used if the channel does not exist yet (it always should).
      playSound: channel == null || channel.sound.kind != NotificationSoundKind.silent,
      sound: channel == null ? null : _sound(channel.sound),
      enableVibration: channel?.vibrate ?? true,
      audioAttributesUsage: channel?.usage == NotificationAudioUsage.alarm
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
      styleInformation: BigTextStyleInformation(r.body),
      category: switch (r.category) {
        NotificationCategory.alarm => AndroidNotificationCategory.alarm,
        NotificationCategory.reminder => AndroidNotificationCategory.reminder,
        NotificationCategory.event => AndroidNotificationCategory.event,
        NotificationCategory.status => AndroidNotificationCategory.status,
      },
      fullScreenIntent: r.fullScreen,
      visibility: r.publicOnLockScreen ? NotificationVisibility.public : NotificationVisibility.private,
      timeoutAfter: r.timeout?.inMilliseconds,
      ongoing: r.ongoing,
      autoCancel: r.autoCancel,
      color: r.colorArgb == null ? null : Color(r.colorArgb!),
      subText: r.subText,
      ticker: r.title,
      actions: [
        for (final a in r.actions)
          AndroidNotificationAction(a.id, a.title, showsUserInterface: a.opensApp, cancelNotification: a.cancels),
      ],
    );
  }

  static Importance _importance(NotificationImportance i) => switch (i) {
    NotificationImportance.low => Importance.low,
    NotificationImportance.normal => Importance.defaultImportance,
    NotificationImportance.high => Importance.high,
    NotificationImportance.urgent => Importance.max,
  };

  static AndroidNotificationSound? _sound(NotificationSoundSpec s) => switch (s.kind) {
    NotificationSoundKind.raw => RawResourceAndroidNotificationSound(s.value),
    NotificationSoundKind.uri => UriAndroidNotificationSound(s.value!),
    NotificationSoundKind.systemDefault || NotificationSoundKind.silent => null,
  };

  @override
  Future<void> cancel(int id) async {
    if (!_android) return;
    await _plugin.cancel(id: id);
  }

  @override
  Future<List<PendingNotice>> pending() async {
    if (!_android) return const [];
    final list = await _plugin.pendingNotificationRequests();
    return [for (final p in list) PendingNotice(p.id, p.payload)];
  }

  /// Madar's own Android side (MainActivity.kt): whether the plugin's alarm
  /// pending intents still exist.
  static const alarmsChannel = MethodChannel('app.madar.orbit/alarms');

  /// Asks the system which alarms still exist: the plugin arms each one as
  /// a broadcast `PendingIntent` to its `ScheduledNotificationReceiver`
  /// (request code = id); a force stop cancels those with the alarms, so
  /// `FLAG_NO_CREATE` finds none. Null when the answer is unavailable.
  @override
  Future<Set<int>?> armedIds(Iterable<int> ids) async {
    if (!_android) return null;
    final list = ids.toList();
    if (list.isEmpty) return <int>{};
    try {
      final armed = await alarmsChannel.invokeListMethod<int>('armed', {'ids': list});
      return armed?.toSet();
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('FlutterLocalNotificationsPlatform.armedIds failed: ${e.message}');
      return null;
    }
  }

  @override
  Future<List<int>> activeIds() async {
    if (!_android) return const [];
    final list = await _plugin.getActiveNotifications();
    return [for (final a in list) ?a.id];
  }

  @override
  Future<bool> notificationsEnabled() async {
    if (!_android) return false;
    return await _androidPlugin?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestNotifications() async {
    if (!_android) return false;
    return await _androidPlugin?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> canScheduleExact() async {
    if (!_android) return false;
    return await _androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<bool> requestExactAlarms() async {
    if (!_android) return false;
    return await _androidPlugin?.requestExactAlarmsPermission() ?? false;
  }

  @override
  Future<bool> requestFullScreenIntent() async {
    if (!_android) return false;
    return await _androidPlugin?.requestFullScreenIntentPermission() ?? false;
  }
}
