import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../home/home_providers.dart' show homeClockProvider;
import '../../quran/data/quran_providers.dart';
import '../../quran/domain/quran_meta.dart';
import '../domain/search_doc.dart';
import 'builtin_sources.dart';
import 'custom_module_source.dart';
import 'quran_search_source.dart';
import 'recent_searches.dart';
import 'search_engine.dart';
import 'search_source.dart';
import 'search_worker.dart';

/// Opens a result. Return true when handled; false shows "can't open this
/// here yet". The app maps [SearchDoc.openKey] / `refTable` / `refId` /
/// `extra` to its routes (see the open keys in `search.dart`).
typedef SearchOpener = FutureOr<bool> Function(BuildContext context, SearchDoc doc);

/// The app's opener (null until the app shell sets one; the screen can
/// also take one directly).
final searchOpenerProvider = Provider<SearchOpener?>((ref) => null);

/// How the search reaches the Quran (overridable in tests).
class SearchQuranAccess {
  const SearchQuranAccess({required this.meta, required this.data});

  /// Nothing Quran-related (no ayat results, sura numbers instead of names).
  static final SearchQuranAccess none = SearchQuranAccess(meta: () async => null, data: () async => null);

  final Future<QuranMeta?> Function() meta;
  final QuranSearchLoader data;
}

final searchQuranAccessProvider = Provider<SearchQuranAccess>(
  (ref) => SearchQuranAccess(
    meta: () => ref.read(quranMetaProvider.future),
    data: () async {
      final index = await ref.read(quranSearchIndexProvider.future);
      final text = await ref.read(quranTextProvider.future);
      return (index: index, ayahText: text.ayahText);
    },
  ),
);

/// Every search source: the built-in ones (all tables, custom modules) and
/// the Quran's ayat. Register more (games, settings pages …) with
/// `ref.read(searchRegistryProvider).register(...)`.
final searchRegistryProvider = Provider<SearchRegistry>((ref) {
  final quran = ref.watch(searchQuranAccessProvider);
  final registry = SearchRegistry([...BuiltInSearchSources.all(), QuranSearchSource.create(quran.data)]);
  ref.onDispose(registry.dispose);
  return registry;
});

/// Where the index lives (a background isolate; tests use
/// [InlineSearchWorker]).
final searchWorkerFactoryProvider = Provider<SearchWorkerFactory>((ref) => () => IsolateSearchWorker.spawn());

/// "Now" for recency and result dates.
final searchClockProvider = Provider<DateTime Function()>((ref) => ref.watch(homeClockProvider));

/// Debounce of index updates after database changes.
final searchDebounceProvider = Provider<Duration>((ref) => const Duration(milliseconds: 350));

/// The global search engine (lazy: nothing is read until the search is
/// first used). Rebuilt when the language or digit style changes, since
/// records are written up in them. It lives while a search screen listens:
/// closing the last one stops it (its index isolate and database listener
/// with it), and the next search builds the index again.
final searchEngineProvider = Provider.autoDispose<SearchEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final registry = ref.watch(searchRegistryProvider);
  final quran = ref.watch(searchQuranAccessProvider);
  final (language, digits) = ref.watch(appSettingsProvider.select((s) => (s.languageCode, s.digits)));
  final engine = SearchEngine(
    db: db,
    registry: registry,
    workerFactory: ref.watch(searchWorkerFactoryProvider),
    clock: ref.watch(searchClockProvider),
    debounce: ref.watch(searchDebounceProvider),
    context: () async {
      QuranMeta? meta;
      try {
        meta = await quran.meta().timeout(const Duration(seconds: 3));
      } on Object {
        meta = null;
      }
      final arabic = language != 'en';
      final m = meta;
      // Records are written up away from any widget: make sure the date
      // names of the language are loaded.
      try {
        await initializeDateFormatting(arabic ? 'ar' : 'en');
      } on Object {
        // Dates fall back to yyyy-MM-dd.
      }
      return SearchLoadContext(
        repos: Repositories(db),
        l10n: lookupL10n(Locale(arabic ? 'ar' : 'en')),
        formatter: MadarFormatter(languageCode: arabic ? 'ar' : 'en', digits: digits),
        surahName: m == null ? null : (s) => arabic ? m.surah(s).nameArabic : m.surah(s).nameEnglish,
      );
    },
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final recentSearchesStoreProvider = Provider<RecentSearchesStore>(
  (ref) => RecentSearchesStore(ref.watch(repositoriesProvider).keyValues),
);

/// The last searches, newest first.
final recentSearchesProvider = StreamProvider<List<String>>((ref) => ref.watch(recentSearchesStoreProvider).watch());

/// Planets (names, colours) for filter chips and result orbs.
final searchPlanetsProvider = StreamProvider<List<PlanetRow>>((ref) => ref.watch(repositoriesProvider).planets.watchAll());

/// Custom modules by id (names, icons, colours of their result groups).
final searchModuleGroupsProvider = StreamProvider<Map<String, CustomModuleRowLike>>(
  (ref) => ref
      .watch(repositoriesProvider)
      .customModules
      .watchAll()
      .map((rows) => {for (final m in rows) m.id: CustomModuleRowLike(m.id, m.name, m.planetKey, m.icon, m.color)}),
);
