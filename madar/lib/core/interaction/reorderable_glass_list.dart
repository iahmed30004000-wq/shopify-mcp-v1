import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../design/tokens.dart';
import '../i18n/gen/app_localizations.dart';
import '../motion/motion.dart';
import '../sound/sound_api.dart';
import 'interaction_math.dart';
import 'src/grip_registry.dart';

/// Builds one row of a [ReorderableGlassList]. Place [dragHandle] wherever the
/// row's grip should be (typically the trailing edge); it can live inside an
/// [ActionableItem] without conflicting with its swipes.
typedef ReorderableItemBuilder<T> = Widget Function(BuildContext context, T item, int index, Widget dragHandle);

/// Generic drag-to-reorder list: explicit grips, a lifted proxy (scale 1.03,
/// accent glow, deep shadow), Sfx.pickUp / Sfx.drop, an optimistic local order
/// and a staggered entrance.
class ReorderableGlassList<T> extends StatefulWidget {
  const ReorderableGlassList({
    super.key,
    required this.items,
    required this.itemKey,
    required this.itemBuilder,
    required this.onReorder,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter, vertical: Space.m),
    this.spacing = Space.s,
    this.header,
    this.footer,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
    this.animateEntrance = true,
    this.itemBorderRadius,
  });

  final List<T> items;

  /// Stable identity of an item (e.g. its database id).
  final Object Function(T item) itemKey;
  final ReorderableItemBuilder<T> itemBuilder;

  /// Receives the complete list in its new order after every drop.
  final void Function(List<T> newOrder) onReorder;
  final EdgeInsetsGeometry padding;

  /// Gap below each row.
  final double spacing;
  final Widget? header;
  final Widget? footer;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final bool animateEntrance;

  /// Shape used for the lifted glow. Defaults to [MadarTokens.radiusM].
  final BorderRadius? itemBorderRadius;

  @override
  State<ReorderableGlassList<T>> createState() => _ReorderableGlassListState<T>();
}

class _ReorderableGlassListState<T> extends State<ReorderableGlassList<T>> {
  late List<T> _items = List<T>.of(widget.items);
  final Set<Object> _animated = <Object>{};
  Set<Object> _fresh = <Object>{};
  bool _initialPhase = true;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialPhase = false;
    });
  }

  @override
  void didUpdateWidget(ReorderableGlassList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      final before = {for (final i in _items) widget.itemKey(i)};
      _items = List<T>.of(widget.items);
      _fresh = {
        for (final i in _items)
          if (!before.contains(widget.itemKey(i))) widget.itemKey(i),
      };
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() => _items = reorderItems(_items, oldIndex, newIndex));
    widget.onReorder(List<T>.unmodifiable(_items));
  }

  Widget _proxy(Widget child, int index, Animation<double> animation) {
    return _ProxyScope(
      animation: animation,
      child: Material(type: MaterialType.transparency, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    final t = context.tokens;
    final radius = widget.itemBorderRadius ?? BorderRadius.circular(t.radiusM);
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: widget.padding.resolve(dir),
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      scrollController: widget.controller,
      header: widget.header,
      footer: widget.footer,
      itemCount: _items.length,
      proxyDecorator: _proxy,
      onReorderStart: (_) => Fx.fire(Sfx.pickUp),
      onReorderEnd: (_) => Fx.fire(Sfx.drop),
      onReorderItem: _onReorder,
      itemBuilder: (context, index) {
        final item = _items[index];
        final key = widget.itemKey(item);
        final fresh = _fresh.contains(key);
        final animate = widget.animateEntrance && !_animated.contains(key) && (_initialPhase || fresh);
        _animated.add(key);
        _fresh.remove(key);
        return _ReorderSlot(
          key: ValueKey<Object>(key),
          spacing: widget.spacing,
          radius: radius,
          entranceDelay: animate && !fresh ? _staggerDelay(index) : Duration.zero,
          animateEntrance: animate,
          child: widget.itemBuilder(context, item, index, ReorderGrip(index: index)),
        );
      },
    );
  }

  static Duration _staggerDelay(int index) {
    final d = MadarMotion.staggerStep * index;
    return d > MadarMotion.staggerCap ? MadarMotion.staggerCap : d;
  }
}

