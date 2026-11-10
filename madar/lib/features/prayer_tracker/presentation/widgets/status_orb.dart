import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/ambient_motion.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/motion/motion.dart';
import '../../domain/tracker_day.dart';
import '../../domain/tracker_prayers.dart';
import '../../domain/tracker_timing.dart';
import '../tracker_actions.dart';
import '../tracker_labels.dart';

/// The round status badge of a prayer: a lit flame in gold once prayed on
/// time, an ember for late, the cool replay mark for a made-up prayer, a
/// dim crescent for missed, an accent ring that softly breathes while the
/// prayer is due, a dashed ring once its time passed unlogged, and a small
/// clock while it is still to come. Changes cross-fade with a spring pop.
class StatusOrb extends StatefulWidget {
  const StatusOrb({super.key, required this.slot, this.size = 46});

  final TrackerSlot slot;
  final double size;

  @override
  State<StatusOrb> createState() => _StatusOrbState();
}

class _StatusOrbState extends State<StatusOrb> with SingleTickerProviderStateMixin {
  AnimationController? _breath;

  bool _wantsBreath(BuildContext context) => widget.slot.isDue && context.ambientMotion;

  void _syncBreath() {
    final want = _wantsBreath(context);
    if (want && _breath == null) {
      _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
    } else if (!want && _breath != null) {
      _breath!.dispose();
      _breath = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBreath();
  }

  @override
  void didUpdateWidget(StatusOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBreath();
  }

  @override
  void dispose() {
    _breath?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = TrackerColors.of(context);
    final slot = widget.slot;
    final status = slot.status;
    final size = widget.size;

    final (Color color, IconData icon, bool filled) = switch ((status, slot.timing)) {
      (final PrayerStatus s, _) when s.counts => (c.status(s), TrackerIcons.status(s), true),
      (PrayerStatus.missed, _) => (c.missed, TrackerIcons.missed, false),
      (_, SlotTiming.open) => (c.due, TrackerIcons.of(slot.prayer), false),
      (_, SlotTiming.closed) => (c.idle, TrackerIcons.of(slot.prayer), false),
      _ => (t.textTertiary, TrackerIcons.upcoming, false),
    };
    final upcoming = slot.timing == SlotTiming.upcoming && status == null;
    final key = ValueKey<(PrayerStatus?, SlotTiming)>((status, slot.timing));

    Widget orb = DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: filled
            ? RadialGradient(
                center: const Alignment(-0.3, -0.35),
                radius: 0.95,
                colors: [Color.lerp(color, t.starTint, 0.35)!, color, Color.lerp(color, t.space0, 0.35)!],
                stops: const [0, 0.55, 1],
              )
            : null,
        color: filled ? null : color.withValues(alpha: upcoming ? 0.06 : 0.12),
        border: filled
            ? Border.all(color: Color.lerp(color, t.starTint, 0.5)!.withValues(alpha: 0.8), width: 1)
            : slot.unloggedPast && slot.isObligatory
            ? null
            : Border.all(
                color: color.withValues(alpha: upcoming ? 0.35 : 0.75),
                width: slot.isDue ? 2 : 1.4,
              ),
        boxShadow: filled && t.isDark
            ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: size * 0.4, spreadRadius: -2)]
            : null,
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(
          icon,
          size: size * 0.48,
          color: filled
              ? t.space0.withValues(alpha: t.isDark ? 0.85 : 0.9)
              : color.withValues(alpha: upcoming ? 0.6 : 1),
        ),
      ),
    );
    if (slot.unloggedPast && slot.isObligatory) {
      orb = CustomPaint(
        key: key,
        foregroundPainter: _DashedRing(color: c.idle),
        child: orb,
      );
    }

    final breath = _breath;
    // The breathing glow is painted straight from the animation (no rebuild
    // per frame) behind its own repaint boundary, so a due prayer never
    // repaints its whole card – or the list – on every frame.
    return SizedBox.square(
      dimension: size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: breath == null ? null : _BreathPainter(animation: breath, color: c.due),
          child: AnimatedSwitcher(
            duration: context.motion(MadarMotion.medium),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(animation), child: child),
            ),
            child: orb,
          ),
        ),
      ),
    );
  }
}

/// The soft accent halo of a due prayer, breathing with [animation].
class _BreathPainter extends CustomPainter {
  _BreathPainter({required this.animation, required this.color}) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final v = Curves.easeInOut.transform(animation.value);
    final blur = 10 + 8 * v;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2,
      Paint()
        ..color = color.withValues(alpha: 0.18 + 0.22 * v)
        // BoxShadow's blur radius → sigma.
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 0.57735 + 0.5),
    );
  }

  @override
  bool shouldRepaint(_BreathPainter old) => old.animation != animation || old.color != color;
}

class _DashedRing extends CustomPainter {
  _DashedRing({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 - 1;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = color;
    const dashes = 14;
    const sweep = 2 * 3.141592653589793 / dashes;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => old.color != color;
}
