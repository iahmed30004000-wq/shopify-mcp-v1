/// Family & friends: people, their contact rhythm, one-tap "contacted",
/// the gentle daily reach-out digest and birthday reminders.
///
/// Screens: [FamilyScreen], [PersonScreen]; sheets: [showPersonSheet] /
/// [PersonSheet], [showContactedSheet] / [ContactedSheet],
/// [showFamilySettingsSheet]; the compact [FamilyTodayCard] for the Family
/// planet page. Keep the notifications planned by watching
/// [familyReminderSyncProvider] once below the database gate; route taps
/// with [FamilyNotificationTaps].
library;

export 'data/contact_launcher.dart';
export 'data/family_notifications.dart';
export 'data/family_providers.dart';
export 'data/family_service.dart';
export 'domain/birthdays.dart';
export 'domain/contact_stats.dart';
export 'domain/family_models.dart';
export 'domain/family_reminders.dart';
export 'domain/rhythm.dart';
export 'family_texts.dart';
export 'presentation/contacted_sheet.dart';
export 'presentation/family_actions.dart';
export 'presentation/family_navigation.dart';
export 'presentation/family_screen.dart';
export 'presentation/family_settings_sheet.dart';
export 'presentation/family_today_card.dart';
export 'presentation/person_screen.dart';
export 'presentation/person_sheet.dart';
export 'presentation/widgets/family_widgets.dart';
export 'presentation/widgets/person_tile.dart';
