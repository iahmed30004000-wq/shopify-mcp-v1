import 'package:flutter/foundation.dart';

import '../../../core/design/themes.dart' show PlanetPalette, PlanetPalettes;
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import 'neglect_text.dart';
import 'orbit_moons.dart';
import 'planet_archetypes.dart';
import 'planet_extras.dart';
import 'planet_scores.dart';
import 'prayer_schedule.dart';
import 'score_sources.dart';

/// A planet as configured by the user (mirrors a `planets` row).
@immutable
class PlanetConfig {
  const PlanetConfig({
    required this.id,
    required this.key,
    required this.nameAr,
    required this.nameEn,
    required this.color,
    required this.archetype,
    this.icon = 'star',
    this.hidden = false,
    this.weight = 1,
    this.sources = const {},
    this.sortOrder = 0,
  });

  final String id;

  /// Stable key: one of the eight built-ins or `custom_<id>`.
  final String key;
  final String nameAr;
  final String nameEn;

  /// ARGB.
  final int color;
  final PlanetArchetype archetype;
  final String icon;
  final bool hidden;

  /// Importance in the overall balance (0 = not counted).
  final double weight;

  /// Source → weight, as stored (aliases allowed).
  final Map<String, double> sources;
  final int sortOrder;

  /// User-added (can be deleted) rather than one of the eight built-ins.
  bool get isCustom => !PlanetPalettes.byKey.containsKey(key);

  /// The name in [languageCode], falling back to the other language.
  String nameFor(String languageCode) {
    final primary = languageCode == 'en' ? nameEn : nameAr;
    final other = languageCode == 'en' ? nameAr : nameEn;
    return primary.trim().isNotEmpty ? primary : other;
  }
}

/// One world of the orbit, ready to render.
@immutable
class OrbitPlanet {
  const OrbitPlanet({
    required this.config,
    required this.name,
    required this.palette,
    required this.score,
    required this.moonSet,
    required this.extras,
    required this.seed,
  });

  final PlanetConfig config;

  /// Name in the current language.
  final String name;
  final PlanetPalette palette;
  final PlanetScore score;
  final MoonSet moonSet;

  /// `uExtra` (4 floats, see the planet's shader header).
  final List<double> extras;

  /// Stable per-planet noise seed → `uSeed`.
  final double seed;

  String get id => config.id;
  String get key => config.key;
  PlanetArchetype get archetype => config.archetype;

  /// The shader that draws this planet (ice → crystal, desert → terracotta).
  PlanetArchetype get shaderArchetype => OrbitArchetypes.shaderFor(config.archetype);
  double get weight => config.weight;
  List<OrbitMoon> get moons => moonSet.moons;
  int get moonOverflow => moonSet.overflow;

  /// `uScore`: the balance score (dormant planets sit at a calm 0.6).
  double get uScore => score.score;
  PlanetState get state => score.state;

  /// The sources feeding this world's score as the planet page lists them
  /// (weakest first): each with its label – a custom module's by the
  /// module's name (its moon); a module that cannot be named is left out
  /// rather than shown as a raw id.
  List<({String key, double value, String label})> sourceRows(L10n l) {
    String? name(String key) {
      if (!key.startsWith(ScoreSources.modulePrefix)) return scoreSourceLabel(l, key);
      final id = key.substring(ScoreSources.modulePrefix.length);
      return moons.where((m) => m.refTable == 'custom_modules' && m.refId == id).firstOrNull?.label;
    }

    return [
      for (final e in score.sources.entries)
        if (ScoreSources.isKnown(e.key))
          if (name(e.key) case final label?) (key: e.key, value: e.value, label: label),
    ]..sort((a, b) => a.value.compareTo(b.value));
  }

  /// Everything the scene or the planet page shows of this world: a change
  /// in any of it (the weight or the data sources chosen in the customise
  /// sheet included) reaches the screen.
  int get contentHash => Object.hash(
    key,
    name,
    palette.surface,
    palette.glow,
    archetype,
    (score.score * 1e4).round(),
    score.state,
    Object.hashAll(extras),
    Object.hashAll(moons),
    moonOverflow,
    (config.weight * 1e3).round(),
    _mapHash(config.sources, (v) => (v * 1e3).round()),
    _mapHash(score.sources, (v) => (v * 1e3).round()),
    Object.hashAll(score.reasons.map(_reasonHash)),
    score.dormant,
  );

