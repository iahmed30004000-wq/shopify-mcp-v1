import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/gen/app_localizations.dart';
import '../../motion/motion.dart';
import '../../sound/sound_api.dart';
import '../actions.dart';
import '../interaction_math.dart';
import 'glass.dart';
import 'pressable.dart';

/// One row of the context menu.
@immutable
class KitMenuEntry {
  const KitMenuEntry({
    required this.id,
    required this.icon,
    required this.label,
    required this.run,
    this.tone = ActionTone.neutral,
    this.sfx = Sfx.tap,
    this.enabled = true,
    this.dividerBefore = false,
  });

  final String id;
  final IconData icon;
  final String label;
  final FutureOr<void> Function() run;
  final ActionTone tone;
  final Sfx? sfx;
  final bool enabled;
  final bool dividerBefore;
}

/// Popup route showing a lifted snapshot of an item above a blurred scrim,
/// with a glass menu anchored to it. Pops with the chosen [KitMenuEntry].
class KitContextMenuRoute extends PopupRoute<KitMenuEntry> {
  KitContextMenuRoute({
    required this.itemRect,
    required this.entries,
    required this.tokens,
    required this.reduced,
    required this.barrierText,
    required this.itemBorderRadius,
    this.snapshot,
    this.snapshotScale = 1,
    this.fallback,
    this.startScale = MadarMotion.pressScale,
  });

  /// Item bounds in the navigator overlay's coordinates.
  final Rect itemRect;
  final List<KitMenuEntry> entries;
  final MadarTokens tokens;
  final bool reduced;
  final String barrierText;
  final BorderRadius itemBorderRadius;

  /// Pixel snapshot of the item (owned and disposed by the route).
  final ui.Image? snapshot;
  final double snapshotScale;

  /// Used when no snapshot could be taken.
  final WidgetBuilder? fallback;
  final double startScale;

  static const double liftScale = 1.03;
  static final Duration _springTimeline = InteractionSpringCurve.settleDuration(MadarMotion.bouncy);

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => barrierText;

  @override
  Duration get transitionDuration => reduced ? MadarMotion.reduced : _springTimeline;

  @override
  Duration get reverseTransitionDuration => reduced ? MadarMotion.reduced : MadarMotion.short;

  @override
  Widget buildModalBarrier() {
    final anim = animation!;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: AnimatedBuilder(
            animation: anim,
            builder: (context, _) {
              final t = Curves.easeOut.transform(anim.value.clamp(0.0, 1.0));
              final scrim = ColoredBox(color: tokens.space0.withValues(alpha: (tokens.isDark ? 0.42 : 0.22) * t));
              if (t <= 0.01) return scrim;
              final sigma = 9.0 * t;
              return BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: scrim);
            },
          ),
        ),
        ModalBarrier(dismissible: true, semanticsLabel: barrierText, barrierSemanticsDismissible: true),
      ],
    );
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _ContextMenuPage(route: this, animation: animation);
  }

  @override
  void dispose() {
    snapshot?.dispose();
    super.dispose();
  }
}

class _ContextMenuPage extends StatelessWidget {
  const _ContextMenuPage({required this.route, required this.animation});

