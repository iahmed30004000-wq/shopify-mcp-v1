/// «أهدافي» · his memorisation goals, in his own words (Part 14, step 2).
///
/// Add, edit, switch off, reorder – and every goal's reminder hangs off a
/// **prayer**, not off a clock: «بعد المغرب بـ ١٥ دقيقة» moves with
/// Maghrib all year. The planning itself is
/// [hifzGoalReminderSyncProvider]'s, watched from the app root; this
/// screen only asks it to re-plan the moment he saves, so he never waits
/// for a debounce to see his own change take.
///
/// The title is **his, verbatim**. Nothing here renames a goal and
/// nothing generates one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/quran/ayah.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../wird/data/wird_providers.dart' show quranCatalogReadyProvider;
import '../../data/hifz_plan_providers.dart';
import '../../domain/hifz_goals.dart';
import 'hifz_plan_texts.dart';
import 'hifz_plan_widgets.dart';

/// His goals, in his own order.
class HifzGoalsScreen extends ConsumerWidget {
  const HifzGoalsScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final goals = ref.watch(hifzGoalProgressProvider);
    final texts = HifzPlanTexts.of(context, catalog: ref.watch(quranCatalogReadyProvider).value);
    return MadarScaffold(
      title: l.hifzGoalsTitle,
      backdropSeed: 4.8,
      animateBackdrop:
          animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      actions: [
        MadarButton.icon(
          key: const ValueKey('hifz.goals.add'),
          icon: Icons.add_rounded,
          semanticLabel: l.hifzGoalAdd,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => unawaited(editHifzGoal(context, ref, texts: texts)),
        ),
      ],
      body: switch (goals) {
        AsyncData(value: final list) => list.isEmpty
            ? Center(
                child: AnimatedEmptyState(
                  key: const ValueKey('hifz.goals.empty'),
                  kind: EmptyStateKind.emptyList,
                  title: l.hifzGoalsTitle,
                  body: l.hifzGoalsEmpty,
                  actionLabel: l.hifzGoalAdd,
                  actionIcon: Icons.add_rounded,
                  onAction: () => unawaited(editHifzGoal(context, ref, texts: texts)),
                ),
              )
            : _List(goals: list, texts: texts),
        AsyncError() => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.hifzCatalogError, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.goals, required this.texts});

