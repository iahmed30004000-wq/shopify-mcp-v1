import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../../../../core/astro/astronomy.dart';
import '../../../../core/design/tokens.dart';
import '../../domain/prayer_schedule.dart';
import '../../domain/scene_math.dart';
import 'sky_colors.dart';

/// Where on Earth the sky is seen from (degrees, east/north positive).
@immutable
class SkyObserver {
  const SkyObserver({required this.latitude, required this.longitude});

  /// The app's default location (Amman), matching `PrayerSettings`.
  static const amman = SkyObserver(latitude: 31.9539, longitude: 35.9106);

  /// The user's prayer location (GPS or chosen city).
  factory SkyObserver.fromPrayerSettings(PrayerSettings s) => SkyObserver(latitude: s.latitude, longitude: s.longitude);

  final double latitude;
  final double longitude;

  /// Great-circle bearing of the Kaaba from here.
  double get qiblaAzimuth => Qibla.bearingDeg(latitude, longitude);

  @override
  bool operator ==(Object other) => other is SkyObserver && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Direction of prayer.
abstract final class Qibla {
  static const kaabaLatitude = 21.422487;
  static const kaabaLongitude = 39.826206;

  /// Initial great-circle bearing (degrees from north, clockwise) from
  /// ([latitude], [longitude]) to the Kaaba.
  static double bearingDeg(double latitude, double longitude) {
    const d = math.pi / 180;
    final p1 = latitude * d, p2 = kaabaLatitude * d;
    final dl = (kaabaLongitude - longitude) * d;
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
    final b = math.atan2(y, x) / d;
    return (b % 360 + 360) % 360;
  }
}

/// The theme inputs of the sky (from [MadarTokens]): the sky's time-of-day
/// palette is harmonised toward these so it belongs to the active theme.
@immutable
class SkyTone {
  const SkyTone({
    required this.dark,
    required this.space0,
    required this.space1,
    required this.nebulaA,
    required this.nebulaB,
    required this.starTint,
    required this.gold,
    required this.engrave,
    required this.engraveShadow,
  });

  factory SkyTone.fromTokens(MadarTokens t) => SkyTone(
    dark: t.isDark,
    space0: t.space0,
    space1: t.space1,
    nebulaA: t.nebulaA,
    nebulaB: t.nebulaB,
    starTint: t.starTint,
    gold: t.gold,
    // Engraved silver for star names: the theme's secondary text in dark
    // themes (warmed by the star tint); on Pearl (names show only on its
    // indigo-slate night) a pearl ink over the theme's own dark ink.
    engrave: t.isDark ? Color.lerp(t.textSecondary, t.starTint, 0.35)! : Color.lerp(t.space1, t.nebulaB, 0.35)!,
    engraveShadow: t.isDark ? t.space0 : t.textPrimary,
  );

  /// Whether the theme is dark (deep, rich sky) or light (luminous pearl).
  final bool dark;
  final Color space0, space1, nebulaA, nebulaB, starTint, gold;

  /// Star-name label colour and its engraving shadow.
  final Color engrave, engraveShadow;

  @override
  bool operator ==(Object other) =>
      other is SkyTone &&
      other.dark == dark &&
      other.space0 == space0 &&
      other.space1 == space1 &&
      other.nebulaA == nebulaA &&
      other.nebulaB == nebulaB &&
      other.starTint == starTint &&
      other.gold == gold &&
      other.engrave == engrave &&
      other.engraveShadow == engraveShadow;

  @override
  int get hashCode => Object.hash(dark, space0, space1, nebulaA, nebulaB, starTint, gold, engrave, engraveShadow);
}

/// One sky look at a sun altitude (display sRGB colours).
@immutable
class SkyKeyframe {
  const SkyKeyframe(this.altitude, this.zenith, this.horizon, this.glow, this.glowIntensity);

