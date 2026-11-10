import '../../orbit/domain/prayer_schedule.dart';

/// Pure transforms of [PrayerSettings] (the settings screen and the
/// controller use exactly these; unit-tested).
abstract final class PrayerSettingsChanges {
  static const minAngle = 10.0;
  static const maxAngle = 22.0;
  static const angleStep = 0.5;
  static const minIshaInterval = 60;
  static const maxIshaInterval = 150;
  static const maxAdjustment = 30;
  static const maxHijriOffset = 2;

  /// Selects [method]. Switching to [PrayerMethod.custom] starts from the
  /// current method's angles (and its fixed Isha interval, if it has one) and
  /// keeps that preset as [PrayerSettings.customBase] – its minute offsets
  /// and Maghrib angle stay – so the times only change once the user edits
  /// them; a preset records its own angles so the stored settings describe
  /// what is computed.
  static PrayerSettings method(PrayerSettings s, PrayerMethod method) {
    if (method == s.method) return s;
    final current = s.method.parameters();
    if (method == PrayerMethod.custom) {
      final interval = s.method == PrayerMethod.custom ? s.ishaIntervalMin : current.ishaInterval;
      return s.copyWith(
        method: PrayerMethod.custom,
        customBase: s.method,
        fajrAngle: _snap(s.method == PrayerMethod.custom ? s.fajrAngle : current.fajrAngle),
        ishaAngle: _snap(
          s.method == PrayerMethod.custom
              ? s.ishaAngle
              : (current.ishaAngle > 0 ? current.ishaAngle : PrayerMethod.muslimWorldLeague.parameters().ishaAngle),
        ),
        ishaIntervalMin: (interval ?? 0) > 0 ? interval : null,
      );
    }
    final p = method.parameters();
    return s.copyWith(
      method: method,
      fajrAngle: p.fajrAngle,
      ishaAngle: p.ishaAngle,
      ishaIntervalMin: null,
      customBase: null,
    );
  }

  /// Custom Fajr angle (switches to [PrayerMethod.custom]).
  static PrayerSettings fajrAngle(PrayerSettings s, double degrees) =>
      _custom(s).copyWith(fajrAngle: _clampAngle(degrees));

  /// Custom Isha angle (switches to [PrayerMethod.custom] and drops a fixed
  /// Isha interval).
  static PrayerSettings ishaAngle(PrayerSettings s, double degrees) =>
      _custom(s).copyWith(ishaAngle: _clampAngle(degrees), ishaIntervalMin: null);

  /// Custom Isha as [minutes] after Maghrib; null returns to the Isha angle.
  static PrayerSettings ishaInterval(PrayerSettings s, int? minutes) =>
      _custom(s).copyWith(ishaIntervalMin: minutes?.clamp(minIshaInterval, maxIshaInterval));

  static PrayerSettings hanafiAsr(PrayerSettings s, bool hanafi) => s.copyWith(hanafiAsr: hanafi);

  static PrayerSettings highLatitude(PrayerSettings s, HighLatitudeMode mode) => s.copyWith(highLatitude: mode);

  /// Sets the manual offset of [key] (see [PrayerAdjustmentKeys]), clamped to
  /// ±[maxAdjustment] minutes; 0 removes it.
  static PrayerSettings adjustment(PrayerSettings s, String key, int minutes) {
    if (!PrayerAdjustmentKeys.all.contains(key)) return s;
    final next = Map<String, int>.of(s.adjustmentsMin);
    final v = minutes.clamp(-maxAdjustment, maxAdjustment);
    if (v == 0) {
      next.remove(key);
    } else {
      next[key] = v;
    }
    return s.copyWith(adjustmentsMin: next);
  }

  static PrayerSettings resetAdjustments(PrayerSettings s) => s.copyWith(adjustmentsMin: const {});

  static PrayerSettings hijriOffset(PrayerSettings s, int days) =>
      s.copyWith(hijriOffsetDays: days.clamp(-maxHijriOffset, maxHijriOffset));

  static PrayerSettings hijriAtMaghrib(PrayerSettings s, bool value) => s.copyWith(hijriAtMaghrib: value);

  static PrayerSettings clock24h(PrayerSettings s, bool value) => s.copyWith(clock24h: value);

  static PrayerSettings _custom(PrayerSettings s) =>
      s.method == PrayerMethod.custom ? s : method(s, PrayerMethod.custom);

  static double _clampAngle(double v) => _snap(v.clamp(minAngle, maxAngle));

  /// Angles move in half-degree steps; preset angles such as 18.2° or 17.7°
  /// are kept as they are.
  static double _snap(double v) => ((v * 10).roundToDouble()) / 10;
}