  final List<HifzGoalProgress> goals;
  final HifzPlanTexts texts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    return ReorderableGlassList<HifzGoalProgress>(
      key: const ValueKey('hifz.goals.list'),
      items: goals,
      itemKey: (g) => g.goal.id,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
      header: Padding(
        padding: const EdgeInsets.only(bottom: Space.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.hifzGoalReminderExplain,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: Space.xs),
            Text(
              l.hifzGoalReorderHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary),
            ),
          ],
        ),
      ),
      onReorder: (order) => unawaited(_reorder(ref, order)),
      itemBuilder: (context, g, index, grip) => _GoalCard(progress: g, texts: texts, grip: grip),
    );
  }

  Future<void> _reorder(WidgetRef ref, List<HifzGoalProgress> order) async {
    final service = await ref.read(hifzPlanServiceProvider.future);
    await service.reorderGoals([for (final g in order) g.goal.id]);
    await ref.read(hifzGoalReminderSyncProvider.notifier).syncNow();
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.progress, required this.texts, this.grip});

  final HifzGoalProgress progress;
  final HifzPlanTexts texts;

  /// The list's own drag grip, so reordering is an explicit handle and
  /// never a long-press that fights the tap.
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final style = Theme.of(context).textTheme;
    final goal = progress.goal;
    final range = goal.range;
    final reminder = goal.canRemind
        ? MadarFormatter.of(context).localizeDigits(
            l.hifzGoalReminderAfterPrayer(
              hifzWindowLabel(l, goal.window),
              l.wirdMinutes(goal.offsetMinutes),
            ),
          )
        : l.hifzGoalNoReminder;
    return HifzPanel(
      key: ValueKey('hifz.goal.${goal.id}'),
      // His own words, verbatim.
      title: goal.title,
      subtitle: [
        texts.goalKind(goal.kind),
        if (range != null) texts.range(range),
        if (goal.kind == HifzGoalKind.rangeOnWeekday && goal.weekday != null) texts.weekday(goal.weekday!),
      ].join(l.commonFactSeparator),
      icon: Icons.flag_outlined,
      iconColor: goal.active ? t.accent : t.textTertiary,
      onTap: () => unawaited(editHifzGoal(context, ref, texts: texts, goal: goal)),
      // No semanticLabel on purpose: the card holds a switch and a drag
      // grip, and collapsing the children into one label would take both
      // away from TalkBack.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MadarSwitch(
            key: ValueKey('hifz.goal.active.${goal.id}'),
            value: goal.active,
            semanticLabel: l.hifzGoalFieldActive,
            onChanged: (v) => unawaited(_setActive(context, ref, goal.id, v)),
          ),
          ?grip,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  texts.goalProgress(progress),
                  key: ValueKey('hifz.goal.progress.${goal.id}'),
                  style: style.bodyMedium,
                ),
              ),
              if (progress.met)
                Text(l.hifzGoalMet, style: style.labelMedium?.copyWith(color: t.success))
              else if (!progress.due)
                Text(l.hifzGoalNotDueToday, style: style.labelMedium?.copyWith(color: t.textTertiary)),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            goal.active ? reminder : l.hifzGoalOffNow,
            key: ValueKey('hifz.goal.reminder.${goal.id}'),
            style: style.bodySmall?.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _setActive(BuildContext context, WidgetRef ref, String id, bool active) async {
    final l = L10n.of(context);
    Fx.fire(active ? Sfx.toggleOn : Sfx.toggleOff);
    final service = await ref.read(hifzPlanServiceProvider.future);
    final undo = await service.setGoalActive(id, active);
    await ref.read(hifzGoalReminderSyncProvider.notifier).syncNow();
    if (!context.mounted) return;
    unawaited(showUndoToast(context, UndoableAction(label: l.hifzGoalSaved, undo: undo)));
  }
}

