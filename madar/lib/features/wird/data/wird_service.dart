import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import '../domain/calendar_days.dart';
import '../domain/quran_axis.dart';
import '../domain/wird_engine.dart';
import '../domain/wird_plan.dart';

/// Undoes one wird change exactly.
typedef WirdUndo = Future<void> Function();

/// Writes one activity entry (the app's goes through the orbit pulse hub so
/// the Faith world pulses).
typedef WirdActivityRecorder = Future<void> Function({
  required String kind,
  required String refTable,
  required String refId,
  required DateTime at,
  double? value,
  Map<String, Object?> payload,
});

/// How the wird shows up in the activity stream (the Faith planet's `quran`
/// score source counts kinds containing `quran`).
abstract final class WirdActivity {
  static const String planetKey = 'faith';
  static const String kind = 'quran.wird';
  static const String refTable = 'wird_plans';

  /// One entry per plan and day: `<planId>:2026-09-28`.
  static String refIdFor(String planId, DateTime day) => '$planId:${CalendarDays.key(day)}';
}

/// What the plan editor produces.
@immutable
class WirdDraft {
  const WirdDraft({
    required this.name,
    required this.template,
    this.amount = 2,
    this.khatmaDays = 30,
    this.start = const AyahRef(1, 1),
    required this.startDate,
    this.window,
    this.catchUp = WirdCatchUp.spread,
    this.remind = true,
    this.remindOffsetMin = 15,
  });

  /// The editor's starting values for [plan].
  factory WirdDraft.of(WirdPlan plan) => WirdDraft(
    name: plan.name,
    template: plan.template,
    amount: plan.amountPerDay,
    khatmaDays: plan.khatmaDays ?? 30,
    start: plan.start,
    startDate: plan.startDate,
    window: plan.window,
    catchUp: plan.meta.catchUp,
    remind: plan.meta.remind,
    remindOffsetMin: plan.meta.remindOffsetMin,
  );

  final String name;
  final WirdTemplate template;

  /// Units a day (open-ended templates).
  final double amount;

  /// Length of a khatma.
  final int khatmaDays;
  final AyahRef start;
  final DateTime startDate;
  final PrayerWindow? window;
  final WirdCatchUp catchUp;
  final bool remind;
  final int remindOffsetMin;

  WirdUnit get unit => template.unit;
  bool get isKhatma => template == WirdTemplate.khatma;
  DateTime? get targetDate => isKhatma ? CalendarDays.add(startDate, khatmaDays - 1) : null;

  /// Units a day: [amount], or for a khatma the pages left from [start]
  /// over [khatmaDays] (with [pagesAxis]; 604 / days without one).
  double amountPerDay([QuranAxis? pagesAxis]) {
    if (!isKhatma) return amount;
    final pages = pagesAxis == null ? 604.0 : 604 - pagesAxis.positionOf(pagesAxis.index.indexOf(start));
    return pages / math.max(1, khatmaDays);
  }

  WirdDraft copyWith({
    String? name,
    WirdTemplate? template,
    double? amount,
    int? khatmaDays,
    AyahRef? start,
    DateTime? startDate,
    PrayerWindow? window,
    bool clearWindow = false,
    WirdCatchUp? catchUp,
    bool? remind,
    int? remindOffsetMin,
  }) => WirdDraft(
    name: name ?? this.name,
    template: template ?? this.template,
    amount: amount ?? this.amount,
    khatmaDays: khatmaDays ?? this.khatmaDays,
    start: start ?? this.start,
    startDate: startDate ?? this.startDate,
    window: clearWindow ? null : (window ?? this.window),
    catchUp: catchUp ?? this.catchUp,
    remind: remind ?? this.remind,
    remindOffsetMin: remindOffsetMin ?? this.remindOffsetMin,
  );

  WirdPlanMeta meta([WirdPlanMeta base = const WirdPlanMeta()]) =>
      base.copyWith(catchUp: catchUp, remind: remind, remindOffsetMin: remindOffsetMin);
}

/// Reads and writes wird plans (`wird_plans` + `key_values` `wird.meta` /
/// `wird.primary`) and the sessions that move them (`quran_sessions`).
/// Every write returns a [WirdUndo] that restores the exact prior state.
class WirdService {
  WirdService(this.repos, {required this.clock, this.recorder});

