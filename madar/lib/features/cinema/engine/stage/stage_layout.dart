import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show EdgeInsets;

import '../core/era_skin.dart';

/// The theatre's measurements for one screen size (logical px): proscenium
/// header and pilasters, the arch of the opening, valance, curtains and the
/// footlight lip, the play area and the HUD area.
///
/// ```
///  ┌──────────────── header (hdr) ─────────────────┐
///  │pil╭─────────── rim (arch) ─────────────╮  pil │
///  │   │~~~~~~~~ valance swags ~~~~~~~~~~~~~│      │
///  │   │  ┌──────────── hud ─────────────┐  │      │
///  │   │  │                              │  │      │
///  │   │  │   play (camera viewport)     │  │      │
///  │   │  └──────────────────────────────┘  │      │
///  ├───┴────────── footlight lip (foot) ───┴───────┤
///  └────────────────────────────────────────────────┘
/// ```
class StageLayout {
  StageLayout._(this.screen, this.style);

  factory StageLayout.compute(Size screen, EdgeInsets safe, StageStyle style) {
    final l = StageLayout._(screen, style);
    final w = screen.width, h = screen.height;
    // A landscape screen gets a proportionally slimmer frame.
    final unit = math.min(w, h * 0.62);
    l.pil = math.max(12, unit * style.sideWidth * 0.58);
    l.hdr = math.max(math.min(h * style.valanceHeight, unit * 0.2), safe.top + 22);
    l.valDepth = math.min(h * style.valanceHeight * 0.58, unit * 0.12);
    l.foot = h * style.footlightHeight + safe.bottom * 0.5;
    l.footTop = h - l.foot;
    l.drop = switch (style.proscenium) {
      ProsceniumStyle.picturePalace => unit * 0.075,
      ProsceniumStyle.artDeco => unit * 0.026,
      ProsceniumStyle.noirArch => unit * 0.1,
      ProsceniumStyle.atomic => unit * 0.07,
      ProsceniumStyle.marquee => 5,
      ProsceniumStyle.neon => 10,
    };
    final inset = unit * 0.02;
    l.play = Rect.fromLTRB(l.pil + inset, l.hdr + l.valDepth * 0.35, w - l.pil - inset, l.footTop);
    l.hud = Rect.fromLTRB(
      math.max(l.play.left + 6, safe.left + 8),
      math.max(l.hdr + l.valDepth + 6, safe.top + 8),
      math.min(l.play.right - 6, w - safe.right - 8),
      math.max(l.hdr + l.valDepth + 60, math.min(l.play.bottom - 8, h - safe.bottom - l.foot - 6)),
    );
    l.curtainOpenWidth = l.pil + unit * 0.1;
    l.curtainClosedWidth = w / 2 + 8;
    l.curtainTop = l.hdr - 8;
    l.curtainBottom = l.footTop + l.foot * 0.45;
    l._buildRim();
    return l;
  }

  final Size screen;
  final StageStyle style;

  /// Pilaster width, header height, arch drop (or step), valance depth
  /// below the header, footlight lip height and its top edge.
  late final double pil, hdr, drop, valDepth, foot, footTop;

  /// Camera viewport and HUD area (screen px).
  late final Rect play, hud;

  /// Side curtain width (from the screen edge to the leading edge) when
  /// open and when closed; the curtain rod and the hem.
  late final double curtainOpenWidth, curtainClosedWidth, curtainTop, curtainBottom;

  /// The opening's edge: an open path from the bottom of the left pilaster
  /// up round the arch and down the right pilaster.
  final Path rim = Path();

  /// The proscenium body: the screen above the lip minus the opening.
  final Path body = Path()..fillType = PathFillType.evenOdd;

  /// Tie-back point of the curtains (fraction of the curtain height; the
  /// curtain shader uses the same constant).
  static const double tieY = 0.58;

  double get width => screen.width;
  double get height => screen.height;

  void _buildRim() {
    final w = width;
    final l = pil, r = w - pil, top = hdr, bottom = footTop + 1;
    const k = 0.5523;
    rim.moveTo(l, bottom);
    switch (style.proscenium) {
      case ProsceniumStyle.picturePalace:
        // A segmental arch springing from the pilasters.
        rim
          ..lineTo(l, top + drop)
          ..quadraticBezierTo(w / 2, top - drop, r, top + drop);
      case ProsceniumStyle.artDeco:
        final s = drop;
        rim
          ..lineTo(l, top + 3 * s)
          ..lineTo(l + s, top + 3 * s)
          ..lineTo(l + s, top + 2 * s)
          ..lineTo(l + 2 * s, top + 2 * s)
          ..lineTo(l + 2 * s, top + s)
          ..lineTo(l + 3 * s, top + s)
          ..lineTo(l + 3 * s, top)
          ..lineTo(r - 3 * s, top)
          ..lineTo(r - 3 * s, top + s)
          ..lineTo(r - 2 * s, top + s)
          ..lineTo(r - 2 * s, top + 2 * s)
          ..lineTo(r - s, top + 2 * s)
          ..lineTo(r - s, top + 3 * s)
          ..lineTo(r, top + 3 * s);
      case ProsceniumStyle.noirArch || ProsceniumStyle.atomic || ProsceniumStyle.marquee || ProsceniumStyle.neon:
        final rr = drop;
        rim
          ..lineTo(l, top + rr)
          ..cubicTo(l, top + rr * (1 - k), l + rr * (1 - k), top, l + rr, top)
          ..lineTo(r - rr, top)
          ..cubicTo(r - rr * (1 - k), top, r, top + rr * (1 - k), r, top + rr);
    }
    rim.lineTo(r, bottom);
    final opening = Path.from(rim)..close();
    body
      ..addRect(Rect.fromLTRB(-2, -2, w + 2, bottom))
      ..addPath(opening, Offset.zero);
  }

  /// Y of the opening's top edge at [x] (for placing things under the arch).
  double rimTopAt(double x) {
    final w = width;
    final l = pil, r = w - pil;
    final cx = x.clamp(l, r);
    switch (style.proscenium) {
      case ProsceniumStyle.picturePalace:
        // Quadratic from (l, top+drop) via (w/2, top-drop) to (r, top+drop).
        final t = (cx - l) / (r - l);
        return (1 - t) * (1 - t) * (hdr + drop) + 2 * (1 - t) * t * (hdr - drop) + t * t * (hdr + drop);
      case ProsceniumStyle.artDeco:
        final d = math.min(cx - l, r - cx);
        final steps = (3 - (d / drop).floor()).clamp(0, 3);
        return hdr + steps * drop;
      case _:
        final d = math.min(cx - l, r - cx);
        if (d >= drop) return hdr;
        final u = 1 - d / drop;
        return hdr + drop * (1 - math.sqrt(math.max(0, 1 - u * u)));
    }
  }
}
