import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/music/stingers.dart';
import 'package:madar/features/cinema/engine/audio/sfx/sfx_synth.dart';
import 'package:madar/features/cinema/engine/core/era.dart';

void main() {
  test('kit timing', () {
    for (final era in Era.values) {
      var sw = Stopwatch()..start();
      final k = renderStingerKit(eraScore(era));
      final st = sw.elapsedMilliseconds;
      sw = Stopwatch()..start();
      final s = SfxSynth(era).renderKit();
      final sx = sw.elapsedMilliseconds;
      // ignore: avoid_print
      print('${era.name}: stingers ${st}ms ${(k.bytes / 1e6).toStringAsFixed(2)}MB, sfx ${sx}ms ${(s.values.fold(0, (a, b) => a + b.length) / 1e6).toStringAsFixed(2)}MB');
    }
  });
}
