import 'package:flutter/foundation.dart';

import '../../design/themes.dart' show PlanetPalettes;
import '../../domain/enums.dart';
import '../../i18n/gen/app_localizations.dart';

/// Keys of the data sources that may feed a planet's balance score (the keys
/// of `Planets.sources`; values are relative weights that sum to 1).
abstract final class PlanetSourceKeys {
  static const prayers = 'prayers';
  static const adhkar = 'adhkar';
  static const quran = 'quran';
  static const medications = 'medications';
  static const mood = 'mood';
  static const pain = 'pain';
  static const habits = 'habits';
  static const labs = 'labs';
  static const appointments = 'appointments';
  static const contacts = 'contacts';
  static const tasks = 'tasks';
  static const boards = 'boards';
  static const projects = 'projects';
  static const budget = 'budget';
  static const transactions = 'transactions';
  static const jars = 'jars';
  static const obligations = 'obligations';
  static const learning = 'learning';
  static const workouts = 'workouts';
  static const water = 'water';
  static const fasting = 'fasting';
  static const trips = 'trips';
  static const documents = 'documents';
}

/// One of the eight built-in planets.
@immutable
class DefaultPlanet {
  const DefaultPlanet({required this.key, required this.archetype, required this.icon, required this.sources});

  /// Stable key (`Planets.key`).
  final String key;
  final PlanetArchetype archetype;

  /// Icon name (`Planets.icon`), resolved to a glyph by the UI.
  final String icon;

  /// Default score sources → weight (sums to 1).
  final Map<String, double> sources;

  /// Signature surface colour from [PlanetPalettes] as ARGB.
  int get color => PlanetPalettes.byKey[key]!.surface.toARGB32();

  /// Localised name.
  String nameIn(L10n l10n) => switch (key) {
    'faith' => l10n.planetFaith,
    'health' => l10n.planetHealth,
    'family' => l10n.planetFamily,
    'work' => l10n.planetWork,
    'money' => l10n.planetMoney,
    'growth' => l10n.planetGrowth,
    'body' => l10n.planetBody,
    'travel' => l10n.planetTravel,
    _ => key,
  };
}

/// A seeded currency. Rates are *generic reference defaults* the user is
/// expected to edit (Money → Currencies); see `SeedKeys.currencyRatesAreDefaults`.
@immutable
class DefaultCurrency {
  const DefaultCurrency({
    required this.code,
    required this.symbol,
    required this.decimals,
    required this.rateToBase,
    this.isBase = false,
  });

  final String code;
  final String symbol;
  final int decimals;

  /// 1 unit of this currency in the base currency (JOD).
  final double rateToBase;
  final bool isBase;

  String nameIn(L10n l10n) => switch (code) {
    'JOD' => l10n.dbCurrencyJod,
    'USD' => l10n.dbCurrencyUsd,
    'SYP' => l10n.dbCurrencySyp,
    'EGP' => l10n.dbCurrencyEgp,
    'LYD' => l10n.dbCurrencyLyd,
    _ => code,
  };
}

/// A seeded habit.
@immutable
class DefaultHabit {
  const DefaultHabit(this.name, {this.planetKey = 'health', this.category = 'stress'});
  final String name;
  final String? planetKey;
  final String category;
}

/// Generic first-run content. Nothing here is personal.
abstract final class MadarDefaults {
  /// The eight built-in planets in orbit order, all with equal weight 1.0.
  static const planets = <DefaultPlanet>[
    DefaultPlanet(
      key: 'faith',
      archetype: PlanetArchetype.faith,
      icon: 'mosque',
      sources: {PlanetSourceKeys.prayers: 0.6, PlanetSourceKeys.adhkar: 0.2, PlanetSourceKeys.quran: 0.2},
    ),
    DefaultPlanet(
      key: 'health',
      archetype: PlanetArchetype.ocean,
      icon: 'heart',
      sources: {
        PlanetSourceKeys.medications: 0.35,
        PlanetSourceKeys.mood: 0.2,
        PlanetSourceKeys.habits: 0.2,
        PlanetSourceKeys.pain: 0.1,
        PlanetSourceKeys.appointments: 0.1,
        PlanetSourceKeys.labs: 0.05,
      },
    ),
    DefaultPlanet(
      key: 'family',
      archetype: PlanetArchetype.terracotta,
      icon: 'family',
      sources: {PlanetSourceKeys.contacts: 0.7, PlanetSourceKeys.tasks: 0.3},
    ),
    DefaultPlanet(
      key: 'work',
      archetype: PlanetArchetype.industrial,
      icon: 'briefcase',
      sources: {PlanetSourceKeys.tasks: 0.5, PlanetSourceKeys.boards: 0.3, PlanetSourceKeys.projects: 0.2},
    ),
    DefaultPlanet(
      key: 'money',
      archetype: PlanetArchetype.crystal,
      icon: 'coins',
      sources: {
        PlanetSourceKeys.budget: 0.4,
        PlanetSourceKeys.transactions: 0.2,
        PlanetSourceKeys.jars: 0.2,
        PlanetSourceKeys.obligations: 0.2,
      },
    ),
    DefaultPlanet(
      key: 'growth',
      archetype: PlanetArchetype.verdant,
      icon: 'sprout',
      sources: {PlanetSourceKeys.learning: 0.7, PlanetSourceKeys.projects: 0.3},
    ),
    DefaultPlanet(
      key: 'body',
      archetype: PlanetArchetype.volcanic,
      icon: 'dumbbell',
      sources: {PlanetSourceKeys.workouts: 0.5, PlanetSourceKeys.fasting: 0.3, PlanetSourceKeys.water: 0.2},
    ),
    DefaultPlanet(
      key: 'travel',
      archetype: PlanetArchetype.gasGiant,
      icon: 'plane',
      sources: {PlanetSourceKeys.trips: 0.6, PlanetSourceKeys.documents: 0.4},
    ),
  ];

