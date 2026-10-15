import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/hifz/domain/hadith_collection.dart';
import 'package:madar/features/hifz/domain/hifz_models.dart';
import 'package:madar/features/hifz/domain/hifz_reveal.dart';
import 'package:madar/features/hifz/domain/hifz_session.dart';
import 'package:madar/features/hifz/domain/sm2.dart';

import '../wird/fake_quran_catalog.dart';

final _today = DateTime(2026, 9, 28);

HifzCard _card(
  String id, {
  DateTime? due,
  Sm2State sm2 = Sm2State.initial,
  bool suspended = false,
  int order = 0,
  HifzKind kind = HifzKind.custom,
}) => HifzCard(
  id: id,
  kind: kind,
  title: id,
  body: 'نص $id',
  sm2: sm2,
  due: due,
  suspended: suspended,
  sortOrder: order,
  createdAt: DateTime(2026, 9, 1),
);

HifzReviewLog _review(String item, DateTime at, int grade, {int before = 1}) =>
    HifzReviewLog(itemId: item, at: at, grade: grade, intervalBefore: before, intervalAfter: before * 2);

void main() {
  group('queue', () {
    test('due first (most overdue, then hardest), then new up to the daily limit', () {
      final cards = [
        _card('new1', order: 1),
        _card(
          'due-late',
          due: DateTime(2026, 9, 20),
          sm2: const Sm2State(easeFactor: 2.5, repetitions: 3, intervalDays: 10),
        ),
        _card('future', due: DateTime(2026, 10, 2), sm2: const Sm2State(repetitions: 2, intervalDays: 6)),
        _card(
          'due-hard',
          due: DateTime(2026, 9, 28),
          sm2: const Sm2State(easeFactor: 1.5, repetitions: 1, intervalDays: 1),
        ),
        _card(
          'due-easy',
          due: DateTime(2026, 9, 28),
          sm2: const Sm2State(easeFactor: 2.8, repetitions: 1, intervalDays: 1),
        ),
        _card('new0', order: 0),
        _card('new2', order: 2),
        _card('suspended', due: DateTime(2026, 9, 1), suspended: true),
      ];
      final q = HifzQueue.build(cards: cards, reviews: const [], today: _today, newPerDay: 2);
      expect(q.map((c) => c.id), ['due-late', 'due-hard', 'due-easy', 'new0', 'new1']);
    });

    test('new items started today count against the limit', () {
      final cards = [_card('a'), _card('b'), _card('c')];
      final reviews = [_review('x', _today.add(const Duration(hours: 9)), 4, before: 0)];
      final q = HifzQueue.build(cards: cards, reviews: reviews, today: _today, newPerDay: 2);
      expect(q.length, 1);
      // An item first studied yesterday is not new today.
      final older = [
        _review('y', DateTime(2026, 9, 27, 10), 4, before: 0),
        _review('y', _today.add(const Duration(hours: 8)), 5),
      ];
      expect(HifzQueue.newStartedToday(older, _today), 0);
    });
  });

  group('session', () {
    test('grades reschedule with SM-2 and due dates land on calendar days', () {
      final s = HifzSession([_card('a'), _card('b')]);
      final now = DateTime(2026, 9, 28, 20, 30);
      final a = s.grade(5, now);
      expect(a.after!.sm2.intervalDays, 1);
      expect(a.after!.due, DateTime(2026, 9, 29));
      expect(a.after!.lastReviewedAt, now);
      expect(a.queuedRedrill, isFalse);
      final b = s.grade(4, now);
      expect(b.after!.due, DateTime(2026, 9, 29));
      expect(s.isComplete, isTrue);
      expect(s.summary.reviewed, 2);
      expect(s.summary.learnedNew, 2);
      expect(s.summary.averageGrade, 4.5);
    });

    test('below 4 is drilled again the same day without changing the schedule', () {
      final s = HifzSession([_card('a', due: _today, sm2: const Sm2State(repetitions: 2, intervalDays: 6))]);
      final first = s.grade(2, _today);
      expect(first.after!.sm2.repetitions, 0);
      expect(first.after!.sm2.lapses, 1);
      expect(first.queuedRedrill, isTrue);
      expect(s.current!.redrill, isTrue);
      final again = s.grade(3, _today);
      expect(again.scheduled, isFalse);
      expect(again.queuedRedrill, isTrue);
      final ok = s.grade(4, _today);
      expect(ok.queuedRedrill, isFalse);
      expect(s.isComplete, isTrue);
      final sum = s.summary;
      expect(sum.reviewed, 1);
      expect(sum.redrills, 2);
      expect(sum.recalled, 0);
    });

    test('re-drills are capped', () {
      final s = HifzSession([_card('a')]);
      for (var i = 0; i < 10 && !s.isComplete; i++) {
        s.grade(0, _today);
      }
      expect(s.isComplete, isTrue);
      expect(s.length, 1 + HifzSession.maxRedrills);
    });

    test('undo takes back the grade and its re-drill', () {
      final s = HifzSession([_card('a'), _card('b')]);
      s.grade(1, _today);
      expect(s.length, 3);
      final undone = s.undo()!;
      expect(undone.grade, 1);
      expect(undone.before.id, 'a');
      expect(s.length, 2);
      expect(s.position, 0);
      expect(s.current!.card.id, 'a');
      expect(s.canUndo, isFalse);
      expect(s.undo(), isNull);
    });
  });

  group('stats', () {
    test('due, learned, retention, streak and forecast', () {
      final cards = [
        _card('overdue', due: DateTime(2026, 9, 25), sm2: const Sm2State(repetitions: 2, intervalDays: 6)),
        _card('today', due: _today, sm2: const Sm2State(repetitions: 1, intervalDays: 1)),
        _card('tomorrow', due: DateTime(2026, 9, 29), sm2: const Sm2State(repetitions: 3, intervalDays: 25)),
        _card('in6', due: DateTime(2026, 10, 4), sm2: const Sm2State(repetitions: 2, intervalDays: 6)),
        _card('in7', due: DateTime(2026, 10, 5), sm2: const Sm2State(repetitions: 2, intervalDays: 6)),
        _card('new'),
        _card('susp', due: _today, suspended: true, sm2: const Sm2State(repetitions: 1, intervalDays: 1)),
      ];
      final reviews = [
        _review('today', DateTime(2026, 9, 27, 21), 5),
        _review('in6', DateTime(2026, 9, 26, 7), 2),
        _review('in7', DateTime(2026, 9, 25, 7), 4),
        _review('tomorrow', DateTime(2026, 9, 1, 7), 3),
        _review('old', DateTime(2026, 8, 1, 7), 0), // outside 30 days
        _review('new-ish', DateTime(2026, 9, 26, 8), 1, before: 0), // first learning: not a recall
      ];
      final s = HifzStats.compute(cards: cards, reviews: reviews, today: _today, newPerDay: 3);
      expect(s.dueToday, 2);
      expect(s.forecast, [2, 1, 0, 0, 0, 0, 1]);
      expect(s.learned, 6);
      expect(s.mature, 1);
      expect(s.newWaiting, 1);
      expect(s.newLeftToday, 1);
      expect(s.suspended, 1);
      expect(s.sessionSize, 3);
      expect(s.retention, closeTo(3 / 4, 1e-9));
      // Reviews on 25, 26, 27 Sep and none yet today: a 3-day streak.
      expect(s.streak, 3);
      expect(s.reviewedToday, 0);
    });

    test('no reviews: no retention, no streak', () {
      final s = HifzStats.compute(cards: [_card('a')], reviews: const [], today: _today, newPerDay: 3);
      expect(s.retention, isNull);
      expect(s.streak, 0);
      expect(s.sessionSize, 1);
    });
  });

  group('chunks', () {
    test('even chunks of at most N ayat', () {
      expect(HifzChunker.split(1, 13, 5), [(1, 5), (6, 9), (10, 13)]);
      expect(HifzChunker.split(1, 10, 5), [(1, 5), (6, 10)]);
      expect(HifzChunker.split(4, 4, 5), [(4, 4)]);
      expect(HifzChunker.split(1, 30, 7).length, 5);
    });

    test('ranges across surahs split per surah', () {
      final catalog = FakeQuranCatalog();
      final chunks = HifzChunker.chunks(const AyahRange(AyahRef(112, 3), AyahRef(114, 6)), catalog.ayahCount, 4);
      expect(chunks, const [
        AyahRange(AyahRef(112, 3), AyahRef(112, 4)),
        AyahRange(AyahRef(113, 1), AyahRef(113, 3)),
        AyahRange(AyahRef(113, 4), AyahRef(113, 5)),
        AyahRange(AyahRef(114, 1), AyahRef(114, 3)),
        AyahRange(AyahRef(114, 4), AyahRef(114, 6)),
      ]);
    });
  });

  group('reveal', () {
    test('first letters keep their marks', () {
      expect(HifzText.firstLetter('بِسْمِ'), 'بِ');
      expect(HifzText.firstLetter('ٱللَّهِ'), 'ٱ');
      expect(HifzText.firstLetter('ٱلرَّحْمَـٰنِ'), 'ٱ');
      expect(HifzText.firstLetter('قُلْ'), 'قُ');
      expect(HifzText.firstLetter('«الدِّينُ'), '«ا');
      expect(HifzText.splitFirst('هُوَ'), ('هُ', 'وَ'));
      expect(HifzText.firstLetter('Hello'), 'H');
    });

    test('pause signs stay with the word before them', () {
      expect(HifzText.words('ٱلْقَيُّومُ ۚ لَا تَأْخُذُهُۥ'), ['ٱلْقَيُّومُۚ', 'لَا', 'تَأْخُذُهُۥ']);
    });

    test('hidden → first letters → word by word → full', () {
      var r = const HifzReveal(words: 3);
      expect(r.showsFirstLetters, isFalse);
      expect(r.isShown(0), isFalse);
      r = r.firstLetters();
      expect(r.showsFirstLetters, isTrue);
      r = r.nextWord();
      expect(r.stage, HifzRevealStage.words);
      expect([r.isShown(0), r.isShown(1)], [true, false]);
      r = r.revealTo(1);
      expect(r.shown, 2);
      r = r.nextWord();
      expect(r.isFull, isTrue);
      expect(r.hide().stage, HifzRevealStage.hidden);
    });

    test('ayat tokens end each ayah with its marker', () {
      final t = HifzText.ayatTokens([(1, 'ٱللَّهُ ٱلصَّمَدُ'), (2, 'لَمْ يَلِدْ')], (n) => '($n)');
      expect(t.map((e) => e.toString()), ['ٱللَّهُ', 'ٱلصَّمَدُ', '[(1)]', 'لَمْ', 'يَلِدْ', '[(2)]']);
    });
  });

  group('bundled hadith', () {
    late HadithCollection nawawi;
    setUpAll(() {
      nawawi = HadithCollection.fromJson(
        (jsonDecode(File(HadithCollection.nawawiAsset).readAsStringSync()) as Map).cast<String, Object?>(),
      );
    });

    test("An-Nawawi's Forty: 42 hadith, numbered, clean Arabic text", () {
      expect(nawawi.id, 'nawawi40');
      expect(nawawi.entries.length, 42);
      expect(nawawi.validate(), isEmpty);
      expect(nawawi.license, contains('Unlicense'));
      expect(nawawi.source, contains('fawazahmed0/hadith-api'));
    });

    test('well-known opening and closing narrations', () {
      expect(nawawi.entries.first.text, contains('إنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ'));
      expect(nawawi.entries.first.titleAr, 'إنّما الأعمال بالنيّات');
      expect(nawawi.entries[15].text, contains('لَا تَغْضَبْ'));
      expect(nawawi.entries[15].takhrij, 'رَوَاهُ الْبُخَارِيُّ.');
      expect(nawawi.entries.last.number, 42);
    });

    test('keys round-trip', () {
      final e = nawawi.entries[11];
      expect(nawawi.keyOf(e), 'nawawi40:12');
      expect(nawawi.byKey('nawawi40:12'), same(e));
      expect(nawawi.byKey('bukhari:12'), isNull);
      expect(nawawi.byKey(null), isNull);
    });

    test('the credits file names the source and licence', () {
      final credits = File('assets/licenses/hadith_credits.txt').readAsStringSync();
      expect(credits, contains('https://github.com/fawazahmed0/hadith-api'));
      expect(credits, contains('Unlicense'));
    });
  });
}
