import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/synth/buffer.dart';
import 'package:madar/core/sound/synth/dynamics.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/music/composers.dart';
import 'package:madar/features/cinema/engine/audio/music/cue_builder.dart';
import 'package:madar/features/cinema/engine/audio/music/score.dart';
import 'package:madar/features/cinema/engine/audio/music/stingers.dart';
import 'package:madar/features/cinema/engine/audio/sfx/sfx_synth.dart';
import 'package:madar/features/cinema/engine/audio/synth/renderer.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';
import 'package:madar/features/cinema/engine/core/era_skin.dart';

import 'audio_analysis.dart';
import 'preview_util.dart';

void main() {
  group('rendered music', () {
    final highShare = <Era, double>{};
    for (final era in Era.values) {
      test('${era.name}: a loop and a jingle meet the mix spec', () {
        final style = eraScore(era);
        for (final mood in [MusicMood.adventure, MusicMood.victory]) {
          final score = composeCue(style, mood, 1);
          final cue = CueRenderer().render(score, seed: 1);
          final info = cue.info;
          final sr = info.sampleRate;
          final what = '${era.name} ${mood.name}';
          expect(cue.stems, hasLength(score.stems.length));
          expect(info.loopSeconds, closeTo(score.loopSeconds, 1 / sr));
          for (final s in cue.stems) {
            final loop = Pcm.decode(s.loop);
            expect(loop.sampleRate, sr);
            expect(loop.frames, (score.loopSeconds * sr).round(), reason: '$what ${s.spec.name}: exact loop length');
            expect(loop.channels, hasLength(s.spec.stereo ? 2 : 1));
            for (final ch in loop.channels) {
              expect(ch.every((v) => v.isFinite), isTrue);
              expect(mean(ch).abs(), lessThan(0.005), reason: '$what ${s.spec.name}: no DC');
              expect(seamClickScore(ch, sr), lessThan(2.5), reason: '$what ${s.spec.name}: click-free loop point');
            }
            if (s.intro != null) {
              expect(Pcm.decode(s.intro!).frames, greaterThanOrEqualTo((info.introSeconds * sr).round()));
            }
          }
          final full = mixdown(cue, loops: 1);
          expect(peakDb(full.channels[0]), lessThanOrEqualTo(-1.0), reason: '$what: no clipping (L)');
          expect(peakDb(full.channels[1]), lessThanOrEqualTo(-1.0), reason: '$what: no clipping (R)');
          final loopOnly = _loopMix(cue, 1);
          final rms = rmsDb(loopOnly, sr);
          if (mood == MusicMood.adventure) {
            expect(rms, inInclusiveRange(-21.5, -18.5), reason: '$what: loudness on target');
            final quiet = rmsDb(_loopMix(cue, 0), sr);
            expect(quiet, lessThan(rms - 0.5), reason: '$what: the layers add weight');
            highShare[era] = Spectrum.of(speakerWeighted(loopOnly, sr), sr).band(5000, 20000);
          } else {
            expect(rms, inInclusiveRange(-30, -18), reason: '$what: the vamp after the jingle sits under the jingle');
          }
        }
      });
    }

    test('period colour: the silent era is band-limited, the VHS era is not', () {
      // Share of audible power above 5 kHz.
      expect(highShare[Era.silent], lessThan(0.01));
      expect(highShare[Era.rubberHose], lessThan(0.01));
      expect(highShare[Era.vhs], greaterThan(0.02));
      expect(highShare[Era.grindhouse], greaterThan(0.02));
    });

    test('a note sustained across the loop end wraps around seamlessly', () {
      const style = ScoreStyle(style: MusicStyle.synthwave, tempo: 120, rootMidi: 57, lofi: 0.2);
      final b = CueBuilder(style: style.style, mood: MusicMood.calm, key: 57, bpm: 120, sound: cueSoundFor(style), seed: 1);
      b.setLoop('i | i', 2);
      final stem = b.stem(const StemSpec('bed', reverb: 0.3));
      b.note(Inst.synthPad, 7, 3, 57, 0.7, stem: stem);
      b.note(Inst.piano, 7.5, 2, 69, 0.7, stem: stem);
      final cue = CueRenderer().render(b.build());
      final x = Pcm.decode(cue.stems.single.loop).channels.first;
      expect(seamClickScore(x, cue.info.sampleRate), lessThan(1.5));
      // The note really wraps: the start of the loop is not silent.
      expect(peakDb(Float64List.sublistView(x, 0, 2000)), greaterThan(-40));
    });
  });

  test('stingers: every era has the full, click-free set', () {
    for (final era in [Era.rubberHose, Era.vhs]) {
      final kit = renderStingerKit(eraScore(era), seed: 1);
      expect(kit.clips.keys.toSet(), Stinger.values.toSet());
      for (final MapEntry(key: s, value: c) in kit.clips.entries) {
        final percussive = s == Stinger.drumroll || s == Stinger.rimshot;
        expect(c.tonal, !percussive);
        expect(c.major != null && c.minor != null, !percussive, reason: '$s tonal variants');
        for (final wav in [c.major, c.minor, c.drums].nonNulls) {
          final p = Pcm.decode(wav);
          final x = p.channels.first;
          expect(p.seconds, lessThan(5));
          expect(peakDb(x), lessThanOrEqualTo(-1.0), reason: '${era.name} $s peak');
          expect(x.first.abs(), lessThan(0.01));
          expect(x.last.abs(), lessThan(0.001), reason: '${era.name} $s ends silently');
        }
      }
    }
  });

  group('sound effects', () {
    final rolloff = <Era, double>{};
    for (final era in [Era.silent, Era.technicolor, Era.vhs]) {
      test('${era.name}: every effect is levelled, short and click-free', () {
        final synth = SfxSynth(era, seed: 1);
        final kit = synth.renderKit();
        expect(kit.keys.toSet(), {for (final s in CinemaSound.values) sfxKey(s), for (final s in CinemaSfx.values) extraKey(s)});
        for (final s in CinemaSound.values) {
          final p = Pcm.decode(kit[sfxKey(s)]!);
          final x = p.channels.first;
          expect(peakDb(x), lessThanOrEqualTo(-0.9), reason: '$s peak');
          expect(x.first.abs(), lessThan(0.02), reason: '$s starts at rest');
          expect(x.last.abs(), lessThan(0.002), reason: '$s ends at rest');
          final maxLen = switch (s) {
            CinemaSound.tick || CinemaSound.tap || CinemaSound.typewriter || CinemaSound.cardFlip => 0.4,
            CinemaSound.explosion || CinemaSound.bell || CinemaSound.projector || CinemaSound.powerUp => 2.3,
            _ => 1.2,
          };
          expect(p.seconds, lessThanOrEqualTo(maxLen), reason: '$s length');
          final loud = Loudness.momentaryDb(StereoBuffer.fromChannels(p.sampleRate, x, x));
          expect(loud, closeTo(SfxSynth.loudnessOf(s), 3.0), reason: '${era.name} $s loudness');
        }
        final w = Pcm.decode(kit[sfxKey(CinemaSound.whoosh)]!);
        rolloff[era] = Spectrum.of(_pad(speakerWeighted(w.channels.first, w.sampleRate)), w.sampleRate, size: 1024).rolloff();
      });
    }

    test('the optical-track eras sound band-limited next to the 1980s', () {
      expect(rolloff[Era.silent]!, lessThan(rolloff[Era.vhs]!));
    });
  });
}

/// The loop alone (no intro), all stems at their [intensity] layer gains.
Float64List _loopMix(RenderedCue cue, double intensity) {
  Float64List? out;
  for (final s in cue.stems) {
    final p = Pcm.decode(s.loop);
    out ??= Float64List(p.frames);
    final g = s.spec.gain * s.spec.layerGain(intensity);
    final a = (s.spec.pan + 1) * math.pi / 4;
    for (var i = 0; i < p.frames; i++) {
      final v = p.channels.length == 2 ? 0.5 * (p.channels[0][i] + p.channels[1][i]) : p.channels[0][i] * (math.cos(a) + math.sin(a)) / 2;
      out[i] += v * g;
    }
  }
  return out!;
}

Float64List _pad(Float64List x) => x.length >= 4096 ? x : (Float64List(4096)..setRange(0, x.length, x));