  final Repositories repos;
  final DateTime Function() clock;
  final WirdActivityRecorder? recorder;

  static const String metaKey = 'wird.meta';
  static const String primaryKey = 'wird.primary';

  KeyValueRepository get _kv => repos.keyValues;

  DateTime get _today => CalendarDays.dateOnly(clock());

  // ---------------------------------------------------------------- reads --

  Stream<List<WirdPlanRow>> watchRows() => repos.wirdPlans.watchAll();

  Stream<Map<String, WirdPlanMeta>> watchMeta() => _kv.watchJson(metaKey).map(_decodeMeta);

  Stream<String?> watchPrimaryId() => _kv.watchJson(primaryKey).map((v) => v is String ? v : null);

  Stream<List<WirdSession>> watchSessions() =>
      repos.quranSessions.watchAll().map((rows) => [for (final r in rows) WirdSession.fromRow(r)]);

  Future<List<WirdPlan>> plans() async {
    final rows = await repos.wirdPlans.getAll();
    final meta = _decodeMeta(await _kv.getJson(metaKey));
    return [for (final r in rows) WirdPlan.fromRow(r, meta[r.id] ?? const WirdPlanMeta())];
  }

  static Map<String, WirdPlanMeta> _decodeMeta(Object? json) => {
    if (json is Map)
      for (final e in json.entries)
        if (e.key is String) e.key as String: WirdPlanMeta.fromJson(e.value),
  };

  /// The primary plan: the stored choice if it still exists, else the first
  /// active plan, else the first plan.
  static WirdPlan? primaryOf(List<WirdPlan> plans, String? primaryId) {
    if (plans.isEmpty) return null;
    for (final p in plans) {
      if (p.id == primaryId) return p;
    }
    for (final p in plans) {
      if (p.active) return p;
    }
    return plans.first;
  }

  Future<Map<String, Object?>> _rawMeta() async {
    final json = await _kv.getJson(metaKey);
    return json is Map ? {for (final e in json.entries) '${e.key}': e.value} : {};
  }

  Future<void> _putMeta(String id, WirdPlanMeta? meta) async {
    final all = await _rawMeta();
    if (meta == null) {
      all.remove(id);
    } else {
      all[id] = meta.toJson();
    }
    await _kv.setJson(metaKey, all);
  }

  Future<WirdUndo> _metaUndo(String id) async {
    final before = (await _rawMeta())[id];
    return () async {
      final all = await _rawMeta();
      if (before == null) {
        all.remove(id);
      } else {
        all[id] = before;
      }
      await _kv.setJson(metaKey, all);
    };
  }

  // --------------------------------------------------------------- writes --

  /// Adds a plan (the first one becomes primary). Returns it with the undo.
  Future<(WirdPlan, WirdUndo)> create(WirdDraft draft, {QuranAxis? pagesAxis}) async {
    final row = await repos.wirdPlans.insert(
      WirdPlansCompanion.insert(
        name: draft.name.trim(),
        unit: Value(draft.unit),
        amountPerDay: draft.amountPerDay(pagesAxis),
        startSurah: Value(draft.start.surah),
        startAyah: Value(draft.start.ayah),
        startDate: draft.startDate,
        targetDate: Value(draft.targetDate),
        window: Value(draft.window),
      ),
    );
    final meta = draft.meta();
    await _putMeta(row.id, meta);
    final primaryBefore = await _kv.getJson(primaryKey);
    final hadPrimary = primaryBefore is String && await repos.wirdPlans.byId(primaryBefore) != null;
    if (!hadPrimary) await _kv.setJson(primaryKey, row.id);
    Future<void> undo() async {
      await repos.wirdPlans.delete(row.id);
      await _putMeta(row.id, null);
      if (!hadPrimary) {
        if (primaryBefore == null) {
          await _kv.remove(primaryKey);
        } else {
          await _kv.setJson(primaryKey, primaryBefore);
        }
      }
    }

    return (WirdPlan.fromRow(row, meta), undo);
  }

