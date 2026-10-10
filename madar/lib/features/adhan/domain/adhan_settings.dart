import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'adhan_slot.dart';
import 'adhan_sound.dart';

/// Per-prayer alert settings.
@immutable
class PrayerAlert {
  const PrayerAlert({this.adhan = true, this.preMinutes = 0});

  /// Call the adhan at the prayer's time.
  final bool adhan;

  /// Remind this many minutes before the adhan (0 = off).
  final int preMinutes;

  bool get hasReminder => preMinutes > 0;

  PrayerAlert copyWith({bool? adhan, int? preMinutes}) =>
      PrayerAlert(adhan: adhan ?? this.adhan, preMinutes: preMinutes ?? this.preMinutes);

  Map<String, Object?> toJson() => {'adhan': adhan, 'pre': preMinutes};

  static PrayerAlert fromJson(Object? raw) {
    if (raw is! Map) return const PrayerAlert();
    final pre = raw['pre'];
    return PrayerAlert(
      adhan: raw['adhan'] is bool ? raw['adhan'] as bool : true,
      preMinutes: pre is num ? AdhanSettings.clampMinutes(pre.round()) : 0,
    );
  }

  @override
  bool operator ==(Object other) => other is PrayerAlert && other.adhan == adhan && other.preMinutes == preMinutes;

  @override
  int get hashCode => Object.hash(adhan, preMinutes);
}

/// Everything the user decides about the adhan. Stored encrypted in
/// `key_values` under [storageKey]; a fresh install uses the defaults
/// (every adhan on, Madar's own tanbih tones, no reminders).
@immutable
class AdhanSettings {
  const AdhanSettings({
    this.alerts = const {},
    this.sunriseAlert = false,
    this.sunriseMinutesBefore = 0,
    this.fajrSound = const AdhanSoundRef.tone(TanbihTone.dawn),
    this.sound = const AdhanSoundRef.tone(TanbihTone.brass),
    this.vibrate = true,
    this.fullScreen = true,
    this.quietMinutes = 20,
    this.snoozeMinutes = 5,
    this.muezzins = const [],
  });

  static const storageKey = 'adhan.settings';
  static const version = 1;

  /// Choices offered for reminders / sunrise lead / quiet time (minutes).
  static const reminderChoices = [0, 5, 10, 15, 20, 30];
  static const sunriseChoices = [0, 10, 15, 20, 30];
  static const quietChoices = [0, 10, 20, 30];
  static const snoozeChoices = [3, 5, 10];

  /// Per prayer (missing entries mean the default [PrayerAlert]).
  final Map<AdhanSlot, PrayerAlert> alerts;

  /// A gentle alert at sunrise (the end of Fajr's time).
  final bool sunriseAlert;

  /// Alert this many minutes before sunrise (0 = at sunrise).
  final int sunriseMinutesBefore;

  /// Fajr may use its own muezzin / tone.
  final AdhanSoundRef fajrSound;

  /// The muezzin / tone of Dhuhr, Asr, Maghrib and Isha.
  final AdhanSoundRef sound;
  final bool vibrate;

  /// Show the full-screen adhan (also over the lock screen).
  final bool fullScreen;

  /// Game music and the ambient bed stay muted this long after each adhan
  /// (the prayer itself); 0 = only while the adhan sounds.
  final int quietMinutes;

  /// Length of a pre-adhan snooze.
  final int snoozeMinutes;

  /// Recordings the user attached.
  final List<CustomMuezzin> muezzins;

  PrayerAlert alertOf(AdhanSlot slot) => alerts[slot] ?? const PrayerAlert();

  AdhanSoundRef soundFor(AdhanSlot slot) => slot == AdhanSlot.fajr ? fajrSound : sound;

