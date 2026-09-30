import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/music/composers.dart';
import 'package:madar/features/cinema/engine/audio/synth/renderer.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';

import 'audio_analysis.dart';
import 'preview_util.dart';

void main() {
  final eras =
      (const String.fromEnvironment('ERAS').isEmpty ? Era.values.map((e) => e.name).join(',') : const String.fromEnvironment('ERAS')).split(
        ',',
      );
  final moods =
      (const String.fromEnvironment('MOODS').isEmpty
              ? MusicMood.values.map((e) => e.name).join(',')
              : const String.fromEnvironment('MOODS'))
          .split(',');
  for (final era in Era.values.where((e) => eras.contains(e.name))) {
    for (final mood in MusicMood.values.where((m) => moods.contains(m.name))) {
      test('preview ${era.name} ${mood.name}', skip: _skip, () {
        final style = eraScore(era);
        final score = composeCue(style, mood, 1);
        final cue = CueRenderer().render(score);
        final mix = mixdown(cue);
        writePreview('${era.name}_${mood.name}', mix);
        writeSpectrogram('${era.name}_${mood.name}', mix);
        final loop = mixdown(cue, loops: 1);
        final spec = Spectrum.of(mix.mono, mix.sampleRate);
        final seams = [for (final s in cue.stems) Pcm.decode(s.loop)].map((p) => seamScore(p.channels.first).toStringAsFixed(2)).join('/');
        // ignore: avoid_print
        print(
          '${era.name.padRight(11)} ${mood.name.padRight(9)} '
          'bpm ${score.bpm.toStringAsFixed(0)} loop ${cue.info.loopSeconds.toStringAsFixed(1)}s '
          'peak ${peakDb(mix.channels[0]).toStringAsFixed(1)} rms ${rmsDb(loop.mono, mix.sampleRate).toStringAsFixed(1)} '
          'cent ${spec.centroid.toStringAsFixed(0)} roll ${spec.rolloff().toStringAsFixed(0)} '
          'seam $seams events ${score.events.length} ${cue.renderMs}ms ${(cue.decodedBytes / 1e6).toStringAsFixed(1)}MB',
        );
      });
    }
  }
}

final _skip = Platform.environment['MADAR_AUDIO_PREVIEW_DIR'] == null ? 'set MADAR_AUDIO_PREVIEW_DIR to render previews' : null;
