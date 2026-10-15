/// Preferences of the couple specials.
library;

import 'specials_bounds.dart';

final class SpecialsSettings {
  const SpecialsSettings({this.weekStart = SpecialWeeks.defaultWeekStart});

  /// The day the weekly challenge resets (ISO weekday, local time).
  final int weekStart;

  SpecialsSettings copyWith({int? weekStart}) =>
      SpecialsSettings(weekStart: weekStart == null ? this.weekStart : SpecialWeeks.parseWeekStart(weekStart));

  Map<String, Object?> toJson() => {'v': 1, 'ws': weekStart};

  static SpecialsSettings fromJson(Object? json) {
    if (json is! Map) return const SpecialsSettings();
    return SpecialsSettings(weekStart: SpecialWeeks.parseWeekStart(json['ws']));
  }

  @override
  bool operator ==(Object other) => other is SpecialsSettings && other.weekStart == weekStart;

  @override
  int get hashCode => weekStart.hashCode;
}
