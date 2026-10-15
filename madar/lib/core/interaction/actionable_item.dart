import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import '../design/tokens.dart';
import '../i18n/gen/app_localizations.dart';
import '../motion/motion.dart';
import '../sound/sound_api.dart';
import 'actions.dart';
import 'interaction_math.dart';
import 'src/context_menu_route.dart';
import 'src/grip_registry.dart';
import 'src/pressable.dart';
import 'undo_toast.dart';

/// Wraps any list row with Madar's universal item interactions:
///
/// * **Tap** → [onTap] (primary action) with a spring press.
/// * **Long-press** → the item lifts (Sfx.pickUp) above a blurred scrim and a
///   glass context menu offers Edit / Duplicate / Move / Set reminder /
///   [ItemActions.extra] / Delete. Delete dissolves the row and shows an undo
///   toast.
/// * **Swipe right** (physical, regardless of text direction) → complete/log
///   ([onCompleteSwipe]); a success track glows and a check pops in at the
///   threshold (Sfx.countTick), release fires Sfx.complete.
/// * **Swipe left** → a tray of [quickActions] that stays open until tapped
///   elsewhere.
///
/// Coexists with vertical scrolling (gesture arena) and with [ReorderGrip]
/// handles placed inside [child]. Every action is also exposed as a
/// semantics action for screen readers.
class ActionableItem extends StatefulWidget {
  const ActionableItem({
    super.key,
    required this.child,
    this.onTap,
    this.actions = ItemActions.none,
    this.onCompleteSwipe,
    this.quickActions = const [],
    this.enabled = true,
    this.longPressEnabled = true,
    this.swipeEnabled = true,
    this.borderRadius,
    this.semanticLabel,
    this.completeIcon = Icons.check_rounded,
    this.completeLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final ItemActions actions;

  /// Called when the row is swiped right past the threshold. Returning an
  /// [UndoableAction] shows the undo toast.
  final FutureOr<UndoableAction?> Function()? onCompleteSwipe;

  /// Revealed by swiping left.
  final List<QuickAction> quickActions;

  /// Master switch for every gesture.
  final bool enabled;
  final bool longPressEnabled;
  final bool swipeEnabled;

  /// Shape of the row (for the swipe track and the lifted snapshot glow).
  /// Defaults to [MadarTokens.radiusM].
  final BorderRadius? borderRadius;
  final String? semanticLabel;
  final IconData completeIcon;

  /// Accessibility label of the complete action (defaults to "Complete").
  final String? completeLabel;

  @override
  State<ActionableItem> createState() => ActionableItemState();
}

/// Public so tests and parents can drive the item programmatically.
class ActionableItemState extends State<ActionableItem> with TickerProviderStateMixin {
  static const double _trayButtonWidth = 68;
  static const double _trayPadding = 8;

  final GlobalKey _snapshotKey = GlobalKey();

  /// Displayed horizontal offset in physical px (+ = right).
  late final AnimationController _offset = AnimationController.unbounded(vsync: this);

  /// Press depth 0..1.
  late final AnimationController _press = AnimationController.unbounded(vsync: this);

  /// Check badge scale (spring, 0..1+).
  late final AnimationController _check = AnimationController.unbounded(vsync: this);

  /// Success flash after a completed swipe.
  late final AnimationController _flash = AnimationController(vsync: this, duration: MadarMotion.long);

  /// Delete dissolve 0..1.
  late final AnimationController _dissolve = AnimationController(vsync: this, duration: MadarMotion.short);

  /// Grace period before a dissolved row that was not removed reappears.
  late final AnimationController _hold = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  double _raw = 0;
  double _width = 0;
  bool _dragging = false;
  bool _armed = false;
  bool _trayOpen = false;
  bool _menuOpen = false;

  bool get _canComplete => widget.enabled && widget.swipeEnabled && widget.onCompleteSwipe != null;
  bool get _hasTray => widget.enabled && widget.swipeEnabled && widget.quickActions.isNotEmpty;
  bool get _hasMenu => widget.enabled && widget.longPressEnabled && !widget.actions.isEmpty;
  bool get _swipeable => _canComplete || _hasTray;
  double get _threshold => SwipeMath.completeThreshold(_width);
  double get _trayWidth => widget.quickActions.length * _trayButtonWidth + _trayPadding * 2;

  /// Whether the quick-action tray is open.
  bool get trayOpen => _trayOpen;

  @override
  void initState() {
    super.initState();
    _hold.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) _dissolve.reverse();
    });
  }

  @override
  void didUpdateWidget(ActionableItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_trayOpen && !_hasTray) closeTray();
  }

  @override
  void dispose() {
    _offset.dispose();
    _press.dispose();
    _check.dispose();
    _flash.dispose();
    _dissolve.dispose();
    _hold.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ helpers ----

  bool _allowPointer(PointerEvent event) => !GripPointerRegistry.contains(event.pointer);

  void _springTo(AnimationController c, double target, {SpringDescription? spring, double velocity = 0}) {
    if (context.reducedMotion) {
      c.animateTo(target, duration: MadarMotion.reduced, curve: Curves.easeOut);
      return;
    }
    c.animateWith(SpringSimulation(spring ?? MadarMotion.snappy, c.value, target, velocity)).then((_) {
      // Springs settle within a tolerance; land exactly (crisp text, exact
      // hit-testing). The future never completes if the spring was replaced.
      if (mounted && !c.isAnimating) c.value = target;
    });
  }

  void _pressTo(double v) => _springTo(_press, v);

  // --------------------------------------------------------------- tap ----

  void _onTapDown(TapDownDetails _) => _pressTo(1);
  void _onTapUp(TapUpDetails _) => _pressTo(0);
  void _onTapCancel() => _pressTo(0);

  void _handleTap() {
    if (_trayOpen) {
      closeTray();
      return;
    }
    if (widget.onTap == null || !widget.enabled) return;
    Fx.fire(Sfx.tap);
    widget.onTap!();
  }

  // ------------------------------------------------------------ swipes ----

  void _onDragStart(DragStartDetails d) {
    _offset.stop();
    _dragging = true;
    _raw = _offset.value;
    _armed = SwipeMath.completeProgress(_offset.value, _threshold) >= 1;
    _pressTo(0);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    _raw += d.delta.dx;
    final display = SwipeMath.displayOffset(
      raw: _raw,
      threshold: _threshold,
      trayWidth: _trayWidth,
      canComplete: _canComplete,
      hasTray: _hasTray,
      width: _width,
    );
    _offset.value = display;
    final armed = _canComplete && SwipeMath.completeProgress(display, _threshold) >= 1;
    if (armed != _armed) {
      _armed = armed;
      if (armed) {
        Fx.fire(Sfx.countTick);
        _springTo(_check, 1, spring: MadarMotion.bouncy);
      } else {
        Fx.fire(Sfx.countTick, volume: 0.45, pitch: 0.85);
        _springTo(_check, 0);
      }
    }
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final settle = SwipeMath.settle(
      display: _offset.value,
      velocity: d.velocity.pixelsPerSecond.dx,
      threshold: _threshold,
      trayWidth: _trayWidth,
      canComplete: _canComplete,
      hasTray: _hasTray,
    );
    final v = d.velocity.pixelsPerSecond.dx;
    switch (settle) {
      case SwipeSettle.complete:
        _complete(v);
      case SwipeSettle.openTray:
        if (!_trayOpen) Fx.fire(Sfx.swipe);
        setState(() => _trayOpen = true);
        _springTo(_offset, -_trayWidth, velocity: v);
      case SwipeSettle.closed:
        if (_trayOpen) setState(() => _trayOpen = false);
        _springTo(_offset, 0, velocity: v);
    }
    if (settle != SwipeSettle.complete && _armed) {
      _armed = false;
      _springTo(_check, 0);
    }
  }

  void _onDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _armed = false;
    _springTo(_check, 0);
    _springTo(_offset, _trayOpen ? -_trayWidth : 0);
  }

  Future<void> _complete(double velocity) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    Fx.fire(Sfx.complete);
    if (!context.reducedMotion) _flash.forward(from: 0);
    _armed = false;
    if (_trayOpen) setState(() => _trayOpen = false);
    _springTo(_offset, 0, spring: MadarMotion.gentle, velocity: math.min(velocity, 0));
    // Let the check linger a beat, then fold away with the track.
    _springTo(_check, 0, spring: MadarMotion.gentle);
    final cb = widget.onCompleteSwipe;
    if (cb == null) return;
    final undo = await _guard(cb);
    if (undo != null) unawaited(UndoToast.show(overlay, undo));
  }

  /// Programmatically closes the quick-action tray.
  void closeTray() {
    if (!mounted) return;
    if (_trayOpen) setState(() => _trayOpen = false);
    _springTo(_offset, 0);
  }

  /// Programmatically opens the quick-action tray.
  void openTray() {
    if (!_hasTray) return;
    Fx.fire(Sfx.swipe);
    setState(() => _trayOpen = true);
    _springTo(_offset, -_trayWidth);
  }

  Future<void> _runQuick(QuickAction a) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    closeTray();
    final undo = await _guard(a.onPressed);
    if (undo != null) unawaited(UndoToast.show(overlay, undo));
  }

  // -------------------------------------------------------- long-press ----

  Future<void> openMenu() async {
    if (!_hasMenu || _menuOpen || !mounted) return;
    if (_trayOpen) closeTray();
    final nav = Navigator.of(context, rootNavigator: true);
    final overlayBox = nav.overlay?.context.findRenderObject() as RenderBox?;
    final box = context.findRenderObject() as RenderBox?;
    if (overlayBox == null || box == null || !box.hasSize) return;
    final l10n = L10n.of(context);
    final t = context.tokens;
    final reduced = context.reducedMotion;
    final radius = widget.borderRadius ?? BorderRadius.circular(t.radiusM);
    final origin = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final rect = origin & box.size;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    ui.Image? image;
    try {
      final boundary = _snapshotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null && boundary.hasSize) image = boundary.toImageSync(pixelRatio: dpr);
    } catch (_) {
      image = null;
    }
    Fx.fire(Sfx.pickUp);
    setState(() => _menuOpen = true);
    final entries = _menuEntries(l10n);
    final child = widget.child;
    final theme = Theme.of(context);
    final textStyle = DefaultTextStyle.of(context);
    final route = KitContextMenuRoute(
      itemRect: rect,
      entries: entries,
      tokens: t,
      reduced: reduced,
      barrierText: l10n.interactionMenuDismiss,
      itemBorderRadius: radius,
      snapshot: image,
      snapshotScale: dpr,
      startScale: 1 - (1 - MadarMotion.pressScale) * _press.value.clamp(0.0, 1.0),
      fallback: (_) => Theme(
        data: theme,
        child: DefaultTextStyle(
          style: textStyle.style,
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
    _pressTo(0);
    final choice = await nav.push(route);
    if (choice == null) Fx.fire(Sfx.drop);
    // `push` resolves as soon as the menu pops; keep the row hidden until the
    // lifted snapshot has landed back on it, so the two never show at once
    // and a delete dissolves the settled row.
    await route.completed;
    if (mounted) setState(() => _menuOpen = false);
    if (choice == null) return;
    await choice.run();
  }

  List<KitMenuEntry> _menuEntries(L10n l10n) {
    final a = widget.actions;
    return [
      if (a.onEdit != null)
        KitMenuEntry(id: 'edit', icon: Icons.edit_rounded, label: l10n.actionEdit, run: () => a.onEdit!()),
      if (a.onDuplicate != null)
        KitMenuEntry(
          id: 'duplicate',
          icon: Icons.content_copy_rounded,
          label: l10n.actionDuplicate,
          run: () => _runUndoable(a.onDuplicate!),
        ),
      if (a.onMove != null)
        KitMenuEntry(
          id: 'move',
          icon: Icons.drive_file_move_rounded,
          label: l10n.actionMove,
          run: () => _runUndoable(a.onMove!),
        ),
      if (a.onSetReminder != null)
        KitMenuEntry(
          id: 'reminder',
          icon: Icons.notifications_active_rounded,
          label: l10n.actionSetReminder,
          run: () => a.onSetReminder!(),
        ),
      for (final (i, x) in a.extra.indexed)
        KitMenuEntry(
          id: 'extra$i',
          icon: x.icon,
          label: x.label,
          tone: x.tone,
          enabled: x.enabled,
          run: () => _runUndoable(x.onSelected),
        ),
      if (a.onDelete != null)
        KitMenuEntry(
          id: 'delete',
          icon: Icons.delete_outline_rounded,
          label: l10n.actionDelete,
          tone: ActionTone.danger,
          sfx: null,
          dividerBefore: true,
          run: delete,
        ),
    ];
  }

  Future<void> _runUndoable(FutureOr<UndoableAction?> Function() action) async {
    if (!mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final undo = await _guard(action);
    if (undo != null) unawaited(UndoToast.show(overlay, undo));
  }

  /// Dissolves the row, runs [ItemActions.onDelete] and offers undo.
  Future<void> delete() async {
    final onDelete = widget.actions.onDelete;
    if (onDelete == null || !mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    Fx.fire(Sfx.delete);
    _hold.stop();
    await _dissolve.animateTo(1, duration: context.motion(MadarMotion.short), curve: MadarMotion.accelerate);
    final undo = await _guard(onDelete, restoreOnError: true);
    if (undo != null) unawaited(UndoToast.show(overlay, undo));
    // Normally the row is removed by now; if not, bring it back.
    if (mounted) _hold.forward(from: 0);
  }

  Future<UndoableAction?> _guard(FutureOr<UndoableAction?> Function() action, {bool restoreOnError = false}) async {
    try {
      return await action();
    } catch (e, s) {
      Fx.fire(Sfx.error);
      if (restoreOnError && mounted) _dissolve.reverse();
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s, library: 'madar interaction'));
      return null;
    }
  }

  Future<void> _completeFromSemantics() async {
    Fx.fire(Sfx.complete);
    final overlay = Overlay.of(context, rootOverlay: true);
    final undo = await _guard(widget.onCompleteSwipe!);
    if (undo != null) unawaited(UndoToast.show(overlay, undo));
  }

  // ------------------------------------------------------------- build ----

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = L10n.of(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(t.radiusM);

    Widget content = RepaintBoundary(key: _snapshotKey, child: widget.child);
    content = AnimatedBuilder(
      animation: _press,
      builder: (context, child) =>
          Transform.scale(scale: 1 - (1 - MadarMotion.pressScale) * _press.value, child: child),
      child: content,
    );
    content = AnimatedBuilder(
      animation: _offset,
      builder: (context, child) => Transform.translate(offset: Offset(_offset.value, 0), child: child),
      child: content,
    );

    Widget stack = LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (_swipeable)
              Positioned.fill(
                child: _SwipeBackdrop(
                  offset: _offset,
                  check: _check,
                  flash: _flash,
                  radius: radius,
                  threshold: _threshold,
                  completeIcon: widget.completeIcon,
                  quickActions: _hasTray ? widget.quickActions : const [],
                  trayButtonWidth: _trayButtonWidth,
                  trayPadding: _trayPadding,
                  onQuick: _runQuick,
                ),
              ),
            content,
          ],
        );
      },
    );

    final recognizers = <Type, GestureRecognizerFactory>{
      _ItemTapRecognizer: GestureRecognizerFactoryWithHandlers<_ItemTapRecognizer>(
        () => _ItemTapRecognizer(allow: _allowPointer, debugOwner: this),
        (r) {
          final pressable = widget.enabled && widget.onTap != null;
          r
            ..onTapDown = pressable ? _onTapDown : null
            ..onTapUp = pressable ? _onTapUp : null
            ..onTapCancel = pressable ? _onTapCancel : null
            ..onTap = widget.enabled ? _handleTap : null;
        },
      ),
      if (_hasMenu)
        _ItemLongPressRecognizer: GestureRecognizerFactoryWithHandlers<_ItemLongPressRecognizer>(
          () => _ItemLongPressRecognizer(allow: _allowPointer, debugOwner: this),
          (r) => r..onLongPress = openMenu,
        ),
      if (_swipeable)
        _ItemDragRecognizer: GestureRecognizerFactoryWithHandlers<_ItemDragRecognizer>(
          () => _ItemDragRecognizer(allow: _allowPointer, debugOwner: this),
          (r) => r
            ..onStart = _onDragStart
            ..onUpdate = _onDragUpdate
            ..onEnd = _onDragEnd
            ..onCancel = _onDragCancel,
        ),
    };

    Widget result = RawGestureDetector(
      gestures: recognizers,
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      child: stack,
    );

    result = TapRegion(enabled: _trayOpen, onTapOutside: (_) => closeTray(), child: result);

    // Delete dissolve: collapse height, fade and sink slightly.
    result = AnimatedBuilder(
      animation: _dissolve,
      builder: (context, child) {
        final v = _dissolve.value;
        if (v == 0) return child!;
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            heightFactor: (1 - Curves.easeInOut.transform(v)).clamp(0.0, 1.0),
            child: Opacity(
              opacity: (1 - v * 1.4).clamp(0.0, 1.0),
              child: Transform.scale(scale: 1 - 0.06 * v, child: child),
            ),
          ),
        );
      },
      child: result,
    );

    final a = widget.actions;
    final semanticActions = <CustomSemanticsAction, VoidCallback>{
      if (widget.enabled && a.onEdit != null) CustomSemanticsAction(label: l10n.actionEdit): () => a.onEdit!(),
      if (widget.enabled && a.onDuplicate != null)
        CustomSemanticsAction(label: l10n.actionDuplicate): () => _runUndoable(a.onDuplicate!),
      if (widget.enabled && a.onMove != null)
        CustomSemanticsAction(label: l10n.actionMove): () => _runUndoable(a.onMove!),
      if (widget.enabled && a.onSetReminder != null)
        CustomSemanticsAction(label: l10n.actionSetReminder): () => a.onSetReminder!(),
      if (widget.enabled)
        for (final x in a.extra.where((x) => x.enabled))
          CustomSemanticsAction(label: x.label): () => _runUndoable(x.onSelected),
      if (widget.enabled && a.onDelete != null) CustomSemanticsAction(label: l10n.actionDelete): delete,
      if (widget.enabled && widget.onCompleteSwipe != null)
        CustomSemanticsAction(label: widget.completeLabel ?? l10n.actionComplete): _completeFromSemantics,
      if (widget.enabled)
        for (final q in widget.quickActions) CustomSemanticsAction(label: q.label): () => _runQuick(q),
    };

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      hint: _canComplete ? l10n.interactionSwipeToComplete : null,
      onTap: widget.enabled && widget.onTap != null ? _handleTap : null,
      onLongPress: _hasMenu ? openMenu : null,
      customSemanticsActions: semanticActions.isEmpty ? null : semanticActions,
      child: Opacity(opacity: _menuOpen ? 0.0 : 1.0, child: result),
    );
  }
}

