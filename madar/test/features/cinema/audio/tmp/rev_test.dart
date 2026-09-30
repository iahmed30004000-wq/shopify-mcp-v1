import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/synth/reverb.dart';
import 'package:madar/core/sound/synth/filters.dart';
import 'package:madar/features/cinema/engine/audio/synth/renderer.dart';

void main() {
  test('rev', () {
    for (var k = 0; k < 3; k++) {
      final n = 600000;
      final x = Float64List(n);
      for (var i = 0; i < n; i += 1000) x[i] = 1;
      var sw = Stopwatch()..start();
      final l = Float64List(n), r = Float64List(n);
      Reverb(24000, const ReverbSpec()).process(x, l, r);
      final t1 = sw.elapsedMilliseconds;
      sw = Stopwatch()..start();
      halfRateReverb(x, 24000, const ReverbSpec());
      final t2 = sw.elapsedMilliseconds;
      sw = Stopwatch()..start();
      Biquad(BiquadType.lowPass, frequency: 1000, sampleRate: 24000).processBuffer(x);
      final t3 = sw.elapsedMilliseconds;
      print('full $t1 half $t2 biquad $t3');
    }
  });
}
