import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'curl_geometry.dart';
import 'curl_scene.dart';

/// Which parts of the curl a [CurlPainter] draws. The image path draws all of
/// them in one pass; the live-widget fallback draws only the shading, between
/// widget layers.
class CurlLayers {
  const CurlLayers._(this.bits);
  final int bits;
  static const CurlLayers revealedShadow = CurlLayers._(1);
  static const CurlLayers edgeShadow = CurlLayers._(2);
  static const CurlLayers backShade = CurlLayers._(4);
  static const CurlLayers all = CurlLayers._(7);
  bool has(CurlLayers l) => bits & l.bits != 0;
}

/// Draws the page curl with plain canvas operations (clip paths, transforms,
/// gradients) on page images: no fragment shader.
///
/// Per frame it reuses one [Path], one matrix buffer and a fixed set of
/// gradient paints built once per scene; the gradients are defined along a
/// local x axis and the canvas is rotated onto the fold, so they never need
/// rebuilding while the finger moves. What it does allocate per frame is the
/// geometry's small polygon lists (a few dozen Offsets) and the Rects of the
/// image calls: unavoidable with an immutable, testable geometry.
class CurlPainter extends CustomPainter {
  CurlPainter({required this.scene, this.layers = CurlLayers.all, this.drawImages = true})
    : super(repaint: scene) {
    final e = scene.shadowExtent;
    _foldShadow = _gradient(e, const <Color>[Color(0x66000000), Color(0x2E000000), Color(0x00000000)], const <double>[
      0,
      0.35,
      1,
    ]);
    _edgeShadow = _gradient(e * 0.8, const <Color>[Color(0x47000000), Color(0x00000000)], const <double>[0, 1]);
    _backShade = _gradient(
      e * 3,
      const <Color>[Color(0x40000000), Color(0x00000000), Color(0x42FFFFFF), Color(0x00FFFFFF)],
      const <double>[0, 0.14, 0.4, 0.78],
    );
    final full = scene.rects.full;
    _reach = math.sqrt(full.width * full.width + full.height * full.height);
    _paper = Paint()..color = scene.paperTint;
  }

  final CurlScene scene;
  final CurlLayers layers;
  final bool drawImages;

  late final Paint _foldShadow;
  late final Paint _edgeShadow;
  late final Paint _backShade;
  late final Paint _paper;
  late final double _reach;

  final Paint _image = Paint()..filterQuality = FilterQuality.low;
  final Paint _darken = Paint()..color = const Color(0x14000000);
  final Path _path = Path();
  final Float64List _matrix = Float64List(16);

