// Life coverage of global search (Life plan §7 S1/S2, C22): what the
// Arabic search shows and matches for Life records must be Arabic –
// a person saved as «أمي» (relation key `mother`) is labelled «أمي» and is
// found by typing «أمي»; a card in a new board's first column is labelled
// with the column's Arabic name, not the stored English default "To-do".
//
// SKIPPED until the System phase: search is not routed yet, and C22
// assigns S1/S2 to the search package's integration (index
// FamilyTexts.relation and Work's localised default column names).
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/search/search.dart';
import 'package:madar/features/work/work.dart';

const _systemPhase = 'System phase (C22): search is not routed yet; fix S1/S2 in the search integration';

void main() {
  late MadarDatabase db;
  late Repositories repos;

  setUp(() async {
    await initializeDateFormatting('ar');
    db = MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    repos = Repositories(db);
  });
  tearDown(() => db.close());

  Future<List<SearchDoc>> docs(String source) async {
    final ctx = SearchLoadContext(
      repos: repos,
      l10n: lookupL10n(const Locale('ar')),
      formatter: const MadarFormatter(),
      surahName: (_) => null,
    );
    final s = BuiltInSearchSources.all().firstWhere((s) => s.id == source);
    return s.load(ctx);
  }

  test('a person is labelled with the Arabic relation', () async {
    await repos.people.insert(PeopleCompanion.insert(name: 'فاطمة', relation: const Value('mother')));
    final person = (await docs('people')).single;
    expect(person.subtitle, isNot('mother'), reason: 'raw relation key shown and indexed in Arabic search');
    expect(person.subtitle, contains('أمي'));
  }, skip: _systemPhase);

  test("a card's column is named in Arabic", () async {
    final work = WorkService(repos, clock: () => DateTime(2026, 9, 27, 13));
    final board = await work.createBoard(name: 'المحل');
    await work.addCard(board.id, const CardDraft(title: 'اتصل بالمورد'));
    final card = (await docs('board_cards')).single;
    expect(card.subtitle, isNot(contains('To-do')), reason: 'English default column name: ${card.subtitle}');
  }, skip: _systemPhase);
}
