import 'package:flutter/foundation.dart';

/// What the owner can tune about Ramadan: the atmosphere, which reminders are
/// on and how long before the event they ring.
///
/// The Hijri day shift is NOT here: it is the prayer settings' own
/// `hijriOffsetDays` (one setting, never two), read where the calendar is built.
@immutable
class RamadanConfig {
  const RamadanConfig({
    this.atmosphere = true,
    this.iftarReminder = true,
    this.iftarLeadMinutes = defaultIftarLead,
    this.suhoorReminder = true,
    this.suhoorLeadMinutes = defaultSuhoorLead,
    this.taraweehReminder = true,
    this.lastTenReminder = true,
    this.hubKhatmah = true,
  });

  factory RamadanConfig.fromJson(Object? json) {
    if (json is! Map) return const RamadanConfig();
    bool b(Object? v, bool fallback) => v is bool ? v : fallback;
    int n(Object? v, int fallback) => v is num && v.isFinite ? v.round() : fallback;
    return RamadanConfig(
      atmosphere: b(json['atmosphere'], true),
      iftarReminder: b(json['iftarReminder'], true),
      iftarLeadMinutes: n(json['iftarLeadMinutes'], defaultIftarLead).clamp(minLead, maxLead),
      suhoorReminder: b(json['suhoorReminder'], true),
      suhoorLeadMinutes: n(json['suhoorLeadMinutes'], defaultSuhoorLead).clamp(minLead, maxLead),
      taraweehReminder: b(json['taraweehReminder'], true),
      lastTenReminder: b(json['lastTenReminder'], true),
      hubKhatmah: b(json['hubKhatmah'], true),
    );
  }

  /// Starting values; the owner edits both.
  static const int defaultIftarLead = 15;
  static const int defaultSuhoorLead = 45;
  static const int minLead = 1;
  static const int maxLead = 180;

  /// «أجواء رمضان»: the crescent and lanterns and the warmer tint on the Faith
  /// planet while Ramadan lasts.
  final bool atmosphere;

  /// A reminder [iftarLeadMinutes] before Maghrib.
  final bool iftarReminder;
  final int iftarLeadMinutes;

  /// A reminder [suhoorLeadMinutes] before Fajr.
  final bool suhoorReminder;
  final int suhoorLeadMinutes;

  /// After Isha, each night.
  final bool taraweehReminder;

  /// One more note on each of the last ten nights.
  final bool lastTenReminder;

  /// Today's khatmah portion on the Faith card.
  final bool hubKhatmah;

  int get effectiveIftarLead => iftarLeadMinutes.clamp(minLead, maxLead);
  int get effectiveSuhoorLead => suhoorLeadMinutes.clamp(minLead, maxLead);

  RamadanConfig copyWith({
    bool? atmosphere,
    bool? iftarReminder,
    int? iftarLeadMinutes,
    bool? suhoorReminder,
    int? suhoorLeadMinutes,
    bool? taraweehReminder,
    bool? lastTenReminder,
    bool? hubKhatmah,
  }) => RamadanConfig(
    atmosphere: atmosphere ?? this.atmosphere,
    iftarReminder: iftarReminder ?? this.iftarReminder,
    iftarLeadMinutes: iftarLeadMinutes ?? this.iftarLeadMinutes,
    suhoorReminder: suhoorReminder ?? this.suhoorReminder,
    suhoorLeadMinutes: suhoorLeadMinutes ?? this.suhoorLeadMinutes,
    taraweehReminder: taraweehReminder ?? this.taraweehReminder,
    lastTenReminder: lastTenReminder ?? this.lastTenReminder,
    hubKhatmah: hubKhatmah ?? this.hubKhatmah,
  );

  Map<String, Object?> toJson() => {
    'atmosphere': atmosphere,
    'iftarReminder': iftarReminder,
    'iftarLeadMinutes': effectiveIftarLead,
    'suhoorReminder': suhoorReminder,
    'suhoorLeadMinutes': effectiveSuhoorLead,
    'taraweehReminder': taraweehReminder,
    'lastTenReminder': lastTenReminder,
    'hubKhatmah': hubKhatmah,
  };

  @override
  bool operator ==(Object other) =>
      other is RamadanConfig &&
      other.atmosphere == atmosphere &&
      other.iftarReminder == iftarReminder &&
      other.effectiveIftarLead == effectiveIftarLead &&
      other.suhoorReminder == suhoorReminder &&
      other.effectiveSuhoorLead == effectiveSuhoorLead &&
      other.taraweehReminder == taraweehReminder &&
      other.lastTenReminder == lastTenReminder &&
      other.hubKhatmah == hubKhatmah;

  @override
  int get hashCode => Object.hash(
    atmosphere,
    iftarReminder,
    effectiveIftarLead,
    suhoorReminder,
    effectiveSuhoorLead,
    taraweehReminder,
    lastTenReminder,
    hubKhatmah,
  );
}