  static Paint _gradient(double length, List<Color> colors, List<double> stops) =>
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(length, 0), colors, stops);

  void _clip(Canvas canvas, List<Offset> polygon) {
    _path
      ..reset()
      ..addPolygon(polygon, true);
    canvas.clipPath(_path);
  }

  void _page(Canvas canvas, ui.Image? image, Rect dst) {
    if (image == null) {
      canvas.drawRect(dst, _paper);
    } else {
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), dst, _image);
    }
  }

  /// Runs on a canvas whose x axis points along [dir] from [origin].
  void _alongward(Canvas canvas, Offset origin, Offset dir, Rect rect, Paint paint) {
    canvas
      ..save()
      ..translate(origin.dx, origin.dy)
      ..rotate(math.atan2(dir.dy, dir.dx))
      ..drawRect(rect, paint)
      ..restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = scene.geometry;
    final r = scene.rects;

    if (drawImages) {
      if (r.other != null) _page(canvas, scene.other, r.other!);
      if (!g.isFlat) _page(canvas, scene.under, r.leaf);
    }

    if (layers.has(CurlLayers.revealedShadow) && g.revealedShadowPolygon.length >= 3) {
      canvas.save();
      _clip(canvas, g.revealedShadowPolygon);
      _alongward(canvas, g.foldPoint, -g.foldNormal, Rect.fromLTRB(0, -_reach, scene.shadowExtent, _reach), _foldShadow);
      canvas.restore();
    }

    if (drawImages) {
      if (g.flatPolygon.length >= 3) {
        canvas.save();
        if (!g.isFlat) _clip(canvas, g.flatPolygon);
        _page(canvas, scene.front, r.leaf);
        canvas.restore();
      }
    }

    if (layers.has(CurlLayers.edgeShadow) && g.edgeShadowPolygon.length >= 3) {
      canvas.save();
      _clip(canvas, g.edgeShadowPolygon);
      _alongward(canvas, g.touch, g.edgeShadowDirection, Rect.fromLTRB(0, -_reach, scene.shadowExtent * 0.8, _reach), _edgeShadow);
      canvas.restore();
    }

    if (g.backPolygon.length >= 3 && (drawImages || layers.has(CurlLayers.backShade))) {
      canvas.save();
      _clip(canvas, g.backPolygon);
      if (drawImages) {
        canvas.save();
        g.writeBackTransform(_matrix, throughSpine: r.spread);
        canvas.transform(_matrix);
        if (r.spread) {
          _page(canvas, scene.back, r.other!);
        } else {
          _page(canvas, scene.front, r.leaf);
        }
        canvas.restore();
      }
      if (layers.has(CurlLayers.backShade)) {
        // The back of a page is a little darker, with a soft highlight along
        // the curl where the paper bends towards the light.
        canvas.drawPaint(_darken);
        _alongward(canvas, g.foldPoint, g.foldNormal, Rect.fromLTRB(0, -_reach, scene.shadowExtent * 3, _reach), _backShade);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CurlPainter old) =>
      old.scene != scene || old.layers != layers || old.drawImages != drawImages;
}

/// The fallback while a page has no image yet: the live widgets themselves,
/// clipped and mirrored with ordinary widgets, and the same shading painters
/// in between. Heavier than the image path, but never janky and never blank.
class CurlLiveLayers extends StatelessWidget {
  const CurlLiveLayers({
    super.key,
    required this.scene,
    required this.front,
    required this.under,
    required this.back,
    required this.other,
  });

  final CurlScene scene;

  /// Each is already positioned in the reader's coordinates (a Positioned).
  final Widget front;
  final Widget under;
  final Widget back;
  final Widget? other;

  @override
  Widget build(BuildContext context) {
    final spread = scene.rects.spread;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ?other,
          under,
          RepaintBoundary(
            child: CustomPaint(
              painter: CurlPainter(scene: scene, layers: CurlLayers.revealedShadow, drawImages: false),
            ),
          ),
          ClipPath(
            clipper: _PolygonClipper(scene, (g) => g.flatPolygon),
            child: Stack(fit: StackFit.expand, children: <Widget>[front]),
          ),
          RepaintBoundary(
            child: CustomPaint(
              painter: CurlPainter(scene: scene, layers: CurlLayers.edgeShadow, drawImages: false),
            ),
          ),
          ClipPath(
            clipper: _PolygonClipper(scene, (g) => g.backPolygon),
            child: AnimatedBuilder(
              animation: scene,
              child: Stack(fit: StackFit.expand, children: <Widget>[back]),
              builder: (context, child) =>
                  Transform(transform: scene.geometry.backTransform(throughSpine: spread), child: child),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              painter: CurlPainter(scene: scene, layers: CurlLayers.backShade, drawImages: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolygonClipper extends CustomClipper<Path> {
  _PolygonClipper(this.scene, this.pick) : super(reclip: scene);

  final CurlScene scene;
  final List<Offset> Function(CurlGeometry) pick;

  @override
  Path getClip(Size size) {
    final poly = pick(scene.geometry);
    final p = Path();
    if (poly.length >= 3) p.addPolygon(poly, true);
    return p;
  }

  @override
  bool shouldReclip(_PolygonClipper old) => old.scene != scene;
}