  /// Order-independent hash of a map (entries hashed as key + [value]).
  static int _mapHash(Map<String, double> m, int Function(double) value) =>
      Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, value(e.value))));

  static int _reasonHash(NeglectReason r) => Object.hash(
    r.code,
    (r.severity * 1e3).round(),
    Object.hashAllUnordered(r.args.entries.map((e) => Object.hash(e.key, e.value))),
    r.refTable,
    r.refId,
  );
}

/// One line of the Neglect Radar.
@immutable
class RadarEntry {
  const RadarEntry({
    required this.planetKey,
    required this.planetName,
    required this.palette,
    required this.score,
    required this.reason,
    required this.text,
  });

  final String planetKey;
  final String planetName;
  final PlanetPalette palette;

  /// The planet's score (the radar lists the weakest first).
  final double score;
  final NeglectReason reason;

  /// Localised sentence, e.g. «أبي — فات الموعد بـ٣ أيام».
  final String text;

  /// The record to open, or null → open the planet itself.
  String? get refTable => reason.refTable;
  String? get refId => reason.refId;

  /// Tapping opens the planet's module rather than one record.
  bool get opensPlanet => reason.refId == null;
}

/// Prayer state for the astrolabe dial.
@immutable
class PrayerState {
  const PrayerState({
    required this.settings,
    required this.times,
    required this.window,
    required this.prayerDay,
    required this.logged,
  });

  /// Location and calculation settings (default Amman, Jordan preset).
  final PrayerSettings settings;

  /// Today's (calendar day) prayer times – the pointer positions.
  final DayTimes times;

  /// The current window, its bounds and the next prayer.
  final WindowState window;

  /// The prayer-anchored day (the hours before Fajr belong to yesterday).
  final DateTime prayerDay;

  /// Obligatory prayers logged for [prayerDay].
  final Map<Prayer, PrayerStatus> logged;

  PrayerWindow get currentWindow => window.window;
  Prayer get nextPrayer => window.nextPrayer;

  /// When the countdown engraved on the inner ring reaches zero.
  DateTime get countdownTarget => window.nextPrayerAt;

  /// Obligatory prayers whose pointer burns with golden fire (prayed, late
  /// or made up – not missed).
  Set<Prayer> get lit => {
    for (final e in logged.entries)
      if (e.value != PrayerStatus.missed) e.key,
  };

  /// Changes whenever anything the dial shows changes – every time of the
  /// day, the window and its end, the next prayer, and the calculation
  /// settings (a new Asr madhab or adjustment must reach the pointers).
  int get contentHash => Object.hash(
    Object.hash(
      settings.latitude,
      settings.longitude,
      settings.fajrAngle,
      settings.ishaAngle,
      settings.hanafiAsr,
      settings.useJordanPreset,
      Object.hashAllUnordered(settings.adjustmentsMin.entries.map((e) => Object.hash(e.key, e.value))),
    ),
    Object.hash(times.fajr, times.sunrise, times.dhuhr, times.asr, times.maghrib, times.isha),
    window.window,
    window.start,
    window.end,
    window.nextPrayer,
    window.nextPrayerAt,
    prayerDay,
    Object.hashAllUnordered(logged.entries.map((e) => Object.hash(e.key, e.value))),
  );
}

/// Everything the Astrolabe Orbit renders, derived from the database.
@immutable
class SceneSnapshot {
  const SceneSnapshot({
    required this.at,
    required this.languageCode,
    required this.planets,
    required this.balance,
    required this.balanceDormant,
    required this.radar,
    required this.prayer,
  });

  /// When it was computed.
  final DateTime at;
  final String languageCode;

  /// Visible planets in the user's order.
  final List<OrbitPlanet> planets;

  /// Weighted mean of the non-dormant planets' scores → the core star.
  final double balance;

  /// No planet has data yet (the star rests at a calm balance).
  final bool balanceDormant;

  /// The (up to) three weakest planets with their most urgent reason.
  final List<RadarEntry> radar;
  final PrayerState prayer;

