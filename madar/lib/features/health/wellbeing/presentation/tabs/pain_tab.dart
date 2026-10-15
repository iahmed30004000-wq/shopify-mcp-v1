import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/database.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/wellbeing_providers.dart';
import '../../domain/body_map.dart';
import '../../domain/wellbeing_data.dart';
import '../sheets/pain_log_sheet.dart';
import '../sheets/tag_manager_sheet.dart';
import '../wellbeing_actions.dart';
import '../wellbeing_screen.dart';
import '../wellbeing_texts.dart';
import '../widgets/body_map.dart';
import '../widgets/scale_inputs.dart';
import '../widgets/wb_charts.dart';
import '../widgets/wb_palette.dart';
import '../widgets/wb_widgets.dart';

/// Pain: a quick 0–10 log, the daily highest / mean chart (14, 30 or 90
/// days), where it hurt on the body map, the most frequent triggers and
/// locations, and the history.
class PainTab extends ConsumerStatefulWidget {
  const PainTab({super.key});

  @override
  ConsumerState<PainTab> createState() => _PainTabState();
}

class _PainTabState extends ConsumerState<PainTab> {
  int _days = 30;
  int _quick = 3;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final tx = WbTexts.of(context);
    final today = ref.watch(wellbeingTodayProvider);
    final summary = ref.watch(painSummaryProvider(_days));
    final entries = ref.watch(painEntriesProvider).value ?? const <PainEntryRow>[];
    final shown = _showAll ? entries : entries.take(10).toList();
    final painColor = WbPalette.pain(t, 7);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, wbTabBottomPadding),
      children: [
        StaggerItem(
          index: 0,
          child: WbCard(
            title: l.wbPainNowQuestion,
            icon: Icons.healing_rounded,
            seed: 1.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PainScoreSlider(
                  value: _quick,
                  label: l.wbPainScore,
                  caption: tx.painWord(_quick),
                  onChanged: (v) => setState(() => _quick = v),
                ),
                const SizedBox(height: Space.m),
                Row(
                  children: [
                    Expanded(
                      child: MadarButton(
                        label: l.wbQuickLog,
                        icon: Icons.check_rounded,
                        sfx: Sfx.tap,
                        onPressed: () => WellbeingActions.quickPain(context, ref, _quick),
                      ),
                    ),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: MadarButton(
                        label: l.wbWithDetails,
                        icon: Icons.accessibility_new_rounded,
                        variant: MadarButtonVariant.secondary,
                        sfx: Sfx.sheetOpen,
                        onPressed: () => showPainLogSheet(context, initialScore: _quick),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.m),
        StaggerItem(
          index: 1,
          child: WbCard(
            title: l.wbPainOverTime,
            icon: Icons.show_chart_rounded,
            seed: 2.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WbRangePills(values: const [14, 30, 90], value: _days, onChanged: (d) => setState(() => _days = d)),
                const SizedBox(height: Space.s),
                if (summary.days.length < 2)
                  SizedBox(
                    height: 120,
                    child: Center(child: WbHint(l.wbPainChartEmpty, icon: Icons.show_chart_rounded)),
                  )
                else ...[
                  WbLineChart(
                    series: [for (final d in summary.days) MetricPoint(d.day, d.max.toDouble())],
                    secondary: [for (final d in summary.days) MetricPoint(d.day, d.mean)],
                    secondaryColor: t.textSecondary,
                    from: summary.from,
                    to: summary.to,
                    minY: 0,
                    maxY: 10,
                    color: painColor,
                    semanticLabel: l.wbChartSemantics(l.wbMetricPain, tx.daysShort(_days)),
                  ),
                  const SizedBox(height: Space.s),
                  Wrap(
                    spacing: Space.l,
                    runSpacing: Space.xs,
                    children: [
                      _Legend(color: painColor, label: l.wbPainDailyMax),
                      _Legend(color: t.textSecondary, label: l.wbPainDailyMean, dashed: true),
                    ],
                  ),
                ],
                if (!summary.isEmpty) ...[
                  const SizedBox(height: Space.m),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: l.wbPainAvgMax,
                          value: fmt.formatNumber(summary.meanOfDailyMax!, maxDecimals: 1),
                          unit: l.wbOutOfMax(fmt.formatInt(10)),
                          color: painColor,
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      Expanded(
                        child: StatTile(
                          label: l.wbPainPeak,
                          value: fmt.formatInt(summary.peak!),
                          unit: l.wbOutOfMax(fmt.formatInt(10)),
                          color: WbPalette.pain(t, summary.peak!),
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      Expanded(
                        child: StatTile(
                          label: l.wbPainDaysLogged,
                          value: fmt.formatInt(summary.days.length),
                          unit: l.wbOutOfMax(fmt.formatInt(_days)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.m),
        StaggerItem(
          index: 2,
          child: WbCard(
            title: l.wbWhereItHurt,
            icon: Icons.accessibility_new_rounded,
            seed: 3.1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (summary.heat.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.s),
                    child: WbHint(l.wbHeatEmpty, icon: Icons.touch_app_outlined),
                  ),
                BodyMapView(
                  heat: summary.heat,
                  height: 250,
                  frontLabel: l.wbFront,
                  backLabel: l.wbBack,
                  semanticLabel: _heatSemantics(l, tx, summary.heat),
                ),
                if (summary.heat.isNotEmpty) ...[const SizedBox(height: Space.s), _HeatLegend()],
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.m),
        StaggerItem(
          index: 3,
          child: WbCard(
            title: l.wbTriggersFrequent,
            icon: Icons.bolt_outlined,
            seed: 4.2,
            trailing: MadarButton.icon(
              icon: Icons.tune_rounded,
              semanticLabel: l.wbManageTriggers,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              sfx: Sfx.sheetOpen,
              onPressed: () => showTagManagerSheet(context, TagKind.painTrigger),
            ),
            child: summary.triggers.isEmpty
                ? WbHint(l.wbTriggersEmpty)
                : WbFrequencyBars(
                    items: summary.triggers,
                    color: WbPalette.pain(t, 5),
                    countLabel: (n) => fmt.localizeDigits(l.wbTimes(n, fmt.formatInt(n))),
                  ),
          ),
        ),
        const SizedBox(height: Space.m),
        StaggerItem(
          index: 4,
          child: WbCard(
            title: l.wbLocationsFrequent,
            icon: Icons.place_outlined,
            seed: 5.3,
            trailing: MadarButton.icon(
              icon: Icons.tune_rounded,
              semanticLabel: l.wbManageLocations,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              sfx: Sfx.sheetOpen,
              onPressed: () => showTagManagerSheet(context, TagKind.painLocation),
            ),
            child: summary.locations.isEmpty
                ? WbHint(l.wbLocationsEmpty)
                : WbFrequencyBars(
                    items: summary.locations,
                    color: t.info,
                    countLabel: (n) => fmt.localizeDigits(l.wbTimes(n, fmt.formatInt(n))),
                  ),
          ),
        ),
        const SizedBox(height: Space.l),
        SectionHeader(
          title: l.wbHistoryPain,
          actionLabel: entries.length > 10 ? (_showAll ? l.wbShowLess : l.wbShowAll) : null,
          onAction: () => setState(() => _showAll = !_showAll),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.m),
            child: WbHint(l.wbPainHistoryEmpty),
          )
        else
          for (var i = 0; i < shown.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: StaggerItem(
                index: 5 + i,
                child: PainTile(entry: shown[i], today: today),
              ),
            ),
      ],
    );
  }

  static String _heatSemantics(L10n l, WbTexts tx, List<HeatSpot> heat) {
    if (heat.isEmpty) return l.wbHeatEmpty;
    final names = <String>[];
    for (final h in heat.take(4)) {
      final r = BodyFigure.regionAt(h.x, h.y, h.side);
      if (r != null && !names.contains(tx.region(r))) names.add(tx.region(r));
    }
    return l.wbHeatSemantics(names.join(l.wbListSeparator));
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.dashed = false});

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 18, height: 8, child: CustomPaint(painter: _LegendLine(color, dashed))),
        const SizedBox(width: Space.xs),
        Text(label, style: text.labelSmall?.copyWith(color: t.textSecondary)),
      ],
    );
  }
}

class _LegendLine extends CustomPainter {
  _LegendLine(this.color, this.dashed);

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = dashed ? 1.6 : 2.6
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    } else {
      for (var x = 0.0; x < size.width; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), p);
      }
    }
  }

  @override
  bool shouldRepaint(_LegendLine old) => old.color != color || old.dashed != dashed;
}

