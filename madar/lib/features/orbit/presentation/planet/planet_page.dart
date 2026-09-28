import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/themes.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/orbit_providers.dart';
import '../../domain/neglect_text.dart';
import '../../domain/orbit_labels.dart';
import '../../domain/orbit_moons.dart';
import '../../domain/planet_scores.dart';
import '../../domain/scene_snapshot.dart';
import '../orbit_ui_providers.dart';
import '../scene/flight.dart';
import '../scene/orbit_flight.dart';
import '../scene/scene_composition.dart';
import '../scene/scene_controller.dart';
import 'customize_sheet.dart';
import 'moon_sheet.dart';
import 'planet_modules.dart';
import 'record_open.dart';
import 'world_modules.dart';

/// A world's page, rising from its surface after the fly-in: the world
/// itself stays behind the header as a giant, slowly turning hero (it is the
/// orbit scene underneath this transparent route), and a glass sheet slides
/// up with its balance ring, what needs care, its moons (tappable – each is
/// a real record) and what feeds its score.
class PlanetModulePage extends ConsumerStatefulWidget {
  const PlanetModulePage({super.key, required this.planetKey, this.item});

  final String planetKey;

  /// Moon / record to highlight (`refTable:refId`).
  final String? item;

  /// Where the sheet's top edge sits (fraction of the height; the fly-in
  /// lands the world just under it).
  static const double sheetTop = OrbitComposition.heroSheetTop;

  @override
  ConsumerState<PlanetModulePage> createState() => _PlanetModulePageState();
}

class _PlanetModulePageState extends ConsumerState<PlanetModulePage> {
  late final OrbitFlight _flight = ref.read(orbitFlightProvider);
  Animation<double>? _route;
  CurvedAnimation? _header;
  CurvedAnimation? _sheet;
  final Map<String, GlobalKey> _moonKeys = {};