  OrbitPlanet? planet(String key) {
    for (final p in planets) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// The moon with [OrbitMoon.id] (`people:<id>` …) on any planet.
  OrbitMoon? moon(String id) {
    for (final p in planets) {
      for (final m in p.moons) {
        if (m.id == id) return m;
      }
    }
    return null;
  }

  /// Hash of everything a viewer can see (not [at]) – equal hashes mean the
  /// scene would not change.
  int get contentHash => Object.hash(
    languageCode,
    Object.hashAll(planets.map((p) => p.contentHash)),
    (balance * 1e4).round(),
    balanceDormant,
    Object.hashAll(radar.map((r) => Object.hash(r.planetKey, r.text, r.refTable, r.refId))),
    prayer.contentHash,
  );
}

/// Everything read from the database for one snapshot (plain data).
@immutable
class OrbitData {
  const OrbitData({
    required this.now,
    required this.planets,
    required this.scoreInputs,
    required this.moonInputs,
    required this.extrasInputs,
    required this.prayerSettings,
    required this.prayerDay,
    this.prayerLogs = const {},
  });

  final DateTime now;

  /// Every planet (hidden ones too) in the user's order.
  final List<PlanetConfig> planets;
  final ScoreInputs scoreInputs;
  final MoonInputs moonInputs;
  final ExtrasInputs extrasInputs;
  final PrayerSettings prayerSettings;
  final DateTime prayerDay;

  /// Obligatory prayers logged for [prayerDay].
  final Map<Prayer, PrayerStatus> prayerLogs;
}

/// Turns [OrbitData] into a [SceneSnapshot] (pure).
abstract final class SceneSnapshotBuilder {
  static SceneSnapshot build(
    OrbitData data, {
    required L10n l10n,
    required MadarFormatter formatter,
    required PrayerSchedule schedule,
    PlanetScoreEngine engine = const PlanetScoreEngine(),
    int radarCount = 3,
  }) {
    final languageCode = formatter.languageCode;
    final visible = [
      for (final p in data.planets)
        if (!p.hidden) p,
    ];
    final scores = engine.compute(
      data.scoreInputs,
      planetKeys: [for (final p in visible) p.key],
      weights: {for (final p in visible) p.key: p.sources},
    );
    final palettes = {for (final p in visible) p.key: OrbitArchetypes.paletteFor(p.key, p.color)};
    final moons = MoonBuilder.build(data.moonInputs, now: data.now, palettes: palettes);

    final planets = [
      for (final p in visible)
        OrbitPlanet(
          config: p,
          name: p.nameFor(languageCode),
          palette: palettes[p.key]!,
          score: scores[p.key]!,
          moonSet: moons[p.key] ?? MoonSet.empty,
          extras: PlanetExtras.of(key: p.key, archetype: p.archetype, data: data.extrasInputs),
          seed: MoonBuilder.seedOf(p.key),
        ),
    ];

    var sum = 0.0, wsum = 0.0;
    for (final p in planets) {
      if (p.score.dormant || p.weight <= 0) continue;
      sum += p.score.score * p.weight;
      wsum += p.weight;
    }
    final balanceDormant = wsum == 0;
    final balance = balanceDormant ? 0.6 : (sum / wsum).clamp(0.0, 1.0);

    final byKey = {for (final p in planets) p.key: p};
    final radar = <RadarEntry>[];
    final seen = <String>{};
    for (final (score, reason) in engine.neglectRadar(scores, count: scores.length)) {
      if (radar.length >= radarCount) break;
      final p = byKey[score.planetKey];
      if (p == null || p.weight <= 0) continue;
      // The same record can feed two planets (a custom planet borrowing a
      // source); list it once.
      final identity = '${reason.code.name}|${reason.refTable}|${reason.refId}|${reason.args}';
      if (!seen.add(identity)) continue;
      radar.add(
        RadarEntry(
          planetKey: p.key,
          planetName: p.name,
          palette: p.palette,
          score: score.score,
          reason: reason,
          text: neglectReasonText(l10n, reason, formatter),
        ),
      );
    }

    final prayer = PrayerState(
      settings: data.prayerSettings,
      times: schedule.timesFor(data.now),
      window: schedule.windowAt(data.now),
      prayerDay: data.prayerDay,
      logged: data.prayerLogs,
    );

    return SceneSnapshot(
      at: data.now,
      languageCode: languageCode,
      planets: planets,
      balance: balance,
      balanceDormant: balanceDormant,
      radar: radar,
      prayer: prayer,
    );
  }

  /// Canonical engine weights of a planet's stored sources.
  static Map<String, double> weightsOf(PlanetConfig p) => ScoreSources.canonicalWeights(p.sources);
}