  /// Rewrites [plan] from [draft] (progress and history are kept).
  Future<WirdUndo> update(WirdPlan plan, WirdDraft draft, {QuranAxis? pagesAxis}) async {
    final before = await repos.wirdPlans.byId(plan.id);
    if (before == null) return () async {};
    final undoMeta = await _metaUndo(plan.id);
    await repos.wirdPlans.update(
      before.copyWith(
        name: draft.name.trim(),
        unit: draft.unit,
        amountPerDay: draft.amountPerDay(pagesAxis),
        startSurah: draft.start.surah,
        startAyah: draft.start.ayah,
        startDate: draft.startDate,
        targetDate: Value(draft.targetDate),
        window: Value(draft.window),
      ),
    );
    await _putMeta(plan.id, draft.meta(plan.meta));
    return () async {
      await repos.wirdPlans.restore(before);
      await undoMeta();
    };
  }

  /// Deletes [plan] (its reading sessions stay in the Quran history).
  Future<WirdUndo> delete(WirdPlan plan) async {
    final undoMeta = await _metaUndo(plan.id);
    final primaryBefore = await _kv.getJson(primaryKey);
    final row = await repos.wirdPlans.delete(plan.id);
    await _putMeta(plan.id, null);
    if (primaryBefore == plan.id) await _kv.remove(primaryKey);
    final activity = await repos.activity.since(plan.startDate, kind: WirdActivity.kind);
    final removed = <ActivityRow>[];
    for (final a in activity) {
      if (a.refTable == WirdActivity.refTable && (a.refId ?? '').startsWith('${plan.id}:')) {
        removed.addAll(await repos.activity.removeFor(refTable: WirdActivity.refTable, refId: a.refId!));
      }
    }
    return () async {
      if (row != null) await repos.wirdPlans.restore(row);
      await undoMeta();
      if (primaryBefore is String) await _kv.setJson(primaryKey, primaryBefore);
      if (removed.isNotEmpty) await repos.activityLog.restoreAll(removed);
    };
  }

  /// Turns [plan]'s reminder on or off, or moves it to [offsetMin] minutes
  /// after the plan's prayer – the plan itself (pace, progress) is kept
  /// (Settings › Reminders).
  Future<WirdUndo> setReminder(WirdPlan plan, {bool? remind, int? offsetMin}) async {
    final undoMeta = await _metaUndo(plan.id);
    final raw = (await _rawMeta())[plan.id];
    final current = raw == null ? plan.meta : WirdPlanMeta.fromJson(raw);
    await _putMeta(plan.id, current.copyWith(remind: remind, remindOffsetMin: offsetMin));
    return undoMeta;
  }

  Future<WirdUndo> setPrimary(String planId) async {
    final before = await _kv.getJson(primaryKey);
    await _kv.setJson(primaryKey, planId);
    return () async {
      if (before == null) {
        await _kv.remove(primaryKey);
      } else {
        await _kv.setJson(primaryKey, before);
      }
    };
  }

  /// Pauses [plan] from today: paused days owe nothing.
  Future<WirdUndo> pause(WirdPlan plan) async {
    final before = await repos.wirdPlans.byId(plan.id);
    if (before == null || !before.active) return () async {};
    final undoMeta = await _metaUndo(plan.id);
    final pauses = [...plan.meta.pauses.where((p) => p.to != null), WirdPause(_today)];
    await _putMeta(plan.id, plan.meta.copyWith(pauses: pauses));
    await repos.wirdPlans.setColumn(plan.id, 'active', false);
    return () async {
      await repos.wirdPlans.restore(before);
      await undoMeta();
    };
  }

  /// Resumes [plan] today. A khatma's target date moves on by the days it
  /// was paused, so the pace stays what the user chose.
  Future<WirdUndo> resume(WirdPlan plan) async {
    final before = await repos.wirdPlans.byId(plan.id);
    if (before == null || before.active) return () async {};
    final undoMeta = await _metaUndo(plan.id);
    final open = plan.meta.openPause;
    final yesterday = CalendarDays.add(_today, -1);
    final pauses = [
      for (final p in plan.meta.pauses)
        if (p.to != null) p else if (CalendarDays.between(p.from, yesterday) >= 0) WirdPause(p.from, yesterday),
    ];
    await _putMeta(plan.id, plan.meta.copyWith(pauses: pauses));
    final pausedDays = open == null ? 0 : math.max(0, CalendarDays.between(open.from, _today));
    await repos.wirdPlans.update(
      before.copyWith(
        active: true,
        targetDate: Value(
          before.targetDate == null || pausedDays == 0
              ? before.targetDate
              : CalendarDays.add(before.targetDate!, pausedDays),
        ),
      ),
    );
    return () async {
      await repos.wirdPlans.restore(before);
      await undoMeta();
    };
  }

