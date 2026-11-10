// The life services the unlocked app keeps running, in the full app with no
// life screen ever opened:
// * a card placed in a prayer window is finished from the home panel's
//   task → the card moves to its board's done column (card ⇄ task sync);
// * a trip whose dates have passed is marked done at start (Travel's
//   moons and balance follow);
// * yesterday's finished Top 3 is settled at start (the home-screen widget
//   never shows a stale focus);
// * every life reminder sync is alive after the first frame – and a broken
//   notifications plugin takes none of it down.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/life_services.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/body/body.dart' show bodyReminderSyncProvider;
import 'package:madar/features/custom_modules/custom_modules.dart' show customModulesReminderSyncProvider;
import 'package:madar/features/family/family.dart' show familyReminderSyncProvider;
import 'package:madar/features/home/home_providers.dart' show homeTasksServiceProvider;
import 'package:madar/features/home/home_screen.dart';
import 'package:madar/features/travel/travel.dart'
    show TravelService, TripDraft, travelReminderSyncProvider, travelStatusSyncProvider;
import 'package:madar/features/work/work.dart' show CardDraft, WorkDays, WorkService, workCardTaskSyncProvider;

import '../features/lock/lock_test_utils.dart';
import '../helpers/test_app.dart';

const _english = AppSettings(onboarded: true, languageCode: 'en');

/// Lets database writes and the syncs' debounces finish.
Future<void> _writes(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// No notifications plugin at all.
class _BrokenNotifications extends FakeNotificationPlatform {
  @override
  Future<void> initialize({required void Function(RawNotificationTap tap) onTap}) async =>
      throw StateError('no notifications here');

  @override
  Future<RawNotificationTap?> launchTap() async => throw StateError('no notifications here');

  @override
  Future<List<PendingNotice>> pending() async => throw StateError('no notifications here');

  @override
  Future<void> schedule(NotificationRequest request, String payload, {required NotificationTiming timing}) async =>
      throw StateError('no notifications here');
}

void main() {
  testWidgets('a placed card finished from the home panel moves to done – Work never opened', (tester) async {
    late String cardId;
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async {
        final work = WorkService(Repositories(db), clock: () => testNow);
        final board = await work.createBoard(name: 'Shop');
        final card = await work.addCard(board.id, const CardDraft(title: 'Call the supplier'));
        await work.placeCard(card, PrayerWindow.dhuhr);
        cardId = card.id;
      },
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(app.container.exists(workCardTaskSyncProvider), isTrue, reason: 'watched app-wide');
    final tasks = await tester.runAsync(() => app.repos.tasks.getAll(where: (t) => t.cardId.equals(cardId)));
    expect(tasks, hasLength(1));
    expect(tasks!.single.done, isFalse);

    // The home panel's own service – the path of the task row's checkbox.
    final done = app.container.read(homeTasksServiceProvider).toggleDone(tasks.single);
    await _writes(tester);
    await tester.runAsync(() => done);
    await _writes(tester);
    final card = await tester.runAsync(() => app.repos.boardCards.byId(cardId));
    expect(card!.columnId, 'done');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a trip whose dates have passed is marked done at start', (tester) async {
    late String tripId;
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async {
        // Planned back on the 1st, for the 10th–20th: it is over by now.
        final travel = TravelService(Repositories(db), clock: () => DateTime(2026, 9, 1, 9));
        tripId = (await travel.addTrip(
          TripDraft(destination: 'Aqaba', startDate: DateTime(2026, 9, 10), endDate: DateTime(2026, 9, 20)),
        )).id;
        expect((await Repositories(db).trips.byId(tripId))!.status, TripStatus.planned);
      },
    );
    await _writes(tester);
    expect(app.container.exists(travelStatusSyncProvider), isTrue);
    final trip = await tester.runAsync(() => app.repos.trips.byId(tripId));
    expect(trip!.status, TripStatus.done);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets("yesterday's finished Top 3 is settled at start", (tester) async {
    late String taskId;
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async {
        final repos = Repositories(db);
        final yesterday = testNow.subtract(const Duration(days: 1));
        final task = await repos.tasks.insert(
          TasksCompanion.insert(
            title: 'Send the invoice',
            planetKey: const Value('work'),
            date: Value(DateTime(yesterday.year, yesterday.month, yesterday.day)),
            isTop3: const Value(true),
            done: const Value(true),
            doneAt: Value(yesterday),
          ),
        );
        taskId = task.id;
        await repos.keyValues.setJson(WorkService.top3DayKey, WorkDays.key(yesterday));
      },
    );
    await _writes(tester);
    expect(app.container.exists(workTop3SettleProvider), isTrue);
    final task = await tester.runAsync(() => app.repos.tasks.byId(taskId));
    expect(task!.isTop3, isFalse, reason: 'a finished focus of an earlier day is cleared');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('every life sync is alive after the first frame', (tester) async {
    final app = await pumpMadarApp(tester, settings: _english, overrides: LockFixture.empty().overrides);
    final c = app.container;
    expect(c.exists(workCardTaskSyncProvider), isTrue);
    expect(c.exists(workTop3SettleProvider), isTrue);
    expect(c.exists(familyReminderSyncProvider), isTrue);
    expect(c.exists(travelStatusSyncProvider), isTrue);
    expect(c.exists(travelReminderSyncProvider), isTrue);
    expect(c.exists(bodyReminderSyncProvider), isTrue);
    expect(c.exists(customModulesReminderSyncProvider), isTrue);
    await _writes(tester);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a broken notifications plugin takes none of the life services down', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      notifications: _BrokenNotifications(),
      overrides: LockFixture.empty().overrides,
      beforePump: (MadarDatabase db) async {
        final repos = Repositories(db);
        await repos.people.insert(
          PeopleCompanion.insert(
            name: 'Mum',
            rhythmDays: const Value(3),
            lastContact: Value(testNow.subtract(const Duration(days: 12))),
          ),
        );
      },
    );
    await _writes(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(app.container.exists(familyReminderSyncProvider), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });
}
