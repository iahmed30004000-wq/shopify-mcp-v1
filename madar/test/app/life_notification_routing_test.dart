// Life notifications into the running app, end to end (router, database
// gate, adhan host, app lock, the app's services):
// * where each tap leads (pure): the family's digest and a birthday, a
//   travel document's expiry, a fasting notice, a tracker's reminder –
//   and nothing for another feature's tap;
// * at start the app plans every life reminder, each inside its own block
//   of the shared `reminders` namespace;
// * a tap opens its page, cold or warm, under the app lock like every deep
//   link, and never before onboarding.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_services.dart';
import 'package:madar/app/life_services.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/body/body.dart';
import 'package:madar/features/custom_modules/custom_modules.dart';
import 'package:madar/features/family/family.dart';
import 'package:madar/features/lock/presentation/lock_screen.dart';
import 'package:madar/features/money/goals/goals.dart' show GoalsReminderIds;
import 'package:madar/features/onboarding/onboarding_screen.dart';
import 'package:madar/features/travel/travel.dart';

import '../features/family/family_seed.dart' show seedPerson;
import '../features/lock/lock_test_utils.dart';
import '../helpers/test_app.dart';

final DateTime _now = DateTime(2026, 9, 29, 7, 30);
const _english = AppSettings(onboarded: true, languageCode: 'en');

RawNotificationTap _tap(int id, Map<String, Object?> data, {bool launch = false, String channel = 'x'}) =>
    RawNotificationTap(
      id: id,
      fromLaunch: launch,
      payload: NotificationEnvelope.encode(
        NotificationRequest(
          namespace: NotificationNamespaces.reminders,
          id: id,
          channelId: channel,
          title: 't',
          body: '',
          at: _now,
          data: data,
        ),
      ),
    );

RawNotificationTap _digest({bool launch = false}) =>
    _tap(FamilyNotificationIds.digestFirst + 3, {'k': FamilyNoticeKind.digest.name}, launch: launch);
RawNotificationTap _birthday(String person, {bool launch = false}) =>
    _tap(FamilyNotificationIds.birthdayFirst + 7, {'k': FamilyNoticeKind.birthday.name, 'p': person}, launch: launch);
RawNotificationTap _document(String doc, {bool launch = false}) => _tap(
  TravelReminderIds.idFor(0, DocumentReminderKind.values.first),
  {'feature': 'travel', 'documentId': doc, 'kind': DocumentReminderKind.values.first.name},
  launch: launch,
);
RawNotificationTap _fasting({bool launch = false}) =>
    _tap(BodyReminderIds.goal, {'kind': NotificationBodyReminderScheduler.kind, 'notice': 'goal'}, launch: launch);
RawNotificationTap _module(String module, {bool launch = false}) =>
    _tap(CustomModuleReminderIds.first + 12, {'k': CustomModuleNotificationTaps.kind, 'm': module, 'r': 'r1'}, launch: launch);

NotificationTap _decoded(RawNotificationTap raw) =>
    NotificationEnvelope.decode(raw.payload, id: raw.id, actionId: raw.actionId);

