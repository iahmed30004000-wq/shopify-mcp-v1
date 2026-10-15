// The iqama's channel, its requests and its delivery guarantees – which
// must be the adhan's, never weaker – plus the settings round trip a
// backup and restore depend on.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/data/adhan_system.dart';
import 'package:madar/features/adhan/domain/adhan_settings.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/adhan/domain/adhan_sound.dart';
import 'package:madar/features/iqama/iqama.dart';
import 'package:timezone/timezone.dart' as tz;

import '../adhan/adhan_fixtures.dart';

void main() {
  late tz.Location amman;
  late FakeNotificationPlatform platform;
  late FakeAdhanSystem system;
  late DateTime now;
  late IqamaScheduler scheduler;
  late IqamaTexts texts;

  setUpAll(() => amman = zone('Asia/Amman'));

  setUp(() {
    now = wall(amman, 2026, 9, 28, 13, 0);
    platform = FakeNotificationPlatform();
    system = FakeAdhanSystem();
    scheduler = IqamaScheduler(
      notifications: NotificationService(platform, clock: () => now),
      system: system,
      clock: () => now,
    );
    texts = IqamaTexts.forLanguage('ar', wallClock: (t) => tz.TZDateTime.from(t, amman));
  });

  Future<IqamaSyncResult> sync({
    IqamaSettings settings = const IqamaSettings(),
    AdhanSettings adhan = const AdhanSettings(),
  }) => scheduler.sync(
    settings: settings,
    adhan: adhan,
    timesFor: wallClockTimes(amman),
    localDayOf: localDayIn(amman),
    texts: texts,
  );

  List<FakeScheduled> iqamas() =>
      platform.scheduled.values.where((s) => IqamaIds.namespace.contains(s.request.id)).toList()
        ..sort((a, b) => a.request.at.compareTo(b.request.at));

  group('the channel', () {
    test('its own channel, on the alarm stream, in the prayer group', () async {
      await sync();
      final channel = platform.channels['madar.iqama.call.tone-chime.v.1']!;
      expect(channel.usage, NotificationAudioUsage.alarm);
      expect(channel.importance, NotificationImportance.urgent);
      expect(channel.sound, const NotificationSoundSpec.raw('madar_tanbih_chime'));
      expect(channel.groupId, 'madar.adhan');
      expect(channel.name, contains('الإقامة'));
      expect(platform.groups['madar.adhan'], 'الصلاة والأذان');
      // It is never the adhan's channel.
      expect(platform.channels.keys.where((k) => k.startsWith('madar.adhan.call')), isEmpty);
    });

    test('its own sound: a recording of the adhan library, with the old channel pruned', () async {
      final muezzin = CustomMuezzin(id: 'abcd1234', name: 'إقامة الحرم', fileName: 'abcd1234.mp3', addedAt: now);
      await sync();
      expect(platform.channels.keys, contains('madar.iqama.call.tone-chime.v.1'));
      await sync(
        settings: const IqamaSettings(sound: AdhanSoundRef.file('abcd1234')),
        adhan: const AdhanSettings().withMuezzin(muezzin),
      );
      final channel = platform.channels['madar.iqama.call.file-abcd1234.v.1']!;
      expect(channel.sound, const NotificationSoundSpec.uri('content://app.madar.orbit.adhansounds/abcd1234.mp3'));
      expect(channel.name, contains('إقامة الحرم'));
      expect(platform.channels.keys.where((k) => k.startsWith('madar.iqama.')), hasLength(1));
      expect(platform.deletedChannels, contains('madar.iqama.call.tone-chime.v.1'));
    });

    test('a recording that is gone falls back to the tone, and nothing is silent by accident', () async {
      system.directory = null;
      await sync(settings: const IqamaSettings(sound: AdhanSoundRef.file('abcd1234')));
      // Not in the library at all → resolved to the chime before any URI.
      expect(platform.channels.keys.single, 'madar.iqama.call.tone-chime.v.1');
    });

    test('silence is a choice of its own (vibration and the shade only)', () async {
      await sync(settings: const IqamaSettings(sound: AdhanSoundRef.silent()));
      final channel = platform.channels['madar.iqama.call.silent.v.1']!;
      expect(channel.sound, const NotificationSoundSpec.silent());
    });
  });

  group('the notification', () {
    test('«قامت الصلاة», the prayer and its adhan time, on the iqama channel', () async {
      await sync();
      final next = iqamas().first;
      expect(next.request.title, 'قامت الصلاة');
      expect(next.request.body, contains('العصر'));
      expect(next.request.body, contains('٣:٥٠'));
      expect(next.request.channelId, 'madar.iqama.call.tone-chime.v.1');
      expect(next.request.at, wall(amman, 2026, 9, 28, 16, 5));
    });

    test('«صلّيت» and «بعد شوي», both answered without opening Madar', () async {
      await sync();
      final actions = iqamas().first.request.actions;
      expect(actions.map((a) => a.id), [IqamaActions.prayed, IqamaActions.later]);
      expect(actions.map((a) => a.title), ['صلّيت', 'بعد شوي']);
      for (final a in actions) {
        expect(a.opensApp, isFalse, reason: 'answering must never open the app or meet the lock');
        expect(a.cancels, isTrue);
      }
    });

    test('the adhan\'s delivery guarantees, not weaker', () async {
      await sync();
      for (final s in iqamas()) {
        expect(s.request.timing, NotificationTiming.alarmClock, reason: 'exact, out of Doze, past battery saver');
        expect(s.timing, NotificationTiming.alarmClock, reason: 'and that is what reached the platform');
        expect(s.request.category, NotificationCategory.alarm);
        expect(s.request.publicOnLockScreen, isTrue, reason: 'readable on a locked screen');
        expect(s.request.dropIfLateBy, IqamaNotifications.dropIfLateBy, reason: 'restored after a reboot while due');
      }
    });

    test('its payload carries the prayer, its day, the adhan and the next one', () async {
      await sync();
      final tap = NotificationEnvelope.decode(iqamas().first.payload, id: iqamas().first.request.id);
      expect(tap.namespace, 'iqama');
      expect(IqamaNotificationTaps.slotOf(tap), AdhanSlot.asr);
      expect(IqamaNotificationTaps.dayOf(tap), DateTime.utc(2026, 9, 28));
      expect(IqamaNotificationTaps.prayerAtOf(tap), wall(amman, 2026, 9, 28, 15, 50));
      final answer = IqamaNotificationTaps.answerOf(
        NotificationTap(id: tap.id, namespace: tap.namespace, data: tap.data, actionId: IqamaActions.prayed),
      )!;
      expect(answer.nextAdhanAt, wall(amman, 2026, 9, 28, 18, 30));
      expect(answer.snoozeMinutes, 5);
      expect(answer.language, 'ar');
    });
  });

  group('the sync', () {
    test('no churn: an unchanged plan re-schedules nothing', () async {
      final first = await sync();
      expect(first.report.scheduled, greaterThan(0));
      final calls = platform.scheduleLog.length;
      final second = await sync();
      expect(second.report.scheduled, 0);
      expect(second.report.unchanged, first.report.scheduled);
      expect(platform.scheduleLog, hasLength(calls), reason: 'no alarm churn');
    });

    test('switching one prayer off cancels only its own iqamas', () async {
      await sync();
      final asrIds = iqamas()
          .where((s) => s.request.body.contains('العصر'))
          .map((s) => s.request.id)
          .toSet();
      expect(asrIds, isNotEmpty);
      await sync(settings: const IqamaSettings().withPrayer(AdhanSlot.asr, const IqamaPrayer(on: false)));
      expect(iqamas().where((s) => asrIds.contains(s.request.id)), isEmpty);
      expect(iqamas(), isNotEmpty);
    });

    test('a re-plan never cancels the one snooze', () async {
      await sync();
      // The snooze, armed outside the declarative plan.
      final service = NotificationService(platform, clock: () => now);
      await service.schedule(
        IqamaNotifications.request(
          IqamaAlarm(
            id: IqamaIds.snooze,
            slot: AdhanSlot.asr,
            at: now.add(const Duration(minutes: 5)),
            prayerAt: wall(amman, 2026, 9, 28, 15, 50),
            day: DateTime.utc(2026, 9, 28),
            minutes: 0,
          ),
          settings: const IqamaSettings(),
          texts: texts,
          channelId: 'madar.iqama.call.tone-chime.v.1',
          snooze: true,
        ),
      );
      expect(platform.scheduled.containsKey(IqamaIds.snooze), isTrue);
      await sync(settings: const IqamaSettings().withPrayer(AdhanSlot.fajr, const IqamaPrayer(minutes: 20)));
      expect(platform.scheduled.containsKey(IqamaIds.snooze), isTrue, reason: 'the snooze is a one-off, never swept');
    });

    test('every id stays inside the iqama block and out of the adhan\'s', () async {
      await sync();
      for (final s in iqamas()) {
        expect(NotificationNamespaces.owning(s.request.id), NotificationNamespaces.iqama);
        expect(NotificationNamespaces.adhan.contains(s.request.id), isFalse);
      }
      expect(NotificationNamespaces.iqama.first, 180000);
      expect(NotificationNamespaces.iqama.last, 180999);
      for (final other in NotificationNamespaces.all) {
        if (other.name == 'iqama') continue;
        expect(other.last < 180000 || other.first > 180999, isTrue, reason: '${other.name} reaches into the iqama');
      }
      expect(NotificationNamespaces.center.contains(180000), isFalse);
    });
  });

  group('the settings survive a backup and a restore', () {
    test('every offset, Friday\'s, the sound, the vibration and the snooze come back', () {
      final settings = const IqamaSettings(
        jumuah: IqamaPrayer(minutes: 35),
        sound: AdhanSoundRef.file('abcd1234'),
        vibrate: false,
        snoozeMinutes: 10,
      ).withPrayer(AdhanSlot.fajr, const IqamaPrayer(minutes: 25)).withPrayer(AdhanSlot.asr, const IqamaPrayer(on: false));
      final back = IqamaSettings.fromJson(settings.toJson());
      expect(back, settings);
      expect(back.of(AdhanSlot.fajr).minutes, 25);
      expect(back.of(AdhanSlot.asr).on, isFalse);
      expect(back.jumuah.minutes, 35);
      expect(back.sound, const AdhanSoundRef.file('abcd1234'));
      expect(back.vibrate, isFalse);
      expect(back.snoozeMinutes, 10);
    });

    test('a missing or broken row is the defaults, never a crash', () {
      expect(IqamaSettings.fromJson(null), const IqamaSettings());
      expect(IqamaSettings.fromJson('rubbish'), const IqamaSettings());
      final odd = IqamaSettings.fromJson({
        'prayers': {'fajr': 'nonsense', 'nope': {'m': 5}},
        'sound': 'file:',
        'snooze': 999,
      });
      expect(odd.of(AdhanSlot.fajr).minutes, IqamaSettings.defaultMinutes);
      expect(odd.sound, const AdhanSoundRef.tone(TanbihTone.chime));
      expect(odd.snoozeMinutes, 30, reason: 'clamped, not trusted');
    });

    test('a row written before Friday had its own entry keeps Dhuhr\'s offset', () {
      final back = IqamaSettings.fromJson({
        'v': 1,
        'prayers': {'dhuhr': {'on': true, 'm': 20}},
      });
      expect(back.jumuah.minutes, 20);
      expect(back.on(DateTime.utc(2026, 10, 2), AdhanSlot.dhuhr).minutes, 20);
    });

    test('a deleted recording falls back to the tone when the library no longer has it', () {
      const settings = IqamaSettings(sound: AdhanSoundRef.file('abcd1234'));
      expect(settings.resolve(const []), const AdhanSoundRef.tone(TanbihTone.chime));
      final muezzin = CustomMuezzin(id: 'abcd1234', name: 'x', fileName: 'abcd1234.mp3', addedAt: now);
      expect(settings.resolve([muezzin]), const AdhanSoundRef.file('abcd1234'));
    });
  });
}