  /// Base currency code.
  static const baseCurrency = 'JOD';

  /// Seeded currencies. Rates are approximate reference values (1 unit in JOD)
  /// meant only as a starting point: USD uses the JOD peg (0.709); EGP, LYD and
  /// SYP float and must be updated by the user. SYP assumes the redenominated
  /// pound (100 old = 1 new).
  static const currencies = <DefaultCurrency>[
    DefaultCurrency(code: 'JOD', symbol: 'د.أ', decimals: 3, rateToBase: 1, isBase: true),
    DefaultCurrency(code: 'USD', symbol: r'$', decimals: 2, rateToBase: 0.709),
    DefaultCurrency(code: 'SYP', symbol: 'ل.س', decimals: 2, rateToBase: 0.0064),
    DefaultCurrency(code: 'EGP', symbol: 'ج.م', decimals: 2, rateToBase: 0.0145),
    DefaultCurrency(code: 'LYD', symbol: 'ل.د', decimals: 3, rateToBase: 0.13),
  ];

  static List<String> painLocations(L10n l) => [
    l.dbSeedPainHead,
    l.dbSeedPainNeck,
    l.dbSeedPainShoulders,
    l.dbSeedPainUpperBack,
    l.dbSeedPainLowerBack,
    l.dbSeedPainChest,
    l.dbSeedPainAbdomen,
    l.dbSeedPainArms,
    l.dbSeedPainHands,
    l.dbSeedPainHips,
    l.dbSeedPainKnees,
    l.dbSeedPainFeet,
    l.dbSeedPainJoints,
  ];

  static List<String> painTriggers(L10n l) => [
    l.dbSeedTriggerSleep,
    l.dbSeedTriggerStress,
    l.dbSeedTriggerSitting,
    l.dbSeedTriggerStanding,
    l.dbSeedTriggerExertion,
    l.dbSeedTriggerCold,
    l.dbSeedTriggerWeather,
    l.dbSeedTriggerFood,
    l.dbSeedTriggerWater,
    l.dbSeedTriggerMissedDose,
    l.dbSeedTriggerScreens,
  ];

  static List<String> moodFactors(L10n l) => [
    l.dbSeedMoodSleep,
    l.dbSeedMoodPrayer,
    l.dbSeedMoodFamily,
    l.dbSeedMoodWork,
    l.dbSeedMoodMoney,
    l.dbSeedMoodHealth,
    l.dbSeedMoodExercise,
    l.dbSeedMoodFriends,
    l.dbSeedMoodCaffeine,
    l.dbSeedMoodWeather,
    l.dbSeedMoodNews,
    l.dbSeedMoodLoneliness,
  ];

  /// Generic stress-reduction habits (category `stress`).
  static List<DefaultHabit> stressHabits(L10n l) => [
    DefaultHabit(l.dbSeedHabitBreathing),
    DefaultHabit(l.dbSeedHabitWalk, planetKey: 'body'),
    DefaultHabit(l.dbSeedHabitAdhkar, planetKey: 'faith'),
    DefaultHabit(l.dbSeedHabitGratitude, planetKey: 'faith'),
    DefaultHabit(l.dbSeedHabitScreens),
    DefaultHabit(l.dbSeedHabitSleep),
    DefaultHabit(l.dbSeedHabitWater, planetKey: 'body'),
    DefaultHabit(l.dbSeedHabitCaffeine),
    DefaultHabit(l.dbSeedHabitStretch, planetKey: 'body'),
    DefaultHabit(l.dbSeedHabitJournal),
    DefaultHabit(l.dbSeedHabitConnect, planetKey: 'family'),
  ];
}
