import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/music/composers.dart';
import 'package:madar/features/cinema/engine/audio/synth/renderer.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';

void main() {
  test('profile', () {
    for (final era in [Era.silent, Era.noir, Era.vhs, Era.grindhouse]) {
      final r = CueRenderer();
      for (var i = 0; i < 2; i++) {
        r.profile.clear();
        final sw = Stopwatch()..start();
        final score = composeCue(eraScore(era), MusicMood.adventure, 1);
        final comp = sw.elapsedMilliseconds;
        r.render(score);
        // ignore: avoid_print
        print('${era.name} compose ${comp}ms ${r.profile}');
      }
    }
  });
}
