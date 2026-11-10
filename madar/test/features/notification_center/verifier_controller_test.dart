// An independent verifier's end-to-end scenarios for the center over the
// gate, the fake plugin and a real in-memory database: a snooze its
// feature's re-plan moved off its id arrives once, listed once, and leaves
// the tray alone; a snooze its feature cancels is never counted as
// delivered; a tray removal never takes a Doze-delayed dose.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/features/adhkar/domain/adhkar_models.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/money/goals/data/goals_notifications.dart' show GoalsReminderIds;
import 'package:madar/features/notification_center/notification_center.dart';

import 'nc_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late DateTime now;
  late FakeNotificationPlatform fake;
  late MadarDatabase db;

  setUp(() {
    now = ncNow;
    fake = FakeNotificationPlatform();
    db = MadarDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  ProviderContainer container({List<Override> overrides = const []}) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationCenterClockProvider.overrideWithValue(() => now),
        homeClockProvider.overrideWithValue(() => now),
        notificationPlatformProvider.overrideWith((ref) => gatedNotificationPlatform(ref, fake)),
        notificationServiceProvider.overrideWith((ref) {
          final s = NotificationService(ref.watch(notificationPlatformProvider), clock: () => now);
          ref.onDispose(s.dispose);
          return s;
        }),
        ...overrides,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<NotificationCenterState> look(ProviderContainer c) async {
    c.read(notificationCenterProvider);
    await c.read(notificationCenterProvider.notifier).refresh();
    return c.read(notificationCenterProvider);
  }

  NotificationService service(ProviderContainer c) => c.read(notificationServiceProvider);
  NotificationCenterController ctrl(ProviderContainer c) => c.read(notificationCenterProvider.notifier);

  test('a snooze moved off its id by a re-plan: arrives, is listed once, and leaves the tray alone', () async {
    final c = container();
    final today = moneyDue(ncAt(0, 9));
    await service(c).show(today);
    final item = (await look(c)).recent.single;
    expect(await ctrl(c).snooze(item, const Duration(minutes: 30)), ncAt(0, 13, 40));
    // The goals re-plan (a due changed): of(0) is now the next due.
    final next = moneyDue(ncAt(3, 9));
    await service(c).sync(NotificationNamespaces.reminders, [next], keep: (id) => !GoalsReminderIds.owns(id));
    var state = await look(c);
    expect(state.upcoming.map((i) => (i.id, i.state, i.at)), [
      (today.id, CenterItemState.snoozed, ncAt(0, 13, 40)),
      (next.id, CenterItemState.scheduled, next.at.toUtc()),
    ]);
    // It arrives (on the center's id).
    now = ncAt(0, 13, 41);
    fake.fireDue(now);
    state = await look(c);
    final keys = state.recent.map((i) => i.key).toList();
    expect(keys.toSet(), hasLength(keys.length), reason: 'one row per firing');
    final arrived = state.recent.firstWhere((i) => i.notice.at == ncAt(0, 13, 40).toUtc());
    expect(arrived.id, today.id);
    expect(arrived.live, isTrue);
    // Dismissed: it leaves the tray; the next due stays armed.
    await ctrl(c).dismiss(arrived);
    expect(fake.shown, isEmpty);
    expect(fake.scheduled[next.id]?.payload, NotificationEnvelope.encode(next));
  });

  test('a snooze its feature cancels is never counted as delivered', () async {
    final c = container();
    final r = adhkar(AdhkarCategoryId.evening, ncAt(0, 12, 50));
    await service(c).show(r);
    final item = (await look(c)).recent.single;
    expect(await ctrl(c).snooze(item, const Duration(minutes: 30)), isNotNull);
    await look(c);
    // The adhkar were done in the app: the feature takes its reminder back.
    await service(c).cancel(r.id);
    expect(fake.scheduled, isEmpty);
    now = ncAt(0, 13, 45);
    final state = await look(c);
    expect(state.recent.where((i) => i.state == CenterItemState.delivered || i.state == CenterItemState.live), isEmpty);
    expect(state.upcoming, isEmpty);
  });

  test('answering an old dose from the center never cancels the dose Doze is still holding', () async {
    final c = container();
    final yesterday = medsDose(ncAt(-1, 20));
    await service(c).show(yesterday);
    now = ncAt(0, 13);
    final delayed = medsDose(ncAt(0, 13, 5)); // the same id, re-assigned
    expect(await service(c).schedule(delayed), isTrue);
    now = ncAt(0, 13, 10);
    final item = (await look(c)).recent.single;
    await ctrl(c).dismiss(item);
    expect(fake.scheduled[delayed.id]?.payload, NotificationEnvelope.encode(delayed));
  });
}
