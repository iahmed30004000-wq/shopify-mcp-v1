/// «الحفظ» · every read and write Part 14 needs (step 1).
///
/// The engine itself is pure Dart in `domain/`; this is the only part that
/// touches the database, and it touches exactly two tables of its own –
/// `hifz_goals` and `hifz_marks` (schema v8) – plus the key-value row with
/// his plan settings. Every write returns an undo that puts the exact
/// prior state back, as `TasmeeService` and `SufraService` do.
///
/// **The strength is never written.** There is no column for it anywhere:
/// it is computed from Part 13's log on every read, so it can never fall
/// out of step with the results it came from.
///
/// **The results themselves stay in Part 13's log.** When he finishes a
/// drill – written, hidden, blanks, linking – this service hands the check
/// to [TasmeeService.recordCheck] with the right [TasmeeMode]; there is no
/// second log and no second mistake table.
library;

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/quran/quran_catalog.dart';
import '../../tasmee/tasmee.dart';
import '../../wird/domain/calendar_days.dart';
import '../../wird/domain/quran_axis.dart';
import '../domain/hifz_daily_plan.dart';
import '../domain/hifz_export.dart';
import '../domain/hifz_goals.dart';
import '../domain/hifz_marks.dart';
import '../domain/hifz_models.dart';
import '../domain/hifz_modes.dart';
import '../domain/hifz_page_map.dart';
import '../domain/hifz_progress.dart';
import '../domain/hifz_strength.dart';
import '../domain/mushaf_shape.dart';

/// Reverses one change (the UI wraps it in an undo toast).
typedef HifzPlanUndo = Future<void> Function();

/// The mushaf's shape over the app's own [QuranCatalog].
///
/// It adds nothing to the catalogue: the page and juz' boundaries, the
/// ayah counts and the reading order are all the bundled Madani data. The
/// reading-order arithmetic is the wird's [QuranIndex], so the two
/// features cannot disagree about where an ayah is.
class CatalogMushafShape implements MushafShape {
  CatalogMushafShape(this.catalog) : _index = QuranIndex(catalog);

  /// Waits for the catalogue's data, then builds the shape.
  static Future<CatalogMushafShape> load(QuranCatalog catalog) async {
    await catalog.ensureLoaded();
    return CatalogMushafShape(catalog);
  }

  final QuranCatalog catalog;
  final QuranIndex _index;

  @override
  int get surahCount => catalog.surahCount;

  @override
  int get pageCount => 604;

  @override
  int get ayahTotal => _index.total;

  @override
  int ayahCount(int surah) => catalog.ayahCount(surah);

  @override
  int indexOf(AyahRef ref) => _index.indexOf(ref);

  @override
  AyahRef refAt(int index) => _index.refAt(index);

  @override
  int pageOf(AyahRef ref) => catalog.pageOf(ref);

  @override
  AyahRef pageStart(int page) => catalog.pageStart(page.clamp(1, pageCount));

  @override
  AyahRef pageEnd(int page) {
    final p = page.clamp(1, pageCount);
    if (p == pageCount) return refAt(ayahTotal - 1);
    return refAt(indexOf(catalog.pageStart(p + 1)) - 1);
  }

  @override
  int juzOf(AyahRef ref) => catalog.juzOf(ref);

  @override
  int hizbOf(AyahRef ref) => catalog.hizbOf(ref);
}

/// Row → model, and back.
abstract final class HifzPlanRows {
  static AyahRange? rangeOf(int? fromSurah, int? fromAyah, int? toSurah, int? toAyah) {
    if (fromSurah == null || fromAyah == null || toSurah == null || toAyah == null) return null;
    final first = AyahRef(fromSurah.clamp(1, 114), fromAyah < 1 ? 1 : fromAyah);
    final last = AyahRef(toSurah.clamp(1, 114), toAyah < 1 ? 1 : toAyah);
    return last < first ? AyahRange(last, first) : AyahRange(first, last);
  }

  static HifzGoal goal(HifzGoalRow r) => HifzGoal(
    id: r.id,
    title: r.title,
    kind: r.kind,
    range: rangeOf(r.fromSurah, r.fromAyah, r.toSurah, r.toAyah),
    weekday: r.weekday,
    amount: r.amount,
    unit: r.unit,
    window: r.window,
    offsetMinutes: r.offsetMinutes,
    remind: r.remind,
    active: r.active,
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
  );

