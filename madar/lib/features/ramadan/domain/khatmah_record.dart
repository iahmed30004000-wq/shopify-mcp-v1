import 'package:flutter/foundation.dart';

import 'khatmah_plan.dart';
import 'ramadan_calendar.dart';

/// One Ramadan's khatmah: the plan (its start, days and the daily ceiling he
/// set) and how far he has read.
@immutable
class KhatmahRecord {
  const KhatmahRecord({required this.hijriYear, required this.plan, required this.progress});

  /// The plan nobody has stored yet: finishes inside [span], at the default
  /// ceiling. It is shown and used as is; the first change stores it.
  factory KhatmahRecord.defaultFor(RamadanSpan span, {int totalPages = 604}) => KhatmahRecord(
    hijriYear: span.hijriYear,
    plan: KhatmahPlan.forSpan(span, totalPages: totalPages),
    progress: KhatmahProgress(),
  );

  static KhatmahRecord? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final year = json['hijriYear'];
    final plan = json['plan'];
    if (year is! int || year < 1 || plan is! Map<String, dynamic>) return null;
    final progress = json['progress'];
    return KhatmahRecord(
      hijriYear: year,
      plan: KhatmahPlan.fromJson(plan),
      progress: progress is Map<String, dynamic> ? KhatmahProgress.fromJson(progress) : KhatmahProgress(),
    );
  }

  final int hijriYear;
  final KhatmahPlan plan;
  final KhatmahProgress progress;

  KhatmahRecord copyWith({KhatmahPlan? plan, KhatmahProgress? progress}) =>
      KhatmahRecord(hijriYear: hijriYear, plan: plan ?? this.plan, progress: progress ?? this.progress);

  Map<String, Object?> toJson() => {'hijriYear': hijriYear, 'plan': plan.toJson(), 'progress': progress.toJson()};

  @override
  bool operator ==(Object other) =>
      other is KhatmahRecord && other.hijriYear == hijriYear && other.plan == plan && other.progress == progress;

  @override
  int get hashCode => Object.hash(hijriYear, plan, progress);
}
