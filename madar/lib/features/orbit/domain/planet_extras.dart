import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import 'planet_archetypes.dart';

/// Data behind the archetype-specific shader uniforms (`uExtra`), gathered
/// by the data layer.
@immutable
class ExtrasInputs {
  const ExtrasInputs({
    this.peopleCount = 0,
    this.boardCount = 0,
    this.cardsTouched7d = 0,
    this.cardsDone7d = 0,
    this.savingsRatio,
    this.growthFraction,
    this.fastingNow = false,
    this.workoutsToday = 0,
    this.workoutsExpectedToday = 0,
    this.workoutMinutesToday = 0,
    this.upcomingTrips = 0,
  });

  /// People shown as moons around Family.
  final int peopleCount;

  /// Kanban boards (one per country / business).
  final int boardCount;

  /// Cards created, moved or edited in the last 7 days.
  final int cardsTouched7d;

  /// Cards moved to done in the last 7 days.
  final int cardsDone7d;

  /// Saved ÷ target over all savings jars (null without jars).
  final double? savingsRatio;

  /// Mean progress ÷ target over active learning goals (null without goals).
  final double? growthFraction;

  /// A fasting session is running right now.
  final bool fastingNow;

  /// Workouts logged today.
  final int workoutsToday;

  /// Exercises scheduled for today's weekday.
  final int workoutsExpectedToday;

  /// Minutes trained today (logged durations).
  final int workoutMinutesToday;

  /// Trips not yet started (planned, starting today or later).
  final int upcomingTrips;
}

/// `uExtra` for every planet, derived from its data.
///
/// The value follows the uniform contract of the shader that draws the
/// planet ([OrbitArchetypes.shaderFor]). Data only drives it when the planet
/// is the archetype's natural owner (the Work planet in its industrial
/// style); otherwise the style defaults apply ([OrbitArchetypes.styleExtras]).
abstract final class PlanetExtras {
  static List<double> of({required String key, required PlanetArchetype archetype, required ExtrasInputs data}) {
    if (OrbitArchetypes.naturalKey(archetype) != key) return List.of(OrbitArchetypes.styleExtras(archetype));
    return switch (archetype) {
      // Pattern density: shader default.
      PlanetArchetype.faith => [0, 0, 0, 0],
      // Reserved.
      PlanetArchetype.ocean => [0, 0, 0, 0],
      // Hearth density: family size / 4 (0 → shader default).
      PlanetArchetype.terracotta => [hearthDensity(data.peopleCount), 0, 0, 0],
      // One metropolis per board; activity drives the light density.
      PlanetArchetype.industrial => [data.boardCount.clamp(0, 8).toDouble(), workActivity(data), 0, 0],
      // Facets default; gold richness = savings ratio (0 → follows score).
      PlanetArchetype.crystal => [0, goldRichness(data.savingsRatio), 0, 0],
      // Forest coverage = goal progress (0 → follows score).
      PlanetArchetype.verdant => [growthCoverage(data.growthFraction), 0, 0, 0],
      // Fasting wave + today's training intensity.
      PlanetArchetype.volcanic => [data.fastingNow ? 1 : 0, trainingIntensity(data), 0, 0],
      // One ship per upcoming trip.
      PlanetArchetype.gasGiant => [data.upcomingTrips.clamp(0, 6).toDouble(), 0, 0, 0],
      PlanetArchetype.ice || PlanetArchetype.desert => List.of(OrbitArchetypes.styleExtras(archetype)),
    };
  }

  /// People / 4, within 0.5..2 (no people → 0 = shader default).
  static double hearthDensity(int people) => people <= 0 ? 0 : (people / 4).clamp(0.5, 2.0);

  /// 0.6 (the shader's default) without boards; otherwise 0.3..1 rising with
  /// recent card movement and completions.
  static double workActivity(ExtrasInputs d) {
    if (d.boardCount == 0) return 0.6;
    final n = d.cardsTouched7d + d.cardsDone7d;
    return 0.3 + 0.7 * (1 - math.exp(-n / 6));
  }

  /// The savings ratio, floored at 0.05 so "no savings yet" still overrides
  /// the score (0 would mean "follow the score").
  static double goldRichness(double? ratio) => ratio == null ? 0 : ratio.clamp(0.05, 1.0);

  /// The goal progress, floored at 0.02 for the same reason.
  static double growthCoverage(double? fraction) => fraction == null ? 0 : fraction.clamp(0.02, 1.0);

  /// max(done ÷ scheduled today, minutes ÷ 60), 0..1.
  static double trainingIntensity(ExtrasInputs d) {
    final bySessions = d.workoutsToday / math.max(1, d.workoutsExpectedToday);
    final byMinutes = d.workoutMinutesToday / 60;
    return math.max(bySessions, byMinutes).clamp(0.0, 1.0);
  }
}
