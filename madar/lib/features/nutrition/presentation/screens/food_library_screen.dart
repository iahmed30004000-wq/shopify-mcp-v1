import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../body/presentation/widgets/body_widgets.dart';
import '../../data/nutrition_providers.dart';
import '../../domain/food_library.dart';
import '../nutrition_actions.dart';
import '../nutrition_texts.dart';
import '../widgets/nutrition_widgets.dart';

/// His food library: every food he defined once, with his own words on it,
/// his favourites first, the archive behind a switch, and the tag
/// vocabulary as a filter.
class FoodLibraryScreen extends ConsumerStatefulWidget {
  const FoodLibraryScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  ConsumerState<FoodLibraryScreen> createState() => _FoodLibraryScreenState();
}

class _FoodLibraryScreenState extends ConsumerState<FoodLibraryScreen> {
  String? _tag;
  bool _archived = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    final all = ref.watch(nutritionFoodsProvider);
    final tags = ref.watch(nutritionTagsProvider);
    final usage = ref.watch(nutritionUsageProvider);
    final tag = _tag;
    final shown = [
      for (final f in FoodLookup.favoritesFirst(
        [
          for (final f in all)
            if (_archived || !f.archived) f,
        ],
        usage: usage,
        limit: 500,
      ))
        if (tag == null || f.tags.any((x) => FoodLookup.sameWord(x, tag))) f,
      // `favoritesFirst` drops archived rows: add them at the end when the
      // archive is shown, so nothing he kept disappears.
      if (_archived)
        for (final f in all)
          if (f.archived && (tag == null || f.tags.any((x) => FoodLookup.sameWord(x, tag)))) f,
    ];
    final live = all.where((f) => !f.archived).length;

