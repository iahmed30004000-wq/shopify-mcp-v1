import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Offset, Rect, Size;

import '../../../../core/astro/star_catalog.dart';
import '../../domain/scene_math.dart';
import 'sky_model.dart';
import 'sky_view.dart';

/// Atlas layout of the procedural star sprite (see `StarSprite`): three
/// square cells side by side – a soft round star, a 4-point and an 8-point
/// diffraction star.
abstract final class StarSpriteLayout {
  /// Cell edge in atlas pixels.
  static const int cell = 64;
  static const int round = 0, spikes4 = 1, spikes8 = 2;
  static const int cells = 3;

  /// Magnitude at or below which a star gets 8 / 4 diffraction spikes.
  static const double spikes8Magnitude = 0.5;
  static const double spikes4Magnitude = 1.6;

  static int cellFor(double magnitude) => magnitude <= spikes8Magnitude
      ? spikes8
      : magnitude <= spikes4Magnitude
      ? spikes4
      : round;
}

/// Equatorial (J2000) → local ENU rotation for a local sidereal time and
/// latitude, as three row vectors (east, north, up) in the equatorial frame
/// (x → RA 0h, z → north celestial pole).
(V3, V3, V3) equatorialToEnu(double lstDeg, double latitudeDeg) {
  final t = lstDeg * math.pi / 180, p = latitudeDeg * math.pi / 180;
  final st = math.sin(t), ct = math.cos(t), sp = math.sin(p), cp = math.cos(p);
  return (V3(-st, ct, 0), V3(-sp * ct, -sp * st, cp), V3(cp * ct, cp * st, sp));
}

/// ENU vector of an equatorial unit vector.
V3 enuOf(V3 eq, double lstDeg, double latitudeDeg) {
  final (e, n, u) = equatorialToEnu(lstDeg, latitudeDeg);
  return V3(e.dot(eq), n.dot(eq), u.dot(eq));
}

/// The star catalogue prepared for drawing with `Canvas.drawRawAtlas`.
///
/// [project] fills [transforms] / [rects] (4 floats per star) for the stars
/// that are above the horizon, on screen and bright enough for the current
/// darkness; it skips the work when neither the camera basis (by more than
/// [reprojectDegrees]) nor the visibility inputs changed. [colorize] writes
/// the per-frame [colors] with a gentle per-star twinkle. Nothing is
/// allocated after construction except the cached sub-list views, which are
/// only recreated when the visible count changes.
class StarField {
  StarField({List<CatalogStar>? catalog, Color tint = const Color(0xFFFFFFFF)})
    : _stars = catalog ?? StarCatalog.stars,
      length = (catalog ?? StarCatalog.stars).length {
    final n = length;
    _eq = Float64List(n * 3);
    _mag = Float32List(n);
    _size = Float32List(n);
    _alpha = Float32List(n);
    _cell = Uint8List(n);
    _phase = Float32List(n);
    _freq = Float32List(n);
    _rgb = Int32List(n);
    transforms = Float32List(n * 4);
    rects = Float32List(n * 4);
    colors = Int32List(n);
    _vis = Int32List(n);
    _visAlpha = Float32List(n);
    _visAmp = Float32List(n);
    final rng = math.Random(0x5354);
    for (var i = 0; i < n; i++) {
      final s = _stars[i];
      final (x, y, z) = s.unitVector;
      _eq[i * 3] = x;
      _eq[i * 3 + 1] = y;
      _eq[i * 3 + 2] = z;
      _mag[i] = s.magnitude;
      final flux = math.pow(10, -0.4 * (s.magnitude + 1.46)).toDouble();
      final cell = StarSpriteLayout.cellFor(s.magnitude);
      _cell[i] = cell;
      final base = 6.2 + 20 * math.sqrt(flux);
      _size[i] = base * (cell == StarSpriteLayout.round ? 1.0 : 1.6);
      _alpha[i] = (0.42 + 1.1 * math.pow(flux, 0.3)).clamp(0.0, 1.0).toDouble();
      _phase[i] = rng.nextDouble() * math.pi * 2;
      _freq[i] = 1.3 + rng.nextDouble() * 2.6;
    }
    this.tint = tint;
  }

  final List<CatalogStar> _stars;

  /// Number of catalogue stars.
  final int length;

  /// Re-projection threshold for camera basis changes.
  static const double reprojectDegrees = 0.05;

  late final Float64List _eq;
  late final Float32List _mag, _size, _alpha, _phase, _freq;
  late final Uint8List _cell;
  late final Int32List _rgb;

