import 'package:flutter/material.dart';

import '../../../core/design/themes.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../domain/goal_math.dart';
import '../domain/growth_days.dart';
import '../domain/growth_goal.dart';
import '../domain/growth_units.dart';

/// Texts about amounts, rates, dates and pace in the UI language (digits
/// per the user's setting, custom units bidi-isolated).
class GrowthTexts {
  GrowthTexts(this.l, this.fmt);

  factory GrowthTexts.of(BuildContext context) => GrowthTexts(L10n.of(context), MadarFormatter.of(context));

  final L10n l;
  final MadarFormatter fmt;

  static const String _alm = '؜';
  static const String _lrm = '‎';

  static double _tidy(double v) => (v * 100).roundToDouble() / 100;

  /// `1,250` / `١٬٢٥٠`, `2.5` / `٢٫٥`.
  String number(double v) => fmt.formatNumber(_tidy(v));

  /// `+٥` (the sign placed as Arabic text expects it).
  String signed(double v) {
    final n = number(v.abs());
    final s = v < 0 ? '-' : '+';
    if (!fmt.isArabic) return '$s$n';
    return fmt.arabicIndic ? '$_alm$s$n' : '$_lrm$s$n';
  }

  /// `صفحتان`, `١١ صفحة`, `٢٫٥ ساعة`, `12 episodes`, `٤٢`.
  String amount(GrowthUnit unit, double v) {
    final r = _tidy(v);
    final kind = unit.kind;
    if (kind == null) {
      if (unit.isEmpty) return number(r);
      return l.growthAmountCustom(number(r), fmt.isolate(unit.custom!.trim()));
    }
    final whole = (r - r.roundToDouble()).abs() < 1e-9;
    if (whole && r.abs() < 1000) {
      final n = r.round();
      return fmt.localizeDigits(switch (kind) {
        GrowthUnitKind.pages => l.growthUnitPages(n),
        GrowthUnitKind.lessons => l.growthUnitLessons(n),
        GrowthUnitKind.hours => l.growthUnitHours(n),
        GrowthUnitKind.chapters => l.growthUnitChapters(n),
        GrowthUnitKind.courses => l.growthUnitCourses(n),
        GrowthUnitKind.words => l.growthUnitWords(n),
        GrowthUnitKind.books => l.growthUnitBooks(n),
        GrowthUnitKind.lectures => l.growthUnitLectures(n),
        GrowthUnitKind.minutes => l.growthUnitMinutes(n),
        GrowthUnitKind.articles => l.growthUnitArticles(n),
      });
    }
    final s = number(r);
    return switch (kind) {
      GrowthUnitKind.pages => l.growthUnitPagesDecimal(s),
      GrowthUnitKind.lessons => l.growthUnitLessonsDecimal(s),
      GrowthUnitKind.hours => l.growthUnitHoursDecimal(s),
      GrowthUnitKind.chapters => l.growthUnitChaptersDecimal(s),
      GrowthUnitKind.courses => l.growthUnitCoursesDecimal(s),
      GrowthUnitKind.words => l.growthUnitWordsDecimal(s),
      GrowthUnitKind.books => l.growthUnitBooksDecimal(s),
      GrowthUnitKind.lectures => l.growthUnitLecturesDecimal(s),
      GrowthUnitKind.minutes => l.growthUnitMinutesDecimal(s),
      GrowthUnitKind.articles => l.growthUnitArticlesDecimal(s),
    };
  }

  /// [v] rounded to the unit's granularity (whole pages, tenths of an
  /// hour), e.g. how far ahead of plan.
  String approx(GrowthUnit unit, double v) {
    final g = unit.countable ? 1.0 : unit.granularity;
    return amount(unit, (v / g).roundToDouble() * g);
  }

