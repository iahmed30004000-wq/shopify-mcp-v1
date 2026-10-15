import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/data/adhan_scheduler.dart';
import 'package:madar/features/adhan/data/adhan_system.dart';
import 'package:madar/features/adhan/data/adhan_texts.dart';
import 'package:madar/features/adhan/domain/adhan_event.dart';
import 'package:madar/features/adhan/domain/adhan_plan.dart';
import 'package:madar/features/adhan/domain/adhan_settings.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/adhan/domain/adhan_sound.dart';
import 'package:timezone/timezone.dart' as tz;

import 'adhan_fixtures.dart';

void main() {
  late tz.Location amman;
  late FakeNotificationPlatform platform;
  late FakeAdhanSystem system;
  late DateTime now;
  late AdhanScheduler scheduler;
  late AdhanTexts texts;

  setUpAll(() => amman = zone('Asia/Amman'));

  setUp(() {
    now = wall(amman, 2026, 9, 28, 13, 0);
    platform = FakeNotificationPlatform();
    system = FakeAdhanSystem();
    final service = NotificationService(platform, clock: () => now);
    scheduler = AdhanScheduler(notifications: service, system: system, clock: () => now);
    texts = AdhanTexts.forLanguage('ar', wallClock: (t) => tz.TZDateTime.from(t, amman));
  });

  Future<AdhanSyncResult> sync(AdhanSettings s) =>
      scheduler.sync(settings: s, timesFor: wallClockTimes(amman), localDayOf: localDayIn(amman), texts: texts);

  group('channels', () {
    test('adhan on the alarm stream with the muezzin as channel sound', () async {
      await sync(const AdhanSettings());
      final fajr = platform.channels['madar.adhan.call.tone-dawn.v.1']!;
      final others = platform.channels['madar.adhan.call.tone-brass.v.1']!;
      for (final c in [fajr, others]) {
        expect(c.usage, NotificationAudioUsage.alarm);
        expect(c.importance, NotificationImportance.urgent);
        expect(c.vibrate, isTrue);
        expect(c.groupId, AdhanScheduler.groupId);
      }
      expect(fajr.sound, const NotificationSoundSpec.raw('madar_tanbih_dawn'));
      expect(others.sound, const NotificationSoundSpec.raw('madar_tanbih_brass'));
      expect(fajr.name, contains('نور الفجر'));
      expect(
        platform.channels['madar.adhan.reminder.v.1']!.sound,
        const NotificationSoundSpec.raw('madar_tanbih_chime'),
      );
      expect(
        platform.channels['madar.adhan.sunrise.v.1']!.sound,
        const NotificationSoundSpec.raw('madar_tanbih_sunrise'),
      );
      expect(platform.groups[AdhanScheduler.groupId], 'الصلاة والأذان');
    });

    test('re-selecting a sound makes a new channel and removes the old one', () async {
      await sync(const AdhanSettings());
      await sync(const AdhanSettings(fajrSound: AdhanSoundRef.tone(TanbihTone.bowl)));
      expect(platform.channels.keys, contains('madar.adhan.call.tone-bowl.v.1'));
      expect(platform.channels.keys, isNot(contains('madar.adhan.call.tone-dawn.v.1')));
      expect(platform.deletedChannels, ['madar.adhan.call.tone-dawn.v.1']);
    });

    test('vibration is frozen per channel too', () async {
      await sync(const AdhanSettings());
      await sync(const AdhanSettings(vibrate: false));
      expect(platform.channels.keys.where((id) => id.contains('.v.')), isEmpty);
      final quiet = platform.channels['madar.adhan.call.tone-brass.q.1']!;
      expect(quiet.vibrate, isFalse);
      expect(quiet.vibrationPattern, isNull);
    });

    test("a recording plays through Madar's sound provider", () async {
      final m = CustomMuezzin(id: 'rec00001', name: 'Makkah', fileName: 'rec00001.mp3', addedAt: DateTime.utc(2026));
      await sync(const AdhanSettings().withMuezzin(m).copyWith(sound: AdhanSoundRef.file(m.id)));
      final c = platform.channels['madar.adhan.call.file-rec00001.v.1']!;
      expect(c.sound, const NotificationSoundSpec.uri('content://app.madar.orbit.adhansounds/rec00001.mp3'));
      expect(c.name, contains('Makkah'));
      final isha = platform.scheduled.values.firstWhere((s) => s.request.title.contains('العشاء'));
      expect(isha.request.channelId, c.id);
    });

    test('a recording whose file vanished falls back to the default tone', () async {
      final m = CustomMuezzin(id: 'rec00002', name: 'Gone', fileName: 'rec00002.mp3', addedAt: DateTime.utc(2026));
      final fs = _NoFileSystem();
      final service = NotificationService(platform, clock: () => now);
      final s = AdhanScheduler(notifications: service, system: fs, clock: () => now);
      await s.sync(
        settings: const AdhanSettings().withMuezzin(m).copyWith(sound: AdhanSoundRef.file(m.id)),
        timesFor: wallClockTimes(amman),
        localDayOf: localDayIn(amman),
        texts: texts,
      );
      final isha = platform.scheduled.values.firstWhere((x) => x.request.title.contains('العشاء'));
      expect(isha.request.channelId, 'madar.adhan.call.tone-brass.v.1');
    });
  });

  group('alarms', () {
    test('exact, full-screen, alarm category, with a stop action', () async {
      final result = await sync(const AdhanSettings());
      expect(result.report.scheduled, result.plan.length);
      expect(result.degraded, isFalse);
      final asr = platform.scheduled.values.first.request;
      final first = platform.scheduleLog.first;
      expect(first.timing, NotificationTiming.alarmClock);
      expect(asr.category, NotificationCategory.alarm);
      expect(asr.fullScreen, isTrue);
      expect(asr.publicOnLockScreen, isTrue);
      expect(asr.timeout, AdhanScheduler.callTimeout);
      expect(asr.actions.single.id, AdhanActions.stop);
      expect(asr.actions.single.opensApp, isFalse);
      expect(first.request.title, 'حان الآن وقت صلاة العصر');
      expect(first.request.body, contains('٣:٥٠'));
      final event = adhanEventFromPayload(first.payload, notificationId: first.request.id)!;
      expect(event.slot, AdhanSlot.asr);
      expect(event.prayerAt, wall(amman, 2026, 9, 28, 15, 50));
      expect(result.nextCall(now)?.slot, AdhanSlot.asr);
    });

    test('a full-screen switch off keeps the adhan but not the takeover', () async {
      await sync(const AdhanSettings(fullScreen: false));
      expect(platform.scheduled.values.every((s) => !s.request.fullScreen), isTrue);
    });

    test('re-syncing unchanged settings touches nothing', () async {
      await sync(const AdhanSettings());
      final log = platform.scheduleLog.length;
      final again = await sync(const AdhanSettings());
      expect(again.report.scheduled, 0);
      expect(again.report.cancelled, 0);
      expect(again.report.unchanged, again.plan.length);
      expect(platform.scheduleLog.length, log);
    });

    test('after a force stop (OEM task killer) the next sync re-arms the whole week', () async {
      final first = await sync(const AdhanSettings());
      // The system dropped every alarm; the plugin's cache still lists them.
      platform.dropArmedAlarms();
      expect(await platform.armedIds(platform.scheduled.keys), isEmpty);

      final again = await sync(const AdhanSettings());
      expect(again.report.rearmed, first.plan.length);
      expect(again.report.unchanged, 0);
      expect(await platform.armedIds(platform.scheduled.keys), hasLength(first.plan.length));
    });

    test('changing one prayer re-schedules only that prayer', () async {
      final first = await sync(const AdhanSettings());
      final asrCount = first.plan.where((a) => a.slot == AdhanSlot.asr).length;
      final off = await sync(const AdhanSettings().withAlert(AdhanSlot.asr, const PrayerAlert(adhan: false)));
      expect(off.report.cancelled, asrCount);
      expect(off.report.scheduled, 0);
      final fajr = await sync(
        const AdhanSettings(fajrSound: AdhanSoundRef.tone(TanbihTone.bowl))
            .withAlert(AdhanSlot.asr, const PrayerAlert(adhan: false)),
      );
      expect(fajr.report.scheduled, fajr.plan.where((a) => a.slot == AdhanSlot.fajr).length);
    });

    test('a day later only the new day is added', () async {
      await sync(const AdhanSettings());
      final log = platform.scheduleLog.length;
      now = now.add(const Duration(days: 1));
      final next = await sync(const AdhanSettings());
      expect(next.report.scheduled, 5, reason: 'one more day of five adhans');
      expect(platform.scheduleLog.length, log + 5);
    });

    test('language change re-schedules the texts', () async {
      await sync(const AdhanSettings());
      texts = AdhanTexts.forLanguage('en', wallClock: (t) => tz.TZDateTime.from(t, amman));
      final r = await sync(const AdhanSettings());
      expect(r.report.scheduled, r.plan.length);
      expect(platform.scheduled.values.first.request.title, "It's time for Asr");
    });

    test('reminders and sunrise use their own channels and drop-if-late windows', () async {
      await sync(
        const AdhanSettings(sunriseAlert: true).withAlert(AdhanSlot.maghrib, const PrayerAlert(preMinutes: 10)),
      );
      final pre = platform.scheduled.values.firstWhere((s) => s.request.title.startsWith('المغرب بعد'));
      expect(pre.request.title, 'المغرب بعد ١٠ دقائق');
      expect(pre.request.channelId, 'madar.adhan.reminder.v.1');
      expect(pre.request.timeout, const Duration(minutes: 10));
      expect(pre.request.fullScreen, isFalse);
      expect(pre.request.dropIfLateBy, AdhanScheduler.reminderDropIfLate);
      final sunrise = platform.scheduled.values.firstWhere((s) => s.request.channelId.contains('sunrise'));
      expect(sunrise.request.title, 'أشرقت الشمس');
    });

    test('exact alarms refused → scheduled inexactly and reported', () async {
      platform.exactAllowed = false;
      final r = await sync(const AdhanSettings());
      expect(r.degraded, isTrue);
      expect(r.report.inexactFallback, r.plan.length);
      expect(platform.scheduled.values.every((s) => s.timing == NotificationTiming.inexactWhileIdle), isTrue);
    });
  });

  group('test and snooze', () {
    test('test adhan: a real full-screen adhan in a few seconds', () async {
      final event = await scheduler.scheduleTest(settings: const AdhanSettings(), texts: texts);
      expect(event?.kind, AdhanKind.test);
      expect(event?.notificationId, AdhanIds.test);
      final t = platform.scheduled[AdhanIds.test]!;
      expect(t.request.at, now.add(const Duration(seconds: 10)));
      expect(t.request.fullScreen, isTrue);
      expect(t.timing, NotificationTiming.alarmClock);
      expect(adhanEventFromPayload(t.payload, notificationId: AdhanIds.test)!.kind, AdhanKind.test);
      // A re-plan in the meantime leaves the one-off test alone.
      final r = await sync(const AdhanSettings());
      expect(r.report.cancelled, 0);
      expect(platform.scheduled[AdhanIds.test], isNotNull);
    });

    test('snooze reminds again before the adhan, never after it', () async {
      final event = AdhanEvent(
        kind: AdhanKind.preAdhan,
        slot: AdhanSlot.asr,
        prayerAt: now.add(const Duration(minutes: 10)),
        firedAt: now,
        day: DateTime.utc(2026, 9, 28),
        minutesBefore: 10,
      );
      expect(await scheduler.snooze(event, settings: const AdhanSettings(), texts: texts), isTrue);
      final s = platform.scheduled[AdhanIds.snooze]!;
      expect(s.request.at, now.add(const Duration(minutes: 5)));
      expect(s.request.title, 'العصر بعد ٥ دقائق');
      final late = AdhanEvent(
        kind: AdhanKind.preAdhan,
        slot: AdhanSlot.asr,
        prayerAt: now.add(const Duration(minutes: 5, seconds: 30)),
        firedAt: now,
        day: DateTime.utc(2026, 9, 28),
      );
      expect(AdhanScheduler.canSnooze(late, settings: const AdhanSettings(), now: now), isFalse);
      expect(await scheduler.snooze(late, settings: const AdhanSettings(), texts: texts), isFalse);
      final adhan = AdhanEvent(
        kind: AdhanKind.adhan,
        slot: AdhanSlot.asr,
        prayerAt: now,
        firedAt: now,
        day: DateTime.utc(2026, 9, 28),
      );
      expect(AdhanScheduler.canSnooze(adhan, settings: const AdhanSettings(), now: now), isFalse);
    });

    test('silence cancels the sounding notification', () async {
      final event = AdhanEvent(
        kind: AdhanKind.adhan,
        slot: AdhanSlot.asr,
        prayerAt: now,
        firedAt: now,
        day: DateTime.utc(2026, 9, 28),
        notificationId: 100002,
      );
      await scheduler.silence(event);
      expect(platform.cancelled, [100002]);
    });
  });
}

class _NoFileSystem extends FakeAdhanSystem {
  @override
  Future<String?> soundUri(String fileName) async => null;
}
