import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../data/body_providers.dart';
import '../body_actions.dart';
import '../body_texts.dart';
import '../widgets/body_charts.dart';
import '../widgets/body_widgets.dart';
import '../widgets/water_card.dart';

/// Water: today's ring with quick amounts, the past week and today's log
/// (tap to edit, swipe or long-press to delete with undo).
class BodyWaterTab extends ConsumerWidget {
  const BodyWaterTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final week = ref.watch(bodyWaterWeekProvider);
    final target = ref.watch(bodyWaterTargetProvider);
    final today = ref.watch(bodyTodayProvider);
    final rows = ref.watch(bodyWaterTodayRowsProvider);
    final logged = week.where((d) => d.ml > 0).toList();
    final average = logged.isEmpty ? 0 : logged.fold<int>(0, (a, d) => a + d.ml) ~/ logged.length;
    var i = 0;
    Widget stagger(Widget child) => StaggerItem(index: i++, child: child);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bodyTabBottomPadding),
      children: [
        stagger(const WaterCard()),
        const SizedBox(height: Space.m),
        stagger(
          BodyCard(
            title: l.bodyWaterWeek,
            icon: Icons.bar_chart_rounded,
            iconColor: p.water,
            seed: 6.6,
            trailing: average == 0
                ? null
                : BodyPill(label: l.bodyWaterAverage(tx.ml(average)), color: p.water, dense: true),
            child: WaterWeekChart(days: week, target: target, today: today),
          ),
        ),
        stagger(BodySectionTitle(l.bodyWaterToday, icon: Icons.format_list_bulleted_rounded)),
        if (rows.isEmpty)
          stagger(BodyHint(l.bodyWaterEmptyToday, icon: Icons.water_drop_outlined, color: t.textTertiary))
        else
          for (final r in rows)
            stagger(
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: WaterTile(row: r),
              ),
            ),
      ],
    );
  }
}

/// One glass of today's log.
class WaterTile extends ConsumerWidget {
  const WaterTile({super.key, required this.row});

  final WaterLogRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    return ActionableItem(
      key: ValueKey('body.water.${row.id}'),
      semanticLabel: '${tx.ml(row.ml)}, ${tx.fmt.formatTime(row.at)}',
      borderRadius: BorderRadius.circular(t.radiusM),
      onTap: () => BodyActions.editWater(context, ref, row),
      actions: ItemActions(
        onEdit: () => BodyActions.editWater(context, ref, row),
        onDelete: () => BodyActions.deleteWater(context, ref, row),
      ),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.bodyDelete,
          tone: ActionTone.danger,
          onPressed: () => BodyActions.deleteWater(context, ref, row),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.m, Space.s + 2),
        borderRadius: BorderRadius.circular(t.radiusM),
        child: Row(
          children: [
            Icon(row.ml >= 500 ? Icons.water_drop_rounded : Icons.local_drink_rounded, color: p.water, size: 20),
            const SizedBox(width: Space.m),
            Expanded(child: Text(tx.ml(row.ml), style: text.titleSmall)),
            Text(tx.fmt.formatTime(row.at), style: text.labelMedium?.copyWith(color: t.textTertiary)),
          ],
        ),
      ),
    );
  }
}
