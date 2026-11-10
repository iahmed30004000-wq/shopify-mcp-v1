import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/calendar_days.dart';
import '../../domain/wird_engine.dart';
import '../wird_labels.dart';

/// A month of a plan's history: each day a small medallion – filled when the
/// portion was read, half-lit when partly, a faint dot when missed, soft
/// when nothing was owed, dashed while paused; today ringed. Swipes / arrows
/// move between months (never past the current one).
class WirdHistoryCalendar extends StatefulWidget {
  const WirdHistoryCalendar({super.key, required this.state});

  final WirdPlanState state;

  @override
  State<WirdHistoryCalendar> createState() => _WirdHistoryCalendarState();
}

class _WirdHistoryCalendarState extends State<WirdHistoryCalendar> {
  late DateTime _month = DateTime(widget.state.today.year, widget.state.today.month);

  bool get _canBack {
    final s = widget.state.plan.startDate;
    return DateTime(s.year, s.month).isBefore(_month);
  }

  bool get _canForward => DateTime(widget.state.today.year, widget.state.today.month).isAfter(_month);

  void _move(int delta) {
    Fx.fire(Sfx.swipe);
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final ml = MaterialLocalizations.of(context);
    final first = ml.firstDayOfWeekIndex; // 0 = Sunday
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final lead = (DateTime(_month.year, _month.month).weekday % 7 - first + 7) % 7;
    final cells = lead + days;
    final rows = (cells / 7).ceil();
    final monthTitle = fmt.localizeDigits(ml.formatMonthYear(_month));
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MadarButton.icon(
                icon: Icons.chevron_left_rounded, // mirrored in RTL
                onPressed: _canBack ? () => _move(-1) : null,
                semanticLabel: l.wirdPrevMonth,
                size: MadarButtonSize.small,
                variant: MadarButtonVariant.ghost,
                sfx: Sfx.swipe,
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: context.motion(MadarMotion.short),
                  child: Text(monthTitle, key: ValueKey(_month), textAlign: TextAlign.center, style: text.titleMedium),
                ),
              ),
              MadarButton.icon(
                icon: Icons.chevron_right_rounded,
                onPressed: _canForward ? () => _move(1) : null,
                semanticLabel: l.wirdNextMonth,
                size: MadarButtonSize.small,
                variant: MadarButtonVariant.ghost,
                sfx: Sfx.swipe,
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(ml.narrowWeekdays[(first + i) % 7], textAlign: TextAlign.center, style: text.labelSmall),
                ),
            ],
          ),
          const SizedBox(height: Space.xs),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < 200) return;
              // Swipe towards the reading start = earlier month.
              final back = rtl ? v < 0 : v > 0;
              if (back && _canBack) _move(-1);
              if (!back && _canForward) _move(1);
            },
            child: AnimatedSwitcher(
              duration: context.motion(MadarMotion.medium),
              child: Column(
                key: ValueKey(_month),
                children: [
                  for (var r = 0; r < rows; r++)
                    Row(
                      children: [
                        for (var c = 0; c < 7; c++)
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final n = r * 7 + c - lead + 1;
                                if (n < 1 || n > days) return const SizedBox(height: 40);
                                return _DayCell(day: DateTime(_month.year, _month.month, n), state: widget.state);
                              },
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Space.m,
            runSpacing: Space.xs,
            children: [
              for (final s in const [
                WirdDayStatus.met,
                WirdDayStatus.partial,
                WirdDayStatus.missed,
                WirdDayStatus.rest,
                WirdDayStatus.paused,
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 12,
                      child: CustomPaint(
                        painter: _DayMark(status: s, tokens: t, legend: true),
                      ),
                    ),
                    const SizedBox(width: Space.xs),
                    Text(wirdDayStatusLabel(l, s), style: text.labelSmall),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.state});

  final DateTime day;
  final WirdPlanState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final record = state.dayOf(day);
    final isToday = CalendarDays.same(day, state.today);
    final future = CalendarDays.between(state.today, day) > 0;
    final status = record?.status;
    final color = switch (status) {
      WirdDayStatus.met => t.textPrimary,
      WirdDayStatus.partial => t.textPrimary,
      WirdDayStatus.missed => t.textSecondary,
      WirdDayStatus.rest => t.textSecondary,
      WirdDayStatus.pending => t.accent,
      WirdDayStatus.paused || null => t.textTertiary,
    };
    final label = status == null
        ? fmt.formatDate(day, style: MadarDateStyle.weekdayDayMonth)
        : l.wirdDayStatusSemantics(
            fmt.formatDate(day, style: MadarDateStyle.weekdayDayMonth),
            wirdDayStatusLabel(l, status),
          );
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        height: 40,
        child: Center(
          child: SizedBox.square(
            dimension: 34,
            child: CustomPaint(
              painter: _DayMark(status: status, tokens: t, today: isToday, progress: record?.progress ?? 0),
              child: Center(
                child: Text(
                  fmt.formatInt(day.day),
                  style: text.labelMedium!.copyWith(
                    color: future ? t.textTertiary.withValues(alpha: 0.6) : color,
                    fontWeight: isToday || status == WirdDayStatus.met ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayMark extends CustomPainter {
  _DayMark({required this.status, required this.tokens, this.today = false, this.progress = 0, this.legend = false});

  final WirdDayStatus? status;
  final MadarTokens tokens;
  final bool today;
  final double progress;
  final bool legend;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tokens;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - (legend ? 0.5 : 1.5);
    final stroke = legend ? 1.2 : 1.6;
    switch (status) {
      case WirdDayStatus.met:
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(colors: [t.success.withValues(alpha: 0.55), t.success.withValues(alpha: 0.28)])
                .createShader(Rect.fromCircle(center: c, radius: r)),
        );
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = t.success,
        );
      case WirdDayStatus.partial:
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = t.warning.withValues(alpha: 0.35),
        );
        final sweep = 2 * math.pi * (legend ? 0.5 : progress.clamp(0.08, 1.0));
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -math.pi / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke + 0.6
            ..strokeCap = StrokeCap.round
            ..color = t.warning,
        );
      case WirdDayStatus.missed:
        if (legend) {
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..color = t.danger.withValues(alpha: 0.6),
          );
        } else {
          canvas.drawCircle(Offset(c.dx, size.height - 2.5), 2, Paint()..color = t.danger.withValues(alpha: 0.75));
        }
      case WirdDayStatus.rest:
        canvas.drawCircle(c, r, Paint()..color = t.accentSoft);
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = t.accent.withValues(alpha: 0.35),
        );
      case WirdDayStatus.paused:
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = t.textTertiary.withValues(alpha: 0.6);
        const dashes = 12;
        for (var i = 0; i < dashes; i++) {
          final a = i * 2 * math.pi / dashes;
          canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, math.pi / dashes, false, p);
        }
      case WirdDayStatus.pending:
        final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
        if (sweep > 0) {
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r),
            -math.pi / 2,
            sweep,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke + 0.6
              ..strokeCap = StrokeCap.round
              ..color = t.accent,
          );
        }
      case null:
        break;
    }
    if (today) {
      canvas.drawCircle(
        c,
        r + 2.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = t.accent.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(_DayMark old) =>
      old.status != status || old.tokens != tokens || old.today != today || old.progress != progress;
}