  @override
  void initState() {
    super.initState();
    _flight.addListener(_onFlight);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_route != null) return;
    final route = ModalRoute.of(context)?.animation;
    if (route == null) return;
    _route = route;
    _header = CurvedAnimation(parent: route, curve: const _Curve(FlightTiming.header));
    _sheet = CurvedAnimation(parent: route, curve: const _Curve(FlightTiming.sheet));
    // Attach after this frame: home's chrome listens to the flight.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _flight.attach(widget.planetKey, route, item: widget.item);
      final item = widget.item;
      if (item != null) {
        _reveal(item);
        // A moon tapped in the orbit opens its record once the world has
        // landed.
        if (route.status == AnimationStatus.completed) {
          _openItem(item);
        } else {
          void landed(AnimationStatus s) {
            if (s != AnimationStatus.completed) return;
            route.removeStatusListener(landed);
            _openItem(item);
          }

          route.addStatusListener(landed);
        }
      }
    });
  }

  bool _openedItem = false;

  void _openItem(String id) {
    if (!mounted || _openedItem) return;
    // A moon's sheet, or the record's own editor (a task); a record with no
    // sheet of its own is listed among the reasons on this page.
    final moons = ref.read(sceneSnapshotProvider).value?.planet(widget.planetKey)?.moons ?? const <OrbitMoon>[];
    _openedItem = true;
    unawaited(RecordOpener.open(context, ref, id, moons));
  }

  /// A record that is not a moon (a task): its own editor.
  void _openRecord(String item) {
    final moons = ref.read(sceneSnapshotProvider).value?.planet(widget.planetKey)?.moons ?? const <OrbitMoon>[];
    unawaited(RecordOpener.open(context, ref, item, moons));
  }

  /// A moon (its row, or the moon itself on the hero world): highlight it
  /// and open its record.
  void _openMoon(OrbitMoon moon) {
    _select(moon.id);
    unawaited(showMoonSheet(context, ref, moon));
  }

  @override
  void dispose() {
    _header?.dispose();
    _sheet?.dispose();
    _flight.removeListener(_onFlight);
    final route = _route;
    if (route != null) scheduleMicrotask(() => _flight.detach(route));
    super.dispose();
  }

  void _onFlight() {
    if (mounted) setState(() {});
  }

  void _back() {
    Fx.fire(Sfx.back);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _select(String? id) {
    _flight.select(id);
    if (id != null) _reveal(id);
  }

  void _reveal(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _moonKeys[id]?.currentContext;
      if (ctx == null || !ctx.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.3,
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.standard,
        ),
      );
    });
  }

  /// A tap on the hero world: its moons are tappable up there too.
  void _onHeroTap(TapUpDetails d) {
    final SceneController? scene = _flight.scene;
    final hit = scene?.hitTest(_flight.toScene(d.globalPosition));
    if (hit == null || hit.kind != SceneHitKind.moon || hit.planetKey != widget.planetKey) return;
    Fx.fire(Sfx.tap);
    _openMoon(hit.moon!);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final snapshot = ref.watch(sceneSnapshotProvider).value;
    final planet = snapshot?.planet(widget.planetKey);
    final Animation<double> header = _header ?? kAlwaysCompleteAnimation;
    final Animation<double> sheet = _sheet ?? kAlwaysCompleteAnimation;
    final glow = planet?.palette.glow ?? t.accentGlow;
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight;
        final sheetTop = h * PlanetModulePage.sheetTop;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.translucent, onTapUp: _onHeroTap),
            ),
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: FadeTransition(
                opacity: header,
                child: Stack(
                  children: [
                    // A soft scrim keeps the header legible over the hero
                    // world, its moons and a bright day sky – it never takes
                    // a tap meant for a moon up there.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                t.space0.withValues(alpha: t.isDark ? 0.55 : 0.6),
                                t.space0.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: Space.xl),
                      child: SafeArea(
                        bottom: false,
                        child: _Header(planet: planet, onBack: _back, planetKey: widget.planetKey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // The world's atmosphere catching the sheet's edge: the page
            // rises out of the planet's surface. Both edges are feathered
            // with smoothstep ramps (a linear ramp's corner reads as a seam
            // across the world).
            PositionedDirectional(
              top: sheetTop - _Glow.above,
              start: 0,
              end: 0,
              height: _Glow.above + _Glow.below,
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: sheet,
                  child: _Glow(color: glow.withValues(alpha: t.isDark ? 0.3 : 0.22)),
                ),
              ),
            ),
            PositionedDirectional(
              top: sheetTop,
              start: 0,
              end: 0,
              bottom: 0,
              // The sheet rises from below the screen (no fade: it takes over
              // from home's panel, which the flight carried down).
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 1.0), end: Offset.zero).animate(sheet),
                child: RepaintBoundary(
                  child: BackdropGroup(
                    child: GlassPanel(
                      padding: EdgeInsetsDirectional.zero,
                      borderRadius: BorderRadiusDirectional.vertical(top: Radius.circular(t.radiusXL)),
                      glowColor: planet?.palette.glow.withValues(alpha: 0.28),
                      // The world's own deep colour over deep navy (never a
                      // muddy slate): the sheet belongs to the planet and its
                      // text keeps ≥ 4.5 : 1 over a bright hero and day sky.
                      tint: _sheetTint(t, planet?.palette),
                      seed: 0.33,
                      // A still sheen: the page otherwise redraws its blur
                      // every vsync for as long as it stays open.
                      animateSheen: false,
                      child: snapshot == null
                          ? const Center(child: OrbitLoader())
                          : planet == null
                          ? _Missing(onBack: _back, label: l.orbitUiPlanetMissing, action: l.orbitUiBackToOrbit)
                          : _SheetShade(
                              child: _Sheet(
                                planet: planet,
                                snapshot: snapshot,
                                selected: _flight.key == widget.planetKey ? _flight.item : widget.item,
                                moonKeys: _moonKeys,
                                onSelect: _select,
                                onOpenMoon: _openMoon,
                                onOpenRecord: _openRecord,
                                delay: FlightTiming.duration * 0.55,
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
    );
  }
}

/// The world's atmosphere glowing along the sheet's top edge: a band
/// peaking at the edge, feathered both ways with smoothstep ramps.
class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  /// Reach of the glow above and below the sheet's top edge (px).
  static const double above = 64, below = 36;

  static const int _steps = 8;

  @override
  Widget build(BuildContext context) {
    const total = above + below;
    const peak = above / total;
    final colors = <Color>[];
    final stops = <double>[];
    double smooth(double x) => x * x * (3 - 2 * x);
    for (var i = 0; i <= _steps; i++) {
      final x = i / _steps;
      colors.add(color.withValues(alpha: color.a * smooth(x)));
      stops.add(peak * x);
    }
    for (var i = 1; i <= _steps; i++) {
      final x = i / _steps;
      colors.add(color.withValues(alpha: color.a * smooth(1 - x)));
      stops.add(peak + (1 - peak) * x);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: stops),
      ),
    );
  }
}

