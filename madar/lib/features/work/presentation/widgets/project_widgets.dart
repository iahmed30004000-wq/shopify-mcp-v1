import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../data/work_models.dart';
import '../../domain/countdown.dart';
import '../work_labels.dart';
import 'work_widgets.dart';

/// Colour of a countdown.
Color countdownColor(MadarTokens t, Countdown c, {bool done = false}) {
  if (done) return t.success;
  return switch (c.kind) {
    CountdownKind.overdue => t.danger,
    CountdownKind.today || CountdownKind.tomorrow => t.warning,
    CountdownKind.days => c.days <= 7 ? t.warning : t.textSecondary,
    CountdownKind.none => t.textTertiary,
  };
}

/// One-line countdown text: "١٢ يومًا", "tomorrow", "3 days past …".
String countdownText(WorkTexts texts, Countdown c) => switch (c.kind) {
  CountdownKind.none => texts.l.workNoDeadline,
  CountdownKind.today => texts.l.workDueTodayCaption,
  CountdownKind.tomorrow => texts.l.workDueTomorrowCaption,
  CountdownKind.overdue => texts.d(texts.l.workOverdueDays(c.days)),
  CountdownKind.days => texts.daysLeft(c.days),
};

/// A project row: progress ring, name, countdown, steps and status.
class ProjectTile extends StatelessWidget {
  const ProjectTile({super.key, required this.project, required this.today, this.trailing});

  final ProjectView project;
  final DateTime today;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final text = Theme.of(context).textTheme;
    final p = project.row;
    final color = workColor(t, p.color);
    final done = p.status == ProjectStatus.done;
    final countdown = done ? Countdown.none : Countdown.of(p.deadline, today);
    final prog = project.progress;
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
      child: Row(
        children: [
          ProgressRing(
            value: prog.fraction,
            size: 52,
            strokeWidth: 5,
            color: prog.complete || done ? t.success : color,
            glow: prog.complete,
            semanticLabel: p.name,
            semanticValue: texts.fmt.formatPercent(prog.fraction),
            child: prog.complete || done
                ? Icon(Icons.check_rounded, color: t.success, size: 22)
                : Text(texts.fmt.formatPercent(prog.fraction), style: text.labelSmall!.copyWith(color: t.textPrimary)),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                const SizedBox(height: 2),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    if (!done && p.deadline != null)
                      WorkPill(
                        label: countdownText(texts, countdown),
                        icon: countdown.isOverdue ? Icons.error_outline_rounded : Icons.hourglass_bottom_rounded,
                        color: countdownColor(t, countdown),
                        filled: countdown.isOverdue,
                      ),
                    if (prog.total > 0)
                      WorkPill(
                        label: texts.l.workItemsProgress(texts.n(prog.done), texts.n(prog.total)),
                        icon: Icons.checklist_rounded,
                      ),
                    if (p.status != ProjectStatus.active)
                      WorkPill(label: texts.status(p.status), icon: workStatusIcon(p.status), color: done ? t.success : t.info),
                  ],
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The big countdown of a project page: "١٢" over "يومًا – حتى الموعد
/// النهائي" (or today / tomorrow / overdue), with the date.
class CountdownBlock extends StatelessWidget {
  const CountdownBlock({super.key, required this.deadline, required this.today, this.done = false});

  final DateTime? deadline;
  final DateTime today;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final text = Theme.of(context).textTheme;
    final c = Countdown.of(deadline, today);
    final color = countdownColor(t, c, done: done);
    final d = deadline;
    String? big;
    String caption;
    if (done) {
      caption = texts.l.workStatusDone;
    } else {
      switch (c.kind) {
        case CountdownKind.days:
          // "١٢" over "يومًا حتى الموعد النهائي"; a form without the digits
          // (Arabic dual "يومان") stays whole.
          final n = texts.n(c.days), full = texts.daysLeft(c.days);
          big = full.contains(n) ? n : null;
          caption = '${big == null ? full : full.replaceFirst(n, '').trim()} ${texts.l.workDaysLeftCaption}';
        case CountdownKind.overdue:
          big = texts.n(c.days);
          caption = countdownText(texts, c);
        case _:
          caption = countdownText(texts, c);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (big != null)
          Text(
            big,
            style: MadarTypography.numerals(t, size: 40, color: color).copyWith(fontWeight: FontWeight.w600, height: 1.1),
          )
        else
          Icon(done ? Icons.verified_rounded : Icons.hourglass_bottom_rounded, color: color, size: 30),
        const SizedBox(height: 2),
        Text(caption, style: text.labelLarge!.copyWith(color: color)),
        if (d != null && !done)
          Text(
            texts.l.workDeadlineOn(texts.fmt.formatDate(d, style: MadarDateStyle.medium)),
            style: text.labelSmall,
          ),
      ],
    );
  }
}
