import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../sound/sound_api.dart';
import 'motion.dart';
import 'springs.dart';

/// Wraps any child with a physical press: it springs down to
/// [MadarMotion.pressScale] on touch ([MadarMotion.snappy]) and bounces back
/// on release ([MadarMotion.bouncy]), keeping velocity if the finger lifts
/// mid-compression.
///
/// * With [onTap] / [onLongPress] it is a complete tappable (button
///   semantics, [Fx.fire] feedback with [sfx] / [longPressSfx]).
/// * Without callbacks it is purely visual, so it can decorate a child that
///   handles its own gestures.
///
/// The press itself follows raw pointers (instant on touch-down) and releases
/// when the pointer lifts or travels farther than the touch slop (a scroll).
///
/// Under reduced motion the scale is skipped (feedback still fires).
class SpringPress extends StatefulWidget {
  const SpringPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.sfx = Sfx.tap,
    this.longPressSfx = Sfx.pickUp,
    this.pressScale = MadarMotion.pressScale,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
    this.alignment = Alignment.center,
    this.onPressedChanged,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Feedback fired on tap; `null` = silent (the caller fires its own).
  final Sfx? sfx;
  final Sfx? longPressSfx;
  final double pressScale;
  final bool enabled;
  final HitTestBehavior behavior;

  /// Scale origin.
  final AlignmentGeometry alignment;
  final ValueChanged<bool>? onPressedChanged;
  final String? semanticLabel;

  @override
  State<SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<SpringPress> with SingleTickerProviderStateMixin {
  late final SpringValue _scale = SpringValue(vsync: this, value: 1, spring: MadarMotion.snappy);
  bool _pressed = false;
  int? _pointer;
  Offset _downPosition = Offset.zero;

  bool get _hasCallbacks => widget.onTap != null || widget.onLongPress != null;
  bool get _interactive => widget.enabled && _hasCallbacks;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    _pressed = value;
    widget.onPressedChanged?.call(value);
    if (context.reducedMotion) {
      _scale.jumpTo(1);
      return;
    }
    _scale.animateTo(value ? widget.pressScale : 1, spring: value ? MadarMotion.snappy : MadarMotion.bouncy);
  }

  void _handleTap() {
    if (!_interactive || widget.onTap == null) return;
    final sfx = widget.sfx;
    if (sfx != null) Fx.fire(sfx);
    widget.onTap!();
  }

  void _handleLongPress() {
    if (!_interactive || widget.onLongPress == null) return;
    _setPressed(false);
    final sfx = widget.longPressSfx;
    if (sfx != null) Fx.fire(sfx);
    widget.onLongPress!();
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!widget.enabled || _pointer != null) return;
    if (_hasCallbacks && !_interactive) return;
    _pointer = e.pointer;
    _downPosition = e.position;
    _setPressed(true);
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if ((e.position - _downPosition).distance > kTouchSlop) {
      _pointer = null;
      _setPressed(false);
    }
  }

  void _onPointerEnd(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _setPressed(false);
  }

  @override
  void didUpdateWidget(SpringPress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) _setPressed(false);
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = ScaleTransition(
      scale: _scale,
      alignment: widget.alignment.resolve(Directionality.maybeOf(context)),
      child: widget.child,
    );
    if (_hasCallbacks) {
      final interactive = _interactive;
      child = Semantics(
        button: true,
        enabled: interactive,
        label: widget.semanticLabel,
        onTap: interactive && widget.onTap != null ? _handleTap : null,
        onLongPress: interactive && widget.onLongPress != null ? _handleLongPress : null,
        child: GestureDetector(
          behavior: widget.behavior,
          excludeFromSemantics: true,
          onTap: interactive && widget.onTap != null ? _handleTap : null,
          onLongPress: interactive && widget.onLongPress != null ? _handleLongPress : null,
          child: child,
        ),
      );
    }
    // The visual press follows raw pointers so it reacts on touch-down
    // (a tap recogniser only confirms after the press timeout or on lift).
    return Listener(
      behavior: widget.behavior,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: child,
    );
  }
}
