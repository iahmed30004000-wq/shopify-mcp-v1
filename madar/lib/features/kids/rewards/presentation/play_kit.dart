// Small building blocks shared by the child-facing screens in stories/, games/
// and rewards/: the kids palette (docs/kids/DESIGN.md section 2), a header with
// the star chip and the home button, big buttons (>= 64 dp) and the khatam
// (8-point star) path. Nothing here is red: a child is never told he is wrong.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../../core/kids_section.dart';

/// The approved kids palette.
abstract final class KidsColors {
  static const night900 = Color(0xFF17143F);
  static const night800 = Color(0xFF221E5A);
  static const night700 = Color(0xFF2F2A78);
  static const night500 = Color(0xFF5650B0);
  static const night300 = Color(0xFFA9A5E6);
  static const night100 = Color(0xFFE6E4FA);
  static const sun500 = Color(0xFFF5B431);
  static const sun300 = Color(0xFFFFD479);
  static const sun100 = Color(0xFFFFF0CC);
  static const sun700 = Color(0xFFA8680F);
  static const teal700 = Color(0xFF17706C);
  static const teal500 = Color(0xFF2FA59C);
  static const teal200 = Color(0xFFB6E6DF);
  static const teal100 = Color(0xFFE2F5F1);
  static const rose500 = Color(0xFFE26A89);
  static const rose300 = Color(0xFFF6A9BC);
  static const rose100 = Color(0xFFFCE3EA);
  static const rose700 = Color(0xFFA93556);
  // The soft "try again" state: amber, never red.
  static const retry = Color(0xFFF7A94B);
  static const retryFill = Color(0xFFFFEBD0);
  static const retryText = Color(0xFF8A4B05);
  static const paper = Color(0xFFFFF8EA);
  static const sand = Color(0xFFF7E9CF);
  static const sand2 = Color(0xFFEBD5A8);
  static const ink = Color(0xFF26214F);
  static const ink2 = Color(0xFF5A5482);
}

/// Text styles from the design's type scale.
abstract final class KidsText {
  static const display = TextStyle(
    fontFamily: 'ReemKufi',
    fontWeight: FontWeight.w700,
    fontSize: 34,
    height: 1.25,
    color: KidsColors.ink,
  );
  static const title = TextStyle(
    fontFamily: 'ReemKufi',
    fontWeight: FontWeight.w700,
    fontSize: 26,
    height: 1.3,
    color: KidsColors.ink,
  );
  static const subtitle = TextStyle(
    fontFamily: 'ReemKufi',
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.35,
    color: KidsColors.ink,
  );
  static const body = TextStyle(
    fontFamily: 'PlexArabic',
    fontWeight: FontWeight.w500,
    fontSize: 20,
    height: 1.6,
    color: KidsColors.ink,
  );
  static const small = TextStyle(
    fontFamily: 'PlexArabic',
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 1.5,
    color: KidsColors.ink2,
  );
  static const button = TextStyle(
    fontFamily: 'ReemKufi',
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.2,
    color: KidsColors.night900,
  );
}

/// A number written the way the screen's language writes it (Arabic-Indic in
/// Arabic, as in the school books).
String kidsNumber(BuildContext context, int n) {
  if (Localizations.localeOf(context).languageCode != 'ar') return '$n';
  const d = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) => c == '-' ? '-' : d[int.parse(c)]).join();
}

/// `m:ss` in the screen's digits.
String kidsClock(BuildContext context, Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final mm = s ~/ 60, ss = s % 60;
  final text = '$mm:${ss.toString().padLeft(2, '0')}';
  if (Localizations.localeOf(context).languageCode != 'ar') return text;
  const dg = '٠١٢٣٤٥٦٧٨٩';
  return text.split('').map((c) => c == ':' ? ':' : dg[int.parse(c)]).join();
}

