// Rendered-pixel contrast audit: measures the WCAG contrast of every piece of
// text as it is actually painted – glass, gradients, shaders, opacity and
// all – rather than the declared token colours.
//
// For each visible [RenderParagraph] it samples the frame's pixels inside the
// text's glyph boxes: the background is a luminance band of the box away
// from the ink's side (glyphs cover a minority of it), the ink the far 2 %
// tail on the text's side (its glyph cores). Their WCAG ratio is what a
// reader sees. Icons (solid shapes) take their ground from a thin ring
// around them; a tight, dense text shadow counts as the text's own ground
// (WCAG's halo technique for text over images and skies).
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/contrast.dart';

/// One measured piece of text.
class TextContrast {
  const TextContrast({
    required this.text,
    required this.ratio,
    required this.required,
    required this.rect,
    required this.ink,
    required this.background,
    required this.declared,
    required this.fontSize,
    required this.icon,
    required this.obscured,
  });

  /// The painted string (icons: their code point as `U+xxxx`).
  final String text;

  /// Measured ink-on-background contrast.
  final double ratio;

  /// WCAG AA minimum for this text: 4.5 body, 3 large text and icons.
  final double required;

  /// Global rect of the glyph boxes (logical pixels).
  final Rect rect;
  final Color ink, background, declared;
  final double fontSize;
  final bool icon;

  /// Painted far fainter than its colour says (covered, clipped, faded out)
  /// or drawn in a disabled tone (≤ 40 % opacity) – not text a reader is
  /// meant to read; reported, never enforced.
  final bool obscured;

  bool get passes => obscured || ratio >= required;

  @override
  String toString() =>
      '"${text.length > 48 ? '${text.substring(0, 48)}…' : text}" '
      '${ratio.toStringAsFixed(2)}:1 (needs $required) ink ${_hex(ink)} on ${_hex(background)} '
      'declared ${_hex(declared)} ${fontSize.toStringAsFixed(1)}px at '
      '(${rect.left.round()},${rect.top.round()} ${rect.width.round()}×${rect.height.round()})';
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Renders [boundary] at [dpr] and measures every visible text on it.
///
/// Texts smaller than [minArea] logical px² or mostly off-screen are skipped;
/// texts painted far fainter than their colour (covered by another page,
/// clipped, faded out) are marked [TextContrast.obscured].
Future<List<TextContrast>> measureRenderedContrast(
  WidgetTester tester,
  GlobalKey boundary, {
  double dpr = 2.625,
  double minArea = 20,
}) async {
  final box = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late ByteData pixels;
  late int width, height;
  await tester.runAsync(() async {
    final image = await box.toImage(pixelRatio: dpr);
    try {
      width = image.width;
      height = image.height;
      pixels = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
    } finally {
      image.dispose();
    }
  });

  final screen = Offset.zero & box.size;
  final out = <TextContrast>[];
  for (final e in find.byType(RichText).evaluate()) {
    final p = e.renderObject;
    if (p is! RenderParagraph || !p.attached || !p.hasSize || p.size.isEmpty) continue;
    // A page under a sheet or dialog sits behind its modal barrier: inactive
    // content, not something to read (WCAG 1.4.3 exempts it).
    final route = ModalRoute.of(e);
    if (route != null && !route.isCurrent) continue;
    final plain = p.text.toPlainText(includeSemanticsLabels: false, includePlaceholders: false);
    if (plain.trim().isEmpty) continue;
    final style = _firstStyle(p.text);
    final declared = style?.color ?? const Color(0xFF000000);
    final isIcon = (style?.fontFamily ?? '').contains('MaterialIcons');
    final transform = p.getTransformTo(box);
    final boxes = p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: plain.length));
    var rect = Rect.zero;
    final rects = <Rect>[];
    var fullArea = 0.0;
    for (final b in boxes) {
      final full = MatrixUtils.transformRect(transform, b.toRect());
      fullArea += full.width * full.height;
      final r = full.intersect(screen);
      if (r.width <= 0 || r.height <= 0) continue;
      rects.add(r);
      rect = rect.isEmpty ? r : rect.expandToInclude(r);
    }
    if (rects.isEmpty) continue;
    final area = rects.fold<double>(0, (a, r) => a + r.width * r.height);
    // Too small to measure, or mostly off the screen's edge.
    if (area < minArea || area < fullArea * 0.6) continue;

