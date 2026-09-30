import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/synth/filters.dart';
import 'package:madar/features/cinema/engine/audio/music/score.dart';
import 'package:madar/features/cinema/engine/audio/synth/voices.dart';
import 'package:madar/features/cinema/engine/core/era_skin.dart';

void main() {
  test('inst levels', () {
    final box = VoiceBox(32000, MusicStyle.bigBand, 1);
    for (final i in Inst.values) {
      final pitch = i.isDrum ? (i == Inst.timpani ? 45.0 : 0.0) : (const [Inst.uprightBass, Inst.tuba, Inst.electricBass, Inst.synthBass].contains(i) ? 40.0 : 64.0);
      final x = box.render(NoteEvent(0, 0.5, pitch, 0.7, i), 0.5);
      final w = Float64List.fromList(x);
      Biquad(BiquadType.highPass, frequency: 150, sampleRate: 32000).processBuffer(w);
      // RMS over the loudest 300 ms window
      final win = math.min(w.length, 9600);
      var best = 0.0;
      for (var s = 0; s + win <= w.length; s += 800) {
        var e = 0.0;
        for (var k = s; k < s + win; k++) {
          e += w[k] * w[k];
        }
        best = math.max(best, e / win);
      }
      var pk = 0.0;
      for (final v in x) {
        pk = math.max(pk, v.abs());
      }
      // ignore: avoid_print
      print('${i.name.padRight(14)} len ${(x.length / 32).round().toString().padLeft(5)}ms peak ${(20 * math.log(pk) / math.ln10).toStringAsFixed(1).padLeft(6)} rms300w ${(10 * math.log(best + 1e-20) / math.ln10).toStringAsFixed(1).padLeft(6)}');
    }
  });
}
