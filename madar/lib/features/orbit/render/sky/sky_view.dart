import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

import '../../domain/scene_math.dart';
import 'sky_model.dart';

/// How the living sky is framed behind the orbit (all positions are
/// fractions of the viewport).
@immutable
class SkyComposition {
  const SkyComposition({
    this.fovY = 1.45,
    this.twilightHorizonY = 0.56,
    this.sunX = 0.8,
    this.moonAnchor = const Offset(0.26, 0.15),
    this.restHorizonY = 0.6,
    this.minPitchDeg = -4,
    this.maxPitchDeg = 62,
    this.parallax = 0.12,
    this.maxGyroDeg = 4,
    this.referenceElevation = 0.36,
    this.zoomFovScale = 0.1,
  });

  /// Vertical field of view of the sky (radians; wider than the scene's).
  final double fovY;

  /// During twilight the camera faces the sun with the horizon at this
  /// height and the sun's azimuth at [sunX] (off the astrolabe's axis).
  final double twilightHorizonY;
  final double sunX;

  /// At night, when the moon is up, it is framed at this point.
  final Offset moonAnchor;

  /// Otherwise (day, moonless night) the camera faces the qibla with the
  /// horizon here: its bright haze glows through the top of the glass
  /// panel while the panel itself sits over the dark ground (legible text
  /// even at noon).
  final double restHorizonY;

  final double minPitchDeg, maxPitchDeg;

  /// Sky rotation per radian of orbit-camera rotation (distant parallax).
  final double parallax;

  /// Gyroscope parallax is clamped to ± this many degrees.
  final double maxGyroDeg;

  /// Orbit-camera elevation at which the sky pitch is not offset.
  final double referenceElevation;

  /// The sky's field of view narrows by this fraction on a full fly-in.
  final double zoomFovScale;

  @override
  bool operator ==(Object other) =>
      other is SkyComposition &&
      other.fovY == fovY &&
      other.twilightHorizonY == twilightHorizonY &&
      other.sunX == sunX &&
      other.moonAnchor == moonAnchor &&
      other.restHorizonY == restHorizonY &&
      other.minPitchDeg == minPitchDeg &&
      other.maxPitchDeg == maxPitchDeg &&
      other.parallax == parallax &&
      other.maxGyroDeg == maxGyroDeg &&
      other.referenceElevation == referenceElevation &&
      other.zoomFovScale == zoomFovScale;

  @override
  int get hashCode => Object.hash(
    fovY,
    twilightHorizonY,
    sunX,
    moonAnchor,
    restHorizonY,
    minPitchDeg,
    maxPitchDeg,
    parallax,
    maxGyroDeg,
    referenceElevation,
    zoomFovScale,
  );
}

/// A sky view direction (degrees): yaw = azimuth of the camera's forward
/// axis, pitch = its altitude.
@immutable
class SkyAim {
  const SkyAim(this.yaw, this.pitch);

  final double yaw, pitch;

  /// Interpolates along the shortest arc of yaw.
  static SkyAim lerp(SkyAim a, SkyAim b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    var d = (b.yaw - a.yaw) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return SkyAim(a.yaw + d * t, a.pitch + (b.pitch - a.pitch) * t);
  }

  @override
  String toString() => 'SkyAim(yaw ${yaw.toStringAsFixed(2)}, pitch ${pitch.toStringAsFixed(2)})';
}

/// What the sky camera is looking at, and why.
enum SkyTarget { sun, moon, qibla }

/// The sky's pinhole camera in ENU (x east, y north, z up), sharing the
/// orbit camera's principal point so both perspectives agree.
@immutable
class SkyCamera {
  const SkyCamera({
    required this.right,
    required this.up,
    required this.forward,
    required this.focal,
    required this.principal,
    required this.viewport,
    required this.aim,
    required this.roll,
  });

  /// Builds the camera for an [aim] (degrees) and [roll] (radians).
  factory SkyCamera.fromAim(
    SkyAim aim, {
    required Size viewport,
    required Offset principal,
    required double fovY,
    double roll = 0,
  }) {
    final (r, u, f) = basisFor(aim.yaw, aim.pitch, roll);
    return SkyCamera(
      right: r,
      up: u,
      forward: f,
      focal: viewport.height / (2 * math.tan(fovY / 2)),
      principal: principal,
      viewport: viewport,
      aim: aim,
      roll: roll,
    );
  }

  final V3 right, up, forward;
  final double focal;

  /// Principal point in logical pixels.
  final Offset principal;
  final Size viewport;
  final SkyAim aim;
  final double roll;

