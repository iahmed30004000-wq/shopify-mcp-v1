import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import 'history_view.dart';
import 'today_view.dart';

enum TrackerTab { today, history }

/// The prayer tracker: a Today tab (the five prayers with their rawatib,
/// Duha, Witr and Qiyam) and a History tab (streaks, week strip, month
/// heatmap, totals, per-prayer bars and the qada ledger).
class PrayerTrackerScreen extends StatefulWidget {
  const PrayerTrackerScreen({super.key, this.initialTab = TrackerTab.today, this.animateBackdrop = true});

  final TrackerTab initialTab;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  State<PrayerTrackerScreen> createState() => _PrayerTrackerScreenState();
}

class _PrayerTrackerScreenState extends State<PrayerTrackerScreen> {
  late TrackerTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return MadarScaffold(
      title: l.trackerTitle,
      backdropSeed: 5.3,
      animateBackdrop: widget.animateBackdrop,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
            child: TrackerTabBar(
              value: _tab,
              labels: {TrackerTab.today: l.trackerTabToday, TrackerTab.history: l.trackerTabHistory},
              onChanged: (tab) => setState(() => _tab = tab),
            ),
          ),
          Expanded(
            child: EntranceChoreo(
              id: _tab,
              child: _FadeStack(
                index: _tab.index,
                // Only the selected tab is built (MadarFadeStack): a tab
                // opens at its top again, and no PageStorage slot is shared
                // with the nested horizontal scrollers inside it.
                children: const [
                  _EdgeFade(child: TrackerTodayView(key: ValueKey('tracker.today'))),
                  _EdgeFade(child: TrackerHistoryView(key: ValueKey('tracker.history'))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A glass segmented control whose golden thumb springs between the tabs
/// (follows the reading direction).
class TrackerTabBar extends StatelessWidget {
  const TrackerTabBar({super.key, required this.value, required this.labels, required this.onChanged});

  final TrackerTab value;
  final Map<TrackerTab, String> labels;
  final ValueChanged<TrackerTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    const tabs = TrackerTab.values;
    final dir = Directionality.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        // 48 dp tabs inside the 4 dp rim and the hairline (Android's
        // minimum tap target).
        height: 58,
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

