import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/family/family.dart';

import 'family_seed.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MadarDatabase db;
  late Repositories repos;
  late FamilyService service;
  var now = familyTestNow;

  setUp(() {
    now = familyTestNow;
    db = MadarDatabase(NativeDatabase.memory());
    repos = Repositories(db);
    service = FamilyService(repos, clock: () => now);
  });
  tearDown(() => db.close());

  Future<List<ActivityRow>> activities() => repos.activityLog.getAll();

  group('contacted', () {
    test('logs a contact, moves the last contact and records a Family activity', () async {
      final p = await seedPerson(repos, name: 'Mum', rhythm: 2, lastContact: daysAgo(4));
      final logged = await service.logContact(p.id, channel: ContactChannel.call, note: '  asked about her day ');
      expect(logged.log.channel, ContactChannel.call);
      expect(logged.log.note, 'asked about her day');
      expect(logged.log.at, now);
      expect(logged.previousLastContact, daysAgo(4));
      expect((await repos.people.byId(p.id))!.lastContact, now);

      final acts = await activities();
      expect(acts, hasLength(1));
      expect(acts.single.planetKey, 'family');
      expect(acts.single.kind, 'family.contact');
      expect(acts.single.refTable, 'contact_logs');
      expect(acts.single.refId, logged.log.id);

      final view = (await service.overview()).byId(p.id)!;
      expect(view.rhythm.daysUntilDue, 2);
      expect(view.rhythm.isDue, isFalse);
      expect(view.rhythm.daysSinceContact, 0);
      expect(view.lastChannel, ContactChannel.call);
    });

    test('undo removes exactly that contact and restores the last contact', () async {
      final p = await seedPerson(repos, name: 'Mum', rhythm: 2, lastContact: daysAgo(4));
      final logged = await service.logContact(p.id);
      await logged.undo();
      expect(await repos.contactLogs.count(), 0);
      expect(await activities(), isEmpty);
      expect((await repos.people.byId(p.id))!.lastContact, daysAgo(4));
    });

    test('undo keeps a later contact logged meanwhile', () async {
      final p = await seedPerson(repos, name: 'Dad', rhythm: 3, lastContact: daysAgo(6));
      final first = await service.logContact(p.id, at: daysAgo(1));
      final second = await service.logContact(p.id);
      await second.undo();
      expect((await repos.people.byId(p.id))!.lastContact, daysAgo(1));
      await first.undo();
      expect((await repos.people.byId(p.id))!.lastContact, daysAgo(6));
    });

    test('undo out of order never leaves a contact that no longer exists', () async {
      final p = await seedPerson(repos, name: 'Dad', rhythm: 3);
      await service.logContact(p.id, at: daysAgo(8));
      final first = await service.logContact(p.id, at: daysAgo(1));
      final second = await service.logContact(p.id);
      await first.undo();
      expect((await repos.people.byId(p.id))!.lastContact, now);
      await second.undo();
      expect((await repos.people.byId(p.id))!.lastContact, daysAgo(8));
    });

    test('a back-dated contact never rewinds the last contact', () async {
      final p = await seedPerson(repos, name: 'Sam', rhythm: 14, lastContact: daysAgo(2));
      await service.logContact(p.id, at: daysAgo(10));
      expect((await repos.people.byId(p.id))!.lastContact, daysAgo(2));
      expect(await repos.contactLogs.count(), 1);
    });

    test('a future time is clamped to now (never a future last contact)', () async {
      final p = await seedPerson(repos, name: 'Sam', rhythm: 14);
      final logged = await service.logContact(p.id, at: now.add(const Duration(days: 3)));
      expect(logged.log.at, now);
      expect((await repos.people.byId(p.id))!.lastContact, now);
    });

    test('goes through the injected recorder (the orbit pulse hub)', () async {
      final calls = <(String, String, String, DateTime)>[];
      final hooked = FamilyService(
        repos,
        clock: () => now,
        recorder: ({required kind, required refTable, required refId, required at}) async =>
            calls.add((kind, refTable, refId, at)),
      );
      final p = await seedPerson(repos, name: 'Mum', rhythm: 2);
      final logged = await hooked.logContact(p.id);
      expect(calls, [('family.contact', 'contact_logs', logged.log.id, now)]);
    });

    test('reads contacts written by the home quick-add / moon sheet (log newer than the column)', () async {
      final p = await seedPerson(repos, name: 'Mum', rhythm: 2, lastContact: daysAgo(9));
      await seedPerson(repos, name: 'x');
      // Written elsewhere without touching the column (e.g. an import).
      await repos.contactLogs.insert(ContactLogsCompanion.insert(personId: p.id, at: daysAgo(1)));
      final view = (await service.overview()).byId(p.id)!;
      expect(view.rhythm.lastContact, daysAgo(1));
      expect(view.rhythm.daysOverdue, 0);
    });
  });

  group('history edits', () {
    test('deleting the latest contact falls back to the previous one; undo restores', () async {
      final p = await seedPerson(repos, name: 'Mum', rhythm: 2);
      final a = await service.logContact(p.id, at: daysAgo(5));
      final b = await service.logContact(p.id, at: daysAgo(1));
      expect((await repos.people.byId(p.id))!.lastContact, daysAgo(1));

      final undo = await service.deleteContact(b.log.id);
      expect((await repos.people.byId(p.id))!.lastContact, daysAgo(5));
      expect(await repos.contactLogs.count(), 1);
      expect((await activities()).map((x) => x.refId), [a.log.id]);

      await undo();
      expect((await repos.people.byId(p.id))!.lastContact, daysAgo(1));
      expect(await repos.contactLogs.count(), 2);
      expect((await activities()).map((x) => x.refId).toSet(), {a.log.id, b.log.id});
    });

    test('deleting an older contact leaves the last contact alone', () async {
      final p = await seedPerson(repos, name: 'Mum', rhythm: 2);
      final a = await service.logContact(p.id, at: daysAgo(5));
      await service.logContact(p.id, at: daysAgo(1));
      await service.deleteContact(a.log.id);
      expect((await repos.people.byId(p.id))!.lastContact, daysAgo(1));
    });

    test('editing a contact moves its time (clamped), the activity and the last contact', () async {
      final p = await seedPerson(repos, name: 'Dad', rhythm: 7);
      await service.logContact(p.id, at: daysAgo(6));
      final b = await service.logContact(p.id, at: daysAgo(2));

      // Moved earlier than the other one: the last contact falls back.
      final undo = await service.updateContact(
        b.log.id,
        ContactDraft(channel: ContactChannel.visit, at: daysAgo(8), note: 'Eid visit'),
      );
      final edited = (await repos.contactLogs.byId(b.log.id))!;
      expect(edited.at, daysAgo(8));
      expect(edited.channel, ContactChannel.visit);
      expect(edited.note, 'Eid visit');
      expect((await repos.people.byId(p.id))!.lastContact, daysAgo(6));
      final act = (await activities()).firstWhere((x) => x.refId == b.log.id);
      expect(act.at, daysAgo(8));

      await undo();
      expect((await repos.contactLogs.byId(b.log.id))!.at, daysAgo(2));
      expect((await repos.people.byId(p.id))!.lastContact, daysAgo(2));

      // Into the future: clamped to now.
      await service.updateContact(
        b.log.id,
        ContactDraft(channel: ContactChannel.call, at: now.add(const Duration(hours: 5))),
      );
      expect((await repos.contactLogs.byId(b.log.id))!.at, now);
      expect((await repos.people.byId(p.id))!.lastContact, now);
    });
  });

  group('people', () {
    test('add (trimmed, seeded last contact clamped), update and undo, moon toggle', () async {
      final row = await service.addPerson(
        PersonDraft(
          name: '  Mum ',
          relation: 'mother',
          rhythmDays: 2,
          phone: ' ',
          notes: '',
          lastContact: now.add(const Duration(days: 1)),
        ),
      );
      expect(row.name, 'Mum');
      expect(row.phone, isNull);
      expect(row.notes, isNull);
      expect(row.lastContact, now);
      expect(row.showAsMoon, isTrue);

      final undo = await service.updatePerson(row.id, PersonDraft.of(row).copyForTest(rhythmDays: 5, name: 'Mother'));
      expect((await repos.people.byId(row.id))!.rhythmDays, 5);
      await undo();
      final back = (await repos.people.byId(row.id))!;
      expect(back.rhythmDays, 2);
      expect(back.name, 'Mum');

      final moonUndo = await service.setShowAsMoon(row.id, false);
      expect((await repos.people.byId(row.id))!.showAsMoon, isFalse);
      await moonUndo();
      expect((await repos.people.byId(row.id))!.showAsMoon, isTrue);

      expect(() => service.addPerson(const PersonDraft(name: '  ')), throwsArgumentError);
    });

    test('delete removes the person and their history; undo restores both', () async {
      final p = await seedPerson(repos, name: 'Sam', rhythm: 14);
      await service.logContact(p.id, at: daysAgo(3));
      await service.logContact(p.id, at: daysAgo(1));
      final undo = await service.deletePerson(p.id);
      expect(await repos.people.count(), 0);
      expect(await repos.contactLogs.count(), 0);
      await undo();
      expect((await repos.people.byId(p.id))!.name, 'Sam');
      expect(await repos.contactLogs.count(), 2);
    });

    test('manual order persists', () async {
      final a = await seedPerson(repos, name: 'A');
      final b = await seedPerson(repos, name: 'B');
      final c = await seedPerson(repos, name: 'C');
      await service.reorder([c.id, a.id, b.id]);
      expect((await service.people()).map((p) => p.name), ['C', 'A', 'B']);
    });

    test('overview: groups, due list, in-touch share, birthdays', () async {
      await seedFamily(db, arabic: false);
      final o = await service.overview();
      expect(o.groups.keys, [
        FamilyGroup.overdue,
        FamilyGroup.dueToday,
        FamilyGroup.thisWeek,
        FamilyGroup.inTouch,
        FamilyGroup.noRhythm,
      ]);
      expect(o.groups[FamilyGroup.overdue]!.map((p) => p.name), ['Mum', 'Sam']);
      expect(o.groups[FamilyGroup.dueToday]!.map((p) => p.name), ['Adam']);
      expect(o.due.map((p) => p.name), ['Mum', 'Sam', 'Adam']);
      expect(o.withRhythm, 5);
      expect(o.inTouch, 3);
      expect(o.upcomingBirthdays().map((p) => p.name), ['Lily', 'Mum']);
    });
  });

  test('settings round-trip with defaults', () async {
    expect(await service.settings(), const FamilySettings());
    const s = FamilySettings(digestEnabled: false, digestMinutes: 21 * 60 + 30, sortMode: FamilySortMode.manual);
    await service.saveSettings(s);
    expect(await service.settings(), s);
    expect(FamilySettings.fromJson({'digestAt': 99999, 'sort': 'nope'}), const FamilySettings());
  });
}

extension on PersonDraft {
  PersonDraft copyForTest({int? rhythmDays, String? name}) => PersonDraft(
    name: name ?? this.name,
    relation: relation,
    rhythmDays: rhythmDays ?? this.rhythmDays,
    phone: phone,
    birthday: birthday,
    notes: notes,
    color: color,
    showAsMoon: showAsMoon,
  );
}
