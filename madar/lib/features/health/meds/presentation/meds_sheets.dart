import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/interaction/sheets/field_inputs.dart';
import '../../../../core/motion/motion_kit.dart';
import '../data/meds_providers.dart';
import '../domain/course_schedule.dart';
import '../domain/dose_tracker.dart';
import '../domain/med_models.dart';
import '../domain/meds_settings.dart';
import '../meds_texts.dart';
import 'meds_actions.dart';
import 'widgets/meds_widgets.dart';

// ------------------------------------------------------------------ snooze --

/// Asks how long to snooze (10 / 30 / 60 minutes).
Future<int?> showSnoozeSheet(BuildContext context, {required String name}) {
  return showInteractionSheet<int>(
    context,
    builder: (context) {
      final l = L10n.of(context);
      final tx = MedsTexts(l, MadarFormatter.of(context));
      final t = context.tokens;
      final text = Theme.of(context).textTheme;
      return InteractionSheetFrame(
        title: l.medsSnooze,
        subtitle: tx.name(name),
        icon: Icons.snooze_rounded,
        body: Row(
          children: [
            for (final (i, m) in MedsSettings.snoozeChoices.indexed) ...[
              if (i > 0) const SizedBox(width: Space.m),
              Expanded(
                child: StaggerItem(
                  index: i,
                  child: GlassCard(
                    onTap: () => Navigator.of(context).pop(m),
                    semanticLabel: l.medsSnoozeFor(tx.duration(m)),
                    borderRadius: BorderRadius.circular(t.radiusL),
                    padding: const EdgeInsetsDirectional.symmetric(vertical: Space.l),
                    child: Column(
                      children: [
                        Icon(Icons.snooze_rounded, color: t.info, size: 22),
                        const SizedBox(height: Space.s),
                        Text(tx.duration(m), style: text.titleLarge!.copyWith(color: t.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

// ------------------------------------------------------------------ refill --

/// Asks how many units a refill added.
Future<int?> showRefillSheet(BuildContext context, {required MedSpec med}) {
  return showInteractionSheet<int>(context, builder: (context) => _RefillSheet(med: med));
}

class _RefillSheet extends StatefulWidget {
  const _RefillSheet({required this.med});

  final MedSpec med;

  @override
  State<_RefillSheet> createState() => _RefillSheetState();
}

class _RefillSheetState extends State<_RefillSheet> {
  int _added = 30;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tx = MedsTexts(l, fmt);
    final stock = widget.med.stock ?? 0;
    return InteractionSheetFrame(
      title: l.medsRefillSheetTitle(tx.name(widget.med.name)),
      subtitle: l.medsStockLine(fmt.formatInt(stock)),
      icon: Icons.inventory_2_rounded,
      body: FieldShell(
        label: l.medsRefillAdded,
        icon: Icons.add_box_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final n in const [10, 20, 28, 30, 60, 90])
                  KitChip(
                    label: fmt.formatInt(n),
                    selected: _added == n,
                    dense: true,
                    onTap: () => setState(() => _added = n),
                  ),
              ],
            ),
            const SizedBox(height: Space.m),
            MedsStepper(
              value: _added,
              min: 1,
              max: 9999,
              label: l.medsRefillAdded,
              onChanged: (v) => setState(() => _added = v),
            ),
          ],
        ),
      ),
      footer: SheetButton(
        label: l.medsSave,
        primary: true,
        icon: Icons.check_rounded,
        onPressed: () => Navigator.of(context).pop(_added),
      ),
    );
  }
}

// ---------------------------------------------------------------- settings --

/// The tracker's settings: meal times, "empty stomach", reminders, snooze.
Future<MedsSettings?> showMedsSettingsSheet(BuildContext context, {required MedsSettings settings}) {
  return showInteractionSheet<MedsSettings>(context, builder: (context) => _SettingsSheet(initial: settings));
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.initial});

  final MedsSettings initial;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late MedsSettings _s = widget.initial;
  MealSlot? _editing;

  void _set(MedsSettings s) => setState(() => _s = s);

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tx = MedsTexts(l, fmt);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    Widget chips(List<int> values, int current, ValueChanged<int> onPick) => Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final v in values)
          KitChip(label: tx.duration(v), selected: v == current, dense: true, onTap: () => onPick(v)),
      ],
    );

    return InteractionSheetFrame(
      title: l.medsSettingsTitle,
      icon: Icons.tune_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldShell(
            label: l.medsMealTimes,
            icon: Icons.restaurant_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: Space.s, start: Space.xxs),
                  child: Text(l.medsMealTimesHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                ),
                for (final meal in MealSlot.values) ...[
                  PickerButton(
                    icon: switch (meal) {
                      MealSlot.breakfast => Icons.free_breakfast_rounded,
                      MealSlot.lunch => Icons.lunch_dining_rounded,
                      MealSlot.dinner => Icons.dinner_dining_rounded,
                      MealSlot.bedtime => Icons.bedtime_rounded,
                    },
                    text: '${tx.mealTitle(meal)} · ${tx.clock(_s.mealTime(meal))}',
                    active: _editing == meal,
                    onTap: () => setState(() => _editing = _editing == meal ? null : meal),
                  ),
                  AnimatedSize(
                    duration: context.motion(MadarMotion.medium),
                    curve: MadarMotion.standard,
                    child: _editing == meal
                        ? Padding(
                            padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s),
                            child: TimeWheel(
                              value: _s.mealTime(meal).hhmm,
                              minuteStep: 5,
                              onChanged: (v) {
                                final hm = ClockHm.tryParse(v);
                                if (hm == null) return;
                                _set(_s.copyWith(meals: {..._s.meals, meal: hm}));
                              },
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: Space.s),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.medsEmptyStomachLead,
            icon: Icons.no_food_rounded,
            child: chips(const [15, 30, 45, 60], _s.emptyStomachLead, (v) => _set(_s.copyWith(emptyStomachLead: v))),
          ),
          const SizedBox(height: Space.xl),
          Row(
            children: [
              Icon(Icons.notifications_active_rounded, size: 18, color: t.accent),
              const SizedBox(width: Space.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.medsReminders, style: text.titleSmall!.copyWith(color: t.textPrimary)),
                    Text(l.medsRemindersHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                  ],
                ),
              ),
              const SizedBox(width: Space.s),
              GlassSwitch(
                value: _s.notify,
                semanticLabel: l.medsReminders,
                onChanged: (v) => _set(_s.copyWith(notify: v)),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.medsSnoozeDefault,
            icon: Icons.snooze_rounded,
            child: chips(MedsSettings.snoozeChoices, _s.snoozeMinutes, (v) => _set(_s.copyWith(snoozeMinutes: v))),
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.medsLateAfter,
            icon: Icons.hourglass_bottom_rounded,
            child: chips(const [30, 60, 90, 120], _s.lateAfter, (v) => _set(_s.copyWith(lateAfter: v))),
          ),
        ],
      ),
      footer: SheetButton(
        label: l.medsSave,
        primary: true,
        icon: Icons.check_rounded,
        onPressed: () => Navigator.of(context).pop(_s),
      ),
    );
  }
}

// ----------------------------------------------------------------- history --

/// One medication's history: 30-day adherence, streak, recent doses,
/// titration, stock and notes.
Future<void> showMedHistorySheet(BuildContext context, {required String medId}) {
  return showInteractionSheet<void>(context, builder: (context) => _HistorySheet(medId: medId));
}

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet({required this.medId});

  final String medId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tx = MedsTexts(l, fmt);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final history = ref.watch(medHistoryProvider(medId));
    if (history == null) {
      return InteractionSheetFrame(
        title: l.medsHistory,
        body: const SizedBox(height: 120, child: Center(child: OrbitLoader())),
      );
    }
    final med = history.med;
    final a = history.adherence;
    final rate = a.rate;
    final today = ref.watch(medsTodayDateProvider);
    TitrationStep? current;
    for (final s in med.titration) {
      if (!s.from.isAfter(today)) current = s;
    }
    final recent = history.doses.take(12).toList();

    Widget stat(String label, int value, Color color) => Expanded(
      child: Column(
        children: [
          Text(fmt.formatInt(value), style: text.titleLarge!.copyWith(color: color)),
          Text(label, style: text.labelSmall!.copyWith(color: t.textTertiary)),
        ],
      ),
    );

    return InteractionSheetFrame(
      title: l.medsHistoryTitle(tx.name(med.name)),
      subtitle: [
        if (med.dose != null) tx.dose(med.dose!),
        tx.kind(med.kind),
      ].join(' · '),
      icon: medKindIcon(med.kind),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            borderRadius: BorderRadius.circular(t.radiusL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ProgressRing(
                      value: rate ?? 0,
                      size: 64,
                      strokeWidth: 5,
                      color: (rate ?? 0) >= 0.9 ? t.success : t.accent,
                      semanticLabel: l.medsAdherence,
                      semanticValue: rate == null ? null : fmt.formatPercent(rate),
                      child: Text(
                        rate == null ? '—' : fmt.formatPercent(rate),
                        style: text.labelLarge!.copyWith(color: t.textPrimary),
                      ),
                    ),
                    const SizedBox(width: Space.l),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fmt.localizeDigits(l.medsLastDays(30)), style: text.titleSmall),
                          Text(
                            rate == null ? l.medsNoAdherence : l.medsAdherenceRate(fmt.formatPercent(rate)),
                            style: text.bodySmall!.copyWith(color: t.textSecondary),
                          ),
                          Text(
                            fmt.localizeDigits(l.medsStreakDays(a.streak)),
                            style: text.labelMedium!.copyWith(color: t.gold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.l),
                AdherenceBars(summary: a, height: 40),
                const SizedBox(height: Space.m),
                Row(
                  children: [
                    stat(l.medsStatTaken, a.taken, t.success),
                    stat(l.medsStatSkipped, a.skipped, t.textSecondary),
                    stat(l.medsStatMissed, a.missed, t.danger),
                    stat(l.medsStatLate, a.days.fold(0, (s, d) => s + d.late), t.warning),
                  ],
                ),
              ],
            ),
          ),
          if (med.titration.isNotEmpty) ...[
            MedsGroupHeader(label: l.medsTitration, icon: Icons.stairs_rounded),
            for (final s in med.titration)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Space.xs),
                child: Row(
                  children: [
                    Icon(
                      identical(s, current) ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: identical(s, current) ? t.accent : t.textTertiary,
                    ),
                    const SizedBox(width: Space.s),
                    Text(
                      l.medsTitrationFrom(fmt.formatDate(s.from, style: MadarDateStyle.dayMonth)),
                      style: text.bodyMedium!.copyWith(color: t.textSecondary),
                    ),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: Text(
                        s.stop ? l.medsTitrationStopLine : tx.dose(s.dose ?? med.dose ?? ''),
                        style: text.bodyMedium!.copyWith(color: t.textPrimary),
                      ),
                    ),
                    if (identical(s, current)) MedBadge(label: l.medsTitrationNow, color: t.accent, filled: true),
                  ],
                ),
              ),
          ],
          MedsGroupHeader(label: l.medsRecent, icon: Icons.history_rounded),
          if (recent.isEmpty && history.offSchedule.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: Space.m),
              child: Text(l.medsNoHistory, style: text.bodyMedium!.copyWith(color: t.textTertiary)),
            ),
          for (final d in recent) _HistoryRow(dose: d),
          for (final log in history.offSchedule.take(6))
            _HistoryLine(
              when: log.at!,
              label: l.medsOffSchedule,
              color: t.info,
              icon: Icons.add_task_rounded,
            ),
          if (med.stock != null || (med.notes?.isNotEmpty ?? false)) const SizedBox(height: Space.m),
          if (med.stock != null)
            Text(
              [
                l.medsStockLine(fmt.formatInt(med.stock!)),
                if (med.refillAt != null) l.medsRefillAtLine(fmt.formatInt(med.refillAt!)),
              ].join(' · '),
              style: text.bodySmall!.copyWith(color: med.needsRefill ? t.warning : t.textSecondary),
            ),
          if (med.notes?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.s),
              child: Text(
                med.notes!,
                textDirection: BidiIsolate.directionOf(med.notes!),
                style: text.bodyMedium!.copyWith(color: t.textSecondary),
              ),
            ),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(
              label: l.medsEdit,
              icon: Icons.edit_rounded,
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(MedsActions.editMed(context, ref, med));
              },
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: SheetButton(
              label: l.medsLogNow,
              icon: Icons.add_task_rounded,
              primary: true,
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(MedsActions.logNow(context, ref, med));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.dose});

  final TrackedDose dose;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final tx = MedsTexts(l, MadarFormatter.of(context));
    final t = context.tokens;
    return _HistoryLine(
      // The time it is set for (a taken dose's own time is in its label).
      when: dose.dose.baseAt,
      label: tx.state(dose),
      color: doseStateColor(dose.state, t),
      icon: doseStateIcon(dose.state),
    );
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({required this.when, required this.label, required this.color, required this.icon});

  final DateTime when;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fmt = MadarFormatter.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(
              '${fmt.formatDate(when, style: MadarDateStyle.weekdayDayMonth)} · ${fmt.formatTime(when)}',
              style: text.bodyMedium!.copyWith(color: t.textSecondary),
            ),
          ),
          Text(label, style: text.labelMedium!.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ course --

/// A course's dates: past doses with their answers, today, upcoming ones.
Future<void> showCourseSheet(BuildContext context, {required String courseId}) {
  return showInteractionSheet<void>(context, builder: (context) => _CourseSheet(courseId: courseId));
}

class _CourseSheet extends ConsumerWidget {
  const _CourseSheet({required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tx = MedsTexts(l, fmt);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final course = ref.watch(medCoursesProvider).value?.where((c) => c.id == courseId).firstOrNull;
    if (course == null) {
      return InteractionSheetFrame(title: l.medsCourseTimeline, body: const SizedBox(height: 80));
    }
    final today = ref.watch(medsTodayDateProvider);
    final logs = ref.watch(medLogsProvider).value ?? const [];
    final taken = <String, DoseStatus>{};
    for (final lg in logs) {
      if (lg.medId != course.medicationId) continue;
      final when = lg.slot ?? lg.at;
      if (when == null) continue;
      final key = MedDays.key(when);
      final prev = taken[key];
      if (prev != DoseStatus.taken) taken[key] = lg.status;
    }
    final all = CourseSchedule.expand(course, until: MedDays.addMonths(today, 13));
    // The recent past and what is ahead, around today.
    final firstUpcoming = all.indexWhere((d) => !d.day.isBefore(today));
    final start = (firstUpcoming < 0 ? all.length : firstUpcoming) - 6;
    final shown = all.sublist(start.clamp(0, all.length), (start.clamp(0, all.length) + 16).clamp(0, all.length));
    final more = all.length - (start.clamp(0, all.length) + shown.length);

    return InteractionSheetFrame(
      title: course.name,
      subtitle: l.medsCourseTimeline,
      icon: Icons.vaccines_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, d) in shown.indexed)
            _TimelineRow(
              date: d.day,
              phaseLabel: '${l.medsCoursePhaseN(fmt.formatInt(d.phase + 1))} · ${tx.phase(course.phases[d.phase])}',
              dose: d.dose,
              status: d.day.isBefore(today) || MedDays.same(d.day, today) ? taken[MedDays.key(d.day)] : null,
              isToday: MedDays.same(d.day, today),
              past: d.day.isBefore(today),
              first: i == 0,
              last: i == shown.length - 1,
              phaseChanged: i > 0 && shown[i - 1].phase != d.phase,
            ),
          if (more > 0 && CourseSchedule.total(course) != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.s, start: Space.xl),
              child: Text(
                fmt.localizeDigits(l.medsCourseMoreDates(more)),
                style: text.bodySmall!.copyWith(color: t.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.date,
    required this.phaseLabel,
    required this.dose,
    required this.status,
    required this.isToday,
    required this.past,
    required this.first,
    required this.last,
    required this.phaseChanged,
  });

  final DateTime date;
  final String phaseLabel;
  final String? dose;
  final DoseStatus? status;
  final bool isToday;
  final bool past;
  final bool first;
  final bool last;
  final bool phaseChanged;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tx = MedsTexts(l, fmt);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (Color c, IconData icon, String label) = switch (status) {
      DoseStatus.taken => (t.success, Icons.check_circle_rounded, l.medsStatTaken),
      DoseStatus.skipped => (t.textTertiary, Icons.redo_rounded, l.medsStatSkipped),
      _ when isToday => (t.accent, Icons.radio_button_checked_rounded, l.medsToday),
      _ when past => (t.danger, Icons.remove_circle_outline_rounded, l.medsStatMissed),
      _ => (t.textTertiary, Icons.circle_outlined, ''),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(child: Container(width: 1.4, color: first ? Colors.transparent : t.brass.withValues(alpha: 0.5))),
                Icon(icon, size: 18, color: c),
                Expanded(child: Container(width: 1.4, color: last ? Colors.transparent : t.brass.withValues(alpha: 0.5))),
              ],
            ),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (phaseChanged || first)
                    Text(phaseLabel, style: text.labelSmall!.copyWith(color: t.gold)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fmt.formatDate(date, style: MadarDateStyle.weekdayDayMonth),
                          style: text.bodyMedium!.copyWith(
                            color: isToday ? t.textPrimary : (past ? t.textSecondary : t.textPrimary),
                            fontWeight: isToday ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                      if (dose != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: Space.s),
                          child: Text(tx.dose(dose!), style: text.bodySmall!.copyWith(color: t.textSecondary)),
                        ),
                      if (label.isNotEmpty) Text(label, style: text.labelMedium!.copyWith(color: c)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
