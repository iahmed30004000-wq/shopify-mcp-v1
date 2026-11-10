import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../data/wellbeing_providers.dart';
import '../../domain/insights.dart';
import '../../domain/wellbeing_data.dart';
import '../../domain/wellbeing_stats.dart';
import '../wellbeing_screen.dart';
import '../wellbeing_texts.dart';
import '../widgets/wb_palette.dart';
import '../widgets/wb_widgets.dart';

/// Local insights: neutral observations of the user's own numbers, computed
/// on this device (see [InsightEngine]); hidden until there is enough data.
class InsightsTab extends ConsumerWidget {
  const InsightsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final insights = ref.watch(wellbeingInsightsProvider);
    final readiness = ref.watch(insightReadinessProvider);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, wbTabBottomPadding),
      children: [
        StaggerItem(
          index: 0,
          child: WbHint(
            l.wbInsightsIntro(WbTexts.of(context).daysShort(InsightEngine.windowDays)),
            icon: Icons.lock_outline_rounded,
          ),
        ),
        const SizedBox(height: Space.m),
        if (insights.isEmpty)
          StaggerItem(index: 1, child: _NotYet(readiness: readiness))
        else
          for (var i = 0; i < insights.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: StaggerItem(
                index: 1 + i,
                child: InsightCard(insight: insights[i]),
              ),
            ),
        const SizedBox(height: Space.s),
        StaggerItem(index: 8, child: const _Averages()),
      ],
    );
  }
}

class _NotYet extends StatelessWidget {
  const _NotYet({required this.readiness});

  final InsightReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final enough = readiness.daysLogged >= readiness.daysNeeded;
    return WbCard(
      seed: 9.1,
      child: Row(
        children: [
          ProgressRing(
            value: readiness.progress,
            size: 72,
            strokeWidth: 6,
            color: t.gold,
            child: Text(fmt.formatInt(readiness.daysLogged), style: text.titleMedium),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(enough ? l.wbInsightsNoneTitle : l.wbInsightsNotYetTitle, style: text.titleMedium),
                const SizedBox(height: Space.xs),
                Text(
                  enough
                      ? l.wbInsightsNoneBody
                      : fmt.localizeDigits(
                          l.wbInsightsNotYetBody(
                            fmt.formatInt(readiness.daysNeeded),
                            fmt.formatInt(readiness.daysLogged),
                          ),
                        ),
                  style: text.bodySmall?.copyWith(color: t.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One observation: the sentence, a small picture of its numbers and the
/// days it rests on.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight});

  final WellbeingInsight insight;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = WbTexts.of(context);
    final i = insight;
    final (WellMetric a, WellMetric b) = switch (i) {
      SplitInsight s => (s.condition.metric, s.outcome),
      CorrelationInsight c => (c.a, c.b),
    };
    return WbCard(
      seed: 9.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _MetricDot(metric: a),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                child: Icon(Icons.sync_alt_rounded, size: 14, color: t.textTertiary),
              ),
              _MetricDot(metric: b),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(
                  '${tx.metricName(a)} · ${tx.metricName(b)}',
                  style: text.labelMedium?.copyWith(color: t.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Text(tx.insight(i), style: text.bodyLarge?.copyWith(height: 1.6)),
          const SizedBox(height: Space.m),
          switch (i) {
            SplitInsight s => _SplitBars(insight: s),
            CorrelationInsight c => _CorrelationGauge(r: c.r, color: WbPalette.metric(t, c.b)),
          },
          const SizedBox(height: Space.s),
          Text(l.wbInsightBasis(tx.dayCount(i.days)), style: text.labelSmall?.copyWith(color: t.textTertiary)),
          if (i is CorrelationInsight)
            Text(l.wbInsightCorrelationNote, style: text.labelSmall?.copyWith(color: t.textTertiary)),
        ],
      ),
    );
  }
}

class _MetricDot extends StatelessWidget {
  const _MetricDot({required this.metric});

  final WellMetric metric;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = WbPalette.metric(t, metric);
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c,
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)],
      ),
    );
  }
}

