import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart' show BudgetPeriod;
import 'widget_kind.dart';
import 'widget_links.dart';
import 'widget_snapshot.dart';
import 'widget_texts.dart';

/// The budget period the widget shows, as the builder needs it (mapped from
/// the budget package's `BudgetSpending` by the providers – read-only use of
/// its public API).
@immutable
class WidgetBudget {
  const WidgetBudget({
    required this.period,
    required this.start,
    required this.end,
    required this.plannedMilli,
    required this.spentMilli,
  });

  final BudgetPeriod period;

  /// The period `[start, end)` (local midnights).
  final DateTime start;
  final DateTime end;

  /// Plan and expenses of the period in the base currency (milli-units).
  final int plannedMilli;
  final int spentMilli;

  int get remainingMilli => plannedMilli - spentMilli;
}

/// The budget widget's snapshot (pure): one page per day up to a week ahead
/// (the "days left" line changes at midnight), and when the period ends in
/// that time, the next period's first day (its whole plan left – nothing is
/// booked in it yet).
///
/// Details shown: the amount left in the base currency (or "over by"), the
/// plan, the days left and a bar of what is left. Counts only: the share
/// left as a percentage, the bar and the days – no amounts.
abstract final class BudgetWidgetBuilder {
  static const int horizonDays = 7;

  /// Spent from this share of the plan on, the widget warns (the budget's
  /// own "nearly spent" threshold).
  static const double nearRatio = 0.85;

  static WidgetSnapshot build({
    required DateTime now,
    required WidgetBudget budget,
    required String Function(int milli) money,
    required WidgetTexts texts,
    required bool details,
    int horizon = horizonDays,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final pages = <WidgetPage>[];
    var until = DateTime(today.year, today.month, today.day + horizon);
    for (var i = 0; i < horizon; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      if (!day.isBefore(budget.end)) {
        // The next period's first day, then the data runs out.
        final next = WidgetBudget(
          period: budget.period,
          start: budget.end,
          end: budget.end,
          plannedMilli: budget.plannedMilli,
          spentMilli: 0,
        );
        pages.add(_page(day, next, _daysLeft(next.period, day), money, texts, details));
        until = DateTime(day.year, day.month, day.day + 1);
        break;
      }
      pages.add(_page(i == 0 ? null : day, budget, _daysBetween(day, budget.end) - 1, money, texts, details));
    }
    return WidgetSnapshot(
      kind: MadarWidgetKind.budget,
      languageCode: texts.languageCode,
      private: !details,
      title: texts.title(MadarWidgetKind.budget),
      until: until,
      stale: texts.stale,
      link: WidgetLinks.budget,
      pages: pages,
    );
  }

  static WidgetPage _page(
    DateTime? from,
    WidgetBudget b,
    int daysLeft,
    String Function(int milli) money,
    WidgetTexts texts,
    bool details,
  ) {
    final l = texts.l;
    if (b.plannedMilli <= 0) return WidgetPage(from: from, empty: l.widgetsBudgetNone);
    final left = b.remainingMilli;
    final over = left < 0;
    final share = (left / b.plannedMilli).clamp(0.0, 1.0);
    final warn = over || b.spentMilli >= b.plannedMilli * nearRatio;
    final days = texts.digits(l.widgetsBudgetDaysLeft(daysLeft < 0 ? 0 : daysLeft));
    final bar = (share * 1000).round();
    if (!details) {
      return WidgetPage(
        from: from,
        headline: texts.fmt.formatPercent(share),
        detail: over
            ? l.widgetsBudgetOver
            : (b.period == BudgetPeriod.weekly ? l.widgetsBudgetLeftWeek : l.widgetsBudgetLeftMonth),
        note: days,
        bar: bar,
        warn: warn,
      );
    }
    return WidgetPage(
      from: from,
      headline: over ? l.widgetsBudgetOverBy(money(-left)) : money(left),
      detail: l.widgetsBudgetOf(money(b.plannedMilli)),
      note: days,
      bar: bar,
      warn: warn,
    );
  }

  /// Days after [day] left in a fresh period starting on [day].
  static int _daysLeft(BudgetPeriod period, DateTime day) {
    final end = period == BudgetPeriod.weekly
        ? DateTime(day.year, day.month, day.day + 7)
        : DateTime(day.year, day.month + 1);
    return _daysBetween(day, end) - 1;
  }

  static int _daysBetween(DateTime a, DateTime b) =>
      (DateTime.utc(b.year, b.month, b.day).millisecondsSinceEpoch -
          DateTime.utc(a.year, a.month, a.day).millisecondsSinceEpoch) ~/
      86400000;
}
