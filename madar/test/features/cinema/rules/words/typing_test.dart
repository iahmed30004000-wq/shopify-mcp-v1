import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/words/words.dart';

import 'words_test_utils.dart';

void main() {
  group('typing units', () {
    test('ignore mode: letters only, tashkeel dropped, spaces collapsed', () {
      final t = TypingTarget('الشَّمْسُ  تُشْرِقُ');
      expect(t.units.join(), 'الشمس تشرق');
      expect(t.wordCount, 2);
      expect(t.matches(0, 'ا'), isTrue);
      expect(t.matches(0, 'أ'), isTrue); // lenient hamza
      expect(TypingTarget('أحمد', lenientHamza: false).matches(0, 'ا'), isFalse);
    });

    test('Quran text: annotation signs and superscript alef are not typed', () {
      final text = quranIndex.ayah(2, 255)!;
      final t = TypingTarget(text);
      // Uthmani spelling (الحى, لآ) folds to the everyday letters a typist uses.
      expect(ArabicText.fold(t.units.join()), startsWith(ArabicText.fold('الله لا إله إلا هو الحي القيوم لا تأخذه سنة')));
      expect(t.units.join().contains('  '), isFalse);
      final fatiha = TypingTarget(quranIndex.ayah(1, 1)!);
      expect(fatiha.units.join(), 'بسم الله الرحمن الرحيم');
    });

    test('strict mode: one unit per letter with its harakat, any mark order', () {
      final t = TypingTarget('مَدَّ', mode: TashkeelMode.strict);
      expect(t.length, 2);
      expect(t.matches(1, 'دَّ'), isTrue);
      expect(t.matches(1, 'دَّ'), isTrue);
      expect(t.matches(1, TypingTarget.unitsOf('دّ' 'َ', TashkeelMode.strict).single), isTrue);
      expect(t.matches(1, 'د'), isFalse);
    });
  });

  group('session metrics', () {
    test('accuracy, net / gross WPM and completed words', () {
      final target = TypingTarget('من جد وجد'); // 9 units, 3 words
      final s = TypingSession(target);
      s.update('م', 0);
      s.update('من', 1000);
      s.update('من ح', 2000); // wrong unit
      expect(s.firstError, 3);
      s.update('من ', 2500); // corrected
      s.update('من جد وجد', 12000);
      expect(s.finished, isTrue);
      final st = s.stats();
      expect(st.correctUnits, 9);
      expect(st.errors, 1);
      expect(st.keystrokes, 10);
      expect(st.accuracy, closeTo(0.9, 1e-9));
      expect(st.elapsedMs, 12000);
      expect(st.netWpm, closeTo(9 / 5 / 0.2, 1e-9));
      expect(st.wordsPerMinute, closeTo(3 / 0.2, 1e-9));
      s.update('من جد وجد!', 13000); // ignored after finishing
      expect(s.stats().typedUnits, 9);
    });

    test('tashkeel typed in ignore mode does not count as extra units', () {
      final s = TypingSession(TypingTarget('كتب'));
      s.update('كَتَبَ', 3000);
      expect(s.finished, isTrue);
      expect(s.stats().keystrokes, 3);
    });
  });

  group('ghosts', () {
    test('three speeds, monotonic progress, deterministic, nominal finish', () {
      final target = TypingTarget('الوقت كالسيف إن لم تقطعه قطعك');
      final times = <int>[];
      for (final speed in GhostSpeed.values) {
        final g = GhostOpponent(speed: speed, target: target, seed: 1);
        expect(g.finishMs, closeTo(60000 / (speed.wpm * 5) * target.length, 1));
        var last = 0;
        for (var ms = 0; ms <= g.finishMs; ms += 250) {
          final u = g.unitsAt(ms);
          expect(u, greaterThanOrEqualTo(last));
          last = u;
        }
        expect(g.progressAt(g.finishMs), 1);
        expect(g.unitsAt(0), 0);
        times.add(g.finishMs);
        expect(GhostOpponent(speed: speed, target: target, seed: 1).unitsAt(3000), g.unitsAt(3000));
      }
      expect(times[0] > times[1] && times[1] > times[2], isTrue);
      final a = GhostOpponent(speed: GhostSpeed.steady, target: target, seed: 1);
      final b = GhostOpponent(speed: GhostSpeed.steady, target: target, seed: 2);
      expect(List.generate(20, (i) => a.unitsAt(i * 300)), isNot(List.generate(20, (i) => b.unitsAt(i * 300))));
    });
  });

  group('passage bank', () {
    test('filters and seeded picks', () {
      final quran = passageBank.filter(kinds: {PassageKind.quran});
      expect(quran.length, greaterThanOrEqualTo(30));
      final rng = WordsRng(4);
      final recent = <String>{};
      for (var i = 0; i < 20; i++) {
        final p = passageBank.pick(rng, levels: {1}, recent: recent);
        expect(p.level, 1);
        expect(recent.add(p.id), isTrue);
      }
      final ref = quran.firstWhere((p) => p.sura == 112);
      expect(ArabicText.skeleton(ref.resolve(quranIndex)!), startsWith(ArabicText.skeleton('الله الصمد لم يلد')));
      expect(ref.resolve(), isNull);
      expect(ref.cite!.en, 'Quran 112:2-4 (Al-Ikhlas)');
    });
  });
}
