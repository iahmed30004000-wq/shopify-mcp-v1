import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../motion/motion.dart';
import '../../sound/sound_api.dart';
import '../tokens.dart';

/// The single press behaviour of every tappable Madar surface: spring scale
/// to [MadarMotion.pressScale], synced sound + haptic via [Fx.fire], keyboard
/// activation (Enter/Space), focus, and button semantics.
///
/// Under reduced motion the scale is skipped entirely.
class MadarPressable extends StatefulWidget {
  const MadarPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.sfx = Sfx.tap,
    this.longPressSfx = Sfx.pickUp,
    this.pressScale = MadarMotion.pressScale,
    this.semanticLabel,
    this.button = true,
    this.selected,
    this.toggled,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
    this.onPressedChanged,
    this.focusNode,
    this.autofocus = false,
    this.excludeChildSemantics = false,
    this.focusRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Sound (+ its synced haptic) fired on tap. `null` = silent (the caller
  /// fires its own feedback, e.g. a switch choosing toggleOn/toggleOff).
  final Sfx? sfx;
  final Sfx? longPressSfx;
  final double pressScale;
  final String? semanticLabel;
  final bool button;
  final bool? selected;
  final bool? toggled;
  final bool enabled;
  final HitTestBehavior behavior;

  /// Reports press-down / release so the caller can light up its surface.
  final ValueChanged<bool>? onPressedChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool excludeChildSemantics;

  /// Corner radius of the keyboard-focus ring (defaults to a pill).
  final BorderRadius? focusRadius;

  bool get _interactive => enabled && (onTap != null || onLongPress != null);

  @override
  State<MadarPressable> createState() => _MadarPressableState();
}

class _MadarPressableState extends State<MadarPressable> with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(vsync: this, value: 1);
  bool _pressed = false;
  bool _focused = false;

  /// Cached so gesture callbacks never look up inherited widgets (a tap
  /// cancel can arrive while the element is being unmounted).
  bool _reduced = false;
  bool _active = true;

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _handleTap()),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = context.reducedMotion;
  }

  @override
  void deactivate() {
    _active = false;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  void _springTo(double target, SpringDescription spring) {
    if (_reduced) {
      _scale.value = 1;
      return;
    }
    _scale.animateWith(SpringSimulation(spring, _scale.value, target, _scale.velocity));
  }

  void _setPressed(bool value) {
    if (_pressed == value || !_active) return;
    _pressed = value;
    widget.onPressedChanged?.call(value);
    _springTo(value ? widget.pressScale : 1, value ? MadarMotion.snappy : MadarMotion.bouncy);
  }

  // The press follows the raw pointer: a tap recognizer that competes in the
  // gesture arena (any scrollable, or onTap + onLongPress) reports tap-down
  // only after kPressTimeout or on pointer-up, so a quick tap would never
  // show its press.
  int? _pointer;
  Offset? _downAt;

  void _onPointerDown(PointerDownEvent e) {
    if (!widget._interactive || _pointer != null || (e.buttons & kPrimaryButton) == 0) return;
    _pointer = e.pointer;
    _downAt = e.position;
    _setPressed(true);
  }

  void _onPointerMove(PointerMoveEvent e) {
    final down = _downAt;
    if (e.pointer != _pointer || down == null) return;
    // A drag (scrolling the list) is not a press.
    if ((e.position - down).distance > kTouchSlop) _release();
  }

  void _onPointerEnd(PointerEvent e) {
    if (e.pointer == _pointer) _release();
  }

  void _release() {
    _pointer = null;
    _downAt = null;
    _setPressed(false);
  }

  void _handleTap() {
    if (!widget._interactive || widget.onTap == null) return;
    final sfx = widget.sfx;
    if (sfx != null) Fx.fire(sfx);
    widget.onTap!();
  }

  void _handleLongPress() {
    if (!widget._interactive || widget.onLongPress == null) return;
    _release();
    final sfx = widget.longPressSfx;
    if (sfx != null) Fx.fire(sfx);
    widget.onLongPress!();
  }

  @override
  void didUpdateWidget(MadarPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget._interactive && _pressed) _release();
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget._interactive;
    // The ring is always in the tree (only its decoration changes), so
    // focusing never rebuilds – and never resets – the child's state.
    final child = _FocusRing(
      visible: _focused,
      radius: widget.focusRadius,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
    return Semantics(
      button: widget.button,
      enabled: interactive,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      onTap: interactive && widget.onTap != null ? _handleTap : null,
      onLongPress: interactive && widget.onLongPress != null ? _handleLongPress : null,
      child: FocusableActionDetector(
        enabled: interactive,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        actions: _actions,
        mouseCursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (v) {
          if (mounted) setState(() => _focused = v);
        },
        // Excluded below the focus detector so focusability still merges
        // into this node.
        child: ExcludeSemantics(
          excluding: widget.excludeChildSemantics,
          child: Listener(
            behavior: widget.behavior,
            onPointerDown: interactive ? _onPointerDown : null,
            onPointerMove: interactive ? _onPointerMove : null,
            onPointerUp: _onPointerEnd,
            onPointerCancel: _onPointerEnd,
            child: GestureDetector(
              behavior: widget.behavior,
              excludeFromSemantics: true,
              // A harmless extra release when the arena rejects the tap.
              onTapCancel: interactive ? _release : null,
              onTap: interactive && widget.onTap != null ? _handleTap : null,
              onLongPress: interactive && widget.onLongPress != null ? _handleLongPress : null,
              dragStartBehavior: DragStartBehavior.down,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Keyboard focus indication (hardware keyboards / accessibility switches).
class _FocusRing extends StatelessWidget {
  const _FocusRing({required this.child, required this.visible, this.radius});

  final Widget child;
  final bool visible;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: visible
          ? BoxDecoration(
              borderRadius: radius ?? BorderRadius.circular(999),
              border: Border.all(color: context.tokens.accent, width: 1.5),
            )
          : const BoxDecoration(),
      child: child,
    );
  }
}
