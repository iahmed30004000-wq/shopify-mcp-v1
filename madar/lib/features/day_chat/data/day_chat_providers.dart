/// The daily chat's providers – what the chat screen reads.
///
/// Every write goes through the same services the screens use, taken from
/// their own providers, so a piece filed from the chat pulses the orbit and
/// records the activity exactly as the quick-add bar does.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../body/data/body_providers.dart';
import '../../custom_modules/data/custom_modules_providers.dart';
import '../../family/data/family_providers.dart';
import '../../health/wellbeing/data/wellbeing_providers.dart';
import '../../home/home_providers.dart';
import '../../money/ledger/data/ledger_providers.dart';
import '../../nutrition/data/nutrition_providers.dart';
import '../../prayer_tracker/data/tracker_providers.dart';
import '../domain/day_chat_journal.dart';
import '../domain/day_chat_piece.dart';
import '../domain/day_summary.dart';
import 'day_chat_service.dart';

/// The daily chat, end to end (read a line, apply one piece, undo it, and
/// «شو صار اليوم؟»).
final dayChatServiceProvider = Provider<DayChatService>(
  (ref) => DayChatService(
    ref.watch(repositoriesProvider),
    clock: () => ref.read(homeClockProvider)(),
    prayerDay: () => ref.read(prayerDayProvider),
    focusedWindow: () =>
        ref.read(homeWindowProvider) ?? ref.read(prayerDayProvider).windowAt(ref.read(homeClockProvider)()),
    defaultWalletName: () => lookupL10n(ref.read(appSettingsProvider).locale).homeDefaultWallet,
    ledger: () => ref.read(ledgerServiceProvider),
    nutrition: () => ref.read(nutritionServiceProvider),
    body: () => ref.read(bodyServiceProvider),
    wellbeing: () => ref.read(wellbeingServiceProvider),
    family: () => ref.read(familyServiceProvider),
    modules: () => ref.read(customModulesServiceProvider),
    prayers: () => ref.read(prayerTrackerRepositoryProvider),
    tasks: () => ref.read(homeTasksServiceProvider),
  ),
);

/// The prayer day the chat is on.
final dayChatTodayProvider = Provider<DateTime>((ref) => ref.watch(dayChatServiceProvider).today());

/// One day of the chat – his lines and what he decided about every piece –
/// live, so an apply or an undo shows the moment it is written.
final dayChatDayProvider = StreamProvider.autoDispose.family<DayChatDay, DateTime>(
  (ref, day) => ref.watch(dayChatServiceProvider).watchDay(day),
);

/// The days that have a chat, newest first.
final dayChatDaysProvider = StreamProvider.autoDispose<List<DateTime>>(
  (ref) => ref.watch(dayChatServiceProvider).watchDays(),
);

/// Reads one typed line into proposals. Nothing is written.
final dayChatReadingProvider = FutureProvider.autoDispose.family<DayChatReading, String>(
  (ref, text) => ref.watch(dayChatServiceProvider).read(text),
);

/// «شو صار اليوم؟» – from his own data, offline.
final dayChatSummaryProvider = FutureProvider.autoDispose.family<DaySummary, DateTime>(
  (ref, day) => ref.watch(dayChatServiceProvider).summary(day: day),
);