  static HifzMark mark(HifzMarkRow r) => HifzMark(
    id: r.id,
    kind: r.kind,
    range: rangeOf(r.fromSurah, r.fromAyah, r.toSurah, r.toAyah)!,
    createdAt: r.createdAt,
    since: r.since,
    note: r.note,
  );
}

/// Every read and write of «الحفظ».
class HifzPlanService {
  HifzPlanService({required this.repos, required this.tasmee, required this.shape, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  final Repositories repos;

  /// Part 13's log – the only place a result is ever written.
  final TasmeeService tasmee;

  final MushafShape shape;
  final DateTime Function() clock;

  MadarDatabase get _db => repos.db;

  DateTime get today {
    final now = clock();
    return DateTime(now.year, now.month, now.day);
  }

  // ------------------------------------------------------------ settings ----

  static const _settingsKey = KvKey<HifzPlanSettings>(
    HifzPlanSettings.storageKey,
    decode: HifzPlanSettings.fromJson,
    encode: _encodeSettings,
  );

  static Object? _encodeSettings(HifzPlanSettings s) => s.toJson();

  Future<HifzPlanSettings> settings() async => await repos.keyValues.get(_settingsKey) ?? const HifzPlanSettings();

  Stream<HifzPlanSettings> watchSettings() =>
      repos.keyValues.watch(_settingsKey).map((s) => s ?? const HifzPlanSettings()).distinct();

  Future<HifzPlanUndo> setSettings(HifzPlanSettings settings) async {
    final had = await repos.keyValues.contains(HifzPlanSettings.storageKey);
    final before = await repos.keyValues.getJson(HifzPlanSettings.storageKey);
    await repos.keyValues.set(_settingsKey, settings);
    return () async {
      if (had) {
        await repos.keyValues.setJson(HifzPlanSettings.storageKey, before);
      } else {
        await repos.keyValues.remove(HifzPlanSettings.storageKey);
      }
    };
  }

  /// Moves the new-portion cursor on (after he finished today's «جديد»).
  Future<HifzPlanUndo> setNewFrom(AyahRef? ref) async {
    final current = await settings();
    return setSettings(ref == null ? current.copyWith(clearNewFrom: true) : current.copyWith(newFrom: ref));
  }

  // --------------------------------------------------------------- goals ----

  Future<List<HifzGoal>> goals() async => [for (final r in await repos.hifzGoals.getAll()) HifzPlanRows.goal(r)];

  Stream<List<HifzGoal>> watchGoals() =>
      repos.hifzGoals.watchAll().map((rows) => [for (final r in rows) HifzPlanRows.goal(r)]);

  Future<HifzGoal?> goal(String id) async {
    final row = await repos.hifzGoals.byId(id);
    return row == null ? null : HifzPlanRows.goal(row);
  }

  /// Adds a goal in his own words.
  Future<(HifzGoal, HifzPlanUndo)> addGoal({
    required String title,
    required HifzGoalKind kind,
    AyahRange? range,
    int? weekday,
    double? amount,
    WirdUnit unit = WirdUnit.pages,
    PrayerWindow? window,
    int offsetMinutes = 15,
    bool remind = true,
    bool active = true,
  }) async {
    final id = newId();
    final now = clock();
    final order = (await repos.hifzGoals.getAll()).length;
    await _db.into(_db.hifzGoals).insert(
      HifzGoalsCompanion.insert(
        id: Value(id),
        title: title,
        kind: kind,
        fromSurah: Value(range?.first.surah),
        fromAyah: Value(range?.first.ayah),
        toSurah: Value(range?.last.surah),
        toAyah: Value(range?.last.ayah),
        weekday: Value(weekday),
        amount: Value(amount),
        unit: Value(unit),
        window: Value(window),
        offsetMinutes: Value(offsetMinutes),
        remind: Value(remind),
        active: Value(active),
        sortOrder: Value(order),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    final written = (await goal(id))!;
    return (written, () async => repos.hifzGoals.delete(id));
  }

  Future<HifzPlanUndo> _changeGoal(String id, HifzGoalRow Function(HifzGoalRow row) change) async {
    final before = await repos.hifzGoals.byId(id);
    if (before == null) return () async {};
    await repos.hifzGoals.restore(change(before).copyWith(updatedAt: clock()));
    return () async => repos.hifzGoals.restore(before);
  }

  /// Changes a goal; anything left out stays as it was.
  Future<HifzPlanUndo> editGoal(
    String id, {
    String? title,
    AyahRange? range,
    int? weekday,
    double? amount,
    WirdUnit? unit,
    PrayerWindow? window,
    int? offsetMinutes,
    bool? remind,
    bool? active,
  }) => _changeGoal(
    id,
    (row) => row.copyWith(
      title: title ?? row.title,
      fromSurah: Value(range?.first.surah ?? row.fromSurah),
      fromAyah: Value(range?.first.ayah ?? row.fromAyah),
      toSurah: Value(range?.last.surah ?? row.toSurah),
      toAyah: Value(range?.last.ayah ?? row.toAyah),
      weekday: Value(weekday ?? row.weekday),
      amount: Value(amount ?? row.amount),
      unit: unit ?? row.unit,
      window: Value(window ?? row.window),
      offsetMinutes: offsetMinutes ?? row.offsetMinutes,
      remind: remind ?? row.remind,
      active: active ?? row.active,
    ),
  );

  Future<HifzPlanUndo> setGoalActive(String id, bool active) => _changeGoal(id, (r) => r.copyWith(active: active));

  Future<HifzPlanUndo> deleteGoal(String id) async {
    final row = await repos.hifzGoals.byId(id);
    if (row == null) return () async {};
    await repos.hifzGoals.delete(id);
    return () async => repos.hifzGoals.restore(row);
  }

  Future<void> reorderGoals(List<String> ids) => repos.hifzGoals.reorder(ids);

  // --------------------------------------------------------------- marks ----

  Future<HifzMarks> marks() async =>
      HifzMarks.of([for (final r in await repos.hifzMarks.getAll()) HifzPlanRows.mark(r)]);

  Stream<HifzMarks> watchMarks() =>
      repos.hifzMarks.watchAll().map((rows) => HifzMarks.of([for (final r in rows) HifzPlanRows.mark(r)]));

  Future<(HifzMark, HifzPlanUndo)> _addMark(HifzMarkKind kind, AyahRange range, {DateTime? since, String? note}) async {
    final id = newId();
    final now = clock();
    await _db.into(_db.hifzMarks).insert(
      HifzMarksCompanion.insert(
        id: Value(id),
        kind: kind,
        fromSurah: range.first.surah,
        fromAyah: range.first.ayah,
        toSurah: range.last.surah,
        toAyah: range.last.ayah,
        since: Value(since),
        note: Value(note),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    final row = await repos.hifzMarks.byId(id);
    return (HifzPlanRows.mark(row!), () async => repos.hifzMarks.delete(id));
  }

  /// «مش عليّ»: this stretch is not his to review.
  Future<(HifzMark, HifzPlanUndo)> markSkipped(AyahRange range, {String? note}) =>
      _addMark(HifzMarkKind.skipReview, range, note: note);

  /// «صفّر القوة»: start this stretch's strength again from [since] (today
  /// by default). Nothing is deleted – the log keeps every attempt.
  Future<(HifzMark, HifzPlanUndo)> resetStrength(AyahRange range, {DateTime? since, String? note}) =>
      _addMark(HifzMarkKind.resetStrength, range, since: since ?? today, note: note);

  /// Resets one whole page.
  Future<(HifzMark, HifzPlanUndo)> resetPage(int page, {DateTime? since, String? note}) =>
      resetStrength(AyahRange(shape.pageStart(page), shape.pageEnd(page)), since: since, note: note);

  Future<HifzPlanUndo> removeMark(String id) async {
    final row = await repos.hifzMarks.byId(id);
    if (row == null) return () async {};
    await repos.hifzMarks.delete(id);
    return () async => repos.hifzMarks.restore(row);
  }

  // ----------------------------------------------------- his inventory ----

  /// The ayah ranges of his Hifz list (`hifz_items`), the suspended ones
  /// left out – they are paused on purpose.
  Future<List<AyahRange>> memorised({bool includeSuspended = false}) async {
    final rows = await repos.hifzItems.getAll();
    final out = <AyahRange>[];
    for (final row in rows) {
      final card = HifzCard.fromRow(row);
      if (card.kind != HifzKind.ayat) continue;
      if (!includeSuspended && card.suspended) continue;
      final range = card.range;
      if (range != null) out.add(range);
    }
    return out;
  }

  /// The days he actually did something – «التسميع» and the Hifz reviews
  /// both count, because both are him turning up.
  Future<Set<DateTime>> activeDays() async {
    final days = <DateTime>{};
    for (final row in await tasmee.ayahRows()) {
      days.add(CalendarDays.dateOnly(row.day));
    }
    for (final row in await repos.hifzReviews.getAll()) {
      days.add(CalendarDays.dateOnly(row.at));
    }
    return days;
  }

  // ------------------------------------------------------------- reads ----

  /// The strength of every ayah he has a result for.
  Future<HifzStrengths> strengths({HifzStrengthModel model = HifzStrengthModel.standard}) async =>
      HifzStrengths.of(await tasmee.log(), today: today, model: model, marks: await marks());

  /// Today's plan.
  ///
  /// [methods] says what the phone can do right now; with nothing given it
  /// assumes the worst about the microphone (there is no speech model in
  /// this build) and plans the written modes instead – so the plan is
  /// never built on a promise the phone cannot keep.
  Future<HifzDailyPlan> plan({List<HifzMethodState>? methods, DateTime? day}) async {
    final s = await settings();
    return HifzPlanner.planFor(
      today: day ?? today,
      shape: shape,
      memorised: await memorised(),
      strengths: await strengths(),
      settings: s,
      methods: methods ?? HifzMethods.all(recogniser: _noRecogniser),
      activeDays: await activeDays(),
    );
  }

  static const RecogniserAvailability _noRecogniser = RecogniserAvailability(
    trouble: RecogniserTrouble.notImplemented,
    detail: 'No on-device recitation model in this build',
  );

  /// The mushaf coloured by strength.
  Future<HifzPageMap> pageMap({int? firstPage, int? lastPage}) async => HifzPageMap.build(
    shape: shape,
    strengths: await strengths(),
    memorised: await memorised(),
    firstPage: firstPage,
    lastPage: lastPage,
  );

  /// Streaks and the heatmap.
  Future<HifzProgress> progress() async => HifzProgress.of(
    stats: await tasmee.stats(),
    strengths: await strengths(),
    pageMap: await pageMap(),
  );

  /// Where every goal stands today.
  Future<List<HifzGoalProgress>> goalProgress({DateTime? day}) async =>
      HifzGoalProgressReader.all(await goals(), day: day ?? today, shape: shape, log: await tasmee.log());

  // ------------------------------------------------------------ writes ----

  /// Writes a finished drill into **Part 13's** log, under the mode that
  /// matches the method. Returns the session and the undo.
  ///
  /// [recogniser] is who judged it: for a typed answer that is
  /// [TypedWords.byHand], so a reader of the export can see at a glance
  /// that no speech model was involved.
  Future<(TasmeeSession, TasmeeUndo)> recordDrill(
    RecitationCheck check, {
    required HifzMethod method,
    RecogniserInfo recogniser = TypedWords.byHand,
    DateTime? startedAt,
    int? seed,
    String? note,
  }) {
    final mode = HifzMethods.logModeOf(method);
    if (mode == null) {
      throw ArgumentError.value(method, 'method', 'This mode judges nothing, so it writes no result');
    }
    return tasmee.recordCheck(check, mode: mode, recogniser: recogniser, startedAt: startedAt, seed: seed, note: note);
  }

  /// Writes what he wrote from memory.
  Future<(TasmeeSession, TasmeeUndo)> recordWriting(
    WritingResult result, {
    DateTime? startedAt,
    String? note,
  }) => recordDrill(result.check, method: HifzMethod.writing, startedAt: startedAt, note: note);

  // ------------------------------------------------------------ export ----

  /// Part 13's documented export with «الحفظ»'s block inside it – one
  /// file, one format, for «فلك».
  Future<Map<String, Object?>> exportJson({DateTime? exportedAt, bool? includeHeard}) async {
    final base = await tasmee.exportJson(exportedAt: exportedAt, includeHeard: includeHeard);
    return HifzExport.extend(
      base,
      settings: await settings(),
      goals: await goalProgress(),
      marks: await marks(),
      strengths: await strengths(),
      plan: await plan(),
      pageMap: await pageMap(),
    );
  }
}
