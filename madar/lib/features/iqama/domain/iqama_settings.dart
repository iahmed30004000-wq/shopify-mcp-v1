import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../adhan/domain/adhan_slot.dart';
import '../../adhan/domain/adhan_sound.dart';

/// One prayer's iqama: on or off on its own, and how long after the adhan
/// it calls.
@immutable
class IqamaPrayer {
  const IqamaPrayer({this.on = true, this.minutes = IqamaSettings.defaultMinutes});

  /// Call the iqama for this prayer (its adhan is a separate switch).
  final bool on;

  /// Minutes after the adhan (0 = with the adhan itself).
  final int minutes;

  IqamaPrayer copyWith({bool? on, int? minutes}) =>
      IqamaPrayer(on: on ?? this.on, minutes: minutes ?? this.minutes);

  Map<String, Object?> toJson() => {'on': on, 'm': minutes};

  static IqamaPrayer fromJson(Object? raw, {int fallbackMinutes = IqamaSettings.defaultMinutes}) {
    if (raw is! Map) return IqamaPrayer(minutes: fallbackMinutes);
    final m = raw['m'];
    return IqamaPrayer(
      on: raw['on'] is bool ? raw['on'] as bool : true,
      minutes: m is num ? IqamaSettings.clampMinutes(m.round()) : fallbackMinutes,
    );
  }

  @override
  bool operator ==(Object other) => other is IqamaPrayer && other.on == on && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(on, minutes);
}

/// Everything the user decides about «الإقامة». Stored encrypted in
/// `key_values` under [storageKey] (so it goes with a backup and comes back
/// with a restore, exactly like the adhan's own settings); a fresh install
/// uses the defaults: every prayer on, [defaultMinutes] after its adhan,
/// Friday's Dhuhr with the same offset until he changes it, Madar's own
/// short tanbih tone.
@immutable
class IqamaSettings {
  const IqamaSettings({
    this.prayers = const {},
    this.jumuah = const IqamaPrayer(),
    this.sound = const AdhanSoundRef.tone(TanbihTone.chime),
    this.vibrate = true,
    this.snoozeMinutes = 5,
  });

  static const storageKey = 'iqama.settings';
  static const version = 1;

  /// The owner's default: a quarter of an hour after the adhan.
  static const defaultMinutes = 15;

  /// Offsets offered on the settings sheet (minutes after the adhan).
  static const minuteChoices = [0, 5, 10, 15, 20, 25, 30, 45];

  /// Lengths offered for the one «بعد شوي» snooze.
  static const snoozeChoices = [3, 5, 10];

  /// Per prayer (a missing entry means the default [IqamaPrayer]).
  final Map<AdhanSlot, IqamaPrayer> prayers;

  /// Friday's Dhuhr – «الجمعة» – with its own offset and its own switch.
  final IqamaPrayer jumuah;

  /// The iqama's own sound: a built-in tanbih tone, one of the recordings
  /// attached in the adhan's muezzin library, or silence.
  final AdhanSoundRef sound;
  final bool vibrate;

  /// Length of the single «بعد شوي» snooze.
  final int snoozeMinutes;

  IqamaPrayer of(AdhanSlot slot) => prayers[slot] ?? const IqamaPrayer();

  /// The iqama that applies to [slot] on [day]: Friday's own entry for
  /// Dhuhr on a Friday, the prayer's own otherwise.
  IqamaPrayer on(DateTime day, AdhanSlot slot) =>
      isJumuah(day, slot) ? jumuah : of(slot);

  /// Whether [slot] on [day] is the Friday prayer (a calendar date).
  static bool isJumuah(DateTime day, AdhanSlot slot) =>
      slot == AdhanSlot.dhuhr && DateTime.utc(day.year, day.month, day.day).weekday == DateTime.friday;

  /// Whether any prayer's iqama is on at all.
  bool get anyEnabled => jumuah.on || AdhanSlot.prayers.any((s) => of(s).on);

  static int clampMinutes(int m) => m.clamp(0, 120);

  IqamaSettings copyWith({
    Map<AdhanSlot, IqamaPrayer>? prayers,
    IqamaPrayer? jumuah,
    AdhanSoundRef? sound,
    bool? vibrate,
    int? snoozeMinutes,
  }) => IqamaSettings(
    prayers: prayers ?? this.prayers,
    jumuah: jumuah ?? this.jumuah,
    sound: sound ?? this.sound,
    vibrate: vibrate ?? this.vibrate,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
  );

  /// Sets [slot]'s iqama.
  IqamaSettings withPrayer(AdhanSlot slot, IqamaPrayer value) => copyWith(prayers: {...prayers, slot: value});

  /// [sound] if it still resolves (a recording the user deleted falls back
  /// to the built-in chime), given the muezzins of the adhan's library.
  AdhanSoundRef resolve(Iterable<CustomMuezzin> muezzins) {
    if (sound.kind != AdhanSoundKind.file) return sound;
    for (final m in muezzins) {
      if (m.id == sound.fileId) return sound;
    }
    return const AdhanSoundRef.tone(TanbihTone.chime);
  }

  Map<String, Object?> toJson() => {
    'v': version,
    'prayers': {for (final s in AdhanSlot.prayers) s.name: of(s).toJson()},
    'jumuah': jumuah.toJson(),
    'sound': sound.key,
    'vibrate': vibrate,
    'snooze': snoozeMinutes,
  };

  /// Tolerant: unknown or malformed values fall back to the defaults.
  factory IqamaSettings.fromJson(Object? raw) {
    const d = IqamaSettings();
    if (raw is! Map) return d;
    final prayers = <AdhanSlot, IqamaPrayer>{};
    final p = raw['prayers'];
    if (p is Map) {
      for (final e in p.entries) {
        final slot = AdhanSlot.byName(e.key);
        if (slot != null && slot.isPrayer) prayers[slot] = IqamaPrayer.fromJson(e.value);
      }
    }
    // An older row without Friday's own entry keeps Dhuhr's offset.
    final dhuhr = prayers[AdhanSlot.dhuhr] ?? const IqamaPrayer();
    return IqamaSettings(
      prayers: prayers,
      jumuah: raw['jumuah'] == null ? dhuhr : IqamaPrayer.fromJson(raw['jumuah'], fallbackMinutes: dhuhr.minutes),
      sound: AdhanSoundRef.parse(raw['sound']) ?? d.sound,
      vibrate: raw['vibrate'] is bool ? raw['vibrate'] as bool : d.vibrate,
      snoozeMinutes: raw['snooze'] is num ? (raw['snooze'] as num).round().clamp(1, 30) : d.snoozeMinutes,
    );
  }

  /// Canonical JSON (equality, sync keys).
  String get canonical => jsonEncode(toJson());

  @override
  bool operator ==(Object other) => other is IqamaSettings && other.canonical == canonical;

  @override
  int get hashCode => canonical.hashCode;
}
