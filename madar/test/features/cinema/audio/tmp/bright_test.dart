import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/music/composers.dart';
import 'package:madar/features/cinema/engine/audio/synth/renderer.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';

import '../audio_analysis.dart';
import '../preview_util.dart';

void main() {
  test('brightness', () {
    for (final era in Era.values) {
      final cue = CueRenderer().render(composeCue(eraScore(era), MusicMood.adventure, 1));
      final m = mixdown(cue, loops: 1).mono;
      final w = speakerWeighted(m, cue.info.sampleRate);
      final sp = Spectrum.of(w, cue.info.sampleRate);
      // ignore: avoid_print
      print('${era.name.padRight(11)} weighted cent ${sp.centroid.toStringAsFixed(0)} roll85 ${sp.rolloff().toStringAsFixed(0)} >2k ${(sp.band(2000, 20000) * 100).toStringAsFixed(0)}% >5k ${(sp.band(5000, 20000) * 100).toStringAsFixed(1)}%');
    }
  });
}
