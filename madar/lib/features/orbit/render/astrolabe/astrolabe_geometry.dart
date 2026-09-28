import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../core/domain/enums.dart';
import '../../domain/prayer_schedule.dart';

/// Radii of every part of the astrolabe as fractions of the limb's outer
/// radius R (see [AstrolabeGeometry.radiusFor]).
abstract final class AstrolabeRadii {
  /// How far the outer glow / drop shadow reaches.
  static const halo = 1.075;

  // --- limb (the raised brass rim with the 24-hour scale) ----------------
  static const limbOuter = 1.0;
  static const beadOuter = 0.988;
  static const beadInner = 0.966;
  static const scaleOuter = 0.962;
  static const scaleInner = 0.926;
  static const numerals = 0.892;
  static const numeralsInner = 0.862;
  static const limbInner = 0.855;

  // --- plate ---------------------------------------------------------------
  /// The engraved groove the prayer pointers and the lit arc sit in.
  static const channelOuter = 0.838;
  static const channel = 0.808;
  static const channelInner = 0.778;

  /// Tropic of Capricorn = the rete's outer ring = the edge of the
  /// stereographic plate (horizon / almucantars are clipped to it).
  static const capricorn = 0.758;

  /// Prayer names engraved on the plate (upright, inside the channel):
  /// nominal centre radius, and the radius their outer edge never passes.
  static const labels = 0.672;
  static const labelsOuter = 0.742;

  // --- hub -----------------------------------------------------------------
  /// Outer edge of the central brass hub ring carrying the countdown.
  static const hubOuter = 0.285;

  /// Photosphere of the core star.
  static const coreStar = 0.094;

  /// Half-size of a prayer pointer's 8-point star.
  static const pointerStar = 0.046;

  /// Disc of the sun marker on the rete.
  static const sun = 0.034;
}

/// How much engraving detail is drawn, chosen by the on-screen radius.
enum AstrolabeLod {
  /// Tiny (zoomed far out): brass rings, hour ticks, pointers, rete frame.
  minimal,

  /// Small: + quarter-hour ticks, even-hour numerals, countdown, labels.
  medium,

  /// Normal home size: every numeral, beads, girih, almucantars, star
  /// pointers, prayer names.
  full,

  /// Large (zoomed in / tablets): + star names on the rete, fine ecliptic
  /// graduations, prayer times under the names, hairline minute dots.
  ultra;

  bool operator >=(AstrolabeLod other) => index >= other.index;

  bool operator <(AstrolabeLod other) => index < other.index;
}

/// Display state of one obligatory prayer pointer.
enum AstrolabePrayerStatus {
  /// Its time has not come yet (engraved outline).
  upcoming,

  /// Its time has come and it is not logged yet (gently breathing outline).
  due,

  /// Logged today (ignited with golden fire).
  prayed,

  /// Its window ended without a log (dimmed).
  missed,
}

/// Small 3D tilt of the astrolabe disc (gyro parallax / camera), radians.
@immutable
class AstrolabeTilt {
  const AstrolabeTilt({this.pitch = 0, this.yaw = 0});

  static const flat = AstrolabeTilt();

  /// Rotation about the horizontal axis (positive: top edge away).
  final double pitch;

  /// Rotation about the vertical axis (positive: right edge away).
  final double yaw;

  bool get isFlat => pitch.abs() < 1e-5 && yaw.abs() < 1e-5;

  static AstrolabeTilt lerp(AstrolabeTilt a, AstrolabeTilt b, double t) =>
      AstrolabeTilt(pitch: a.pitch + (b.pitch - a.pitch) * t, yaw: a.yaw + (b.yaw - a.yaw) * t);

  @override
  bool operator ==(Object other) => other is AstrolabeTilt && other.pitch == pitch && other.yaw == yaw;

  @override
  int get hashCode => Object.hash(pitch, yaw);

  @override
  String toString() => 'AstrolabeTilt(pitch: $pitch, yaw: $yaw)';
}

