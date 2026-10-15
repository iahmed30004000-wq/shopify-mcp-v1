import '../../../core/domain/enums.dart';

/// The six moments the adhan feature can announce: the five prayers and
/// sunrise (the end of Fajr's time – an alert, never an adhan).
enum AdhanSlot {
  fajr,
  sunrise,
  dhuhr,
  asr,
  maghrib,
  isha;

  /// The five prayers, in the day's order.
  static const prayers = [fajr, dhuhr, asr, maghrib, isha];

  bool get isPrayer => this != sunrise;

  /// The obligatory prayer of this slot (`null` for sunrise).
  Prayer? get prayer => switch (this) {
    fajr => Prayer.fajr,
    dhuhr => Prayer.dhuhr,
    asr => Prayer.asr,
    maghrib => Prayer.maghrib,
    isha => Prayer.isha,
    sunrise => null,
  };

  static AdhanSlot? fromPrayer(Prayer p) => switch (p) {
    Prayer.fajr => fajr,
    Prayer.dhuhr => dhuhr,
    Prayer.asr => asr,
    Prayer.maghrib => maghrib,
    Prayer.isha => isha,
    _ => null,
  };

  static AdhanSlot? byName(Object? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// What an adhan notification announces.
enum AdhanKind {
  /// The call to prayer at the prayer's exact time (full-screen).
  adhan,

  /// A gentle reminder some minutes before the adhan.
  preAdhan,

  /// Sunrise: the time of Fajr has ended (or is about to).
  sunrise,

  /// "Test adhan now" from the settings (full-screen, like a real one).
  test,

  /// A snoozed pre-adhan reminder.
  snooze;

  static AdhanKind? byName(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }

  /// Plays the muezzin on the adhan channel and may launch full-screen.
  bool get isCall => this == adhan || this == test;
}