  final double altitude;
  final Color zenith, horizon, glow;
  final double glowIntensity;
}

/// The sky's colours at one instant (display sRGB).
@immutable
class SkyPalette {
  const SkyPalette({
    required this.zenith,
    required this.horizon,
    required this.glow,
    required this.glowIntensity,
    required this.nebula,
    required this.ground,
  });

  final Color zenith, horizon, glow;

  /// Below the horizon: the horizon haze sinking into the theme's own
  /// depth, so whatever sits low on the screen (the glass panel) matches
  /// the UI.
  final Color ground;

  /// Strength of the sun's glow / twilight arch.
  final double glowIntensity;

  /// Tint of the Milky Way (from the theme).
  final Color nebula;

  @override
  bool operator ==(Object other) =>
      other is SkyPalette &&
      other.zenith == zenith &&
      other.horizon == horizon &&
      other.glow == glow &&
      other.glowIntensity == glowIntensity &&
      other.nebula == nebula &&
      other.ground == ground;

  @override
  int get hashCode => Object.hash(zenith, horizon, glow, glowIntensity, nebula, ground);
}

/// Spoken moon phase (eight classic names).
enum MoonPhaseName {
  newMoon,
  waxingCrescent,
  firstQuarter,
  waxingGibbous,
  full,
  waningGibbous,
  lastQuarter,
  waningCrescent;

  /// From the synodic phase 0..1 (0 new, 0.5 full).
  static MoonPhaseName of(double phase) {
    final p = phase % 1.0;
    final i = ((p < 0 ? p + 1 : p) * 8 + 0.5).floor() % 8;
    return MoonPhaseName.values[i];
  }
}

/// Spoken look of the sky.
enum SkyMood { night, dawn, sunrise, day, goldenHour, sunset, dusk }

/// Everything the sky shows at one instant for one observer and theme.
/// Directions are unit vectors in the local ENU frame (x east, y north,
/// z up).
@immutable
class SkyState {
  const SkyState({
    required this.time,
    required this.observer,
    required this.sun,
    required this.moon,
    required this.sunDir,
    required this.moonDir,
    required this.galacticPole,
    required this.galacticCenter,
    required this.localSiderealDeg,
    required this.night,
    required this.daylight,
    required this.moonlight,
    required this.milkyWay,
    required this.starLimit,
    required this.starGain,
    required this.morning,
    required this.palette,
    required this.qiblaAzimuth,
    required this.dark,
  });

  final DateTime time;
  final SkyObserver observer;
  final SunState sun;
  final MoonState moon;
  final V3 sunDir, moonDir, galacticPole, galacticCenter;

  /// Local sidereal time (degrees) – rotates the star catalogue.
  final double localSiderealDeg;

  /// 0 (sun above -3°) … 1 (sun below -15°).
  final double night;

  /// 0 (sun below -4°) … 1 (sun above 10°).
  final double daylight;

  /// How much the moon brightens the night sky (0..1).
  final double moonlight;

  /// Milky Way strength fed to sky.frag (its `uNight`).
  final double milkyWay;

  /// Faintest visible star magnitude (catalogue goes to 5.2).
  final double starLimit;

  /// Overall star visibility 0..1.
  final double starGain;

  /// 0..1: how much the twilight looks like dawn (1) rather than dusk (0).
  final double morning;

  final SkyPalette palette;
  final double qiblaAzimuth;
  final bool dark;

  SkyPhase get phase => sun.skyPhase;

  /// Illuminated fraction of the moon 0..1.
  double get moonIllumination => moon.illumination;

  /// Moon phase angle i (radians): 0 full, π new (from the illumination).
  double get moonPhaseAngle => math.acos((2 * moon.illumination - 1).clamp(-1.0, 1.0));

  MoonPhaseName get moonPhaseName => MoonPhaseName.of(moon.phase);

  bool get moonUp => moon.altitude > -0.5;

