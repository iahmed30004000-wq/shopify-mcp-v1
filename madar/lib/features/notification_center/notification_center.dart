/// The notification center: every notification Madar schedules or has
/// delivered, grouped by feature, with the notifications' own buttons,
/// snooze / skip / mute, and each group's reminder settings.
///
/// Wiring (for the app shell):
///
/// * Route the gate into the platform so mutes, skips and snoozes are
///   enforced: `notificationPlatformProvider.overrideWith((ref) =>
///   gatedNotificationPlatform(ref, realPlatform))`.
/// * Watch [notificationCenterProvider] from the app's services (below the
///   database gate) so arrivals, taps and answers are recorded while the
///   center is closed.
/// * Override [notificationCenterLinksProvider] with the router (open an
///   item) and each group's settings.
/// * Route [NotificationCenterScreen]; put [NotificationBell] in an app bar
///   or on the home panel; embed [NotificationSettingsSummary] in Settings.
library;

export 'data/center_controller.dart';
export 'data/center_hooks.dart';
export 'data/center_providers.dart';
export 'data/center_store.dart' show NotificationCenterStore, WatchedNotice;
export 'data/group_settings.dart';
export 'data/notification_gate.dart';
export 'domain/builtin_describers.dart';
export 'domain/center_layout.dart';
export 'domain/center_models.dart';
export 'domain/center_policy.dart';
export 'domain/center_texts.dart';
export 'domain/describers.dart';
export 'domain/notification_history.dart';
export 'presentation/center_actions.dart';
export 'presentation/center_visuals.dart';
export 'presentation/notification_center_screen.dart';
export 'presentation/widgets/group_section.dart';
export 'presentation/widgets/notification_bell.dart';
export 'presentation/widgets/notification_row.dart';
export 'presentation/widgets/notification_settings_summary.dart';
