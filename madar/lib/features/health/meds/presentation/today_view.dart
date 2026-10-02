import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../home/widgets/window_chips.dart' show windowIcon, windowLabel;
import '../data/meds_providers.dart';
import '../domain/dose_scheduler.dart';
import '../domain/dose_tracker.dart';
import '../domain/med_models.dart';
import '../meds_texts.dart';
import 'meds_actions.dart';
import 'widgets/dose_tile.dart';
import 'widgets/editor_frame.dart' show MedsChoiceRow;
import 'widgets/meds_widgets.dart';

/// Today's doses grouped by prayer window, with the day's progress and the
/// week's adherence on top, refill and rule notices, and the as-needed
/// medications at the end.
class MedsTodayView extends ConsumerWidget {
  const MedsTodayView({super.key, this.bottomPadding = 110});

  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final today = ref.watch(medsTodayProvider);
    if (today == null) return const Center(child: OrbitLoader());
    if (!today.hasMeds) {
      return ListView(
        padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xl, Space.gutter, bottomPadding),
        children: [
          AnimatedEmptyState(
            kind: EmptyStateKind.emptyList,
            title: l.medsEmptyTitle,
            body: l.medsEmptyBody,
            actionLabel: l.medsAddMed,
            actionIcon: Icons.add_rounded,
            onAction: () => MedsActions.addMed(context, ref),
          ),
        ],
      );
    }
    final windowOf = ref.watch(medsWindowOfProvider);
    final courses = {for (final c in ref.watch(medCoursesProvider).value ?? const <CourseSpec>[]) c.id: c.name};
    final logs = ref.watch(medLogsProvider).value ?? const [];
    final lastTaken = <String, DateTime>{};
    for (final lg in logs) {
      final at = lg.takenAt;
      if (at == null) continue;
      final prev = lastTaken[lg.medId];
      if (prev == null || at.isAfter(prev)) lastTaken[lg.medId] = at;
    }

    // Groups in time order, each a prayer window.
    final groups = <(PrayerWindow, List<TrackedDose>)>[];
    for (final d in today.doses) {
      final w = windowOf(d.dose.at);
      if (groups.isNotEmpty && groups.last.$1 == w) {
        groups.last.$2.add(d);
      } else {
        groups.add((w, [d]));
      }
    }

    var index = 0;
    Widget stagger(Widget child) => StaggerItem(index: index++, child: child);

    return ListView(
      padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bottomPadding),
      children: [
        stagger(MedsDaySummary(today: today)),
        for (final m in today.refills)
          stagger(
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.m),
              child: _RefillBanner(med: m),
            ),
          ),
        if (today.conflicts.isNotEmpty)
          stagger(
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.m),
              child: MedsConflictsCard(conflicts: today.conflicts),
            ),
          ),
        if (today.doses.isEmpty)
          stagger(
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.l),
              child: _Note(icon: Icons.event_available_rounded, text: l.medsNoDosesToday),
            ),
          ),
        for (final (w, doses) in groups) ...[
          stagger(
            MedsGroupHeader(
              label: w == PrayerWindow.anytime ? l.medsAnytimeGroup : windowLabel(l, w),
              icon: windowIcon(w),
            ),
          ),
          for (final d in doses)
            stagger(
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                child: _DoseTileFor(
                  dose: d,
                  courseName: courses[d.dose.courseId],
                  // Buttons from an hour before a dose (taken a little early).
                  showButtons: d.state != DoseState.upcoming || d.dueAt.difference(today.now) <= const Duration(hours: 1),
                ),
              ),
            ),
        ],
        if (today.asNeeded.isNotEmpty) ...[
          stagger(MedsGroupHeader(label: l.medsAsNeeded, icon: Icons.back_hand_rounded)),
          for (final m in today.asNeeded)
            stagger(
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                child: _AsNeededRow(med: m, lastTaken: lastTaken[m.id]),
              ),
            ),
        ],
      ],
    );
  }
}

/// A [DoseTile] wired to [MedsActions].
class _DoseTileFor extends ConsumerWidget {
  const _DoseTileFor({required this.dose, this.courseName, this.showButtons});

  final TrackedDose dose;
  final String? courseName;
  final bool? showButtons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DoseTile(
      dose: dose,
      courseName: courseName,
      showButtons: showButtons,
      onTake: () => MedsActions.take(context, ref, dose, toast: false),
      onSkip: () => MedsActions.skip(context, ref, dose, toast: false),
      onSnooze: (m) => MedsActions.snooze(context, ref, dose, m, toast: false),
      onPickSnooze: () => unawaited(MedsActions.pickSnooze(context, ref, dose)),
      onReset: () => MedsActions.reset(context, ref, dose),
      onEditMed: () => MedsActions.editMed(context, ref, dose.dose.med),
      onHistory: () => MedsActions.openHistory(context, ref, dose.dose.med),
    );
  }
}

/// The day at a glance: a ring of answered doses, what comes next (or what
/// waits now) and the week's adherence bars.
class MedsDaySummary extends ConsumerStatefulWidget {
  const MedsDaySummary({super.key, required this.today});

  final MedsToday today;

  @override
  ConsumerState<MedsDaySummary> createState() => _MedsDaySummaryState();
}