/// Pure maths of the 24-hour astrolabe dial: noon at the top, midnight at
/// the bottom, time running clockwise (morning on the left, evening on the
/// right – the sun's path as seen facing south). Angles are canvas radians
/// (0 = +x, clockwise positive because canvas y points down).
abstract final class AstrolabeGeometry {
  static const double tau = 2 * math.pi;

  /// The five obligatory prayers in dial order.
  static const prayers = <Prayer>[Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];

  /// Index of an obligatory prayer in [prayers] (-1 for voluntary prayers).
  static int indexOf(Prayer p) => switch (p) {
    Prayer.fajr => 0,
    Prayer.dhuhr => 1,
    Prayer.asr => 2,
    Prayer.maghrib => 3,
    Prayer.isha => 4,
    _ => -1,
  };

  /// Limb radius for a paint box: the astrolabe fills the shortest side,
  /// leaving room for its halo.
  static double radiusFor(Size size) => size.shortestSide / 2 / AstrolabeRadii.halo;

  /// Detail level for an on-screen limb radius in logical pixels.
  static AstrolabeLod lodFor(double radius) {
    if (radius < 78) return AstrolabeLod.minimal;
    if (radius < 150) return AstrolabeLod.medium;
    if (radius < 330) return AstrolabeLod.full;
    return AstrolabeLod.ultra;
  }

  /// Canvas angle of a dial fraction (0 = midnight, 0.5 = noon).
  static double angleForFraction(double fraction) => tau * fraction - 1.5 * math.pi;

  /// Dial fraction (0..1) of a canvas angle.
  static double fractionForAngle(double angle) {
    final f = (angle + 1.5 * math.pi) / tau;
    return f - f.floorToDouble();
  }

  /// Canvas angle of a local clock time.
  static double angleForTime(DateTime t) => angleForFraction(PrayerSchedule.dialFraction(t));

  /// Point on the dial at [fraction] and [radius] (px) around [center].
  static Offset pointAt(Offset center, double radius, double fraction) {
    final a = angleForFraction(fraction);
    return center + Offset(math.cos(a) * radius, math.sin(a) * radius);
  }

  /// Unit direction (outward) of a dial fraction.
  static Offset directionOf(double fraction) {
    final a = angleForFraction(fraction);
    return Offset(math.cos(a), math.sin(a));
  }

  /// Clockwise arc from [from] to [to] (handles the midnight wrap, e.g.
  /// Isha → Fajr); sweep in (0, 2π].
  static ({double start, double sweep}) arc(DateTime from, DateTime to) {
    final seconds = to.difference(from).inMilliseconds / 1000.0;
    final sweep = (seconds / 86400.0 * tau).clamp(0.0, tau);
    return (start: angleForTime(from), sweep: sweep);
  }

  /// Fraction (0..1) of the arc [from]→[to] already elapsed at [now].
  static double arcProgress(DateTime from, DateTime to, DateTime now) {
    final total = to.difference(from).inMilliseconds;
    if (total <= 0) return 1;
    return (now.difference(from).inMilliseconds / total).clamp(0.0, 1.0);
  }

  /// Centre of a prayer pointer's 8-point star.
  static Offset pointerCenter(Offset center, double radius, double fraction) =>
      pointAt(center, radius * AstrolabeRadii.channel, fraction);

  /// Tip of a prayer pointer (touches the limb's scale at the exact time).
  static Offset pointerTip(Offset center, double radius, double fraction) =>
      pointAt(center, radius * AstrolabeRadii.limbInner, fraction);

  /// Rotation that keeps text upright on a ring: glyph tops point outward
  /// on the upper half and inward on the lower half (so nothing reads upside
  /// down). [angle] is the canvas angle of the glyph's centre.
  static double uprightRotation(double angle) {
    final lower = math.sin(angle) > 1e-6;
    return angle + (lower ? -math.pi / 2 : math.pi / 2);
  }

