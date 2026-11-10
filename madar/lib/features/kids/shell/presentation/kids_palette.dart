import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The kids section's colours and type, exactly as docs/kids/DESIGN.md fixes
/// them (light paper and indigo night: the child sees at once he is somewhere
/// else than the adult app).
abstract final class KidsColors {
  static const Color night900 = Color(0xFF17143F);
  static const Color night800 = Color(0xFF221E5A);
  static const Color night700 = Color(0xFF2F2A78);
  static const Color night500 = Color(0xFF5650B0);
  static const Color night300 = Color(0xFFA9A5E6);
  static const Color night100 = Color(0xFFE6E4FA);
  static const Color sun500 = Color(0xFFF5B431);
  static const Color sun300 = Color(0xFFFFD479);
  static const Color sun100 = Color(0xFFFFF0CC);
  static const Color teal700 = Color(0xFF17706C);
  static const Color teal500 = Color(0xFF2FA59C);
  static const Color teal200 = Color(0xFFB6E6DF);
  static const Color teal100 = Color(0xFFE2F5F1);
  static const Color rose500 = Color(0xFFE26A89);
  static const Color rose100 = Color(0xFFFCE3EA);
  static const Color paper = Color(0xFFFFF8EA);
  static const Color sand = Color(0xFFF7E9CF);
  static const Color sand2 = Color(0xFFEBD5A8);
  static const Color ink = Color(0xFF26214F);
  static const Color ink2 = Color(0xFF5A5482);
}

/// Type: ReemKufi for headings, IBM Plex Sans Arabic for reading.
abstract final class KidsText {
  static const String display = 'ReemKufi';
  static const String body = 'PlexArabic';

  static TextStyle title(Color color, {double size = 30}) =>
      TextStyle(fontFamily: display, fontSize: size, height: 1.3, fontWeight: FontWeight.w700, color: color);

  static TextStyle text(Color color, {double size = 20, FontWeight weight = FontWeight.w500}) =>
      TextStyle(fontFamily: body, fontSize: size, height: 1.5, fontWeight: weight, color: color);
}

/// The smallest thing a child may be asked to hit.
const double kKidsMinTarget = 64;

/// The khatam: two squares turned 45 degrees (an eight-point star). One shape,
/// repeated everywhere, drawn without allocating per frame.
class KhatamStar extends StatelessWidget {
  const KhatamStar({super.key, required this.size, required this.color, this.child});

  final double size;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _KhatamPainter(color),
      child: child == null ? null : Center(child: child),
    ),
  );
}

class _KhatamPainter extends CustomPainter {
  _KhatamPainter(this.color) : _paint = Paint()..color = color;

  final Color color;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final half = size.shortestSide / 2;
    // Two squares whose corners reach the circle of radius [half].
    final side = half * math.sqrt2;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..drawRect(Rect.fromCenter(center: Offset.zero, width: side, height: side), _paint)
      ..rotate(math.pi / 4)
      ..drawRect(Rect.fromCenter(center: Offset.zero, width: side, height: side), _paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_KhatamPainter old) => old.color != color;
}

/// A starry night for the gate and the end screen: fixed positions, painted
/// once, never animated.
class KidsNightBackdrop extends StatelessWidget {
  const KidsNightBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [KidsColors.night900, KidsColors.night800, KidsColors.night700],
      ),
    ),
    child: CustomPaint(painter: _StarsPainter(), child: child),
  );
}

class _StarsPainter extends CustomPainter {
  _StarsPainter() : _paint = Paint()..color = KidsColors.night300.withValues(alpha: 0.55);

  final Paint _paint;

  // Unit-square positions and radii, chosen by hand.
  static const List<(double, double, double)> _stars = [
    (0.08, 0.06, 1.6),
    (0.31, 0.03, 1.2),
    (0.62, 0.08, 1.8),
    (0.91, 0.05, 1.3),
    (0.15, 0.22, 1.1),
    (0.78, 0.2, 1.5),
    (0.46, 0.31, 1.0),
    (0.95, 0.38, 1.6),
    (0.05, 0.47, 1.4),
    (0.55, 0.55, 1.1),
    (0.88, 0.62, 1.2),
    (0.22, 0.7, 1.5),
    (0.67, 0.78, 1.3),
    (0.1, 0.9, 1.2),
    (0.4, 0.94, 1.6),
    (0.84, 0.92, 1.1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, r) in _stars) {
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, _paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => false;
}

/// The kids buttons' fill recipes.
enum KidsButtonTone { gold, teal, paper, ghost }

/// A big, forgiving button: at least [kKidsMinTarget] high (80 for the main
/// action), a label that wraps instead of clipping at text scale 1.3.
class KidsBigButton extends StatelessWidget {
  const KidsBigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = KidsButtonTone.gold,
    this.height = 76,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final KidsButtonTone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (fill, border, fg) = switch (tone) {
      KidsButtonTone.gold => (KidsColors.sun500, null, KidsColors.night900),
      KidsButtonTone.teal => (KidsColors.teal700, null, Colors.white),
      KidsButtonTone.paper => (KidsColors.paper, null, KidsColors.ink),
      KidsButtonTone.ghost => (Colors.transparent, KidsColors.sand2, KidsColors.ink2),
    };
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: fill,
          shape: StadiumBorder(side: border == null ? BorderSide.none : BorderSide(color: border, width: 2)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height < kKidsMinTarget ? kKidsMinTarget : height),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (icon != null) ...[Icon(icon, color: fg, size: 28), const SizedBox(width: 12)],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: KidsText.title(fg, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round icon button, [kKidsMinTarget] across.
class KidsRoundButton extends StatelessWidget {
  const KidsRoundButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.background = const Color(0x33FFFFFF),
    this.foreground = Colors.white,
    this.size = kKidsMinTarget,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: size < kKidsMinTarget ? kKidsMinTarget : size,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, color: foreground, size: 30),
        ),
      ),
    ),
  );
}

/// Numbers on kids screens are always Arabic-Indic in Arabic (docs/kids
/// DESIGN §3), whatever the adult digit setting says.
String kidsDigits(BuildContext context, String text) {
  if (Localizations.localeOf(context).languageCode != 'ar') return text;
  const western = '0123456789';
  const indic = '٠١٢٣٤٥٦٧٨٩';
  final out = StringBuffer();
  for (final r in text.runes) {
    final ch = String.fromCharCode(r);
    final i = western.indexOf(ch);
    out.write(i < 0 ? ch : indic[i]);
  }
  return out.toString();
}