/// Marks the subtree as the floating drag proxy.
class _ProxyScope extends InheritedWidget {
  const _ProxyScope({required this.animation, required super.child});

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ProxyScope>()?.animation;

  @override
  bool updateShouldNotify(_ProxyScope oldWidget) => oldWidget.animation != animation;
}

class _ReorderSlot extends StatefulWidget {
  const _ReorderSlot({
    super.key,
    required this.spacing,
    required this.radius,
    required this.entranceDelay,
    required this.animateEntrance,
    required this.child,
  });

  final double spacing;
  final BorderRadius radius;
  final Duration entranceDelay;
  final bool animateEntrance;
  final Widget child;

  @override
  State<_ReorderSlot> createState() => _ReorderSlotState();
}

class _ReorderSlotState extends State<_ReorderSlot> with SingleTickerProviderStateMixin {
  AnimationController? _entrance;
  Animation<double>? _curve;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance != null || !widget.animateEntrance || _ProxyScope.maybeOf(context) != null) return;
    final reduced = context.reducedMotion;
    final body = reduced ? MadarMotion.reduced : MadarMotion.long;
    final delay = reduced ? Duration.zero : widget.entranceDelay;
    final total = delay + body;
    final c = AnimationController(vsync: this, duration: total);
    _entrance = c;
    _curve = CurvedAnimation(
      parent: c,
      curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1, curve: MadarMotion.decelerate),
    );
    c.forward();
  }

  @override
  void dispose() {
    _entrance?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final proxy = _ProxyScope.maybeOf(context);
    Widget item = widget.child;
    if (proxy != null) {
      item = AnimatedBuilder(
        animation: proxy,
        builder: (context, child) {
          final v = Curves.easeOutCubic.transform(proxy.value.clamp(0.0, 1.0));
          return Transform.scale(
            scale: 1 + 0.03 * v,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: widget.radius,
                boxShadow: [
                  BoxShadow(color: t.accentGlow.withValues(alpha: t.accentGlow.a * 0.4 * v), blurRadius: 26 * v),
                  BoxShadow(
                    color: t.glassShadow.withValues(alpha: t.glassShadow.a * v),
                    blurRadius: 22 * v,
                    offset: Offset(0, 12 * v),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: item,
      );
    } else if (_curve != null) {
      final curve = _curve!;
      item = AnimatedBuilder(
        animation: curve,
        builder: (context, child) {
          final v = curve.value;
          if (v >= 1) return child!;
          return Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: child),
          );
        },
        child: item,
      );
    }
    return Padding(padding: EdgeInsetsDirectional.only(bottom: widget.spacing), child: item);
  }
}

/// Drag handle for a row of a [ReorderableGlassList] (or any
/// [ReorderableListView] with `buildDefaultDragHandles: false`). Starts the
/// drag immediately on touch; [ActionableItem] ignores pointers that land on
/// a grip.
class ReorderGrip extends StatelessWidget {
  const ReorderGrip({super.key, required this.index, this.enabled = true, this.size = 44});

  final int index;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: L10n.of(context).interactionReorderHandle,
      child: Listener(
        onPointerDown: (e) => GripPointerRegistry.add(e.pointer),
        onPointerUp: (e) => GripPointerRegistry.remove(e.pointer),
        onPointerCancel: (e) => GripPointerRegistry.remove(e.pointer),
        child: ReorderableDragStartListener(
          index: index,
          enabled: enabled,
          child: MouseRegion(
            cursor: enabled ? SystemMouseCursors.grab : MouseCursor.defer,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: Icon(Icons.drag_indicator_rounded, size: 22, color: enabled ? t.textTertiary : t.glassBorder),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
