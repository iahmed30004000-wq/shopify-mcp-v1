import 'package:flutter/material.dart';

import '../../i18n/gen/app_localizations.dart';
import '../../sound/sound_api.dart';
import '../tokens.dart';
import 'cosmos_backdrop.dart';
import 'madar_button.dart';

/// Standard page frame for every non-home screen: living [CosmosBackdrop],
/// a transparent app bar (Reem Kufi title, glass back button that mirrors
/// in RTL and plays [Sfx.back]), SafeArea'd body inside a shared
/// [BackdropGroup] (so all GlassPanels share one blur capture), and an
/// optional floating action at the reading end.
class MadarScaffold extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final back = showBack ?? (route?.impliesAppBarDismissal ?? false);
    return Stack(
      fit: StackFit.expand,
      children: [
        CosmosBackdrop(intensity: backdropIntensity, seed: backdropSeed, animate: animateBackdrop),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: extendBodyBehindAppBar,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          appBar: MadarAppBar(
            title: title,
            titleWidget: titleWidget,
            actions: actions,
            showBack: back,
            onBack: onBack,
            scrim: extendBodyBehindAppBar,
          ),
          floatingActionButton: floatingAction,
          bottomNavigationBar: bottomBar,
          body: BackdropGroup(
            child: SafeArea(top: !extendBodyBehindAppBar, bottom: safeBottom && bottomBar == null, child: body),
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
    this.scrim = false,
  });

  static const double height = 60;

  final String? title;
  final Widget? titleWidget;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  /// Paint a soft top scrim so content scrolling underneath stays calm.
  final bool scrim;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final backLabel = Localizations.of<L10n>(context, L10n)?.actionBack ?? MaterialLocalizations.of(context).backButtonTooltip;
    final middle = titleWidget ??
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: scrim
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [t.space0.withValues(alpha: 0.88), t.space0.withValues(alpha: 0.55), t.space0.withValues(alpha: 0)],
                stops: const [0, 0.6, 1],
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m),
            child: NavigationToolbar(
              centerMiddle: true,
              middleSpacing: Space.m,
              leading: showBack
                  ? MadarButton.icon(
                      icon: Icons.arrow_back_rounded,
                      semanticLabel: backLabel,
                      size: MadarButtonSize.small,
                      sfx: Sfx.back,
                      onPressed: onBack ?? () => Navigator.maybePop(context),
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
      ),
    );
  }
}
