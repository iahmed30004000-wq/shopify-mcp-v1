import 'dart:async';

import 'package:drift/drift.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/domain/enums.dart';
import '../domain/body_map.dart';
import '../domain/wellbeing_data.dart';
import '../domain/wellbeing_drafts.dart';
import '../domain/wellbeing_settings.dart';

/// Reverses a change (the UI wraps it in an undo toast).
typedef WbUndo = Future<void> Function();

/// Logs a completion on the Health planet. The default writes an
/// `activity_log` row; the app routes it through the orbit's pulse hub so
/// the world flares at once.
typedef WellbeingActivityRecorder = Future<void> Function(
  String kind,
  String? refTable,
  String? refId, {
  double? value,
  Map<String, Object?> payload,
});

/// Every write of the wellbeing package: pain logs, mood & stress check-ins,
/// their editable tag lists, stress-reduction habits, parked worries,
/// breathing sessions and the package's settings. Data stays in the
/// encrypted database; nothing leaves the device.
class WellbeingService {
  WellbeingService(this.repos, {DateTime Function()? clock, this.recorder}) : clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() clock;

  /// Null: completions are written straight to `activity_log`.
  final WellbeingActivityRecorder? recorder;

  static const String planetKey = 'health';
  static const String kindPain = 'health.pain';
  static const String kindMood = 'health.mood';
  static const String kindHabit = 'health.habit';
  static const String kindBreathing = 'health.breathing';
  static const String kindWorryReview = 'health.worry';

  /// Habits shown in the wellbeing checklist.
  static const String habitCategory = 'stress';

  static final KvKey<WellbeingSettings> settingsKey = KvKey.json<WellbeingSettings>(
    WellbeingSettings.storageKey,
    fromJson: WellbeingSettings.fromJson,
    toJson: (s) => s.toJson(),
  );

  MadarDatabase get _db => repos.db;

  Future<void> _record(
    String kind,
    String? table,
    String? id, {
    double? value,
    Map<String, Object?> payload = const {},
  }) {
    final r = recorder;
    if (r != null) return r(kind, table, id, value: value, payload: payload);
    return repos.activity.log(
      planetKey: planetKey,
      kind: kind,
      refTable: table,
      refId: id,
      at: clock(),
      value: value,
      payload: payload,
    );
  }

  // ------------------------------------------------------------ streams --

  /// Every pain log, newest first.
  Stream<List<PainEntryRow>> watchPain() =>
      repos.painEntries.watchAll().map((rows) => rows.toList()..sort((a, b) => b.at.compareTo(a.at)));

  /// Every check-in, newest first.
  Stream<List<MoodEntryRow>> watchMood() =>
      repos.moodEntries.watchAll().map((rows) => rows.toList()..sort((a, b) => b.at.compareTo(a.at)));

  /// One editable vocabulary, in the user's order.
  Stream<List<TagOptionRow>> watchTags(TagKind kind) =>
      repos.tagOptions.watchAll(where: (t) => t.kind.equalsValue(kind));

  /// The checklist's habits (category `stress`), in the user's order.
  Stream<List<HabitRow>> watchHabits() => repos.habits.watchAll(where: (t) => t.category.equals(habitCategory));

  /// Habit logs from [since] on.
  Stream<List<HabitLogRow>> watchHabitLogs({required DateTime since}) =>
      repos.habitLogs.watchAll(where: (t) => t.day.isBiggerOrEqualValue(WbDays.key(since)));

  /// Every parked worry, in the user's order.
  Stream<List<WorryRow>> watchWorries() => repos.worries.watchAll();

  Stream<WellbeingSettings> watchSettings() =>
      repos.keyValues.watch(settingsKey).map((s) => s ?? const WellbeingSettings());

  Future<WellbeingSettings> settings() async => await repos.keyValues.get(settingsKey) ?? const WellbeingSettings();

  Future<WellbeingSettings> updateSettings(WellbeingSettings Function(WellbeingSettings s) change) async {
    final next = change(await settings());
    await repos.keyValues.set(settingsKey, next);
    return next;
  }

  /// Hides the support banner for [SupportRule.snooze] from now.
  Future<void> dismissSupport(DateTime until) => updateSettings((s) => s.copyWith(supportDismissedUntil: until));

  // --------------------------------------------------------------- pain --

  Future<PainEntryRow> logPain(PainDraft draft) async {
    final d = draft.normalized();
    final row = await repos.painEntries.insert(
      PainEntriesCompanion.insert(
        at: d.at,
        score: d.score,
        locations: Value(d.locations),
        triggers: Value(d.triggers),
        bodyPoints: Value(BodyPoint.encodeAll(d.points)),
        notes: Value(d.notes),
      ),
    );
    await _record(kindPain, repos.painEntries.tableName, row.id, value: d.score.toDouble());
    return row;
  }

