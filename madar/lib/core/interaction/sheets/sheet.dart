import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import '../../design/tokens.dart';
import '../../i18n/gen/app_localizations.dart';
import '../../motion/motion.dart';
import '../../sound/sound_api.dart';
import '../interaction_math.dart';
import '../src/glass.dart';
import '../src/pressable.dart';

/// Opens an animated glass bottom sheet (spring rise, blurred scrim,
/// drag-to-dismiss, keyboard-aware). Build the content with
/// [InteractionSheetFrame] for the standard header / body / footer.
///
/// Pops through `Navigator.maybePop` when dragged down or tapped outside, so a
/// [PopScope] inside the sheet can veto the dismissal (unsaved changes).
Future<T?> showInteractionSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool useRootNavigator = true,
}) {
  final nav = Navigator.of(context, rootNavigator: useRootNavigator);
  Fx.fire(Sfx.sheetOpen);
  return nav.push(InteractionSheetRoute<T>(
    builder: builder,
    tokens: context.tokens,
    reduced: context.reducedMotion,
    barrierText: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  ));
}

/// The route behind [showInteractionSheet].
class InteractionSheetRoute<T> extends PopupRoute<T> {
  InteractionSheetRoute({
    required this.builder,
    required this.tokens,
    required this.reduced,
    required this.barrierText,
    super.settings,
  });

  final WidgetBuilder builder;
  final MadarTokens tokens;
  final bool reduced;
  final String barrierText;

  /// Rise spring: quick with a whisper of overshoot.
  static final SpringDescription rise = SpringDescription.withDampingRatio(mass: 1, stiffness: 300, ratio: 0.86);

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => barrierText;

  @override
  Duration get transitionDuration => reduced ? MadarMotion.reduced : InteractionSpringCurve.settleDuration(rise);

  @override
  Duration get reverseTransitionDuration => reduced ? MadarMotion.reduced : MadarMotion.short;

  @override
  bool didPop(T? result) {
    Fx.fire(Sfx.sheetClose);
    return super.didPop(result);
  }

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
              final scrim = ColoredBox(color: tokens.space0.withValues(alpha: (tokens.isDark ? 0.5 : 0.25) * t));
              if (t <= 0.01) return scrim;
              final sigma = 6.0 * t;
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
    return _SheetPage(route: this, animation: animation);
  }
}

/// Lets the frame's grabber, header and body drive the page's drag.
class _SheetDragScope extends InheritedWidget {
  const _SheetDragScope({required this.page, required super.child});

  final _SheetPageState page;

  static _SheetPageState? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SheetDragScope>()?.page;

  @override
  bool updateShouldNotify(_SheetDragScope oldWidget) => oldWidget.page != page;
}

class _SheetPage extends StatefulWidget {
  const _SheetPage({required this.route, required this.animation});

  final InteractionSheetRoute<dynamic> route;
  final Animation<double> animation;

  @override
  State<_SheetPage> createState() => _SheetPageState();
}

class _SheetPageState extends State<_SheetPage> with SingleTickerProviderStateMixin {
  late final AnimationController _drag = AnimationController.unbounded(vsync: this);
  late final CurvedAnimation _rise = CurvedAnimation(
    parent: widget.animation,
    curve: widget.route.reduced ? Curves.easeOut : InteractionSpringCurve(InteractionSheetRoute.rise),
    reverseCurve: MadarMotion.accelerate,
  );
  double _sheetHeight = 400;
  bool _settling = false;

  @override
  void dispose() {
    _rise.dispose();
    _drag.dispose();
    super.dispose();
  }

  void dragBy(double dy) {
    if (_settling) return;
    _drag.stop();
    var next = _drag.value + dy;
    if (next < 0) next = -SwipeMath.rubberBand(-next, 60);
    _drag.value = next;
  }

  Future<void> dragEnd(double velocity) async {
    if (_settling) return;
    final threshold = math.min(140.0, _sheetHeight * 0.28);
    if (_drag.value > threshold || (velocity > 900 && _drag.value > 8)) {
      _settling = true;
      final nav = Navigator.of(context);
      await nav.maybePop();
      _settling = false;
      if (!mounted) return;
      final status = widget.animation.status;
      if (status == AnimationStatus.reverse || status == AnimationStatus.dismissed) return;
    }
    _springBack(velocity);
  }

