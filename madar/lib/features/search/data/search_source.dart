import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show IconData;

import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/money.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../domain/search_doc.dart';

/// What a source's loader gets: the repositories and the language the
/// records are written up in (records are re-read when it changes).
class SearchLoadContext {
  SearchLoadContext({
    required this.repos,
    required this.l10n,
    required this.formatter,
    String? Function(int surah)? surahName,
  }) : _surahName = surahName;

  final Repositories repos;
  final L10n l10n;
  final MadarFormatter formatter;
  final String? Function(int surah)? _surahName;

  String get languageCode => formatter.languageCode;
  bool get arabic => formatter.isArabic;

  /// `12.500 د.أ` / `JOD 12.500` in the app's digits.
  String money(int milli, String currency) => formatter.localizeDigits(
    Money(milli, currency).format(locale: formatter.languageCode, digits: MoneyDigits.western),
  );

  /// A number in the app's digits (at most two decimals).
  String number(num value) => formatter.formatNumber(value);

  /// A day in the app's style (`٢٧ سبتمبر ٢٠٢٦`).
  String date(DateTime day) => formatter.formatDate(day);

  /// The sura's name in the app's language (`البقرة`), or «سورة ٢» while the
  /// Quran data is not loaded.
  String surah(int number) =>
      _surahName?.call(number) ?? l10n.searchSurahNumber(formatter.formatInt(number, grouping: false));

  /// «البقرة · الآية ٢٥٥».
  String ayahPlace(int surah, int ayah) =>
      l10n.searchAyahPlace(this.surah(surah), formatter.formatInt(ayah, grouping: false));

  /// Non-empty [parts] joined by « · ».
  static String join(Iterable<String?> parts) => parts.where((p) => p != null && p.trim().isNotEmpty).join(' · ');
}

/// Produces the records of an indexed source.
typedef SearchDocLoader = FutureOr<List<SearchDoc>> Function(SearchLoadContext ctx);

/// A source's name in the app's language.
typedef SearchLabel = String Function(L10n l10n);

/// A module that contributes to the global search (built in, or registered
/// by the app: games, settings pages …).
@immutable
sealed class SearchSourceBase {
  const SearchSourceBase({
    required this.id,
    required this.planetKey,
    required this.icon,
    required this.labelKey,
    this.weight = 1,
    SearchLabel? label,
  }) : _label = label;

  /// Stable id (`tasks`, `quran`, `games` …); also the default group.
  final String id;

  /// Planet its records belong to unless a record says otherwise.
  final String planetKey;

  /// Group icon in the results.
  final IconData icon;

  /// Localisation key of its name (`searchSourceTasks`); resolved by
  /// [SearchLabels.source] unless [label] is given.
  final String labelKey;

  /// Ranking weight of its records (1 = normal; logs are lighter).
  final double weight;

  final SearchLabel? _label;

  /// The source's name in the app's language.
  String label(L10n l10n) => _label?.call(l10n) ?? SearchLabels.source(l10n, labelKey);
}

/// A source whose records are loaded and kept in the index. The engine
/// reloads it (debounced) when one of [tables] changes or [changes] fires,
/// and applies only the records that changed.
class SearchSource extends SearchSourceBase {
  const SearchSource({
    required super.id,
    required super.planetKey,
    required super.icon,
    required super.labelKey,
    required this.load,
    this.tables = const {},
    this.changes,
    super.weight,
    super.label,
  });

  /// A fixed list of records (settings pages, games …) re-read only when
  /// [changes] fires.
  factory SearchSource.static({
    required String id,
    required String planetKey,
    required IconData icon,
    required String labelKey,
    required List<SearchDoc> Function(SearchLoadContext ctx) docs,
    SearchLabel? label,
    double weight = 1,
    Stream<void>? changes,
  }) => SearchSource(
    id: id,
    planetKey: planetKey,
    icon: icon,
    labelKey: labelKey,
    label: label,
    weight: weight,
    changes: changes,
    load: docs,
  );

  final SearchDocLoader load;

  /// SQL tables the records are read from (`tasks`, `wallets` …).
  final Set<String> tables;

  /// Extra "records changed" signal (for sources that are not tables).
  final Stream<void>? changes;
}

/// What a live source found for a query.
@immutable
class LiveSearchResult {
  const LiveSearchResult(this.hits, this.total);

  static const empty = LiveSearchResult([], 0);

  /// Hits (scored; highlight ranges filled in by the source).
  final List<SearchHit> hits;

  /// Every match, beyond the hits returned.
  final int total;
}

/// Answers a query itself instead of being indexed (the Quran text, which
/// has its own folded index).
typedef LiveSearch = Future<LiveSearchResult> Function(String query, SearchLoadContext ctx, {int limit});

/// A source searched at query time (see [LiveSearch]).
class LiveSearchSource extends SearchSourceBase {
  const LiveSearchSource({
    required super.id,
    required super.planetKey,
    required super.icon,
    required super.labelKey,
    required this.search,
    super.weight,
    super.label,
  });

  final LiveSearch search;
}