  Future<void> updatePain(String id, PainDraft draft) async {
    final row = await repos.painEntries.byId(id);
    if (row == null) return;
    final d = draft.normalized();
    await repos.painEntries.update(
      row.copyWith(
        at: d.at,
        score: d.score,
        locations: d.locations,
        triggers: d.triggers,
        bodyPoints: BodyPoint.encodeAll(d.points),
        notes: Value(d.notes),
      ),
    );
  }

  Future<WbUndo?> deletePain(String id) => _deleteWithActivity(repos.painEntries, id);

  // --------------------------------------------------------------- mood --

  Future<MoodEntryRow> logMood(MoodDraft draft) async {
    final d = draft.normalized();
    final row = await repos.moodEntries.insert(
      MoodEntriesCompanion.insert(
        at: d.at,
        mood: Value(d.mood),
        stress: Value(d.stress),
        anxiety: Value(d.anxiety),
        energy: Value(d.energy),
        sleepHours: Value(d.sleepHours),
        caffeineCups: Value(d.caffeineCups),
        factors: Value(d.factors),
        notes: Value(d.notes),
      ),
    );
    await _record(kindMood, repos.moodEntries.tableName, row.id, value: d.mood?.toDouble());
    return row;
  }

  Future<void> updateMood(String id, MoodDraft draft) async {
    final row = await repos.moodEntries.byId(id);
    if (row == null) return;
    final d = draft.normalized();
    await repos.moodEntries.update(
      row.copyWith(
        at: d.at,
        mood: Value(d.mood),
        stress: Value(d.stress),
        anxiety: Value(d.anxiety),
        energy: Value(d.energy),
        sleepHours: Value(d.sleepHours),
        caffeineCups: Value(d.caffeineCups),
        factors: d.factors,
        notes: Value(d.notes),
      ),
    );
  }

  Future<WbUndo?> deleteMood(String id) => _deleteWithActivity(repos.moodEntries, id);

  Future<WbUndo?> _deleteWithActivity<T extends Table, R extends DataClass>(
    EntityRepository<T, R> repo,
    String id,
  ) async {
    late final R? row;
    late final List<ActivityRow> activity;
    await _db.transaction(() async {
      row = await repo.delete(id);
      activity = row == null ? const [] : await repos.activity.removeFor(refTable: repo.tableName, refId: id);
    });
    final deleted = row;
    if (deleted == null) return null;
    return () => _db.transaction(() async {
      await repo.restore(deleted);
      if (activity.isNotEmpty) await repos.activityLog.restoreAll(activity);
    });
  }

  // --------------------------------------------------------------- tags --

  /// Adds [label] to [kind]'s list (or returns the existing option with the
  /// same label, ignoring case and surrounding spaces).
  Future<TagOptionRow?> addTag(TagKind kind, String label) async {
    final clean = label.trim();
    if (clean.isEmpty) return null;
    final existing = await repos.tagOptions.getAll(where: (t) => t.kind.equalsValue(kind));
    for (final e in existing) {
      if (e.label.trim().toLowerCase() == clean.toLowerCase()) return e;
    }
    return repos.tagOptions.insert(TagOptionsCompanion.insert(kind: kind, label: clean));
  }

  /// Renames an option and the same label in every entry that used it, so
  /// history and charts stay together. Returns the entries changed.
  Future<int> renameTag(String id, String label) async {
    final clean = label.trim();
    final tag = await repos.tagOptions.byId(id);
    if (tag == null || clean.isEmpty || clean == tag.label) return 0;
    final old = tag.label;
    List<String> swap(List<String> l) {
      final out = <String>[];
      for (final x in l) {
        final v = x == old ? clean : x;
        if (!out.contains(v)) out.add(v);
      }
      return out;
    }

    var changed = 0;
    await _db.transaction(() async {
      await repos.tagOptions.update(tag.copyWith(label: clean));
      switch (tag.kind) {
        case TagKind.painLocation || TagKind.painTrigger:
          final location = tag.kind == TagKind.painLocation;
          for (final p in await repos.painEntries.getAll()) {
            final list = location ? p.locations : p.triggers;
            if (!list.contains(old)) continue;
            await repos.painEntries.update(
              location ? p.copyWith(locations: swap(list)) : p.copyWith(triggers: swap(list)),
            );
            changed++;
          }
        case TagKind.moodFactor:
          for (final m in await repos.moodEntries.getAll()) {
            if (!m.factors.contains(old)) continue;
            await repos.moodEntries.update(m.copyWith(factors: swap(m.factors)));
            changed++;
          }
        case TagKind.habitCategory || TagKind.generic:
          break;
      }
    });
    return changed;
  }

  /// Removes an option from its list (entries keep the label they were
  /// logged with).
  Future<WbUndo?> deleteTag(String id) async {
    final row = await repos.tagOptions.delete(id);
    if (row == null) return null;
    return () => repos.tagOptions.restore(row);
  }

  Future<void> reorderTags(List<String> ids) => repos.tagOptions.reorder(ids);

  // ------------------------------------------------------------- habits --