  void _springBack(double velocity) {
    if (context.reducedMotion) {
      _drag.animateTo(0, duration: MadarMotion.reduced);
      return;
    }
    _drag.animateWith(SpringSimulation(MadarMotion.snappy, _drag.value, 0, -velocity)).then((_) {
      if (mounted && !_drag.isAnimating) _drag.value = 0;
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is OverscrollNotification && n.dragDetails != null && n.overscroll < 0) {
      dragBy(-n.overscroll);
    } else if (n is ScrollUpdateNotification && n.dragDetails != null && _drag.value > 0 && (n.scrollDelta ?? 0) > 0) {
      dragBy(-(n.scrollDelta ?? 0));
    } else if (n is ScrollEndNotification && _drag.value != 0 && !_drag.isAnimating) {
      dragEnd(n.dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final maxHeight = math.max(200.0, mq.size.height - keyboard - mq.padding.top - Space.xl);
    return _SheetDragScope(
      page: this,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 640),
              child: AnimatedBuilder(
                animation: Listenable.merge([_rise, _drag]),
                builder: (context, child) {
                  final v = _rise.value;
                  return FractionalTranslation(
                    translation: Offset(0, 1 - v),
                    child: Transform.translate(offset: Offset(0, math.max(-60, _drag.value)), child: child),
                  );
                },
                child: _MeasureHeight(
                  onHeight: (h) => _sheetHeight = h,
                  child: Builder(builder: widget.route.builder),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasure(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasure renderObject) => renderObject.onHeight = onHeight;
}

class _RenderMeasure extends RenderProxyBox {
  _RenderMeasure(this.onHeight);
  ValueChanged<double> onHeight;

  @override
  void performLayout() {
    super.performLayout();
    onHeight(size.height);
  }
}

/// Standard sheet layout: brass grabber, Reem Kufi title with an optional
/// medallion icon and a faint eight-pointed star, a scrollable [body] and an
/// optional sticky [footer] above the keyboard / safe area.
class InteractionSheetFrame extends StatelessWidget {
  const InteractionSheetFrame({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.icon,
    this.footer,
    this.bodyPadding = const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.l),
    this.scrollable = true,
    this.scrollController,
    this.toolbar,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget body;
  final Widget? footer;
  final EdgeInsetsGeometry bodyPadding;
  final bool scrollable;
  final ScrollController? scrollController;

  /// Pinned under the header, above the scrolling body (e.g. a search field).
  final Widget? toolbar;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final page = _SheetDragScope.of(context);
    final radius = BorderRadius.vertical(top: Radius.circular(t.radiusXL));
    final bottomSafe = MediaQuery.viewInsetsOf(context).bottom > 0 ? 0.0 : MediaQuery.paddingOf(context).bottom;

    Widget header = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.m),
      child: Row(
        children: [
          if (icon != null) ...[
            _Medallion(icon: icon!),
            const SizedBox(width: Space.m),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: text.headlineSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: Space.xxs),
                    child: Text(subtitle!, style: text.bodySmall),
                  ),
              ],
            ),
          ),
          ExcludeSemantics(
            child: SizedBox.square(
              dimension: 34,
              child: CustomPaint(painter: StarOrnamentPainter(color: t.brass.withValues(alpha: 0.45), strokeWidth: 0.9)),
            ),
          ),
        ],
      ),
    );

    final grabber = Semantics(
      label: L10n.of(context).interactionSheetGrabber,
      child: SizedBox(
        height: 26,
        child: Center(
          child: Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(colors: [t.brassDark, t.gold, t.brassDark]),
              boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 8)],
            ),
          ),
        ),
      ),
    );

    Widget dragArea = Column(mainAxisSize: MainAxisSize.min, children: [grabber, header]);
    if (page != null) {
      dragArea = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => page.dragBy(d.delta.dy),
        onVerticalDragEnd: (d) => page.dragEnd(d.velocity.pixelsPerSecond.dy),
        onVerticalDragCancel: () => page.dragEnd(0),
        child: dragArea,
      );
    }

    Widget content = Padding(padding: bodyPadding, child: body);
    if (scrollable) {
      content = SingleChildScrollView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        child: content,
      );
    }

    return InteractionGlass(
      borderRadius: radius,
      dense: true,
      glowColor: t.glassShadow,
      glowSigma: 28,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            dragArea,
            if (toolbar != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.m),
                child: toolbar,
              ),
            Container(
              height: 0.8,
              margin: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [t.glassBorder.withValues(alpha: 0), t.glassBorder, t.glassBorder.withValues(alpha: 0)],
                ),
              ),
            ),
            Flexible(child: content),
            if (footer != null)
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.m + bottomSafe),
                child: footer,
              )
            else
              SizedBox(height: bottomSafe),
          ],
        ),
      ),
    );
  }
}

class _Medallion extends StatelessWidget {
  const _Medallion({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [t.accentSoft, t.accent.withValues(alpha: 0.05)]),
        border: Border.all(color: t.accent.withValues(alpha: 0.55), width: 0.9),
        boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: 0.3), blurRadius: 14)],
      ),
      child: Icon(icon, size: 21, color: t.accent),
    );
  }
}

/// Primary / secondary buttons used in sheet footers.
class SheetButton extends StatelessWidget {
  const SheetButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.enabled = true,
    this.icon,
    this.tone,
    this.onDisabledTap,
    this.sfx = Sfx.tap,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool enabled;
  final IconData? icon;

  /// Overrides the accent (e.g. danger for "Discard").
  final Color? tone;
  final VoidCallback? onDisabledTap;
  final Sfx? sfx;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final accent = tone ?? t.accent;
    final active = enabled && onPressed != null;
    final fg = primary ? (tone == null ? t.textOnAccent : t.textPrimary) : accent;
    return KitPressable(
      onTap: active ? onPressed : null,
      enabled: active,
      sfx: sfx,
      onDisabledTap: onDisabledTap,
      semanticLabel: label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: context.motion(MadarMotion.short),
        opacity: active ? 1 : 0.45,
        child: AnimatedContainer(
          duration: context.motion(MadarMotion.short),
          height: 50,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusXL),
            gradient: primary
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(accent, t.glassHighlight, 0.18)!, accent],
                  )
                : null,
            color: primary ? null : accent.withValues(alpha: 0.08),
            border: Border.all(color: accent.withValues(alpha: primary ? 0.9 : 0.4), width: 0.9),
            boxShadow: primary && active
                ? [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 4))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19, color: fg),
                const SizedBox(width: Space.s),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
