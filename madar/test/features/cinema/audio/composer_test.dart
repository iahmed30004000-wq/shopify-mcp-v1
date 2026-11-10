import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/music/composers.dart';
import 'package:madar/features/cinema/engine/audio/music/grammar.dart';
import 'package:madar/features/cinema/engine/audio/music/score.dart';
import 'package:madar/features/cinema/engine/audio/music/theory.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';

void main() {
  group('theory', () {
    test('parses roman-numeral progressions', () {
      final slots = parseProgression('I | VI7 | ii7 V7 | bVIM7 #IVo7', beatsPerBar: 4);
      expect(slots.map((s) => s.chord.toString()), ['Imaj', 'VIdom7', 'IImin7', 'Vdom7', 'bVImaj7', '#IVdim7']);
      expect(slots.map((s) => s.beat), [0, 4, 8, 10, 12, 14]);
      expect(parseChord('iiø7').q, ChordQ.m7b5);
      expect(parseChord('iM7').q, ChordQ.minMaj7);
      expect(parseChord('Vb9').q, ChordQ.dom7b9);
      expect(() => parseChord('X7'), throwsFormatException);
    });

    test('swing moves off-beat eighths towards the triplet', () {
      final s = composeCue(eraScore(Era.rubberHose), MusicMood.adventure, 1);
      final spb = 60 / s.bpm;
      expect(s.beatToSeconds(1.0), closeTo(spb, 1e-9));
      final off = s.beatToSeconds(0.5) / spb;
      expect(off, closeTo(0.5 + s.swing * (2 / 3 - 0.5), 1e-9));
      expect(s.beatToSeconds(0.5, straight: true), closeTo(0.5 * spb, 1e-9));
    });
  });

  group('style grammars', () {
    for (final era in Era.values) {
      test('${era.name}: every mood composes a playable, deterministic cue', () {
        final style = eraScore(era);
        for (final mood in MusicMood.values) {
          final a = composeCue(style, mood, 5);
          final b = composeCue(style, mood, 5);
          final c = composeCue(style, mood, 6);
          expect(a.events.length, b.events.length, reason: '$mood determinism');
          for (var i = 0; i < a.events.length; i++) {
            expect(a.events[i].pitch, b.events[i].pitch);
            expect(a.events[i].beat, b.events[i].beat);
          }
          if (a.loops) expect(_signature(a) == _signature(c), isFalse, reason: '${era.name} $mood: seeds give different music');
          expect(a.stems.length, inInclusiveRange(2, 4));
          expect(a.loopBars, greaterThan(0));
          expect(a.loops, mood != MusicMood.victory && mood != MusicMood.defeat);
          final total = a.introBeats + a.loopBeats;
          for (var s = 0; s < a.stems.length; s++) {
            expect(a.events.any((e) => e.stem == s), isTrue, reason: '${era.name} $mood stem ${a.stems[s].name} has notes');
          }
          for (final e in a.events) {
            expect(e.beat, inInclusiveRange(0, total), reason: '${era.name} $mood event inside the cue');
            expect(e.vel, inInclusiveRange(0, 1));
            if (!e.inst.isDrum || e.inst == Inst.timpani) {
              expect(e.pitch, inInclusiveRange(21, 108), reason: '${era.name} $mood ${e.inst} pitch');
            }
          }
          final tempo = 60 / a.secondsPerBeat;
          expect(tempo, inInclusiveRange(55, 200));
          // Loops last long enough not to nag, short enough for memory.
          expect(a.loopSeconds, inInclusiveRange(4, 32), reason: '${era.name} $mood loop length');
        }
      });
    }
  });

  group('melody grammar', () {
    test('strong beats land on chord tones', () {
      final chart = ChordChart(parseProgression('I | VI7 | ii7 | V7 | I | IV | ii7 V7 | I'));
      var strong = 0, fit = 0;
      for (var seed = 0; seed < 40; seed++) {
        final mel = composeMelody(
          chart: chart,
          startBeat: 0,
          bars: 8,
          beatsPerBar: 4,
          keyMidi: 60,
          spec: const MelodySpec(lo: 60, hi: 84, rhythms: ['x-x-x-x-x-x-x-x-', 'x---x-xxx---x---', 'xx-x-xx-xx-x----']),
          seed: seed,
        );
        for (final n in mel) {
          final pos = n.beat % 4;
          if (pos == 0 || pos == 2) {
            strong++;
            if (chart.at(n.beat).contains((n.pitch - 60) % 12)) fit++;
          }
          expect(n.pitch, inInclusiveRange(60, 84));
        }
      }
      expect(fit / strong, greaterThan(0.85));
    });

    test('the originality guard recognises famous openings and the grammar never produces them', () {
      // A planted quotation is caught…
      expect(quotesFamousTune([62, 63, 64, 72, 64, 72, 64]), isTrue);
      expect(quotesFamousTune([60, 62, 64, 65, 67, 65, 64]), isFalse);
      // …and no line of any cue contains one.
      for (final era in Era.values) {
        for (final mood in MusicMood.values) {
          for (final seed in [1, 2, 3]) {
            final cue = composeCue(eraScore(era), mood, seed);
            for (final line in _lines(cue)) {
              expect(quotesFamousTune(line), isFalse, reason: '${era.name} $mood seed $seed');
            }
          }
        }
      }
    });
  });
}

String _signature(CueScore s) => s.events.map((e) => '${e.beat.toStringAsFixed(2)}:${e.pitch}').join(',');

/// The top line of every pitched instrument in every stem (monophonic view).
Iterable<List<int>> _lines(CueScore s) sync* {
  final keys = s.events.where((e) => !e.inst.isDrum).map((e) => (e.stem, e.inst)).toSet();
  for (final (stem, inst) in keys) {
    final byBeat = <double, int>{};
    for (final e in s.events.where((e) => e.stem == stem && e.inst == inst)) {
      final p = e.pitch.round();
      byBeat[e.beat] = byBeat.containsKey(e.beat) ? (byBeat[e.beat]! > p ? byBeat[e.beat]! : p) : p;
    }
    final beats = byBeat.keys.toList()..sort();
    yield [for (final b in beats) byBeat[b]!];
  }
}
