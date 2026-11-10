/// «تذكير الصيام» / «صيامي» (Part 9b): the voluntary fasts - Monday and
/// Thursday, the white days, Arafah, Tasu'a and Ashura, the first of Dhu
/// al-Hijjah, the six of Shawwal and a gentle Muharram / Sha'ban nudge -
/// reminded **the night before, after Isha**, with «ناوي» and «لأ» answered
/// straight from the shade (even with Madar closed), a log of the days he
/// fasted, and the Hijri day shift (the prayer settings' own) that moves
/// every rule.
///
/// The rules and the planner are pure (`domain/`, 66 tests); the rest wires
/// them into the app. It owns notification ids 200000-200999
/// ([NotificationNamespaces.fasting]) and three `key_values` rows
/// (`fastingReminders.*`) - no schema change.
library;

export 'application/fasting_providers.dart';
export 'data/fasting_background.dart';
export 'data/fasting_describer.dart';
export 'data/fasting_notifications.dart';
export 'data/fasting_repository.dart';
export 'data/fasting_texts.dart';
export 'domain/fasting_log.dart';
export 'domain/fasting_models.dart';
export 'domain/fasting_overview.dart';
export 'domain/fasting_planner.dart';
export 'domain/fasting_rules.dart';
export 'presentation/fasting_screen.dart';
