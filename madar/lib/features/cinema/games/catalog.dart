import '../engine/cinema_engine.dart';
import 'caravan_dash/caravan_dash_entry.dart';
import 'demo/demo_entry.dart';
import 'flappy_orbit/flappy_orbit_entry.dart';
import 'metropolis_machine/metropolis_machine_entry.dart';
import 'neon_souk_racer/neon_souk_racer_entry.dart';
import 'noir_rooftops/noir_rooftops_entry.dart';

/// The Madar Cinema programme. Owner: architect – a new game adds ONE import
/// and ONE line here; everything else lives in `games/<id>/`.
abstract final class CinemaCatalog {
  static final List<GameCatalogEntry> all = [
    flappyOrbitEntry,
    metropolisMachineEntry,
    caravanDashEntry,
    noirRooftopsEntry,
    neonSoukRacerEntry,
    demoEntry,
  ];

  static GameCatalogEntry? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  static List<GameCatalogEntry> ofTier(GameTier tier) => [for (final e in all) if (e.tier == tier) e];
}