/// The planet page's glass: the world's deep colour over the theme's navy
/// (dark themes), a pearl wash touched by the world's colour (Pearl).
Color _sheetTint(MadarTokens t, PlanetPalette? palette) {
  if (!t.isDark) {
    final base = t.space1.withValues(alpha: 0.8);
    return palette == null ? base : Color.alphaBlend(palette.surface.withValues(alpha: 0.1), base);
  }
  final navy = Color.alphaBlend(t.space0.withValues(alpha: 0.55), t.space1).withValues(alpha: 0.8);
  return palette == null ? navy : Color.alphaBlend(palette.deep.withValues(alpha: 0.42), navy);
}

/// Deepens the sheet toward its bottom edge: the blurred worlds far below
/// the hero never smudge through the glass there.
class _SheetShade extends StatelessWidget {
  const _SheetShade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    t.space1.withValues(alpha: 0),
                    t.space1.withValues(alpha: t.isDark ? 0.55 : 0.45),
                  ],
                  stops: const [0.45, 1],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _Curve extends Curve {
  const _Curve(this.f);

  final double Function(double) f;

  @override
  double transformInternal(double t) => f(t);
}

class _Header extends ConsumerWidget {
  const _Header({required this.planet, required this.onBack, required this.planetKey});

  final OrbitPlanet? planet;
  final VoidCallback onBack;
  final String planetKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final p = planet;
    final shadow = [Shadow(color: t.space0.withValues(alpha: 0.85), blurRadius: 14)];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.s, Space.l, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MadarButton.icon(
            // Mirrors itself in right-to-left layouts.
            icon: Icons.arrow_back_rounded,
            semanticLabel: l.orbitUiBackToOrbit,
            size: MadarButtonSize.small,
            sfx: Sfx.back,
            onPressed: onBack,
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: p == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.headlineMedium!.copyWith(
                            color: t.textPrimary,
                            height: 1.15,
                            shadows: [
                              ...shadow,
                              Shadow(color: p.palette.glow.withValues(alpha: 0.5), blurRadius: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.score.dormant
                            ? planetStateLabel(l, p.state)
                            : l.orbitUiListSeparator(planetStateLabel(l, p.state), fmt.formatPercent(p.uScore)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium!.copyWith(color: t.textPrimary.withValues(alpha: 0.86), shadows: shadow),
                      ),
                    ],
                  ),
          ),
          if (p != null)
            MadarButton.icon(
              icon: Icons.tune_rounded,
              semanticLabel: l.orbitUiCustomize,
              size: MadarButtonSize.small,
              sfx: Sfx.sheetOpen,
              onPressed: () => showPlanetCustomizeSheet(context, ref, planetKey),
            ),
        ],
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.onBack, required this.label, required this.action});

  final VoidCallback onBack;
  final String label;
  final String action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IslamicStar(size: 32, glow: true),
            const SizedBox(height: Space.l),
            Text(label, textAlign: TextAlign.center, style: text.titleMedium),
            const SizedBox(height: Space.l),
            MadarButton(label: action, onPressed: onBack, variant: MadarButtonVariant.secondary, sfx: Sfx.back),
          ],
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.planet,
    required this.snapshot,
    required this.selected,
    required this.moonKeys,
    required this.onSelect,
    required this.onOpenMoon,
    required this.onOpenRecord,
    required this.delay,
  });

  final OrbitPlanet planet;
  final SceneSnapshot snapshot;
  final String? selected;
  final Map<String, GlobalKey> moonKeys;
  final ValueChanged<String?> onSelect;
  final ValueChanged<OrbitMoon> onOpenMoon;

  /// Opens a record that is not a moon (a task's editor).
  final ValueChanged<String> onOpenRecord;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final score = planet.score;
    final reasons = score.reasons.take(5).toList();
    final moons = planet.moons;
    final sources = planet.sourceRows(l);

    Widget section(String title) => SectionHeader(
      title: title,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, Space.s),
    );

    return EntranceChoreo(
      id: 'planet:${planet.key}',
      delay: context.motion(delay),
      child: ListView(
        padding: EdgeInsetsDirectional.only(top: Space.l, bottom: MediaQuery.paddingOf(context).bottom + Space.xl),
        children: [
          StaggerItem(
            index: 0,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
              child: _ScoreRow(planet: planet),
            ),
          ),
          // The world's own module first: Faith's prayers of the day …
          if (planet.key == 'faith') ...[
            StaggerItem(index: 1, child: section(l.orbitUiTodayPrayersTitle)),
            StaggerItem(
              index: 1,
              child: FaithTodayModule(snapshot: snapshot, planet: planet),
            ),
          ],
          // … and every world's tasks of the day.
          StaggerItem(index: 1, child: section(l.orbitUiWorldTasksTitle)),
          StaggerItem(index: 1, child: WorldTasksModule(planetKey: planet.key)),
          StaggerItem(index: 1, child: section(l.orbitUiReasonsTitle)),
          if (score.dormant)
            StaggerItem(
              index: 2,
              child: _Note(text: l.orbitUiReasonsDormant, icon: Icons.nights_stay_outlined),
            )
          else if (reasons.isEmpty)
            StaggerItem(
              index: 2,
              child: _Note(text: l.orbitUiReasonsNone, icon: Icons.auto_awesome_rounded),
            )
          else
            for (var i = 0; i < reasons.length; i++)
              StaggerItem(
                index: 2 + i,
                child: _ReasonRow(
                  reason: reasons[i],
                  text: neglectReasonText(l, reasons[i], fmt),
                  // A button only when it opens something (a moon, a task).
                  onTap: !RecordOpener.canOpen(reasons[i].refTable, reasons[i].refId, moons)
                      ? null
                      : () {
                          final r = reasons[i];
                          final id = PlanetModules.itemOf(r.refTable!, r.refId!);
                          Fx.fire(Sfx.tap);
                          final moon = RecordOpener.moonOf(id, moons);
                          if (moon != null) {
                            onOpenMoon(moon);
                          } else {
                            onSelect(null);
                            onOpenRecord(id);
                          }
                        },
                ),
              ),
          StaggerItem(index: 7, child: section(l.orbitUiMoonsTitle)),
          if (moons.isEmpty)
            StaggerItem(
              index: 8,
              child: _Note(text: l.orbitUiMoonsNone, icon: Icons.brightness_3_outlined),
            )
          else ...[
            for (var i = 0; i < moons.length; i++)
              StaggerItem(
                index: 8 + i,
                child: _MoonRow(
                  key: moonKeys.putIfAbsent(moons[i].id, GlobalKey.new),
                  moon: moons[i],
                  planetName: planet.name,
                  selected: moons[i].id == selected,
                  onTap: () => onOpenMoon(moons[i]),
                ),
              ),
            if (planet.moonOverflow > 0)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, 0),
                child: Text(
                  moonOverflowText(l, fmt, planet.moonOverflow),
                  style: text.bodySmall!.copyWith(color: t.textTertiary),
                ),
              ),
          ],
          if (sources.isNotEmpty) ...[
            StaggerItem(index: 12, child: section(l.orbitUiSourcesTitle)),
            for (var i = 0; i < sources.length; i++)
              StaggerItem(
                index: 13 + i,
                child: _SourceRow(label: sources[i].label, value: sources[i].value, color: planet.palette.glow),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScoreRow extends ConsumerWidget {
  const _ScoreRow({required this.planet});

  final OrbitPlanet planet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final w = planet.weight;
    final dormant = planet.score.dormant;
    // Below half the ring warns (amber → red), whatever the world's colour.
    final low = !dormant && planet.uScore < 0.5;
    final ringColor = low
        ? Color.lerp(t.danger, t.warning, (planet.uScore / 0.5).clamp(0.0, 1.0))!
        : planet.palette.glow;
    return Row(
      children: [
        SpringBuilder(
          value: dormant ? 0 : planet.uScore,
          from: 0,
          builder: (context, v, _) => ProgressRing(
            value: v,
            size: 76,
            strokeWidth: 6,
            color: ringColor,
            gradientEnd: low ? t.warning : planet.palette.surface,
            semanticLabel: l.orbitUiBalanceLabel,
            semanticValue: dormant ? planetStateLabel(l, planet.state) : fmt.formatPercent(planet.uScore),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dormant ? '—' : fmt.formatPercent(v.clamp(0.0, 1.0)),
                  style: text.titleMedium!.copyWith(color: t.textPrimary, height: 1.1),
                ),
                Text(l.orbitUiBalanceLabel, style: text.labelSmall!.copyWith(color: t.textSecondary, height: 1.1)),
              ],
            ),
          ),
        ),
        const SizedBox(width: Space.l),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                planetStateLabel(l, planet.state),
                style: text.titleMedium!.copyWith(color: _stateColor(t, planet.state), height: 1.2),
              ),
              const SizedBox(height: 2),
              Text(
                w <= 0 ? l.orbitUiPlanetNotCounted : l.orbitUiPlanetWeight(fmt.formatNumber(w, maxDecimals: 1)),
                style: text.bodySmall!.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Color _stateColor(MadarTokens t, PlanetState s) => switch (s) {
    PlanetState.thriving => t.success,
    PlanetState.steady => t.textPrimary,
    PlanetState.neglected => t.warning,
    PlanetState.dormant => t.textSecondary,
  };
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.textSecondary);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
      child: Row(
        children: [
          Icon(icon, size: 18, color: t.accent),
          const SizedBox(width: Space.s),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.reason, required this.text, required this.onTap});

  final NeglectReason reason;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.textPrimary, height: 1.35);
    final color = reason.severity >= 0.6 ? t.danger : (reason.severity >= 0.3 ? t.warning : t.info);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, 0, Space.l, Space.s),
      child: GlassCard(
        glow: false,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
        onTap: onTap,
        semanticLabel: text,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(child: Text(text, style: style)),
          ],
        ),
      ),
    );
  }
}

