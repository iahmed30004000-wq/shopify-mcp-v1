import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/islamic_geometry/islamic_geometry.dart';
import '../../../core/design/tokens.dart';
import '../application/ramadan_providers.dart';

/// The Faith planet's Ramadan atmosphere, restrained and original: a crescent
/// with a small star between two pairs of hanging lanterns on a sagging
/// garland, a thin row of the app's own geometry under it, and a warmer tint
/// over the page.
///
/// It costs no frames: the strip is drawn once per size into a cached picture
/// ([PatternPictureCache], the geometry folder's own cache) and never
/// animates - so there is nothing for reduced motion to switch off, and the
/// page stays as still as it was. Light and dark themes both read: the metals
/// come from the theme's tokens, the glow is a low-alpha wash.
///
/// It exists only while [ramadanAtmosphereProvider] says so - from the first
/// day of Ramadan to the last, never on 1 Shawwal, never when he switched
/// «أجواء رمضان» off.
class RamadanAtmosphereBand extends StatelessWidget {
  const RamadanAtmosphereBand({super.key});

  /// The strip's height (the divider below adds its own).
  static const double height = 84;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(
                painter: RamadanSkyPainter(
                  metal: t.isDark ? t.metalGold : t.gold,
                  glow: t.gold,
                  thread: t.brass,
                  dark: t.isDark,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
            child: PatternDivider(
              spec: const PatternSpec(family: PatternFamily.square4, lineWidth: 1),
              color: t.brass,
              height: 18,
              opacity: t.isDark ? 0.55 : 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

/// The crescent, the star and the lanterns. Symmetric about the middle, so it
/// needs no right-to-left handling.
class RamadanSkyPainter extends CustomPainter {
  RamadanSkyPainter({required this.metal, required this.glow, required this.thread, required this.dark})
    : _config = ('ramadanSky', metal, glow, thread, dark);

  final Color metal;
  final Color glow;
  final Color thread;
  final bool dark;
  final Object _config;

  /// Lanterns: where they hang along the garland (0..1) and how far down.
  static const List<(double, double)> _lanterns = [(0.1, 26), (0.26, 42), (0.74, 42), (0.9, 26)];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawPicture(
      PatternPictureCache.find(_config, size) ?? PatternPictureCache.record(_config, size, (c) => _draw(c, size)),
    );
  }

  double _garlandY(double f) => (1 - f) * (1 - f) * 4 + 2 * (1 - f) * f * 22 + f * f * 4;

  void _draw(Canvas canvas, Size size) {
    final w = size.width;
    final line = Paint()
      ..color = thread.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final garland = Path()
      ..moveTo(0, 4)
      ..quadraticBezierTo(w / 2, 22, w, 4);
    canvas.drawPath(garland, line);

    // The crescent hangs from the middle of the garland.
    final cx = w / 2, topY = _garlandY(0.5);
    const r = 17.0, drop = 12.0;
    final cy = topY + drop + r;
    canvas.drawLine(Offset(cx, topY), Offset(cx, cy - r + 2), line);
    canvas.drawCircle(
      Offset(cx, cy),
      r * 1.9,
      Paint()
        ..color = glow.withValues(alpha: dark ? 0.16 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    final disc = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    final bite = Path()..addOval(Rect.fromCircle(center: Offset(cx + r * 0.42, cy - r * 0.18), radius: r * 0.82));
    canvas.drawPath(Path.combine(PathOperation.difference, disc, bite), Paint()..color = metal);
    _star(canvas, Offset(cx + r * 0.78, cy - r * 0.2), 4.6, Paint()..color = metal);

    for (final (f, length) in _lanterns) {
      _lantern(canvas, Offset(f * w, _garlandY(f)), length, line);
    }
  }

  void _lantern(Canvas canvas, Offset anchor, double length, Paint line) {
    final bodyTop = anchor.dy + length;
    canvas.drawLine(anchor, Offset(anchor.dx, bodyTop), line);
    const halfW = 7.5, bodyH = 17.0;
    final cx = anchor.dx;
    // The glow first, so the metal sits on it.
    canvas.drawCircle(
      Offset(cx, bodyTop + bodyH / 2 + 2),
      13,
      Paint()
        ..color = glow.withValues(alpha: dark ? 0.2 : 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final cap = Path()
      ..moveTo(cx - 3.2, bodyTop - 4)
      ..lineTo(cx + 3.2, bodyTop - 4)
      ..lineTo(cx + halfW * 0.8, bodyTop + 1)
      ..lineTo(cx - halfW * 0.8, bodyTop + 1)
      ..close();
    final body = Path()
      ..moveTo(cx - halfW * 0.8, bodyTop + 1)
      ..quadraticBezierTo(cx - halfW * 1.25, bodyTop + bodyH * 0.55, cx - halfW * 0.55, bodyTop + bodyH)
      ..lineTo(cx + halfW * 0.55, bodyTop + bodyH)
      ..quadraticBezierTo(cx + halfW * 1.25, bodyTop + bodyH * 0.55, cx + halfW * 0.8, bodyTop + 1)
      ..close();
    final fill = Paint()..color = metal.withValues(alpha: dark ? 0.9 : 0.85);
    canvas.drawPath(cap, fill);
    canvas.drawPath(body, Paint()..color = metal.withValues(alpha: dark ? 0.3 : 0.22));
    canvas.drawPath(
      body,
      Paint()
        ..color = metal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(Offset(cx, bodyTop + 2), Offset(cx, bodyTop + bodyH - 1), Paint()..color = metal.withValues(alpha: 0.6)..strokeWidth = 0.8);
    canvas.drawCircle(Offset(cx, bodyTop + bodyH + 3), 1.6, fill);
  }

  /// A five-pointed star, filled.
  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(RamadanSkyPainter old) => old._config != _config;
}

/// The warmer tint over the Faith page: a faint wash of the theme's gold that
/// fades out down the page. Ignores touches, draws nothing animated.
class RamadanTint extends StatelessWidget {
  const RamadanTint({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                t.gold.withValues(alpha: t.isDark ? 0.1 : 0.08),
                t.gold.withValues(alpha: t.isDark ? 0.04 : 0.03),
                t.gold.withValues(alpha: 0),
              ],
              stops: const [0, 0.35, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps [child] (the Faith hub) in the tint while the atmosphere is on.
class RamadanAtmosphereScope extends ConsumerWidget {
  const RamadanAtmosphereScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(ramadanAtmosphereProvider)) return child;
    return Stack(children: [const Positioned.fill(child: RamadanTint()), child]);
  }
}
