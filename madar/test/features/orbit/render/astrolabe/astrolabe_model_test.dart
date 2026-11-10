import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/orbit/domain/scene_snapshot.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe.dart';

import 'astrolabe_fixtures.dart';

void main() {
  group('rete model', () {
    final rete = AstrolabePaths.buildRete();

    test('carries every classic star, each pointer tip on its star', () {
      expect(rete.stars.map((s) => s.id).toList(), ReteStarId.values);
      for (final s in rete.stars) {
        expect((s.tip - AstrolabePaths.starPosition(s.id)).distance, lessThan(1e-12));
      }
    });

    test('every star lies between the hub and the Capricorn ring', () {
      for (final id in ReteStarId.values) {
        final r = AstrolabePaths.starPosition(id).distance;
        expect(r, greaterThan(AstrolabeRadii.hubOuter), reason: id.name);
        expect(r, lessThan(AstrolabeRadii.capricorn), reason: id.name);
      }
    });

    test('stars are spread around the whole sky', () {
      final ras = ReteStarId.values.map((s) => s.ra).toList()..sort();
      var widest = 360 - ras.last + ras.first;
      for (var i = 0; i + 1 < ras.length; i++) {
        widest = math.max(widest, ras[i + 1] - ras[i]);
      }
      expect(widest, lessThan(45));
    });

    test('each flame is long enough to read and riveted to the rete', () {
      for (final s in rete.stars) {
        final len = (s.tip - s.base).distance;
        expect(len, greaterThanOrEqualTo(0.1 - 1e-9), reason: s.id.name);
        expect(len, lessThan(0.3), reason: s.id.name);
        expect(s.bend.abs(), 1);
      }
    });

    test('the lattice is a Rub el Hizb with eight woven crossings', () {
      final strands = AstrolabePaths.latticeStrands();
      expect(strands, hasLength(2));
      for (final s in strands) {
        expect(s, hasLength(5));
        expect((s.first - s.last).distance, lessThan(1e-12));
        for (final p in s) {
          expect(p.distance, closeTo(AstrolabeRadii.capricorn - ReteModel.ringWidth * 0.25, 1e-9));
        }
      }
      final crossings = AstrolabePaths.latticeCrossings(strands);
      expect(crossings, hasLength(8));
      for (final c in crossings) {
        expect(c.overDirection.distance, closeTo(1, 1e-9));
      }
    });

    test('the woven over-strand alternates along each square', () {
      final strands = AstrolabePaths.latticeStrands();
      final crossings = AstrolabePaths.latticeCrossings(strands);
      // Walk square A: its direction at each crossing either matches the
      // over direction (A passes over) or not; neighbours must alternate.
      final a = strands.first;
      final along = <(double, bool)>[];
      for (final c in crossings) {
        for (var i = 0; i + 1 < a.length; i++) {
          final d = a[i + 1] - a[i];
          final t = ((c.point - a[i]).dx * d.dx + (c.point - a[i]).dy * d.dy) / (d.dx * d.dx + d.dy * d.dy);
          final foot = a[i] + d * t;
          if (t > 0 && t < 1 && (foot - c.point).distance < 1e-9) {
            final u = d / d.distance;
            along.add((i + t, (u - c.overDirection).distance < 1e-6 || (u + c.overDirection).distance < 1e-6));
          }
        }
      }
      along.sort((x, y) => x.$1.compareTo(y.$1));
      expect(along, hasLength(8));
      for (var i = 0; i + 1 < along.length; i++) {
        expect(along[i].$2, isNot(along[i + 1].$2));
      }
    });

    test('the multifoil ring bulges outward between its cusps', () {
      final ring = AstrolabePaths.lobedRing(0.3, lobes: 16, sagitta: 0.014);
      final radii = ring.map((p) => p.distance).toList();
      expect(radii.reduce(math.min), closeTo(0.3, 1e-9));
      // each lobe rises [sagitta] above its chord
      expect(radii.reduce(math.max), closeTo(0.3 * math.cos(math.pi / 16) + 0.014, 1e-3));
      expect(radii.reduce(math.max), greaterThan(0.3));
    });

    test('anchors keep a minimum pointer length', () {
      final metal = [for (var i = 0; i < 100; i++) Offset(i / 100, 0)];
      final base = AstrolabePaths.anchorFor(const Offset(0.5, 0.02), metal);
      expect((base - const Offset(0.5, 0.02)).distance, greaterThanOrEqualTo(0.1));
      // nothing near: hangs from the hub ring
      final far = AstrolabePaths.anchorFor(const Offset(0, -0.6), const []);
      expect(far.distance, closeTo(ReteModel.innerRing, 1e-9));
    });

    test('flame paths stay near the segment between base and tip', () {
      final path = AstrolabePaths.flamePointer(Offset.zero, const Offset(0, -1), width: 0.1);
      final b = path.getBounds();
      expect(b.top, closeTo(-1, 0.02));
      expect(b.bottom, lessThan(0.06));
      expect(b.width, lessThan(0.5));
      expect(AstrolabePaths.flamePointer(Offset.zero, Offset.zero, width: 1).getBounds().isEmpty, isTrue);
    });

    test('girih covers the plate with segments', () {
      final segs = AstrolabePaths.girihSegments(radius: 0.8, spacing: 0.2);
      expect(segs, isNotEmpty);
      final path = AstrolabePaths.girih(scale: 100, radius: 0.8, spacing: 0.2);
      expect(path.getBounds().width, greaterThan(150));
    });
  });

  group('state and labels', () {
    final ar = AmmanDay.labels('ar');
    final en = AmmanDay.labels('en');

    test('countdown is engraved in the reading language with the digit setting', () {
      expect(en.countdown(Prayer.asr, const Duration(hours: 1, minutes: 23, seconds: 5)), contains('Asr'));
      expect(
        BidiIsolate.strip(en.countdown(Prayer.asr, const Duration(hours: 1, minutes: 23, seconds: 5))),
        'Asr in 1:23:05',
      );
      final arText = BidiIsolate.strip(ar.countdown(Prayer.asr, const Duration(hours: 1, minutes: 23, seconds: 5)));
      expect(arText, 'العصر بعد ١:٢٣:٠٥');
      final western = AmmanDay.labels('ar', digits: DigitStyle.western);
      expect(
        BidiIsolate.strip(western.countdown(Prayer.asr, const Duration(minutes: 3, seconds: 9))),
        'العصر بعد 03:09',
      );
      expect(en.countdown(Prayer.fajr, Duration.zero), isNot(contains('0:00')));
    });

    test('clock format pads minutes and seconds only', () {
      expect(AstrolabeLabels.clockOf(const Duration(hours: 10, minutes: 2, seconds: 3)), '10:02:03');
      expect(AstrolabeLabels.clockOf(const Duration(minutes: 59, seconds: 59)), '59:59');
      expect(AstrolabeLabels.clockOf(const Duration(seconds: -4)), '00:00');
    });

    test('numerals follow the digit setting', () {
      expect(ar.numeral(12), '١٢');
      expect(en.numeral(12), '12');
      expect(AmmanDay.labels('en', digits: DigitStyle.arabicIndic).numeral(24), '٢٤');
    });

    test('every star and zodiac sign has a name in both languages', () {
      for (final s in ReteStarId.values) {
        expect(ar.starName(s), isNotEmpty);
        expect(en.starName(s), isNotEmpty);
        expect(ar.starName(s), isNot(en.starName(s)));
      }
      for (var k = 0; k < 12; k++) {
        expect(ar.zodiacName(k), isNotEmpty);
        expect(en.zodiacName(k), isNotEmpty);
      }
      expect(en.zodiacName(0), 'Aries');
      expect(ar.zodiacName(12), ar.zodiacName(0));
    });

    test('labels compare by language and digits', () {
      expect(AmmanDay.labels('ar'), AmmanDay.labels('ar'));
      expect(AmmanDay.labels('ar'), isNot(AmmanDay.labels('en')));
      expect(AmmanDay.labels('ar'), isNot(AmmanDay.labels('ar', digits: DigitStyle.western)));
    });

    test('state derives statuses, fractions and the countdown', () {
      final s = AmmanDay.state(AmmanDay.at(16, 0), lang: 'en', prayed: {Prayer.dhuhr});
      expect(s.statusOf(Prayer.fajr), AstrolabePrayerStatus.missed);
      expect(s.statusOf(Prayer.dhuhr), AstrolabePrayerStatus.prayed);
      expect(s.statusOf(Prayer.asr), AstrolabePrayerStatus.due);
      expect(s.statusOf(Prayer.maghrib), AstrolabePrayerStatus.upcoming);
      expect(s.prayedCount, 1);
      expect(s.fractions[Prayer.dhuhr], closeTo((12 * 3600 + 27 * 60 + 22) / 86400, 1e-9));
      expect(BidiIsolate.strip(s.countdown), 'Maghrib in 2:31:42');
      expect(s.copyWith(countdownText: 'x').countdown, 'x');
      expect(s.copyWith(missed: {Prayer.asr}).statusOf(Prayer.asr), AstrolabePrayerStatus.missed);
    });

    test('from the offline schedule, before Fajr the day is still yesterday', () {
      final schedule = PrayerSchedule(const PrayerSettings());
      // an hour before Fajr in whatever time zone the tests run in
      final early = schedule.timesFor(DateTime(2026, 9, 28, 12)).fajr.subtract(const Duration(hours: 1));
      final s = AstrolabeState.fromSchedule(schedule: schedule, now: early, labels: en);
      expect(s.times.day, DateTime(2026, 9, 27));
      expect(s.window.window, PrayerWindow.isha);
      expect(s.statusOf(Prayer.isha), AstrolabePrayerStatus.due);
      expect(s.sky.sunFraction, closeTo(PrayerSchedule.dialFraction(early), 1e-12));
    });

    test('from the scene snapshot: logged prayers light, missed ones dim', () {
      const settings = PrayerSettings();
      final schedule = PrayerSchedule(settings);
      final now = schedule.timesFor(DateTime(2026, 9, 27, 12)).asr.add(const Duration(minutes: 30));
      final prayer = PrayerState(
        settings: settings,
        times: schedule.timesFor(now),
        window: schedule.windowAt(now),
        prayerDay: DateTime(now.year, now.month, now.day),
        logged: const {
          Prayer.fajr: PrayerStatus.late,
          Prayer.dhuhr: PrayerStatus.missed,
          Prayer.asr: PrayerStatus.prayed,
        },
      );
      final s = AstrolabeState.fromPrayerState(prayer, now: now, labels: ar, balance: 0.6);
      expect(s.prayed, {Prayer.fajr, Prayer.asr});
      expect(s.statusOf(Prayer.dhuhr), AstrolabePrayerStatus.missed);
      expect(s.statusOf(Prayer.maghrib), AstrolabePrayerStatus.upcoming);
      expect(s.balance, 0.6);
      expect(s.window.nextPrayer, Prayer.maghrib);
    });

    test('sky equality and derived rotations', () {
      final a = AmmanDay.skyAt(AmmanDay.at(9, 0));
      final b = AmmanDay.skyAt(AmmanDay.at(9, 0));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.plateRotation.abs(), lessThan(0.2));
      expect(AstrolabeSky.at(DateTime(2026, 9, 27, 9)).sunFraction, closeTo(0.375, 1e-9));
    });
  });

  group('palette', () {
    test('comes from the theme tokens and compares by value', () {
      final a = AstrolabePalette.fromTokens(MadarPalettes.tokensFor(MadarThemeId.lapis));
      final b = AstrolabePalette.fromTokens(MadarPalettes.tokensFor(MadarThemeId.lapis));
      final pearl = AstrolabePalette.fromTokens(MadarPalettes.tokensFor(MadarThemeId.pearl));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(pearl));
      expect(pearl.light, isTrue);
      expect(a.light, isFalse);
      expect(a.withMetal(brass: const Color(0xFF000000)), isNot(a));
      expect(a.withMetal(), a);
    });
  });
}
