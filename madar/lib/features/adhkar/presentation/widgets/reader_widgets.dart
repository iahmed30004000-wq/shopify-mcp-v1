import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/adhkar_session.dart';

/// The set's progress as one thin segment per dhikr (finished ones gold,
/// the current one glowing and partly filled). Tapping jumps to a dhikr.
class AdhkarSetProgressBar extends StatelessWidget {
  const AdhkarSetProgressBar({super.key, required this.session, this.onJump, this.height = 22});

  final AdhkarSession session;
  final ValueChanged<int>? onJump;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final dir = Directionality.of(context);
    final n = session.length;
    return Semantics(
      label: l.adhkarDhikrSemantics(fmt.formatInt(session.index + 1), fmt.formatInt(n)),
      value: fmt.formatPercent(session.progress),
      child: LayoutBuilder(
        builder: (context, c) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onJump == null || n == 0
              ? null
              : (d) {
                  var f = (d.localPosition.dx / c.maxWidth).clamp(0.0, 0.999);
                  if (dir == TextDirection.rtl) f = 0.999 - f;
                  final i = (f * n).floor();
                  if (i == session.index) return;
                  Fx.fire(Sfx.swipe);
                  onJump!(i);
                },
          child: SizedBox(
            height: height,
            width: c.maxWidth,
            child: CustomPaint(
              painter: _SegmentsPainter(
                fractions: [for (var i = 0; i < n; i++) session.progressAt(i)],
                current: session.index,
                direction: dir,
                done: t.accent,
                track: t.glassBorder,
                glow: t.accentGlow,
                complete: session.isComplete,
                success: t.success,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentsPainter extends CustomPainter {
  _SegmentsPainter({
    required this.fractions,
    required this.current,
    required this.direction,
    required this.done,
    required this.track,
    required this.glow,
    required this.complete,
    required this.success,
  });

  final List<double> fractions;
  final int current;
  final TextDirection direction;
  final Color done, track, glow, success;
  final bool complete;

  @override
  void paint(Canvas canvas, Size size) {
    final n = fractions.length;
    if (n == 0) return;
    final gap = n > 20 ? 2.5 : 4.0;
    final w = (size.width - gap * (n - 1)) / n;
    const h = 4.0;
    final y = (size.height - h) / 2;
    final fill = Paint()..color = complete ? success : done;
    final bg = Paint()..color = track;
    for (var i = 0; i < n; i++) {
      final slot = direction == TextDirection.rtl ? n - 1 - i : i;
      final x = slot * (w + gap);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(h / 2));
      canvas.drawRRect(r, bg);
      final f = fractions[i].clamp(0.0, 1.0);
      if (i == current) {
        final halo = Paint()
          ..color = glow.withValues(alpha: glow.a * 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawRRect(r.inflate(1.5), halo);
        canvas.drawRRect(r, Paint()..color = (complete ? success : done).withValues(alpha: 0.35));
      }
      if (f > 0) {
        final fw = w * f;
        final fx = direction == TextDirection.rtl ? x + w - fw : x;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(fx, y, fw, h), const Radius.circular(h / 2)), fill);
      }
    }
  }

  @override
  bool shouldRepaint(_SegmentsPainter old) =>
      old.current != current ||
      old.complete != complete ||
      old.direction != direction ||
      old.done != done ||
      old.track != track ||
      !_listEq(old.fractions, fractions);

  static bool _listEq(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Repetition beads are drawn around the counter ring up to this count.
const int kMaxRepetitionBeads = 40;

const double _beadGap = 14;

/// Small beads around the counter ring, one per repetition (lit as counted)
/// – a misbaha's cue for short counts.
class _RepetitionBeadsPainter extends CustomPainter {
  _RepetitionBeadsPainter({
    required this.total,
    required this.done,
    required this.radius,
    required this.lit,
    required this.glow,
    required this.dim,
  });

  final int total;
  final int done;
  final double radius;
  final Color lit, glow, dim;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final step = 2 * math.pi / total;
    final r = math.min(3.2, radius * step * 0.26);
    final halo = Paint()
      ..color = glow.withValues(alpha: glow.a * 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.2);
    for (var i = 0; i < total; i++) {
      final a = -math.pi / 2 + i * step;
      final p = c + Offset(math.cos(a), math.sin(a)) * radius;
      if (i < done) {
        canvas.drawCircle(p, r * 1.6, halo);
        canvas.drawCircle(p, r, Paint()..color = lit);
      } else {
        canvas.drawCircle(p, r * 0.8, Paint()..color = dim);
      }
    }
  }

  @override
  bool shouldRepaint(_RepetitionBeadsPainter old) =>
      old.total != total || old.done != done || old.radius != radius || old.lit != lit || old.dim != dim;
}

/// The big counter: a ring that fills with every repetition, the number
/// still to go rolling in its centre, a check when done. The whole ring is
/// the button (the reader also counts taps anywhere on the page).
class AdhkarCounterRing extends StatelessWidget {
  const AdhkarCounterRing({
    super.key,
    required this.count,
    required this.target,
    required this.onTap,
    this.reading = false,
    this.size = 136,
  });

  final int count;
  final int target;
  final VoidCallback? onTap;

  /// A "read the surahs" item: a single tick, no number.
  final bool reading;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final done = count >= target;
    final remaining = math.max(0, target - count);
    final color = done ? t.success : t.accent;
    final Widget center;
    if (done) {
      center = Column(
        key: const ValueKey('done'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, color: t.success, size: size * 0.3),
          Text(l.adhkarCounterDone, style: text.labelMedium!.copyWith(color: t.success)),
        ],
      );
    } else if (reading) {
      center = Column(
        key: const ValueKey('reading'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, color: t.accent, size: size * 0.24),
          const SizedBox(height: Space.xs),
          Text(
            l.adhkarReadingDone,
            textAlign: TextAlign.center,
            style: text.labelMedium!.copyWith(color: t.textPrimary),
          ),
        ],
      );
    } else {
      center = Column(
        key: const ValueKey('count'),
        mainAxisSize: MainAxisSize.min,
        children: [
          RollingNumber(
            value: remaining,
            formatter: (n) => fmt.formatInt(n.toInt()),
            style: MadarTypography.numerals(
              t,
              size: size * 0.29,
              color: t.textPrimary,
            ).copyWith(fontWeight: FontWeight.w600, height: 1.1),
          ),
          Text(l.adhkarRemaining, style: text.labelSmall!.copyWith(color: t.textSecondary)),
        ],
      );
    }
    final beads = !reading && target >= 2 && target <= kMaxRepetitionBeads;
    final ring = ProgressRing(
      value: target == 0 ? 0 : count / target,
      size: size,
      strokeWidth: 9,
      color: color,
      child: AnimatedSwitcher(
        duration: context.motion(MadarMotion.short),
        switchInCurve: MadarMotion.decelerate,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: child),
        ),
        child: center,
      ),
    );
    return MadarPressable(
      onTap: onTap,
      sfx: null,
      pressScale: 0.94,
      semanticLabel: l.adhkarCounterSemantics(fmt.formatInt(count), fmt.formatInt(target)),
      focusRadius: BorderRadius.circular(size / 2 + _beadGap),
      child: SizedBox.square(
        dimension: size + _beadGap * 2,
        child: CustomPaint(
          painter: beads
              ? _RepetitionBeadsPainter(
                  total: target,
                  done: count,
                  radius: size / 2 + _beadGap * 0.62,
                  lit: color,
                  glow: done ? t.success : t.accentGlow,
                  dim: t.glassBorder,
                )
              : null,
          child: Center(child: ring),
        ),
      ),
    );
  }
}
