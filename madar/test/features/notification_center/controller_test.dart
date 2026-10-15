import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/features/adhan/domain/adhan_event.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/adhkar/domain/adhkar_models.dart';
import 'package:madar/features/health/meds/data/meds_notifications.dart';
import 'package:madar/features/health/meds/data/meds_providers.dart';
import 'package:madar/features/health/meds/data/meds_service.dart';
import 'package:madar/features/health/meds/domain/med_models.dart';
import 'package:madar/features/health/meds/meds_texts.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/notification_center/notification_center.dart';

import 'nc_fixtures.dart';

/// The meds reminder sync without its planning (prayer times, settings…):
/// only what an answer needs afterwards.
class _QuietMedsSync extends MedsReminderSync {
  @override
  NotificationSyncReport? build() => null;
}

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

  ProviderContainer container({List<Override> overrides = const [], bool gated = true}) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationCenterClockProvider.overrideWithValue(() => now),
        homeClockProvider.overrideWithValue(() => now),
        notificationPlatformProvider.overrideWith((ref) => gated ? gatedNotificationPlatform(ref, fake) : fake),
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

  test('upcoming: every feature\'s pending notifications of the week, grouped with counts', () async {
    final c = container();
    final s = service(c);
    await s.sync(NotificationNamespaces.adhan, [
      adhanCall(AdhanSlot.maghrib, ncAt(0, 18, 12)),
      adhanCall(AdhanSlot.isha, ncAt(0, 19, 40)),
    ]);
    await s.sync(NotificationNamespaces.adhkar, [adhkar(AdhkarCategoryId.morning, ncAt(1, 5, 30))]);
    await s.sync(NotificationNamespaces.reminders, [moneyDue(ncAt(2, 9)), travelDoc(ncAt(20, 10))]);
    final state = await look(c);
    expect(state.loaded, isTrue);
    expect(state.enforced, isTrue);
    expect(state.upcoming, hasLength(4), reason: 'the travel reminder is beyond the week');
    expect(state.upcomingSections.map((x) => (x.group, x.count)), [
      (NotificationGroup.prayer, 2),
      (NotificationGroup.adhkar, 1),
      (NotificationGroup.money, 1),
    ]);
    expect(state.upcoming.first.notice.title, isNotEmpty);
    expect(state.upcomingIn(NotificationGroup.prayer), 2);
    expect(state.recent, isEmpty);
  });

  test('recent: what fired while nobody looked is delivered; what a feature cancelled first is not', () async {
    final c = container();
    final s = service(c);
    final morning = adhkar(AdhkarCategoryId.morning, ncAt(0, 13, 30));
    final plan = wird(ncAt(0, 13, 40));
    await s.sync(NotificationNamespaces.adhkar, [morning]);
    await s.sync(NotificationNamespaces.wird, [plan]);
    await look(c);
    // The wird was read early: the feature cancels its reminder.
    await s.sync(NotificationNamespaces.wird, const []);
    // The adhkar reminder fires, is swiped away in the tray.
    now = ncAt(0, 13, 45);
    fake.fireDue(now);
    await fake.cancel(morning.id);
    final state = await look(c);
    expect(state.recent.map((i) => i.notice.id), [morning.id]);
    expect(state.recent.single.state, CenterItemState.delivered);
    expect(state.recent.single.unread, isTrue);
    expect(state.unread, 1);
    expect(c.read(notificationUnreadCountProvider), 1);
  });

  test('the tray is recorded; a live notification offers its buttons', () async {
    final c = container();
    await service(c).show(medsDose(ncAt(0, 13)));
    await service(c).show(adhanCall(AdhanSlot.dhuhr, ncAt(0, 12, 30)));
    final state = await look(c);
    expect(state.recent.map((i) => i.group), [NotificationGroup.medications, NotificationGroup.prayer]);
    expect(state.recent.every((i) => i.live && i.state == CenterItemState.live), isTrue);
    expect(state.recentSections.map((x) => x.group), [NotificationGroup.medications, NotificationGroup.prayer]);
  });

  test('a mute holds the group back, lists it as muted, and records it silenced at its time', () async {
    final c = container();
    await look(c);
    await ctrl(c).mute(NotificationGroup.prayer, ncAt(0, 19));
    final maghrib = adhanCall(AdhanSlot.maghrib, ncAt(0, 18, 12));
    final isha = adhanCall(AdhanSlot.isha, ncAt(0, 19, 40));
    await service(c).sync(NotificationNamespaces.adhan, [maghrib, isha]);
    var state = await look(c);
    expect(fake.scheduled.keys, [isha.id], reason: 'Maghrib never reaches the system');
    expect(state.upcoming.map((i) => i.state), [CenterItemState.muted, CenterItemState.scheduled]);
    expect(state.mutes, {NotificationGroup.prayer: ncAt(0, 19)});
    expect(state.upcomingSections.single.mutedUntil, ncAt(0, 19));
    now = ncAt(0, 18, 20);
    state = await look(c);
    expect(state.recent.single.state, CenterItemState.silenced);
    expect(state.recent.single.notice.id, maghrib.id);
    // Mute ends: the group is back (nothing to re-arm – only moments inside it were held).
    now = ncAt(0, 19, 1);
    state = await look(c);
    expect(state.mutes, isEmpty);
    expect(fake.scheduled.keys, [isha.id]);
  });

  test('muted show() is silenced into Recent', () async {
    final c = container();
    await look(c);
    await ctrl(c).mute(NotificationGroup.medications, ncAt(0, 16));
    await service(c).show(medsRefill(now));
    await pumpEventQueue();
    final state = await look(c);
    expect(fake.shown, isEmpty);
    expect(state.recent.single.state, CenterItemState.silenced);
    expect(state.unread, 1);
  });

  test('mute undo restores the previous state; unmute re-arms what is held', () async {
    final c = container();
    await look(c);
    final isha = adhanCall(AdhanSlot.isha, ncAt(0, 19, 40));
    await service(c).sync(NotificationNamespaces.adhan, [isha]);
    final undo = await ctrl(c).mute(NotificationGroup.prayer, ncAt(1, 7));
    expect(fake.scheduled, isEmpty);
    await undo();
    expect(fake.scheduled.keys, [isha.id]);
    expect((await look(c)).mutes, isEmpty);
  });

  test('taps and button answers from the tray are recorded', () async {
    final c = container();
    await look(c);
    final dose = medsDose(ncAt(0, 13));
    final morning = adhkar(AdhkarCategoryId.morning, ncAt(0, 5, 30));
    await service(c).show(dose);
    await service(c).show(morning);
    fake.tap(RawNotificationTap(id: morning.id, payload: fake.shown[morning.id]!.payload));
    fake.tap(
      RawNotificationTap(id: dose.id, actionId: MedsNotificationTaps.actionSkip, payload: fake.shown[dose.id]!.payload),
    );
    await pumpEventQueue();
    final state = await look(c);
    final byId = {for (final i in state.recent) i.notice.id: i};
    expect(byId[morning.id]!.state, CenterItemState.opened);
    expect(byId[dose.id]!.state, CenterItemState.acted);
    expect(byId[dose.id]!.actionId, MedsNotificationTaps.actionSkip);
    expect(byId[dose.id]!.notice.title, dose.title, reason: 'texts merged from the tray');
    expect(state.unread, 0, reason: 'handled ones are not new');
  });

  test('inline actions route through the handler registered for the action id', () async {
    final calls = <CenterActionRequest>[];
    final c = container(
      overrides: [
        notificationActionHandlersProvider.overrideWithValue(
          NotificationActionHandlers({
            MedsNotificationTaps.actionTaken: (r) async {
              calls.add(r);
              return true;
            },
            'broken': (r) async => false,
          }),
        ),
      ],
    );
    final dose = medsDose(ncAt(0, 13));
    await service(c).show(dose);
    final item = (await look(c)).recent.single;
    expect(await ctrl(c).perform(item, MedsNotificationTaps.actionTaken), isTrue);
    expect(calls.single.actionId, MedsNotificationTaps.actionTaken);
    expect(calls.single.live, isTrue);
    expect(MedsNotificationTaps.doseOf(calls.single.tap)!.medId, 'med-1');
    expect(fake.shown, isEmpty, reason: 'taken out of the tray, as its button would');
    final after = c.read(notificationCenterProvider).recent.single;
    expect(after.state, CenterItemState.acted);
    expect(after.actionId, MedsNotificationTaps.actionTaken);
    expect(await ctrl(c).perform(after, 'broken'), isFalse);
    expect(await ctrl(c).perform(after, 'unknown'), isFalse);
  });

  test('Taken on a dose is recorded by the medication tracker itself', () async {
    final c = container(
      overrides: [
        medsReminderSyncProvider.overrideWith(_QuietMedsSync.new),
        medsNotificationTextsProvider.overrideWithValue(MedsTexts.forLanguage('ar')),
        medsPrayerTimeProvider.overrideWithValue((day, prayer) => null),
      ],
    );
    final meds = MedsService(Repositories(db), clock: () => now);
    final med = await meds.saveMed(
      MedDraft(
        name: 'Levo',
        dose: '10 mg',
        slots: [MedSlot(ClockHm.tryParse('13:00')!)],
        takenWith: TakenWith.breakfast,
      ),
    );
    now = ncAt(0, 12);
    final engine = MedsReminderEngine(
      service: meds,
      notifications: service(c),
      texts: MedsTexts.forLanguage('ar'),
      clock: () => now,
    );
    await engine.resync();
    now = ncAt(0, 13, 2);
    fake.fireDue(now);
    final state = await look(c);
    final item = state.recent.firstWhere((i) => i.group == NotificationGroup.medications);
    expect(item.live, isTrue);
    expect(MedsNotificationTaps.doseOf(item.notice.toTap())!.medId, med.id);
    expect(await ctrl(c).perform(item, MedsNotificationTaps.actionTaken), isTrue);
    final logs = await meds.logs(DateTime(2026, 9, 30));
    expect(logs.single.status, DoseStatus.taken);
    expect(logs.single.slot, ncAt(0, 13));
    expect(fake.shown.containsKey(item.id), isFalse);
  });

  test('adhan Stop silences the sounding notification', () async {
    final c = container();
    final call = adhanCall(AdhanSlot.asr, ncAt(0, 13, 5));
    await service(c).show(call);
    final item = (await look(c)).recent.single;
    expect(await ctrl(c).perform(item, AdhanActions.stop), isTrue);
    expect(fake.shown, isEmpty);
    expect(fake.cancelled, contains(call.id));
    expect(c.read(notificationCenterProvider).recent.single.state, CenterItemState.acted);
  });

  test('snooze takes it out of the tray and lists it upcoming; undo cancels', () async {
    final c = container();
    final morning = adhkar(AdhkarCategoryId.morning, ncAt(0, 12, 50));
    await service(c).show(morning);
    final item = (await look(c)).recent.single;
    final until = await ctrl(c).snooze(item, const Duration(minutes: 30));
    expect(until, ncAt(0, 13, 40));
    var state = c.read(notificationCenterProvider);
    expect(fake.shown, isEmpty);
    expect(fake.scheduled[morning.id]!.request.at, ncAt(0, 13, 40));
    expect(state.recent.single.state, CenterItemState.deferred);
    expect(state.recent.single.until, ncAt(0, 13, 40));
    expect(state.upcoming.single.state, CenterItemState.snoozed);
    expect(state.upcoming.single.at, ncAt(0, 13, 40));
    // The adhkar feature re-plans (nothing wanted): the snooze survives.
    await service(c).sync(NotificationNamespaces.adhkar, const []);
    expect(fake.scheduled.keys, [morning.id]);
    await ctrl(c).cancelSnooze(state.upcoming.single);
    state = c.read(notificationCenterProvider);
    expect(fake.scheduled, isEmpty);
    expect(state.upcoming, isEmpty);
  });

  test('skip one upcoming firing, with undo', () async {
    final c = container();
    final isha = adhanCall(AdhanSlot.isha, ncAt(0, 19, 40));
    await service(c).sync(NotificationNamespaces.adhan, [isha]);
    final item = (await look(c)).upcoming.single;
    final undo = await ctrl(c).skip(item);
    expect(fake.scheduled, isEmpty);
    expect(c.read(notificationCenterProvider).upcoming.single.state, CenterItemState.skipped);
    await undo();
    expect(fake.scheduled.keys, [isha.id]);
    expect(c.read(notificationCenterProvider).upcoming.single.state, CenterItemState.scheduled);
  });

  test('dismiss and clear all hide from Recent and clear the tray; undo brings them back', () async {
    final c = container();
    await service(c).show(medsDose(ncAt(0, 13)));
    await service(c).show(worry(ncAt(0, 12)));
    await service(c).show(moneyDue(ncAt(0, 9)));
    var state = await look(c);
    expect(state.recent, hasLength(3));
    final undoOne = await ctrl(c).dismiss(state.recent.first);
    state = c.read(notificationCenterProvider);
    expect(state.recent, hasLength(2));
    expect(fake.shown, hasLength(2));
    await undoOne();
    expect(c.read(notificationCenterProvider).recent, hasLength(3));
    final undoAll = await ctrl(c).clearAll();
    expect(c.read(notificationCenterProvider).recent, isEmpty);
    expect(fake.shown, isEmpty);
    // Nothing comes back by itself.
    expect((await look(c)).recent, isEmpty);
    await undoAll!();
    expect(c.read(notificationCenterProvider).recent, hasLength(3));
  });

  test('seen: the Recent tab clears the new count', () async {
    final c = container();
    await service(c).show(worry(ncAt(0, 13)));
    expect((await look(c)).unread, 1);
    now = ncAt(0, 13, 12);
    await ctrl(c).markSeen();
    expect(c.read(notificationUnreadCountProvider), 0);
    expect(c.read(notificationCenterProvider).recent.single.unread, isFalse);
  });

  test('history, policy and last look persist in the key/value store (no schema change)', () async {
    var c = container();
    final morning = adhkar(AdhkarCategoryId.morning, ncAt(0, 12));
    await service(c).show(morning);
    await look(c);
    await ctrl(c).mute(NotificationGroup.family, ncAt(1, 7));
    await ctrl(c).markSeen();
    final kv = Repositories(db).keyValues;
    expect(await kv.getJson(NotificationCenterStore.historyKey), isA<List<Object?>>());
    expect(await kv.getJson(NotificationCenterStore.policyKey), isA<Map<Object?, Object?>>());
    c.dispose();
    // A restart: the tray is gone, the memory stays.
    fake.shown.clear();
    c = container();
    final state = await look(c);
    expect(state.recent.single.notice.id, morning.id);
    expect(state.recent.single.live, isFalse);
    expect(state.mutes, {NotificationGroup.family: ncAt(1, 7)});
    expect(state.unread, 0);
  });

  test('without the gate the center still lists and does its best', () async {
    final c = container(gated: false);
    final isha = adhanCall(AdhanSlot.isha, ncAt(0, 19, 40));
    await service(c).sync(NotificationNamespaces.adhan, [isha]);
    final state = await look(c);
    expect(state.enforced, isFalse);
    await ctrl(c).skip(state.upcoming.single);
    expect(fake.scheduled, isEmpty, reason: 'cancelled directly');
  });
}