  SkyMood get mood {
    final alt = sun.altitude;
    final am = morning >= 0.5;
    if (alt < -15) return SkyMood.night;
    if (alt < -3) return am ? SkyMood.dawn : SkyMood.dusk;
    if (alt < 1.5) return am ? SkyMood.sunrise : SkyMood.sunset;
    if (alt < 9) return am ? SkyMood.sunrise : SkyMood.goldenHour;
    return SkyMood.day;
  }
}

/// Real-time sky model: from an instant, a location and the theme to the
/// sun, moon, Milky Way, star visibility and a palette keyed on the sun's
/// altitude (night → astronomical / nautical / civil twilight → golden hour
/// → day), with separate dawn and dusk looks and a moonlit lift at night.
abstract final class SkyModel {
  /// North galactic pole and galactic centre (J2000).
  static const galacticPoleRaDec = (192.85948, 27.12825);
  static const galacticCenterRaDec = (266.40499, -28.93617);

  /// Unit ENU vector for an altitude/azimuth in degrees.
  static V3 enu(double altitudeDeg, double azimuthDeg) {
    final a = altitudeDeg * Astro.deg, z = azimuthDeg * Astro.deg;
    final c = math.cos(a);
    return V3(c * math.sin(z), c * math.cos(z), math.sin(a));
  }

  /// Altitude / azimuth (degrees) of an ENU unit vector.
  static (double, double) altAz(V3 v) {
    final alt = math.asin(v.z.clamp(-1.0, 1.0)) * Astro.rad;
    final az = math.atan2(v.x, v.y) * Astro.rad;
    return (alt, (az % 360 + 360) % 360);
  }

