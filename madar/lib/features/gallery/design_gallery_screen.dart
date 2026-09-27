import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/design/themes.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/motion/motion.dart';
import 'gallery_sections.dart';

/// Visual showcase of every design-system component, used for visual critic
/// passes. It carries its own theme switcher (all five themes, animated
/// cross-fade), writing-direction toggle and a local reduced-motion switch,
/// so it never touches the user's real settings.
class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key, this.initialTheme = MadarThemeId.lapis, this.initialDirection});

  final MadarThemeId initialTheme;

  /// Defaults to the ambient direction (RTL for Arabic).
  final TextDirection? initialDirection;

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  late MadarThemeId _theme = widget.initialTheme;
  late TextDirection? _direction = widget.initialDirection;
  late GalleryDemoState _demo = const GalleryDemoState();
  Timer? _loadingTimer;

  void _update(GalleryDemoState next) => setState(() => _demo = next);

  void _startLoading() {
    _loadingTimer?.cancel();
    _update(_demo.copyWith(loading: true));
    _loadingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _update(_demo.copyWith(loading: false));
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final direction = _direction ?? Directionality.of(context);
    final reduced = _demo.reduceMotion || MotionScope.reducedOf(context);
    return AnimatedTheme(
      data: buildMadarTheme(_theme, arabic: arabic),
      duration: reduced ? MadarMotion.reduced : MadarMotion.long,
      curve: MadarMotion.standard,
      child: Directionality(
        textDirection: direction,
        child: MotionScope(
          reduced: reduced,
          child: Builder(
            builder: (context) {
              final l = L10n.of(context);
              return MadarScaffold(
                title: l.designGalleryTitle,
                extendBodyBehindAppBar: true,
                floatingAction: MadarButton.icon(
                  icon: Icons.add_rounded,
                  semanticLabel: l.actionAdd,
                  variant: MadarButtonVariant.primary,
                  size: MadarButtonSize.large,
                  onPressed: () {},
                ),
                body: GalleryBody(
                  theme: _theme,
                  direction: direction,
                  demo: _demo,
                  arabicDigits: arabic,
                  onTheme: (id) => setState(() => _theme = id),
                  onDirection: (d) => setState(() => _direction = d),
                  onDemo: _update,
                  onStartLoading: _startLoading,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Interactive demo values shown in the gallery (UI state only).
@immutable
class GalleryDemoState {
  const GalleryDemoState({
    this.window = 'fajr',
    this.planets = const {'faith', 'health', 'growth'},
    this.sound = true,
    this.haptics = true,
    this.reduceMotion = false,
    this.loading = false,
    this.ring = 0.72,
  });

  final String? window;
  final Set<String> planets;
  final bool sound;
  final bool haptics;
  final bool reduceMotion;
  final bool loading;
  final double ring;

  GalleryDemoState copyWith({
    String? window,
    Set<String>? planets,
    bool? sound,
    bool? haptics,
    bool? reduceMotion,
    bool? loading,
    double? ring,
  }) =>
      GalleryDemoState(
        window: window ?? this.window,
        planets: planets ?? this.planets,
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        loading: loading ?? this.loading,
        ring: ring ?? this.ring,
      );
}

/// Scroll padding shared by gallery sections.
const galleryGutter = EdgeInsetsDirectional.symmetric(horizontal: Space.gutter);
