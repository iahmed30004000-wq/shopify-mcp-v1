import 'package:flutter/material.dart';

import '../../../../../core/db/database.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../data/record_providers.dart' show LabTestView;
import '../../domain/appointment_plan.dart';
import '../../domain/lab_flags.dart';
import '../record_ui.dart';
import 'lab_bits.dart';

/// A quiet in-tab group header: a small gold star, the title (and a
/// subtitle) and an optional text action on the end side.
class RecordGroupHeader extends StatelessWidget {
  const RecordGroupHeader({super.key, required this.title, this.subtitle, this.actionLabel, this.onAction});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.xxs, Space.l, 0, Space.s),
        child: Row(
          children: [
            IslamicStar(size: 10, color: t.gold),
            const SizedBox(width: Space.s),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: text.titleSmall!.copyWith(color: t.textPrimary),
                    ),
                    if (subtitle != null)
                      TextSpan(
                        text: '${L10n.of(context).recordListSeparator}$subtitle',
                        style: text.bodySmall!.copyWith(color: t.textTertiary),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actionLabel != null)
              MadarButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                icon: Icons.add_rounded,
              ),
          ],
        ),
      ),
    );
  }
}

/// One lab test: name, reference range, sparkline, latest result and flag.
class LabTestTile extends StatelessWidget {
  const LabTestTile({super.key, required this.view, this.grip});

  final LabTestView view;

  /// Drag handle in reorder mode.
  final Widget? grip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final texts = context.recordTexts;
    final latest = view.latest;
    final range = texts.range(view.range, unit: view.test.unit, decimals: view.decimals);
    final flag = latest?.flag;
    return GlassCard(
      padding: EdgeInsetsDirectional.fromSTEB(grip == null ? Space.l : Space.xs, Space.m, Space.l, Space.m),
      borderColor: flag != null && flag.isOutOfRange ? RecordColors.flag(t, flag).withValues(alpha: 0.45) : null,
      child: Row(
        children: [
          ?grip,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(view.test.name, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  range ?? (view.test.unit == null ? l.recordLabNoRange : BidiIsolate.isolate(view.test.unit!)),
                  style: text.bodySmall!.copyWith(color: t.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (latest != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    fmt.formatDate(latest.date, style: MadarDateStyle.medium),
                    style: text.labelSmall!.copyWith(color: t.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          if (grip == null && view.points.where((p) => p.isNumeric).length >= 2) ...[
            const SizedBox(width: Space.s),
            LabSparkline(
              points: view.points.length > 8 ? view.points.sublist(view.points.length - 8) : view.points,
              range: view.range,
            ),
          ],
          const SizedBox(width: Space.m),
          if (latest == null)
            Text(l.recordLabNoReadings, style: text.bodySmall!.copyWith(color: t.textTertiary))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    texts.reading(latest, decimals: view.decimals),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleLarge!.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: flag != null && flag.isOutOfRange ? RecordColors.flag(t, flag) : t.textPrimary,
                    ),
                  ),
                  if (flag != null && flag != LabFlag.qualitative && flag != LabFlag.noRange) ...[
                    const SizedBox(height: 3),
                    LabFlagChip(flag: flag, dense: true),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A calendar medallion: day number over the month.
class DateMedallion extends StatelessWidget {
  const DateMedallion({super.key, required this.date, this.size = 52, this.highlight = false, this.muted = false});

  final DateTime date;
  final double size;
  final bool highlight;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final month = fmt.formatDate(date, style: MadarDateStyle.dayMonth).replaceAll(RegExp(r'[\d٠-٩]+'), '').trim();
    final color = muted ? t.textTertiary : (highlight ? t.textOnAccent : t.accent);
    return Container(
      width: size,
      height: size + 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusS + 2),
        gradient: highlight && !muted
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(t.accent, t.starTint, 0.2)!, t.accent],
              )
            : null,
        color: highlight && !muted ? null : t.glassFill,
        border: Border.all(color: highlight && !muted ? t.accent : t.glassBorder),
        boxShadow: highlight && !muted && t.isDark
            ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 14)]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            fmt.formatInt(date.day),
            style: text.titleLarge!.copyWith(
              color: color,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            month,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: text.labelSmall!.copyWith(color: color.withValues(alpha: 0.85), height: 1.1),
          ),
        ],
      ),
    );
  }
}

/// An appointment: date medallion, title, when, doctor / place and how
/// many questions wait for it.
class AppointmentTile extends StatelessWidget {
  const AppointmentTile({
    super.key,
    required this.appointment,
    required this.now,
    this.openQuestions = 0,
    this.highlight = false,
    this.footer,
  });

  final AppointmentRow appointment;
  final DateTime now;
  final int openQuestions;

  /// The next appointment: lit medallion and a glowing border.
  final bool highlight;