  static double smoothstep(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// 0 when the sun is above -3°, 1 below -15°.
  static double nightFactor(double sunAltitude) => smoothstep(-3, -15, sunAltitude);

  /// 0 below -4°, 1 above 10°.
  static double daylightFactor(double sunAltitude) => smoothstep(-4, 10, sunAltitude);

  static SkyState compute(DateTime time, {SkyObserver observer = SkyObserver.amman, required SkyTone tone}) {
    final lat = observer.latitude, lon = observer.longitude;
    final sun = Astro.sun(time, latitude: lat, longitude: lon);
    final moon = Astro.moon(time, latitude: lat, longitude: lon);
    final pole = Astro.toHorizontal(
      raDeg: galacticPoleRaDec.$1,
      decDeg: galacticPoleRaDec.$2,
      time: time,
      latitude: lat,
      longitude: lon,
    );
    final centre = Astro.toHorizontal(
      raDeg: galacticCenterRaDec.$1,
      decDeg: galacticCenterRaDec.$2,
      time: time,
      latitude: lat,
      longitude: lon,
    );

    final alt = sun.altitude;
    final night = nightFactor(alt);
    final daylight = daylightFactor(alt);
    // Dawn when the sun is in the eastern half of the sky (smooth through
    // solar noon and midnight, where both looks agree).
    final morning = smoothstep(-0.3, 0.3, math.sin(sun.azimuth * Astro.deg));
    final moonUp = smoothstep(-1, 12, moon.altitude);
    final moonlight = math.pow(moon.illumination, 1.7).toDouble() * moonUp * smoothstep(-2, -12, alt);

    // Stars: magnitude limit by darkness, washed out by moonlight and by the
    // luminous Pearl sky.
    final dark = smoothstep(-2, -17, alt);
    // A real night shows a few hundred stars down to ~5th magnitude; a full
    // moon washes out only the faintest.
    var limit = -1.6 + 7.4 * math.pow(dark, 0.8).toDouble() - 0.6 * moonlight;
    // (Pearl's indigo-slate night is lighter than deep space: a few fewer.)
    if (!tone.dark) limit -= 0.4;
    final starGain = smoothstep(-1.5, -6, alt) * (tone.dark ? 1.0 : 0.92);

    final mw = smoothstep(-11, -18, alt) * (1 - 0.8 * moonlight) * (tone.dark ? 0.2 : 0.12);

    return SkyState(
      time: time,
      observer: observer,
      sun: sun,
      moon: moon,
      sunDir: enu(sun.altitude, sun.azimuth),
      moonDir: enu(moon.altitude, moon.azimuth),
      galacticPole: enu(pole.altitude, pole.azimuth),
      galacticCenter: enu(centre.altitude, centre.azimuth),
      localSiderealDeg: Astro.lstDeg(time, lon),
      night: night,
      daylight: daylight,
      moonlight: moonlight,
      milkyWay: mw,
      starLimit: limit,
      starGain: starGain,
      morning: morning,
      palette: paletteFor(alt, tone, morning: morning, moonlight: moonlight),
      qiblaAzimuth: observer.qiblaAzimuth,
      dark: tone.dark,
    );
  }

  /// The palette at a sun altitude for a theme ([morning] 1 = dawn look,
  /// 0 = dusk look; [moonlight] lifts the night sky).
  static SkyPalette paletteFor(double sunAltitude, SkyTone tone, {double morning = 0.5, double moonlight = 0}) {
    final dawnKeys = tone.dark ? darkDawn : lightDawn;
    final duskKeys = tone.dark ? darkDusk : lightDusk;
    final a = _sample(dawnKeys, sunAltitude);
    final b = _sample(duskKeys, sunAltitude);
    final m = morning.clamp(0.0, 1.0);
    var zenith = SkyColors.lerp(b.zenith, a.zenith, m);
    var horizon = SkyColors.lerp(b.horizon, a.horizon, m);
    final glow = SkyColors.lerp(b.glow, a.glow, m);
    final gi = b.glowIntensity + (a.glowIntensity - b.glowIntensity) * m;

    // Harmonise with the theme: strongest at night (the sky becomes the
    // theme's cosmos), gentle in twilight, a whisper by day. Lightness is
    // kept so the time of day stays unmistakable.
    final night = nightFactor(sunAltitude);
    final day = daylightFactor(sunAltitude);
    final twilight = (1 - night - day).clamp(0.0, 1.0);
    final zenithRef = tone.dark ? tone.nebulaA : tone.nebulaB;
    final horizonRef = tone.dark ? tone.nebulaB : tone.nebulaA;
    final kz = tone.dark ? 0.38 * night + 0.16 * twilight + 0.07 * day : 0.12 * night + 0.12 * twilight + 0.1 * day;
    final kh = tone.dark ? 0.3 * night + 0.1 * twilight + 0.05 * day : 0.1 * night + 0.1 * twilight + 0.12 * day;
    zenith = SkyColors.harmonize(zenith, zenithRef, kz);
    horizon = SkyColors.harmonize(horizon, horizonRef, kh);

    if (moonlight > 0) {
      zenith = SkyColors.lighten(zenith, (tone.dark ? 0.045 : 0.04) * moonlight);
      horizon = SkyColors.lighten(horizon, (tone.dark ? 0.1 : 0.04) * moonlight);
    }

    final nebula = SkyColors.lerp(tone.nebulaA, tone.nebulaB, 0.35);
    // The ground takes the horizon's hue at the theme's depth.
    final ground = tone.dark
        ? SkyColors.harmonize(SkyColors.lerp(tone.space1, horizon, 0.16 + 0.1 * day), horizon, 0.35)
        : SkyColors.harmonize(SkyColors.lerp(tone.space1, horizon, 0.3), horizon, 0.25);
    return SkyPalette(zenith: zenith, horizon: horizon, glow: glow, glowIntensity: gi, nebula: nebula, ground: ground);
  }

  static SkyKeyframe _sample(List<SkyKeyframe> keys, double alt) {
    if (alt <= keys.first.altitude) return keys.first;
    for (var i = 1; i < keys.length; i++) {
      final k1 = keys[i];
      if (alt <= k1.altitude) {
        final k0 = keys[i - 1];
        final raw = (alt - k0.altitude) / (k1.altitude - k0.altitude);
        final t = raw * raw * (3 - 2 * raw);
        return SkyKeyframe(
          alt,
          SkyColors.lerp(k0.zenith, k1.zenith, t),
          SkyColors.lerp(k0.horizon, k1.horizon, t),
          SkyColors.lerp(k0.glow, k1.glow, t),
          k0.glowIntensity + (k1.glowIntensity - k0.glowIntensity) * t,
        );
      }
    }
    return keys.last;
  }

  // ---------------------------------------------------------------------------
  // Keyframes (display sRGB). Dark themes: deep and rich, never washed out.
  // Light (Pearl): luminous, pearly pastels at every hour. Dawn and dusk
  // tables share their night (≤ -18°) and day (≥ 18°) entries.
  // ---------------------------------------------------------------------------

  static const _darkNight = [
    SkyKeyframe(-90, Color(0xFF02040C), Color(0xFF0A1024), Color(0xFF080C1E), 0.0),
    SkyKeyframe(-18, Color(0xFF040817), Color(0xFF101A3C), Color(0xFF161E4A), 0.12),
  ];

  /// Day: a calm, slightly desaturated blue zenith fading into a pale haze
  /// along the horizon (not a flat cobalt).
  static const _darkDay = [
    SkyKeyframe(18, Color(0xFF1E549C), Color(0xFFA9C6DE), Color(0xFFFFF2DC), 0.16),
    SkyKeyframe(40, Color(0xFF1F4F92), Color(0xFFB2CADD), Color(0xFFFFF8EC), 0.08),
    SkyKeyframe(90, Color(0xFF1D4A8C), Color(0xFFAFC8DC), Color(0xFFFFFFFF), 0.07),
  ];

  /// Dawn (Fajr → sunrise): the true dawn is a cool, pale band spreading
  /// along the eastern horizon under a deep indigo sky; peach and gold only
  /// arrive just before sunrise.
  /// (Fajr: deep indigo overhead, a teal band lower down and a thin
  /// rose-amber line right on the horizon; the brighter stars stay out.)
  static const darkDawn = [
    ..._darkNight,
    SkyKeyframe(-14, Color(0xFF070E2C), Color(0xFF1D4A66), Color(0xFFD08C78), 0.42),
    SkyKeyframe(-10, Color(0xFF0B1638), Color(0xFF2E6A80), Color(0xFFF0A27A), 0.62),
    SkyKeyframe(-6, Color(0xFF12275A), Color(0xFF5A8CA4), Color(0xFFF4B48C), 0.72),
    SkyKeyframe(-3, Color(0xFF173266), Color(0xFFC0928E), Color(0xFFFFC49A), 0.85),
    SkyKeyframe(0, Color(0xFF1E4282), Color(0xFFE8A880), Color(0xFFFFD6A8), 0.9),
    SkyKeyframe(5, Color(0xFF22509A), Color(0xFFF0C696), Color(0xFFFFE6C0), 0.75),
    SkyKeyframe(11, Color(0xFF1A56A6), Color(0xFF9CC0DC), Color(0xFFFFF0D8), 0.4),
    ..._darkDay,
  ];

  /// Dusk (golden hour → Maghrib → Isha): gold under a clear blue, then
  /// ember and rose-orange under a deepening blue, then a dusky afterglow –
  /// never a saturated magenta band.
  static const darkDusk = [
    ..._darkNight,
    SkyKeyframe(-14, Color(0xFF070B24), Color(0xFF1C1C40), Color(0xFF3E2C48), 0.3),
    SkyKeyframe(-10, Color(0xFF0A1434), Color(0xFF5A3848), Color(0xFFBE6456), 0.55),
    SkyKeyframe(-6, Color(0xFF0F1F4C), Color(0xFFA4523E), Color(0xFFF4844C), 0.85),
    SkyKeyframe(-3, Color(0xFF162C64), Color(0xFFD65838), Color(0xFFFF8C46), 1.0),
    SkyKeyframe(0, Color(0xFF1C3A7A), Color(0xFFF08040), Color(0xFFFFAA58), 1.0),
    SkyKeyframe(4, Color(0xFF1F5C9C), Color(0xFFF2B460), Color(0xFFFFC874), 0.85),
    SkyKeyframe(8, Color(0xFF2468AA), Color(0xFFE8CA86), Color(0xFFFFDC9A), 0.65),
    SkyKeyframe(13, Color(0xFF1C5CA8), Color(0xFFB0C6CE), Color(0xFFFFEBC6), 0.35),
    ..._darkDay,
  ];

  /// Pearl's night: a deep indigo-slate (it must read as night), lighter
  /// and softer than the dark themes' deep space; the pearl UI stays light.
  static const _lightNight = [
    SkyKeyframe(-90, Color(0xFF1A2240), Color(0xFF3A4468), Color(0xFF444C78), 0.05),
    SkyKeyframe(-18, Color(0xFF1E2748), Color(0xFF434E76), Color(0xFF585C8C), 0.1),
  ];
  static const _lightDay = [
    SkyKeyframe(18, Color(0xFF9CC2EC), Color(0xFFEDF1F3), Color(0xFFFFFCF4), 0.34),
    SkyKeyframe(40, Color(0xFF93BCEA), Color(0xFFE9EFF4), Color(0xFFFFFFFF), 0.3),
    SkyKeyframe(90, Color(0xFF8FB8E8), Color(0xFFE6EDF4), Color(0xFFFFFFFF), 0.3),
  ];

  static const lightDawn = [
    ..._lightNight,
    SkyKeyframe(-14, Color(0xFF28345E), Color(0xFF626C96), Color(0xFFA890B4), 0.22),
    SkyKeyframe(-10, Color(0xFF3E4A7C), Color(0xFF9C9CC0), Color(0xFFE2B0BC), 0.38),
    SkyKeyframe(-6, Color(0xFF6C7AAE), Color(0xFFEAC0C0), Color(0xFFFFCEB8), 0.52),
    SkyKeyframe(-2, Color(0xFF8292C2), Color(0xFFF4CCB6), Color(0xFFFFDABC), 0.62),
    SkyKeyframe(3, Color(0xFF96ACD8), Color(0xFFF8DCBC), Color(0xFFFFE6C4), 0.62),
    SkyKeyframe(10, Color(0xFFA2C0E6), Color(0xFFF0E8DA), Color(0xFFFFF2DE), 0.46),
    ..._lightDay,
  ];

  static const lightDusk = [
    ..._lightNight,
    SkyKeyframe(-14, Color(0xFF262E58), Color(0xFF5E5E8A), Color(0xFFA07CA0), 0.22),
    SkyKeyframe(-10, Color(0xFF384474), Color(0xFF9488B0), Color(0xFFE0A0A8), 0.4),
    SkyKeyframe(-6, Color(0xFF6A72A6), Color(0xFFECB0A6), Color(0xFFFFBEA0), 0.56),
    SkyKeyframe(-2, Color(0xFF808EBE), Color(0xFFF6BE98), Color(0xFFFFC894), 0.66),
    SkyKeyframe(3, Color(0xFF94A8D4), Color(0xFFFAD09C), Color(0xFFFFD8A2), 0.66),
    SkyKeyframe(8, Color(0xFF9CB8E0), Color(0xFFF6DEB2), Color(0xFFFFE6BC), 0.52),
    SkyKeyframe(13, Color(0xFFA0C0E8), Color(0xFFF0E8DA), Color(0xFFFFF2DE), 0.42),
    ..._lightDay,
  ];
}