// ------------------------------------------------------------ recognizers --

typedef _PointerFilter = bool Function(PointerEvent event);

class _ItemTapRecognizer extends TapGestureRecognizer {
  _ItemTapRecognizer({required this.allow, super.debugOwner});
  final _PointerFilter allow;

  @override
  bool isPointerAllowed(PointerDownEvent event) => allow(event) && super.isPointerAllowed(event);
}

class _ItemLongPressRecognizer extends LongPressGestureRecognizer {
  _ItemLongPressRecognizer({required this.allow, super.debugOwner});
  final _PointerFilter allow;

  @override
  bool isPointerAllowed(PointerDownEvent event) => allow(event) && super.isPointerAllowed(event);
}

class _ItemDragRecognizer extends HorizontalDragGestureRecognizer {
  _ItemDragRecognizer({required this.allow, super.debugOwner});
  final _PointerFilter allow;

  @override
  bool isPointerAllowed(PointerEvent event) => allow(event) && super.isPointerAllowed(event);
}

// ----------------------------------------------------------- swipe track --

class _SwipeBackdrop extends StatelessWidget {
  const _SwipeBackdrop({
    required this.offset,
    required this.check,
    required this.flash,
    required this.radius,
    required this.threshold,
    required this.completeIcon,
    required this.quickActions,
    required this.trayButtonWidth,
    required this.trayPadding,
    required this.onQuick,
  });