  /// Pushes sorted [angles] apart so neighbour i / i+1 are at least
  /// `minGaps[i]` apart (radians), keeping each crowded group centred.
  static List<double> spread(List<double> angles, List<double> minGaps, {int iterations = 32}) {
    final a = List<double>.of(angles);
    for (var it = 0; it < iterations; it++) {
      var moved = false;
      for (var i = 0; i + 1 < a.length; i++) {
        final gap = a[i + 1] - a[i];
        if (gap < minGaps[i] - 1e-9) {
          final push = (minGaps[i] - gap) / 2;
          a[i] -= push;
          a[i + 1] += push;
          moved = true;
        }
      }
      if (!moved) break;
    }
    return a;
  }

  /// Canvas angles for the five prayer names: each at its prayer's angle,
  /// spread so neighbours never overlap. [gapFor] gives the smallest allowed
  /// angular distance (radians) between two names meeting around a canvas
  /// angle (upright names need more room side by side than stacked).
  static Map<Prayer, double> labelAngles(
    Map<Prayer, double> fractions, {
    required double Function(double angle) gapFor,
  }) {
    final entries = fractions.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    if (entries.isEmpty) return const {};
    // Unwrap in dial order starting after the widest gap so the spread never
    // pushes a name across that gap.
    var widest = 0;
    var widestGap = -1.0;
    for (var i = 0; i < entries.length; i++) {
      final next = i + 1 < entries.length ? entries[i + 1].value : entries.first.value + 1;
      final gap = next - entries[i].value;
      if (gap > widestGap) {
        widestGap = gap;
        widest = i;
      }
    }
    final order = [for (var k = 1; k <= entries.length; k++) entries[(widest + k) % entries.length]];
    var prev = -double.infinity;
    final angles = <double>[];
    for (final e in order) {
      var f = e.value;
      while (f < prev) {
        f += 1;
      }
      angles.add(f * tau);
      prev = f;
    }
    final gaps = <double>[
      for (var i = 0; i + 1 < angles.length; i++) gapFor(angleForFraction((angles[i] + angles[i + 1]) / 2 / tau)),
    ];
    final spreadOut = spread(angles, gaps);
    return {for (var i = 0; i < order.length; i++) order[i].key: angleForFraction(spreadOut[i] / tau)};
  }

  /// Status of [prayer] at [now] on the prayer day [times]: logged ([prayed])
  /// → prayed; logged as [missed], or its own time ended without a log →
  /// missed; its time has come → due; otherwise upcoming.
  static AstrolabePrayerStatus statusOf(
    Prayer prayer,
    DayTimes times,
    DateTime now, {
    required Set<Prayer> prayed,
    Set<Prayer> missed = const {},
    DateTime? nextFajr,
  }) {
    if (prayed.contains(prayer)) return AstrolabePrayerStatus.prayed;
    if (missed.contains(prayer)) return AstrolabePrayerStatus.missed;
    if (now.isBefore(timeOf(prayer, times))) return AstrolabePrayerStatus.upcoming;
    if (now.isBefore(windowEndOf(prayer, times, nextFajr: nextFajr))) return AstrolabePrayerStatus.due;
    return AstrolabePrayerStatus.missed;
  }

  /// Start time of an obligatory prayer on [times]' day.
  static DateTime timeOf(Prayer prayer, DayTimes times) => switch (prayer) {
    Prayer.fajr => times.fajr,
    Prayer.dhuhr => times.dhuhr,
    Prayer.asr => times.asr,
    Prayer.maghrib => times.maghrib,
    Prayer.isha => times.isha,
    _ => times.sunrise,
  };

  /// When an obligatory prayer's own time ends (Fajr at sunrise, Isha at
  /// the next day's Fajr – [nextFajr] when known, else the same wall-clock
  /// time a calendar day later, never "+ 24 h" across a DST change – the
  /// others at the next prayer).
  static DateTime windowEndOf(Prayer prayer, DayTimes times, {DateTime? nextFajr}) => switch (prayer) {
    Prayer.fajr => times.sunrise,
    Prayer.dhuhr => times.asr,
    Prayer.asr => times.maghrib,
    Prayer.maghrib => times.isha,
    _ => nextFajr ?? _nextDay(times.fajr),
  };