  /// RSTransforms (scos, ssin, tx, ty) of the visible stars.
  late final Float32List transforms;

  /// Atlas source rects (l, t, r, b) of the visible stars.
  late final Float32List rects;

  /// ARGB colours of the visible stars (twinkle applied).
  late final Int32List colors;

  late final Int32List _vis;
  late final Float32List _visAlpha, _visAmp;

  int _count = 0;

  /// Stars currently visible.
  int get count => _count;

  /// Catalogue index of the i-th visible star.
  int visibleIndex(int i) => _vis[i];

  /// Pre-twinkle alpha of the i-th visible star.
  double visibleAlpha(int i) => _visAlpha[i];

  Color _tint = const Color(0xFFFFFFFF);

  /// Colour the black-body colours lean toward (theme star tint).
  Color get tint => _tint;
  set tint(Color value) {
    _tint = value;
    for (var i = 0; i < length; i++) {
      final bb = _stars[i].color;
      // Real stars read mostly white with a hint of colour.
      double ch(double b, double t) => (1 + (b - 1) * 0.5) * 0.88 + t * 0.12;
      final r = (ch(bb.r, value.r) * 255).round().clamp(0, 255);
      final g = (ch(bb.g, value.g) * 255).round().clamp(0, 255);
      final b = (ch(bb.b, value.b) * 255).round().clamp(0, 255);
      _rgb[i] = (r << 16) | (g << 8) | b;
    }
    _dirty = true;
  }

  // Last projection inputs (for the re-projection threshold).
  SkyCamera? _cam;
  final Float64List _rows = Float64List(12);
  double _lst = double.nan, _lat = double.nan, _limit = double.nan, _gain = double.nan, _scale = double.nan;
  Offset? _occluder;
  double _occluderR = 0;
  bool _dirty = true;

  /// Rows (right, up, forward, zenith) of the equatorial → camera matrix.
  static void cameraRows(SkyCamera cam, double lstDeg, double latitudeDeg, Float64List out) {
    final (e, n, u) = equatorialToEnu(lstDeg, latitudeDeg);
    void row(int o, V3 c) {
      out[o] = c.x * e.x + c.y * n.x + c.z * u.x;
      out[o + 1] = c.x * e.y + c.y * n.y + c.z * u.y;
      out[o + 2] = c.x * e.z + c.y * n.z + c.z * u.z;
    }

    row(0, cam.right);
    row(3, cam.up);
    row(6, cam.forward);
    out[9] = u.x;
    out[10] = u.y;
    out[11] = u.z;
  }

  bool _needsProjection(
    SkyCamera cam,
    double lst,
    double lat,
    double limit,
    double gain,
    double scale,
    Offset? occ,
    double occR,
  ) {
    if (_dirty) return true;
    final prev = _cam;
    if (prev == null) return true;
    if ((limit - _limit).abs() > 0.01 || (gain - _gain).abs() > 0.004 || scale != _scale) return true;
    if (lat != _lat) return true;
    if ((occ == null) != (_occluder == null)) return true;
    if (occ != null && ((occ - _occluder!).distance > 0.25 || (occR - _occluderR).abs() > 0.25)) return true;
    if (prev.viewport != cam.viewport || (prev.focal - cam.focal).abs() > 1e-3) return true;
    if ((prev.principal - cam.principal).distanceSquared > 1e-4) return true;
    // Sky rotation since the last projection: camera change + sidereal drift.
    final lstDelta = ((lst - _lst + 540) % 360 - 180).abs();
    return prev.angleTo(cam) + lstDelta > reprojectDegrees;
  }