  final Animation<double> offset, check, flash;
  final BorderRadius radius;
  final double threshold;
  final IconData completeIcon;
  final List<QuickAction> quickActions;
  final double trayButtonWidth, trayPadding;
  final ValueChanged<QuickAction> onQuick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedBuilder(
      animation: Listenable.merge([offset, check, flash]),
      builder: (context, _) {
        final dx = offset.value;
        final f = flash.isAnimating || flash.value > 0 ? math.sin(flash.value * math.pi) : 0.0;
        if (dx.abs() < 0.5 && f == 0) return const SizedBox.shrink();
        // Physical sides on purpose: swipe direction is physical.
        if (dx >= 0) {
          final progress = SwipeMath.completeProgress(dx, threshold);
          return RepaintBoundary(
            child: CustomPaint(
              painter: _CompleteTrackPainter(
                reveal: dx,
                progress: progress,
                armed: check.value,
                flash: f,
                radius: radius,
                color: t.success,
                glow: t.success,
                track: t.glassFill,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: math.max(56, dx),
                  child: Center(
                    child: _CheckBadge(progress: progress, scale: check.value, icon: completeIcon),
                  ),
                ),
              ),
            ),
          );
        }
        final reveal = -dx;
        final trayWidth = quickActions.length * trayButtonWidth + trayPadding * 2;
        final fraction = trayWidth == 0 ? 0.0 : (reveal / trayWidth).clamp(0.0, 1.2);
        // The tray is uncovered from the physical right edge inwards; the Row
        // follows the reading direction, so map each button to its physical
        // slot counted from the right.
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final n = quickActions.length;
        return ClipRRect(
          borderRadius: radius,
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: math.max(reveal, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [t.space2.withValues(alpha: 0), t.space2.withValues(alpha: 0.75)],
                  ),
                ),
                child: OverflowBox(
                  alignment: Alignment.centerRight,
                  minWidth: trayWidth,
                  maxWidth: trayWidth,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: trayPadding),
                    child: Row(
                      children: [
                        for (final (i, q) in quickActions.indexed)
                          SizedBox(
                            width: trayButtonWidth,
                            child: _TrayButton(
                              action: q,
                              // Buttons pop in as the row uncovers them.
                              reveal: ((fraction * n) - (rtl ? i : n - 1 - i) * 0.6).clamp(0.0, 1.0),
                              onTap: () => onQuick(q),
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
      },
    );
  }
}

class _CompleteTrackPainter extends CustomPainter {
  _CompleteTrackPainter({
    required this.reveal,
    required this.progress,
    required this.armed,
    required this.flash,
    required this.radius,
    required this.color,
    required this.glow,
    required this.track,
  });

  final double reveal, progress, armed, flash;
  final BorderRadius radius;
  final Color color, glow, track;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rrect = radius.toRRect(Offset.zero & size);
    final p = progress.clamp(0.0, 1.0);
    final a = armed.clamp(0.0, 1.0);
    // Base track.
    canvas.drawRRect(rrect, Paint()..color = track);
    // Success wash from the left edge, stronger as the threshold nears.
    final width = math.max(1.0, math.min(size.width, reveal + 24));
    final wash = Rect.fromLTWH(0, 0, width, size.height);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      wash,
      Paint()
        ..shader = ui.Gradient.linear(wash.centerLeft, wash.centerRight, [
          color.withValues(alpha: 0.16 + 0.34 * p + 0.2 * a + 0.2 * flash),
          color.withValues(alpha: 0.04 + 0.1 * a),
        ]),
    );
    if (a > 0 || flash > 0) {
      final c = Offset(math.max(28, reveal / 2), size.height / 2);
      canvas.drawCircle(
        c,
        size.height * (0.7 + 0.5 * flash),
        Paint()
          ..shader = ui.Gradient.radial(c, size.height * (0.7 + 0.5 * flash), [
            glow.withValues(alpha: 0.35 * math.max(a, flash)),
            glow.withValues(alpha: 0),
          ]),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompleteTrackPainter old) =>
      old.reveal != reveal ||
      old.progress != progress ||
      old.armed != armed ||
      old.flash != flash ||
      old.radius != radius ||
      old.color != color ||
      old.track != track;
}

/// Progress ring that fills while dragging; the check pops in (spring) at
/// the threshold.
class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.progress, required this.scale, required this.icon});

  final double progress;
  final double scale;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = scale.clamp(0.0, 1.4);
    return SizedBox.square(
      dimension: 36,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          color: t.success,
          track: t.glassBorder,
          fill: s.clamp(0.0, 1.0),
        ),
        child: Center(
          child: Transform.scale(
            scale: s,
            child: Icon(icon, size: 20, color: t.isDark ? t.space0 : t.textOnAccent),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track, required this.fill});

  final double progress, fill;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = track,
    );
    if (fill > 0) canvas.drawCircle(c, r * fill, Paint()..color = color);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.fill != fill || old.color != color || old.track != track;
}

class _TrayButton extends StatelessWidget {
  const _TrayButton({required this.action, required this.reveal, required this.onTap});

  final QuickAction action;
  final double reveal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = action.tone.resolve(t);
    final text = Theme.of(context).textTheme;
    final r = Curves.easeOutBack.transform(reveal.clamp(0.0, 1.0));
    return Opacity(
      opacity: reveal.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.6 + 0.4 * r,
        child: KitPressable(
          onTap: onTap,
          semanticLabel: action.label,
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16),
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 12)],
                ),
                child: Icon(action.icon, size: 20, color: color),
              ),
              const SizedBox(height: Space.xxs),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
