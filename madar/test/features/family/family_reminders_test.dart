import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/family/family.dart';

import 'family_seed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late MadarDatabase db;
  late Repositories repos;
  late FamilyService service;
  late FakeNotificationPlatform platform;
  late NotificationService notifications;
  late FamilyReminderEngine engine;
  var now = familyTestNow;
  final ar = FamilyTexts.forLanguage('ar');
  final en = FamilyTexts.forLanguage('en');

  FamilyReminderEngine engineWith(FamilyTexts texts) =>
      FamilyReminderEngine(service: service, notifications: notifications, texts: texts, clock: () => now);

  setUp(() {
    now = familyTestNow;
    db = MadarDatabase(NativeDatabase.memory());
    repos = Repositories(db);
    service = FamilyService(repos, clock: () => now);
    platform = FakeNotificationPlatform();
    notifications = NotificationService(platform, clock: () => now);
    engine = engineWith(ar);
  });
  tearDown(() async {
    await notifications.dispose();
    await db.close();
  });

  List<FakeScheduled> digests() =>
      platform.scheduled.values.where((s) => s.request.data['k'] == FamilyNoticeKind.digest.name).toList()
        ..sort((a, b) => a.request.at.compareTo(b.request.at));

  List<FakeScheduled> birthdays() =>
      platform.scheduled.values.where((s) => s.request.data['k'] != FamilyNoticeKind.digest.name).toList()
        ..sort((a, b) {
          final c = a.request.at.compareTo(b.request.at);
          // The day before first at the same moment ('birthdayEve' > 'birthday').
          return c != 0 ? c : (b.request.data['k']! as String).compareTo(a.request.data['k']! as String);
        });

  String plain(String s) => BidiIsolate.strip(s);

  group('daily digest', () {
    test('one gentle notification a day listing everyone due – not one per person', () async {
      final people = await seedFamily(db, arabic: false);
      final report = await engineWith(en).resync();
      expect(report.failed, 0);

      final list = digests();
      expect(list, hasLength(FamilyReminderPlanner.digestDays));
      final today = list.first.request;
      expect(today.at, DateTime(2026, 9, 29, 20));
      expect(today.namespace, NotificationNamespaces.reminders);
      expect(today.channelId, FamilyReminderEngine.channelId);
      expect(plain(today.title), '3 people to reach out to today');
      expect(plain(today.body), 'Mum, Sam, Adam — a short call is enough.');
      expect(today.data, {'k': 'digest'});

      // Tomorrow Lily is not due yet; on 2 October she is.
      expect(plain(list[1].request.body), 'Mum, Sam, Adam — a short call is enough.');
      expect(plain(list[3].request.body), contains('Lily'));
      expect(plain(list[3].request.title), '4 people to reach out to today');

      // Only people with a rhythm are ever listed.
      for (final d in list) {
        expect(plain(d.request.body), isNot(contains('Mr. Jones')));
      }
      expect(people, hasLength(6));
    });

    test('more than four names are counted, not listed', () async {
      for (var i = 0; i < 6; i++) {
        await seedPerson(repos, name: 'P$i', rhythm: 3, lastContact: daysAgo(10 + i));
      }
      await engineWith(en).resync();
      final today = digests().first.request;
      expect(plain(today.title), '6 people to reach out to today');
      expect(plain(today.body), 'P5, P4, P3, P2, +2 more — a short call is enough.');
    });

    test('Arabic texts with Arabic-Indic digits and isolated names', () async {
      await seedFamily(db);
      await engine.resync();
      final today = digests().first.request;
      expect(today.title, '٣ أشخاص ينتظرون سؤالك اليوم');
      expect(plain(today.body), 'أمي، سامي، أخي أحمد — مكالمة قصيرة تكفي.');
      expect(today.body, contains('${BidiIsolate.fsi}أمي${BidiIsolate.pdi}'));
    });

    test('a contact reschedules the digest: that person drops out, same ids', () async {
      final people = await seedFamily(db, arabic: false);
      await engineWith(en).resync();
      final before = digests().first.request;

      await service.logContact(people['mother']!.id);
      final report = await engineWith(en).resync();
      final after = digests().first.request;
      expect(after.id, before.id);
      expect(plain(after.body), 'Sam, Adam — a short call is enough.');
      expect(report.scheduled, greaterThan(0));

      // Unchanged plan: nothing rescheduled.
      final again = await engineWith(en).resync();
      expect(again.scheduled, 0);
      expect(again.unchanged, platform.scheduled.length);
    });

    test('everyone in touch: no digest until someone is due', () async {
      await seedPerson(repos, name: 'Mum', rhythm: 3, lastContact: now);
      await engineWith(en).resync();
      final list = digests();
      // Contacted today with a 3-day rhythm: due on 2 October.
      expect(list.first.request.at, DateTime(2026, 10, 2, 20));
    });

    test("today's digest time already passed: starts tomorrow", () async {
      now = DateTime(2026, 9, 29, 21);
      await seedFamily(db, arabic: false);
      await engineWith(en).resync();
      expect(digests().first.request.at, DateTime(2026, 9, 30, 20));
    });

    test('user-chosen time, and off', () async {
      await seedFamily(db, arabic: false);
      await service.saveSettings(const FamilySettings(digestMinutes: 8 * 60 + 15, birthdaysEnabled: false));
      await engineWith(en).resync();
      expect(digests().first.request.at, DateTime(2026, 9, 29, 8, 15));
      expect(birthdays(), isEmpty);

      await service.saveSettings(const FamilySettings(digestEnabled: false, birthdaysEnabled: false));
      await engineWith(en).resync();
      expect(platform.scheduled, isEmpty);
    });

    test('digest ids stay in the Family block and are distinct', () async {
      await seedFamily(db, arabic: false);
      await engine.resync();
      final ids = digests().map((d) => d.request.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final id in ids) {
        expect(id, inInclusiveRange(FamilyNotificationIds.digestFirst, FamilyNotificationIds.digestLast));
      }
    });
  });

  group('birthdays', () {
    test('the day before and the day, at the birthday time', () async {
      final people = await seedFamily(db, arabic: false);
      await engineWith(en).resync();
      final list = birthdays();
      // Lily on 1 October (eve 30 Sep), Mum on 2 October (eve 1 Oct).
      expect(
        [for (final b in list) (b.request.at, b.request.data['k'], b.request.data['p'])],
        [
          (DateTime(2026, 9, 30, 9), 'birthdayEve', people['sister']!.id),
          (DateTime(2026, 10, 1, 9), 'birthdayEve', people['mother']!.id),
          (DateTime(2026, 10, 1, 9), 'birthday', people['sister']!.id),
          (DateTime(2026, 10, 2, 9), 'birthday', people['mother']!.id),
        ],
      );
      expect(plain(list.first.request.title), "Lily's birthday is tomorrow");
      expect(plain(list.first.request.body), 'Turns 32 · Get a kind word or a small gift ready.');
      expect(plain(list[2].request.title), "It's Lily's birthday today");
      for (final b in list) {
        expect(b.request.id, inInclusiveRange(FamilyNotificationIds.birthdayFirst, FamilyNotificationIds.birthdayLast));
      }
    });

    test('birthday today after the reminder time: nothing left for this year', () async {
      now = DateTime(2026, 10, 1, 10);
      final p = await seedPerson(repos, name: 'Lily', birthday: DateTime(1994, 10, 1));
      await engineWith(en).resync();
      expect(birthdays().where((b) => b.request.data['p'] == p.id), isEmpty);
    });

    test('unknown year: no age; far birthdays are not scheduled yet', () async {
      await seedPerson(repos, name: 'Omar', birthday: DateTime(1904, 10, 10));
      await seedPerson(repos, name: 'Far', birthday: DateTime(1990, 3, 1));
      await engineWith(en).resync();
      final list = birthdays();
      expect(list, hasLength(2));
      expect(plain(list.first.request.body), 'Get a kind word or a small gift ready.');
    });
  });

  test("never touches other features' reminders in the shared namespace", () async {
    await notifications.schedule(
      NotificationRequest(
        namespace: NotificationNamespaces.reminders,
        id: 130005,
        channelId: 'madar.reminders.test',
        title: 'Pay the rent',
        body: '',
        at: now.add(const Duration(days: 2)),
      ),
    );
    await seedFamily(db);
    await engine.resync();
    expect(platform.scheduled.keys, contains(130005));
    await engine.cancelAll();
    expect(platform.scheduled.keys, [130005]);
  });

  test('channel: a gentle default-importance channel in its own group', () async {
    await seedFamily(db);
    await engine.resync();
    final channel = platform.channels[FamilyReminderEngine.channelId]!;
    expect(channel.importance, NotificationImportance.normal);
    expect(channel.groupId, FamilyReminderEngine.groupId);
    expect(channel.name, 'تذكيرات الصلة');
  });

  test('taps: digest opens the Family screen, a birthday opens the person', () {
    const digest = NotificationTap(id: 136003, namespace: 'reminders', data: {'k': 'digest'});
    const birthday = NotificationTap(id: 136500, namespace: 'reminders', data: {'k': 'birthday', 'p': 'abc'});
    const foreign = NotificationTap(id: 130005, namespace: 'reminders', data: {'k': 'digest'});
    const meds = NotificationTap(id: 120001, namespace: 'meds', data: {'m': 'x'});
    expect(FamilyNotificationTaps.kindOf(digest), FamilyNoticeKind.digest);
    expect(FamilyNotificationTaps.personOf(digest), isNull);
    expect(FamilyNotificationTaps.kindOf(birthday), FamilyNoticeKind.birthday);
    expect(FamilyNotificationTaps.personOf(birthday), 'abc');
    expect(FamilyNotificationTaps.isFamily(foreign), isFalse);
    expect(FamilyNotificationTaps.isFamily(meds), isFalse);
  });

  test('pure planner: birthday ids are stable per person and collision-free', () {
    final ids = FamilyNotificationIds.birthdays(['eve:a', 'day:a', 'eve:b', 'day:b']);
    expect(ids.values.toSet(), hasLength(4));
    expect(FamilyNotificationIds.birthdays(['day:a', 'eve:a', 'eve:b', 'day:b']), ids);
    expect(FamilyNotificationIds.owns(135999), isFalse);
    expect(FamilyNotificationIds.owns(136000), isTrue);
    expect(FamilyNotificationIds.owns(137000), isFalse);
  });
}