class _SplitBars extends StatelessWidget {
  const _SplitBars({required this.insight});

  final SplitInsight insight;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = WbTexts.of(context);
    final m = insight.outcome;
    final color = WbPalette.metric(t, m);
    final top = [insight.meanIn, insight.meanOut, m.max].reduce((a, b) => a > b ? a : b);
    // Both rows share one value column as wide as the longer value at the
    // current text scale ("٤٫٣ من ١٠" lost its "١٠" in a fixed 52 px at
    // 1.3×), so the two bars keep the same track and stay comparable.
    final valueStyle = text.labelMedium?.copyWith(color: t.textPrimary);
    double widthOf(String s) {
      final painter = TextPainter(
        text: TextSpan(text: s, style: valueStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    final valueWidth = [
      52.0,
      widthOf(tx.metricValue(m, insight.meanIn)) + 2,
      widthOf(tx.metricValue(m, insight.meanOut)) + 2,
    ].reduce((a, b) => a > b ? a : b).ceilToDouble();
    Widget bar(String label, double v, bool highlight) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: text.labelSmall?.copyWith(color: t.textSecondary), maxLines: 2),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: v / top),
                  duration: context.motion(MadarMotion.long),
                  curve: MadarMotion.decelerate,
                  builder: (context, f, _) => Container(
                    width: (c.maxWidth * f).clamp(6.0, c.maxWidth),
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: highlight ? color : color.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.s),
          SizedBox(
            width: valueWidth,
            child: Text(tx.metricValue(m, v), textAlign: TextAlign.end, style: valueStyle, maxLines: 1, softWrap: false),
          ),
        ],
      ),
    );
    return Column(
      children: [bar(l.wbInsightThoseDays, insight.meanIn, true), bar(l.wbInsightOtherDays, insight.meanOut, false)],
    );
  }
}

class _CorrelationGauge extends StatelessWidget {
  const _CorrelationGauge({required this.r, required this.color});

  final double r;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final dir = Directionality.of(context);
    // −1 at the reading start, +1 at the end.
    final pos = (r + 1) / 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final x = dir == TextDirection.rtl ? w * (1 - pos) : w * pos;
            return SizedBox(
              height: 18,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 7,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: t.glassBorder.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w / 2 - 0.5,
                    top: 3,
                    child: Container(width: 1, height: 12, color: t.textTertiary),
                  ),
                  Positioned(
                    left: x - 7,
                    top: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: Space.xxs),
        Row(
          children: [
            Text(l.wbCorrelationOpposite, style: text.labelSmall?.copyWith(color: t.textTertiary)),
            const Spacer(),
            Text(l.wbCorrelationNone, style: text.labelSmall?.copyWith(color: t.textTertiary)),
            const Spacer(),
            Text(l.wbCorrelationTogether, style: text.labelSmall?.copyWith(color: t.textTertiary)),
          ],
        ),
      ],
    );
  }
}

/// 30-day averages of the main numbers (plain facts, no judgement).
class _Averages extends ConsumerWidget {
  const _Averages();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = WbTexts.of(context);
    const metrics = [WellMetric.mood, WellMetric.stress, WellMetric.sleep, WellMetric.pain];
    final tiles = <Widget>[];
    for (final m in metrics) {
      final s = ref.watch(wellbeingSeriesProvider((m, 30)));
      final mean = WellbeingStats.mean(s);
      if (mean == null) continue;
      tiles.add(
        StatTile(
          label: tx.metricName(m),
          value: tx.metricValue(m, mean),
          color: WbPalette.metric(t, m),
          caption: tx.dayCount(s.length),
        ),
      );
    }
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l.wbAverages30(tx.daysShort(30))),
        for (var i = 0; i < tiles.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: Space.s),
                Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
              ],
            ),
          ),
      ],
    );
  }
}