  CustomMuezzin? muezzinById(String? id) {
    for (final m in muezzins) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// [ref] if it still resolves (a deleted recording falls back to the
  /// built-in default of the slot).
  AdhanSoundRef resolve(AdhanSoundRef ref, AdhanSlot slot) {
    if (ref.kind == AdhanSoundKind.file && muezzinById(ref.fileId) == null) {
      return AdhanSoundRef.tone(slot == AdhanSlot.fajr ? TanbihTone.dawn : TanbihTone.brass);
    }
    return ref;
  }

  /// Whether any adhan, reminder or sunrise alert is on.
  bool get anyEnabled => sunriseAlert || AdhanSlot.prayers.any((s) => alertOf(s).adhan || alertOf(s).hasReminder);

  static int clampMinutes(int m) => m.clamp(0, 120);

  AdhanSettings copyWith({
    Map<AdhanSlot, PrayerAlert>? alerts,
    bool? sunriseAlert,
    int? sunriseMinutesBefore,
    AdhanSoundRef? fajrSound,
    AdhanSoundRef? sound,
    bool? vibrate,
    bool? fullScreen,
    int? quietMinutes,
    int? snoozeMinutes,
    List<CustomMuezzin>? muezzins,
  }) => AdhanSettings(
    alerts: alerts ?? this.alerts,
    sunriseAlert: sunriseAlert ?? this.sunriseAlert,
    sunriseMinutesBefore: sunriseMinutesBefore ?? this.sunriseMinutesBefore,
    fajrSound: fajrSound ?? this.fajrSound,
    sound: sound ?? this.sound,
    vibrate: vibrate ?? this.vibrate,
    fullScreen: fullScreen ?? this.fullScreen,
    quietMinutes: quietMinutes ?? this.quietMinutes,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    muezzins: muezzins ?? this.muezzins,
  );

  /// Sets [slot]'s alert.
  AdhanSettings withAlert(AdhanSlot slot, PrayerAlert alert) => copyWith(alerts: {...alerts, slot: alert});

  /// Adds a recording (replacing one with the same id).
  AdhanSettings withMuezzin(CustomMuezzin m) => copyWith(
    muezzins: [
      for (final x in muezzins)
        if (x.id != m.id) x,
      m,
    ],
  );

  /// Removes a recording; prayers that used it fall back to the default
  /// tones.
  AdhanSettings withoutMuezzin(String id) {
    final gone = AdhanSoundRef.file(id);
    return copyWith(
      muezzins: [
        for (final x in muezzins)
          if (x.id != id) x,
      ],
      fajrSound: fajrSound == gone ? const AdhanSoundRef.tone(TanbihTone.dawn) : fajrSound,
      sound: sound == gone ? const AdhanSoundRef.tone(TanbihTone.brass) : sound,
    );
  }

  Map<String, Object?> toJson() => {
    'v': version,
    'alerts': {for (final s in AdhanSlot.prayers) s.name: alertOf(s).toJson()},
    'sunrise': sunriseAlert,
    'sunriseBefore': sunriseMinutesBefore,
    'fajrSound': fajrSound.key,
    'sound': sound.key,
    'vibrate': vibrate,
    'fullScreen': fullScreen,
    'quiet': quietMinutes,
    'snooze': snoozeMinutes,
    'muezzins': [for (final m in muezzins) m.toJson()],
  };

  /// Tolerant: unknown or malformed values fall back to the defaults.
  factory AdhanSettings.fromJson(Object? raw) {
    const d = AdhanSettings();
    if (raw is! Map) return d;
    final alerts = <AdhanSlot, PrayerAlert>{};
    final a = raw['alerts'];
    if (a is Map) {
      for (final e in a.entries) {
        final slot = AdhanSlot.byName(e.key);
        if (slot != null && slot.isPrayer) alerts[slot] = PrayerAlert.fromJson(e.value);
      }
    }
    int minutes(Object? v, int fallback) => v is num ? clampMinutes(v.round()) : fallback;
    bool flag(Object? v, bool fallback) => v is bool ? v : fallback;
    final muezzins = <CustomMuezzin>[];
    final ids = <String>{};
    final list = raw['muezzins'];
    if (list is List) {
      for (final item in list) {
        final m = CustomMuezzin.fromJson(item);
        if (m != null && ids.add(m.id)) muezzins.add(m);
      }
    }
    final settings = AdhanSettings(
      alerts: alerts,
      sunriseAlert: flag(raw['sunrise'], d.sunriseAlert),
      sunriseMinutesBefore: minutes(raw['sunriseBefore'], d.sunriseMinutesBefore),
      fajrSound: AdhanSoundRef.parse(raw['fajrSound']) ?? d.fajrSound,
      sound: AdhanSoundRef.parse(raw['sound']) ?? d.sound,
      vibrate: flag(raw['vibrate'], d.vibrate),
      fullScreen: flag(raw['fullScreen'], d.fullScreen),
      quietMinutes: minutes(raw['quiet'], d.quietMinutes),
      snoozeMinutes: raw['snooze'] is num ? (raw['snooze'] as num).round().clamp(1, 30) : d.snoozeMinutes,
      muezzins: muezzins,
    );
    // A sound pointing at a recording that no longer exists → default.
    return settings.copyWith(
      fajrSound: settings.resolve(settings.fajrSound, AdhanSlot.fajr),
      sound: settings.resolve(settings.sound, AdhanSlot.dhuhr),
    );
  }

  /// Canonical JSON (equality, sync keys).
  String get canonical => jsonEncode(toJson());

  @override
  bool operator ==(Object other) => other is AdhanSettings && other.canonical == canonical;

  @override
  int get hashCode => canonical.hashCode;
}