/// The 8-point star (two squares: the khatam) around [c].
Path khatamPath(Offset c, double r, {double innerRatio = 0.765}) {
  final path = Path();
  const n = 8;
  for (var i = 0; i < n * 2; i++) {
    final a = -math.pi / 2 + i * math.pi / n;
    final rad = i.isEven ? r : r * innerRatio;
    final p = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

/// A small gold khatam, the star of the child's collection.
class KhatamStarIcon extends StatelessWidget {
  const KhatamStarIcon({super.key, this.size = 28, this.color = KidsColors.sun500, this.core = KidsColors.night800});

  final double size;
  final Color color;
  final Color core;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _KhatamPainter(color, core)),
  );
}

class _KhatamPainter extends CustomPainter {
  _KhatamPainter(this.color, this.core);
  final Color color, core;
  final Paint _p = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawPath(khatamPath(c, r), _p..color = color);
    canvas.drawPath(khatamPath(c, r * 0.42, innerRatio: 0.6), _p..color = core);
  }

  @override
  bool shouldRepaint(_KhatamPainter old) => old.color != color || old.core != core;
}

/// Header of a child screen: the home button, the title and the star chip.
class PlayHeader extends ConsumerWidget {
  const PlayHeader({super.key, required this.title, this.dark = false, this.onHome, this.showStars = true});

  final String title;

  /// On a night background: light title, outlined chip.
  final bool dark;
  final VoidCallback? onHome;
  final bool showStars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final stars = showStars ? ref.watch(kidsStarCountProvider) : 0;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      child: Row(
        children: [
          RoundPlayButton(
            icon: Icons.home_rounded,
            tooltip: l.kidsPlayHome,
            background: dark ? KidsColors.night100 : KidsColors.paper,
            foreground: KidsColors.night800,
            onPressed: onHome ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: KidsText.title.copyWith(color: dark ? Colors.white : KidsColors.ink),
              ),
            ),
          ),
          if (showStars) StarChip(count: stars, outlined: dark) else const SizedBox(width: 64),
        ],
      ),
    );
  }
}

/// The star count pill. It also says its value to a screen reader.
class StarChip extends StatelessWidget {
  const StarChip({super.key, required this.count, this.outlined = false});

  final int count;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Semantics(
      label: l.kidsPlayStarsSemantics(kidsNumber(context, count)),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: KidsColors.night800,
          borderRadius: BorderRadius.circular(32),
          border: outlined ? Border.all(color: KidsColors.night300.withValues(alpha: .5), width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kidsNumber(context, count),
              style: KidsText.subtitle.copyWith(color: Colors.white, fontSize: 22),
            ),
            const SizedBox(width: 6),
            const KhatamStarIcon(size: 26),
          ],
        ),
      ),
    );
  }
}

/// A 64 dp round icon button.
class RoundPlayButton extends StatelessWidget {
  const RoundPlayButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.background = KidsColors.paper,
    this.foreground = KidsColors.night800,
    this.size = 64,
    this.iconSize = 32,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color background, foreground;
  final double size, iconSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      excludeSemantics: true,
      child: Material(
        color: enabled ? background : background.withValues(alpha: .45),
        shape: const CircleBorder(),
        elevation: enabled ? 2 : 0,
        shadowColor: KidsColors.night900.withValues(alpha: .3),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, size: iconSize, color: enabled ? foreground : foreground.withValues(alpha: .5)),
          ),
        ),
      ),
    );
  }
}

/// A wide, rounded button (min 64 dp tall). Gold by default.
class BigPlayButton extends StatelessWidget {
  const BigPlayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.background = KidsColors.sun500,
    this.foreground = KidsColors.night900,
    this.height = 64,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color background, foreground;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      label: label,
      child: Material(
        color: enabled ? background : background.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(height / 2),
        elevation: enabled ? 2 : 0,
        shadowColor: KidsColors.night900.withValues(alpha: .3),
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height, minWidth: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (icon != null) ...[Icon(icon, size: 30, color: foreground), const SizedBox(width: 10)],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: KidsText.button.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