  static DateTime _nextDay(DateTime t) => t.isUtc
      ? DateTime.utc(t.year, t.month, t.day + 1, t.hour, t.minute, t.second, t.millisecond)
      : DateTime(t.year, t.month, t.day + 1, t.hour, t.minute, t.second, t.millisecond);

  // --- tilt ------------------------------------------------------------------

  /// Perspective tilt of the disc around [center]; [radius] sets the viewing
  /// distance so the foreshortening looks the same at every size.
  static Matrix4 tiltMatrix(Offset center, double radius, AstrolabeTilt tilt, {double distance = 3.6}) {
    final m = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..setEntry(3, 2, -1 / (distance * math.max(radius, 1)))
      ..rotateX(tilt.pitch)
      ..rotateY(tilt.yaw)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    return m;
  }

  /// Where a point of the (tilted) disc plane lands on screen.
  static Offset project(Matrix4 m, Offset p) {
    final s = m.storage;
    final x = s[0] * p.dx + s[4] * p.dy + s[12];
    final y = s[1] * p.dx + s[5] * p.dy + s[13];
    final w = s[3] * p.dx + s[7] * p.dy + s[15];
    return Offset(x / w, y / w);
  }

  /// Inverse of [project]: the disc-plane point under a screen position
  /// (the plane's homography inverted), or null when degenerate.
  static Offset? unproject(Matrix4 m, Offset screen) {
    final s = m.storage;
    // H maps (x, y, 1) → (X, Y, W) for points on the z = 0 plane.
    final a = s[0], b = s[4], c = s[12];
    final d = s[1], e = s[5], f = s[13];
    final g = s[3], h = s[7], i = s[15];
    final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
    if (det.abs() < 1e-12) return null;
    final u = screen.dx, v = screen.dy;
    final x = (e * i - f * h) * u + (c * h - b * i) * v + (b * f - c * e);
    final y = (f * g - d * i) * u + (a * i - c * g) * v + (c * d - a * f);
    final w = (d * h - e * g) * u + (b * g - a * h) * v + (a * e - b * d);
    if (w.abs() < 1e-12) return null;
    return Offset(x / w, y / w);
  }

  // --- hit testing -------------------------------------------------------------

  /// The prayer pointer (or its engraved name) under [local] (a position in
  /// the paint box), or null. [fractions] are the prayers' dial fractions;
  /// [labelCenters] the centres of their engraved names in units of the limb
  /// radius around the dial's centre. A tilted disc is un-projected first.
  /// Touch targets are at least [minTouchRadius] logical pixels.
  static Prayer? hitTestPrayer(
    Offset local, {
    required Size size,
    required Map<Prayer, double> fractions,
    Map<Prayer, Offset> labelCenters = const {},
    AstrolabeTilt tilt = AstrolabeTilt.flat,
    double minTouchRadius = 22,
  }) {
    final center = size.center(Offset.zero);
    final radius = radiusFor(size);
    var p = local;
    if (!tilt.isFlat) {
      final plane = unproject(tiltMatrix(center, radius, tilt), local);
      if (plane == null) return null;
      p = plane;
    }
    final touch = math.max(radius * 0.075, minTouchRadius);
    Prayer? best;
    var bestD = double.infinity;
    for (final e in fractions.entries) {
      final star = pointerCenter(center, radius, e.value);
      final tip = pointerTip(center, radius, e.value);
      final d = math.min((p - star).distance, (p - tip).distance);
      if (d < touch && d < bestD) {
        best = e.key;
        bestD = d;
      }
    }
    if (best != null) return best;
    // The engraved names (a smaller target around each name's centre).
    for (final e in labelCenters.entries) {
      final c = center + e.value * radius;
      final d = (p - c).distance;
      if (d < touch * 0.9 && d < bestD) {
        best = e.key;
        bestD = d;
      }
    }
    return best;
  }
}