  /// Projects the visible stars. Returns false when the previous projection
  /// is still valid (sub-[reprojectDegrees] change).
  ///
  /// [limitMagnitude] / [gain] come from [SkyState]; stars inside the
  /// [occluder] circle (the moon) are skipped; [scale] multiplies sprite
  /// sizes (logical px).
  bool project(
    SkyCamera cam, {
    required double lstDeg,
    required double latitudeDeg,
    required double limitMagnitude,
    required double gain,
    double scale = 1,
    Offset? occluder,
    double occluderRadius = 0,
    bool force = false,
  }) {
    if (!force && !_needsProjection(cam, lstDeg, latitudeDeg, limitMagnitude, gain, scale, occluder, occluderRadius)) {
      return false;
    }
    _cam = cam;
    _lst = lstDeg;
    _lat = latitudeDeg;
    _limit = limitMagnitude;
    _gain = gain;
    _scale = scale;
    _occluder = occluder;
    _occluderR = occluderRadius;
    _dirty = false;
    cameraRows(cam, lstDeg, latitudeDeg, _rows);
    final k = _rows;
    final f = cam.focal, cx = cam.principal.dx, cy = cam.principal.dy;
    final w = cam.viewport.width, h = cam.viewport.height;
    final ox = occluder?.dx ?? 0, oy = occluder?.dy ?? 0;
    final or2 = occluderRadius * occluderRadius;
    var n = 0;
    if (gain > 0.002) {
      final cutoff = limitMagnitude + 0.35;
      for (var i = 0; i < length; i++) {
        final mag = _mag[i];
        if (mag > cutoff) break; // catalogue sorted by magnitude
        final vx = _eq[i * 3], vy = _eq[i * 3 + 1], vz = _eq[i * 3 + 2];
        final sinAlt = k[9] * vx + k[10] * vy + k[11] * vz;
        if (sinAlt < -0.004) continue;
        final z = k[6] * vx + k[7] * vy + k[8] * vz;
        if (z < 0.02) continue;
        final sx = cx + (k[0] * vx + k[1] * vy + k[2] * vz) * f / z;
        final sy = cy - (k[3] * vx + k[4] * vy + k[5] * vz) * f / z;
        final size = _size[i] * scale;
        final half = size * 0.5;
        if (sx < -half || sy < -half || sx > w + half || sy > h + half) continue;
        if (occluder != null) {
          final dx = sx - ox, dy = sy - oy;
          if (dx * dx + dy * dy < or2) continue;
        }
        final fade = _smooth(cutoff, limitMagnitude - 0.35, mag);
        final ext = _smooth(-0.004, 0.26, sinAlt);
        final a = _alpha[i] * fade * gain * (0.3 + 0.7 * ext);
        if (a < 0.01) continue;
        final s = size * (0.8 + 0.2 * ext) / StarSpriteLayout.cell;
        final o = n * 4;
        const c = StarSpriteLayout.cell;
        transforms[o] = s;
        transforms[o + 1] = 0;
        transforms[o + 2] = sx - s * c * 0.5;
        transforms[o + 3] = sy - s * c * 0.5;
        final left = (_cell[i] * c).toDouble();
        rects[o] = left;
        rects[o + 1] = 0;
        rects[o + 2] = left + c;
        rects[o + 3] = c.toDouble();
        _vis[n] = i;
        _visAlpha[n] = a;
        // Scintillation is strongest low in the sky.
        _visAmp[n] = 0.1 + 0.26 * (1 - ext);
        n++;
      }
    }
    _count = n;
    return true;
  }

  /// Writes [colors] for time [t] (seconds). [twinkle] false = steady.
  void colorize(double t, {bool twinkle = true}) {
    for (var j = 0; j < _count; j++) {
      final i = _vis[j];
      var a = _visAlpha[j];
      if (twinkle) {
        final ph = _phase[i], fr = _freq[i];
        final tw = 0.62 * math.sin(t * fr + ph) + 0.38 * math.sin(t * fr * 1.73 + ph * 2.1);
        a *= 1 + _visAmp[j] * tw;
      }
      final ai = (a.clamp(0.0, 1.0) * 255).round();
      colors[j] = (ai << 24) | _rgb[i];
    }
  }

  Float32List _tView = Float32List(0), _rView = Float32List(0);
  Int32List _cView = Int32List(0);
  int _viewCount = 0;

  /// [transforms] / [rects] / [colors] trimmed to [count] – views that are
  /// only recreated when the visible count changes (no per-frame garbage).
  Float32List get transformsView {
    _syncViews();
    return _tView;
  }

  Float32List get rectsView {
    _syncViews();
    return _rView;
  }

  Int32List get colorsView {
    _syncViews();
    return _cView;
  }

  void _syncViews() {
    if (_viewCount == _count) return;
    _viewCount = _count;
    _tView = Float32List.sublistView(transforms, 0, _count * 4);
    _rView = Float32List.sublistView(rects, 0, _count * 4);
    _cView = Int32List.sublistView(colors, 0, _count);
  }

  /// Screen position of the i-th visible star (sprite centre).
  Offset visiblePosition(int i) {
    final o = i * 4;
    const half = StarSpriteLayout.cell * 0.5;
    final s = transforms[o];
    return Offset(transforms[o + 2] + s * half, transforms[o + 3] + s * half);
  }

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}

/// A named bright star (traditional Arabic name) ready for labelling.
class StarName {
  const StarName({required this.ar, required this.en, required this.magnitude, required this.eq});

