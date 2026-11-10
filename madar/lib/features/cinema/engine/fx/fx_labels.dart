import '../../../../core/i18n/gen/app_localizations.dart';
import 'film_look.dart';

/// Localised names for the FX settings (a hall or pause-menu picker).
extension FilmQualityLabel on FilmQuality {
  String label(L10n l10n) => switch (this) {
    FilmQuality.lowPower => l10n.cinemaFxQualityLowPower,
    FilmQuality.balanced => l10n.cinemaFxQualityBalanced,
    FilmQuality.full => l10n.cinemaFxQualityFull,
  };
}

/// "Film look" – the heading of the FX settings.
String filmLookHeading(L10n l10n) => l10n.cinemaFxFilmLook;

/// "Reel ٣" / "Reel 3" – the caption of a countdown leader; [number] is
/// already formatted with the user's digits.
String reelCaption(L10n l10n, String number) => '${l10n.cinemaFxReelLabel} $number';
