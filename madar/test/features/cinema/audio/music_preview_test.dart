import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/music/composers.dart';
import 'package:madar/features/cinema/engine/audio/synth/renderer.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';

import 'audio_analysis.dart';
import 'preview_util.dart';

/// Opt-in listening reel: renders every era × mood, writes a WAV, a
/// spectrogram and a piano roll per cue to `MADAR_AUDIO_PREVIEW_DIR`, prints
/// the numbers and asserts the mix spec on the full catalogue (the routine
/// `render_quality_test` samples two moods per era).
///
/// `--dart-define=ERAS=silent,noir --dart-define=MOODS=title,boss` narrows it.
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
        writePianoRoll('${era.name}_${mood.name}', score);
        final one = mixdown(cue, loops: 1);
        final sr = mix.sampleRate;
        final introN = (cue.info.introSeconds * sr).round();
        final loopN = (cue.info.loopSeconds * sr).round();
        final loopOnly = Float64List.sublistView(one.mono, introN, introN + loopN);
        final spec = Spectrum.of(mix.mono, sr);
        final seams = [for (final s in cue.stems) Pcm.decode(s.loop)].map((p) => seamScore(p.channels.first).toStringAsFixed(2)).join('/');
        final what = '${era.name} ${mood.name}';
        final loopRms = rmsDb(loopOnly, sr);
        // ignore: avoid_print
        print(
          '${era.name.padRight(11)} ${mood.name.padRight(9)} '
          'bpm ${score.bpm.toStringAsFixed(0)} loop ${cue.info.loopSeconds.toStringAsFixed(1)}s '
          'peak ${peakDb(mix.channels[0]).toStringAsFixed(1)} rms ${loopRms.toStringAsFixed(1)} '
          'cent ${spec.centroid.toStringAsFixed(0)} roll ${spec.rolloff().toStringAsFixed(0)} '
          'seam $seams events ${score.events.length} ${cue.renderMs}ms ${(cue.decodedBytes / 1e6).toStringAsFixed(1)}MB',
        );

        // The mix spec, on every cue of the catalogue.
        expect(peakDb(mix.channels[0]), lessThanOrEqualTo(-1.0), reason: '$what: no clipping (L)');
        expect(peakDb(mix.channels[1]), lessThanOrEqualTo(-1.0), reason: '$what: no clipping (R)');
        if (cue.info.loops) {
          expect(loopRms, inInclusiveRange(-23, -18), reason: '$what: loop loudness on target');
        } else {
          // Jingles are levelled on the jingle itself; the vamp after it
          // sits underneath.
          final jingle = Float64List.sublistView(one.mono, 0, introN);
          expect(rmsDb(jingle, sr), inInclusiveRange(-23, -17), reason: '$what: jingle loudness on target');
          expect(loopRms, lessThan(-17), reason: '$what: the vamp stays under the jingle');
        }
        for (final s in cue.stems) {
          for (final ch in Pcm.decode(s.loop).channels) {
            expect(seamClickScore(ch, sr), lessThan(2.5), reason: '$what ${s.spec.name}: click-free loop point');
            expect(mean(ch).abs(), lessThan(0.005), reason: '$what ${s.spec.name}: no DC');
          }
        }
        expect(seamClickScore(loopOnly, sr), lessThan(2.5), reason: '$what: click-free loop point in the mix');
        expect(cue.renderMs, lessThan(4000), reason: '$what: renders well inside the 1.5 s budget on a phone (JIT here)');
      });
    }
  }
}

final _skip = Platform.environment['MADAR_AUDIO_PREVIEW_DIR'] == null ? 'set MADAR_AUDIO_PREVIEW_DIR to render previews' : null;