class _HeatLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(l.wbHeatLess, style: text.labelSmall?.copyWith(color: t.textTertiary)),
        const SizedBox(width: Space.s),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: WbPalette.painScale(t),
              ),
            ),
          ),
        ),
        const SizedBox(width: Space.s),
        Text(l.wbHeatMore, style: text.labelSmall?.copyWith(color: t.textTertiary)),
      ],
    );
  }
}

/// A logged pain entry: tap to edit, long-press / swipe to delete (undo).
class PainTile extends ConsumerWidget {
  const PainTile({super.key, required this.entry, required this.today});

  final PainEntryRow entry;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final tx = WbTexts.of(context);
    final color = WbPalette.pain(t, entry.score);
    final where = [...entry.locations];
    final points = entry.bodyPoints.length;
    return ActionableItem(
      semanticLabel: '${l.wbMetricPain} ${fmt.formatInt(entry.score)}, ${tx.dayTime(entry.at, today)}',
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => showPainLogSheet(context, entry: entry),
      actions: ItemActions(
        onEdit: () => showPainLogSheet(context, entry: entry),
        onDelete: () => WellbeingActions.deletePain(context, ref, entry),
      ),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.wbDelete,
          tone: ActionTone.danger,
          onPressed: () => WellbeingActions.deletePain(context, ref, entry),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.l, Space.m),
        borderRadius: BorderRadius.circular(t.radiusL),
        glow: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.16),
                border: Border.all(color: color, width: 1.6),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10)],
              ),
              child: Text(fmt.formatInt(entry.score), style: text.titleMedium?.copyWith(color: t.textPrimary)),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(tx.painWord(entry.score), style: text.titleSmall)),
                      Text(tx.dayTime(entry.at, today), style: text.labelSmall?.copyWith(color: t.textTertiary)),
                    ],
                  ),
                  if (where.isNotEmpty || points > 0) ...[
                    const SizedBox(height: Space.xxs),
                    Text(
                      [
                        if (where.isNotEmpty) where.join(l.wbListSeparator),
                        if (points > 0) fmt.localizeDigits(l.wbPointsCount(points, fmt.formatInt(points))),
                      ].join(' · '),
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (entry.triggers.isNotEmpty) ...[
                    const SizedBox(height: Space.xs),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        for (final tr in entry.triggers)
                          WbValuePill(label: tr, icon: Icons.bolt_outlined, color: color),
                      ],
                    ),
                  ],
                  if (entry.notes != null) ...[
                    const SizedBox(height: Space.xs),
                    Text(
                      entry.notes!,
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
