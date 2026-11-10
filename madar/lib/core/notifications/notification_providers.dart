import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'flutter_local_notifications_platform.dart';
import 'notification_platform.dart';
import 'notification_service.dart';

/// The platform notifications plugin (flutter_local_notifications on
/// Android). Tests override it with `FakeNotificationPlatform`.
final notificationPlatformProvider = Provider<NotificationPlatform>((ref) => FlutterLocalNotificationsPlatform());

/// The app-wide [NotificationService]. Call `init()` once at bootstrap (it
/// is also awaited lazily by every method).
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(ref.watch(notificationPlatformProvider));
  ref.onDispose(service.dispose);
  return service;
});