    // Text: every pixel in the glyph boxes (the glyphs cover a minority of
    // them). Icons are solid shapes: their ground is a thin ring around them.
    final ink = _Pixels(pixels, width, height, dpr);
    for (final r in rects) {
      ink.addRect(r);
    }
    if (ink.length < 16) continue;
    Color bg;
    if (isIcon) {
      final ring = _Pixels(pixels, width, height, dpr);
      for (final r in rects) {
        ring.addRing(r, 3);
      }
      if (ring.length < 16) continue;
      bg = ring.band(0.25, 0.75);
    } else {
      // The ground: a band of the box's pixels well away from the ink side.
      final probe = MadarContrast.luminance(MadarContrast.over(declared, ink.band(0.4, 0.6)));
      final lighter = probe >= MadarContrast.luminance(ink.band(0.4, 0.6));
      bg = lighter ? ink.band(0.3, 0.5) : ink.band(0.5, 0.7);
    }
    // A tight, dense halo (a text shadow of ≤ 4 px blur) is the glyphs'
    // own ground – WCAG's halo technique for text over images and skies.
    final halo = style?.shadows?.where((sh) => sh.blurRadius <= 4 && sh.color.a >= 0.75).firstOrNull;
    if (halo != null) bg = MadarContrast.over(halo.color, bg);
    final bgLum = MadarContrast.luminance(bg);
    final opaqueDeclared = MadarContrast.over(declared, bg);
    final lighter = MadarContrast.luminance(opaqueDeclared) >= bgLum;
    // The glyph cores: the most extreme 2 % on the text's side.
    final inkColor = lighter ? ink.band(0.98, 1) : ink.band(0, 0.02);
    final ratio = MadarContrast.ratio(inkColor, bg);
    final declaredRatio = MadarContrast.ratio(opaqueDeclared, bg);

    final size = (style?.fontSize ?? 14) * p.textScaler.scale(1);
    final weight = style?.fontWeight ?? FontWeight.w400;
    final large = size >= 24 || (size >= 18.66 && weight.value >= 600);
    out.add(
      TextContrast(
        text: isIcon ? plain.runes.map((r) => 'U+${r.toRadixString(16)}').join() : plain,
        ratio: ratio,
        required: isIcon || large ? MadarContrast.graphic : MadarContrast.text,
        rect: rect,
        ink: inkColor,
        background: bg,
        // Faded to a disabled state (Material's 38 %: a calendar's
        // out-of-range days) is inactive UI, which WCAG exempts too.
        obscured: ratio < 1.25 || ratio < declaredRatio * 0.5 || declared.a <= 0.4,
        declared: declared,
        fontSize: size,
        icon: isIcon,
      ),
    );
  }
  return out;
}

TextStyle? _firstStyle(InlineSpan span, [TextStyle? inherited]) {
  final own = span.style;
  final style = inherited == null ? own : (own == null ? inherited : inherited.merge(own));
  if (span is TextSpan) {
    if (span.text?.trim().isNotEmpty ?? false) return style;
    for (final child in span.children ?? const <InlineSpan>[]) {
      final found = _firstStyle(child, style);
      if (found != null) return found;
    }
  }
  return null;
}

/// Pixels of a frame gathered from some rects, sortable by luminance.
class _Pixels {
  _Pixels(this._data, this._width, this._height, this._dpr);

  final ByteData _data;
  final int _width, _height;
  final double _dpr;
  final List<int> _colors = [];
  final List<double> _lums = [];
  List<int>? _order;

  int get length => _colors.length;

  void _add(int x, int y) {
    if (x < 0 || y < 0 || x >= _width || y >= _height) return;
    final i = (y * _width + x) * 4;
    final c = Color.fromARGB(255, _data.getUint8(i), _data.getUint8(i + 1), _data.getUint8(i + 2));
    _colors.add(c.toARGB32());
    _lums.add(MadarContrast.luminance(c));
    _order = null;
  }

  void addRect(Rect r) {
    final x0 = (r.left * _dpr).floor(), x1 = (r.right * _dpr).ceil();
    final y0 = (r.top * _dpr).floor(), y1 = (r.bottom * _dpr).ceil();
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        _add(x, y);
      }
    }
  }

  /// A ring [gap] logical px wide just outside [r].
  void addRing(Rect r, double gap) {
    final outer = r.inflate(gap);
    final x0 = (outer.left * _dpr).floor(), x1 = (outer.right * _dpr).ceil();
    final y0 = (outer.top * _dpr).floor(), y1 = (outer.bottom * _dpr).ceil();
    final inner = r.inflate(1);
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        if (inner.contains(Offset(x / _dpr, y / _dpr))) continue;
        _add(x, y);
      }
    }
  }

  /// Mean colour of the pixels between the [from] and [to] luminance
  /// quantiles (0 = darkest, 1 = brightest).
  Color band(double from, double to) {
    final order = _order ??= List<int>.generate(_lums.length, (i) => i)..sort((a, b) => _lums[a].compareTo(_lums[b]));
    final n = order.length;
    final a = (n * from).floor().clamp(0, n - 1);
    final b = math.max(a + 1, (n * to).ceil().clamp(0, n));
    var r = 0.0, g = 0.0, bl = 0.0;
    for (var k = a; k < b; k++) {
      final c = Color(_colors[order[k]]);
      r += c.r;
      g += c.g;
      bl += c.b;
    }
    final count = b - a;
    return Color.from(alpha: 1, red: r / count, green: g / count, blue: bl / count);
  }
}