class _MedsDaySummaryState extends ConsumerState<MedsDaySummary> {
  /// Adherence over the last 7 or 30 days.
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final today = widget.today;
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tx = MedsTexts(l, fmt);
    final text = Theme.of(context).textTheme;
    final total = today.total;
    final answered = today.answered;
    final progress = total == 0 ? 0.0 : today.taken / total;
    final due = today.dueNow;
    final next = today.next;
    final complete = total > 0 && answered == total;
    final (String line, Color lineColor) = due.isNotEmpty
        ? (fmt.localizeDigits(l.medsDueNowCount(due.length)), due.any((d) => d.state == DoseState.late) ? t.warning : t.accent)
        : next != null
        ? (l.medsNextDose(tx.name(next.dose.med.name), tx.time(next.dueAt)), t.textSecondary)
        : complete
        ? (l.medsAllAnswered, t.success)
        : (l.medsNoDosesToday, t.textSecondary);
    final adherence = _days == 7 ? today.week : (ref.watch(medsAdherenceProvider(_days)) ?? today.week);
    final rate = adherence.rate;
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(
                value: progress,
                size: 74,
                strokeWidth: 6,
                color: complete ? t.success : t.accent,
                glow: complete,
                semanticLabel: l.medsTodayHeader,
                semanticValue: l.medsTodayCount(fmt.formatInt(today.taken), fmt.formatInt(total)),
                child: complete
                    ? Icon(Icons.check_rounded, color: t.success, size: 28)
                    : Text(
                        '${fmt.formatInt(today.taken)}/${fmt.formatInt(total)}',
                        textDirection: TextDirection.ltr,
                        style: text.titleMedium!.copyWith(color: t.textPrimary),
                      ),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.medsTodayHeader, style: text.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      l.medsTodayCount(fmt.formatInt(today.taken), fmt.formatInt(total)),
                      style: text.bodyMedium!.copyWith(color: t.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge!.copyWith(color: lineColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Text(l.medsAdherence, style: text.labelMedium!.copyWith(color: t.textTertiary)),
              const SizedBox(width: Space.s),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MedsChoiceRow<int>(
                    values: const [7, 30],
                    selected: _days,
                    label: (n) => fmt.localizeDigits(l.medsLastDays(n)),
                    onSelected: (n) => setState(() => _days = n),
                  ),
                ),
              ),
              Text(
                rate == null ? '—' : fmt.formatPercent(rate),
                style: text.labelLarge!.copyWith(color: (rate ?? 0) >= 0.9 ? t.success : t.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.medium),
            child: AdherenceBars(key: ValueKey(_days), summary: adherence, height: 26),
          ),
        ],
      ),
    );
  }
}

class _RefillBanner extends ConsumerWidget {
  const _RefillBanner({required this.med});

  final MedSpec med;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    return GlassCard(
      tint: t.warning.withValues(alpha: t.isDark ? 0.12 : 0.07),
      borderColor: t.warning.withValues(alpha: 0.55),
      glowColor: t.warning.withValues(alpha: 0.25),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.s, Space.s + 2),
      child: Row(
        children: [
          Icon(Icons.inventory_2_rounded, size: 20, color: t.warning),
          const SizedBox(width: Space.s + 2),
          Expanded(
            child: Text(
              l.medsRefillBanner(fmt.isolate(med.name), fmt.formatInt(med.stock ?? 0)),
              style: text.bodyMedium!.copyWith(color: t.textPrimary),
            ),
          ),
          const SizedBox(width: Space.s),
          MadarButton(
            label: l.medsRefilled,
            size: MadarButtonSize.small,
            variant: MadarButtonVariant.secondary,
            onPressed: () => MedsActions.refill(context, ref, med),
          ),
        ],
      ),
    );
  }
}

/// The rules the plan could not satisfy today, in neutral words.
class MedsConflictsCard extends StatelessWidget {
  const MedsConflictsCard({super.key, required this.conflicts});

  final List<DoseConflict> conflicts;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final tx = MedsTexts(l, MadarFormatter.of(context));
    final text = Theme.of(context).textTheme;
    final seen = <String>{};
    final lines = [
      for (final c in conflicts)
        if (seen.add(tx.conflict(c))) tx.conflict(c),
    ];
    return GlassCard(
      tint: t.info.withValues(alpha: t.isDark ? 0.10 : 0.06),
      borderColor: t.info.withValues(alpha: 0.5),
      glowColor: t.info.withValues(alpha: 0.2),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.l, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.rule_rounded, size: 18, color: t.info),
              const SizedBox(width: Space.s),
              Text(l.medsConflictsTitle, style: text.titleSmall!.copyWith(color: t.info)),
            ],
          ),
          for (final line in lines.take(4))
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.xs, start: Space.xl + 2),
              child: Text(line, style: text.bodySmall!.copyWith(color: t.textSecondary)),
            ),
        ],
      ),
    );
  }
}

class _AsNeededRow extends ConsumerWidget {
  const _AsNeededRow({required this.med, this.lastTaken});

  final MedSpec med;
  final DateTime? lastTaken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tx = MedsTexts(l, fmt);
    final text = Theme.of(context).textTheme;
    final last = lastTaken;
    final sub = [
      if (med.dose != null) tx.dose(med.dose!),
      if (last != null) l.medsStateTakenAt('${fmt.formatDate(last, style: MadarDateStyle.dayMonth)} ${fmt.formatTime(last)}'),
    ].join(' · ');
    return GlassCard(
      onTap: () => MedsActions.openHistory(context, ref, med),
      semanticLabel: med.name,
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
      child: Row(
        children: [
          MedOrb(med: med, size: 38),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: BidiIsolate.directionOf(med.name),
                  style: text.titleMedium,
                ),
                if (sub.isNotEmpty)
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: t.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: Space.s),
          MadarButton(
            label: l.medsLogNow,
            icon: Icons.add_task_rounded,
            size: MadarButtonSize.small,
            variant: MadarButtonVariant.secondary,
            onPressed: () => MedsActions.logNow(context, ref, med),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.textSecondary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: t.textTertiary),
        const SizedBox(width: Space.s),
        Flexible(child: Text(text, style: style, textAlign: TextAlign.center)),
      ],
    );
  }
}