  final String ar, en;
  final double magnitude;

  /// Equatorial unit vector.
  final V3 eq;

  String label(bool arabic) => arabic ? ar : en;
}

/// One placed star-name label (a reusable slot).
class StarLabel {
  /// Index into [StarNames.all].
  int name = 0;
  Offset star = Offset.zero;
  Rect rect = Rect.zero;
  double opacity = 0;
}

/// Chooses which bright stars get their (Arabic) names: the brightest ones
/// that are well above the horizon, on screen, outside a keep-out rect (the
/// astrolabe) and not overlapping each other.
class StarNames {
  StarNames({List<CatalogStar>? catalog}) : all = _build(catalog ?? StarCatalog.stars) {
    _order = List<int>.generate(all.length, (i) => i)..sort((a, b) => all[a].magnitude.compareTo(all[b].magnitude));
    placed = List<StarLabel>.generate(all.length, (_) => StarLabel(), growable: false);
  }

  final List<StarName> all;
  late final List<int> _order;

  /// Label slots; the first [count] are placed.
  late final List<StarLabel> placed;
  int count = 0;
  final Float64List _rows = Float64List(12);

  static List<StarName> _build(List<CatalogStar> catalog) {
    final out = <StarName>[];
    for (final e in kArabicStarNames) {
      final ra = e.ra * math.pi / 180, dec = e.dec * math.pi / 180;
      final v = V3(math.cos(dec) * math.cos(ra), math.cos(dec) * math.sin(ra), math.sin(dec));
      // Magnitude of the nearest catalogue star (clusters fall back to 1.6).
      var mag = 1.6;
      var best = math.cos(0.4 * math.pi / 180);
      for (final s in catalog) {
        if (s.magnitude > 3) break;
        final (x, y, z) = s.unitVector;
        final d = x * v.x + y * v.y + z * v.z;
        if (d > best) {
          best = d;
          mag = s.magnitude;
        }
      }
      out.add(StarName(ar: e.ar, en: e.en, magnitude: mag, eq: v));
    }
    return out;
  }

  /// Places up to [maxLabels] labels. [labelSize] gives each label's text
  /// size; labels sit beside their star on the reading-start side
  /// ([rtl]: to the left, text ending near the star).
  void layout(
    SkyCamera cam, {
    required double lstDeg,
    required double latitudeDeg,
    required Size Function(int index) labelSize,
    required bool rtl,
    double limitMagnitude = 1.8,
    double opacity = 1,
    Rect? keepOut,
    int maxLabels = 7,
    double gap = 7,
  }) {
    count = 0;
    if (opacity <= 0.01) return;
    StarField.cameraRows(cam, lstDeg, latitudeDeg, _rows);
    final k = _rows;
    final f = cam.focal, cx = cam.principal.dx, cy = cam.principal.dy;
    final bounds = (Offset.zero & cam.viewport).deflate(6);
    for (final idx in _order) {
      if (count >= maxLabels) break;
      final s = all[idx];
      if (s.magnitude > limitMagnitude) continue;
      final v = s.eq;
      final sinAlt = k[9] * v.x + k[10] * v.y + k[11] * v.z;
      if (sinAlt < 0.14) continue; // ~8° above the horizon
      final z = k[6] * v.x + k[7] * v.y + k[8] * v.z;
      if (z < 0.05) continue;
      final sx = cx + (k[0] * v.x + k[1] * v.y + k[2] * v.z) * f / z;
      final sy = cy - (k[3] * v.x + k[4] * v.y + k[5] * v.z) * f / z;
      final star = Offset(sx, sy);
      if (!bounds.contains(star)) continue;
      if (keepOut != null && keepOut.inflate(4).contains(star)) continue;
      final size = labelSize(idx);
      final left = rtl ? sx - gap - size.width : sx + gap;
      final rect = Rect.fromLTWH(left, sy - size.height / 2, size.width, size.height);
      if (!bounds.contains(rect.topLeft) || !bounds.contains(rect.bottomRight)) continue;
      if (keepOut != null && keepOut.overlaps(rect)) continue;
      var clash = false;
      for (var j = 0; j < count; j++) {
        if (placed[j].rect.inflate(6).overlaps(rect)) {
          clash = true;
          break;
        }
      }
      if (clash) continue;
      // Fixed slot objects: no per-frame allocation of labels.
      placed[count++]
        ..name = idx
        ..star = star
        ..rect = rect
        ..opacity = opacity * SkyModel.smoothstep(0.14, 0.3, sinAlt);
    }
  }
}
