// Regression tests (from an adversarial probe): the Quran group of the
// global search for everyday queries (names, money) – matches must start a
// word and keep the alefs the user typed.
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/quran/domain/arabic_search.dart';
import 'package:madar/features/search/search.dart';

void main() {
  const ayat = [
    'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
    'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ',
    'وَقُلِ ٱعْمَلُوا۟ فَسَيَرَى ٱللَّهُ عَمَلَكُمْ وَرَسُولُهُۥ وَٱلْمُؤْمِنُونَ',
    'وَمُبَشِّرًۢا بِرَسُولٍ يَأْتِى مِنۢ بَعْدِى ٱسْمُهُۥٓ أَحْمَدُ',
    'ٱلْمَالُ وَٱلْبَنُونَ زِينَةُ ٱلْحَيَوٰةِ ٱلدُّنْيَا',
    'وَهُوَ ٱلْعَلِىُّ ٱلْعَظِيمُ',
    'إِنَّ ٱللَّهَ عَلَىٰ كُلِّ شَىْءٍ قَدِيرٌ',
    'وَعَلَّمَ ءَادَمَ ٱلْأَسْمَآءَ كُلَّهَا',
    'إِنَّمَا حَرَّمَ عَلَيْكُمُ ٱلْمَيْتَةَ وَٱلدَّمَ',
  ];
  final refs = [
    const AyahRef(1, 1),
    const AyahRef(1, 2),
    const AyahRef(9, 105),
    const AyahRef(61, 6),
    const AyahRef(18, 46),
    const AyahRef(2, 255),
    const AyahRef(2, 20),
    const AyahRef(2, 31),
    const AyahRef(2, 173),
  ];

  late MadarDatabase db;
  late SearchEngine engine;

  setUp(() async {
    db = MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final quran = QuranSearchSource.create(
      () async => (index: QuranSearchIndex(ayat, refs), ayahText: (int i) => ayat[i]),
    );
    engine = SearchEngine(
      db: db,
      registry: SearchRegistry([...BuiltInSearchSources.all(), quran]),
      workerFactory: () async => InlineSearchWorker(),
      clock: () => DateTime(2026, 9, 30, 12),
      debounce: const Duration(milliseconds: 20),
      context: () async => SearchLoadContext(
        repos: Repositories(db),
        l10n: lookupL10n(const Locale('ar')),
        formatter: MadarFormatter(languageCode: 'ar'),
      ),
    );
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  Future<List<String>> ayahHits(String q) async {
    final r = await engine.search(SearchRequest(q));
    return [for (final h in r.hits) if (h.doc.sourceId == 'quran') h.doc.refId];
  }

  test('the names «باسم» / «بسام» (Basem, Bassam) do not find «بِسْمِ ٱللَّهِ»', () async {
    expect(await ayahHits('باسم'), isEmpty);
    expect(await ayahHits('بسام'), isEmpty);
  });

  test('«أحمد» (Ahmad) finds 61:6 «أَحْمَدُ», not 1:2 «ٱلْحَمْدُ»', () async {
    expect(await ayahHits('أحمد'), ['61:6']);
  });

  test('«مال» (money) finds 18:46 «ٱلْمَالُ», not «ٱعْمَلُوا۟ … عَمَلَكُمْ» (9:105)', () async {
    expect(await ayahHits('مال'), ['18:46']);
  });

  test('«علي» (Ali) finds «ٱلْعَلِىُّ» first, then «عَلَيْكُمُ», never «عَلَىٰ» (on)', () async {
    final hits = await ayahHits('علي');
    expect(hits.first, '2:255');
    expect(hits, isNot(contains('2:20')));
  });

  test('«دم» (blood) finds «وَٱلدَّمَ», not «ءَادَمَ» (Adam)', () async {
    expect(await ayahHits('دم'), ['2:173']);
  });

  test('the article whose alef the mushaf drops: «الله» still finds «لِلَّهِ» (1:2)', () async {
    expect(await ayahHits('الله'), containsAll(['1:1', '1:2', '2:20']));
  });
}