/// Lets database writes and the reminder syncs' debounces finish.
Future<void> _writes(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// An overdue person with a rhythm, a passport expiring in 20 days, a
/// tracker with a daily reminder, and a running fast whose goal notifies.
Future<void> _seed(MadarDatabase db) async {
  final repos = Repositories(db);
  await seedPerson(
    repos,
    name: 'Mum',
    relation: 'mother',
    rhythm: 3,
    lastContact: _now.subtract(const Duration(days: 12)),
    createdAt: DateTime(2025, 1, 1),
  );
  await TravelService(repos, clock: () => _now).addDocument(
    DocumentDraft(name: 'Passport', expiry: DateTime(2026, 10, 19), remindDaysBefore: 7),
  );
  final modules = CustomModulesService(repos, clock: () => _now);
  final m = await modules.createModule(
    ModuleTemplates.build(ModuleTemplateKey.readingLog, (t) => t.name).copyWith(name: 'Reading'),
  );
  await modules.addReminder(m.id, {'kind': 'daily', 'time': '21:00'});
  final body = BodyService(repos, clock: () => _now);
  await body.setFastingPlan(const FastingPlan(notifyGoal: true));
  await body.startFast(at: _now.subtract(const Duration(hours: 2)), targetHours: 16);
}

void main() {
  group('where a tap leads (pure)', () {
    test('each life reminder opens its page', () {
      expect(lifeNotificationLocation(_decoded(_digest())), '/family');
      expect(lifeNotificationLocation(_decoded(_birthday('p 1'))), '/family/person/p%201');
      expect(lifeNotificationLocation(_decoded(_document('d1'))), '/travel?tab=documents');
      expect(lifeNotificationLocation(_decoded(_fasting())), '/body?tab=fasting');
      expect(lifeNotificationLocation(_decoded(_module('m/1'))), '/modules/module/m%2F1');
    });

    test('the app router reads them after health and money', () {
      for (final (tap, location) in [
        (_digest(), '/family'),
        (_birthday('p1'), '/family/person/p1'),
        (_document('d1'), '/travel?tab=documents'),
        (_fasting(), '/body?tab=fasting'),
        (_module('m1'), '/modules/module/m1'),
      ]) {
        expect(AppNotificationRouter.locationOf(_decoded(tap)), location);
      }
    });

    test("another feature's tap, a foreign id block or an unknown kind is not life's", () {
      // A family payload outside the family block (Money's goals block).
      expect(
        lifeNotificationLocation(_decoded(_tap(GoalsReminderIds.first + 1, {'k': FamilyNoticeKind.digest.name}))),
        isNull,
      );
      // A module payload in the family block.
      expect(
        lifeNotificationLocation(
          _decoded(_tap(FamilyNotificationIds.digestFirst, {'k': CustomModuleNotificationTaps.kind, 'm': 'm1'})),
        ),
        isNull,
      );
      // A fasting payload outside Body's four ids.
      expect(
        lifeNotificationLocation(
          _decoded(_tap(BodyReminderIds.last + 1, {'kind': NotificationBodyReminderScheduler.kind})),
        ),
        isNull,
      );
      expect(lifeNotificationLocation(_decoded(_tap(136001, const {'k': 'party'}))), isNull);
      // An adhan tap (another namespace).
      final adhan = RawNotificationTap(
        id: 100001,
        payload: NotificationEnvelope.encode(
          NotificationRequest(
            namespace: NotificationNamespaces.adhan,
            id: 100001,
            channelId: 'x',
            title: 't',
            body: '',
            at: _now,
            data: const {'k': 'digest', 'feature': 'travel', 'documentId': 'd'},
          ),
        ),
      );
      expect(lifeNotificationLocation(_decoded(adhan)), isNull);
    });
  });

  testWidgets('at start every life reminder is planned inside its own block', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      now: _now,
      overrides: LockFixture.empty().overrides,
      beforePump: _seed,
    );
    await _writes(tester);
    final ids = [for (final s in app.notifications.scheduled.values) s.request.id];
    Iterable<int> within(int first, int last) => ids.where((id) => id >= first && id <= last);
    expect(within(FamilyNotificationIds.first, FamilyNotificationIds.last), isNotEmpty, reason: 'family digest');
    expect(within(TravelReminderIds.first, TravelReminderIds.last), isNotEmpty, reason: 'passport');
    expect(within(CustomModuleReminderIds.first, CustomModuleReminderIds.last), isNotEmpty, reason: 'tracker');
    expect(within(BodyReminderIds.first, BodyReminderIds.last), isNotEmpty, reason: 'fasting goal');
    for (final s in app.notifications.scheduled.values) {
      final r = s.request;
      final d = r.data;
      if (d['k'] == FamilyNoticeKind.digest.name || d['k'] == FamilyNoticeKind.birthday.name) {
        expect(FamilyNotificationIds.owns(r.id), isTrue, reason: '${r.id}');
      }
      if (d['feature'] == 'travel') expect(TravelReminderIds.owns(r.id), isTrue, reason: '${r.id}');
      if (d['k'] == CustomModuleNotificationTaps.kind) expect(CustomModuleReminderIds.owns(r.id), isTrue);
      if (d['kind'] == NotificationBodyReminderScheduler.kind) expect(BodyReminderIds.owns(r.id), isTrue);
      // …and each one leads somewhere.
      if (r.namespace == NotificationNamespaces.reminders && !GoalsReminderIds.owns(r.id)) {
        expect(lifeNotificationLocation(NotificationTap(namespace: r.namespace.name, id: r.id, data: d)), isNotNull);
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('warm: each life reminder opens its page; back returns home', (tester) async {
    final app = await pumpMadarApp(tester, settings: _english, now: _now, overrides: LockFixture.empty().overrides);
    Future<void> tapAndCheck(RawNotificationTap tap, String location, Type screen) async {
      app.notifications.tap(tap);
      await settleApp(tester);
      expect(app.router.state.uri.toString(), location);
      expect(find.byType(screen), findsOneWidget, reason: location);
    }

    await tapAndCheck(_digest(), '/family', FamilyScreen);
    await tapAndCheck(_birthday('p1'), '/family/person/p1', PersonScreen);
    // Nested under Family: back returns there, then home.
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.family);
    await tapAndCheck(_document('d1'), '/travel?tab=documents', TravelScreen);
    expect(tester.widget<TravelScreen>(find.byType(TravelScreen)).initialTab, TravelTab.documents);
    await tapAndCheck(_fasting(), '/body?tab=fasting', BodyScreen);
    expect(tester.widget<BodyScreen>(find.byType(BodyScreen)).initialTab, BodyTab.fasting);
    await tapAndCheck(_module('m1'), '/modules/module/m1', ModuleScreen);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.modules);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.home);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  for (final (name, tap, location, screen) in [
    ('the digest', _digest(launch: true), '/family', FamilyScreen),
    ('a birthday', _birthday('p-9', launch: true), '/family/person/p-9', PersonScreen),
    ('a document', _document('d-9', launch: true), '/travel?tab=documents', TravelScreen),
    ('a fasting notice', _fasting(launch: true), '/body?tab=fasting', BodyScreen),
    ('a tracker', _module('m-9', launch: true), '/modules/module/m-9', ModuleScreen),
  ]) {
    testWidgets('cold start from $name opens its page', (tester) async {
      final app = await pumpMadarApp(
        tester,
        settings: _english,
        now: _now,
        notifications: FakeNotificationPlatform(launch: tap),
        overrides: LockFixture.empty().overrides,
      );
      expect(app.router.state.uri.toString(), location);
      expect(find.byType(screen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    });
  }

  testWidgets('a life reminder tapped while locked moves the router under the lock', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    final app = await pumpMadarApp(tester, settings: _english, now: _now, overrides: fx.overrides);
    expect(find.byType(LockScreen), findsOneWidget);
    app.notifications.tap(_birthday('p-1'));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), '/family/person/p-1');
    expect(find.byType(LockScreen), findsOneWidget, reason: 'a deep link never lifts the lock');
    expect(find.byType(PersonScreen), findsNothing);
    app.notifications.tap(_module('m-1'));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), '/modules/module/m-1');
    expect(find.byType(LockScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('before onboarding a life tap is ignored', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(languageCode: 'en'),
      now: _now,
      overrides: LockFixture.empty().overrides,
    );
    expect(find.byType(OnboardingScreen), findsOneWidget);
    app.notifications.tap(_fasting());
    await settleApp(tester);
    expect(app.location, AppRoutes.onboarding);
    expect(find.byType(BodyScreen), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });
}
