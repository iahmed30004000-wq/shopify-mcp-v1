import 'package:flutter/foundation.dart';

import 'breathing.dart';
import 'worry_window.dart';

/// Wellbeing preferences, stored encrypted under `key_values['wellbeing.settings']`.
@immutable
class WellbeingSettings {
  const WellbeingSettings({
    this.supportNumber = defaultSupportNumber,
    this.supportDismissedUntil,
    this.worry = const WorryWindowSettings(),
    this.breathingPattern = '478',
    this.breathingCycles = 4,
    this.breathingSound = true,
  });

  static const String storageKey = 'wellbeing.settings';

  /// Jordan's unified emergency number. Editable for other countries.
  static const String defaultSupportNumber = '911';

  static const List<int> cycleChoices = [3, 4, 6, 8];

  /// The number the support banner offers to call (digits, `+`, `*`, `#`).
  final String supportNumber;

  /// The banner stays hidden until then (set by "hide for a week").
  final DateTime? supportDismissedUntil;
  final WorryWindowSettings worry;
  final String breathingPattern;
  final int breathingCycles;

  /// Soft sound cues on phase changes (haptics always play).
  final bool breathingSound;

  BreathingPattern get pattern => BreathingPattern.byId(breathingPattern);

  /// A dialable form of [supportNumber] (Arabic-Indic digits converted,
  /// spaces and dashes dropped); null when nothing dialable remains.
  String? get dialable => normalizeNumber(supportNumber);

  static String? normalizeNumber(String raw) {
    final b = StringBuffer();
    for (final r in raw.runes) {
      if (r >= 0x30 && r <= 0x39) {
        b.writeCharCode(r);
      } else if (r >= 0x0660 && r <= 0x0669) {
        b.writeCharCode(r - 0x0660 + 0x30);
      } else if (r >= 0x06F0 && r <= 0x06F9) {
        b.writeCharCode(r - 0x06F0 + 0x30);
      } else if (r == 0x2B && b.isEmpty) {
        b.write('+');
      } else if (r == 0x2A || r == 0x23) {
        b.writeCharCode(r);
      } else if (r == 0x20 || r == 0x2D || r == 0x28 || r == 0x29 || r == 0xA0) {
        continue;
      } else {
        return null;
      }
    }
    final s = b.toString();
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 2 || digits.length > 15) return null;
    return s;
  }

  WellbeingSettings copyWith({
    String? supportNumber,
    DateTime? supportDismissedUntil,
    bool clearDismissal = false,
    WorryWindowSettings? worry,
    String? breathingPattern,
    int? breathingCycles,
    bool? breathingSound,
  }) => WellbeingSettings(
    supportNumber: supportNumber ?? this.supportNumber,
    supportDismissedUntil: clearDismissal ? null : (supportDismissedUntil ?? this.supportDismissedUntil),
    worry: worry ?? this.worry,
    breathingPattern: breathingPattern ?? this.breathingPattern,
    breathingCycles: breathingCycles ?? this.breathingCycles,
    breathingSound: breathingSound ?? this.breathingSound,
  );

  Map<String, Object?> toJson() => {
    'supportNumber': supportNumber,
    'supportDismissedUntil': supportDismissedUntil?.toUtc().toIso8601String(),
    'worry': worry.toJson(),
    'breathingPattern': breathingPattern,
    'breathingCycles': breathingCycles,
    'breathingSound': breathingSound,
  };

  static WellbeingSettings fromJson(Object? json) {
    if (json is! Map) return const WellbeingSettings();
    final number = json['supportNumber'];
    final until = json['supportDismissedUntil'];
    final cycles = json['breathingCycles'];
    return WellbeingSettings(
      supportNumber: number is String && normalizeNumber(number) != null ? number : defaultSupportNumber,
      supportDismissedUntil: until is String ? DateTime.tryParse(until)?.toLocal() : null,
      worry: WorryWindowSettings.fromJson(json['worry']),
      breathingPattern: BreathingPattern.byId(json['breathingPattern'] as String?).id,
      breathingCycles: cycles is num ? cycles.toInt().clamp(1, 20) : 4,
      breathingSound: json['breathingSound'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WellbeingSettings &&
      other.supportNumber == supportNumber &&
      other.supportDismissedUntil == supportDismissedUntil &&
      other.worry == worry &&
      other.breathingPattern == breathingPattern &&
      other.breathingCycles == breathingCycles &&
      other.breathingSound == breathingSound;

  @override
  int get hashCode =>
      Object.hash(supportNumber, supportDismissedUntil, worry, breathingPattern, breathingCycles, breathingSound);
}
