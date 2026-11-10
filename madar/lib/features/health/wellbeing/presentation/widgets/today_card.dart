import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/wellbeing_providers.dart';
import '../../domain/breathing.dart';
import '../../domain/wellbeing_data.dart';
import '../breathing_screen.dart';
import '../sheets/mood_check_in_sheet.dart';
import '../wellbeing_screen.dart';
import '../wellbeing_texts.dart';
import 'mood_face.dart';
import 'support_banner.dart';
import 'wb_palette.dart';
import 'wb_widgets.dart';

/// The wellbeing summary for the Health hub: today's check-in (or five
/// faces to start one), the habit checklist's progress, parked worries, a
/// breathing shortcut and – when it applies – the compact support banner.
class WellbeingTodayCard extends ConsumerWidget {
  const WellbeingTodayCard({super.key, this.onOpen, this.onBreathe});

  /// Opens the wellbeing screen on a tab (defaults to pushing
  /// [WellbeingScreen]).
  final void Function(WellbeingTab tab)? onOpen;

  /// Opens guided breathing (defaults to pushing [BreathingScreen]).
  final VoidCallback? onBreathe;

  void _open(BuildContext context, WellbeingTab tab) {
    if (onOpen != null) return onOpen!(tab);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WellbeingScreen(initialTab: tab)));
  }

  void _breathe(BuildContext context) {
    if (onBreathe != null) return onBreathe!();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BreathingScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final tx = WbTexts.of(context);
    final checkIn = ref.watch(todayCheckInProvider);
    final habits = ref.watch(habitTodayCountProvider);
    final parked = ref.watch(parkedWorriesProvider).length;
    final today = ref.watch(wellbeingTodayProvider);
    return WbCard(
      title: l.wbTodayCardTitle,
      icon: Icons.spa_outlined,
      seed: 3.3,
      trailing: MadarButton.icon(
        icon: wbForwardChevron(context),
        semanticLabel: l.wbOpen,
        variant: MadarButtonVariant.ghost,
        size: MadarButtonSize.small,
        sfx: Sfx.navigate,
        onPressed: () => _open(context, WellbeingTab.today),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SupportBanner(compact: true, padding: EdgeInsets.only(bottom: Space.m)),
          if (checkIn == null) ...[
            Text(l.wbMoodQuestion, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
            const SizedBox(height: Space.s),
            MoodFacePicker(
              value: null,
              labels: tx.moodLabels,
              size: 38,
              showLabels: false,
              onChanged: (m) => showMoodCheckInSheet(context, initialMood: m),
            ),
          ] else
            Semantics(
              button: true,
              label: l.wbCheckInEditTitle,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Fx.fire(Sfx.sheetOpen);
                  showMoodCheckInSheet(context, entry: checkIn);
                },
                child: Row(
                  children: [
                    if (checkIn.mood != null) ...[
                      MoodFace(mood: checkIn.mood!, size: 44, selected: true),
                      const SizedBox(width: Space.m),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            checkIn.mood != null ? tx.moodLabel(checkIn.mood!) : l.wbCheckedIn,
                            style: text.titleMedium,
                          ),
                          Text(tx.dayTime(checkIn.at, today), style: text.labelSmall?.copyWith(color: t.textTertiary)),
                          const SizedBox(height: Space.xs),
                          Wrap(
                            spacing: Space.xs,
                            runSpacing: Space.xs,
                            children: [
                              if (checkIn.stress != null)
                                WbValuePill(
                                  label: '${l.wbMetricStress} ${fmt.formatInt(checkIn.stress!)}',
                                  color: WbPalette.metric(t, WellMetric.stress),
                                ),
                              if (checkIn.sleepHours != null)
                                WbValuePill(
                                  label: tx.hours(checkIn.sleepHours!),
                                  icon: Icons.bedtime_outlined,
                                  color: WbPalette.metric(t, WellMetric.sleep),
                                ),
                              if (checkIn.energy != null)
                                WbValuePill(
                                  label: '${l.wbMetricEnergy} ${fmt.formatInt(checkIn.energy!)}',
                                  color: WbPalette.metric(t, WellMetric.energy),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Expanded(
                child: _Mini(
                  icon: Icons.checklist_rounded,
                  label: l.wbHabitsShort,
                  value: fmt.localizeDigits(l.wbFraction(fmt.formatInt(habits.done), fmt.formatInt(habits.total))),
                  progress: habits.total == 0 ? 0 : habits.done / habits.total,
                  onTap: () => _open(context, WellbeingTab.habits),
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: _Mini(
                  icon: Icons.inventory_2_outlined,
                  label: l.wbWorriesShort,
                  value: fmt.formatInt(parked),
                  onTap: () => _open(context, WellbeingTab.worries),
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: _Mini(
                  icon: Icons.air_rounded,
                  label: l.wbBreatheShort,
                  value: tx.patternRhythm(
                    ref.watch(wellbeingSettingsProvider).value?.pattern ?? BreathingPattern.fourSevenEight,
                  ),
                  onTap: () => _breathe(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.label, required this.value, required this.onTap, this.progress});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: onTap,
      sfx: Sfx.navigate,
      semanticLabel: '$label: $value',
      excludeChildSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.s),
        decoration: BoxDecoration(
          color: t.glassFill,
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: t.glassBorder),
        ),
        child: Row(
          children: [
            if (progress != null)
              ProgressRing(value: progress!, size: 26, strokeWidth: 3.5, glow: false, color: t.success)
            else
              Icon(icon, size: 20, color: t.gold),
            const SizedBox(width: Space.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: text.titleSmall, maxLines: 1),
                  Text(
                    label,
                    style: text.labelSmall?.copyWith(color: t.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