  /// (right, up, forward) for a yaw / pitch in degrees and a roll in radians.
  static (V3, V3, V3) basisFor(double yawDeg, double pitchDeg, double roll) {
    final y = yawDeg * math.pi / 180, p = pitchDeg * math.pi / 180;
    final sy = math.sin(y), cy = math.cos(y), sp = math.sin(p), cp = math.cos(p);
    final f = V3(cp * sy, cp * cy, sp);
    final r = V3(cy, -sy, 0);
    final u = V3(-sy * sp, -cy * sp, cp);
    if (roll == 0) return (r, u, f);
    final c = math.cos(roll), s = math.sin(roll);
    return (r * c + u * s, u * c - r * s, f);
  }

  /// Screen position (logical px) of an ENU direction, or null behind the
  /// camera.
  Offset? project(V3 dir) {
    final z = dir.dot(forward);
    if (z <= 1e-4) return null;
    return Offset(principal.dx + dir.dot(right) * focal / z, principal.dy - dir.dot(up) * focal / z);
  }

  /// ENU ray through a screen point.
  V3 ray(Offset screen) {
    final dx = (screen.dx - principal.dx) / focal;
    final dy = -(screen.dy - principal.dy) / focal;
    return (forward + right * dx + up * dy).normalized;
  }

  /// Largest rotation (degrees) between this camera's basis and [other]'s.
  double angleTo(SkyCamera other) {
    double ang(V3 a, V3 b) => math.acos(a.dot(b).clamp(-1.0, 1.0)) * 180 / math.pi;
    return math.max(ang(forward, other.forward), ang(up, other.up));
  }

  /// Whether the framing differs from [other] by more than [degrees] or by
  /// any change of viewport, focal length or principal point.
  bool differsFrom(SkyCamera? other, {double degrees = 0.05}) {
    if (other == null) return true;
    if (other.viewport != viewport) return true;
    if ((other.focal - focal).abs() > 1e-3) return true;
    if ((other.principal - principal).distanceSquared > 1e-4) return true;
    return angleTo(other) > degrees;
  }
}

/// The view logic of the living sky.
abstract final class SkyView {
  /// Sun altitudes over which the view pans between night and twilight
  /// (finished before Fajr / begun after Isha, both at -18°) and between
  /// twilight and day.
  static const nightPan = (-24.0, -19.0);
  static const dayPan = (9.0, 17.0);

  /// Weights of each [SkyTarget] for a sun altitude and moon altitude:
  /// face the sun in twilight (-19° … +9°), the moon at night when it is
  /// up, the qibla otherwise; the pans between them take ~20 minutes.
  static Map<SkyTarget, double> weights(double sunAltitude, double moonAltitude) {
    final toSun = SkyModel.smoothstep(nightPan.$1, nightPan.$2, sunAltitude);
    final toDay = SkyModel.smoothstep(dayPan.$1, dayPan.$2, sunAltitude);
    final moonUp = SkyModel.smoothstep(-1, 6, moonAltitude);
    final sun = toSun * (1 - toDay);
    final night = 1 - toSun;
    final moon = night * moonUp;
    return {SkyTarget.sun: sun, SkyTarget.moon: moon, SkyTarget.qibla: 1 - sun - moon};
  }

