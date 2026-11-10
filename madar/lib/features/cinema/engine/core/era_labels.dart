import '../../../../core/i18n/gen/app_localizations.dart';
import 'era.dart';

extension EraLabels on Era {
  /// Localised era name ("كرتون الثلاثينيات" …).
  String label(L10n l10n) => switch (this) {
    Era.silent => l10n.cinemaEraSilent,
    Era.rubberHose => l10n.cinemaEraRubberHose,
    Era.noir => l10n.cinemaEraNoir,
    Era.technicolor => l10n.cinemaEraTechnicolor,
    Era.grindhouse => l10n.cinemaEraGrindhouse,
    Era.vhs => l10n.cinemaEraVhs,
  };
}
