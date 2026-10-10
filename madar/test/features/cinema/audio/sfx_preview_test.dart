import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/music/stingers.dart';
import 'package:madar/features/cinema/engine/audio/sfx/sfx_synth.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';

import 'audio_analysis.dart';
import 'preview_util.dart';

void main() {
  for (final era in Era.values) {
    test('stinger preview ${era.name}', skip: _skip, () => _stingerReel(era));
  }
  for (final era in Era.values) {
    test('sfx preview ${era.name}', skip: _skip, () {
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
        // Every effect of every era: under the ceiling, at rest at both
        // ends (no clicks), short.
        expect(peakDb(x), lessThanOrEqualTo(-0.9), reason: '${era.name} $key peak');
        expect(x.first.abs(), lessThan(0.02), reason: '${era.name} $key starts at rest');
        expect(x.last.abs(), lessThan(0.002), reason: '${era.name} $key ends at rest');
        expect(p.seconds, lessThanOrEqualTo(key == 'extra:gong' ? 4.5 : 3.0), reason: '${era.name} $key length');
        lines.add(
          '${key.padRight(20)} ${(p.seconds * 1000).round().toString().padLeft(5)}ms peak ${peakDb(x).toStringAsFixed(1)} '
          'rms ${rmsDb(x, sr).toStringAsFixed(1)} start ${x.first.abs().toStringAsFixed(4)} end ${x.last.abs().toStringAsFixed(4)} '
          'cent ${Spectrum.of(x.length >= 2048 ? x : Float64List(2048)
            ..setRange(0, x.length, x), sr).centroid.toStringAsFixed(0)}',
        );
      }
      writePreview('sfx_${era.name}', all);
      writeSpectrogram('sfx_${era.name}', all, seconds: all.seconds);
      // ignore: avoid_print
      print('== ${era.name} kit ${ms}ms\n${lines.join('\n')}');
    });
  }
}

void _stingerReel(Era era) {
  final kit = renderStingerKit(eraScore(era));
  final parts = <Pcm>[];
  for (final s in Stinger.values) {
    final c = kit.clips[s]!;
    final tonal = c.major == null ? null : Pcm.decode(c.major!);
    final drums = c.drums == null ? null : Pcm.decode(c.drums!);
    final n = [tonal?.frames ?? 0, drums?.frames ?? 0].reduce((a, b) => a > b ? a : b);
    final sr = (tonal ?? drums)!.sampleRate;
    final x = Float64List(n);
    for (final p in [tonal, drums].nonNulls) {
      for (var i = 0; i < p.frames; i++) {
        x[i] += p.channels.first[i];
      }
    }
    parts.add(Pcm(sr, [x]));
  }
  final sr = parts.first.sampleRate;
  final gap = (0.4 * sr).round();
  final total = parts.fold(0, (a, p) => a + p.frames + gap);
  final reel = Float64List(total);
  var at = 0;
  for (final p in parts) {
    reel.setRange(at, at + p.frames, p.channels.first);
    at += p.frames + gap;
  }
  final pcm = Pcm(sr, [reel]);
  expect(peakDb(reel), lessThanOrEqualTo(-1.0), reason: '${era.name} stingers: tonal + drums never clip together');
  writePreview('stingers_${era.name}', pcm);
  writeSpectrogram('stingers_${era.name}', pcm, seconds: pcm.seconds);
  // ignore: avoid_print
  print('== ${era.name} stingers ${(kit.bytes / 1e6).toStringAsFixed(2)}MB peak ${peakDb(reel).toStringAsFixed(1)} dBFS');
}

final _skip = Platform.environment['MADAR_AUDIO_PREVIEW_DIR'] == null ? 'set MADAR_AUDIO_PREVIEW_DIR to render previews' : null;