  /// The unit on its own: `صفحات`, or the user's text.
  String unitName(GrowthUnit unit) => switch (unit.kind) {
    GrowthUnitKind.pages => l.growthUnitPagesName,
    GrowthUnitKind.lessons => l.growthUnitLessonsName,
    GrowthUnitKind.hours => l.growthUnitHoursName,
    GrowthUnitKind.chapters => l.growthUnitChaptersName,
    GrowthUnitKind.courses => l.growthUnitCoursesName,
    GrowthUnitKind.words => l.growthUnitWordsName,
    GrowthUnitKind.books => l.growthUnitBooksName,
    GrowthUnitKind.lectures => l.growthUnitLecturesName,
    GrowthUnitKind.minutes => l.growthUnitMinutesName,
    GrowthUnitKind.articles => l.growthUnitArticlesName,
    null => unit.custom!.trim(),
  };

  /// `١٢ صفحة يوميًا`, or `٣ صفحات أسبوعيًا` below one a day; [needed]
  /// rounds up.
  String rate(GrowthUnit unit, double perDay, {bool needed = false}) {
    final r = GrowthRate.of(perDay, unit, roundUp: needed);
    final a = amount(unit, r.amount);
    return r.perWeek ? l.growthRatePerWeek(a) : l.growthRatePerDay(a);
  }

  /// [perDay] as a weekly rate: `٣٥ صفحة أسبوعيًا`.
  String weekly(GrowthUnit unit, double perDay, {bool needed = false}) {
    final g = unit.countable ? 1.0 : unit.granularity;
    final week = perDay * 7 / g;
    final v = (needed ? (week - 1e-9).ceilToDouble() : week.roundToDouble()) * g;
    return l.growthRatePerWeek(amount(unit, v));
  }

  String days(int n) => fmt.localizeDigits(l.growthDays(n));

  String percent(double fraction) => fmt.formatPercent(fraction);

  /// `٣٠ نوفمبر` (with the year when it is not [today]'s).
  String date(DateTime d, {DateTime? today}) =>
      fmt.formatDate(d, style: today != null && d.year != today.year ? MadarDateStyle.medium : MadarDateStyle.dayMonth);

  /// `اليوم`, `أمس` or `الأحد ٢٧ سبتمبر`.
  String dayLabel(DateTime day, DateTime today) {
    final diff = GrowthDays.between(day, today);
    if (diff == 0) return l.growthToday;
    if (diff == 1) return l.growthYesterday;
    return fmt.formatDate(day, style: MadarDateStyle.weekdayDayMonth);
  }

  /// `١٢٠ من ٣٠٠ صفحة`.
  String progressOf(GrowthGoal g) => l.growthProgressOf(number(g.stats.current), amount(g.unit, g.row.target));

  String paceLabel(GoalPace p) => switch (p) {
    GoalPace.completed => l.growthPaceCompleted,
    GoalPace.paused => l.growthPacePaused,
    GoalPace.notStarted => l.growthPaceNotStarted,
    GoalPace.noDeadline => l.growthPaceNoDeadline,
    GoalPace.ahead => l.growthPaceAhead,
    GoalPace.onTrack => l.growthPaceOnTrack,
    GoalPace.behind => l.growthPaceBehind,
    GoalPace.overdue => l.growthPaceOverdue,
  };