  /// Extra content under the details (questions inline).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final texts = context.recordTexts;
    final a = appointment;
    final past = !AppointmentTimeline.isUpcoming(a, now);
    final days = AppointmentTimeline.daysUntil(a.at, now);
    final when = texts.dateAtTime(a.at);
    final details = [
      ?a.doctor,
      ?a.place,
    ].where((s) => s.trim().isNotEmpty).map(BidiIsolate.isolate).join(l.recordListSeparator);
    return GlassCard(
      borderColor: highlight ? t.accent.withValues(alpha: 0.6) : null,
      glowColor: highlight ? t.accentGlow : null,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.l, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DateMedallion(date: a.at, highlight: highlight, muted: past),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            a.title,
                            style: text.titleMedium!.copyWith(
                              color: past ? t.textSecondary : t.textPrimary,
                              decoration: a.done ? TextDecoration.lineThrough : null,
                              decorationColor: t.textTertiary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!past) ...[
                          const SizedBox(width: Space.s),
                          _Pill(label: texts.relativeDay(days), color: days <= 1 ? t.accent : t.textSecondary),
                        ],
                        if (a.done) ...[
                          const SizedBox(width: Space.s),
                          _Pill(label: l.recordAppointmentDone, color: t.success, icon: Icons.check_rounded),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(RecordIcons.time, size: 14, color: t.textTertiary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(when, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            a.doctor != null ? RecordIcons.doctor : RecordIcons.place,
                            size: 14,
                            color: t.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(details, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    if (openQuestions > 0) ...[
                      const SizedBox(height: Space.xs),
                      _Pill(
                        label: l.recordAppointmentQuestions(openQuestions, fmt.formatInt(openQuestions)),
                        color: t.info,
                        icon: RecordIcons.questions,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          ?footer,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(7, 2, 8, 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
          Text(
            label,
            style: text.labelSmall!.copyWith(color: color, fontWeight: FontWeight.w600, height: 1.25),
          ),
        ],
      ),
    );
  }
}

/// A condition: name, since when, notes; inactive ones are quieter.
class ConditionTile extends StatelessWidget {
  const ConditionTile({super.key, required this.condition, this.grip});

  final ConditionRow condition;
  final Widget? grip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final c = condition;
    return GlassCard(
      padding: EdgeInsetsDirectional.fromSTEB(grip == null ? Space.l : Space.xs, Space.m, Space.l, Space.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ?grip,
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (c.active ? t.accent : t.textTertiary).withValues(alpha: 0.14),
            ),
            child: Icon(RecordIcons.conditions, size: 19, color: c.active ? t.accent : t.textTertiary),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.name,
                        style: text.titleMedium!.copyWith(color: c.active ? t.textPrimary : t.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!c.active) ...[
                      const SizedBox(width: Space.s),
                      _Pill(label: l.recordConditionInactive, color: t.textTertiary),
                    ],
                  ],
                ),
                if (c.since != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l.recordConditionSince(fmt.formatDate(c.since!, style: MadarDateStyle.medium)),
                      style: text.labelSmall!.copyWith(color: t.textTertiary),
                    ),
                  ),
                if (c.notes != null && c.notes!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(c.notes!, style: text.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A question for the doctor: a ring that fills when answered, the
/// question and its answer.
class QuestionTile extends StatelessWidget {
  const QuestionTile({super.key, required this.question, this.grip, this.onToggle, this.appointmentLabel});

  final DoctorQuestionRow question;
  final Widget? grip;
  final VoidCallback? onToggle;

  /// "For an appointment" line (in the general list).
  final String? appointmentLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final q = question;
    return GlassCard(
      padding: EdgeInsetsDirectional.fromSTEB(grip == null ? Space.s : Space.xs, Space.s, Space.l, Space.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?grip,
          MadarPressable(
            onTap: onToggle,
            sfx: null,
            semanticLabel: q.answered ? l.recordQuestionReopen : l.recordQuestionMarkAnswered,
            toggled: q.answered,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: q.answered ? t.success.withValues(alpha: 0.9) : null,
                    border: Border.all(color: q.answered ? t.success : t.textTertiary, width: 1.6),
                  ),
                  child: q.answered ? Icon(Icons.check_rounded, size: 15, color: t.space1) : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.question,
                    style: text.bodyLarge!.copyWith(color: q.answered ? t.textSecondary : t.textPrimary),
                  ),
                  if (appointmentLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(appointmentLabel!, style: text.labelSmall!.copyWith(color: t.textTertiary)),
                    ),
                  if (q.answered && (q.answer?.trim().isNotEmpty ?? false))
                    Container(
                      margin: const EdgeInsets.only(top: Space.xs),
                      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.xs, Space.s, Space.xs),
                      decoration: BoxDecoration(
                        border: BorderDirectional(start: BorderSide(color: t.success.withValues(alpha: 0.6), width: 2)),
                      ),
                      child: Text(q.answer!, style: text.bodySmall!.copyWith(color: t.textSecondary)),
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
