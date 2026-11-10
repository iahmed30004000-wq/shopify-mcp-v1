import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import 'wb_palette.dart';

/// A 0–10 scale as eleven beads in the reading direction: tap or drag to
/// set, tap the chosen bead again to clear. Unset shows every bead quiet.
class ScaleBeads extends StatelessWidget {
  const ScaleBeads({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.color,
    this.icon,
    this.lowHint,
    this.highHint,
    this.min = 0,
    this.max = 10,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final Color color;
  final IconData? icon;
  final String? lowHint;
  final String? highHint;
  final int min;
  final int max;

  int get _count => max - min + 1;

  void _set(int? v) {
    if (v == value) return;
    Fx.fire(v == null ? Sfx.toggleOff : Sfx.countTick, pitch: v == null ? 1 : 0.85 + 0.03 * (v - min));
    onChanged(v);
  }

  int _indexAt(double dx, double width, TextDirection dir) {
    final slot = width / _count;
    var i = (dx / slot).floor().clamp(0, _count - 1);
    if (dir == TextDirection.rtl) i = _count - 1 - i;
    return min + i;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final dir = Directionality.of(context);
    final v = value;
    return Semantics(
      label: label,
      value: v == null ? '—' : '${fmt.formatInt(v)} / ${fmt.formatInt(max)}',
      increasedValue: fmt.formatInt(math.min(max, (v ?? min - 1) + 1)),
      decreasedValue: v == null || v <= min ? null : fmt.formatInt(v - 1),
      onIncrease: () => _set(math.min(max, (v ?? min - 1) + 1)),
      onDecrease: v == null || v <= min ? null : () => _set(v - 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: color), const SizedBox(width: Space.s)],
              Expanded(child: Text(label, style: text.titleSmall)),
              AnimatedSwitcher(
                duration: context.motion(MadarMotion.short),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: child),
                ),
                child: Text(
                  v == null ? '—' : fmt.formatInt(v),
                  key: ValueKey(v),
                  style: text.titleMedium?.copyWith(
                    color: v == null ? t.textTertiary : color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  final i = _indexAt(d.localPosition.dx, w, dir);
                  _set(i == value ? null : i);
                },
                onHorizontalDragUpdate: (d) => _set(_indexAt(d.localPosition.dx, w, dir)),
                child: SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      for (var i = min; i <= max; i++)
                        Expanded(
                          child: Center(
                            child: _Bead(
                              filled: v != null && i <= v,
                              current: v == i,
                              color: color,
                              track: t.glassBorder,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (lowHint != null || highHint != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs),
              child: Row(
                children: [
                  Text(lowHint ?? '', style: text.labelSmall?.copyWith(color: t.textTertiary)),
                  const Spacer(),
                  Text(highHint ?? '', style: text.labelSmall?.copyWith(color: t.textTertiary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bead extends StatelessWidget {
  const _Bead({required this.filled, required this.current, required this.color, required this.track});

  final bool filled;
  final bool current;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final size = current ? 20.0 : (filled ? 13.0 : 10.0);
    return AnimatedContainer(
      duration: context.motion(MadarMotion.short),
      curve: MadarMotion.decelerate,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color.withValues(alpha: current ? 1 : 0.72) : track.withValues(alpha: 0.35),
        border: Border.all(color: filled ? color : track, width: current ? 2 : 1),
        boxShadow: current ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10)] : null,
      ),
    );
  }
}

/// The pain score slider: a calm gradient track (quiet → coral), a glowing
/// thumb in the score's own colour and the chosen number large beside it.
class PainScoreSlider extends StatelessWidget {
  const PainScoreSlider({super.key, required this.value, required this.onChanged, required this.label, this.caption});

  final int value;
  final ValueChanged<int> onChanged;
  final String label;

  /// A word for the value (e.g. "moderate").
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final c = WbPalette.pain(t, value);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: context.motion(MadarMotion.short),
                style: (text.displaySmall ?? const TextStyle(fontSize: 36)).copyWith(
                  color: c,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
                child: Text(fmt.formatInt(value)),
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: text.labelSmall?.copyWith(color: t.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: Space.s),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 10,
              trackShape: _GradientTrackShape(WbPalette.painScale(t), t.glassBorder),
              thumbShape: _GlowThumb(c, t.space1),
              overlayColor: c.withValues(alpha: 0.12),
              activeTickMarkColor: Colors.transparent,
              inactiveTickMarkColor: Colors.transparent,
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Semantics(
              label: label,
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                semanticFormatterCallback: (v) => '${fmt.formatInt(v.round())} / ${fmt.formatInt(10)}',
                onChanged: (v) {
                  final n = v.round();
                  if (n == value) return;
                  Fx.fire(Sfx.countTick, pitch: 0.85 + n * 0.03);
                  onChanged(n);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _GradientTrackShape(this.colors, this.border);

  final List<Color> colors;
  final Color border;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final rect = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
    final ordered = textDirection == TextDirection.rtl ? colors.reversed.toList() : colors;
    context.canvas.drawRRect(
      rrect,
      Paint()..shader = LinearGradient(colors: [for (final c in ordered) c.withValues(alpha: 0.85)]).createShader(rect),
    );
    context.canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = border,
    );
    // Ticks for every whole score.
    final tick = Paint()..color = border.withValues(alpha: 0.9);
    for (var i = 1; i < 10; i++) {
      final x = rect.left + rect.width * i / 10;
      context.canvas.drawCircle(Offset(x, rect.center.dy), 1.2, tick);
    }
  }
}

class _GlowThumb extends SliderComponentShape {
  const _GlowThumb(this.color, this.core);

  final Color color;
  final Color core;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size.square(30);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final r = 12 + 3 * activationAnimation.value;
    canvas.drawCircle(center, r + 6, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawCircle(center, r, Paint()..color = core);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
    canvas.drawCircle(center, r * 0.38, Paint()..color = color);
  }
}

/// A − value + stepper for sleep hours or caffeine cups; null shows "—" and
/// the first tap starts from [start].
class WbStepper extends StatelessWidget {
  const WbStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.format,
    required this.step,
    required this.min,
    required this.max,
    required this.start,
    this.icon,
    this.color,
    this.decreaseLabel,
    this.increaseLabel,
  });

  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  final String Function(double v) format;
  final double step;
  final double min;
  final double max;
  final double start;
  final IconData? icon;
  final Color? color;
  final String? decreaseLabel;
  final String? increaseLabel;

  void _change(double? v) {
    if (v == value) {
      Fx.fire(Sfx.error);
      return;
    }
    Fx.fire(Sfx.countTick);
    onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = color ?? t.accent;
    final v = value;
    Widget button(IconData ic, String? sem, VoidCallback onTap) => Semantics(
      button: true,
      label: sem,
      excludeSemantics: true,
      child: SpringPress(
        sfx: null,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.withValues(alpha: 0.12),
            border: Border.all(color: c.withValues(alpha: 0.45)),
          ),
          child: Icon(ic, size: 20, color: c),
        ),
      ),
    );
    return Semantics(
      label: label,
      value: v == null ? '—' : format(v),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: c), const SizedBox(width: Space.s)],
          Expanded(child: Text(label, style: text.titleSmall)),
          button(Icons.remove_rounded, decreaseLabel, () {
            if (v == null) return _change(start);
            _change(v - step < min ? null : v - step);
          }),
          SizedBox(
            width: 92,
            child: Center(
              child: AnimatedSwitcher(
                duration: context.motion(MadarMotion.short),
                child: Text(
                  v == null ? '—' : format(v),
                  key: ValueKey(v),
                  style: text.titleMedium?.copyWith(
                    color: v == null ? t.textTertiary : t.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ),
          button(Icons.add_rounded, increaseLabel, () => _change(v == null ? start : math.min(max, v + step))),
        ],
      ),
    );
  }
}