/// Adds a goal, or edits one. The reminder is asked for as a **prayer**
/// and the minutes after it – never as a time on the clock.
Future<void> editHifzGoal(
  BuildContext context,
  WidgetRef ref, {
  required HifzPlanTexts texts,
  HifzGoal? goal,
}) async {
  final l = L10n.of(context);
  final catalog = ref.read(quranCatalogReadyProvider).value;
  final range = goal?.range;
  final values = await showEditSheet(
    context,
    title: goal == null ? l.hifzGoalAdd : l.hifzGoalEditTitle,
    subtitle: l.hifzGoalReminderExplain,
    icon: Icons.flag_outlined,
    initial: {
      'title': goal?.title ?? '',
      'kind': (goal?.kind ?? HifzGoalKind.rangeOnWeekday).name,
      'surah': range?.first.surah ?? 18,
      'from': range?.first.ayah ?? 1,
      'to': range?.last.ayah ?? 1,
      'weekday': (goal?.weekday ?? DateTime.friday).toString(),
      'amount': goal?.amount ?? 1,
      'unit': (goal?.unit ?? WirdUnit.pages).name,
      'window': goal?.window ?? PrayerWindow.fajr,
      'offset': goal?.offsetMinutes ?? 15,
      'remind': goal?.remind ?? true,
    },
    fields: [
      FieldSpec.text(
        'title',
        l.hifzGoalFieldTitle,
        required: true,
        hint: l.hifzGoalFieldTitleHint,
        icon: Icons.title_rounded,
        maxLength: 80,
        autofocus: goal == null,
      ),
      FieldSpec.singleSelect(
        'kind',
        l.hifzGoalFieldKind,
        required: true,
        icon: Icons.category_outlined,
        options: [
          for (final k in HifzGoalKind.values) SelectOption(id: k.name, label: texts.goalKind(k)),
        ],
      ),
      FieldSpec.number('surah', l.hifzGoalFieldSurah, min: 1, max: 114, step: 1, icon: Icons.menu_book_rounded),
      FieldSpec.number('from', l.hifzGoalFieldFrom, min: 1, max: 286, step: 1),
      FieldSpec.number('to', l.hifzGoalFieldTo, min: 1, max: 286, step: 1),
      FieldSpec.singleSelect(
        'weekday',
        l.hifzGoalFieldWeekday,
        icon: Icons.calendar_today_rounded,
        options: [
          for (final (day, name) in texts.weekdays) SelectOption(id: day.toString(), label: name),
        ],
      ),
      FieldSpec.number('amount', l.hifzGoalFieldAmount, min: 0, max: 604, step: 1, icon: Icons.straighten_rounded),
      FieldSpec.singleSelect(
        'unit',
        l.hifzGoalFieldUnit,
        options: [
          for (final u in WirdUnit.values) SelectOption(id: u.name, label: texts.amount(u, 2)),
        ],
      ),
      FieldSpec.prayerWindow('window', l.hifzGoalFieldWindow, icon: Icons.schedule_rounded),
      FieldSpec.number('offset', l.hifzGoalFieldOffset, min: 0, max: 180, step: 5, icon: Icons.timer_outlined),
      FieldSpec.toggle('remind', l.hifzGoalFieldRemind, icon: Icons.notifications_active_outlined),
    ],
  );
  if (values == null || !context.mounted) return;
  final title = (values['title'] as String?)?.trim() ?? '';
  if (title.isEmpty) return;
  final kind = HifzGoalKind.values.firstWhere(
    (k) => k.name == values['kind'],
    orElse: () => HifzGoalKind.rangeOnWeekday,
  );
  final unit = WirdUnit.values.firstWhere((u) => u.name == values['unit'], orElse: () => WirdUnit.pages);
  int pick(String key, int fallback) => (values[key] as num?)?.toInt() ?? fallback;
  final surah = pick('surah', 18).clamp(1, 114).toInt();
  final maxAyah = catalog?.ayahCount(surah) ?? 286;
  final from = pick('from', 1).clamp(1, maxAyah).toInt();
  final to = pick('to', from).clamp(from, maxAyah).toInt();
  final weekday = int.tryParse('${values['weekday']}') ?? DateTime.friday;
  final window = values['window'] is PrayerWindow ? values['window']! as PrayerWindow : null;
  final goalRange = kind == HifzGoalKind.amountPerDay ? null : AyahRange(AyahRef(surah, from), AyahRef(surah, to));

  final service = await ref.read(hifzPlanServiceProvider.future);
  final Future<void> Function() undo;
  if (goal == null) {
    final (_, u) = await service.addGoal(
      title: title,
      kind: kind,
      range: goalRange,
      weekday: kind == HifzGoalKind.rangeOnWeekday ? weekday : null,
      amount: kind == HifzGoalKind.amountPerDay ? (values['amount'] as num?)?.toDouble() : null,
      unit: unit,
      window: window,
      offsetMinutes: pick('offset', 15),
      remind: values['remind'] != false,
    );
    undo = u;
  } else {
    undo = await service.editGoal(
      goal.id,
      title: title,
      range: goalRange,
      weekday: kind == HifzGoalKind.rangeOnWeekday ? weekday : null,
      amount: kind == HifzGoalKind.amountPerDay ? (values['amount'] as num?)?.toDouble() : null,
      unit: unit,
      window: window,
      offsetMinutes: pick('offset', 15),
      remind: values['remind'] != false,
    );
  }
  // Plan the reminders now, so the prayer-time notice is armed before he
  // leaves the screen.
  await ref.read(hifzGoalReminderSyncProvider.notifier).syncNow();
  if (!context.mounted) return;
  Fx.fire(Sfx.complete);
  unawaited(showUndoToast(context, UndoableAction(label: l.hifzGoalSaved, undo: undo)));
}
