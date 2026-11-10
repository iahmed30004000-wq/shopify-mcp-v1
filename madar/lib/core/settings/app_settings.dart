import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/themes.dart';
import '../sound/sound_api.dart';

/// Digit style for numbers shown in the UI.
enum DigitStyle {
  /// Western digits in English, Arabic-Indic in Arabic.
  auto,
  western,
  arabicIndic,
}

enum MotionPreference { system, reduced, full }

enum PowerMode {
  /// Full scene; drop to 30 fps when idle.
  auto,

  /// Beautiful pre-rendered stills instead of the live scene.
  batterySaver,
}

/// UI preferences that must be readable before the encrypted database is
/// unlocked (theme, language, lock). Nothing personal lives here.
@immutable
class AppSettings {
  const AppSettings({
    this.themeId = MadarThemeId.lapis,
    this.followSystem = false,
    this.customAccent,
    this.languageCode = 'ar',
    this.digits = DigitStyle.auto,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.ambientEnabled = false,
    this.volumes = const {
      SoundCategory.ui: 0.8,
      SoundCategory.ambient: 0.5,
      SoundCategory.games: 0.8,
      SoundCategory.prayer: 1.0,
    },
    this.motion = MotionPreference.system,
    this.powerMode = PowerMode.auto,
    this.lockEnabled = true,
    this.lockAfterSeconds = 120,
    this.onboarded = false,
  });

  final MadarThemeId themeId;

  /// When true: system light → Pearl, system dark → [themeId] (or Lapis if
  /// [themeId] is Pearl).
  final bool followSystem;
  final Color? customAccent;
  final String languageCode;
  final DigitStyle digits;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool ambientEnabled;
  final Map<SoundCategory, double> volumes;
  final MotionPreference motion;
  final PowerMode powerMode;
  final bool lockEnabled;
  final int lockAfterSeconds;
  final bool onboarded;

  Locale get locale => Locale(languageCode);
  bool get isArabic => languageCode == 'ar';

  /// Effective theme for the platform brightness.
  MadarThemeId effectiveTheme(Brightness platformBrightness) {
    if (!followSystem) return themeId;
    if (platformBrightness == Brightness.light) return MadarThemeId.pearl;
    return themeId == MadarThemeId.pearl ? MadarThemeId.lapis : themeId;
  }

  AppSettings copyWith({
    MadarThemeId? themeId,
    bool? followSystem,
    Color? customAccent,
    bool clearCustomAccent = false,
    String? languageCode,
    DigitStyle? digits,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? ambientEnabled,
    Map<SoundCategory, double>? volumes,
    MotionPreference? motion,
    PowerMode? powerMode,
    bool? lockEnabled,
    int? lockAfterSeconds,
    bool? onboarded,
  }) {
    return AppSettings(
      themeId: themeId ?? this.themeId,
      followSystem: followSystem ?? this.followSystem,
      customAccent: clearCustomAccent ? null : (customAccent ?? this.customAccent),
      languageCode: languageCode ?? this.languageCode,
      digits: digits ?? this.digits,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      ambientEnabled: ambientEnabled ?? this.ambientEnabled,
      volumes: volumes ?? this.volumes,
      motion: motion ?? this.motion,
      powerMode: powerMode ?? this.powerMode,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      lockAfterSeconds: lockAfterSeconds ?? this.lockAfterSeconds,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  Map<String, Object?> toJson() => {
        'themeId': themeId.name,
        'followSystem': followSystem,
        'customAccent': customAccent?.toARGB32(),
        'languageCode': languageCode,
        'digits': digits.name,
        'soundEnabled': soundEnabled,
        'hapticsEnabled': hapticsEnabled,
        'ambientEnabled': ambientEnabled,
        'volumes': {for (final e in volumes.entries) e.key.name: e.value},
        'motion': motion.name,
        'powerMode': powerMode.name,
        'lockEnabled': lockEnabled,
        'lockAfterSeconds': lockAfterSeconds,
        'onboarded': onboarded,
      };

  factory AppSettings.fromJson(Map<String, Object?> j) {
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    const d = AppSettings();
    final vols = Map<SoundCategory, double>.of(d.volumes);
    final rawVols = j['volumes'];
    if (rawVols is Map) {
      for (final c in SoundCategory.values) {
        final v = rawVols[c.name];
        if (v is num) vols[c] = v.toDouble().clamp(0.0, 1.0);
      }
    }
    final accent = j['customAccent'];
    return AppSettings(
      themeId: byName(MadarThemeId.values, j['themeId'], d.themeId),
      followSystem: j['followSystem'] as bool? ?? d.followSystem,
      customAccent: accent is int ? Color(accent) : null,
      languageCode: (j['languageCode'] as String?) == 'en' ? 'en' : 'ar',
      digits: byName(DigitStyle.values, j['digits'], d.digits),
      soundEnabled: j['soundEnabled'] as bool? ?? d.soundEnabled,
      hapticsEnabled: j['hapticsEnabled'] as bool? ?? d.hapticsEnabled,
      ambientEnabled: j['ambientEnabled'] as bool? ?? d.ambientEnabled,
      volumes: vols,
      motion: byName(MotionPreference.values, j['motion'], d.motion),
      powerMode: byName(PowerMode.values, j['powerMode'], d.powerMode),
      lockEnabled: j['lockEnabled'] as bool? ?? d.lockEnabled,
      lockAfterSeconds: (j['lockAfterSeconds'] as num?)?.toInt() ?? d.lockAfterSeconds,
      onboarded: j['onboarded'] as bool? ?? d.onboarded,
    );
  }
}

/// Overridden at bootstrap with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden in bootstrap'),
);

final appSettingsProvider = NotifierProvider<AppSettingsController, AppSettings>(AppSettingsController.new);

class AppSettingsController extends Notifier<AppSettings> {
  static const _key = 'madar.settings.v1';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> update(AppSettings Function(AppSettings s) change) async {
    state = change(state);
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(state.toJson()));
  }
}
