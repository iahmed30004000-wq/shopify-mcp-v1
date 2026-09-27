import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../i18n/gen/app_localizations.dart';
import '../../motion/motion.dart';
import '../../sound/sound_api.dart';
import '../tokens.dart';
import 'cosmos_backdrop.dart';
import 'madar_button.dart';

/// Standard page frame for every non-home screen: living [CosmosBackdrop],
/// a transparent app bar (Reem Kufi title, glass back button that mirrors
/// in RTL and plays [Sfx.back]), SafeArea'd body inside a shared
/// [BackdropGroup] (so all GlassPanels share one blur capture), and an
/// optional floating action at the reading end. When content scrolls under
/// the bar ([extendBodyBehindAppBar]) the bar frosts into glass.
class MadarScaffold extends StatefulWidget {
  const MadarScaffold({
    super.key,
    this.title,
    this.titleWidget,
    required this.body,
    this.actions = const [],
    this.showBack,
    this.onBack,
    this.floatingAction,
    this.bottomBar,
    this.backdropIntensity = 1,
    this.backdropSeed = 0,
    this.animateBackdrop = true,
    this.extendBodyBehindAppBar = false,
    this.safeBottom = true,
    this.resizeToAvoidBottomInset = true,
  });

  final String? title;

  /// Replaces [title] (e.g. a search field).
  final Widget? titleWidget;
  final Widget body;
  final List<Widget> actions;

  /// Defaults to whether the route can be dismissed.
  final bool? showBack;

  /// Defaults to `Navigator.maybePop`.
  final VoidCallback? onBack;
  final Widget? floatingAction;
  final Widget? bottomBar;
  final double backdropIntensity;
  final double backdropSeed;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  /// Let scrolling content pass under the (scrimmed) app bar. The body is
  /// then NOT top-padded: scroll views pick the padding up from MediaQuery.
  final bool extendBodyBehindAppBar;
  final bool safeBottom;
  final bool resizeToAvoidBottomInset;

  @override
  State<MadarScaffold> createState() => _MadarScaffoldState();
}

class _MadarScaffoldState extends State<MadarScaffold> {
  bool _scrolled = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final scrolled = n.metrics.pixels > n.metrics.minScrollExtent + 2;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final route = ModalRoute.of(context);
    final back = widget.showBack ?? (route?.impliesAppBarDismissal ?? false);
    final extend = widget.extendBodyBehindAppBar;
    return Stack(
      fit: StackFit.expand,
      children: [
        CosmosBackdrop(intensity: widget.backdropIntensity, seed: widget.backdropSeed, animate: widget.animateBackdrop),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: extend,
          resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
          appBar: MadarAppBar(
            title: widget.title,
            titleWidget: widget.titleWidget,
            actions: widget.actions,
            showBack: back,
            onBack: widget.onBack,
            frosted: extend && _scrolled,
          ),
          floatingActionButton: widget.floatingAction,
          bottomNavigationBar: widget.bottomBar,
          body: NotificationListener<ScrollNotification>(
            onNotification: extend ? _onScroll : null,
            child: BackdropGroup(
              child: SafeArea(top: !extend, bottom: widget.safeBottom && widget.bottomBar == null, child: widget.body),
            ),
          ),
        ),
      ],
    );
  }
}

/// Transparent Madar app bar (used by [MadarScaffold]).
class MadarAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MadarAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions = const [],
    this.showBack = false,
    this.onBack,
    this.frosted = false,
  });

  static const double height = 60;

  final String? title;
  final Widget? titleWidget;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  /// Frost into glass (blur + tint + hairline) – set while content is
  /// scrolled underneath.
  final bool frosted;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final backLabel =
        Localizations.of<L10n>(context, L10n)?.actionBack ?? MaterialLocalizations.of(context).backButtonTooltip;
    final middle =
        titleWidget ??
        (title == null
            ? null
            : Semantics(
                header: true,
                child: Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineSmall!.copyWith(color: t.textPrimary),
                ),
              ));
    final toolbar = SafeArea(
      bottom: false,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m),
          child: NavigationToolbar(
            centerMiddle: true,
            middleSpacing: Space.m,
            // NavigationToolbar gives the leading slot the full bar height;
            // centre the button so it keeps its round size.
            leading: showBack
                ? Center(
                    widthFactor: 1,
                    child: MadarButton.icon(
                      icon: Icons.arrow_back_rounded,
                      semanticLabel: backLabel,
                      size: MadarButtonSize.small,
                      sfx: Sfx.back,
                      onPressed: onBack ?? () => Navigator.maybePop(context),
                    ),
                  )
                : null,
            middle: middle,
            trailing: actions.isEmpty
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: Space.s),
                        actions[i],
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
    final frost = Color.alphaBlend(t.glassFill, t.space0.withValues(alpha: t.isDark ? 0.5 : 0.55));
    return TweenAnimationBuilder<double>(
      tween: Tween(end: frosted ? 1 : 0),
      duration: context.motion(MadarMotion.medium),
      curve: MadarMotion.standard,
      child: toolbar,
      builder: (context, v, child) => Stack(
        children: [
          // Resting: a faint scrim keeps the status bar legible over nebulae.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      t.space0.withValues(alpha: 0.5 * (1 - v)),
                      t.space0.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Scrolled: the bar frosts into glass.
          if (v > 0.001)
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20 * v, sigmaY: 20 * v),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: frost.withValues(alpha: frost.a * 0.85 * v),
                      border: Border(
                        bottom: BorderSide(color: t.glassBorder.withValues(alpha: t.glassBorder.a * v), width: 0.8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          child!,
        ],
      ),
    );
  }
}
