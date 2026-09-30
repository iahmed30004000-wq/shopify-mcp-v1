/// Global search across every module of Madar.
///
/// * [SearchRegistry] (`searchRegistryProvider`) – the sources: one per table
///   with user-written text ([BuiltInSearchSources]), every custom module
///   ([CustomModuleSearch]), and the Quran's ayat ([QuranSearchSource],
///   searched live by the Quran's own index). Register more with
///   `ref.read(searchRegistryProvider).register(SearchSource.static(...))`.
/// * [SearchEngine] (`searchEngineProvider`) – builds an in-memory inverted
///   index on a background isolate on first use, follows database changes
///   (debounced, only changed records re-indexed) and answers queries.
/// * [GlobalSearchScreen], [SearchResultTile], [SearchLauncher] – the UI.
///   Results open through `searchOpenerProvider` (or the screen's
///   `onOpen`), which maps [SearchDoc.openKey] / `refTable` / `refId` /
///   `extra` to routes.
///
/// Open keys: the SQL table of the record (`tasks`, `transactions`,
/// `board_cards` …, `extra` carries parent ids such as `boardId`,
/// `projectId`, `personId`, `walletId`, `moduleId`), `planets` (refId = the
/// planet key), `quran.ayah` (`extra`: `surah`, `ayah`).
///
/// Never indexed: key/values (settings), reminders, the activity stream,
/// import archives, travel-document numbers and phone numbers. The index
/// lives only in memory.
library;

export 'data/builtin_sources.dart' show BuiltInSearchSources;
export 'data/custom_module_source.dart' show CustomModuleSearch, CustomModuleRowLike;
export 'data/quran_search_source.dart' show QuranSearchSource, QuranSearchData, QuranSearchLoader;
export 'data/recent_searches.dart' show RecentSearchesStore;
export 'data/search_engine.dart' show SearchEngine, SearchEngineStatus, SearchContextFactory;
export 'data/search_providers.dart';
export 'data/search_source.dart';
export 'data/search_worker.dart';
export 'domain/search_doc.dart';
export 'domain/search_index.dart' show SearchIndex, SearchIndexLimits, SearchScoring;
export 'domain/search_results.dart';
export 'domain/search_text.dart';
export 'presentation/global_search_screen.dart' show GlobalSearchScreen;
export 'presentation/search_launcher.dart' show SearchLauncher;
export 'presentation/search_result_tile.dart' show SearchResultTile;
export 'presentation/search_visuals.dart' show SearchVisual, SearchVisuals, searchHighlightSpan;
