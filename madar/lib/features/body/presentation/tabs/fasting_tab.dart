import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/body_providers.dart';
import '../../domain/body_clock.dart';
import '../../domain/fasting.dart';
import '../body_actions.dart';
import '../body_texts.dart';
import '../widgets/body_widgets.dart';
import '../widgets/fasting_card.dart';

/// Intermittent fasting: the live clock, the plan (hours, last meal,
/// optional notifications), stats and the history of past fasts.
class BodyFastingTab extends ConsumerWidget {
  const BodyFastingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final past = [
      for (final f in ref.watch(bodyFastsProvider))
        if (!f.active) f,
    ];
    var i = 0;
    Widget stagger(Widget child) => StaggerItem(index: i++, child: child);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bodyTabBottomPadding),
      children: [
        stagger(const FastingCard()),
        const SizedBox(height: Space.m),
        stagger(const FastingPlanCard()),
        if (past.isNotEmpty) ...[const SizedBox(height: Space.m), stagger(const _FastingStats())],
        stagger(BodySectionTitle(l.bodyFastHistory, icon: Icons.history_rounded)),
        if (past.isEmpty)
          stagger(BodyHint(l.bodyFastHistoryEmpty, icon: Icons.nights_stay_outlined))
        else
          for (final f in past.take(60))
            stagger(
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: FastTile(fast: f),
              ),
            ),
      ],
    );
  }
}

/// Fasting hours (16:8 …, custom), the last-meal time and the optional
/// notifications.
class FastingPlanCard extends ConsumerWidget {
  const FastingPlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final plan = ref.watch(bodyFastingPlanProvider).value ?? const FastingPlan();
    final eat = plan.eatingWindow;
    return BodyCard(
      title: l.bodyFastPlan,
      icon: Icons.tune_rounded,
      seed: 8.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.bodyFastHours, style: text.labelLarge?.copyWith(color: t.textSecondary)),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final h in FastingPlan.presets)
                MadarChip(
                  key: ValueKey('body.fast.preset.$h'),
                  label: tx.fmt.localizeDigits('$h:${24 - h}'),
                  selected: plan.target.inMinutes == h * 60,
                  color: p.fasting,
                  onSelected: (_) => BodyActions.updatePlan(context, ref, (x) => x.copyWith(targetHours: h.toDouble())),
                ),
              MadarChip(
                key: const ValueKey('body.fast.custom'),
                label: plan.isPreset ? l.bodyFastCustom : '${l.bodyFastCustom}${tx.sep}${tx.hours(plan.targetHours)}',
                icon: Icons.edit_rounded,
                selected: !plan.isPreset,
                color: p.fasting,
                sfx: Sfx.sheetOpen,
                onSelected: (_) => BodyActions.customFastHours(context, ref),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          BodyHint(
            eat == Duration.zero
                ? l.bodyFastLongHint(tx.fmt.formatNumber(plan.targetHours, maxDecimals: 1))
                : l.bodyFastRatioHint(
                    tx.fmt.formatNumber(plan.targetHours, maxDecimals: 1),
                    tx.fmt.formatNumber(eat.inMinutes / 60, maxDecimals: 1),
                  ),
            icon: Icons.hourglass_bottom_rounded,
          ),
          const MadarDivider(ornament: false, height: Space.xl),
          _SettingRow(
            key: const ValueKey('body.fast.lastMeal'),
            icon: Icons.restaurant_rounded,
            title: l.bodyLastMeal,
            subtitle: l.bodyLastMealHint,
            trailing: Text(
              tx.fmt.formatClock(plan.lastMealMinutes ~/ 60, plan.lastMealMinutes % 60),
              style: text.titleMedium?.copyWith(color: p.fasting),
            ),
            onTap: () => BodyActions.pickLastMeal(context, ref),
          ),
          const SizedBox(height: Space.s),
          _SettingRow(
            icon: Icons.notifications_active_outlined,
            title: l.bodyNotifyGoal,
            trailing: MadarSwitch(
              value: plan.notifyGoal,
              semanticLabel: l.bodyNotifyGoal,
              onChanged: (v) => BodyActions.updatePlan(context, ref, (x) => x.copyWith(notifyGoal: v)),
            ),
          ),
          if (eat > Duration.zero) ...[
            const SizedBox(height: Space.s),
            _SettingRow(
              icon: Icons.alarm_rounded,
              title: l.bodyNotifyEating,
              trailing: MadarSwitch(
                value: plan.notifyEatingClose,
                semanticLabel: l.bodyNotifyEating,
                onChanged: (v) => BodyActions.updatePlan(context, ref, (x) => x.copyWith(notifyEatingClose: v)),
              ),
            ),
            AnimatedSize(
              duration: context.motion(MadarMotion.short),
              curve: MadarMotion.standard,
              child: !plan.notifyEatingClose
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsetsDirectional.only(start: 36, top: Space.s),
                      child: ChoicePills<int>.single(
                        dense: true,
                        options: [
                          for (final m in FastingPlan.leadChoices)
                            ChoiceOption(
                              value: m,
                              label: m == 0 ? l.bodyLeadAtTime : tx.fmt.localizeDigits(l.bodyLeadBefore(tx.fmt.formatInt(m))),
                            ),
                        ],
                        selected: plan.eatingLeadMinutes,
                        onChanged: (m) {
                          if (m != null) BodyActions.updatePlan(context, ref, (x) => x.copyWith(eatingLeadMinutes: m));
                        },
                      ),
                    ),
            ),
          ],
          if (plan.notifyGoal || plan.notifyEatingClose) ...[
            const SizedBox(height: Space.s),
            BodyHint(l.bodyNotifyHint, icon: Icons.notifications_none_rounded),
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({super.key, required this.icon, required this.title, this.subtitle, required this.trailing, this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final row = Row(
      children: [
        Icon(icon, size: 20, color: t.gold),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.bodyMedium),
              if (subtitle != null) Text(subtitle!, style: text.bodySmall?.copyWith(color: t.textTertiary)),
            ],
          ),
        ),
        const SizedBox(width: Space.s),
        trailing,
      ],
    );
    if (onTap == null) return row;
    return MadarPressable(
      onTap: onTap,
      sfx: Sfx.sheetOpen,
      semanticLabel: title,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: Space.xs), child: row),
    );
  }
}