/// The sources the global search reads. Register more at start-up (or any
/// time: the engine follows) with [register].
class SearchRegistry extends ChangeNotifier {
  SearchRegistry([Iterable<SearchSourceBase> sources = const []]) {
    for (final s in sources) {
      _sources[s.id] = s;
    }
  }

  final Map<String, SearchSourceBase> _sources = {};

  /// Every source, in registration order.
  List<SearchSourceBase> get sources => List.unmodifiable(_sources.values);

  SearchSourceBase? operator [](String id) => _sources[id];

  Iterable<SearchSource> get indexed => _sources.values.whereType<SearchSource>();
  Iterable<LiveSearchSource> get live => _sources.values.whereType<LiveSearchSource>();

  /// Adds [source], replacing one with the same id.
  void register(SearchSourceBase source) {
    _sources[source.id] = source;
    notifyListeners();
  }

  void registerAll(Iterable<SearchSourceBase> sources) {
    for (final s in sources) {
      _sources[s.id] = s;
    }
    notifyListeners();
  }

  /// Removes the source [id]; whether it was registered.
  bool unregister(String id) {
    final removed = _sources.remove(id) != null;
    if (removed) notifyListeners();
    return removed;
  }
}

/// Names of the built-in sources (by label key) and of the planets.
abstract final class SearchLabels {
  /// The name behind [key] (a `searchSource…` key); the key itself when
  /// unknown.
  static String source(L10n l, String key) => switch (key) {
    'searchSourceTasks' => l.searchSourceTasks,
    'searchSourcePrayerLogs' => l.searchSourcePrayerLogs,
    'searchSourceMedications' => l.searchSourceMedications,
    'searchSourceMedCourses' => l.searchSourceMedCourses,
    'searchSourceMedDoses' => l.searchSourceMedDoses,
    'searchSourceConditions' => l.searchSourceConditions,
    'searchSourceHealthAlerts' => l.searchSourceHealthAlerts,
    'searchSourceLabTests' => l.searchSourceLabTests,
    'searchSourceLabReadings' => l.searchSourceLabReadings,
    'searchSourceAppointments' => l.searchSourceAppointments,
    'searchSourceDoctorQuestions' => l.searchSourceDoctorQuestions,
    'searchSourcePain' => l.searchSourcePain,
    'searchSourceMood' => l.searchSourceMood,
    'searchSourceHabits' => l.searchSourceHabits,
    'searchSourceWorries' => l.searchSourceWorries,
    'searchSourceWallets' => l.searchSourceWallets,
    'searchSourceTransactions' => l.searchSourceTransactions,
    'searchSourceBudget' => l.searchSourceBudget,
    'searchSourceJars' => l.searchSourceJars,
    'searchSourceJarDeposits' => l.searchSourceJarDeposits,
    'searchSourceDebts' => l.searchSourceDebts,
    'searchSourceDebtPayments' => l.searchSourceDebtPayments,
    'searchSourceObligations' => l.searchSourceObligations,
    'searchSourcePeople' => l.searchSourcePeople,
    'searchSourceContactLogs' => l.searchSourceContactLogs,
    'searchSourceProjects' => l.searchSourceProjects,
    'searchSourceProjectItems' => l.searchSourceProjectItems,
    'searchSourceBoards' => l.searchSourceBoards,
    'searchSourceCards' => l.searchSourceCards,
    'searchSourceTrips' => l.searchSourceTrips,
    'searchSourceTripItems' => l.searchSourceTripItems,
    'searchSourcePackingTemplates' => l.searchSourcePackingTemplates,
    'searchSourceTravelDocuments' => l.searchSourceTravelDocuments,
    'searchSourceLearningGoals' => l.searchSourceLearningGoals,
    'searchSourceGoalLogs' => l.searchSourceGoalLogs,
    'searchSourceExercises' => l.searchSourceExercises,
    'searchSourceWorkouts' => l.searchSourceWorkouts,
    'searchSourceAvoidItems' => l.searchSourceAvoidItems,
    'searchSourceFasting' => l.searchSourceFasting,
    'searchSourceCustomModules' => l.searchSourceCustomModules,
    'searchSourceCustomEntries' => l.searchSourceCustomEntries,
    'searchSourceQuranAyat' => l.searchSourceQuranAyat,
    'searchSourceQuranBookmarks' => l.searchSourceQuranBookmarks,
    'searchSourceWirdPlans' => l.searchSourceWirdPlans,
    'searchSourceHifz' => l.searchSourceHifz,
    'searchSourcePlanets' => l.searchSourcePlanets,
    _ => key,
  };

  /// A built-in planet's name (`faith` → «الإيمان»), or null.
  static String? builtInPlanet(L10n l, String key) => switch (key) {
    'faith' => l.planetFaith,
    'health' => l.planetHealth,
    'family' => l.planetFamily,
    'work' => l.planetWork,
    'money' => l.planetMoney,
    'growth' => l.planetGrowth,
    'body' => l.planetBody,
    'travel' => l.planetTravel,
    'custom' => l.searchPlanetCustom,
    _ => null,
  };
}
