import 'package:flutter/foundation.dart';

import 'body_map.dart';

/// A pain log being written or edited (validated, trimmed values).
@immutable
class PainDraft {
  const PainDraft({
    required this.at,
    required this.score,
    this.locations = const [],
    this.triggers = const [],
    this.points = const [],
    this.notes,
  });

  final DateTime at;

  /// 0–10.
  final int score;
  final List<String> locations;
  final List<String> triggers;
  final List<BodyPoint> points;
  final String? notes;

  PainDraft normalized() => PainDraft(
    at: at,
    score: score.clamp(0, 10),
    locations: _clean(locations),
    triggers: _clean(triggers),
    points: points.take(maxPoints).toList(),
    notes: _note(notes),
  );

  static const int maxPoints = 24;

  PainDraft copyWith({
    DateTime? at,
    int? score,
    List<String>? locations,
    List<String>? triggers,
    List<BodyPoint>? points,
    String? notes,
  }) => PainDraft(
    at: at ?? this.at,
    score: score ?? this.score,
    locations: locations ?? this.locations,
    triggers: triggers ?? this.triggers,
    points: points ?? this.points,
    notes: notes ?? this.notes,
  );
}

/// A mood & stress check-in being written or edited. Every metric is
/// optional: a check-in may be just a face.
@immutable
class MoodDraft {
  const MoodDraft({
    required this.at,
    this.mood,
    this.stress,
    this.anxiety,
    this.energy,
    this.sleepHours,
    this.caffeineCups,
    this.factors = const [],
    this.notes,
  });

  final DateTime at;

  /// 1–5.
  final int? mood;

  /// 0–10.
  final int? stress;
  final int? anxiety;
  final int? energy;

  /// 0–16 in half hours.
  final double? sleepHours;
  final int? caffeineCups;
  final List<String> factors;
  final String? notes;

  static const double maxSleep = 16;
  static const int maxCups = 12;

  bool get isEmpty =>
      mood == null &&
      stress == null &&
      anxiety == null &&
      energy == null &&
      sleepHours == null &&
      caffeineCups == null &&
      factors.isEmpty &&
      (notes == null || notes!.trim().isEmpty);

  MoodDraft normalized() => MoodDraft(
    at: at,
    mood: mood?.clamp(1, 5),
    stress: stress?.clamp(0, 10),
    anxiety: anxiety?.clamp(0, 10),
    energy: energy?.clamp(0, 10),
    sleepHours: sleepHours == null ? null : ((sleepHours!.clamp(0, maxSleep)) * 2).round() / 2,
    caffeineCups: caffeineCups?.clamp(0, maxCups),
    factors: _clean(factors),
    notes: _note(notes),
  );
}

List<String> _clean(List<String> labels) {
  final seen = <String>{};
  return [
    for (final l in labels)
      if (l.trim().isNotEmpty && seen.add(l.trim())) l.trim(),
  ];
}

String? _note(String? n) {
  final t = n?.trim();
  return t == null || t.isEmpty ? null : t;
}
