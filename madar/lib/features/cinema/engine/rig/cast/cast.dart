import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../core/era.dart';
import '../../core/era_skin.dart';
import '../../core/rig.dart';
import '../toon_rig.dart';
import 'camel_courier.dart';
import 'clockwork_boss.dart';
import 'detective_cat.dart';
import 'neon_rider.dart';
import 'star_bird.dart';

/// One member of the original cast: who they are, which film they star in,
/// and how to build them.
class CastMember {
  const CastMember({
    required this.id,
    required this.gameId,
    required this.era,
    required this.name,
    required this.role,
    required this.build,
    required this.height,
  });

  final String id;

  /// The game (catalog id) the character was designed for.
  final String gameId;

  /// The era the design is drawn for (it re-skins in every era).
  final Era era;
  final String Function(L10n l10n) name;
  final String Function(L10n l10n) role;

  /// Builds a fresh rig ([height] in world units, default [this.height]).
  final RigCharacter Function({double? height}) build;

  /// Default height in world units.
  final double height;
}

/// The original characters seeding the Tier 1 films. Every one is an
/// original design (see ENGINE.md → Originality) and implements
/// [RigCharacter], so it plugs into `RigComponent` like any rig.
abstract final class RigCast {
  /// Nujaym, the star-bird of Flappy Orbit.
  static StarBird starBird({double height = 90, int seed = 0}) => StarBird(height: height, seed: seed);

  /// Baron Zunbruk, the clockwork boss of Metropolis Machine.
  static ClockworkBoss clockworkBoss({double height = 280, int seed = 0}) => ClockworkBoss(height: height, seed: seed);

  /// Zajil, the camel courier of Caravan Dash.
  static CamelCourier camelCourier({double height = 120, int seed = 0}) => CamelCourier(height: height, seed: seed);

  /// Inspector Mishmish, the detective cat of Noir Rooftops.
  static DetectiveCat detectiveCat({double height = 110, int seed = 0}) => DetectiveCat(height: height, seed: seed);

  /// Sarab, the hover-bike rider of Neon Souk Racer.
  static NeonRider neonRider({double height = 110, int seed = 0}) => NeonRider(height: height, seed: seed);

  /// Habba, the bean of the engine demo (the generic rig with its default
  /// look).
  static ToonRig bean({double height = 118, int seed = 0}) =>
      ToonRig(RigSpec(id: 'demo_hero', height: height, accent: PaletteRole.accent, seed: seed));

  static final List<CastMember> all = [
    CastMember(
      id: 'nujaym',
      gameId: 'flappy_orbit',
      era: Era.rubberHose,
      name: (l) => l.cinemaRigNujaym,
      role: (l) => l.cinemaRigNujaymRole,
      build: ({double? height}) => starBird(height: height ?? 90),
      height: 90,
    ),
    CastMember(
      id: 'zunbruk',
      gameId: 'metropolis_machine',
      era: Era.silent,
      name: (l) => l.cinemaRigZunbruk,
      role: (l) => l.cinemaRigZunbrukRole,
      build: ({double? height}) => clockworkBoss(height: height ?? 280),
      height: 280,
    ),
    CastMember(
      id: 'zajil',
      gameId: 'caravan_dash',
      era: Era.technicolor,
      name: (l) => l.cinemaRigZajil,
      role: (l) => l.cinemaRigZajilRole,
      build: ({double? height}) => camelCourier(height: height ?? 120),
      height: 120,
    ),
    CastMember(
      id: 'mishmish',
      gameId: 'noir_rooftops',
      era: Era.noir,
      name: (l) => l.cinemaRigMishmish,
      role: (l) => l.cinemaRigMishmishRole,
      build: ({double? height}) => detectiveCat(height: height ?? 110),
      height: 110,
    ),
    CastMember(
      id: 'sarab',
      gameId: 'neon_souk_racer',
      era: Era.vhs,
      name: (l) => l.cinemaRigSarab,
      role: (l) => l.cinemaRigSarabRole,
      build: ({double? height}) => neonRider(height: height ?? 110),
      height: 110,
    ),
    CastMember(
      id: 'habba',
      gameId: 'demo',
      era: Era.rubberHose,
      name: (l) => l.cinemaRigBean,
      role: (l) => l.cinemaRigBeanRole,
      build: ({double? height}) => bean(height: height ?? 118),
      height: 118,
    ),
  ];

  static CastMember? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}
