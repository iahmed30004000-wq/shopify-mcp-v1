import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../motion/motion.dart';
import '../../sound/sound_api.dart';
import '../painters/islamic_star_painter.dart';
import '../tokens.dart';

/// Madar's toggle: a glass track that floods with glowing accent when on,
/// and a pearl thumb engraved with an eight-point star that turns as it
/// travels. Springs between states, can be dragged, stretches while
/// pressed, mirrors in RTL, and fires [Sfx.toggleOn] / [Sfx.toggleOff].
class MadarSwitch extends StatefulWidget {
  const MadarSwitch({super.key, required this.value, required this.onChanged, this.activeColor, this.semanticLabel});

  final bool value;

  /// `null` disables the switch.
  final ValueChanged<bool>? onChanged;

  /// Defaults to the theme accent.
  final Color? activeColor;
  final String? semanticLabel;

  static const Size size = Size(54, 32);

  @override
  State<MadarSwitch> createState() => _MadarSwitchState();
}

class _MadarSwitchState extends State<MadarSwitch> with TickerProviderStateMixin {
  late final AnimationController _pos = AnimationController.unbounded(vsync: this, value: widget.value ? 1 : 0);
  late final AnimationController _press = AnimationController(vsync: this, duration: MadarMotion.micro);
  bool _dragging = false;

  static const _travel = 22.0;

  bool get _enabled => widget.onChanged != null;

