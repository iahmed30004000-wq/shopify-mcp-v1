import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/ambient.dart';
import 'package:madar/core/sound/profiles.dart';
import 'package:madar/core/sound/synth/synth.dart';

void main() {
  group('AmbientSoundscape', () {
    test('default loop: 24 kHz stereo WAV, ≈28 s, frames a multiple of 16', () {
      final sw = Stopwatch()..start();
      final wav = AmbientSoundscape.renderWav('lapis');
      sw.stop();
      // Sanity bound on the host; on a phone it runs on a background isolate.
      expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
      final info = Wav.parse(wav);
      expect(info.channels, 2);
      expect(info.sampleRate, AmbientSoundscape.defaultSampleRate);
      expect(info.frames % 16, 0);
      expect(info.duration.inMilliseconds, closeTo(28000, 5));
      expect(info.duration.inSeconds, inInclusiveRange(24, 32));
      final l = Wav.decodeChannel(wav, 0);
      final r = Wav.decodeChannel(wav, 1);
      var peak = 0.0, e = 0.0;
      for (var i = 0; i < l.length; i++) {
        peak = math.max(peak, math.max(l[i].abs(), r[i].abs()));
        e += 0.5 * (l[i] * l[i] + r[i] * r[i]);
      }
      expect(peak, lessThanOrEqualTo(dbToGain(-1)));
      expect(gainToDb(math.sqrt(e / l.length)), closeTo(AmbientSoundscape.targetRmsDb, 1.0));
    });

    for (final id in SoundProfiles.ids) {
      test('$id loops seamlessly: consecutive periods are sample-identical', () {
        final b = AmbientSoundscape.render(id, loopSeconds: 6, loops: 2);
        final loop = b.frames ~/ 2;
        var maxDiff = 0.0, energy = 0.0;
        for (var i = 0; i < loop; i++) {
          maxDiff = math.max(maxDiff, (b.left[i] - b.left[i + loop]).abs());
          maxDiff = math.max(maxDiff, (b.right[i] - b.right[i + loop]).abs());
          energy += b.left[i] * b.left[i];
        }
        expect(energy, greaterThan(0), reason: 'not silent');
        // Far below one 16-bit LSB (3e-5): the wrap point is inaudible.
        expect(maxDiff, lessThan(1e-5), reason: '$id period mismatch $maxDiff');
      });
    }

    test('is deterministic and profile-specific', () {
      final a = AmbientSoundscape.renderWav('desert', loopSeconds: 4);
      final b = AmbientSoundscape.renderWav('desert', loopSeconds: 4);
      final c = AmbientSoundscape.renderWav('aurora', loopSeconds: 4);
      expect(a, b);
      expect(a, isNot(c));
    });

    test('renders on a background isolate', () async {
      final bg = await AmbientSoundscape.renderInBackground('pearl', loopSeconds: 4);
      expect(bg, AmbientSoundscape.renderWav('pearl', loopSeconds: 4));
    });
  });
}
