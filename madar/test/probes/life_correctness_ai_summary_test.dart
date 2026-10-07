// Probe (Life coverage of the AI summary, plan §8 / C18 / C22): the
// summary the user hands to an AI must describe the Life worlds the way the
// app shows them –
// * a person's relation in the summary's language («فاطمة (أمي)», never the
//   stored key "mother");
// * today's Top 3 as Work counts it: a card placed in a prayer window is ONE
//   focus item (Work shows it once and its window task is that same card),
//   so it must be listed once, not twice.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/data/data/data_repository.dart';
import 'package:madar/features/data/domain/ai_summary.dart';
import 'package:madar/features/data/domain/ai_summary_builder.dart';
import 'package:madar/features/work/work.dart';

import '../helpers/test_app.dart';

void main() {
  final now = DateTime(2026, 9, 27, 13, 10);
  late MadarDatabase db;
  late Repositories repos;

  setUp(() async {
    db = testDatabase();
    await db.customSelect('SELECT 1').get();
    repos = Repositories(db);
  });
  tearDown(() => db.close());

  Future<String> section(SummarySectionId id, String lang) async {
    final input = await DataExportRepository(db, useIsolate: false).loadSummaryInput(now);
    final l = lookupL10n(Locale(lang));
    final summary = AiSummaryBuilder(l, languageCode: lang).build(input);
    return summary.sections.firstWhere((s) => s.id == id).body;
  }

  test('a relation is written in the summary language', () async {
    await repos.people.insert(
      PeopleCompanion.insert(name: 'فاطمة', relation: const Value('mother'), rhythmDays: const Value(7)),
    );
    final ar = await section(SummarySectionId.family, 'ar');
    expect(ar, isNot(contains('mother')), reason: 'raw relation key in the Arabic summary:\n$ar');
    expect(ar, contains('أمي'));
  });

  test("a Top 3 card placed in a prayer window is listed once", () async {
    final work = WorkService(repos, clock: () => now);
    final board = await work.createBoard(name: 'Shop');
    await work.addCard(
      board.id,
      CardDraft(title: 'Call the supplier', window: PrayerWindow.asr, windowDay: now, isTop3: true),
    );
    final state = await work.top3State();
    expect(state.items, hasLength(1), reason: 'Work counts one focus item');
    final en = await section(SummarySectionId.work, 'en');
    expect(
      RegExp('Call the supplier').allMatches(en).length,
      1,
      reason: 'the same focus item appears more than once in the Top 3:\n$en',
    );
  });

  test("a board's default columns are named in the summary language", () async {
    final work = WorkService(repos, clock: () => now);
    final board = await work.createBoard(name: 'المحل');
    await work.addCard(board.id, const CardDraft(title: 'اتصل بالمورد'));
    final ar = await section(SummarySectionId.work, 'ar');
    expect(ar, isNot(contains('To-do')), reason: 'English default column names in the Arabic summary:\n$ar');
  });
}
