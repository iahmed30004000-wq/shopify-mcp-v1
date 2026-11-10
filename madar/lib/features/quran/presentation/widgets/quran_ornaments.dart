import 'package:flutter/material.dart';

import '../../../../core/design/painters/painters.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../domain/quran_meta.dart';
import '../../domain/tajweed.dart';
import 'ayah_spans.dart';

/// The ornamental sura title of the mushaf: a brass-framed cartouche with
/// rub-el-hizb stars at both ends and «سورة …» in the naskh face.
class SurahCartouche extends StatelessWidget {
  const SurahCartouche({super.key, required this.surah, this.subtitle, this.scale = 1});

  final SurahInfo surah;

  /// A small line under the title (e.g. Makki · 286 ayat).
  final String? subtitle;

  /// Follows the page's text size.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final titleSize = 22.0 * scale;
    final height = 50.0 * scale;
    return Semantics(
      header: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: CustomPaint(
              painter: _CartouchePainter(
                border: t.brass,
                inner: t.metalGold.withValues(alpha: 0.55),
                fill: t.accentSoft,
                glow: t.accentGlow,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: height * 0.62),
                child: Row(
                  children: [
                    IslamicStar(size: height * 0.44, style: IslamicStarStyle.rubElHizb),
                    Expanded(
                      child: Text(
                        'سورة ${surah.nameArabic}',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: MadarTypography.naskhFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: titleSize,
                          height: 1.2,
                          color: t.gold,
                        ),
                      ),
                    ),
                    IslamicStar(size: height * 0.44, style: IslamicStarStyle.rubElHizb),
                  ],
                ),
              ),
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: EdgeInsets.only(top: 4 * scale),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartouchePainter extends CustomPainter {
  const _CartouchePainter({required this.border, required this.inner, required this.fill, required this.glow});

  final Color border;
  final Color inner;
  final Color fill;
  final Color glow;

  /// A long lozenge whose ends are pointed arches (like the printed titles).
  Path _shape(Rect r) {
    final h = r.height;
    final tip = h * 0.5;
    final p = Path()
      ..moveTo(r.left, r.center.dy)
      ..quadraticBezierTo(r.left + tip * 0.35, r.top, r.left + tip, r.top)
      ..lineTo(r.right - tip, r.top)
      ..quadraticBezierTo(r.right - tip * 0.35, r.top, r.right, r.center.dy)
      ..quadraticBezierTo(r.right - tip * 0.35, r.bottom, r.right - tip, r.bottom)
      ..lineTo(r.left + tip, r.bottom)
      ..quadraticBezierTo(r.left + tip * 0.35, r.bottom, r.left, r.center.dy)
      ..close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    final shape = _shape(outer.deflate(1));
    canvas.drawPath(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fill, fill.withValues(alpha: fill.a * 0.45)],
        ).createShader(outer),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = border,
    );
    canvas.drawPath(
      _shape(outer.deflate(5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = inner,
    );
  }

  @override
  bool shouldRepaint(_CartouchePainter old) =>
      old.border != border || old.inner != inner || old.fill != fill || old.glow != glow;
}

/// The basmala centred under a sura title.
class BasmalaLine extends StatelessWidget {
  const BasmalaLine({
    super.key,
    required this.text,
    required this.marks,
    required this.fontSize,
    this.tajweed = true,
    this.highlight,
  });

  final String text;
  final List<TajweedMark> marks;
  final double fontSize;
  final bool tajweed;

  /// Lights the line (the reciter is reciting it).
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    var base = MadarTypography.quran(t, size: fontSize).copyWith(height: 1.9);
    if (highlight != null) base = base.copyWith(background: Paint()..color = highlight!);
    return Text.rich(
      TextSpan(children: AyahSpans.plain(text, marks, base, t, tajweed: tajweed)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
    );
  }
}

/// An ayah number in an eight-point star (verse cards, bookmark rows).
class AyahMedallion extends StatelessWidget {
  const AyahMedallion({super.key, required this.label, this.size = 40, this.color, this.active = false});

  /// The number, already formatted.
  final String label;
  final double size;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IslamicStar(size: size, filled: false, color: color ?? t.brass, strokeWidth: 1.3, glow: active),
          IslamicStar(size: size * 0.78, filled: false, color: (color ?? t.brass).withValues(alpha: 0.45), rotation: 0.39),
          // Kept inside the star's inner field at any text size.
          SizedBox(
            width: size * 0.62,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: MadarTypography.numerals(t, size: size * (label.length > 2 ? 0.28 : 0.34), color: color ?? t.gold)
                    .copyWith(fontWeight: FontWeight.w600, height: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A mushaf page's double brass frame around its text.
class MushafFrame extends StatelessWidget {
  const MushafFrame({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return CustomPaint(
      painter: _FramePainter(
        fill: t.isDark ? t.space1.withValues(alpha: 0.72) : t.space2.withValues(alpha: 0.88),
        outer: t.brass,
        inner: t.metalGold.withValues(alpha: 0.4),
        radius: t.radiusL,
        corner: t.gold,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({
    required this.fill,
    required this.outer,
    required this.inner,
    required this.radius,
    required this.corner,
  });

  final Color fill;
  final Color outer;
  final Color inner;
  final double radius;
  final Color corner;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r.deflate(0.8), Radius.circular(radius));
    canvas.drawRRect(rr, Paint()..color = fill);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = outer,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(6), Radius.circular(radius - 5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = inner,
    );
    // Small eight-point stars in the four corners.
    const s = 9.0;
    final painter = IslamicStarPainter(fillColor: corner.withValues(alpha: 0.85));
    for (final c in [
      Offset(radius * 0.55, radius * 0.55),
      Offset(size.width - radius * 0.55, radius * 0.55),
      Offset(radius * 0.55, size.height - radius * 0.55),
      Offset(size.width - radius * 0.55, size.height - radius * 0.55),
    ]) {
      canvas.save();
      canvas.translate(c.dx - s / 2, c.dy - s / 2);
      painter.paint(canvas, const Size.square(s));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.fill != fill || old.outer != outer || old.inner != inner || old.radius != radius || old.corner != corner;
}

/// A glass row with a coloured stripe on its start edge (bookmarks, the
/// tajweed legend).
class StripeBox extends StatelessWidget {
  const StripeBox({super.key, required this.stripe, required this.child, this.padding = EdgeInsets.zero});

  final Color stripe;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(t.radiusM);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.glassFill,
          borderRadius: radius,
          border: Border.all(color: t.glassBorder),
        ),
        child: Stack(
          children: [
            PositionedDirectional(start: 0, top: 0, bottom: 0, width: 3, child: ColoredBox(color: stripe)),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
