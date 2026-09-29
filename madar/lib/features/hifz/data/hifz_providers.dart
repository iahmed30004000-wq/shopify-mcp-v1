import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/quran/ayah.dart';
import '../../wird/data/wird_providers.dart';
import '../../wird/domain/calendar_days.dart';
import '../domain/hadith_collection.dart';
import '../domain/hifz_models.dart';
import '../domain/hifz_reveal.dart';
import '../domain/hifz_session.dart';
import 'hifz_service.dart';

/// Where bundled data is read from (tests override it).
final hifzAssetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// An-Nawawi's Forty Hadith (bundled, Arabic).
final hadithCollectionProvider = FutureProvider<HadithCollection>((ref) async {
  final raw = await ref.watch(hifzAssetBundleProvider).loadString(HadithCollection.nawawiAsset);
  return HadithCollection.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
});

final hifzServiceProvider = Provider<HifzService>(
  (ref) => HifzService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(wirdClockProvider),
    recorder: ref.watch(wirdActivityRecorderProvider),
  ),
);

final hifzCardsProvider = StreamProvider<List<HifzCard>>((ref) => ref.watch(hifzServiceProvider).watchCards());

final hifzReviewsProvider = StreamProvider<List<HifzReviewLog>>((ref) => ref.watch(hifzServiceProvider).watchReviews());

final hifzSettingsProvider = StreamProvider<HifzSettings>((ref) => ref.watch(hifzServiceProvider).watchSettings());

/// Today's numbers.
final hifzStatsProvider = Provider<AsyncValue<HifzStats>>((ref) {
  final cards = ref.watch(hifzCardsProvider);
  final reviews = ref.watch(hifzReviewsProvider);
  final settings = ref.watch(hifzSettingsProvider).value ?? const HifzSettings();
  final today = ref.watch(wirdTodayProvider);
  if (cards.hasError) return AsyncError(cards.error!, cards.stackTrace ?? StackTrace.current);
  final c = cards.value, r = reviews.value;
  if (c == null || r == null) return const AsyncLoading();
  return AsyncData(HifzStats.compute(cards: c, reviews: r, today: today, newPerDay: settings.newPerDay));
});

/// Today's review queue (due, then new up to the daily limit).
final hifzQueueProvider = Provider<AsyncValue<List<HifzCard>>>((ref) {
  final cards = ref.watch(hifzCardsProvider);
  final reviews = ref.watch(hifzReviewsProvider);
  final settings = ref.watch(hifzSettingsProvider).value ?? const HifzSettings();
  final today = ref.watch(wirdTodayProvider);
  final c = cards.value, r = reviews.value;
  if (c == null || r == null) return const AsyncLoading();
  return AsyncData(HifzQueue.build(cards: c, reviews: r, today: today, newPerDay: settings.newPerDay));
});

/// What adding a range to Hifz did.
@immutable
class HifzAddResult {
  const HifzAddResult(this.added, this.undo);

  final List<HifzCard> added;
  final HifzUndo undo;
}

/// "Add to Hifz" for other features (the Quran reader's ayah menu).
class HifzImport {
  HifzImport(this._ref);

  final Ref _ref;

  /// Adds [range] to Hifz, split into chunks of the user's chunk size
  /// (chunks already there are skipped). Undo with [HifzAddResult.undo].
  Future<HifzAddResult> addAyahRangeToHifz(AyahRange range) async {
    final catalog = await _ref.read(quranCatalogReadyProvider.future);
    final settings = await _ref.read(hifzServiceProvider).settings();
    final (added, undo) = await _ref
        .read(hifzServiceProvider)
        .addAyahRange(range, ayahCount: catalog.ayahCount, chunkSize: settings.chunkSize);
    return HifzAddResult(added, undo);
  }
}

final hifzImportProvider = Provider<HifzImport>(HifzImport.new);

/// Runs one review session: grades are written as they are given (and undone
/// exactly); the session is logged as a `quran.hifz` activity when it ends
/// or is left with grades in it.
class HifzReviewController extends ChangeNotifier {
  HifzReviewController({required this.service, required Iterable<HifzCard> queue, required this.clock})
    : session = HifzSession(queue),
      sessionId = 'hifz:${clock().microsecondsSinceEpoch}';

  final HifzService service;
  final DateTime Function() clock;
  final HifzSession session;
  final String sessionId;
  final List<HifzUndo> _undos = [];
  bool _logged = false;
  bool _busy = false;
  HifzGradeOutcome? _last;

  bool get busy => _busy;

  /// The last grade given (for "next review in …").
  HifzGradeOutcome? get last => _last;

  Future<HifzGradeOutcome?> grade(int quality) async {
    if (_busy || session.isComplete) return null;
    _busy = true;
    try {
      final o = session.grade(quality, clock());
      _undos.add(await service.applyGrade(o));
      _last = o;
      if (session.isComplete) await finish();
      return o;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<HifzGradeOutcome?> undo() async {
    if (_busy || !session.canUndo) return null;
    _busy = true;
    try {
      final o = session.undo();
      if (_undos.isNotEmpty) await _undos.removeLast()();
      _last = session.history.isEmpty ? null : session.history.last;
      return o;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Logs the session (once).
  Future<void> finish() async {
    if (_logged) return;
    final summary = session.summary;
    if (summary.reviewed == 0) return;
    _logged = true;
    await service.recordSession(sessionId, summary);
  }

  /// Due tomorrow after this session (for the summary).
  int dueTomorrow(List<HifzCard> cards, DateTime today) => hifzDueOn(cards, CalendarDays.add(today, 1));
}

/// The ayah-end marker (U+06DD) with the ayah number in Arabic-Indic digits:
/// Amiri Quran draws it as the ornate end-of-ayah medallion.
String hifzAyahMarker(int ayah) => '۝${Digits.toArabicIndic('$ayah')}';

/// The words to recall of [card]: an ayat item's Uthmani text (each ayah
/// ending with its marker), or a hadith's / custom item's text.
final hifzTokensProvider = FutureProvider.autoDispose.family<List<HifzToken>, HifzCard>((ref, card) async {
  switch (card.kind) {
    case HifzKind.ayat:
      final range = card.range;
      if (range == null) return const [];
      final catalog = await ref.watch(quranCatalogReadyProvider.future);
      final ayat = <(int, String)>[];
      for (var a = range.first.ayah; a <= range.last.ayah; a++) {
        ayat.add((a, await catalog.ayahText(AyahRef(range.first.surah, a))));
      }
      return HifzText.ayatTokens(ayat, hifzAyahMarker);
    case HifzKind.hadith:
      final collection = await ref.watch(hadithCollectionProvider.future);
      final text = collection.byKey(card.source)?.text ?? card.body ?? '';
      return HifzText.textTokens(text);
    case HifzKind.custom:
      return HifzText.textTokens(card.body ?? '');
  }
});