  final KitContextMenuRoute route;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final dir = Directionality.of(context);
    final spring = route.reduced
        ? const Interval(0, 1)
        : InteractionSpringCurve(MadarMotion.bouncy, timeline: route.transitionDuration);
    final snappy = route.reduced
        ? const Interval(0, 1)
        : InteractionSpringCurve(MadarMotion.snappy, timeline: route.transitionDuration);
    final lift = CurvedAnimation(parent: animation, curve: spring, reverseCurve: MadarMotion.standard);
    final pop = CurvedAnimation(parent: animation, curve: snappy, reverseCurve: MadarMotion.accelerate);
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
      reverseCurve: const Interval(0, 0.7, curve: Curves.easeIn),
    );
    final estimatedMenu = Size(
      260,
      route.entries.length * 48.0 + route.entries.where((e) => e.dividerBefore).length * 9 + 16,
    );
    final estimate = ContextMenuLayout.compute(
      item: route.itemRect,
      menu: estimatedMenu,
      screen: mq.size,
      safe: mq.padding,
      direction: dir,
    );

    final item = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedBuilder(
        animation: lift,
        builder: (context, child) {
          final v = lift.value;
          final scale = route.startScale + (KitContextMenuRoute.liftScale - route.startScale) * v;
          return Transform.scale(
            scale: scale,
            child: CustomPaint(
              painter: InteractionGlowPainter(
                radius: route.itemBorderRadius,
                color: route.tokens.accentGlow.withValues(alpha: route.tokens.accentGlow.a * 0.45 * v.clamp(0.0, 1.0)),
                sigma: 22,
                offset: const Offset(0, 10),
              ),
              child: child,
            ),
          );
        },
        child: ExcludeSemantics(child: _snapshot(context)),
      ),
    );

    final menu = FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.82, end: 1).animate(pop),
        alignment: AlignmentDirectional(-1, estimate.below ? -1 : 1).resolve(dir),
        child: _MenuPanel(route: route, animation: animation),
      ),
    );

    return CustomMultiChildLayout(
      delegate: _MenuLayoutDelegate(
        item: route.itemRect,
        safe: mq.padding,
        direction: dir,
        progress: lift,
      ),
      children: [
        LayoutId(id: _Slot.item, child: item),
        LayoutId(id: _Slot.menu, child: menu),
      ],
    );
  }

  Widget _snapshot(BuildContext context) {
    final image = route.snapshot;
    if (image != null) {
      return RawImage(image: image, scale: route.snapshotScale, fit: BoxFit.fill);
    }
    return IgnorePointer(child: route.fallback?.call(context) ?? const SizedBox.shrink());
  }
}

enum _Slot { item, menu }

class _MenuLayoutDelegate extends MultiChildLayoutDelegate {
  _MenuLayoutDelegate({required this.item, required this.safe, required this.direction, required this.progress})
      : super(relayout: progress);

  final Rect item;
  final EdgeInsets safe;
  final TextDirection direction;
  final Animation<double> progress;

  @override
  void performLayout(Size size) {
    final maxW = math.min(280.0, size.width - 24);
    final maxH = math.max(0.0, size.height - safe.vertical - 24);
    final menu = layoutChild(_Slot.menu, BoxConstraints(minWidth: math.min(220, maxW), maxWidth: maxW, maxHeight: maxH));
    final p = ContextMenuLayout.compute(item: item, menu: menu, screen: size, safe: safe, direction: direction);
    positionChild(_Slot.menu, p.menuOffset);
    layoutChild(_Slot.item, BoxConstraints.tight(item.size));
    final t = progress.value.clamp(0.0, 1.0);
    positionChild(_Slot.item, Offset.lerp(item.topLeft, p.itemOffset, t)!);
  }

  @override
  bool shouldRelayout(_MenuLayoutDelegate old) =>
      old.item != item || old.safe != safe || old.direction != direction || old.progress != progress;
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.route, required this.animation});

  final KitContextMenuRoute route;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = L10n.of(context);
    final entries = route.entries;
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (e.dividerBefore && i > 0) {
        rows.add(Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m, vertical: Space.xs),
          child: Container(height: 0.8, color: t.glassBorder.withValues(alpha: 0.6)),
        ));
      }
      // Staggered entrance of the rows.
      final start = route.reduced ? 0.0 : math.min(0.5, 0.05 + i * 0.045);
      final curved = animation.drive(
        CurveTween(curve: Interval(start, math.min(1, start + 0.4), curve: MadarMotion.decelerate)),
      );
      rows.add(FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(curved),
          child: _MenuRow(entry: e),
        ),
      ));
    }
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l10n.interactionMenuLabel,
      child: InteractionGlass(
        borderRadius: BorderRadius.circular(t.radiusL),
        dense: true,
        glowSigma: 24,
        padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s),
        child: IntrinsicWidth(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.entry});

  final KitMenuEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final color = entry.enabled ? entry.tone.resolve(t) : t.textTertiary;
    final iconColor = entry.tone == ActionTone.neutral && entry.enabled ? t.textSecondary : color;
    return KitPressable(
      enabled: entry.enabled,
      sfx: entry.sfx,
      pressScale: 0.98,
      semanticLabel: entry.label,
      excludeSemantics: true,
      onTap: () => Navigator.of(context).pop(entry),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l, vertical: Space.s),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (entry.tone == ActionTone.neutral ? t.accent : color).withValues(alpha: 0.12),
                ),
                child: Icon(entry.icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: Space.m),
              Flexible(
                child: Text(
                  entry.label,
                  style: text.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
