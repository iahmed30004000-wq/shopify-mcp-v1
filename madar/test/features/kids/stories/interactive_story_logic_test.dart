import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/stories/data/voice_recorder.dart';
import 'package:madar/features/kids/stories/domain/little_star_story.dart';
import 'package:madar/features/kids/stories/domain/sound_detector.dart';
import 'package:madar/features/kids/stories/domain/story_runner.dart';
import 'package:madar/features/kids/stories/domain/story_script.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  group('the script (plain data)', () {
    test('«النجمة الصغيرة» has 5-6 beats, some ask for a word, all text in both languages', () {
      expect(littleStarStory.beats.length, inInclusiveRange(5, 6));
      expect(littleStarStory.promptCount, inInclusiveRange(1, 3));
      for (final b in littleStarStory.beats) {
        expect(b.narration.ar.trim(), isNotEmpty);
        expect(b.narration.en.trim(), isNotEmpty);
        for (final p in [b.from, b.to]) {
          expect(p.x, inInclusiveRange(0, 1));
          expect(p.y, inInclusiveRange(0, 1));
          expect(p.glow, inInclusiveRange(0, 1));
        }
        expect(b.lanternFrom, inInclusiveRange(0, 1));
        expect(b.lanternTo, inInclusiveRange(0, 1));
        expect(b.sparkles, inInclusiveRange(0, StoryScript.maxSparkles));
        expect(b.motionMs, greaterThan(0));
      }
    });

    test('the story is original and not religious: no sacred words, no digits, no faces', () {
      final text = [
        littleStarStory.title.ar,
        for (final b in littleStarStory.beats) ...[b.narration.ar, b.say?.word.ar ?? ''],
      ].join(' ');
      for (final w in ['الله', 'نبي', 'رسول', 'قرآن', 'آية', 'صلاة', 'دعاء', 'جنة', 'شيطان']) {
        expect(text.contains(w), isFalse, reason: w);
      }
      expect(RegExp('[0-9٠-٩]').hasMatch(text), isFalse);
    });

    test('a continuous path: each beat starts where the last one ended', () {
      final b = littleStarStory.beats;
      for (var i = 1; i < b.length; i++) {
        expect(b[i].from.x, b[i - 1].to.x, reason: 'beat $i');
        expect(b[i].from.y, b[i - 1].to.y);
      }
    });

    test('LocalizedText picks the language', () {
      const t = LocalizedText(ar: 'أ', en: 'a');
      expect(t.of('ar'), 'أ');
      expect(t.of('en'), 'a');
      expect(t.of('fr'), 'a');
    });
  });

  group('the runner', () {
    StoryRunner finishBeat(StoryRunner r) => r..motionDone();

    test('a beat without a word waits for «التالي»; a beat with a word waits for a sound or the skip', () {
      final r = StoryRunner(littleStarStory);
      expect(r.phase, StoryPhase.moving);
      expect(r.next(), isFalse, reason: 'not before the movement is done');
      finishBeat(r);
      expect(r.phase, StoryPhase.readyToContinue);
      expect(r.soundHeard(), isFalse, reason: 'this beat asks for no word');
      expect(r.next(), isTrue);
      expect(r.beatIndex, 1);
    });

    test('a sound and the skip button do the same thing', () {
      final a = StoryRunner(littleStarStory);
      final b = StoryRunner(littleStarStory);
      for (final r in [a, b]) {
        r
          ..motionDone()
          ..next()
          ..motionDone()
          ..next()
          ..motionDone();
        expect(r.beat.say, isNotNull);
        expect(r.isAskingToSay, isTrue);
      }
      expect(a.soundHeard(), isTrue);
      expect(b.skipSay(), isTrue);
      expect(a.beatIndex, b.beatIndex);
      expect(a.phase, b.phase);
      expect(a.soundsHeard, 1);
      expect(b.wordsSkipped, 1);
    });

    test('a sound while the star is still moving does nothing (no early skip)', () {
      final r = StoryRunner(littleStarStory)
        ..motionDone()
        ..next()
        ..motionDone()
        ..next();
      expect(r.beat.say, isNotNull);
      expect(r.phase, StoryPhase.moving);
      expect(r.soundHeard(), isFalse);
      expect(r.skipSay(), isFalse);
    });

    test('it plays through to the end and finishes once', () {
      final r = StoryRunner(littleStarStory);
      var guard = 0;
      while (!r.isFinished && guard++ < 50) {
        r.motionDone();
        if (r.isAskingToSay) {
          r.skipSay();
        } else {
          r.next();
        }
      }
      expect(r.isFinished, isTrue);
      expect(r.beatIndex, littleStarStory.beats.length - 1);
      expect(r.next(), isFalse);
      expect(r.skipSay(), isFalse);
    });

    test('replay stays on the beat; restart goes back to the first', () {
      final r = StoryRunner(littleStarStory)
        ..motionDone()
        ..next()
        ..motionDone();
      r.replayBeat();
      expect(r.beatIndex, 1);
      expect(r.phase, StoryPhase.moving);
      r.restart();
      expect(r.beatIndex, 0);
      expect(r.soundsHeard + r.wordsSkipped, 0);
    });
  });

  group('the sound detector (no speech recognition, only "was there a sound")', () {
    test('a steady louder sound is heard once, after the deaf start', () {
      final d = SoundDetector();
      var t = 0;
      var heard = 0;
      // 400 ms of quiet room.
      for (; t < 400; t += 50) {
        if (d.update(0.02, ms(t))) heard++;
      }
      expect(heard, 0);
      // A voice: loud for a while.
      for (; t < 1400; t += 50) {
        if (d.update(0.5, ms(t))) heard++;
      }
      expect(heard, 1, reason: 'fires exactly once');
      expect(d.update(0.9, ms(t + 100)), isFalse);
    });

    test('a click (one loud reading) is not a voice', () {
      final d = SoundDetector();
      for (var t = 0; t < 800; t += 50) {
        expect(d.update(t == 600 ? 0.9 : 0.02, ms(t)), isFalse);
      }
    });

    test('the first half second is deaf (the tap that opened the beat)', () {
      final d = SoundDetector();
      var heard = false;
      for (var t = 0; t < 450; t += 50) {
        heard = d.update(0.9, ms(t)) || heard;
      }
      expect(heard, isFalse);
    });

    test('a noisy room raises the bar: a constant hum is never a voice', () {
      final d = SoundDetector();
      var heard = false;
      for (var t = 0; t < 4000; t += 50) {
        heard = d.update(0.12, ms(t)) || heard; // below the 0.15 floor anyway
      }
      expect(heard, isFalse);
      // A hum above the fixed threshold: learnt as the room, so only a rise counts.
      final d2 = SoundDetector(threshold: 0.05);
      for (var t = 0; t < 1000; t += 50) {
        d2.update(0.04, ms(t));
      }
      expect(d2.noiseFloor, greaterThan(0.03));
      var heard2 = false;
      for (var t = 1000; t < 2000; t += 50) {
        heard2 = d2.update(0.06, ms(t)) || heard2; // above 0.05 but not 2.5x the floor
      }
      expect(heard2, isFalse);
    });

    test('reset listens afresh', () {
      final d = SoundDetector();
      var n = 0;
      for (var t = 0; t < 1500; t += 50) {
        if (d.update(0.6, ms(t))) n++;
      }
      expect(n, 1);
      d.reset();
      for (var t = 2000; t < 3500; t += 50) {
        if (d.update(0.6, ms(t))) n++;
      }
      expect(n, 2);
    });
  });

  group('microphone helpers', () {
    test('PCM loudness: silence is 0, a loud tone is high, empty is 0', () {
      expect(pcm16Rms(Uint8List(0)), 0);
      expect(pcm16Rms(Uint8List(640)), 0);
      final loud = Uint8List(640);
      final bd = ByteData.sublistView(loud);
      for (var i = 0; i < 320; i++) {
        bd.setInt16(i * 2, i.isEven ? 12000 : -12000, Endian.little);
      }
      expect(pcm16Rms(loud), greaterThan(0.5));
      expect(pcm16Rms(loud), lessThanOrEqualTo(1));
    });

    test('dBFS maps to 0..1 and never to NaN', () {
      expect(RecordPackageRecorder.dbToLevel(-160), 0);
      expect(RecordPackageRecorder.dbToLevel(0), 1);
      expect(RecordPackageRecorder.dbToLevel(double.nan), 0);
      expect(RecordPackageRecorder.dbToLevel(-27.5), closeTo(0.5, 1e-9));
    });
  });
}
