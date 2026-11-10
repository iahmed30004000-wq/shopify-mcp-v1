import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/meds_providers.dart';
import 'courses_view.dart';
import 'med_list_view.dart';
import 'meds_actions.dart';
import 'today_view.dart';
import 'widgets/meds_widgets.dart';

enum MedsTab { today, meds, courses }

/// Medications & supplements: standing alerts pinned on top, then Today
/// (doses by prayer window with Taken / Snooze / Skip), My meds (the list
/// and the timing rules) and Courses.
class MedsScreen extends ConsumerStatefulWidget {
  const MedsScreen({super.key, this.initialTab = MedsTab.today, this.animateBackdrop = true});

  final MedsTab initialTab;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  ConsumerState<MedsScreen> createState() => _MedsScreenState();
}

class _MedsScreenState extends ConsumerState<MedsScreen> {
  late MedsTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final alerts = ref.watch(medsStandingAlertsProvider).value ?? const [];
    // Keep reminders in step with what the screen changes.
    ref.watch(medsReminderSyncProvider);
    final (IconData fabIcon, String fabLabel, VoidCallback onAdd) = switch (_tab) {
      MedsTab.courses => (Icons.add_rounded, l.medsAddCourse, () => MedsActions.addCourse(context, ref)),
      _ => (Icons.add_rounded, l.medsAddMed, () => MedsActions.addMed(context, ref)),
    };
    return MadarScaffold(
      title: l.medsTitle,
      backdropSeed: 7.1,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        MadarButton.icon(
          icon: Icons.tune_rounded,
          semanticLabel: l.medsSettingsOpen,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => MedsActions.openSettings(context, ref),
        ),
      ],
      floatingAction: MadarButton.icon(
        icon: fabIcon,
        semanticLabel: fabLabel,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
        onPressed: onAdd,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (alerts.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, 0),
              child: MedsStandingAlerts(alerts: alerts),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
            child: MedsTabBar(
              value: _tab,
              labels: {MedsTab.today: l.medsTabToday, MedsTab.meds: l.medsTabMeds, MedsTab.courses: l.medsTabCourses},
              onChanged: (tab) => setState(() => _tab = tab),
            ),
          ),
          Expanded(
            child: EntranceChoreo(
              id: _tab,
              child: _FadeStack(
                index: _tab.index,
                children: const [
                  _EdgeFade(child: MedsTodayView(key: ValueKey('meds.today'))),
                  _EdgeFade(child: MedsListView(key: ValueKey('meds.list'))),
                  _EdgeFade(child: MedCoursesView(key: ValueKey('meds.courses'))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A glass segmented control whose thumb springs between the tabs (follows
/// the reading direction).
class MedsTabBar extends StatelessWidget {
  const MedsTabBar({super.key, required this.value, required this.labels, required this.onChanged});

  final MedsTab value;
  final Map<MedsTab, String> labels;
  final ValueChanged<MedsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    const tabs = MedsTab.values;
    final dir = Directionality.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
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
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color.lerp(t.accent, t.starTint, 0.18)!, t.accent],
                          ),
                          boxShadow: t.isDark
                              ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 14)]
                              : null,
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
                          onTap: tab == value ? null : () => onChanged(tab),
                          sfx: Sfx.navigate,
                          selected: tab == value,
                          semanticLabel: labels[tab],
                          excludeChildSemantics: true,
                          focusRadius: BorderRadius.circular(99),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: context.motion(MadarMotion.short),
                              style: text.labelLarge!.copyWith(
                                color: tab == value ? t.textOnAccent : t.textSecondary,
                                height: 1.2,
                              ),
                              child: Text(labels[tab] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
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

/// Softens the top edge where the list scrolls under the tab bar.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
        stops: [0, (18 / rect.height).clamp(0.0, 1.0)],
      ).createShader(rect),
      child: child,
    );
  }
}

/// Shows the selected tab only and cross-fades between them: a thin name
/// for [MadarFadeStack] (see it for why nothing is kept hidden behind).
class _FadeStack extends StatelessWidget {
  const _FadeStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MadarFadeStack(index: index, children: children);
}

