import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../domain/body_map.dart';
import '../domain/breathing.dart';
import '../domain/insights.dart';
import '../domain/wellbeing_data.dart';

/// Every user-visible wellbeing text that needs numbers, dates or grammar:
/// digits follow the app's digit style, names and numbers are isolated.
class WbTexts {
  const WbTexts(this.l, this.fmt);

  factory WbTexts.of(BuildContext context) => WbTexts(L10n.of(context), context.formatter);

  final L10n l;
  final MadarFormatter fmt;

  String n(num v, {int maxDecimals = 1}) => fmt.formatNumber(v, maxDecimals: maxDecimals);

  String metricName(WellMetric m) => switch (m) {
    WellMetric.mood => l.wbMetricMood,
    WellMetric.stress => l.wbMetricStress,
    WellMetric.anxiety => l.wbMetricAnxiety,
    WellMetric.energy => l.wbMetricEnergy,
    WellMetric.sleep => l.wbMetricSleep,
    WellMetric.caffeine => l.wbMetricCaffeine,
    WellMetric.pain => l.wbMetricPain,
  };

  /// A value with its unit: "6/10", "7.5 h", "3 cups", "4/5".
  String metricValue(WellMetric m, double v) => switch (m) {
    WellMetric.sleep => hours(v),
    WellMetric.caffeine => cups(v.round()),
    WellMetric.mood => l.wbOutOf(n(v), fmt.formatInt(5)),
    _ => l.wbOutOf(n(v), fmt.formatInt(10)),
  };

  /// Chart axis value (no unit).
  String axisValue(WellMetric m, double v) => n(v);

  List<String> get moodLabels => [l.wbMood1, l.wbMood2, l.wbMood3, l.wbMood4, l.wbMood5];

  String moodLabel(int mood) => moodLabels[(mood.clamp(1, 5)) - 1];

  /// A word for a pain score (standard scale anchors, not an assessment).
  String painWord(int score) => switch (score) {
    0 => l.wbPainNone,
    <= 3 => l.wbPainMild,
    <= 6 => l.wbPainModerate,
    <= 9 => l.wbPainSevere,
    _ => l.wbPainWorst,
  };

  String tagKindName(TagKind k) => switch (k) {
    TagKind.painLocation => l.wbTagKindLocations,
    TagKind.painTrigger => l.wbTagKindTriggers,
    TagKind.moodFactor => l.wbTagKindFactors,
    TagKind.habitCategory || TagKind.generic => l.wbTagKindGeneric,
  };

  String hours(double h) => l.wbHours(fmt.isolate(n(h)));

  String cups(int c) => fmt.localizeDigits(l.wbCups(c, fmt.formatInt(c)));

  String daysShort(int d) => fmt.localizeDigits(l.wbDaysRange(d, fmt.formatInt(d)));

  String dayCount(int d) => fmt.localizeDigits(l.wbDayCount(d, fmt.formatInt(d)));

  String time(DateTime t) => fmt.formatTime(t);

  /// "Today", "Yesterday" or "Sunday 27 September".
  String relativeDay(DateTime day, DateTime today) {
    final diff = WbDays.between(day, today);
    if (diff == 0) return l.wbToday;
    if (diff == 1) return l.wbYesterday;
    if (diff > 1 && diff < 7) return DateFormat.EEEE(fmt.languageCode).format(day);
    return fmt.formatDate(day, style: MadarDateStyle.dayMonth);
  }

  /// "Today · 3:45 PM".
  String dayTime(DateTime v, DateTime today) => l.wbDayAtTime(relativeDay(WbDays.dateOf(v), today), time(v));

  String patternName(BreathingPattern p) => p.id == 'box' ? l.wbBreathBox : l.wbBreath478;

  String patternRhythm(BreathingPattern p) =>
      fmt.localizeDigits(p.steps.map((s) => '${s.$2}').join(fmt.isArabic ? '-' : '-'));

  String breathPhase(BreathPhase p) => switch (p) {
    BreathPhase.inhale => l.wbBreathIn,
    BreathPhase.holdIn => l.wbBreathHold,
    BreathPhase.exhale => l.wbBreathOut,
    BreathPhase.holdOut => l.wbBreathRest,
  };

  String region(BodyRegion r) => switch (r) {
    BodyRegion.head => l.dbSeedPainHead,
    BodyRegion.neck => l.dbSeedPainNeck,
    BodyRegion.shoulders => l.dbSeedPainShoulders,
    BodyRegion.chest => l.dbSeedPainChest,
    BodyRegion.abdomen => l.dbSeedPainAbdomen,
    BodyRegion.upperBack => l.dbSeedPainUpperBack,
    BodyRegion.lowerBack => l.dbSeedPainLowerBack,
    BodyRegion.arms => l.dbSeedPainArms,
    BodyRegion.hands => l.dbSeedPainHands,
    BodyRegion.hips => l.dbSeedPainHips,
    BodyRegion.legs => l.wbRegionLegs,
    BodyRegion.knees => l.dbSeedPainKnees,
    BodyRegion.feet => l.dbSeedPainFeet,
  };

  // ------------------------------------------------------------ insights --

  String _metricKey(WellMetric m) => m.name;

  /// "by 2 points" / "by 1.5 hours".
  String _amount(WellMetric m, double diff) {
    final a = (diff.abs() * 10).round() / 10;
    final whole = a == a.roundToDouble();
    if (m.isHours) {
      return whole ? fmt.localizeDigits(l.wbByHours(a.round(), fmt.formatInt(a.round()))) : l.wbByHoursFraction(n(a));
    }
    return whole ? fmt.localizeDigits(l.wbByPoints(a.round(), fmt.formatInt(a.round()))) : l.wbByPointsFraction(n(a));
  }

  String _condition(SplitCondition c, int days) {
    final d = dayCount(days);
    return switch (c.metric) {
      WellMetric.sleep => l.wbWhenSleptUnder(fmt.formatInt(c.threshold.round()), d),
      WellMetric.caffeine => l.wbWhenCaffeineAtLeast(fmt.formatInt(c.threshold.round()), d),
      WellMetric.stress => l.wbWhenStressAtLeast(fmt.formatInt(c.threshold.round()), d),
      _ => l.wbWhenMetricAtLeast(metricName(c.metric), n(c.threshold), d),
    };
  }

  /// A mean as the sentence shows it (one decimal).
  static double _shown(double v) => (v * 10).round() / 10;

  /// The observation as one neutral sentence with its numbers. The gap it
  /// states is the gap between the two means *as printed* (7.5 vs 3.8 is
  /// "3.7 higher", never the unrounded 3.8).
  String insight(WellbeingInsight i) => switch (i) {
    SplitInsight s => l.wbInsightSplit(
      _condition(s.condition, s.daysIn),
      s.higher
          ? l.wbAvgHigher(
              l.wbMetricYour(_metricKey(s.outcome)),
              _amount(s.outcome, _shown(s.meanIn) - _shown(s.meanOut)),
            )
          : l.wbAvgLower(
              l.wbMetricYour(_metricKey(s.outcome)),
              _amount(s.outcome, _shown(s.meanIn) - _shown(s.meanOut)),
            ),
      fmt.isolate(n(s.meanIn)),
      fmt.isolate(n(s.meanOut)),
    ),
    CorrelationInsight c => l.wbInsightCorrelation(
      l.wbWhenHigher(_metricKey(c.a)),
      c.positive ? l.wbThenHigher(_metricKey(c.b)) : l.wbThenLower(_metricKey(c.b)),
      BidiIsolate.ltr(fmt.formatNumber(c.r, decimals: 2)),
      dayCount(c.days),
    ),
  };
}
