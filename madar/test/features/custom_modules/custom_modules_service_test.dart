import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_service.dart';
import 'package:madar/features/custom_modules/custom_modules.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MadarDatabase db;
  late Repositories repos;
  late CustomModulesService service;
  var now = DateTime(2026, 9, 30, 13, 0);

  setUp(() {
    now = DateTime(2026, 9, 30, 13, 0);
    db = MadarDatabase(NativeDatabase.memory());
    repos = Repositories(db);
    service = CustomModulesService(repos, clock: () => now);
  });
  tearDown(() => db.close());

  ModuleDefinition reading() => ModuleTemplates.build(ModuleTemplateKey.readingLog, (t) => t.name);

  group('modules', () {
    test('create stores fields, chart and planet; invalid drafts are refused', () async {
      final m = await service.createModule(reading().copyWith(name: '  Reading  '));
      expect(m.id, isNotEmpty);
      expect(m.name, 'Reading');
      expect(m.planetKey, 'growth');
      expect(m.fields.map((f) => f.id), ['f1', 'f2', 'f3']);
      expect(m.chart!.fieldId, 'f2');
      final row = (await repos.customModules.byId(m.id))!;
      expect((row.fields.first as Map)['type'], 'text');
      await expectLater(service.createModule(reading().copyWith(name: '')), throwsArgumentError);
    });

    test('update migrates entries in one go and undo restores everything', () async {
      final m = await service.createModule(reading());
      final (e1, _) = await service.addEntry(m.id, {'f1': 'Dune', 'f2': 30, 'f3': 4});
      // Rename f1, drop f3 (has data → hidden), change f2 to text.
      final draft = m.copyWith(
        fields: [
          m.field('f1')!.copyWith(label: 'Title'),
          m.field('f2')!.copyWith(type: FieldType.text),
        ],
      );
      final (plan, undo) = await service.updateModule(draft);
      expect(plan.canApply, isTrue);
      final stored = (await service.module(m.id))!;
      expect(stored.fields.map((f) => (f.id, f.type, f.hidden)), [
        ('f1', FieldType.text, false),
        ('f2', FieldType.text, false),
        ('f3', FieldType.rating, true),
      ]);
      expect(stored.field('f1')!.label, 'Title');
      expect(stored.chart!.fieldId, isNull, reason: 'no chartable field left: entries per day');
      final entry = (await service.entries(m.id)).single;
      expect(entry.id, e1.id);
      expect(entry.values, {'f1': 'Dune', 'f2': '30', 'f3': 4});

      await undo();
      final back = (await service.module(m.id))!;
      expect(back.fields.map((f) => f.type), [FieldType.text, FieldType.number, FieldType.rating]);
      expect(back.field('f3')!.hidden, isFalse);
      expect((await service.entries(m.id)).single.values, {'f1': 'Dune', 'f2': 30, 'f3': 4});
    });

    test('a blocked type change writes nothing', () async {
      final m = await service.createModule(reading());
      await service.addEntry(m.id, {'f1': 'Dune', 'f2': 30});
      final draft = m.copyWith(fields: [m.field('f1')!.copyWith(type: FieldType.number), ...m.fields.skip(1)]);
      await expectLater(service.updateModule(draft), throwsA(isA<MigrationBlockedException>()));
      expect((await service.module(m.id))!.field('f1')!.type, FieldType.text);
    });

    test('archive, duplicate, reorder and delete with undo', () async {
      final a = await service.createModule(reading().copyWith(name: 'A'));
      final b = await service.createModule(reading().copyWith(name: 'B'));
      final undoArchive = await service.setArchived(a.id, true);
      expect((await service.module(a.id))!.archived, isTrue);
      await undoArchive();
      expect((await service.module(a.id))!.archived, isFalse);

      final (copy, undoCopy) = await service.duplicateModule(a.id, name: 'A copy');
      expect((await service.modules()).map((m) => m.name), ['A', 'A copy', 'B']);
      expect(copy.fields, a.fields);
      await undoCopy();
      await service.reorderModules([b.id, a.id]);
      expect((await service.modules()).map((m) => m.name), ['B', 'A']);

      await service.addEntry(a.id, {'f1': 'x', 'f2': 1});
      await service.addReminder(a.id, {'kind': 'daily', 'time': '08:00'});
      final undoDelete = await service.deleteModule(a.id);
      expect(await service.module(a.id), isNull);
      expect(await repos.customEntries.count(), 0);
      expect(await service.allReminders(), isEmpty);
      await undoDelete();
      expect((await service.module(a.id))!.name, 'A');
      expect(await repos.customEntries.count(), 1);
      expect(await service.allReminders(), hasLength(1));
    });
  });

  group('entries and planet activity', () {
    test('a tracker entry logs activity for the module planet; undo removes both', () async {
      final m = await service.createModule(reading());
      final (entry, undo) = await service.addEntry(m.id, {'f1': 'Dune', 'f2': 12});
      expect(entry.at, now);
      final acts = await repos.activityLog.getAll();
      expect(acts.single.planetKey, 'growth');
      expect(acts.single.kind, CustomModulesService.kindEntry);
      expect(acts.single.refTable, 'custom_entries');
      expect(acts.single.refId, entry.id);
      expect(acts.single.payload['moduleId'], m.id);
      await undo();
      expect(await repos.customEntries.count(), 0);
      expect(await repos.activityLog.count(), 0);
    });

    test('a module without a planet logs nothing; custom planet keys work', () async {
      final m = await service.createModule(reading().copyWith(clearPlanet: true));
      await service.addEntry(m.id, {'f1': 'x', 'f2': 1});
      expect(await repos.activityLog.count(), 0);
      final c = await service.createModule(reading().copyWith(planetKey: 'custom_abc'));
      await service.addEntry(c.id, {'f1': 'x', 'f2': 1});
      expect((await repos.activityLog.getAll()).single.planetKey, 'custom_abc');
    });

    test('the recorder (orbit pulse hub) is used when given', () async {
      final calls = <String>[];
      final s = CustomModulesService(
        repos,
        clock: () => now,
        recorder: ({required planetKey, required kind, required refTable, required refId, required at, payload = const {}}) async =>
            calls.add('$planetKey/$kind/$refTable'),
      );
      final m = await s.createModule(reading());
      await s.addEntry(m.id, {'f1': 'x', 'f2': 1});
      expect(calls, ['growth/custom.entry/custom_entries']);
    });

    test('list: check-off logs activity, reopen removes it, undo restores', () async {
      final list = await service.createModule(ModuleTemplates.build(ModuleTemplateKey.giftIdeas, (t) => t.name));
      final (item, _) = await service.addEntry(list.id, {'f1': 'Book'});
      expect(await repos.activityLog.count(), 0, reason: 'adding a list item is not an achievement');
      final undoDone = await service.setDone(item.id, true);
      expect((await repos.activityLog.getAll()).single.kind, CustomModulesService.kindDone);
      expect((await repos.activityLog.getAll()).single.planetKey, 'family');
      await undoDone();
      expect((await service.entries(list.id)).single.done, isFalse);
      expect(await repos.activityLog.count(), 0);

      await service.setDone(item.id, true);
      final undoReopen = await service.setDone(item.id, false);
      expect(await repos.activityLog.count(), 0);
      await undoReopen();
      expect(await repos.activityLog.count(), 1);
      expect((await service.entries(list.id)).single.done, isTrue);
    });

    test('reorder, duplicate, clear done, edit and delete entries', () async {
      final list = await service.createModule(ModuleTemplates.build(ModuleTemplateKey.giftIdeas, (t) => t.name));
      final (a, _) = await service.addEntry(list.id, {'f1': 'A'});
      final (b, _) = await service.addEntry(list.id, {'f1': 'B'});
      await service.reorderEntries([b.id, a.id]);
      expect((await service.entries(list.id)).map((e) => e.values['f1']), ['B', 'A']);
      final (copy, _) = await service.duplicateEntry(b.id);
      expect((await service.entries(list.id)).map((e) => e.values['f1']), ['B', 'B', 'A']);
      expect(copy.done, isFalse);
      await service.setDone(a.id, true);
      final undoClear = await service.clearDone(list.id);
      expect(await repos.customEntries.count(), 2);
      await undoClear();
      expect(await repos.customEntries.count(), 3);
      final undoEdit = await service.updateEntry(a.id, {'f1': 'A2'});
      expect((await repos.customEntries.byId(a.id))!.entryValues, {'f1': 'A2'});
      await undoEdit();
      expect((await repos.customEntries.byId(a.id))!.entryValues, {'f1': 'A'});
      final undoDelete = await service.deleteEntry(a.id);
      expect(await repos.customEntries.byId(a.id), isNull);
      await undoDelete();
      expect((await repos.customEntries.byId(a.id))!.done, isTrue);
    });
  });

  group('one-tap logging', () {
    test('check-in toggles today; undo brings it back', () async {
      final habit = await service.createModule(ModuleTemplates.build(ModuleTemplateKey.dailyHabit, (t) => t.name));
      final first = (await service.quickLog(habit.id))!;
      expect(first.added, isTrue);
      expect((await service.entries(habit.id)).single.values, {'f1': true});
      final second = (await service.quickLog(habit.id))!;
      expect(second.added, isFalse);
      expect(await service.entries(habit.id), isEmpty);
      await second.undo();
      expect(await service.entries(habit.id), hasLength(1));
      // Tomorrow is a new day.
      now = now.add(const Duration(days: 1));
      expect((await service.quickLog(habit.id))!.added, isTrue);
      expect(await service.entries(habit.id), hasLength(2));
    });

    test('rating and counter', () async {
      final rate = await service.createModule(
        ModuleDefinition(
          id: '',
          name: 'Mood',
          colorArgb: 0,
          fields: const [ModuleField(id: 'f1', label: 'Mood', type: FieldType.rating, max: 5)],
        ),
      );
      await service.quickLog(rate.id, rating: 4);
      expect((await service.entries(rate.id)).single.values, {'f1': 4});
      expect(await service.quickLog(rate.id, rating: 9), isNull);
      final counter = await service.createModule(const ModuleDefinition(id: '', name: 'Glasses', colorArgb: 0));
      await service.quickLog(counter.id);
      await service.quickLog(counter.id);
      expect(await service.entries(counter.id), hasLength(2));
      final reading = await service.createModule(ModuleTemplates.build(ModuleTemplateKey.readingLog, (t) => t.name));
      expect(await service.quickLog(reading.id), isNull, reason: 'needs the form');
    });
  });

  group('reminders', () {
    test('CRUD with undo and planner input from live modules only', () async {
      final a = await service.createModule(reading().copyWith(name: 'A'));
      final b = await service.createModule(reading().copyWith(name: 'B'));
      final (r1, undoAdd) = await service.addReminder(a.id, {'kind': 'daily', 'time': '08:00'});
      await service.addReminder(b.id, {'kind': 'prayer', 'window': 'asr', 'offsetMin': 10}, title: 'Read');
      await service.setArchived(b.id, true);
      final inputs = await service.reminderInputs();
      expect(inputs.single.moduleName, 'A');
      final undoToggle = await service.setReminderEnabled(r1.id, false);
      expect((await service.reminderInputs()).single.enabled, isFalse);
      await undoToggle();
      final undoUpdate = await service.updateReminder(r1.id, {'kind': 'daily', 'time': '09:00'});
      expect((await service.reminderInputs()).single.rule['time'], '09:00');
      await undoUpdate();
      expect((await service.reminderInputs()).single.rule['time'], '08:00');
      final undoDelete = await service.deleteReminder(r1.id);
      expect(await service.reminderInputs(), isEmpty);
      await undoDelete();
      expect(await service.reminderInputs(), hasLength(1));
      await undoAdd();
      expect(await service.reminderInputs(), isEmpty);
    });

    test('the engine syncs only its own id block', () async {
      final platform = FakeNotificationPlatform();
      final notifications = NotificationService(platform, clock: () => now);
      final m = await service.createModule(reading());
      await service.addReminder(m.id, {'kind': 'daily', 'time': '21:00'});
      final engine = CustomModulesReminderEngine(
        service: service,
        notifications: notifications,
        texts: CustomTexts.forLanguage('en'),
        prayerStart: (day, w) => null,
        clock: () => now,
      );
      final report = await engine.resync();
      expect(report.scheduled, 7);
      final pending = await platform.pending();
      expect(pending, hasLength(7));
      expect(pending.every((p) => CustomModuleReminderIds.owns(p.id)), isTrue);
      await engine.cancelAll();
      expect(await platform.pending(), isEmpty);
    });
  });

  group('export hooks', () {
    test('search, CSV and Markdown from the database', () async {
      final m = await service.createModule(reading().copyWith(name: 'Reading'));
      await service.addEntry(m.id, {'f1': 'Dune', 'f2': 30});
      final records = await service.searchRecords();
      expect(records.map((r) => r.title), ['Reading', 'Dune']);
      final csv = (await service.csv(m.id))!;
      expect(csv.split('\r\n').first, 'date,time,readingBook,readingPages,readingRating');
      final md = (await service.markdown(m.id))!;
      expect(md, contains('## Reading'));
      expect(await service.csv('nope'), isNull);
    });
  });
}