class _MoonRow extends StatelessWidget {
  const _MoonRow({
    super.key,
    required this.moon,
    required this.planetName,
    required this.selected,
    required this.onTap,
  });

  final OrbitMoon moon;
  final String planetName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final palette = PlanetPalettes.fromColor(moon.color);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, 0, Space.l, Space.s),
      child: AnimatedContainer(
        duration: context.motion(MadarMotion.short),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM + 1),
          border: Border.all(color: selected ? t.accent : t.accent.withValues(alpha: 0), width: 1.2),
          boxShadow: selected ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 16)] : null,
        ),
        child: GlassCard(
          glow: false,
          padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
          onTap: onTap,
          semanticLabel: moonSemanticsLabel(l, fmt, moon, planetName),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.4),
                    colors: [palette.glow, palette.surface, palette.deep],
                    stops: const [0, 0.55, 1],
                  ),
                  boxShadow: [BoxShadow(color: palette.surface.withValues(alpha: 0.4), blurRadius: 10)],
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      moon.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall!.copyWith(color: t.textPrimary, height: 1.3),
                    ),
                    Text(
                      selected
                          ? l.orbitUiListSeparator(PlanetModules.moonKindLabel(l, moon), l.orbitUiMoonSelected)
                          : PlanetModules.moonKindLabel(l, moon),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(color: selected ? t.accent : t.textTertiary, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.s),
              _Meter(
                value: moon.score,
                color: palette.glow,
                // Untouched: a word, not a lone "0 %" over an empty bar.
                text: moon.score < _Meter.waiting ? l.orbitUiMoonWaiting : fmt.formatPercent(moon.score),
                label: l.orbitUiMoonFreshness(fmt.formatPercent(moon.score)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.xs),
      child: Semantics(
        label: L10n.of(context).orbitUiSourceSemantics(fmt.isolate(label), fmt.formatPercent(value)),
        excludeSemantics: true,
        child: Row(
          children: [
            SizedBox(
              width: 116,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(color: t.textSecondary),
              ),
            ),
            Expanded(
              child: _Bar(value: value, color: color),
            ),
            const SizedBox(width: Space.s),
            SizedBox(
              width: 40,
              child: Text(
                fmt.formatPercent(value),
                textAlign: TextAlign.end,
                style: text.labelSmall!.copyWith(color: t.textSecondary, fontFamily: MadarTypography.uiFamily),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A moon's freshness: its percentage over a thin bar (read out in full);
/// below [waiting] a warm word and a small ember instead of "0 %".
class _Meter extends StatelessWidget {
  const _Meter({required this.value, required this.color, required this.text, required this.label});

  /// Below this the moon is "waiting on you".
  static const double waiting = 0.05;

  final double value;
  final Color color;
  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context).textTheme;
    final low = value < waiting;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: 72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.labelSmall!.copyWith(color: low ? t.warning : t.textSecondary),
            ),
            const SizedBox(height: 4),
            _Bar(value: low ? 0.08 : value, color: low ? t.warning : color),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = value.clamp(0.0, 1.0);
    return SizedBox(
      height: 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.textTertiary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(3),
        ),
        child: FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: v,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.55), color]),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}