class _FastingStats extends ConsumerWidget {
  const _FastingStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final s = ref.watch(bodyFastingStatsProvider);
    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: l.bodyStatStreak,
            value: tx.fmt.formatInt(s.streak),
            icon: Icons.local_fire_department_outlined,
            color: t.gold,
            caption: tx.fmt.localizeDigits(l.bodyDaysInRow(s.streak, tx.fmt.formatInt(s.streak))),
          ),
        ),
        const SizedBox(width: Space.s),
        Expanded(
          child: StatTile(
            label: l.bodyStatLongest,
            value: s.longest == null ? l.bodyNotSet : tx.duration(s.longest!),
            icon: Icons.emoji_events_outlined,
            color: p.fasting,
            caption: s.average == null ? null : '${l.bodyStatAverage} ${tx.duration(s.average!)}',
          ),
        ),
        const SizedBox(width: Space.s),
        Expanded(
          child: StatTile(
            label: l.bodyStatCompleted,
            value: tx.fmt.localizeDigits(l.bodyFraction(tx.fmt.formatInt(s.completed), tx.fmt.formatInt(s.total))),
            icon: Icons.verified_outlined,
            color: p.eating,
          ),
        ),
      ],
    );
  }
}

/// One finished fast.
class FastTile extends ConsumerWidget {
  const FastTile({super.key, required this.fast});

  final FastingSpan fast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final end = fast.end ?? fast.start;
    final length = fast.duration(end);
    final reached = fast.reached(end);
    final day = tx.fmt.formatDate(BodyDays.of(end), style: MadarDateStyle.weekdayDayMonth);
    final span = '${tx.fmt.formatTime(fast.start)} – ${tx.fmt.formatTime(end)}';
    final share = (length.inSeconds / fast.target.inSeconds).clamp(0.0, 1.0);
    return ActionableItem(
      key: ValueKey('body.fast.${fast.id}'),
      semanticLabel: '$day. ${tx.duration(length)}. ${l.bodyFastGoalBadge(tx.fmt.formatNumber(fast.targetHours, maxDecimals: 1))}',
      borderRadius: BorderRadius.circular(t.radiusM),
      onTap: () => BodyActions.editFast(context, ref, fast.id),
      actions: ItemActions(
        onEdit: () => BodyActions.editFast(context, ref, fast.id),
        onDelete: () => BodyActions.deleteFast(context, ref, fast.id),
      ),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.bodyDelete,
          tone: ActionTone.danger,
          onPressed: () => BodyActions.deleteFast(context, ref, fast.id),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
        borderRadius: BorderRadius.circular(t.radiusM),
        child: Row(
          children: [
            ProgressRing(
              value: share,
              size: 40,
              strokeWidth: 4,
              glow: reached,
              color: reached ? p.eating : p.fasting,
              child: Icon(
                reached ? Icons.check_rounded : Icons.nights_stay_outlined,
                size: 16,
                color: reached ? p.eating : p.fasting,
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day, style: text.labelMedium?.copyWith(color: t.textSecondary)),
                  const SizedBox(height: 2),
                  Text(tx.duration(length), style: text.titleSmall),
                  Text(
                    fast.note == null ? span : '$span${tx.sep}${fast.note}',
                    style: text.bodySmall?.copyWith(color: t.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            BodyPill(
              label: l.bodyFastGoalBadge(tx.fmt.formatNumber(fast.targetHours, maxDecimals: 1)),
              icon: reached ? Icons.verified_rounded : Icons.flag_outlined,
              color: reached ? p.eating : t.textTertiary,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}
