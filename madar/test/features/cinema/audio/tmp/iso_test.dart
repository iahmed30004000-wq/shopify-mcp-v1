import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/music/composers.dart';
import 'package:madar/features/cinema/engine/audio/runtime/cue_source.dart';
import 'package:madar/features/cinema/engine/audio/synth/renderer.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';

void main() {
  test('parallel == sequential, timing', () async {
    for (final era in [Era.silent, Era.noir, Era.vhs, Era.silent, Era.noir, Era.vhs]) {
      final style = eraScore(era);
      var sw = Stopwatch()..start();
      final a = await const IsolateCueSource().renderCue(style, MusicMood.adventure, 3);
      final par = sw.elapsedMilliseconds;
      sw = Stopwatch()..start();
      final b = CueRenderer().render(composeCue(style, MusicMood.adventure, 3), seed: 3);
      final seq = sw.elapsedMilliseconds;
      for (var i = 0; i < a.stems.length; i++) {
        expect(a.stems[i].loop, b.stems[i].loop);
      }
      // ignore: avoid_print
      print('${era.name}: parallel ${par}ms sequential ${seq}ms');
    }
  });
}
