// Seed data for the Hifz widget and screenshot tests.
import 'package:drift/drift.dart' show Value;
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';

import '../wird/wird_harness.dart' show faithTestNow;

DateTime _day(int offset) => DateTime(faithTestNow.year, faithTestNow.month, faithTestNow.day + offset);

/// Al-Mulk in six chunks (two due, one overdue, three learned), al-Ikhlas
/// (mature), three hadith of An-Nawawi's Forty (one due, two new), a custom
/// dua (new), one suspended item, and three weeks of review history.
Future<void> seedHifz(MadarDatabase db, {bool arabic = true}) async {
  final repos = Repositories(db);
  Future<String> item({
    HifzKind kind = HifzKind.ayat,
    int? surah,
    int? from,
    int? to,
    String? title,
    String? body,
    String? source,
    int? dueIn,
    int interval = 0,
    int reps = 0,
    double ease = 2.5,
    int lapses = 0,
    bool suspended = false,
  }) async {
    final row = await repos.hifzItems.insert(
      HifzItemsCompanion.insert(
        kind: Value(kind),
        surah: Value(surah),
        ayahFrom: Value(from),
        ayahTo: Value(to),
        title: Value(title),
        body: Value(body),
        source: Value(source),
        due: Value(dueIn == null ? null : _day(dueIn)),
        intervalDays: Value(interval),
        repetitions: Value(reps),
        easeFactor: Value(ease),
        lapses: Value(lapses),
        suspended: Value(suspended),
        lastReviewedAt: Value(dueIn == null ? null : _day(dueIn - interval).add(const Duration(hours: 20))),
      ),
    );
    return row.id;
  }

  final mulk1 = await item(surah: 67, from: 1, to: 5, dueIn: -2, interval: 6, reps: 2, ease: 2.36, lapses: 1);
  final mulk2 = await item(surah: 67, from: 6, to: 10, dueIn: 0, interval: 1, reps: 1, ease: 2.5);
  final mulk3 = await item(surah: 67, from: 11, to: 15, dueIn: 1, interval: 6, reps: 2, ease: 2.6);
  await item(surah: 67, from: 16, to: 20, dueIn: 4, interval: 6, reps: 2, ease: 2.5);
  await item(surah: 67, from: 21, to: 25, dueIn: 12, interval: 16, reps: 3, ease: 2.6);
  await item(surah: 67, from: 26, to: 30, dueIn: 3, interval: 6, reps: 2, ease: 2.22);
  final ikhlas = await item(surah: 112, from: 1, to: 4, dueIn: 30, interval: 42, reps: 4, ease: 2.8);
  await item(kind: HifzKind.hadith, source: 'nawawi40:16', dueIn: 0, interval: 6, reps: 2, ease: 2.46);
  await item(kind: HifzKind.hadith, source: 'nawawi40:1');
  await item(kind: HifzKind.hadith, source: 'nawawi40:13');
  await item(
    kind: HifzKind.custom,
    title: arabic ? 'دعاء الخروج من المنزل' : 'Leaving the house',
    body: 'بِسْمِ اللَّهِ، تَوَكَّلْتُ عَلَى اللَّهِ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    source: arabic ? 'رواه أبو داود والترمذي' : 'Abu Dawud, at-Tirmidhi',
  );
  await item(surah: 18, from: 1, to: 5, dueIn: 2, interval: 6, reps: 2, suspended: true);

  // Three weeks of reviews (most days), mostly recalled.
  var n = 0;
  for (var d = -20; d <= -1; d++) {
    if (d == -9 || d == -15) continue;
    for (final (id, grade) in [(mulk1, n % 5 == 0 ? 2 : 4), (mulk2, 5), (mulk3, n % 7 == 0 ? 3 : 5), (ikhlas, 5)]) {
      await repos.hifzReviews.insert(
        HifzReviewsCompanion.insert(
          itemId: id,
          at: _day(d).add(Duration(hours: 5, minutes: n)),
          grade: grade,
          intervalBefore: 6,
          intervalAfter: grade >= 3 ? 14 : 1,
          easeAfter: 2.5,
        ),
      );
      n++;
    }
  }
}
