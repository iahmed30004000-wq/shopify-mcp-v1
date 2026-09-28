/// The data sources that can feed a planet's balance score.
///
/// Keys are what `Planets.sources` stores (`{"prayers": 0.6, "tasks": 0.3}`)
/// and what [PlanetScoreEngine] computes. The seeded defaults use a few
/// older names (`medications`, `boards`, `learning`); [ScoreSources.canonical]
/// maps them onto the engine's keys so both spellings work everywhere.
library;

/// Canonical source keys, their aliases and which planets derive which
/// sources by default.
abstract final class ScoreSources {
  static const prayers = 'prayers';
  static const adhkar = 'adhkar';
  static const quran = 'quran';
  static const doses = 'doses';
  static const mood = 'mood';
  static const pain = 'pain';
  static const habits = 'habits';
  static const appointments = 'appointments';
  static const contacts = 'contacts';
  static const tasks = 'tasks';
  static const cards = 'cards';
  static const projects = 'projects';
  static const budget = 'budget';
  static const transactions = 'transactions';
  static const jars = 'jars';
  static const obligations = 'obligations';
  static const debts = 'debts';
  static const goals = 'goals';
  static const workouts = 'workouts';
  static const fasting = 'fasting';
  static const water = 'water';
  static const documents = 'documents';
  static const trips = 'trips';

  /// Prefix of the per-module sources (`module:<customModuleId>`).
  static const modulePrefix = 'module:';

  /// Implicit fallback: how recently anything was logged for the planet in
  /// the activity stream. Only scored when the planet has no other source
  /// (a fresh custom planet fed by recorded completions); a weight of 0
  /// switches it off. Not listed in [all].
  static const activity = 'activity';

  /// Every source the engine can compute, in the order a settings screen
  /// lists them (grouped by life area).
  static const all = <String>[
    prayers,
    adhkar,
    quran,
    doses,
    habits,
    mood,
    pain,
    appointments,
    contacts,
    tasks,
    cards,
    projects,
    budget,
    transactions,
    jars,
    obligations,
    debts,
    goals,
    workouts,
    fasting,
    water,
    documents,
    trips,
  ];

  /// Older / alternative names used by the seeded `Planets.sources`.
  static const aliases = <String, String>{
    'medications': doses,
    'meds': doses,
    'boards': cards,
    'learning': goals,
    'contact': contacts,
  };

  /// Sources computed only for the records attached to a planet by their
  /// `planetKey` column (tasks, habits, project items) – derived for every
  /// planet that has such records, like tasks.
  static const attached = <String>{tasks, habits, projects};

  /// The sources a built-in planet derives without being asked (its
  /// signature data). Custom planets derive only [attached] sources, their
  /// modules and whatever their `sources` weights request.
  static const builtIn = <String, List<String>>{
    'faith': [prayers],
    'health': [doses],
    'family': [contacts],
    'work': [cards],
    'money': [budget, obligations, debts],
    'growth': [goals],
    'body': [workouts, fasting, water],
    'travel': [documents, trips],
  };

  /// Planet an attached record without a `planetKey` belongs to
  /// (habits → health, projects → work).
  static const attachedFallback = <String, String>{habits: 'health', projects: 'work'};

  /// The canonical engine key for a stored source key.
  static String canonical(String key) => aliases[key] ?? key;

  /// Whether [key] is a source the engine knows how to compute.
  static bool isKnown(String key) => all.contains(canonical(key)) || key == activity || key.startsWith(modulePrefix);

  /// Stored weights (any JSON map) → canonical weights. Aliases are merged
  /// into their canonical key (summed), non-numeric and negative values are
  /// dropped, NaN/infinite values ignored.
  static Map<String, double> canonicalWeights(Map<String, Object?> raw) {
    final out = <String, double>{};
    for (final e in raw.entries) {
      final v = e.value;
      if (v is! num || !v.isFinite || v < 0) continue;
      final key = canonical(e.key);
      out[key] = (out[key] ?? 0) + v.toDouble();
    }
    return out;
  }

  /// The sources worth offering in a planet's customisation sheet: its
  /// built-in ones first, then everything else.
  static List<String> suggestedFor(String planetKey) {
    final first = builtIn[planetKey] ?? const <String>[];
    return [
      ...first,
      tasks,
      for (final s in all)
        if (!first.contains(s) && s != tasks) s,
    ];
  }
}
