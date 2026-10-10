import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/astro/astronomy.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/orbit/render/sky/sky.dart';

import 'sky_fixtures.dart';

double _lum(Color c) => OkLab.fromColor(c).l;

double _delta(Color a, Color b) {
  final x = OkLab.fromColor(a), y = OkLab.fromColor(b);
  return math.sqrt(math.pow(x.l - y.l, 2) + math.pow(x.a - y.a, 2) + math.pow(x.b - y.b, 2));
}

void main() {
  group('Qibla', () {
    test('great-circle bearings match published qibla directions', () {
      expect(Qibla.bearingDeg(31.9539, 35.9106), closeTo(160.7, 0.3)); // Amman
      expect(Qibla.bearingDeg(51.5074, -0.1278), closeTo(119.0, 0.5)); // London
      expect(Qibla.bearingDeg(40.7128, -74.0060), closeTo(58.5, 0.5)); // New York
      expect(Qibla.bearingDeg(-6.2088, 106.8456), closeTo(295.1, 0.5)); // Jakarta
      expect(Qibla.bearingDeg(24.4672, 39.6111), closeTo(175.8, 1.5)); // Madinah
    });

    test('observer follows the prayer location and exposes the qibla', () {
      expect(SkyObserver.fromPrayerSettings(const PrayerSettings()), SkyObserver.amman);
      expect(
        SkyObserver.fromPrayerSettings(const PrayerSettings(latitude: 30.0444, longitude: 31.2357)).qiblaAzimuth,
        closeTo(136.1, 0.5),
      ); // Cairo
      expect(SkyObserver.amman.qiblaAzimuth, closeTo(160.7, 0.3));
      expect(const SkyObserver(latitude: 1, longitude: 2), const SkyObserver(latitude: 1, longitude: 2));
    });
  });

  group('SkyModel.compute at the reference instants (Amman, UTC+3)', () {
    final tone = testTone();

    test('Fajr 05:35 is dawn twilight with a full moon behind the view', () {
      final s = SkyModel.compute(SkyShot.fajr.time, tone: tone);
      expect(s.sun.altitude, inInclusiveRange(-13, -11));
      expect(s.mood, SkyMood.dawn);
      expect(s.morning, greaterThan(0.95));
      expect(s.night, inInclusiveRange(0.5, 0.95));
      expect(s.starGain, greaterThan(0.9));
    });

    test('12:30 is a clear day without stars', () {
      final s = SkyModel.compute(SkyShot.noon.time, tone: tone);
      expect(s.phase, SkyPhase.day);
      expect(s.mood, SkyMood.day);
      expect(s.daylight, 1);
      expect(s.starGain, 0);
      expect(s.milkyWay, 0);
    });

    test('17:55 is golden hour, 18:40 the Maghrib glow', () {
      final g = SkyModel.compute(SkyShot.golden.time, tone: tone);
      expect(g.sun.altitude, inInclusiveRange(4, 8));
      expect(g.mood, SkyMood.goldenHour);
      expect(g.morning, lessThan(0.05));
      final m = SkyModel.compute(SkyShot.maghrib.time, tone: tone);
      expect(m.sun.altitude, inInclusiveRange(-5, -2));
      expect(m.mood, SkyMood.dusk);
    });

    test('22:30 is night under a nearly full moon; 10 Oct 22:00 is moonless', () {
      final n = SkyModel.compute(SkyShot.night.time, tone: tone);
      expect(n.mood, SkyMood.night);
      expect(n.moonUp, isTrue);
      expect(n.moonIllumination, greaterThan(0.95));
      expect(n.moonPhaseName, anyOf(MoonPhaseName.full, MoonPhaseName.waningGibbous));
      expect(n.moonlight, greaterThan(0.9));
      final d = SkyModel.compute(SkyShot.newMoon.time, tone: tone);
      expect(d.moonIllumination, lessThan(0.02));
      expect(d.moonPhaseName, MoonPhaseName.newMoon);
      expect(d.moonlight, 0);
      // Moonlight washes out the faintest stars (a full-moon night still
      // shows the bright ones) and the Milky Way.
      expect(d.starLimit, greaterThan(n.starLimit + 0.5));
      expect(n.starLimit, greaterThanOrEqualTo(4.5));
      expect(d.starLimit, greaterThanOrEqualTo(5.2));
      expect(d.milkyWay, greaterThan(n.milkyWay * 3));
    });

    test('directions are unit vectors and match Astro', () {
      final s = SkyModel.compute(SkyShot.night.time, tone: tone);
      for (final v in [s.sunDir, s.moonDir, s.galacticPole, s.galacticCenter]) {
        expect(v.length, closeTo(1, 1e-9));
      }
      final (alt, az) = SkyModel.altAz(s.moonDir);
      expect(alt, closeTo(s.moon.altitude, 1e-6));
      expect(az, closeTo(s.moon.azimuth, 1e-6));
      // The galactic pole and centre are 90° apart.
      expect(s.galacticPole.dot(s.galacticCenter), closeTo(0, 1e-3));
    });
  });

  group('palette', () {
    final dark = testTone();
    final light = testTone(dark: false);

    test('is continuous in sun altitude (no pops between keyframes)', () {
      for (final tone in [dark, light]) {
        for (final morning in [0.0, 1.0]) {
          SkyPalette? prev;
          for (var alt = -40.0; alt <= 70; alt += 0.25) {
            final p = SkyModel.paletteFor(alt, tone, morning: morning);
            if (prev != null) {
              expect(_delta(prev.zenith, p.zenith), lessThan(0.02), reason: 'zenith at $alt');
              expect(_delta(prev.horizon, p.horizon), lessThan(0.03), reason: 'horizon at $alt');
            }
            prev = p;
          }
        }
      }
    });

    test('dawn and dusk agree at night and by day', () {
      for (final alt in [-40.0, -20.0, 20.0, 60.0]) {
        final a = SkyModel.paletteFor(alt, dark, morning: 1);
        final b = SkyModel.paletteFor(alt, dark, morning: 0);
        expect(_delta(a.zenith, b.zenith), lessThan(1e-6));
        expect(_delta(a.horizon, b.horizon), lessThan(1e-6));
      }
    });

    test('the sky brightens from night to day and the day zenith is blue', () {
      final night = SkyModel.paletteFor(-30, dark);
      final day = SkyModel.paletteFor(45, dark);
      expect(_lum(day.zenith), greaterThan(_lum(night.zenith) + 0.2));
      final z = OkLab.fromColor(day.zenith);
      expect(z.b, lessThan(-0.1));
      // Dark themes stay deep: never a pale, washed-out zenith.
      expect(z.l, lessThan(0.5));
    });

    test('dusk is fierier than dawn; golden hour is warm', () {
      final dusk = OkLab.fromColor(SkyModel.paletteFor(-4, dark, morning: 0).horizon);
      final dawn = OkLab.fromColor(SkyModel.paletteFor(-4, dark, morning: 1).horizon);
      expect(dusk.a, greaterThan(dawn.a));
      final golden = OkLab.fromColor(SkyModel.paletteFor(5, dark, morning: 0).horizon);
      expect(golden.b, greaterThan(0.08)); // yellow-orange
      // True dawn (Fajr) is a cool band, not a red one.
      final fajr = OkLab.fromColor(SkyModel.paletteFor(-11, dark, morning: 1).horizon);
      expect(fajr.b, lessThan(0));
    });

    test('Pearl is luminous by day, an indigo-slate night – always lighter than the dark sky', () {
      for (var alt = -60.0; alt <= 60; alt += 5) {
        final p = SkyModel.paletteFor(alt, light);
        final d = SkyModel.paletteFor(alt, dark);
        expect(_lum(p.zenith), greaterThan(_lum(d.zenith)), reason: 'zenith at $alt');
        expect(_lum(p.horizon), greaterThanOrEqualTo(_lum(d.horizon) - 0.02), reason: 'horizon at $alt');
        if (alt >= 0) {
          expect(_lum(p.horizon), greaterThan(0.62), reason: 'horizon at $alt');
          expect(_lum(p.ground), greaterThan(0.6), reason: 'ground at $alt');
        }
      }
      // Night reads as night: a deep indigo-slate, bluish, not lavender.
      final night = SkyModel.paletteFor(-30, light);
      expect(_lum(night.zenith), lessThan(0.3));
      final ink = OkLab.fromColor(night.zenith);
      expect(ink.b, lessThan(-0.03), reason: 'blue, not grey');
      expect(ink.a.abs(), lessThan(ink.b.abs()), reason: 'indigo, not lavender');
    });

    test('harmonises with the theme at night but keeps the lightness', () {
      final lapis = SkyTone.fromTokens(MadarPalettes.tokensFor(MadarThemeId.lapis));
      final emerald = SkyTone.fromTokens(MadarPalettes.tokensFor(MadarThemeId.emerald));
      final l = OkLab.fromColor(SkyModel.paletteFor(-30, lapis).zenith);
      final e = OkLab.fromColor(SkyModel.paletteFor(-30, emerald).zenith);
      expect(e.a, lessThan(l.a)); // greener
      expect(e.l, closeTo(l.l, 0.02));
      // By day the themes differ only slightly.
      final ld = SkyModel.paletteFor(40, lapis).zenith, ed = SkyModel.paletteFor(40, emerald).zenith;
      final ln = SkyModel.paletteFor(-30, lapis).zenith, en = SkyModel.paletteFor(-30, emerald).zenith;
      expect(_delta(ld, ed), lessThan(_delta(ln, en)));
    });

    test('moonlight lifts the night sky', () {
      final a = SkyModel.paletteFor(-40, dark);
      final b = SkyModel.paletteFor(-40, dark, moonlight: 1);
      expect(_lum(b.zenith), greaterThan(_lum(a.zenith)));
      expect(_lum(b.horizon), greaterThan(_lum(a.horizon)));
    });
  });

  group('factors', () {
    test('night and daylight are monotonic and bounded', () {
      var pn = 2.0, pd = -1.0;
      for (var alt = -30.0; alt <= 30; alt += 0.5) {
        final n = SkyModel.nightFactor(alt), d = SkyModel.daylightFactor(alt);
        expect(n, inInclusiveRange(0, 1));
        expect(d, inInclusiveRange(0, 1));
        expect(n, lessThanOrEqualTo(pn));
        expect(d, greaterThanOrEqualTo(pd));
        pn = n;
        pd = d;
      }
    });

    test('moon phase names cover the synodic month', () {
      expect(MoonPhaseName.of(0), MoonPhaseName.newMoon);
      expect(MoonPhaseName.of(0.98), MoonPhaseName.newMoon);
      expect(MoonPhaseName.of(0.25), MoonPhaseName.firstQuarter);
      expect(MoonPhaseName.of(0.5), MoonPhaseName.full);
      expect(MoonPhaseName.of(0.75), MoonPhaseName.lastQuarter);
      expect(MoonPhaseName.of(0.1), MoonPhaseName.waxingCrescent);
      expect(MoonPhaseName.of(0.9), MoonPhaseName.waningCrescent);
    });

    test('mood follows the sun through a whole day', () {
      final seen = <SkyMood>{};
      for (var m = 0; m < 24 * 60; m += 5) {
        seen.add(SkyModel.compute(DateTime.utc(2026, 9, 26, 21).add(Duration(minutes: m)), tone: testTone()).mood);
      }
      expect(seen, containsAll(SkyMood.values));
    });
  });

  group('SkyColors', () {
    test('OKLab round-trips sRGB', () {
      for (final c in const [Color(0xFF123456), Color(0xFFF2B460), Color(0xFF03050F), Color(0xFFFFFFFF)]) {
        final back = OkLab.fromColor(c).toColor();
        expect((back.r - c.r).abs(), lessThan(0.003));
        expect((back.g - c.g).abs(), lessThan(0.003));
        expect((back.b - c.b).abs(), lessThan(0.003));
      }
    });

    test('shader encoding reproduces display colours up to the ceiling', () {
      for (var d = 0.0; d <= SkyColors.encodeCeiling; d += 0.02) {
        expect(SkyColors.decodeChannel(SkyColors.encodeChannel(d)), closeTo(d, 0.004), reason: 'channel $d');
      }
      // Above it, brightness still rises (monotonic) but gently.
      expect(SkyColors.encodeChannel(0.95), greaterThan(SkyColors.encodeChannel(0.86)));
      expect(SkyColors.acesInverse(SkyColors.aces(0.4)), closeTo(0.4, 1e-9));
    });

    test('harmonize keeps lightness and moves hue', () {
      const blue = Color(0xFF1C3E80), green = Color(0xFF0F6B4E);
      final h = SkyColors.harmonize(blue, green, 0.5);
      expect(OkLab.fromColor(h).l, closeTo(OkLab.fromColor(blue).l, 0.01));
      expect(OkLab.fromColor(h).a, lessThan(OkLab.fromColor(blue).a));
      expect(SkyColors.harmonize(blue, green, 0), blue);
    });
  });

  group('SkyFlares', () {
    test('core flare rises with motion and pulse, falls with elevation and zoom', () {
      final rest = SkyFlares.coreIntensity(elevation: 0.36);
      expect(rest, inInclusiveRange(0.15, 0.4));
      expect(SkyFlares.coreIntensity(elevation: 0.36, angularSpeed: 1), greaterThan(rest));
      expect(SkyFlares.coreIntensity(elevation: 0.36, pulse: 1), greaterThan(rest));
      expect(SkyFlares.coreIntensity(elevation: 0.9), lessThan(rest));
      expect(SkyFlares.coreIntensity(elevation: 0.36, zoom: 1), lessThan(rest));
      expect(SkyFlares.coreIntensity(elevation: 0.36, dark: false), lessThan(rest));
      expect(SkyFlares.coreIntensity(elevation: 0, angularSpeed: 9, pulse: 1), lessThanOrEqualTo(1));
    });

    test('sun flare only while the sun is up and near the view', () {
      const size = Size(400, 900);
      expect(SkyFlares.sunIntensity(sunAltitude: -5, sunScreen: const Offset(200, 300), viewport: size), 0);
      expect(SkyFlares.sunIntensity(sunAltitude: 5, sunScreen: null, viewport: size), 0);
      expect(SkyFlares.sunIntensity(sunAltitude: 5, sunScreen: const Offset(2000, 300), viewport: size), 0);
      final low = SkyFlares.sunIntensity(sunAltitude: 5, sunScreen: const Offset(200, 300), viewport: size);
      final high = SkyFlares.sunIntensity(sunAltitude: 60, sunScreen: const Offset(200, 300), viewport: size);
      expect(low, greaterThan(high));
      expect(high, greaterThan(0));
      expect(SkyFlares.withinReach(const Offset(-50, 10), size), isTrue);
      expect(SkyFlares.withinReach(const Offset(-120, 10), size), isFalse);
    });
  });
}
