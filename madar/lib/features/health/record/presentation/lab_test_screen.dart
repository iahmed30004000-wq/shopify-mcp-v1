import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/record_providers.dart';
import '../domain/appointment_plan.dart';
import '../domain/lab_flags.dart';
import '../domain/lab_series.dart';
import 'record_actions.dart';
import 'record_ui.dart';
import 'widgets/lab_bits.dart';
import 'widgets/lab_trend_chart.dart';

/// One lab test: latest result, trend chart with the reference band
/// (3 / 6 / 12 months / all, tap a point for its value), every result.
class LabTestScreen extends ConsumerStatefulWidget {
  const LabTestScreen({
    super.key,
    required this.testId,
    this.initialPeriod = LabPeriod.months12,
    this.animateBackdrop = true,
  });

  final String testId;
  final LabPeriod initialPeriod;
  final bool animateBackdrop;

  @override
  ConsumerState<LabTestScreen> createState() => _LabTestScreenState();
}

class _LabTestScreenState extends ConsumerState<LabTestScreen> {
  late LabPeriod _period = widget.initialPeriod;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final view = ref.watch(labTestViewProvider(widget.testId));
    final actions = RecordActions(context, ref);
    final v = view.value;
    return MadarScaffold(
      title: v?.test.name ?? l.recordTabLabs,
      backdropSeed: 4.9,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        if (v != null)
          MadarButton.icon(
            icon: Icons.edit_outlined,
            onPressed: () => actions.editTest(v.test),
            semanticLabel: l.recordLabEditTest,
            variant: MadarButtonVariant.ghost,
            sfx: Sfx.sheetOpen,
          ),
      ],
      floatingAction: v == null
          ? null
          : MadarButton.icon(
              icon: Icons.add_chart_rounded,
              onPressed: () => actions.addReading(v),
              semanticLabel: l.recordLabAddReading,
              variant: MadarButtonVariant.primary,
              size: MadarButtonSize.large,
              sfx: Sfx.sheetOpen,
            ),
      body: switch (view) {
        AsyncData(value: final v?) => _content(context, v, actions),
        AsyncData() => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noResults, title: l.recordLabTestGone, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }

