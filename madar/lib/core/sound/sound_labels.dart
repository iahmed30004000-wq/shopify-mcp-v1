import '../i18n/gen/app_localizations.dart';
import 'profiles.dart';
import 'sound_api.dart';

/// Localised names for sound settings UIs.
extension SoundLabels on L10n {
  /// Display name of a sound profile id (unknown ids → Lapis).
  String soundProfileName(String profileId) => switch (SoundProfiles.normalize(profileId)) {
        'emerald' => soundProfileEmerald,
        'desert' => soundProfileDesert,
        'aurora' => soundProfileAurora,
        'pearl' => soundProfilePearl,
        _ => soundProfileLapis,
      };

  /// One-line description (instrument + maqam) of a sound profile.
  String soundProfileDescription(String profileId) => switch (SoundProfiles.normalize(profileId)) {
        'emerald' => soundProfileEmeraldDescription,
        'desert' => soundProfileDesertDescription,
        'aurora' => soundProfileAuroraDescription,
        'pearl' => soundProfilePearlDescription,
        _ => soundProfileLapisDescription,
      };

  /// Name of a volume category (for sliders).
  String soundCategoryName(SoundCategory category) => switch (category) {
        SoundCategory.ui => soundCategoryUi,
        SoundCategory.ambient => soundCategoryAmbient,
        SoundCategory.games => soundCategoryGames,
        SoundCategory.prayer => soundCategoryPrayer,
      };
}
