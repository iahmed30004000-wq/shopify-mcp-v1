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

/// His lines of one day, **without** the decisions: the chat re-reads a
/// line only when he sends one, not every time he files a card.
///
/// (`watchDay` carries the lines and the decisions together; a chat that
/// watched the whole day would re-run the reader on every tap.)
final dayChatLinesProvider = StreamProvider.autoDispose.family<List<DayChatLine>, DateTime>(
  (ref, day) => ref
      .watch(dayChatServiceProvider)
      .watchDay(day)
      .map((d) => d.lines)
      .distinct((a, b) => _sameLines(a, b)),
);

bool _sameLines(List<DayChatLine> a, List<DayChatLine> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id || a[i].text != b[i].text) return false;
  }
  return true;
}

/// Every line of one day, read into proposals again – so the chat is still
/// there after a restart, with the same piece ids (and therefore the same
/// decisions) as when he typed it.
///
/// The reading is deliberately **not** stored: a line is read again from
/// his own words, against his data as it is now, with the moment he sent it
/// as "now" so the result is the same every time.
final dayChatReadingsProvider = FutureProvider.autoDispose.family<List<DayChatReading>, DateTime>((ref, day) async {
  final lines = await ref.watch(dayChatLinesProvider(day).future);
  final service = ref.watch(dayChatServiceProvider);
  return [
    for (final line in lines) await service.read(line.text, now: line.at, day: day),
  ];
});
