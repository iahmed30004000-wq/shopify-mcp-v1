/// «رمضان» (Part 19), inside the Faith planet: the month turns itself on at
/// the first day and off at the Eid (the calendar plus the prayer settings'
/// Hijri day shift), with a restrained atmosphere on the Faith planet, a
/// countdown to iftar and suhoor from the prayer schedule, a Taraweeh log, a
/// khatmah plan that re-plans after missed days and never exceeds the ceiling
/// he sets, the last ten nights with a supplication slot he fills himself, and
/// this year's log beside last year's.
///
/// The engine is pure (`domain/`); the rest wires it into the app. It owns
/// notification ids 210000-210999 ([NotificationNamespaces.ramadan]) and five
/// `key_values` rows (`ramadan.*`) - no schema change, in backups, and a
/// restore re-arms the reminders.
library;

export 'application/ramadan_providers.dart';
export 'data/ramadan_background.dart';
export 'data/ramadan_describer.dart';
export 'data/ramadan_notifications.dart';
export 'data/ramadan_repository.dart';
export 'data/ramadan_texts.dart';
export 'domain/fast_countdown.dart';
export 'domain/khatmah_plan.dart';
export 'domain/khatmah_record.dart';
export 'domain/last_ten_nights.dart';
export 'domain/prayer_times_of.dart';
export 'domain/qadr_supplication.dart';
export 'domain/ramadan_calendar.dart';
export 'domain/ramadan_config.dart';
export 'domain/ramadan_notification_ids.dart';
export 'domain/ramadan_planner.dart';
export 'domain/ramadan_today.dart';
export 'domain/ramadan_year_log.dart';
export 'domain/taraweeh_log.dart';
export 'presentation/ramadan_atmosphere.dart';
export 'presentation/ramadan_hub_card.dart';
export 'presentation/ramadan_screen.dart';