/// Stereographic projection of the celestial sphere used by the rete and the
/// plate (a northern astrolabe: projected from the south celestial pole onto
/// the equator plane; the rete's outer ring is the tropic of Capricorn).
/// Lengths are fractions of the limb radius R.
abstract final class AstrolabeProjection {
  static const obliquityDeg = 23.44;
  static const _deg = math.pi / 180;

  /// Radius of the celestial equator.
  static final double equator = AstrolabeRadii.capricorn / math.tan((90 + obliquityDeg) / 2 * _deg);

  /// Radius of the tropic of Cancer.
  static final double cancer = radiusForDec(obliquityDeg);

  /// Projected radius of a declination circle.
  static double radiusForDec(double decDeg) => equator * math.tan((90 - decDeg) / 2 * _deg);

  /// Rete-local position (before the rete's rotation) of a sky point:
  /// right ascension grows counter-clockwise.
  static Offset reteLocal(double raDeg, double decDeg) {
    final r = radiusForDec(decDeg);
    final a = -raDeg * _deg;
    return Offset(math.cos(a) * r, math.sin(a) * r);
  }

  /// The ecliptic's projected circle (rete-local).
  static ({Offset center, double radius}) get ecliptic {
    final summer = reteLocal(90, obliquityDeg);
    final winter = reteLocal(270, -obliquityDeg);
    return (center: (summer + winter) / 2, radius: (summer - winter).distance / 2);
  }

  /// Right ascension / declination of ecliptic longitude [lambdaDeg].
  static ({double ra, double dec}) eclipticToEquatorial(double lambdaDeg) {
    final l = lambdaDeg * _deg;
    final e = obliquityDeg * _deg;
    final ra = math.atan2(math.cos(e) * math.sin(l), math.cos(l)) / _deg;
    final dec = math.asin(math.sin(e) * math.sin(l)) / _deg;
    return (ra: ra < 0 ? ra + 360 : ra, dec: dec);
  }

  /// Rete-local point of ecliptic longitude [lambdaDeg].
  static Offset eclipticPoint(double lambdaDeg) {
    final q = eclipticToEquatorial(lambdaDeg);
    return reteLocal(q.ra, q.dec);
  }

  /// Rotation (canvas radians) that puts the sun – at right ascension
  /// [sunRaDeg] on the rete – at dial fraction [sunFraction]. One turn per
  /// solar day.
  static double reteRotation({required double sunFraction, required double sunRaDeg}) =>
      AstrolabeGeometry.angleForFraction(sunFraction) + sunRaDeg * _deg;

  /// Almucantar (circle of equal altitude) for [latitudeDeg] on the plate,
  /// plate-local: its centre lies on the meridian toward the top (south).
  /// [altitudeDeg] 0 = horizon, −18 = the twilight line of Fajr / Isha.
  static ({Offset center, double radius}) almucantar(double altitudeDeg, double latitudeDeg) {
    final phi = latitudeDeg.abs().clamp(5.0, 70.0) * _deg;
    final h = altitudeDeg * _deg;
    final denom = math.sin(phi) + math.sin(h);
    final safe = denom.abs() < 1e-3 ? 1e-3 : denom;
    final dist = equator * math.cos(phi) / safe;
    final r = equator * math.cos(h) / safe;
    return (center: Offset(0, -dist), radius: r.abs());
  }

  /// The zenith on the plate (plate-local).
  static Offset zenith(double latitudeDeg) => Offset(0, -radiusForDec(latitudeDeg.abs().clamp(5.0, 70.0).toDouble()));

  /// Plate rotation (canvas radians) that lines the plate's meridian up with
  /// the local clock: clock time minus apparent solar time.
  static double plateRotation({required double clockFraction, required double solarFraction}) {
    var d = clockFraction - solarFraction;
    d -= d.roundToDouble();
    return d * AstrolabeGeometry.tau;
  }
}
