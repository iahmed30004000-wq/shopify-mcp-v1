import 'dart:ui' show Locale;

import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/orbit/domain/orbit_moons.dart';
import 'package:madar/features/orbit/domain/planet_archetypes.dart';
import 'package:madar/features/orbit/domain/planet_scores.dart' show PlanetState;
import 'package:madar/features/orbit/render/planets/planets.dart';

/// Deterministic worlds for the planet-layer tests and screenshots.
abstract final class PlanetFixtures {
  static const keys = ['faith', 'health', 'family', 'work', 'money', 'growth', 'body', 'travel'];

  static L10n l10n(String lang) => lookupL10n(Locale(lang));

  static String nameOf(String key, String lang) {
    final l = l10n(lang);
    return switch (key) {
      'faith' => l.planetFaith,
      'health' => l.planetHealth,
      'family' => l.planetFamily,
      'work' => l.planetWork,
      'money' => l.planetMoney,
      'growth' => l.planetGrowth,
      'body' => l.planetBody,
      'travel' => l.planetTravel,
      _ => key,
    };
  }

  static PlanetState stateFor(double score) => score >= 0.75
      ? PlanetState.thriving
      : score >= 0.45
      ? PlanetState.steady
      : PlanetState.neglected;

  /// Family members (typed by the user – Arabic in an Arabic app).
  static const familyAr = ['أبي', 'أمي', 'أختي ريم', 'أخي عمر', 'جدتي', 'عمي خالد', 'خالتي سلمى', 'ابن عمي'];
  static const familyEn = ['Father', 'Mother', 'Reem', 'Omar', 'Grandma', 'Uncle Khaled', 'Aunt Salma', 'Cousin'];

  static List<OrbitMoon> familyMoons({String lang = 'ar', int count = 8, double score = 0.9}) {
    final names = lang == 'ar' ? familyAr : familyEn;
    return [
      for (var i = 0; i < count; i++)
        OrbitMoon(
          planetKey: 'family',
          refTable: 'people',
          refId: 'p$i',
          label: names[i % names.length],
          color: MoonColors.variant(PlanetPalettes.family.surface, i),
          kind: MoonKind.rocky,
          score: i == 0 ? (score < 0.5 ? 0.1 : score) : (score - 0.07 * (i % 3)).clamp(0.0, 1.0),
          size: 1 - i / 10,
          seed: MoonBuilder.seedOf('p$i'),
        ),
    ];
  }

  static List<OrbitMoon> walletMoons({String lang = 'ar'}) {
    final names = lang == 'ar' ? ['النقد', 'البنك', 'التوفير'] : ['Cash', 'Bank', 'Savings'];
    return [
      for (var i = 0; i < names.length; i++)
        OrbitMoon(
          planetKey: 'money',
          refTable: 'wallets',
          refId: 'w$i',
          label: names[i],
          color: MoonColors.walletGem(PlanetPalettes.money, i),
          kind: MoonKind.metallic,
          score: 0.9,
          size: [0.9, 0.6, 0.4][i],
          seed: MoonBuilder.seedOf('w$i'),
        ),
    ];
  }

  static List<OrbitMoon> boardMoons({String lang = 'ar'}) {
    final names = lang == 'ar' ? ['الأردن', 'سوريا'] : ['Jordan', 'Syria'];
    return [
      for (var i = 0; i < names.length; i++)
        OrbitMoon(
          planetKey: 'work',
          refTable: 'boards',
          refId: 'b$i',
          label: names[i],
          color: MoonColors.variant(PlanetPalettes.work.glow, i),
          kind: MoonKind.lava,
          score: 0.8,
          size: 0.7 - i * 0.2,
          seed: MoonBuilder.seedOf('b$i'),
        ),
    ];
  }

  static List<OrbitMoon> tripMoons({String lang = 'ar'}) => [
    OrbitMoon(
      planetKey: 'travel',
      refTable: 'trips',
      refId: 't0',
      label: lang == 'ar' ? 'إسطنبول' : 'Istanbul',
      color: MoonColors.variant(PlanetPalettes.travel.surface, 0),
      kind: MoonKind.icy,
      score: 0.85,
      size: 0.6,
      seed: MoonBuilder.seedOf('t0'),
    ),
  ];

  /// Extras as the data layer would compute them for a lived-in week.
  static List<double> extrasFor(String key, {bool thriving = true, int trips = 3}) => switch (key) {
    'family' => [2, 0, 0, 0],
    'work' => [2, thriving ? 0.85 : 0.3, 0, 0],
    'money' => [0, thriving ? 0.7 : 0.08, 0, 0],
    'growth' => [thriving ? 0.8 : 0.1, 0, 0, 0],
    'body' => [0, thriving ? 0.8 : 0.0, 0, 0],
    'travel' => [trips.toDouble(), 0, 0, 0],
    _ => [0, 0, 0, 0],
  };

  static PlanetBody body(
    String key, {
    double score = 0.9,
    String lang = 'ar',
    bool moons = true,
    PlanetArchetype? archetype,
    int trips = 3,
    List<OrbitMoon>? moonList,
  }) {
    final a = archetype ?? OrbitArchetypes.forBuiltInKey(key)!;
    final thriving = score >= 0.6;
    return PlanetBody(
      key: key,
      name: nameOf(key, lang),
      archetype: a,
      palette: PlanetPalettes.byKey[key] ?? PlanetPalettes.fromColor(OrbitArchetypes.defaultColor(a)),
      score: score,
      state: stateFor(score),
      extras: extrasFor(key, thriving: thriving, trips: trips),
      seed: MoonBuilder.seedOf(key),
      moons:
          moonList ??
          (!moons
              ? const []
              : switch (key) {
                  'family' => familyMoons(lang: lang, score: score),
                  'money' => walletMoons(lang: lang),
                  'work' => boardMoons(lang: lang),
                  'travel' => tripMoons(lang: lang),
                  _ => const <OrbitMoon>[],
                }),
    );
  }

  /// The eight default worlds with a mixed, realistic balance.
  static List<PlanetBody> system({String lang = 'ar', Map<String, double> scores = const {}, bool moons = true}) {
    const mixed = {
      'faith': 0.92,
      'health': 0.55,
      'family': 0.86,
      'work': 0.7,
      'money': 0.34,
      'growth': 0.8,
      'body': 0.18,
      'travel': 0.88,
    };
    return [for (final k in keys) body(k, score: scores[k] ?? mixed[k]!, lang: lang, moons: moons)];
  }

  /// A user-added world in style [a] (ice / desert).
  static PlanetBody custom(String id, PlanetArchetype a, {String name = 'عالمي', double score = 0.85}) => PlanetBody(
    key: 'custom_$id',
    name: name,
    archetype: a,
    palette: PlanetPalettes.fromColor(OrbitArchetypes.defaultColor(a)),
    score: score,
    state: stateFor(score),
    extras: OrbitArchetypes.styleExtras(a),
    seed: MoonBuilder.seedOf('custom_$id'),
  );
}
