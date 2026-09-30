import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/music/composers.dart';
import 'package:madar/features/cinema/engine/audio/music/score.dart';
import 'package:madar/features/cinema/engine/audio/synth/renderer.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';


void main() {
  test('instrument share', () {
    for (final era in Era.values) {
      final score = composeCue(eraScore(era), MusicMood.adventure, 1);
      final insts = score.events.map((e) => (e.inst, e.stem)).toSet();
      final out = <String>[];
      for (final (inst, stem) in insts) {
        final sub = CueScore(style: score.style, mood: score.mood, keyMidi: score.keyMidi, bpm: score.bpm, beatsPerBar: score.beatsPerBar,
          swing: score.swing, swing16: score.swing16, introBars: score.introBars, loopBars: score.loopBars, loops: score.loops, chart: score.chart,
          stems: [for (final s in score.stems) StemSpec(s.name, layer: 0, gain: s.gain, reverb: s.reverb, stereo: s.stereo, pan: s.pan)],
          events: score.events.where((e) => e.inst == inst && e.stem == stem && e.beat >= score.introBeats).toList(), sound: score.sound);
        final r = CueRenderer(targetRmsDb: 0);
        // Render unnormalised: measure relative level via a fixed renderer gain.
        r.render(sub);
        out.add('${inst.name}/${score.stems[stem].name} ${r.lastRawRmsDb.toStringAsFixed(1)}');
      }
      // ignore: avoid_print
      print('${era.name}: ${out.join(', ')}');
    }
  });
}
