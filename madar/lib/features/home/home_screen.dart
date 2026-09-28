import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/interaction/interaction.dart';
import '../../core/motion/motion_kit.dart';
import '../../core/routing/routes.dart';
import '../../core/sound/sound_api.dart';
import '../orbit/presentation/orbit_ui_providers.dart';
import '../orbit/presentation/planet/customize_sheet.dart';
import '../orbit/presentation/prayer/prayer_sheet.dart';
import '../orbit/presentation/scene/flight.dart';
import '../orbit/presentation/scene/orbit_scene.dart';
import 'home_providers.dart';
import 'widgets/task_panel.dart';

/// Home: the Astrolabe Orbit – the living sky, the eight (or the user's)
/// worlds and their data moons around the brass astrolabe – filling the
/// screen as one dominant, centred object, a slim header, and the glass
/// panel below it. At rest the panel only peeks (~28 % of the height): the
/// six prayer-window chips (real times, the next prayer's countdown), a
/// one-line Neglect Radar, the focused window's title and the quick-add
/// bar. Drag (or fling) its top edge to expand it over the scene with the
/// radar's cards and the window's tasks.
///
/// Tapping a world opens its planet page (`/planet/:key`): the scene flies
/// in underneath the transparent route while home's chrome steps aside, and
/// back flies out again.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  /// Height the undo toast keeps clear above the quick-add bar.
  static const double quickAddClearance = 78;

  /// Height of the header row under the status bar.
  static const double headerHeight = 64;

  /// Where the collapsed (peeking) panel's top edge sits at most (fraction
  /// of the height); taller text pushes it up so the peek never clips.
  static const double collapsedPanelTop = 0.72;

  /// Height of the peeking panel's content at text scale 1 (grabber, chips,
  /// one-line radar, window title, quick-add bar).
  static const double peekHeight = 250;

  /// The flight has carried the panel off screen (its blur and paint stop).
  static const double panelGoneAt = FlightTiming.panelGone + 0.01;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _expand = AnimationController.unbounded(vsync: this);
  late final CurvedAnimation _chrome;
  late final CurvedAnimation _panel;
  late final Animation<double> _progress;

  /// A planet page is open (or the flight has carried the panel off
  /// screen): the panel is not painted at all.
  final ValueNotifier<bool> _gone = ValueNotifier(false);

  /// The panel is (mostly) expanded: the radar shows its cards.
  final ValueNotifier<bool> _expanded = ValueNotifier(false);
  double _range = 1;

  @override
  void initState() {
    super.initState();
    UndoToast.bottomInset = HomeScreen.quickAddClearance;
    final flight = ref.read(orbitFlightProvider);
    _progress = flight.progress;
    _chrome = CurvedAnimation(parent: _progress, curve: const _Flight(FlightTiming.chromeOut));
    _panel = CurvedAnimation(parent: _progress, curve: const _Flight(FlightTiming.panelOut));
    _progress.addListener(_onProgress);
    _expand.addListener(_onExpand);
  }

  void _onProgress() => _gone.value = _progress.value >= HomeScreen.panelGoneAt;

  void _onExpand() => _expanded.value = _expand.value > 0.5;

  @override
  void dispose() {
    if (UndoToast.bottomInset == HomeScreen.quickAddClearance) UndoToast.bottomInset = 0;
    _progress.removeListener(_onProgress);
    _expand.removeListener(_onExpand);
    _chrome.dispose();
    _panel.dispose();
    _gone.dispose();
    _expanded.dispose();
    _expand.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _expand.value = (_expand.value - (d.primaryDelta ?? 0) / _range).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = -(d.primaryVelocity ?? 0) / _range;
    final target = velocity.abs() > 0.9 ? (velocity > 0 ? 1.0 : 0.0) : (_expand.value > 0.5 ? 1.0 : 0.0);
    _settle(target, velocity);
  }

  void _settle(double target, [double velocity = 0]) {
    Fx.fire(target > 0.5 ? Sfx.sheetOpen : Sfx.sheetClose);
    if (context.reducedMotion) {
      _expand.animateTo(target, duration: MadarMotion.reduced, curve: Curves.easeOut);
    } else {
      _expand.animateWith(SpringSimulation(MadarMotion.snappy, _expand.value, target, velocity));
    }
  }

  void _openPlanet(String key, {String? item}) => context.go(AppRoutes.planetOf(key, item: item));

  /// Opens the peeking panel all the way (a tap on its grabber).
  void _toggle() => _settle(_expand.value > 0.5 ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final padding = MediaQuery.paddingOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return Scaffold(
      backgroundColor: t.space0,
      // The orbit keeps its size under the keyboard; the panel lifts itself.
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, box) {
          final h = box.maxHeight;
          final top = padding.top;
          final headerBottom = top + HomeScreen.headerHeight * (0.7 + 0.3 * textScale);
          final peek = HomeScreen.peekHeight * (0.45 + 0.55 * textScale) + viewPadding.bottom;
          final collapsedTop = math.max(headerBottom + 220, math.min(h * HomeScreen.collapsedPanelTop, h - peek));
          final expandedTop = headerBottom + Space.xs;
          _range = (collapsedTop - expandedTop).clamp(1.0, double.infinity);
          return Stack(
            fit: StackFit.expand,
            children: [
              // The scene never depends on the keyboard: it is not rebuilt
              // (nor its painters recreated) while the keyboard animates.
              Positioned.fill(
                child: _Scene(
                  sceneInsets: EdgeInsets.only(top: headerBottom + Space.xs, bottom: h - collapsedTop + Space.s),
                  onOpenPlanet: _openPlanet,
                ),
              ),
              PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                height: headerBottom + Space.xl,
                child: FadeTransition(
                  opacity: ReverseAnimation(_chrome),
                  child: Stack(
                    children: [
                      // A soft scrim keeps the date legible over a world or a
                      // ring drifting up under the header – it never takes a
                      // touch meant for the scene.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  t.space0.withValues(alpha: t.isDark ? 0.42 : 0.5),
                                  t.space0.withValues(alpha: t.isDark ? 0.22 : 0.28),
                                  t.space0.withValues(alpha: 0),
                                ],
                                stops: const [0, 0.6, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.only(top: top, bottom: Space.xl),
                        child: const _HomeHeader(),
                      ),
                    ],
                  ),
                ),
              ),
              _PanelFrame(
                expand: _expand,
                collapsedTop: collapsedTop,
                expandedTop: expandedTop,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _gone,
                  builder: (context, gone, child) => Offstage(offstage: gone, child: child),
                  // The fly-in carries the panel straight down off the screen
                  // (ease-in, gone by 45 % of the flight) at full opacity: no
                  // frame shows a half-faded panel over an empty scene.
                  child: SlideTransition(
                    position: Tween(begin: Offset.zero, end: const Offset(0, 1.02)).animate(_panel),
                    child: EntranceChoreo(
                      id: 'home',
                      child: StaggerItem(
                        index: 1,
                        from: EntranceFrom.bottom,
                        distance: 36,
                        // A fading ancestor would hide the backdrop blur until the end.
                        fade: false,
                        child: BackdropGroup(
                          child: Consumer(
                            // Only the glass tint follows the sky (once a minute); the
                            // panel content is passed through untouched.
                            builder: (context, ref, child) => GlassPanel(
                              padding: EdgeInsetsDirectional.zero,
                              borderRadius: BorderRadiusDirectional.vertical(top: Radius.circular(t.radiusXL)),
                              tint: _panelTint(t, ref.watch(homeSkyDaylightProvider)),
                              seed: 0.61,
                              // A still sheen: a drifting one would redraw the
                              // panel (and its backdrop blur) every vsync while
                              // the scene idles at 30 fps.
                              animateSheen: false,
                              child: child!,
                            ),
                            child: SafeArea(
                              top: false,
                              child: TaskPanel(
                                onOpenPlanet: _openPlanet,
                                expanded: _expanded,
                                expansion: _expand,
                                onToggle: _toggle,
                                dragArea: (child) => GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onVerticalDragUpdate: _onDragUpdate,
                                  onVerticalDragEnd: _onDragEnd,
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The orbit scene of home, kept free of the keyboard inset and of the
/// panel's drag (neither rebuilds it).
class _Scene extends ConsumerWidget {
  const _Scene({required this.sceneInsets, required this.onOpenPlanet});

  final EdgeInsets sceneInsets;
  final void Function(String key, {String? item}) onOpenPlanet;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OrbitScene(
    sceneInsets: sceneInsets,
    onPlanetTap: (key, _) => onOpenPlanet(key),
    onMoonTap: (moon, key, _) => onOpenPlanet(key, item: moon.id),
    onPlanetLongPress: (key, _) => showPlanetCustomizeSheet(context, ref, key),
    onPrayerTap: (prayer) => showPrayerSheet(context, ref, prayer),
  );
}

/// Positions the glass panel between its peeking and expanded tops (and
/// lifts it over the keyboard) – the only part of home that follows the
/// keyboard inset.
class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.expand, required this.collapsedTop, required this.expandedTop, required this.child});

  final Animation<double> expand;
  final double collapsedTop, expandedTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedBuilder(
      animation: expand,
      builder: (context, child) => PositionedDirectional(
        start: 0,
        end: 0,
        bottom: keyboardInset,
        top: keyboardInset > 0 ? expandedTop : lerpDouble(collapsedTop, expandedTop, expand.value.clamp(0.0, 1.0)),
        child: child!,
      ),
      child: child,
    );
  }
}

/// A fly-in choreography curve from [FlightTiming].
class _Flight extends Curve {
  const _Flight(this.f);

  final double Function(double) f;

  @override
  double transformInternal(double t) => f(t);
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final now = ref.watch(homeNowProvider);
    final fmt = MadarFormatter.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.l, 0),
      child: Row(
        children: [
          const IslamicStar(size: 18, glow: true),
          const SizedBox(width: Space.s + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l.appName,
                    maxLines: 1,
                    style: text.headlineSmall!.copyWith(
                      color: t.gold,
                      height: 1.15,
                      shadows: [Shadow(color: t.space0.withValues(alpha: 0.8), blurRadius: 12)],
                    ),
                  ),
                ),
                Text(
                  fmt.formatDate(now, style: MadarDateStyle.weekdayDayMonth),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(
                    color: t.textSecondary,
                    height: 1.3,
                    shadows: [Shadow(color: t.space0.withValues(alpha: 0.9), blurRadius: 8)],
                  ),
                ),
              ],
            ),
          ),
          MadarButton.icon(
            icon: Icons.tune_rounded,
            semanticLabel: l.homeOpenSettings,
            size: MadarButtonSize.small,
            sfx: Sfx.navigate,
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
    );
  }
}

/// Glass tint for the home panel: the theme's glass at night, deepening toward
/// an opaque night-sky tone as the real sky brightens so light text stays
/// legible over a day or Maghrib sky. Light themes keep their own glass.
Color? _panelTint(MadarTokens t, double daylight) {
  if (!t.isDark || daylight <= 0.01) return null;
  final deep = t.space1.withValues(alpha: 0.78);
  return Color.lerp(t.glassFill, deep, daylight.clamp(0.0, 1.0));
}
