/// The pairing's pictures: the searching radar, the four confirmation digits,
/// the room code and its QR, and the partner's avatar.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
// `qr` comes with `pdf` (already a dependency); only its matrix is used.
// ignore: depend_on_referenced_packages
import 'package:qr/qr.dart';

import '../../../core/design/tokens.dart';
import '../../../core/motion/motion.dart';
import '../domain/player_profile.dart';
import '../presentation/widgets/together_visuals.dart';
import '../transport/pairing_state.dart';

/// The partner as a profile the avatar view can draw.
TogetherProfile peerProfile(PairingPeer peer, {PlayerSlot slot = PlayerSlot.two}) => TogetherProfile(
  slot: slot,
  name: peer.name,
  avatar: peer.avatar ?? const TogetherAvatar.initials(),
  colorIndex: peer.colorIndex ?? 5,
);

/// Pulses rippling out from this phone; phones found orbit it as small
/// glowing moons with their initial. Still (rings only) under reduced
/// motion or when [active] is false.
class PairingRadar extends StatefulWidget {
  const PairingRadar({super.key, required this.active, this.found = const [], this.center, this.size = 196});

  final bool active;
  final List<PairingPeer> found;

  /// This phone (its avatar).
  final Widget? center;
  final double size;

  @override
  State<PairingRadar> createState() => _PairingRadarState();
}

class _PairingRadarState extends State<PairingRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PairingRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final run = widget.active && !context.reducedMotion;
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final size = widget.size;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: PairingRadarPainter(
                    progress: _c.value,
                    active: widget.active,
                    ring: t.accent,
                    glow: t.accentGlow,
                    gold: t.gold,
                  ),
                ),
              ),
              if (widget.center != null) widget.center!,
              for (final (i, p) in widget.found.indexed)
                _orbiting(p, i, size, t, text, _c.value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orbiting(PairingPeer p, int i, double size, MadarTokens t, TextTheme text, double progress) {
    final base = (p.id.hashCode % 360) * math.pi / 180 + i * 2.1;
    final drift = context.reducedMotion ? 0.0 : progress * 2 * math.pi * 0.08;
    final r = size * 0.36;
    final angle = base + drift;
    final color = TogetherLook.paletteColor(p.colorIndex ?? (i + 3));
    final initial = p.name.characters.isEmpty ? '?' : p.name.characters.first.toUpperCase();
    return Transform.translate(
      offset: Offset(math.cos(angle) * r, math.sin(angle) * r),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: t.gold, width: 1.2),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 14)],
        ),
        child: Text(
          initial,
          textScaler: TextScaler.noScaling,
          style: text.labelLarge?.copyWith(color: TogetherLook.inkOn(color), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class PairingRadarPainter extends CustomPainter {
  PairingRadarPainter({
    required this.progress,
    required this.active,
    required this.ring,
    required this.glow,
    required this.gold,
  });

  final double progress;
  final bool active;
  final Color ring;
  final Color glow;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    // Fixed orbits (astrolabe rings).
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = gold.withValues(alpha: 0.28);
    for (final f in [0.36, 0.62, 0.9]) {
      canvas.drawCircle(c, maxR * f, orbit);
    }
    // Tick marks on the outer ring.
    final tick = Paint()
      ..strokeWidth = 1
      ..color = gold.withValues(alpha: 0.35);
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * maxR * 0.9, c + d * maxR * (i.isEven ? 0.84 : 0.87), tick);
    }
    if (!active) return;
    // Three ripples, staggered.
    for (var k = 0; k < 3; k++) {
      final p = (progress + k / 3) % 1.0;
      final r = maxR * (0.18 + 0.78 * Curves.easeOut.transform(p));
      final alpha = (1 - p) * 0.55;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 + 2 * (1 - p)
          ..color = ring.withValues(alpha: alpha),
      );
    }
    // A sweeping beam.
    final sweep = progress * 2 * math.pi;
    final beam = Paint()
      ..shader = SweepGradient(
        startAngle: sweep - 0.9,
        endAngle: sweep,
        colors: [glow.withValues(alpha: 0), glow.withValues(alpha: 0.28)],
        tileMode: TileMode.decal,
      ).createShader(Rect.fromCircle(center: c, radius: maxR * 0.9));
    canvas.drawCircle(c, maxR * 0.9, beam);
  }

  @override
  bool shouldRepaint(PairingRadarPainter old) =>
      old.progress != progress || old.active != active || old.ring != ring || old.gold != gold || old.glow != glow;
}

/// Digits in glass tiles, always left to right (a code reads the same way in
/// Arabic and English), in the reader's digit style with the Latin digits
/// underneath when those differ – the other phone may use the other style.
class DigitTiles extends StatelessWidget {
  const DigitTiles({
    super.key,
    required this.digits,
    required this.localized,
    required this.semanticLabel,
    this.groupAfter,
    this.tileWidth = 52,
  });

  /// ASCII digits.
  final String digits;

  /// The same digits in the reader's style.
  final String localized;
  final String semanticLabel;

  /// A gap after this many digits (a room code: 3).
  final int? groupAfter;
  final double tileWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final shown = localized.characters.toList();
    Widget tile(String d) => Container(
      width: tileWidth,
      height: tileWidth * 1.22,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusM),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.accent.withValues(alpha: 0.2), t.glassFill],
        ),
        border: Border.all(color: t.gold.withValues(alpha: 0.7), width: 1),
        boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: 0.25), blurRadius: 12)],
      ),
      child: Text(
        d,
        textScaler: TextScaler.noScaling,
        style: text.headlineMedium?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600, height: 1),
      ),
    );
    final tiles = <Widget>[];
    for (final (i, d) in shown.indexed) {
      if (groupAfter != null && i == groupAfter) tiles.add(SizedBox(width: tileWidth * 0.3));
      tiles.add(tile(d));
    }
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: tiles)),
            if (localized != digits)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  digits.split('').join(' '),
                  style: text.labelMedium?.copyWith(color: t.textTertiary, letterSpacing: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A QR code of [data] (dark modules on a light card in every theme, so any
/// camera reads it).
class TogetherQrView extends StatelessWidget {
  const TogetherQrView({super.key, required this.data, required this.semanticLabel, this.size = 148});

  final String data;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final image = QrImage(QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M));
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.07),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF2),
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: t.gold.withValues(alpha: 0.8), width: 1.2),
          boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: 0.3), blurRadius: 16)],
        ),
        child: CustomPaint(painter: QrPainter(image, color: const Color(0xFF14192B))),
      ),
    );
  }
}

class QrPainter extends CustomPainter {
  QrPainter(this.image, {required this.color});

  final QrImage image;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final n = image.moduleCount;
    final cell = size.shortestSide / n;
    final paint = Paint()..color = color;
    final path = Path();
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (image.isDark(y, x)) {
          path.addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x * cell, y * cell, cell + 0.4, cell + 0.4),
              Radius.circular(cell * 0.18),
            ),
          );
        }
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(QrPainter old) => old.image != image || old.color != color;
}

/// A round success mark (connected).
class PairedMark extends StatelessWidget {
  const PairedMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: context.motion(MadarMotion.medium),
      curve: Curves.elasticOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [t.success.withValues(alpha: 0.35), t.success.withValues(alpha: 0.08)]),
          border: Border.all(color: t.success, width: 1.6),
          boxShadow: [BoxShadow(color: t.success.withValues(alpha: 0.45), blurRadius: 22)],
        ),
        child: Icon(Icons.link_rounded, color: t.success, size: size * 0.5),
      ),
    );
  }
}