  /// The one-line summary of where a goal stands (tiles and the card).
  String paceLine(GrowthGoal g) {
    final s = g.stats;
    final u = g.unit;
    final today = s.today;
    final deadline = s.deadline;
    switch (s.pace) {
      case GoalPace.completed:
        return l.growthLineCompleted(date(s.completedOn ?? today, today: today));
      case GoalPace.paused:
        return l.growthLinePaused;
      case GoalPace.overdue:
        return l.growthLineOverdue(days(s.daysOverdue), amount(u, s.remaining));
      case GoalPace.notStarted:
        if (deadline == null || s.neededPerDay == null) return l.growthLineFirstLog;
        return l.growthLineStart(rate(u, s.neededPerDay!, needed: true), date(deadline, today: today));
      case GoalPace.noDeadline:
        if (s.actualPerDay <= 0) return l.growthLineQuiet;
        final finish = s.projectedFinish;
        return finish == null
            ? l.growthLineOpen(rate(u, s.actualPerDay))
            : l.growthLineOpenFinish(rate(u, s.actualPerDay), date(finish, today: today));
      case GoalPace.ahead:
        if (s.daysLeft == 1) return l.growthLineDueToday(amount(u, s.remaining));
        return l.growthLineAhead(rate(u, s.actualPerDay));
      case GoalPace.onTrack:
      case GoalPace.behind:
        if (s.daysLeft == 1) return l.growthLineDueToday(amount(u, s.remaining));
        return l.growthLineNeed(rate(u, s.neededPerDay!, needed: true), date(deadline!, today: today));
    }
  }

  String semantics(GrowthGoal g) =>
      l.growthGoalSemantics(g.name, '${progressOf(g)} (${percent(g.stats.fraction)})', paceLine(g));
}

/// Colours of the Growth planet's goals and pace states (theme tokens; goal
/// colours kept visible on the light Pearl theme).
abstract final class GrowthColors {
  /// The default goal colour (the Growth planet's green).
  static Color planet(MadarTokens t) => _fit(t, PlanetPalettes.growth.surface);

  /// A goal's colour for rings, lines and dots.
  static Color goal(MadarTokens t, int? argb) => argb == null ? planet(t) : _fit(t, Color(argb));

  /// A lighter partner for gradients.
  static Color glow(MadarTokens t, Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + (t.isDark ? 0.18 : 0.1)).clamp(0.0, 0.85)).toColor();
  }

  /// Pastels would vanish on a light background: deepen them there.
  static Color _fit(MadarTokens t, Color c) {
    if (t.isDark) return c;
    final hsl = HSLColor.fromColor(c);
    if (hsl.lightness <= 0.48) return c;
    return hsl.withLightness(0.44).withSaturation(hsl.saturation.clamp(0.0, 0.72)).toColor();
  }

  static Color pace(MadarTokens t, GoalPace p) => switch (p) {
    GoalPace.completed || GoalPace.ahead || GoalPace.onTrack => t.success,
    GoalPace.behind => t.warning,
    GoalPace.overdue => t.danger,
    GoalPace.notStarted => t.info,
    GoalPace.noDeadline => t.textSecondary,
    GoalPace.paused => t.textTertiary,
  };

  static IconData paceIcon(GoalPace p) => switch (p) {
    GoalPace.completed => Icons.verified_rounded,
    GoalPace.paused => Icons.pause_circle_rounded,
    GoalPace.notStarted => Icons.flag_rounded,
    GoalPace.noDeadline => Icons.all_inclusive_rounded,
    GoalPace.ahead => Icons.rocket_launch_rounded,
    GoalPace.onTrack => Icons.trending_up_rounded,
    GoalPace.behind => Icons.hourglass_bottom_rounded,
    GoalPace.overdue => Icons.error_outline_rounded,
  };

  /// Icons of the known units (goal avatars).
  static IconData unitIcon(GrowthUnit unit) => switch (unit.kind) {
    GrowthUnitKind.pages => Icons.menu_book_rounded,
    GrowthUnitKind.lessons => Icons.school_rounded,
    GrowthUnitKind.hours => Icons.schedule_rounded,
    GrowthUnitKind.chapters => Icons.bookmark_rounded,
    GrowthUnitKind.courses => Icons.workspace_premium_rounded,
    GrowthUnitKind.words => Icons.translate_rounded,
    GrowthUnitKind.books => Icons.local_library_rounded,
    GrowthUnitKind.lectures => Icons.co_present_rounded,
    GrowthUnitKind.minutes => Icons.timer_rounded,
    GrowthUnitKind.articles => Icons.article_rounded,
    null => Icons.spa_rounded,
  };
}
