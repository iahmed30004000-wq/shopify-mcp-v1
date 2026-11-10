import '../design/themes.dart';
import 'profiles/aurora_profile.dart';
import 'profiles/desert_profile.dart';
import 'profiles/emerald_profile.dart';
import 'profiles/lapis_profile.dart';
import 'profiles/pearl_profile.dart';
import 'profiles/profile_base.dart';

export 'profiles/aurora_profile.dart';
export 'profiles/desert_profile.dart';
export 'profiles/emerald_profile.dart';
export 'profiles/lapis_profile.dart';
export 'profiles/pearl_profile.dart';
export 'profiles/profile_base.dart';

/// Registry of the five theme-matched sound profiles.
///
/// | theme   | profile                                  | maqam    |
/// |---------|------------------------------------------|----------|
/// | lapis   | glass bells & crystal FM                 | Rast     |
/// | emerald | warm wood & kalimba                      | Bayati   |
/// | desert  | oud pluck (Karplus–Strong) + frame drum  | Hijaz    |
/// | aurora  | airy detuned synth shimmer               | 'Ajam    |
/// | pearl   | delicate crystal pings                   | Nahawand |
abstract final class SoundProfiles {
  static const lapis = LapisProfile();
  static const emerald = EmeraldProfile();
  static const desert = DesertProfile();
  static const aurora = AuroraProfile();
  static const pearl = PearlProfile();

  static const List<SoundProfile> all = [lapis, emerald, desert, aurora, pearl];

  /// Profile ids in theme order.
  static const List<String> ids = ['lapis', 'emerald', 'desert', 'aurora', 'pearl'];

  static const String defaultId = 'lapis';

  /// The profile for [id]; unknown ids fall back to Lapis.
  static SoundProfile byId(String id) => switch (id) {
        'emerald' => emerald,
        'desert' => desert,
        'aurora' => aurora,
        'pearl' => pearl,
        _ => lapis,
      };

  /// Normalises [id] to a known profile id.
  static String normalize(String id) => ids.contains(id) ? id : defaultId;

  /// Profile id matched to a theme.
  static String idForTheme(MadarThemeId theme) => switch (theme) {
        MadarThemeId.lapis => 'lapis',
        MadarThemeId.emerald => 'emerald',
        MadarThemeId.desert => 'desert',
        MadarThemeId.aurora => 'aurora',
        MadarThemeId.pearl => 'pearl',
      };
}