  Widget _content(BuildContext context, LabTestView v, RecordActions actions) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final texts = context.recordTexts;
    final today = ref.watch(recordTodayProvider);
    final inPeriod = LabSeries.within(v.points, _period, today);
    final selected =
        inPeriod.where((p) => p.id == _selectedId).firstOrNull ?? (inPeriod.isEmpty ? null : inPeriod.last);
    final summary = v.summary;
    final latest = summary?.latest;
    final range = texts.range(v.range, unit: v.test.unit, decimals: v.decimals);
    var i = 0;
    return EntranceChoreo(
      id: 'lab-${v.test.id}',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 110),
        children: [
          StaggerItem(
            index: i++,
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.recordLabLatest, style: text.labelMedium),
                  const SizedBox(height: Space.xs),
                  if (latest == null)
                    Text(l.recordLabNoReadings, style: text.bodyLarge!.copyWith(color: t.textTertiary))
                  else ...[
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Space.m,
                      runSpacing: Space.xs,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              texts.readingValue(latest, decimals: v.decimals),
                              style: MadarTypography.numerals(
                                t,
                                size: latest.isNumeric ? 40 : 30,
                                color: latest.flag.isOutOfRange ? RecordColors.flag(t, latest.flag) : t.textPrimary,
                              ).copyWith(fontWeight: FontWeight.w600, height: 1.15),
                            ),
                            if (latest.isNumeric && v.test.unit != null) ...[
                              const SizedBox(width: Space.s),
                              Text(v.test.unit!, style: text.titleMedium!.copyWith(color: t.textSecondary)),
                            ],
                          ],
                        ),
                        LabFlagChip(flag: latest.flag, full: true),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      [
                        fmt.formatDate(latest.date, style: MadarDateStyle.medium),
                        texts.relativeDay(AppointmentTimeline.daysUntil(latest.date, today)),
                      ].join(l.recordListSeparator),
                      style: text.bodySmall,
                    ),
                    if (summary!.change case final change? when change != 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          l.recordLabChange(
                            BidiIsolate.ltr(
                              '${change > 0 ? '+' : '−'}${texts.number(change.abs(), decimals: v.decimals)}',
                            ),
                          ),
                          style: text.bodySmall!.copyWith(color: t.textTertiary),
                        ),
                      ),
                  ],
                  const SizedBox(height: Space.m),
                  MadarDivider(ornament: false, height: 12, color: t.glassBorder),
                  _Fact(
                    icon: Icons.straighten_rounded,
                    label: l.recordLabRangeLabel,
                    value: range ?? l.recordLabNoRange,
                  ),
                  if (v.test.category != null)
                    _Fact(icon: Icons.folder_outlined, label: l.recordLabCategory, value: v.test.category!),
                  if (v.test.notes != null) _Fact(icon: RecordIcons.notes, label: l.recordNotes, value: v.test.notes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.l),
          if (v.hasNumbers) ...[
            StaggerItem(
              index: i++,
              child: ChoicePills<LabPeriod>.single(
                options: [for (final p in LabPeriod.values) ChoiceOption(value: p, label: texts.labPeriod(p))],
                selected: _period,
                onChanged: (p) => setState(() {
                  if (p != null) _period = p;
                  _selectedId = null;
                }),
                dense: true,
              ),
            ),
            const SizedBox(height: Space.m),
            StaggerItem(
              index: i++,
              child: GlassPanel(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (selected != null) _SelectedPoint(point: selected, view: v),
                    Semantics(
                      label: l.recordLabChartSemantics(
                        v.test.name,
                        inPeriod.where((p) => p.isNumeric).length,
                        fmt.formatInt(inPeriod.where((p) => p.isNumeric).length),
                      ),
                      child: LabTrendChart(
                        points: inPeriod,
                        range: v.range,
                        today: today,
                        from: _period.start(today),
                        decimals: v.decimals,
                        unit: v.test.unit,
                        selectedId: selected?.id,
                        onSelected: (p) => setState(() => _selectedId = p.id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.s),
            Text(l.recordLabMarginNote(texts.margin(v.margin)), style: text.bodySmall!.copyWith(color: t.textTertiary)),
          ],
          SectionHeader(
            title: l.recordLabHistory,
            subtitle: l.recordLabReadingsCount(v.points.length, fmt.formatInt(v.points.length)),
            padding: const EdgeInsetsDirectional.only(top: Space.l, bottom: Space.s),
          ),
          if (v.points.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.l),
              child: Text(
                l.recordLabNoReadingsBody,
                textAlign: TextAlign.center,
                style: text.bodyMedium!.copyWith(color: t.textTertiary),
              ),
            ),
          for (final p in v.points.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: AnimatedReveal(
                key: ValueKey(p.id),
                child: ActionableItem(
                  onTap: () => actions.editReading(v, p),
                  semanticLabel:
                      '${fmt.formatDate(p.date)}: ${texts.reading(p, unit: v.test.unit, decimals: v.decimals)}',
                  actions: ItemActions(
                    onEdit: () => actions.editReading(v, p),
                    onDelete: () => actions.deleteReading(p),
                  ),
                  quickActions: [
                    QuickAction(
                      icon: Icons.delete_outline_rounded,
                      label: l.recordDelete,
                      onPressed: () => actions.deleteReading(p),
                      tone: ActionTone.danger,
                    ),
                  ],
                  child: _ReadingRow(point: p, view: v, selected: p.id == selected?.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: t.textTertiary),
          const SizedBox(width: Space.s),
          Text('$label: ', style: text.bodySmall!.copyWith(color: t.textTertiary)),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

class _SelectedPoint extends StatelessWidget {
  const _SelectedPoint({required this.point, required this.view});

  final LabPoint point;
  final LabTestView view;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final texts = context.recordTexts;
    return AnimatedSwitcher(
      duration: context.motion(MadarMotion.short),
      child: Row(
        key: ValueKey(point.id),
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: RecordColors.dot(t, point.flag)),
          ),
          const SizedBox(width: Space.s),
          Flexible(
            child: Text(
              texts.reading(point, unit: view.test.unit, decimals: view.decimals),
              style: text.titleMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Space.s),
          LabFlagChip(flag: point.flag, dense: true),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(
              fmt.formatDate(point.date, style: MadarDateStyle.medium),
              style: text.bodySmall,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.point, required this.view, this.selected = false});

  final LabPoint point;
  final LabTestView view;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final texts = context.recordTexts;
    final p = point;
    return GlassCard(
      borderColor: selected ? t.accent.withValues(alpha: 0.5) : null,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fmt.formatDate(p.date, style: MadarDateStyle.medium),
                  style: text.titleSmall!.copyWith(color: t.textPrimary),
                ),
                if (p.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(p.note!, style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          Flexible(
            child: Text(
              texts.reading(p, unit: view.test.unit, decimals: view.decimals),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: text.titleMedium!.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: p.flag.isOutOfRange ? RecordColors.flag(t, p.flag) : t.textPrimary,
              ),
            ),
          ),
          if (p.flag.isFlagged) ...[const SizedBox(width: Space.s), LabFlagChip(flag: p.flag, dense: true)],
        ],
      ),
    );
  }
}
