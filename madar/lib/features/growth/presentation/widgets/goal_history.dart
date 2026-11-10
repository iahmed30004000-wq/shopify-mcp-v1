import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../domain/growth_days.dart';
import '../../domain/growth_goal.dart';
import '../growth_texts.dart';

/// A goal's progress log as a timeline, newest first, grouped by day (with
/// each day's total): amount, time, note and the running total after it.
/// Tap or long-press an entry to edit it; delete it with undo.
class GoalHistory extends StatelessWidget {
  const GoalHistory({
    super.key,
    required this.goal,
    required this.today,
    required this.onEdit,
    required this.onDelete,
    this.limit,
  });

  final GrowthGoal goal;
  final DateTime today;
  final FutureOr<void> Function(GoalLogRow log) onEdit;
  final FutureOr<UndoableAction?> Function(GoalLogRow log) onDelete;

  /// Show at most this many entries (null = all).
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final logs = limit == null || goal.logs.length <= limit! ? goal.logs : goal.logs.sublist(0, limit!);
    if (logs.isEmpty) {
      return GlassCard(
        padding: const EdgeInsetsDirectional.all(Space.l),
        child: Row(
          children: [
            Icon(Icons.history_edu_rounded, color: t.textTertiary),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(l.growthHistoryEmpty, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
            ),
          ],
        ),
      );
    }
    final totals = goal.runningTotals();
    final groups = <(DateTime, List<GoalLogRow>)>[];
    for (final log in logs) {
      final day = GrowthDays.dateOnly(log.at);
      if (groups.isEmpty || !GrowthDays.sameDay(groups.last.$1, day)) groups.add((day, []));
      groups.last.$2.add(log);
    }
    var index = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (day, dayLogs) in groups) ...[
          _DayHeader(goal: goal, day: day, today: today, logs: dayLogs),
          for (final (i, log) in dayLogs.indexed)
            StaggerItem(
              index: index++,
              child: _LogEntry(
                key: ValueKey(log.id),
                goal: goal,
                log: log,
                total: totals[log.id] ?? goal.stats.current,
                first: i == 0,
                last: i == dayLogs.length - 1,
                onEdit: () => onEdit(log),
                onDelete: () => onDelete(log),
              ),
            ),
          const SizedBox(height: Space.m),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.goal, required this.day, required this.today, required this.logs});

  final GrowthGoal goal;
  final DateTime day;
  final DateTime today;
  final List<GoalLogRow> logs;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final text = Theme.of(context).textTheme;
    final total = logs.fold<double>(0, (s, e) => s + e.amount);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xs, Space.xs, Space.s),
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(texts.dayLabel(day, today), style: text.titleSmall)),
          ),
          Text(
            l.growthDayTotal(texts.amount(goal.unit, total)),
            style: text.labelMedium!.copyWith(color: t.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _LogEntry extends StatelessWidget {
  const _LogEntry({
    super.key,
    required this.goal,
    required this.log,
    required this.total,
    required this.first,
    required this.last,
    required this.onEdit,
    required this.onDelete,
  });

  final GrowthGoal goal;
  final GoalLogRow log;
  final double total;
  final bool first;
  final bool last;
  final FutureOr<void> Function() onEdit;
  final FutureOr<UndoableAction?> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final text = Theme.of(context).textTheme;
    final color = GrowthColors.goal(t, goal.color);
    final amount = texts.amount(goal.unit, log.amount);
    final time = texts.fmt.formatTime(log.at);
    final note = log.note;
    return ActionableItem(
      onTap: () => onEdit(),
      semanticLabel: [amount, time, ?note, l.growthRunningTotal(texts.number(total))].join(l.growthSep),
      swipeEnabled: true,
      actions: ItemActions(onEdit: onEdit, onDelete: onDelete),
      quickActions: [
        QuickAction(
          icon: Icons.edit_rounded,
          label: l.growthEdit,
          onPressed: () async {
            await onEdit();
            return null;
          },
          tone: ActionTone.accent,
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.growthDelete,
          onPressed: onDelete,
          tone: ActionTone.danger,
        ),
      ],
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 26,
              child: CustomPaint(
                painter: _TimelinePainter(color: color, line: t.glassBorder, first: first, last: last),
              ),
            ),
            const SizedBox(width: Space.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: GlassCard(
                  glow: false,
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.add_rounded, size: 16, color: color),
                                const SizedBox(width: Space.xxs),
                                Flexible(
                                  child: Text(amount, style: text.titleSmall!.copyWith(color: t.textPrimary)),
                                ),
                              ],
                            ),
                            if (note != null && note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: Space.xxs),
                                child: Text(note, maxLines: 3, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(time, style: text.labelMedium),
                          Text(
                            l.growthRunningTotal(texts.number(total)),
                            style: text.labelSmall!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The timeline rail with a glowing bead at the entry.
class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.color, required this.line, required this.first, required this.last});

  final Color color;
  final Color line;
  final bool first;
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    const beadY = 22.0;
    final rail = Paint()
      ..color = line
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(x, first ? beadY : 0), Offset(x, last ? beadY : size.height), rail);
    canvas.drawCircle(
      Offset(x, beadY),
      7,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(Offset(x, beadY), 4.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.color != color || old.line != line || old.first != first || old.last != last;
}
