import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/sound/profiles.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/core/sound/sound_kit.dart';
import 'package:madar/core/sound/synth/synth.dart';

void main() {
  // Render every kit once and share it across the checks below.
  final kits = {for (final id in SoundProfiles.ids) id: SoundKitRenderer.render(id)};
  final ceiling = dbToGain(-1);

  group('registry', () {
    test('five profiles, one per theme, with stable ids', () {
      expect(SoundProfiles.ids, ['lapis', 'emerald', 'desert', 'aurora', 'pearl']);
      expect([for (final p in SoundProfiles.all) p.id], SoundProfiles.ids);
      for (final t in MadarThemeId.values) {
        final id = SoundProfiles.idForTheme(t);
        expect(id, t.name);
        expect(SoundProfiles.byId(id).id, id);
      }
      expect(SoundProfiles.byId('nope').id, 'lapis');
      expect(SoundProfiles.normalize('nope'), 'lapis');
      expect(SoundProfiles.normalize('desert'), 'desert');
    });

    test('each profile has its own maqam colour', () {
      expect(SoundProfiles.lapis.maqam, Maqam.rast);
      expect(SoundProfiles.emerald.maqam, Maqam.bayati);
      expect(SoundProfiles.desert.maqam, Maqam.hijaz);
      expect(SoundProfiles.aurora.maqam, Maqam.ajam);
      expect(SoundProfiles.pearl.maqam, Maqam.nahawand);
    });
  });

  for (final id in SoundProfiles.ids) {
    group('profile $id', () {
      test('voices every Sfx as a valid, clean, level-matched stereo WAV', () {
        final kit = kits[id]!;
        expect(kit.profileId, id);
        expect(kit.wavs.keys.toSet(), Sfx.values.toSet(), reason: 'every Sfx voiced');
        for (final sfx in Sfx.values) {
          final wav = kit.wavs[sfx]!;
          final info = Wav.parse(wav);
          final what = '$id/${sfx.name}';
          expect(info.channels, 2, reason: what);
          expect(info.sampleRate, 44100, reason: what);
          expect(info.bitsPerSample, 16, reason: what);
          expect(wav.length, 44 + info.frames * 4, reason: what);
          final ms = info.frames * 1000 / info.sampleRate;
          expect(ms, inInclusiveRange(40, 900), reason: '$what length ${ms.toStringAsFixed(0)} ms');

          final l = Wav.decodeChannel(wav, 0);
          final r = Wav.decodeChannel(wav, 1);
          var peak = 0.0, dc = 0.0;
          for (var i = 0; i < l.length; i++) {
            peak = math.max(peak, math.max(l[i].abs(), r[i].abs()));
            dc += l[i] + r[i];
          }
          expect(peak, lessThanOrEqualTo(ceiling), reason: '$what peak ${gainToDb(peak).toStringAsFixed(2)} dBFS');
          expect(peak, greaterThan(dbToGain(-40)), reason: '$what is audible');
          expect((dc / (2 * l.length)).abs(), lessThan(0.003), reason: '$what DC offset');
          // Click-free edges.
          expect(l.first.abs() + r.first.abs(), lessThan(0.002), reason: '$what starts at silence');
          expect(l.last.abs() + r.last.abs(), lessThan(0.002), reason: '$what ends at silence');
          // Level-matched to the shared loudness target.
          final loud = Loudness.momentaryDb(StereoBuffer.fromChannels(44100, l, r));
          expect(loud, closeTo(SfxSpecs.loudnessDb(sfx), 2.0), reason: '$what loudness');
        }
      });

      test('is deterministic', () {
        final again = SoundProfiles.byId(id);
        for (final sfx in [Sfx.tap, Sfx.complete, Sfx.sparkle, Sfx.sheetOpen]) {
          expect(again.renderWav(sfx), kits[id]!.wavs[sfx], reason: '$id/${sfx.name}');
        }
      });
    });
  }

  test('profiles sound different from one another', () {
    for (final sfx in [Sfx.tap, Sfx.complete, Sfx.error]) {
      final set = {for (final id in SoundProfiles.ids) Object.hashAll(kits[id]!.wavs[sfx]!)};
      expect(set.length, SoundProfiles.ids.length, reason: sfx.name);
    }
  });

  test('complete is a rising three-note chime; error is a gentle low two-note', () {
    // Onset detection on the envelope: three distinct attacks for complete,
    // two for error.
    int onsets(List<double> x) {
      const win = 441; // 10 ms
      final env = <double>[];
      for (var s = 0; s + win <= x.length; s += win) {
        var e = 0.0;
        for (var i = s; i < s + win; i++) {
          e += x[i] * x[i];
        }
        env.add(math.sqrt(e / win));
      }
      final floor = 0.3 * env.reduce(math.max);
      var n = env.first > floor ? 1 : 0;
      for (var i = 3; i < env.length; i++) {
        final before = math.min(env[i - 1], math.min(env[i - 2], env[i - 3]));
        if (env[i] > floor && env[i] > before * 1.2) {
          n++;
          i += 4; // skip the rest of this attack
        }
      }
      return n;
    }

    for (final id in SoundProfiles.ids) {
      final complete = Wav.decodeChannel(kits[id]!.wavs[Sfx.complete]!, 0);
      final error = Wav.decodeChannel(kits[id]!.wavs[Sfx.error]!, 0);
      expect(onsets(complete), greaterThanOrEqualTo(3), reason: '$id complete');
      expect(onsets(error), inInclusiveRange(2, 3), reason: '$id error');
    }
  });

  test('render-time budget: a full kit renders well under 300 ms', () {
    // Host JIT numbers are a sanity bound; the < 300 ms target applies to a
    // mid-range phone with AOT code, where rendering runs on an isolate.
    for (final id in SoundProfiles.ids) {
      final best = [for (var i = 0; i < 2; i++) SoundKitRenderer.render(id).renderTime]
          .reduce((a, b) => a < b ? a : b);
      expect(best, lessThan(const Duration(milliseconds: 300)), reason: '$id rendered in ${best.inMilliseconds} ms');
    }
  });

  test('kit partitioning covers every sound exactly once, balanced by length', () {
    for (final n in [1, 2, 3, 4]) {
      final parts = SoundKitRenderer.partition(Sfx.values, n);
      expect(parts.length, n);
      expect(parts.expand((p) => p).toList()..sort((a, b) => a.index - b.index), Sfx.values);
      final loads = [for (final p in parts) p.fold(0.0, (a, s) => a + SfxSpecs.maxSeconds(s))];
      expect(loads.reduce(math.max) - loads.reduce(math.min), lessThan(0.95));
    }
  });

  test('renders in a background isolate with identical output', () async {
    final kit = await SoundKitRenderer.renderInBackground('desert');
    expect(kit.profileId, 'desert');
    for (final sfx in Sfx.values) {
      expect(kit.wavs[sfx], kits['desert']!.wavs[sfx], reason: sfx.name);
    }
  });
}
