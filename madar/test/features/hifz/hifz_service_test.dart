import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_catalog.dart';
import 'package:madar/features/hifz/hifz.dart';
import 'package:madar/features/home/home_providers.dart';

import '../../helpers/test_app.dart';
import '../wird/fake_quran_catalog.dart';
import '../wird/wird_harness.dart' show loadNawawi;

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late HifzService service;
  var now = DateTime(2026, 9, 28, 20, 15);
  final catalog = FakeQuranCatalog();

  setUp(() async {
    db = testDatabase(seed: false);
    await db.customSelect('SELECT 1').get();
    repos = Repositories(db);
    now = DateTime(2026, 9, 28, 20, 15);
    service = HifzService(repos, clock: () => now);
  });

  tearDown(() => db.close());

  test('an ayah range is added in even chunks; chunks already there are skipped; undo', () async {
    final (added, undo) = await service.addAyahRange(
      const AyahRange(AyahRef(67, 1), AyahRef(67, 13)),
      ayahCount: catalog.ayahCount,
      chunkSize: 5,
    );
    expect(added.map((c) => c.range), const [
      AyahRange(AyahRef(67, 1), AyahRef(67, 5)),
      AyahRange(AyahRef(67, 6), AyahRef(67, 9)),
      AyahRange(AyahRef(67, 10), AyahRef(67, 13)),
    ]);
    expect(added.every((c) => c.isNew && c.kind == HifzKind.ayat), isTrue);
    final (again, _) = await service.addAyahRange(
      const AyahRange(AyahRef(67, 1), AyahRef(67, 13)),
      ayahCount: catalog.ayahCount,
      chunkSize: 5,
    );
    expect(again, isEmpty);
    await undo();
    expect(await service.cards(), isEmpty);
  });

  test('a hadith is added once, pointing at the collection', () async {
    final nawawi = loadNawawi();
    final first = await service.addHadith(nawawi, nawawi.entries[15]);
    expect(first!.$1.source, 'nawawi40:16');
    expect(first.$1.body, contains('لَا تَغْضَبْ'));
    expect(await service.addHadith(nawawi, nawawi.entries[15]), isNull);
    final (custom, _) = await service.addCustom(title: '  دعاء  ', body: ' نص ', source: '');
    expect([custom.title, custom.body, custom.source], ['دعاء', 'نص', null]);
  });

  test('grading writes the schedule and a review row; undo restores both', () async {
    final (added, _) = await service.addAyahRange(
      const AyahRange(AyahRef(112, 1), AyahRef(112, 4)),
      ayahCount: catalog.ayahCount,
    );
    final session = HifzSession(added);
    final outcome = session.grade(4, now);
    final undo = await service.applyGrade(outcome);
    var card = (await service.cards()).single;
    expect(card.due, DateTime(2026, 9, 29));
    expect(card.sm2.repetitions, 1);
    expect(card.sm2.intervalDays, 1);
    expect(card.lastReviewedAt, now);
    final review = (await repos.hifzReviews.getAll()).single;
    expect([review.grade, review.intervalBefore, review.intervalAfter, review.easeAfter], [4, 0, 1, 2.5]);
    await undo();
    card = (await service.cards()).single;
    expect(card.isNew, isTrue);
    expect(await repos.hifzReviews.getAll(), isEmpty);
  });

  test('suspend, start over and delete (with its reviews) all undo exactly', () async {
    final (added, _) = await service.addAyahRange(
      const AyahRange(AyahRef(112, 1), AyahRef(112, 4)),
      ayahCount: catalog.ayahCount,
    );
    await service.applyGrade(HifzSession(added).grade(5, now));
    var card = (await service.cards()).single;
    final undoSuspend = await service.setSuspended(card, true);
    expect((await service.cards()).single.suspended, isTrue);
    await undoSuspend();
    expect((await service.cards()).single.suspended, isFalse);
    final undoReset = await service.resetProgress(card);
    expect((await service.cards()).single.isNew, isTrue);
    await undoReset();
    card = (await service.cards()).single;
    expect(card.due, DateTime(2026, 9, 29));
    final undoDelete = await service.delete(card);
    expect(await service.cards(), isEmpty);
    expect(await repos.hifzReviews.getAll(), isEmpty);
    await undoDelete();
    expect((await service.cards()).single.id, card.id);
    expect((await repos.hifzReviews.getAll()).length, 1);
  });

  test('editing a range or a custom text keeps the schedule', () async {
    final (added, _) = await service.addAyahRange(
      const AyahRange(AyahRef(67, 1), AyahRef(67, 5)),
      ayahCount: catalog.ayahCount,
    );
    await service.applyGrade(HifzSession(added).grade(5, now));
    final card = (await service.cards()).single;
    final undo = await service.edit(card, range: const AyahRange(AyahRef(67, 1), AyahRef(67, 4)));
    final edited = (await service.cards()).single;
    expect(edited.range, const AyahRange(AyahRef(67, 1), AyahRef(67, 4)));
    expect(edited.due, card.due);
    await undo();
    expect((await service.cards()).single.ayahTo, 5);
  });

  test('a finished session is logged once as quran.hifz; an empty one is not', () async {
    await service.recordSession('s0', const HifzSessionSummary());
    expect(await repos.activity.since(DateTime(2026, 9, 28), kind: HifzActivity.kind), isEmpty);
    await service.recordSession('s1', const HifzSessionSummary(reviewed: 4, learnedNew: 1, recalled: 0.75));
    final a = (await repos.activity.since(DateTime(2026, 9, 28), kind: HifzActivity.kind)).single;
    expect([a.planetKey, a.value, a.refId, a.payload['new']], ['faith', 4.0, 's1', 1]);
  });

  test('settings round-trip and clamp', () async {
    expect(await service.settings(), const HifzSettings());
    final undo = await service.saveSettings(const HifzSettings(newPerDay: 5, listenRepeat: 7, chunkSize: 3));
    expect((await service.settings()).newPerDay, 5);
    await undo();
    expect(await service.settings(), const HifzSettings());
    expect(HifzSettings.fromJson({'newPerDay': 999, 'listenRepeat': 0}), const HifzSettings());
  });

  test('the import provider adds a range from the reader with the chunk size setting', () async {
    await service.saveSettings(const HifzSettings(chunkSize: 3));
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        quranCatalogProvider.overrideWithValue(catalog),
        homeClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    final result = await container
        .read(hifzImportProvider)
        .addAyahRangeToHifz(const AyahRange(AyahRef(113, 4), AyahRef(114, 3)));
    expect(result.added.map((c) => c.range), const [
      AyahRange(AyahRef(113, 4), AyahRef(113, 5)),
      AyahRange(AyahRef(114, 1), AyahRef(114, 3)),
    ]);
    await result.undo();
    expect(await service.cards(), isEmpty);
  });
}
