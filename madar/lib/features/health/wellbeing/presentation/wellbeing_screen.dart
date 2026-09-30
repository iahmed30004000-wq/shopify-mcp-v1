import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/wellbeing_providers.dart';
import 'breathing_screen.dart';
import 'sheets/mood_check_in_sheet.dart';
import 'sheets/pain_log_sheet.dart';
import 'sheets/worry_sheets.dart';
import 'tabs/habits_tab.dart';
import 'tabs/insights_tab.dart';
import 'tabs/pain_tab.dart';
import 'tabs/today_tab.dart';
import 'tabs/worries_tab.dart';
import 'wellbeing_actions.dart';

enum WellbeingTab { today, pain, habits, worries, insights }

/// Wellbeing: today's check-in, pain, stress-reduction habits, the worry
/// window and local insights. Tracking and visualising only – no advice.
class WellbeingScreen extends ConsumerStatefulWidget {
  const WellbeingScreen({super.key, this.initialTab = WellbeingTab.today, this.animateBackdrop = true, this.onBreathe});

  final WellbeingTab initialTab;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  /// Opens guided breathing (defaults to pushing [BreathingScreen]).
  final VoidCallback? onBreathe;

  @override
  ConsumerState<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends ConsumerState<WellbeingScreen> {
  late WellbeingTab _tab = widget.initialTab;

  void _breathe() {
    if (widget.onBreathe != null) return widget.onBreathe!();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BreathingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    // Keep the worry-window notifications in step with what the screen changes.
    ref.watch(worryReminderSyncProvider);
    final fab = switch (_tab) {
      WellbeingTab.today => (Icons.add_reaction_outlined, l.wbCheckInTitle, () => showMoodCheckInSheet(context)),
      WellbeingTab.pain => (Icons.add_rounded, l.wbPainLogTitle, () => showPainLogSheet(context)),
      WellbeingTab.habits => (Icons.add_task_rounded, l.wbHabitAddTitle, () => WellbeingActions.addHabit(context, ref)),
      WellbeingTab.worries || WellbeingTab.insights => null,
    };
    return MadarScaffold(
      title: l.wbTitle,
      backdropSeed: 4.4,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        MadarButton.icon(
          icon: Icons.air_rounded,
          semanticLabel: l.wbBreathTitle,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.navigate,
          onPressed: _breathe,
        ),
        MadarButton.icon(
          icon: Icons.tune_rounded,
          semanticLabel: l.wbSettingsTitle,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => showWellbeingSettingsSheet(context),
        ),
      ],
      floatingAction: fab == null
          ? null
          : MadarButton.icon(
              icon: fab.$1,
              semanticLabel: fab.$2,
              variant: MadarButtonVariant.primary,
              size: MadarButtonSize.large,
              sfx: Sfx.sheetOpen,
              onPressed: fab.$3,
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
            child: WellbeingTabBar(
              value: _tab,
              labels: {
                WellbeingTab.today: l.wbTabToday,
                WellbeingTab.pain: l.wbTabPain,
                WellbeingTab.habits: l.wbTabHabits,
                WellbeingTab.worries: l.wbTabWorries,
                WellbeingTab.insights: l.wbTabInsights,
              },
              onChanged: (tab) => setState(() => _tab = tab),
            ),
          ),
          Expanded(
            child: EntranceChoreo(
              id: _tab,
              child: _FadeStack(
                index: _tab.index,
                children: [
                  TodayTab(key: const ValueKey('wb.today'), onBreathe: _breathe),
                  const PainTab(key: ValueKey('wb.pain')),
                  const HabitsTab(key: ValueKey('wb.habits')),
                  const WorriesTab(key: ValueKey('wb.worries')),
                  const InsightsTab(key: ValueKey('wb.insights')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glass segmented tabs whose thumb springs between them (follows the
/// reading direction).
class WellbeingTabBar extends StatelessWidget {
  const WellbeingTabBar({super.key, required this.value, required this.labels, required this.onChanged});

  final WellbeingTab value;
  final Map<WellbeingTab, String> labels;
  final ValueChanged<WellbeingTab> onChanged;

  static const Map<WellbeingTab, IconData> icons = {
    WellbeingTab.today: Icons.wb_twilight_rounded,
    WellbeingTab.pain: Icons.healing_rounded,
    WellbeingTab.habits: Icons.checklist_rounded,
    WellbeingTab.worries: Icons.inventory_2_outlined,
    WellbeingTab.insights: Icons.insights_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    const tabs = WellbeingTab.values;
    final dir = Directionality.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: 58,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusL),
          color: t.glassFill,
          border: Border.all(color: t.glassBorder),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth / tabs.length;
            return Stack(
              children: [
                SpringBuilder(
                  value: value.index.toDouble(),
                  spring: MadarMotion.snappy,
                  builder: (context, v, _) {
                    final x = dir == TextDirection.rtl ? constraints.maxWidth - w * (v + 1) : w * v;
                    return Positioned(
                      left: x,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(t.radiusL - 4),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [t.accent.withValues(alpha: 0.32), t.accent.withValues(alpha: 0.16)],
                          ),
                          border: Border.all(color: t.accent.withValues(alpha: 0.55)),
                          boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: 0.25), blurRadius: 12)],
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    for (final tab in tabs)
                      Expanded(
                        child: MadarPressable(
                          semanticLabel: labels[tab],
                          selected: tab == value,
                          sfx: Sfx.navigate,
                          excludeChildSemantics: true,
                          onTap: () {
                            if (tab != value) onChanged(tab);
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icons[tab], size: 18, color: tab == value ? t.textPrimary : t.textTertiary),
                              const SizedBox(height: 2),
                              AnimatedDefaultTextStyle(
                                duration: context.motion(MadarMotion.short),
                                style: (text.labelSmall ?? const TextStyle()).copyWith(
                                  color: tab == value ? t.textPrimary : t.textSecondary,
                                  fontWeight: tab == value ? FontWeight.w600 : FontWeight.w400,
                                ),
                                child: Text(labels[tab]!, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Builds a tab when first shown, keeps it alive afterwards and cross-fades
/// between them.
class _FadeStack extends StatefulWidget {
  const _FadeStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_FadeStack> createState() => _FadeStackState();
}

class _FadeStackState extends State<_FadeStack> {
  final Set<int> _built = {};

  @override
  Widget build(BuildContext context) {
    final d = context.motion(MadarMotion.short);
    final index = widget.index;
    final children = widget.children;
    _built.add(index);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          if (!_built.contains(i))
            const SizedBox.shrink()
          else
            IgnorePointer(
              ignoring: i != index,
              child: ExcludeSemantics(
                excluding: i != index,
                child: TickerMode(
                  enabled: i == index,
                  child: AnimatedOpacity(opacity: i == index ? 1 : 0, duration: d, child: children[i]),
                ),
              ),
            ),
      ],
    );
  }
}

/// Bottom padding every tab leaves for the floating button.
const double wbTabBottomPadding = 112;
