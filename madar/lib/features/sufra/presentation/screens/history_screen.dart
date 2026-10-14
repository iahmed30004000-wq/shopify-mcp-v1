import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/sufra_providers.dart';
import '../../domain/no_repeat.dart';
import '../sufra_actions.dart';
import '../sufra_nav.dart';
import '../sufra_texts.dart';
import '../widgets/sufra_widgets.dart';

/// «اللي طبخناه» – the cooked log, newest day first.
///
/// This is the history «بدون تكرار» actually reads: a dish is held back
/// because she cooked it, not because Madar suggested it. A dish she chose
/// although the window held it says so, so the record stays honest.
class CookedHistoryScreen extends ConsumerWidget {
  const CookedHistoryScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = SufraTexts.of(context);
    final p = SufraPalette.of(context);
    final log = ref.watch(cookedLogProvider).value ?? const <CookedMeal>[];
    final rows = {for (final r in ref.watch(cookedRowsProvider).value ?? const <CookedMealRow>[]) r.id: r};
    final counts = NoRepeat.counts(log);

    return MadarScaffold(
      title: l.sufraHistoryTitle,
      backdropSeed: 9.6,
      animateBackdrop: animateBackdrop,
      floatingAction: MadarButton.icon(
        key: const ValueKey('sufra.history.add'),
        icon: Icons.add_rounded,
        semanticLabel: l.sufraCookFreeText,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
        onPressed: () => SufraActions.cookFreeText(context, ref),
      ),
      body: ListView(
        key: const PageStorageKey('sufra.history'),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, sufraBottomPadding),
        children: [
          SufraCard(
            title: l.sufraWindowLabel,
            icon: Icons.history_rounded,
            iconColor: p.pantry,
            seed: 9.6,
            trailing: SufraPill(label: tx.window(ref.watch(noRepeatWindowProvider)), color: p.pantry, dense: true),
            // The warm empty state below says the same sentence; a card
            // that repeats it reads as if Madar were insisting.
            child: log.isEmpty
                ? const SizedBox.shrink()
                : Text(
                    l.sufraHistoryEmptyBody,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                  ),
          ),
          if (log.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.l),
              child: AnimatedEmptyState(
                key: const ValueKey('sufra.history.empty'),
                kind: EmptyStateKind.noData,
                title: l.sufraHistoryEmptyTitle,
                body: l.sufraHistoryEmptyBody,
                actionLabel: l.sufraCookFreeText,
                actionIcon: Icons.add_rounded,
                onAction: () => SufraActions.cookFreeText(context, ref),
              ),
            ),
          for (final meal in log)
            if (rows[meal.id] case final row?)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: CookedTile(meal: meal, row: row, times: counts[meal.recipeId] ?? 1),
              ),
        ],
      ),
    );
  }
}

/// One day she cooked something.
class CookedTile extends ConsumerWidget {
  const CookedTile({super.key, required this.meal, required this.row, required this.times});

  final CookedMeal meal;
  final CookedMealRow row;
  final int times;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = SufraTexts.of(context);
    final p = SufraPalette.of(context);
    final text = Theme.of(context).textTheme;
    final line = [
      tx.fmt.formatDate(meal.day),
      ?tx.servings(meal.servings),
      if (meal.recipeId != null) tx.cookedTimes(times),
      if (meal.overrode) l.sufraCookedAnyway,
    ].join(l.commonFactSeparator);

    return ActionableItem(
      key: ValueKey('sufra.cooked.${meal.id}'),
      semanticLabel: '${meal.name}, $line',
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: meal.recipeId == null ? null : () => sufraOpenRecipe(context, ref, meal.recipeId!),
      actions: ItemActions(onDelete: () => SufraActions.deleteCooked(context, ref, row)),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.sufraDeleteCooked,
          tone: ActionTone.danger,
          onPressed: () => SufraActions.deleteCooked(context, ref, row),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
        borderRadius: BorderRadius.circular(t.radiusL),
        child: ExcludeSemantics(
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.ready.withValues(alpha: t.isDark ? 0.14 : 0.10),
                  border: Border.all(color: p.ready.withValues(alpha: 0.45)),
                ),
                child: Icon(Icons.local_fire_department_rounded, size: 18, color: p.ready),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(meal.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(line, style: text.bodySmall?.copyWith(color: t.textTertiary)),
                    if (meal.note != null && meal.note!.trim().isNotEmpty)
                      Text(meal.note!.trim(), style: text.labelSmall?.copyWith(color: t.textTertiary)),
                  ],
                ),
              ),
              if (meal.recipeId != null) Icon(Icons.chevron_right_rounded, size: 20, color: t.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
