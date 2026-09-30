import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/music/composers.dart';
import 'package:madar/features/cinema/engine/audio/synth/renderer.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';

import '../audio_analysis.dart';

void main() {
  test('stems', () {
    for (final era in Era.values) {
      final cue = CueRenderer().render(composeCue(eraScore(era), MusicMood.adventure, 1));
      final parts = <String>[];
      for (final s in cue.stems) {
        final p = Pcm.decode(s.loop);
        final sp = Spectrum.of(p.mono, p.sampleRate);
        parts.add('${s.spec.name} rms ${rmsDb(p.mono, p.sampleRate).toStringAsFixed(1)} raw ${rmsDb(p.mono, p.sampleRate, weighted: false).toStringAsFixed(1)} '
            'cent ${sp.centroid.toStringAsFixed(0)} <150 ${(sp.band(0, 150) * 100).toStringAsFixed(0)}% >2k ${(sp.band(2000, 20000) * 100).toStringAsFixed(0)}%');
      }
      // ignore: avoid_print
      print('${era.name.padRight(11)} ${parts.join(' | ')}');
    }
  });
}