  @override
  void didUpdateWidget(MadarSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_dragging) _animateTo(widget.value);
  }

  void _animateTo(bool on, {double velocity = 0}) {
    final target = on ? 1.0 : 0.0;
    if (context.reducedMotion) {
      _pos.value = target;
      return;
    }
    _pos.animateWith(SpringSimulation(MadarMotion.snappy, _pos.value, target, velocity, snapToEnd: true));
  }

  void _request(bool next) {
    if (!_enabled) return;
    if (next == widget.value) {
      _animateTo(next);
      return;
    }
    Fx.fire(next ? Sfx.toggleOn : Sfx.toggleOff);
    widget.onChanged!(next);
    // Optimistic motion; a parent that rejects the change springs us back
    // on its next build.
    _animateTo(next);
  }

  double get _dirSign => Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  void _onDragStart(DragStartDetails d) {
    _dragging = true;
    _pos.stop();
    _press.forward();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _pos.value = (_pos.value + d.primaryDelta! / _travel * _dirSign).clamp(-0.08, 1.08);
  }

  void _onDragEnd(DragEndDetails d) {
    _dragging = false;
    _press.reverse();
    final v = d.primaryVelocity! / _travel * _dirSign;
    final next = v.abs() > 3 ? v > 0 : _pos.value > 0.5;
    if (next == widget.value) {
      _animateTo(next, velocity: v);
    } else {
      _request(next);
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = widget.activeColor ?? t.accent;
    return Semantics(
      toggled: widget.value,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: _enabled ? () => _request(!widget.value) : null,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            _request(!widget.value);
            return null;
          }),
        },
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _press.forward() : null,
          onTapCancel: _enabled ? () => _press.reverse() : null,
          onTapUp: _enabled ? (_) => _press.reverse() : null,
          onTap: _enabled ? () => _request(!widget.value) : null,
          onHorizontalDragStart: _enabled ? _onDragStart : null,
          onHorizontalDragUpdate: _enabled ? _onDragUpdate : null,
          onHorizontalDragEnd: _enabled ? _onDragEnd : null,
          child: Opacity(
            opacity: _enabled ? 1 : 0.45,
            child: Padding(
              // Generous hit area around the 54×32 visual.
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: MadarSwitch.size,
                  painter: MadarSwitchPainter(
                    position: _pos,
                    press: _press,
                    accent: accent,
                    accentGlow: t.accentGlow,
                    track: Color.alphaBlend(t.glassFill, t.space2.withValues(alpha: t.isDark ? 0.7 : 0.55)),
                    border: t.glassBorder,
                    highlight: t.glassHighlight,
                    thumbOff: t.isDark ? t.textSecondary : t.space0,
                    thumbOn: t.isDark ? t.textPrimary : t.space0,
                    engraveOff: t.textTertiary,
                    shadow: t.glassShadow,
                    rtl: Directionality.of(context) == TextDirection.rtl,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MadarSwitchPainter extends CustomPainter {
  MadarSwitchPainter({
    required this.position,
    required this.press,
    required this.accent,
    required this.accentGlow,
    required this.track,
    required this.border,
    required this.highlight,
    required this.thumbOff,
    required this.thumbOn,
    required this.engraveOff,
    required this.shadow,
    required this.rtl,
  }) : super(repaint: Listenable.merge([position, press]));

  final Animation<double> position;
  final Animation<double> press;
  final Color accent, accentGlow, track, border, highlight, thumbOff, thumbOn, engraveOff, shadow;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final raw = position.value;
    final p = raw.clamp(0.0, 1.0);
    final pr = press.value;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));

    // Glow when on.
    if (p > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = accentGlow.withValues(alpha: accentGlow.a * 0.7 * p)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 9),
      );
    }
    // Track: glass → accent flood.
    canvas.drawRRect(rrect, Paint()..color = track);
    if (p > 0) {
      final hsl = HSLColor.fromColor(accent);
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
            hsl.withLightness((hsl.lightness + 0.08).clamp(0.0, 0.95)).toColor().withValues(alpha: p),
            accent.withValues(alpha: p),
          ]),
      );
    }
    // Inner shading + hairline.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [shadow.withValues(alpha: shadow.a * 0.35), shadow.withValues(alpha: 0)], const [0, 0.5]),
    );
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
          Color.lerp(border, highlight, 0.5 + 0.3 * p)!,
          border.withValues(alpha: border.a * 0.5),
        ]),
    );

    // Thumb (stretches toward travel while pressed).
    const pad = 3.0;
    final r = size.height / 2 - pad;
    final stretch = 5.0 * pr;
    final travel = size.width - pad * 2 - r * 2;
    final along = raw.clamp(-0.08, 1.08);
    var cx = pad + r + along * travel;
    if (rtl) cx = size.width - cx;
    final cy = size.height / 2;
    final towardEnd = (p < 0.5) != rtl ? 1.0 : -1.0;
    final thumbRect = Rect.fromLTRB(
      cx - r - (towardEnd < 0 ? stretch : 0),
      cy - r,
      cx + r + (towardEnd > 0 ? stretch : 0),
      cy + r,
    );
    final thumb = RRect.fromRectAndRadius(thumbRect, Radius.circular(r));
    canvas.drawRRect(
      thumb.shift(const Offset(0, 1.2)),
      Paint()
        ..color = shadow.withValues(alpha: math.min(1, shadow.a * 1.2))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    final thumbColor = Color.lerp(thumbOff, thumbOn, p)!;
    canvas.drawRRect(
      thumb,
      Paint()
        ..shader = ui.Gradient.radial(
          thumbRect.center - Offset(r * 0.35, r * 0.4),
          r * 1.6,
          [Color.lerp(thumbColor, highlight, 0.35)!, thumbColor],
        ),
    );
    // Engraved star, turning 45° across the travel.
    final star = IslamicGeometry.starPath(center: thumbRect.center, radius: r * 0.52, points: 8, rotation: p * math.pi / 4 * (rtl ? -1 : 1));
    canvas.drawPath(
      star,
      Paint()
        ..color = Color.lerp(engraveOff.withValues(alpha: 0.5), accent, p)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(MadarSwitchPainter old) =>
      old.position != position ||
      old.press != press ||
      old.accent != accent ||
      old.accentGlow != accentGlow ||
      old.track != track ||
      old.border != border ||
      old.highlight != highlight ||
      old.thumbOff != thumbOff ||
      old.thumbOn != thumbOn ||
      old.engraveOff != engraveOff ||
      old.shadow != shadow ||
      old.rtl != rtl;
}