  /// The dominant target.
  static SkyTarget dominant(double sunAltitude, double moonAltitude) {
    final w = weights(sunAltitude, moonAltitude);
    return w.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /// Pitch (degrees) that puts the horizon at [horizonY] (fraction).
  static double pitchForHorizon(double horizonY, Size viewport, Offset principal, double focal) =>
      math.atan((horizonY * viewport.height - principal.dy) / focal) * 180 / math.pi;

  /// Aim that shows ENU azimuth [azimuth] at screen x [screenX] (fraction) on
  /// a horizon placed at [horizonY].
  static SkyAim aimAtHorizon(
    double azimuth,
    double screenX,
    double horizonY,
    Size viewport,
    Offset principal,
    double focal,
  ) {
    final pitch = pitchForHorizon(horizonY, viewport, principal, focal);
    final dx = (screenX * viewport.width - principal.dx) / focal;
    final dy = (principal.dy - horizonY * viewport.height) / focal;
    final p = pitch * math.pi / 180;
    final yaw = azimuth - math.atan2(dx, math.cos(p) - dy * math.sin(p)) * 180 / math.pi;
    return SkyAim(yaw, pitch);
  }

  /// Aim that frames a body at altitude/azimuth (degrees) exactly at the
  /// screen [anchor] (fractions), pitch clamped to [minPitch, maxPitch].
  static SkyAim aimAtBody(
    double altitude,
    double azimuth,
    Offset anchor,
    Size viewport,
    Offset principal,
    double focal, {
    double minPitch = -89,
    double maxPitch = 89,
  }) {
    final dx = (anchor.dx * viewport.width - principal.dx) / focal;
    final dy = (principal.dy - anchor.dy * viewport.height) / focal;
    final len = math.sqrt(1 + dx * dx + dy * dy);
    final sinAlt = math.sin(altitude * math.pi / 180);
    final k = (len * sinAlt / math.sqrt(1 + dy * dy)).clamp(-1.0, 1.0);
    var p = math.asin(k) - math.atan(dy);
    p = p.clamp(minPitch * math.pi / 180, maxPitch * math.pi / 180);
    final yaw = azimuth - math.atan2(dx, math.cos(p) - dy * math.sin(p)) * 180 / math.pi;
    return SkyAim(yaw, p * 180 / math.pi);
  }

  /// The resting aim (before parallax) for a sky state and viewport.
  static SkyAim restingAim(SkyState s, Size viewport, Offset principal, double focal, SkyComposition c) {
    final qibla = SkyAim(s.qiblaAzimuth, pitchForHorizon(c.restHorizonY, viewport, principal, focal));
    // A low moon may pull the view down to the twilight framing (a moonrise
    // over the horizon), never lower.
    final moonAim = aimAtBody(
      s.moon.altitude,
      s.moon.azimuth,
      c.moonAnchor,
      viewport,
      principal,
      focal,
      minPitch: pitchForHorizon(c.twilightHorizonY, viewport, principal, focal),
      maxPitch: c.maxPitchDeg,
    );
    final sunAim = aimAtHorizon(s.sun.azimuth, c.sunX, c.twilightHorizonY, viewport, principal, focal);
    final sunAlt = s.sun.altitude;
    final moonUp = SkyModel.smoothstep(-1, 6, s.moon.altitude);
    final toSun = SkyModel.smoothstep(nightPan.$1, nightPan.$2, sunAlt);
    final toDay = SkyModel.smoothstep(dayPan.$1, dayPan.$2, sunAlt);
    final nightAim = SkyAim.lerp(qibla, moonAim, moonUp);
    return SkyAim.lerp(SkyAim.lerp(nightAim, sunAim, toSun), qibla, toDay);
  }

  /// The full sky camera: resting aim + distant parallax from the orbit
  /// camera (yaw −[SkyComposition.parallax] × azimuth, pitch likewise from
  /// its elevation) + a few degrees of gyroscope, the orbit camera's roll,
  /// and a field of view that narrows slightly on a fly-in ([zoom] 0..1).
  static SkyCamera camera(
    SkyState s,
    Size viewport, {
    OrbitCamera orbit = const OrbitCamera(),
    double zoom = 0,
    Offset gyro = Offset.zero,
    SkyComposition composition = const SkyComposition(),
  }) {
    final c = composition;
    final principal = Offset(viewport.width * orbit.principal.dx, viewport.height * orbit.principal.dy);
    final fov = c.fovY * (1 - c.zoomFovScale * zoom.clamp(0.0, 1.0));
    final focal = viewport.height / (2 * math.tan(fov / 2));
    final rest = restingAim(s, viewport, principal, focal, c);
    const rad = 180 / math.pi;
    final g = c.maxGyroDeg;
    final yaw = rest.yaw - c.parallax * orbit.azimuth * rad + gyro.dx.clamp(-g, g);
    final pitch = (rest.pitch - c.parallax * (orbit.elevation - c.referenceElevation) * rad + gyro.dy.clamp(-g, g))
        .clamp(c.minPitchDeg, c.maxPitchDeg);
    return SkyCamera.fromAim(
      SkyAim(yaw, pitch.toDouble()),
      viewport: viewport,
      principal: principal,
      fovY: fov,
      roll: orbit.roll,
    );
  }

  /// Screen direction (unit, y up) from the moon toward the sun, i.e. where
  /// its bright limb faces.
  static Offset brightLimbDirection(SkyCamera cam, V3 moonDir, V3 sunDir) {
    var t = sunDir - moonDir * moonDir.dot(sunDir);
    if (t.length < 1e-6) t = cam.up;
    t = t.normalized;
    final p0 = cam.project(moonDir);
    final p1 = cam.project((moonDir + t * 0.01).normalized);
    double x, y;
    if (p0 != null && p1 != null) {
      x = p1.dx - p0.dx;
      y = -(p1.dy - p0.dy);
    } else {
      x = t.dot(cam.right);
      y = t.dot(cam.up);
    }
    final l = math.sqrt(x * x + y * y);
    return l < 1e-9 ? const Offset(0, 1) : Offset(x / l, y / l);
  }

  /// moon.frag's light vector (x right, y up, z toward the viewer):
  /// l = (sin i · u, cos i) with i the phase angle and u the bright-limb
  /// direction.
  static V3 moonLight(double phaseAngle, Offset limb) {
    final s = math.sin(phaseAngle);
    return V3(s * limb.dx, s * limb.dy, math.cos(phaseAngle));
  }
}
