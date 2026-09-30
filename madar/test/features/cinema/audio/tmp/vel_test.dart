import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/music/composers.dart';
import 'package:madar/features/cinema/engine/audio/music/score.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';

void main() {
  test('vel', () {
    final s = composeCue(eraScore(Era.vhs), MusicMood.adventure, 1);
    // ignore: avoid_print
    print(s.events.where((e) => e.inst == Inst.synthArp).map((e) => e.vel.toStringAsFixed(2)).toSet());
    final t = composeCue(eraScore(Era.technicolor), MusicMood.adventure, 1);
    // ignore: avoid_print
    print(t.events.where((e) => e.inst == Inst.trumpet).map((e) => e.vel.toStringAsFixed(2)).toSet());
  });
}
