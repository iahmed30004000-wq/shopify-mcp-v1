import '../../../../core/i18n/gen/app_localizations.dart';
import '../../domain/orbit_moons.dart';

/// Labels and ids of a world's moons on its page (pure).
abstract final class PlanetModules {
  /// "Person", "Wallet", "Board", "Trip" or "Module" for a data moon.
  static String moonKindLabel(L10n l, OrbitMoon moon) => switch (moon.refTable) {
    'people' => l.orbitUiMoonKindPerson,
    'wallets' => l.orbitUiMoonKindWallet,
    'boards' => l.orbitUiMoonKindBoard,
    'trips' => l.orbitUiMoonKindTrip,
    _ => l.orbitUiMoonKindModule,
  };

  /// The moon id (`refTable:refId`) a record reference points at.
  static String itemOf(String refTable, String refId) => '$refTable:$refId';
}