    return MadarScaffold(
      title: l.nutritionLibraryTitle,
      backdropSeed: 7.4,
      animateBackdrop: widget.animateBackdrop,
      floatingAction: MadarButton.icon(
        key: const ValueKey('nutrition.library.fab'),
        icon: Icons.add_rounded,
        semanticLabel: l.nutritionAddFood,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
        onPressed: () => NutritionActions.addFood(context, ref),
      ),
      body: ReorderableGlassList<Food>(
        items: shown,
        itemKey: (f) => f.id,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, nutritionBottomPadding),
        spacing: Space.s,
        itemBorderRadius: BorderRadius.circular(t.radiusL),
        header: Padding(
          padding: const EdgeInsets.only(bottom: Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BodyCard(
                title: l.nutritionLibraryTitle,
                icon: Icons.menu_book_rounded,
                iconColor: p.food,
                seed: 7.4,
                trailing: BodyPill(
                  label: tx.fmt.localizeDigits(l.nutritionFoodsCount(live, tx.fmt.formatInt(live))),
                  color: p.food,
                  dense: true,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.nutritionLibraryEmptyBody,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                    const SizedBox(height: Space.m),
                    Row(
                      children: [
                        Expanded(
                          child: Text(l.nutritionShowArchived, style: Theme.of(context).textTheme.labelLarge),
                        ),
                        MadarSwitch(
                          key: const ValueKey('nutrition.library.archivedSwitch'),
                          value: _archived,
                          semanticLabel: l.nutritionShowArchived,
                          onChanged: (v) => setState(() => _archived = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (tags.isNotEmpty) ...[
                BodySectionTitle(l.nutritionTagsTitle, icon: Icons.label_outline_rounded),
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    MadarChip(
                      key: const ValueKey('nutrition.library.tag.all'),
                      label: l.nutritionAllTags,
                      selected: tag == null,
                      dense: true,
                      onSelected: (_) => setState(() => _tag = null),
                    ),
                    for (final x in tags)
                      MadarChip(
                        key: ValueKey('nutrition.library.tag.$x'),
                        label: x,
                        selected: tag != null && FoodLookup.sameWord(tag, x),
                        dense: true,
                        onSelected: (_) => setState(() => _tag = tag != null && FoodLookup.sameWord(tag, x) ? null : x),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        footer: shown.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: Space.l),
                child: AnimatedEmptyState(
                  key: const ValueKey('nutrition.library.empty'),
                  kind: EmptyStateKind.emptyList,
                  title: tag == null ? l.nutritionLibraryEmptyTitle : l.nutritionLibraryNoMatch,
                  body: tag == null ? l.nutritionLibraryEmptyBody : null,
                  actionLabel: l.nutritionAddFood,
                  actionIcon: Icons.add_rounded,
                  onAction: () => NutritionActions.addFood(context, ref),
                ),
              )
            : null,
        onReorder: (order) => ref.read(nutritionServiceProvider).reorderFoods([for (final f in order) f.id]),
        itemBuilder: (context, food, index, grip) => FoodTile(food: food, grip: grip),
      ),
    );
  }
}

/// One food of the library.
class FoodTile extends ConsumerWidget {
  const FoodTile({super.key, required this.food, this.grip});

  final Food food;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    final text = Theme.of(context).textTheme;
    final count = ref.watch(nutritionUsageProvider)[food.id] ?? 0;
    final portion = tx.portion(food.defaultPortion, food.unit);
    final line = [
      ?portion,
      tx.fmt.localizeDigits(l.nutritionLoggedCount(count, tx.fmt.formatInt(count))),
    ].join(tx.sep);
    return ActionableItem(
      key: ValueKey('nutrition.food.${food.id}'),
      semanticLabel: '${food.name}, $line${food.archived ? ', ${l.nutritionArchivedLabel}' : ''}',
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => NutritionActions.editFood(context, ref, food),
      actions: ItemActions(
        onEdit: () => NutritionActions.editFood(context, ref, food),
        onDelete: () => NutritionActions.deleteFood(context, ref, food),
        extra: [
          ItemAction(
            icon: food.favorite ? Icons.star_rounded : Icons.star_border_rounded,
            label: food.favorite ? l.nutritionUnfavorite : l.nutritionFavorite,
            onSelected: () => NutritionActions.toggleFavorite(context, ref, food),
          ),
          ItemAction(
            icon: food.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            label: food.archived ? l.nutritionUnarchive : l.nutritionArchive,
            onSelected: () => NutritionActions.toggleArchived(context, ref, food),
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: food.favorite ? Icons.star_rounded : Icons.star_border_rounded,
          label: food.favorite ? l.nutritionUnfavorite : l.nutritionFavorite,
          onPressed: () => NutritionActions.toggleFavorite(context, ref, food),
        ),
        QuickAction(
          icon: food.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          label: food.archived ? l.nutritionUnarchive : l.nutritionArchive,
          onPressed: () => NutritionActions.toggleArchived(context, ref, food),
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.nutritionDelete,
          tone: ActionTone.danger,
          onPressed: () => NutritionActions.deleteFood(context, ref, food),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.xs, Space.m),
        borderRadius: BorderRadius.circular(t.radiusL),
        child: ExcludeSemantics(
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.food.withValues(alpha: t.isDark ? 0.14 : 0.10),
                  border: Border.all(color: p.food.withValues(alpha: 0.45)),
                ),
                child: Icon(
                  food.favorite ? Icons.star_rounded : Icons.restaurant_rounded,
                  size: 18,
                  color: food.archived ? t.textTertiary : p.food,
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            food.name,
                            style: text.titleSmall?.copyWith(color: food.archived ? t.textTertiary : t.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (food.archived) ...[
                          const SizedBox(width: Space.s),
                          BodyPill(label: l.nutritionArchivedLabel, color: t.textTertiary, dense: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(line, style: text.bodySmall?.copyWith(color: t.textTertiary)),
                    if (food.tags.isNotEmpty) ...[
                      const SizedBox(height: Space.xs),
                      Wrap(
                        spacing: Space.xs,
                        runSpacing: Space.xs,
                        children: [
                          for (final x in food.tags) BodyPill(label: x, color: p.condition, dense: true),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              ?grip,
            ],
          ),
        ),
      ),
    );
  }
}
