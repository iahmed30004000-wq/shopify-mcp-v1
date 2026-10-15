import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/health/wellbeing/wellbeing.dart';

import '../../../helpers/test_app.dart' show testDatabase;

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late WellbeingService service;
  final now = DateTime(2026, 9, 29, 20, 15);

  setUp(() async {
    db = testDatabase();
    repos = Repositories(db);
    service = WellbeingService(repos, clock: () => now);
  });

  tearDown(() => db.close());

  Future<List<ActivityRow>> activity() => repos.activityLog.getAll();

  group('pain', () {
    test('log writes the entry and a Health completion', () async {
      final row = await service.logPain(
        PainDraft(
          at: now,
          score: 6,
          locations: const ['Neck'],
          triggers: const ['Sitting'],
          points: const [BodyPoint(0.5, 0.15, BodySide.back)],
          notes: ' after work ',
        ),
      );
      final stored = (await repos.painEntries.byId(row.id))!;
      expect(stored.score, 6);
      expect(stored.locations, ['Neck']);
      expect(BodyPoint.listFrom(stored.bodyPoints), [const BodyPoint(0.5, 0.15, BodySide.back)]);
      expect(stored.notes, 'after work');
      final a = await activity();
      expect(a, hasLength(1));
      expect(a.single.planetKey, 'health');
      expect(a.single.kind, 'health.pain');
      expect(a.single.refTable, 'pain_entries');
      expect(a.single.value, 6);
    });

    test('update and delete with undo (activity comes back too)', () async {
      final row = await service.logPain(PainDraft(at: now, score: 3));
      await service.updatePain(row.id, PainDraft(at: now, score: 8, triggers: const ['Cold']));
      expect((await repos.painEntries.byId(row.id))!.triggers, ['Cold']);
      final undo = await service.deletePain(row.id);
      expect(await repos.painEntries.byId(row.id), isNull);
      expect(await activity(), isEmpty);
      await undo!();
      expect((await repos.painEntries.byId(row.id))!.score, 8);
      expect(await activity(), hasLength(1));
      expect(await service.deletePain('missing'), isNull);
    });
  });

  group('mood', () {
    test('check-in and edit', () async {
      final row = await service.logMood(
        MoodDraft(at: now, mood: 4, stress: 3, sleepHours: 7.3, caffeineCups: 2, factors: const ['Work']),
      );
      final stored = (await repos.moodEntries.byId(row.id))!;
      expect(stored.sleepHours, 7.5);
      expect((await activity()).single.kind, 'health.mood');
      await service.updateMood(row.id, MoodDraft(at: now, mood: 2));
      final edited = (await repos.moodEntries.byId(row.id))!;
      expect(edited.mood, 2);
      expect(edited.stress, isNull);
      expect(edited.factors, isEmpty);
    });

    test('delete with undo', () async {
      final row = await service.logMood(MoodDraft(at: now, mood: 3));
      final undo = await service.deleteMood(row.id);
      expect(await repos.moodEntries.count(), 0);
      await undo!();
      expect(await repos.moodEntries.count(), 1);
    });
  });

  group('tags', () {
    test('seeded vocabularies exist and are editable', () async {
      final locations = await repos.tagOptions.getAll(where: (t) => t.kind.equalsValue(TagKind.painLocation));
      expect(locations, isNotEmpty);
      final added = await service.addTag(TagKind.painLocation, '  Jaw ');
      expect(added!.label, 'Jaw');
      final again = await service.addTag(TagKind.painLocation, 'jaw');
      expect(again!.id, added.id);
      expect(await service.addTag(TagKind.painLocation, '   '), isNull);
    });

    test('rename follows into past entries; delete keeps them', () async {
      final tag = (await service.addTag(TagKind.painTrigger, 'Screens'))!;
      final p = await service.logPain(PainDraft(at: now, score: 4, triggers: const ['Screens', 'Cold']));
      final m = await service.logMood(MoodDraft(at: now, mood: 3, factors: const ['Screens']));
      final changed = await service.renameTag(tag.id, 'Long screen time');
      expect(changed, 1);
      expect((await repos.painEntries.byId(p.id))!.triggers, ['Long screen time', 'Cold']);
      // A mood factor with the same text is a different vocabulary.
      expect((await repos.moodEntries.byId(m.id))!.factors, ['Screens']);

      final undo = await service.deleteTag(tag.id);
      expect(await repos.tagOptions.byId(tag.id), isNull);
      expect((await repos.painEntries.byId(p.id))!.triggers, contains('Long screen time'));
      await undo!();
      expect((await repos.tagOptions.byId(tag.id))!.label, 'Long screen time');
    });

    test('reorder', () async {
      final a = (await service.addTag(TagKind.moodFactor, 'A'))!;
      final b = (await service.addTag(TagKind.moodFactor, 'B'))!;
      await service.reorderTags([b.id, a.id]);
      final all = await repos.tagOptions.getAll(where: (t) => t.kind.equalsValue(TagKind.moodFactor));
      expect(all.indexWhere((t) => t.id == b.id), lessThan(all.indexWhere((t) => t.id == a.id)));
    });
  });

  group('habits', () {
    test('seeded stress habits are the checklist', () async {
      final habits = await service.watchHabits().first;
      expect(habits, isNotEmpty);
      expect(habits.every((h) => h.category == 'stress'), isTrue);
    });

    test('done / not done with undo, completions on Health', () async {
      final h = (await service.addHabit('Walk after Asr'))!;
      expect(h.planetKey, 'health');
      final day = DateTime(2026, 9, 29);
      final undoDone = await service.setHabitDone(h.id, day, true);
      var logs = await repos.habitLogs.getAll(where: (t) => t.habitId.equals(h.id));
      expect(logs.single.day, '2026-09-29');
      expect((await activity()).single.kind, 'health.habit');
      // Idempotent.
      await service.setHabitDone(h.id, day, true);
      expect(await repos.habitLogs.count(where: (t) => t.habitId.equals(h.id)), 1);
      await undoDone();
      expect(await repos.habitLogs.count(where: (t) => t.habitId.equals(h.id)), 0);
      expect(await activity(), isEmpty);

      await service.setHabitDone(h.id, day, true);
      final undoOff = await service.setHabitDone(h.id, day, false);
      expect(await repos.habitLogs.count(where: (t) => t.habitId.equals(h.id)), 0);
      expect(await activity(), isEmpty);
      await undoOff();
      logs = await repos.habitLogs.getAll(where: (t) => t.habitId.equals(h.id));
      expect(logs.single.done, isTrue);
      expect(await activity(), hasLength(1));
    });

    test('rename, pause, delete with its history and undo', () async {
      final h = (await service.addHabit('Stretch'))!;
      await service.setHabitDone(h.id, DateTime(2026, 9, 28), true);
      await service.renameHabit(h.id, 'Gentle stretch');
      await service.setHabitActive(h.id, false);
      final stored = (await repos.habits.byId(h.id))!;
      expect(stored.name, 'Gentle stretch');
      expect(stored.active, isFalse);
      final undo = await service.deleteHabit(h.id);
      expect(await repos.habits.byId(h.id), isNull);
      expect(await repos.habitLogs.count(where: (t) => t.habitId.equals(h.id)), 0);
      await undo!();
      expect(await repos.habits.byId(h.id), isNotNull);
      expect(await repos.habitLogs.count(where: (t) => t.habitId.equals(h.id)), 1);
    });
  });

  group('worries', () {
    test('park, edit, keep with a reflection, resolve, reopen, delete', () async {
      expect(await service.parkWorry('  '), isNull);
      final w = (await service.parkWorry(' The exam results '))!;
      expect(w.body, 'The exam results');
      await service.editWorry(w.id, 'Exam results on Thursday');
      await service.keepWorry(w.id, reflection: 'Nothing to do until Thursday');
      var row = (await repos.worries.byId(w.id))!;
      expect(row.resolved, isFalse);
      expect(row.reflection, 'Nothing to do until Thursday');
      final undo = await service.resolveWorry(w.id);
      row = (await repos.worries.byId(w.id))!;
      expect(row.resolved, isTrue);
      expect(row.reflection, 'Nothing to do until Thursday');
      await undo!();
      expect((await repos.worries.byId(w.id))!.resolved, isFalse);
      await service.resolveWorry(w.id, reflection: 'Passed');
      await service.reopenWorry(w.id);
      row = (await repos.worries.byId(w.id))!;
      expect(row.resolved, isFalse);
      expect(row.reflection, 'Passed');
      final undoDelete = await service.deleteWorry(w.id);
      expect(await repos.worries.count(), 0);
      await undoDelete!();
      expect(await repos.worries.count(), 1);
    });

    test('review is logged on Health', () async {
      await service.logWorryReview(reviewed: 3, resolved: 1);
      final a = (await activity()).single;
      expect(a.kind, 'health.worry');
      expect(a.value, 3);
    });
  });

  group('breathing', () {
    test('a session with cycles is logged; an empty one is not', () async {
      await service.logBreathing(pattern: '478', cycles: 0, duration: const Duration(seconds: 5));
      expect(await activity(), isEmpty);
      await service.logBreathing(pattern: 'box', cycles: 4, duration: const Duration(seconds: 64));
      final a = (await activity()).single;
      expect(a.kind, 'health.breathing');
      expect(a.planetKey, 'health');
      expect(a.value, 4);
      expect(a.payload['pattern'], 'box');
      expect(a.payload['seconds'], 64);
    });
  });

  group('settings', () {
    test('defaults, update and support dismissal', () async {
      expect(await service.settings(), const WellbeingSettings());
      await service.updateSettings((s) => s.copyWith(supportNumber: '112'));
      await service.dismissSupport(DateTime(2026, 10, 6, 20, 15));
      final s = await service.settings();
      expect(s.supportNumber, '112');
      expect(s.supportDismissedUntil, DateTime(2026, 10, 6, 20, 15));
      expect(await service.watchSettings().first, s);
    });
  });

  test('a custom recorder receives completions (orbit pulse hub)', () async {
    final calls = <String>[];
    final s = WellbeingService(
      repos,
      clock: () => now,
      recorder: (kind, table, id, {value, payload = const {}}) async => calls.add('$kind:$table:$value'),
    );
    await s.logPain(PainDraft(at: now, score: 2));
    expect(calls, ['health.pain:pain_entries:2.0']);
    expect(await activity(), isEmpty);
  });

  test('import-shaped rows (plain labels, raw points) read back', () async {
    await repos.painEntries.insert(
      PainEntriesCompanion.insert(
        at: now,
        score: 5,
        locations: const Value(['Knees']),
        bodyPoints: const Value([
          {'x': 0.4, 'y': 0.7},
        ]),
      ),
    );
    final rows = await service.watchPain().first;
    expect(painSampleOf(rows.single).points.single.side, BodySide.front);
  });
}
