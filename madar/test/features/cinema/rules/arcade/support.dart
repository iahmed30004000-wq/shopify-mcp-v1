import 'dart:convert';

import 'package:madar/features/cinema/rules/arcade/arcade.dart';

/// Runs [sim] for [ticks] frames of 1/60 s (or the sim's tick) with inputs
/// from [input] and returns the final snapshot as JSON.
String runScripted<S, I>(ArcadeSim<S, I> sim, int frames, I Function(int frame) input, {double? dt}) {
  final step = dt ?? sim.tickSeconds;
  for (var f = 0; f < frames && !sim.isOver; f++) {
    sim.step(step, input(f));
  }
  return jsonEncode(sim.snapshot());
}

/// Jittery frame times (deterministic) between 5 and 40 ms.
double jitterDt(int frame) => 0.005 + ((frame * 7919) % 36) / 1000;
