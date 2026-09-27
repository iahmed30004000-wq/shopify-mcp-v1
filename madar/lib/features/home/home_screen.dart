import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/interaction/interaction.dart';
import '../../core/motion/motion_kit.dart';
import '../../core/routing/routes.dart';
import '../../core/settings/app_settings.dart';
import '../../core/sound/sound_api.dart';
import 'domain/prayer_day.dart';
import 'home_providers.dart';
import 'widgets/astrolabe_dial.dart';
import 'widgets/neglect_radar_card.dart';
import 'widgets/task_panel.dart';
import 'widgets/window_chips.dart';

/// Phase 0 home: the cosmos, a 2D astrolabe of today's prayer windows in
/// the upper half (Phase 1 replaces it with the living 3D orbit), a Neglect
/// Radar placeholder and the bottom glass panel with the focused window's
/// tasks and the quick-add bar. Drag the panel's top edge to expand it.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  /// Height the undo toast keeps clear above the quick-add bar.
  static const double quickAddClearance = 78;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  static const double _headerHeight = 64;
  static const double _minPanel = 300;

  late final AnimationController _expand = AnimationController.unbounded(vsync: this);
  double _range = 1;

  @override
  void initState() {
    super.initState();
    UndoToast.bottomInset = HomeScreen.quickAddClearance;
  }

  @override
  void dispose() {
    if (UndoToast.bottomInset == HomeScreen.quickAddClearance) UndoToast.bottomInset = 0;
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final batterySaver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    return Stack(
      fit: StackFit.expand,
      children: [
        CosmosBackdrop(animate: !batterySaver, seed: 0.37, intensity: 1.1),
        Scaffold(
          backgroundColor: t.space0.withValues(alpha: 0),
          body: SafeArea(
            bottom: false,
            child: BackdropGroup(
              child: LayoutBuilder(
                builder: (context, box) {
                  final h = box.maxHeight;
                  final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
                  final showRadar = h > 640 && !keyboard;
                  final radarH = showRadar ? 78.0 : 0.0;
                  final panelH = (h * 0.53).clamp(_minPanel, h - _headerHeight);
                  final dialH = (h - panelH - _headerHeight - radarH).clamp(0.0, 360.0);
                  final collapsedTop = h - panelH;
                  final expandedTop = _headerHeight + Space.xs;
                  _range = (collapsedTop - expandedTop).clamp(1.0, double.infinity);
                  final dialSize = (dialH - Space.s).clamp(0.0, box.maxWidth - Space.xxl * 2).clamp(0.0, 330.0);

                  return EntranceChoreo(
                    id: 'home',
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedBuilder(
                          animation: _expand,
                          builder: (context, child) {
                            final v = _expand.value.clamp(0.0, 1.0);
                            return PositionedDirectional(
                              top: 0,
                              start: 0,
                              end: 0,
                              child: Opacity(
                                opacity: (1 - v * 0.85).clamp(0.0, 1.0),
                                child: Transform.scale(scale: 1 - 0.06 * v, child: child),
                              ),
                            );
                          },
                          child: StaggerIn(
                            children: [
                              const SizedBox(height: _headerHeight, child: _HomeHeader()),
                              SizedBox(
                                height: dialH,
                                child: dialSize < 120
                                    ? const SizedBox.shrink()
                                    : Center(
                                        child: _Dial(size: dialSize, animate: !batterySaver),
                                      ),
                              ),
                              if (showRadar)
                                const Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.s),
                                  child: NeglectRadarCard(),
                                ),
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _expand,
                          builder: (context, child) => PositionedDirectional(
                            start: 0,
                            end: 0,
                            bottom: 0,
                            top: lerpDouble(collapsedTop, expandedTop, _expand.value.clamp(0.0, 1.0)),
                            child: child!,
                          ),
                          child: StaggerItem(
                            index: 3,
                            from: EntranceFrom.bottom,
                            distance: 36,
                            child: GlassPanel(
                              padding: EdgeInsetsDirectional.zero,
                              borderRadius: BorderRadiusDirectional.vertical(top: Radius.circular(t.radiusXL)),
                              seed: 0.61,
                              child: SafeArea(
                                top: false,
                                child: TaskPanel(
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
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
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
                  child: Text(l.appName, style: text.headlineSmall!.copyWith(color: t.gold, height: 1.15)),
                ),
                Text(
                  fmt.formatDate(now, style: MadarDateStyle.weekdayDayMonth),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.3),
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

class _Dial extends ConsumerWidget {
  const _Dial({required this.size, required this.animate});

  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final times = ref.watch(prayerDayProvider);
    final now = ref.watch(homeNowProvider);
    final focused = ref.watch(homeFocusedWindowProvider);
    final current = ref.watch(homeCurrentWindowProvider);
    final next = times.nextPrayer(now);
    final countdown = l.homeNextPrayer(
      prayerLabel(l, next.prayer),
      fmt.formatDurationWords(l, next.at.difference(now)),
    );
    final marks = [
      for (final p in PrayerDayTimes.obligatory) DialMark(at: times.timeOf(p), label: prayerLabel(l, p)),
      DialMark(at: times.sunrise, label: l.prayerSunrise, isPrayer: false),
    ];
    return Semantics(
      container: true,
      label: l.homeDialSemantics(windowLabel(l, current), countdown),
      child: ExcludeSemantics(
        child: AstrolabeDial(
          size: size,
          times: times,
          now: now,
          focused: focused,
          animate: animate,
          marks: marks,
          center: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.homeNow, style: text.labelSmall!.copyWith(color: t.accent, letterSpacing: 0.6)),
                const SizedBox(height: 2),
                Text(
                  windowLabel(l, current),
                  textAlign: TextAlign.center,
                  style: text.headlineSmall!.copyWith(
                    color: t.textPrimary,
                    height: 1.2,
                    fontFamilyFallback: const [MadarTypography.uiFamily],
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  countdown,
                  textAlign: TextAlign.center,
                  style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.3),
                ),
                if (times.isPlaceholder) ...[
                  const SizedBox(height: Space.s),
                  _PlaceholderBadge(label: l.homePlaceholderBadge, note: l.homePlaceholderNote),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks the placeholder prayer times; tap for the explanation.
class _PlaceholderBadge extends StatelessWidget {
  const _PlaceholderBadge({required this.label, required this.note});

  final String label;
  final String note;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Tooltip(
      message: note,
      triggerMode: TooltipTriggerMode.tap,
      onTriggered: () => Fx.fire(Sfx.tap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.space1.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: t.warning.withValues(alpha: 0.5), width: 0.8),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.s, 2, Space.s + 2, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, size: 12, color: t.warning),
              const SizedBox(width: Space.xs),
              Text(label, style: text.labelSmall!.copyWith(color: t.warning, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}
