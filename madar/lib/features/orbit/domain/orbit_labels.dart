import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import 'neglect_text.dart';
import 'orbit_moons.dart';
import 'planet_scores.dart' show PlanetState;
import 'scene_snapshot.dart';

/// What a planet customisation changed – picks the undo toast's label.
enum PlanetEdit { rename, recolor, reorder, hide, show, weight, sources, style, add, delete, reset }

/// Why a planet customisation was refused (see
/// `PlanetCustomizationException.error`).
enum PlanetEditError {
  /// The name is empty.
  needsName,

  /// Built-in planets can be hidden, not deleted.
  builtInDelete,

  /// A score source that does not exist.
  unknownSource,

  /// No planet with that key (or no defaults to reset to) – a stale sheet.
  notFound,
}

/// Label of the undo toast after [edit] on the planet called [name]
/// (bidi-isolated, so a Latin name reads correctly inside Arabic).
String planetEditUndoLabel(L10n l, MadarFormatter fmt, PlanetEdit edit, {String name = ''}) {
  final n = fmt.isolate(name.trim());
  return switch (edit) {
    PlanetEdit.rename => l.orbitUndoRenamed,
    PlanetEdit.recolor => l.orbitUndoRecolored(n),
    PlanetEdit.reorder => l.orbitUndoReordered,
    PlanetEdit.hide => l.orbitUndoHidden(n),
    PlanetEdit.show => l.orbitUndoShown(n),
    PlanetEdit.weight => l.orbitUndoWeight(n),
    PlanetEdit.sources => l.orbitUndoSources(n),
    PlanetEdit.style => l.orbitUndoStyle(n),
    PlanetEdit.add => l.orbitUndoAdded(n),
    PlanetEdit.delete => l.orbitUndoDeleted(n),
    PlanetEdit.reset => l.orbitUndoReset(n),
  };
}

/// Message for a refused customisation.
String planetEditErrorText(L10n l, PlanetEditError error) => switch (error) {
  PlanetEditError.needsName => l.orbitPlanetNeedsName,
  PlanetEditError.builtInDelete => l.orbitBuiltInCannotDelete,
  PlanetEditError.unknownSource => l.orbitUnknownSource,
  PlanetEditError.notFound => l.orbitPlanetGone,
};

/// «وقمران آخران» / "+2 more moons" for the moons beyond the cap of a
/// planet ([MoonSet.overflow]); empty when everything fits.
String moonOverflowText(L10n l, MadarFormatter fmt, int overflow) =>
    overflow <= 0 ? '' : l.orbitMoonsMore(overflow, fmt.formatInt(overflow));

/// Screen-reader label of a moon: «أبي، قمرٌ يدور حول العائلة».
String moonSemanticsLabel(L10n l, MadarFormatter fmt, OrbitMoon moon, String planetName) =>
    l.orbitMoonSemantics(fmt.isolate(moon.label.trim()), fmt.isolate(planetName.trim()));

/// Screen-reader label of a planet: «العائلة، يحتاج إلى اهتمام، التوازن ٣٢٪».
String planetSemanticsLabel(L10n l, MadarFormatter fmt, OrbitPlanet planet) => l.orbitPlanetSemantics(
  fmt.isolate(planet.name.trim()),
  planetStateLabel(l, planet.state),
  fmt.formatPercent(planet.uScore),
);

/// Screen-reader label of the core star: «توازن حياتك ٧٢٪» (or «توازن حياتك
/// هادئ، لا بيانات بعد» before any planet has data).
String balanceSemanticsLabel(L10n l, MadarFormatter fmt, SceneSnapshot snapshot) => l.orbitBalanceSemantics(
  snapshot.balanceDormant ? planetStateLabel(l, PlanetState.dormant) : fmt.formatPercent(snapshot.balance),
);
