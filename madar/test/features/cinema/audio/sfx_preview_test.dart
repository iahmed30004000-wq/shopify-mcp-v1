@Tags(['audio_preview'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/audio/sfx/sfx_synth.dart';
import 'package:madar/features/cinema/engine/core/era.dart';

import 'audio_analysis.dart';
import 'preview_util.dart';

void main() {
  for (final era in Era.values) {
    test('sfx preview ${era.name}', () {
      final sw = Stopwatch()..start();
      final kit = SfxSynth(era).renderKit();
      final ms = sw.elapsedMilliseconds;
      // One WAV per era: every sound in turn with a gap.
      final clips = kit.entries.map((e) => (e.key, Pcm.decode(e.value))).toList();
      final sr = clips.first.$2.sampleRate;
      final gap = (0.25 * sr).round();
      final total = clips.fold(0, (a, c) => a + c.$2.frames + gap);
      final all = Pcm(sr, [Float64List(total)]);
      var at = 0;
      final lines = <String>[];
      for (final (key, p) in clips) {
        all.channels.first.setRange(at, at + p.frames, p.channels.first);
        at += p.frames + gap;
        final x = p.channels.first;
        lines.add('${key.padRight(20)} ${(p.seconds * 1000).round().toString().padLeft(5)}ms peak ${peakDb(x).toStringAsFixed(1)} '
            'rms ${rmsDb(x, sr).toStringAsFixed(1)} start ${x.first.abs().toStringAsFixed(4)} end ${x.last.abs().toStringAsFixed(4)} '
            'cent ${Spectrum.of(x.length >= 2048 ? x : Float64List(2048)..setRange(0, x.length, x), sr).centroid.toStringAsFixed(0)}');
      }
      writePreview('sfx_${era.name}', all);
      // ignore: avoid_print
      print('== ${era.name} kit ${ms}ms\n${lines.join('\n')}');
    });
  }
}