  Future<void> reorder(List<String> ids) => repos.wirdPlans.reorder(ids);

  /// Marks the rest of today's portion as read (a session tagged with the
  /// plan). Null when nothing is left.
  Future<WirdUndo?> markDone(WirdPlanState state, {QuranAxis? pagesAxis}) async {
    final range = state.target.remaining;
    if (range == null) return null;
    return _logRange(state, range, pagesAxis: pagesAxis);
  }

  /// Records reading from where the plan stands up to [last] (inclusive),
  /// e.g. "I stopped at 2:141".
  Future<WirdUndo?> readUntil(WirdPlanState state, AyahRef last, {QuranAxis? pagesAxis}) async {
    final from = state.target.resumeAt;
    if (from == null || last < from) return null;
    return _logRange(state, AyahRange(from, last), pagesAxis: pagesAxis);
  }

  Future<WirdUndo> _logRange(WirdPlanState state, AyahRange range, {QuranAxis? pagesAxis}) async {
    final idx = pagesAxis?.index;
    final count = idx?.count(range) ?? 0;
    final pages = pagesAxis == null
        ? 0.0
        : pagesAxis.positionOf(idx!.indexOf(range.last) + 1) - pagesAxis.positionOf(idx.indexOf(range.first));
    final row = await repos.quranSessions.insert(
      QuranSessionsCompanion.insert(
        day: _today,
        mode: const Value(QuranSessionMode.read),
        fromSurah: range.first.surah,
        fromAyah: range.first.ayah,
        toSurah: range.last.surah,
        toAyah: range.last.ayah,
        ayahCount: Value(count),
        pages: Value(double.parse(pages.toStringAsFixed(3))),
        planId: Value(state.plan.id),
      ),
    );
    return () async {
      await repos.quranSessions.delete(row.id);
      await unrecord(state.plan.id);
    };
  }

  // ------------------------------------------------------------- activity --

  /// Logs `quran.wird` once for [state]'s plan today when today's portion
  /// is read, and removes it when it no longer is (an undone session).
  /// Returns true when an entry was written.
  Future<bool> syncCompletion(WirdPlanState state) async {
    final today = _today;
    if (!CalendarDays.same(state.today, today)) return false;
    final met = state.started && !state.paused && state.target.met && state.target.quota > WirdEngine.eps;
    final refId = WirdActivity.refIdFor(state.plan.id, today);
    final existing = (await repos.activity.since(
      today,
      kind: WirdActivity.kind,
    )).where((a) => a.refTable == WirdActivity.refTable && a.refId == refId);
    if (met && existing.isEmpty) {
      final r = recorder;
      final payload = <String, Object?>{'unit': state.plan.unit.name, 'quota': state.target.quota};
      if (r != null) {
        await r(
          kind: WirdActivity.kind,
          refTable: WirdActivity.refTable,
          refId: refId,
          at: clock(),
          value: state.target.done,
          payload: payload,
        );
      } else {
        await repos.activity.log(
          planetKey: WirdActivity.planetKey,
          kind: WirdActivity.kind,
          refTable: WirdActivity.refTable,
          refId: refId,
          at: clock(),
          value: state.target.done,
          payload: payload,
        );
      }
      return true;
    }
    // Only a portion that is no longer read (an undone or deleted session)
    // takes the entry back – not pausing the plan later the same day.
    if (existing.isNotEmpty && state.started && !state.paused && !state.target.met) {
      await unrecord(state.plan.id);
    }
    return false;
  }

  /// Removes today's `quran.wird` entry of [planId].
  Future<void> unrecord(String planId) => repos.activity.removeFor(
    refTable: WirdActivity.refTable,
    refId: WirdActivity.refIdFor(planId, _today),
    kind: WirdActivity.kind,
  );
}