  /// Marks [habitId] done (or not) on [day]. Done days log a completion on
  /// the Health planet.
  Future<WbUndo> setHabitDone(String habitId, DateTime day, bool done) async {
    final key = WbDays.key(day);
    final existing = (await repos.habitLogs.getAll(where: (t) => t.habitId.equals(habitId) & t.day.equals(key)))
        .firstOrNull;
    if (done) {
      if (existing != null && existing.done) return () async {};
      late final HabitLogRow row;
      if (existing != null) {
        await repos.habitLogs.setColumn(existing.id, 'done', true);
        row = existing.copyWith(done: true);
      } else {
        row = await repos.habitLogs.insert(HabitLogsCompanion.insert(habitId: habitId, day: key));
      }
      await _record(kindHabit, repos.habitLogs.tableName, row.id, value: 1, payload: {'habitId': habitId, 'day': key});
      return () async {
        await repos.activity.removeFor(refTable: repos.habitLogs.tableName, refId: row.id);
        if (existing != null) {
          await repos.habitLogs.restore(existing);
        } else {
          await repos.habitLogs.delete(row.id);
        }
      };
    }
    if (existing == null) return () async {};
    await repos.habitLogs.delete(existing.id);
    final activity = await repos.activity.removeFor(refTable: repos.habitLogs.tableName, refId: existing.id);
    return () async {
      await repos.habitLogs.restore(existing);
      if (activity.isNotEmpty) await repos.activityLog.restoreAll(activity);
    };
  }

  Future<HabitRow?> addHabit(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return null;
    return repos.habits.insert(
      HabitsCompanion.insert(name: clean, category: const Value(habitCategory), planetKey: const Value(planetKey)),
    );
  }

  Future<void> renameHabit(String id, String name) async {
    final clean = name.trim();
    final row = await repos.habits.byId(id);
    if (row == null || clean.isEmpty) return;
    await repos.habits.update(row.copyWith(name: clean));
  }

  /// Pauses or resumes a habit (paused habits leave the checklist but keep
  /// their history).
  Future<void> setHabitActive(String id, bool active) => repos.habits.setColumn(id, 'active', active);

  /// Deletes a habit and its history.
  Future<WbUndo?> deleteHabit(String id) async {
    late final HabitRow? habit;
    late final List<HabitLogRow> logs;
    await _db.transaction(() async {
      habit = await repos.habits.delete(id);
      logs = habit == null ? const [] : await repos.habitLogs.deleteWhere((t) => t.habitId.equals(id));
    });
    final h = habit;
    if (h == null) return null;
    return () => _db.transaction(() async {
      await repos.habits.restore(h);
      if (logs.isNotEmpty) await repos.habitLogs.restoreAll(logs);
    });
  }

  Future<void> reorderHabits(List<String> ids) => repos.habits.reorder(ids);

  // ------------------------------------------------------------ worries --

  Future<WorryRow?> parkWorry(String body) async {
    final clean = body.trim();
    if (clean.isEmpty) return null;
    return repos.worries.insert(WorriesCompanion.insert(body: clean));
  }

  Future<void> editWorry(String id, String body) async {
    final clean = body.trim();
    final row = await repos.worries.byId(id);
    if (row == null || clean.isEmpty) return;
    await repos.worries.update(row.copyWith(body: clean));
  }

  /// Marks a worry resolved, with an optional reflection note.
  Future<WbUndo?> resolveWorry(String id, {String? reflection}) async {
    final row = await repos.worries.byId(id);
    if (row == null) return null;
    final note = reflection?.trim();
    await repos.worries.update(
      row.copyWith(resolved: true, reflection: Value(note == null || note.isEmpty ? row.reflection : note)),
    );
    return () => repos.worries.restore(row);
  }

  /// Keeps a worry parked for the next window, optionally noting a
  /// reflection.
  Future<void> keepWorry(String id, {String? reflection}) async {
    final note = reflection?.trim();
    if (note == null || note.isEmpty) return;
    final row = await repos.worries.byId(id);
    if (row == null) return;
    await repos.worries.update(row.copyWith(reflection: Value(note)));
  }

  Future<void> reopenWorry(String id) => repos.worries.setColumn(id, 'resolved', false);

  Future<WbUndo?> deleteWorry(String id) async {
    final row = await repos.worries.delete(id);
    if (row == null) return null;
    return () => repos.worries.restore(row);
  }

  Future<void> reorderWorries(List<String> ids) => repos.worries.reorder(ids);

  /// A finished worry-window review.
  Future<void> logWorryReview({required int reviewed, required int resolved}) =>
      _record(kindWorryReview, null, null, value: reviewed.toDouble(), payload: {'resolved': resolved});

  // ---------------------------------------------------------- breathing --

  /// A guided-breathing session (logged when at least one cycle completed).
  Future<void> logBreathing({required String pattern, required int cycles, required Duration duration}) async {
    if (cycles <= 0) return;
    await _record(
      kindBreathing,
      null,
      null,
      value: cycles.toDouble(),
      payload: {'pattern': pattern, 'seconds': duration.inSeconds},
    );
  }
}
