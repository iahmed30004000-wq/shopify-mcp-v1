// «الإقامة» planned: the five offsets and Friday's own, each prayer's
// switch, the adhan that carries it, and the hard rule that no iqama is
// ever armed past the next adhan – in Amman, across a daylight-saving
// change.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/adhan/domain/adhan_settings.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/iqama/domain/iqama_plan.dart';
import 'package:madar/features/iqama/domain/iqama_settings.dart';
import 'package:timezone/timezone.dart' as tz;

import '../adhan/adhan_fixtures.dart';

void main() {
  late tz.Location amman;
  setUpAll(() => amman = zone('Asia/Amman'));

  const planner = IqamaPlanner();

  List<IqamaAlarm> plan({
    IqamaSettings settings = const IqamaSettings(),
    AdhanSettings adhan = const AdhanSettings(),
    required DateTime now,
    Map<AdhanSlot, (int, int)>? at,
  }) => planner.plan(
    settings: settings,
    adhan: adhan,
    now: now,
    timesFor: wallClockTimes(amman, at: at),
    localDayOf: localDayIn(amman),
  );

  IqamaAlarm? firstOf(List<IqamaAlarm> alarms, AdhanSlot slot) =>
      alarms.where((a) => a.slot == slot).firstOrNull;

  group('the minute', () {
    test('every prayer is called fifteen minutes after its adhan by default', () {
      final now = wall(amman, 2026, 9, 28, 0, 30);
      final alarms = plan(now: now);
      // Fajr 04:50, Dhuhr 12:30, Asr 15:50, Maghrib 18:30, Isha 19:50.
      expect(firstOf(alarms, AdhanSlot.fajr)!.at, wall(amman, 2026, 9, 28, 5, 5));
      expect(firstOf(alarms, AdhanSlot.dhuhr)!.at, wall(amman, 2026, 9, 28, 12, 45));
      expect(firstOf(alarms, AdhanSlot.asr)!.at, wall(amman, 2026, 9, 28, 16, 5));
      expect(firstOf(alarms, AdhanSlot.maghrib)!.at, wall(amman, 2026, 9, 28, 18, 45));
      expect(firstOf(alarms, AdhanSlot.isha)!.at, wall(amman, 2026, 9, 28, 20, 5));
      for (final a in alarms) {
        expect(a.minutes, 15);
        expect(a.at.difference(a.prayerAt), const Duration(minutes: 15));
      }
    });

    test('each prayer keeps its own offset', () {
      final settings = const IqamaSettings()
          .withPrayer(AdhanSlot.fajr, const IqamaPrayer(minutes: 25))
          .withPrayer(AdhanSlot.maghrib, const IqamaPrayer(minutes: 5));
      final alarms = plan(settings: settings, now: wall(amman, 2026, 9, 28, 0, 30));
      expect(firstOf(alarms, AdhanSlot.fajr)!.at, wall(amman, 2026, 9, 28, 5, 15));
      expect(firstOf(alarms, AdhanSlot.maghrib)!.at, wall(amman, 2026, 9, 28, 18, 35));
      expect(firstOf(alarms, AdhanSlot.asr)!.minutes, 15, reason: 'the others are untouched');
    });

    test('an offset of zero calls with the adhan itself, and is still planned', () {
      final settings = const IqamaSettings().withPrayer(AdhanSlot.asr, const IqamaPrayer(minutes: 0));
      final asr = firstOf(plan(settings: settings, now: wall(amman, 2026, 9, 28, 0, 30)), AdhanSlot.asr)!;
      expect(asr.at, wall(amman, 2026, 9, 28, 15, 50));
      expect(asr.minutes, 0);
    });
  });

  group('Friday', () {
    test('Friday\'s Dhuhr takes its own offset; the other days keep theirs', () {
      // 2 Oct 2026 is a Friday.
      expect(DateTime.utc(2026, 10, 2).weekday, DateTime.friday);
      final settings = const IqamaSettings(jumuah: IqamaPrayer(minutes: 35))
          .withPrayer(AdhanSlot.dhuhr, const IqamaPrayer(minutes: 10));
      final alarms = plan(settings: settings, now: wall(amman, 2026, 10, 1, 0, 30));
      final dhuhrs = alarms.where((a) => a.slot == AdhanSlot.dhuhr).toList();
      final thursday = dhuhrs.firstWhere((a) => a.day == DateTime.utc(2026, 10, 1));
      final friday = dhuhrs.firstWhere((a) => a.day == DateTime.utc(2026, 10, 2));
      expect(thursday.at, wall(amman, 2026, 10, 1, 12, 40));
      expect(thursday.jumuah, isFalse);
      expect(friday.at, wall(amman, 2026, 10, 2, 13, 5));
      expect(friday.jumuah, isTrue);
    });

    test('Friday\'s own switch can be off while the other days\' Dhuhr is on', () {
      final settings = const IqamaSettings(jumuah: IqamaPrayer(on: false));
      final alarms = plan(settings: settings, now: wall(amman, 2026, 10, 1, 0, 30));
      final dhuhrs = alarms.where((a) => a.slot == AdhanSlot.dhuhr).map((a) => a.day).toList();
      expect(dhuhrs, contains(DateTime.utc(2026, 10, 1)));
      expect(dhuhrs, isNot(contains(DateTime.utc(2026, 10, 2))), reason: 'Friday is off');
    });
  });

  group('switches', () {
    test('one prayer\'s iqama off while its adhan stays on', () {
      final settings = const IqamaSettings().withPrayer(AdhanSlot.asr, const IqamaPrayer(on: false));
      final alarms = plan(settings: settings, now: wall(amman, 2026, 9, 28, 0, 30));
      expect(alarms.where((a) => a.slot == AdhanSlot.asr), isEmpty);
      expect(alarms.where((a) => a.slot == AdhanSlot.dhuhr), isNotEmpty);
      // …and the adhan itself is untouched: the adhan settings say nothing
      // about the iqama.
      expect(const AdhanSettings().alertOf(AdhanSlot.asr).adhan, isTrue);
    });

    test('a prayer whose adhan is off gets no iqama either', () {
      final adhan = const AdhanSettings().withAlert(AdhanSlot.fajr, const PrayerAlert(adhan: false));
      final alarms = plan(adhan: adhan, now: wall(amman, 2026, 9, 28, 0, 30));
      expect(alarms.where((a) => a.slot == AdhanSlot.fajr), isEmpty);
      expect(alarms.where((a) => a.slot == AdhanSlot.isha), isNotEmpty);
    });

    test('nothing at all when every iqama is off', () {
      var settings = const IqamaSettings(jumuah: IqamaPrayer(on: false));
      for (final slot in AdhanSlot.prayers) {
        settings = settings.withPrayer(slot, const IqamaPrayer(on: false));
      }
      expect(settings.anyEnabled, isFalse);
      expect(plan(settings: settings, now: wall(amman, 2026, 9, 28, 0, 30)), isEmpty);
    });
  });

  group('never past the next adhan', () {
    test('a long offset that would land after the next prayer is dropped, not moved', () {
      // Maghrib 18:30, Isha 19:50 – eighty minutes apart.
      final settings = const IqamaSettings().withPrayer(AdhanSlot.maghrib, const IqamaPrayer(minutes: 90));
      final alarms = plan(settings: settings, now: wall(amman, 2026, 9, 28, 0, 30));
      expect(alarms.where((a) => a.slot == AdhanSlot.maghrib), isEmpty);
      expect(alarms.where((a) => a.slot == AdhanSlot.isha), isNotEmpty, reason: 'the others still stand');
    });

    test('Maghrib to Isha in a short winter window: the default fifteen still fits, forty-five does not', () {
      // A winter evening in Amman: Maghrib 16:45, Isha 18:05 (80 min), and
      // a tighter pair for the drop.
      const winter = {
        AdhanSlot.fajr: (5, 10),
        AdhanSlot.sunrise: (6, 40),
        AdhanSlot.dhuhr: (11, 40),
        AdhanSlot.asr: (14, 25),
        AdhanSlot.maghrib: (16, 45),
        AdhanSlot.isha: (17, 15),
      };
      final fits = plan(now: wall(amman, 2026, 12, 20, 0, 30), at: winter);
      expect(firstOf(fits, AdhanSlot.maghrib)!.at, wall(amman, 2026, 12, 20, 17, 0));
      final dropped = plan(
        settings: const IqamaSettings().withPrayer(AdhanSlot.maghrib, const IqamaPrayer(minutes: 45)),
        now: wall(amman, 2026, 12, 20, 0, 30),
        at: winter,
      );
      expect(dropped.where((a) => a.slot == AdhanSlot.maghrib), isEmpty);
    });

    test('Isha is bounded by the next day\'s Fajr', () {
      final alarms = plan(now: wall(amman, 2026, 9, 28, 0, 30));
      final isha = firstOf(alarms, AdhanSlot.isha)!;
      expect(isha.nextAdhanAt, wall(amman, 2026, 9, 29, 4, 50));
      expect(isha.at.isBefore(isha.nextAdhanAt!), isTrue);
    });

    test('every planned iqama carries the next adhan, so the snooze is bounded too', () {
      for (final a in plan(now: wall(amman, 2026, 9, 28, 0, 30))) {
        expect(a.nextAdhanAt, isNotNull, reason: '${a.slot.name} has no bound');
        expect(a.at.isBefore(a.nextAdhanAt!), isTrue);
      }
    });
  });

  group('the clock', () {
    test('nothing in the past, and the week ahead is covered', () {
      final now = wall(amman, 2026, 9, 28, 13, 0);
      final alarms = plan(now: now);
      expect(alarms.every((a) => a.at.isAfter(now)), isTrue);
      expect(alarms.first.at, wall(amman, 2026, 9, 28, 16, 5), reason: 'Asr is the next one after 13:00');
      expect(alarms.length, greaterThan(30), reason: 'eight days of five prayers');
      expect(alarms.last.at.isBefore(now.add(const Duration(days: 8, minutes: 1))), isTrue);
    });

    test('the end of summer time in Amman moves the clock face, not the offset', () {
      // Amman leaves DST overnight on 30/31 Oct 2026.
      final alarms = plan(now: wall(amman, 2026, 10, 29, 0, 30));
      for (final a in alarms) {
        expect(a.at.difference(a.prayerAt), const Duration(minutes: 15), reason: '$a');
        final local = tz.TZDateTime.from(a.at, amman);
        final prayer = tz.TZDateTime.from(a.prayerAt, amman);
        expect(local.minute, (prayer.minute + 15) % 60, reason: 'the wall clock reads +15 either side of the change');
      }
      // The two Dhuhrs across the change are 24 hours apart on the clock,
      // 25 in real time.
      final dhuhrs = alarms.where((a) => a.slot == AdhanSlot.dhuhr).toList();
      final before = dhuhrs.firstWhere((a) => a.day == DateTime.utc(2026, 10, 30));
      final after = dhuhrs.firstWhere((a) => a.day == DateTime.utc(2026, 10, 31));
      expect(tz.TZDateTime.from(before.at, amman).hour, tz.TZDateTime.from(after.at, amman).hour);
    });

    test('ids: the same prayer on the same day keeps its id, and they never leave the block', () {
      final a = plan(now: wall(amman, 2026, 9, 28, 0, 30));
      final b = plan(now: wall(amman, 2026, 9, 28, 1, 30));
      final byKey = {for (final x in a) '${x.day}/${x.slot.name}': x.id};
      for (final x in b) {
        final id = byKey['${x.day}/${x.slot.name}'];
        if (id != null) expect(x.id, id);
        expect(IqamaIds.namespace.contains(x.id), isTrue);
        expect(IqamaIds.isOneOff(x.id), isFalse, reason: 'a planned id must not collide with the snooze');
      }
      expect(a.map((x) => x.id).toSet().length, a.length, reason: 'no two alarms share an id');
    });
  });
}
