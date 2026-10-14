import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/sufra_providers.dart';
import '../../domain/pantry_match.dart';
import '../../domain/recipe.dart';
import '../sufra_actions.dart';
import '../sufra_nav.dart';
import '../sufra_texts.dart';
import '../widgets/sufra_widgets.dart';

/// «طبخاتي» – her dishes, in her own order, with her own tags as a filter
/// and the archive behind a switch. Madar ships none of them.
class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  String? _tag;
  bool _archived = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = SufraPalette.of(context);
    final all = ref.watch(recipesProvider).value ?? const <Recipe>[];
    final tag = _tag;
    final tags = <String>[];
    for (final r in all) {
      for (final x in r.tags) {
        final word = x.trim();
        if (word.isNotEmpty && !tags.contains(word)) tags.add(word);
      }
    }
    final shown = [
      for (final r in all)
        if ((_archived || !r.archived) && (tag == null || r.tags.any((x) => PantryMatcher.sameWord(x, tag)))) r,
    ];
    final live = all.where((r) => !r.archived).length;

    return MadarScaffold(
      title: l.sufraRecipesTitle,
      backdropSeed: 9.3,
      animateBackdrop: widget.animateBackdrop,
      floatingAction: MadarButton.icon(
        key: const ValueKey('sufra.recipes.add'),
        icon: Icons.add_rounded,
        semanticLabel: l.sufraAddRecipe,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
        onPressed: () => SufraActions.addRecipe(context, ref),
      ),
      body: ReorderableGlassList<Recipe>(
        items: shown,
        itemKey: (r) => r.id,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, sufraBottomPadding),
        spacing: Space.s,
        itemBorderRadius: BorderRadius.circular(t.radiusL),
        header: Padding(
          padding: const EdgeInsets.only(bottom: Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nothing above the warm empty state: on a fresh install the
              // screen is the invitation, not a header with a zero on it.
              if (all.isNotEmpty)
                SufraCard(
                  title: l.sufraRecipesTitle,
                  icon: Icons.menu_book_rounded,
                  iconColor: p.ready,
                  seed: 9.3,
                  trailing: SufraPill(label: SufraTexts.of(context).recipesCount(live), color: p.ready, dense: true),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // No explanation here: the warm empty state below says
                      // it when it is needed, and saying it twice reads as
                      // if Madar were insisting.
                      if (all.any((r) => r.archived))
                        Row(
                          children: [
                            Expanded(child: Text(l.sufraShowArchived, style: Theme.of(context).textTheme.labelLarge)),
                            MadarSwitch(
                              key: const ValueKey('sufra.recipes.archivedSwitch'),
                              value: _archived,
                              semanticLabel: l.sufraShowArchived,
                              onChanged: (v) => setState(() => _archived = v),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              if (tags.isNotEmpty) ...[
                SufraSectionTitle(l.sufraTagFilter, icon: Icons.label_outline_rounded),
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    MadarChip(
                      key: const ValueKey('sufra.recipes.tag.all'),
                      label: l.sufraAllTags,
                      selected: tag == null,
                      dense: true,
                      onSelected: (_) => setState(() => _tag = null),
                    ),
                    for (final x in tags)
                      MadarChip(
                        key: ValueKey('sufra.recipes.tag.$x'),
                        label: x,
                        selected: tag != null && PantryMatcher.sameWord(tag, x),
                        dense: true,
                        onSelected: (_) =>
                            setState(() => _tag = tag != null && PantryMatcher.sameWord(tag, x) ? null : x),
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
                  key: const ValueKey('sufra.recipes.empty'),
                  kind: EmptyStateKind.emptyList,
                  title: l.sufraRecipesEmptyTitle,
                  body: l.sufraRecipesEmptyBody,
                  actionLabel: l.sufraAddRecipe,
                  actionIcon: Icons.add_rounded,
                  onAction: () => SufraActions.addRecipe(context, ref),
                ),
              )
            : null,
        onReorder: (order) => unawaited(ref.read(sufraServiceProvider).reorderRecipes([for (final r in order) r.id])),
        itemBuilder: (context, recipe, index, grip) => RecipeTile(recipe: recipe, grip: grip),
      ),
    );
  }
}

/// One dish in the list: what the house says about it today, how many it
/// feeds, how long it takes, and where it came from.
class RecipeTile extends ConsumerWidget {
  const RecipeTile({super.key, required this.recipe, this.grip});

  final Recipe recipe;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = SufraTexts.of(context);
    final p = SufraPalette.of(context);
    final text = Theme.of(context).textTheme;
    final match = ref.watch(recipeMatchProvider(recipe.id));
    final color = match == null ? t.textTertiary : p.verdict(match.verdict);
    final line = [
      if (match != null) tx.verdict(match.verdict),
      ?tx.servings(recipe.servings),
      ?tx.minutes(recipe.minutes),
      if (recipe.archived) l.sufraArchivedLabel,
    ].join(l.commonFactSeparator);

    return ActionableItem(
      key: ValueKey('sufra.recipe.${recipe.id}'),
      semanticLabel: '${recipe.name}, $line',
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => sufraOpenRecipe(context, ref, recipe.id),
      actions: ItemActions(
        onEdit: () => SufraActions.editRecipe(context, ref, recipe),
        onDuplicate: () => SufraActions.duplicateRecipe(context, ref, recipe),
        onDelete: () => SufraActions.deleteRecipe(context, ref, recipe),
        extra: [
          ItemAction(
            icon: recipe.favorite ? Icons.star_rounded : Icons.star_border_rounded,
            label: recipe.favorite ? l.sufraUnfavorite : l.sufraFavorite,
            onSelected: () => SufraActions.toggleFavorite(context, ref, recipe),
          ),
          ItemAction(
            icon: recipe.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            label: recipe.archived ? l.sufraUnarchiveRecipe : l.sufraArchiveRecipe,
            onSelected: () => SufraActions.toggleArchivedRecipe(context, ref, recipe),
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: recipe.favorite ? Icons.star_rounded : Icons.star_border_rounded,
          label: recipe.favorite ? l.sufraUnfavorite : l.sufraFavorite,
          onPressed: () => SufraActions.toggleFavorite(context, ref, recipe),
        ),
        QuickAction(
          icon: recipe.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          label: recipe.archived ? l.sufraUnarchiveRecipe : l.sufraArchiveRecipe,
          onPressed: () => SufraActions.toggleArchivedRecipe(context, ref, recipe),
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.sufraDelete,
          tone: ActionTone.danger,
          onPressed: () => SufraActions.deleteRecipe(context, ref, recipe),
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
                  color: color.withValues(alpha: t.isDark ? 0.14 : 0.10),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Icon(
                  match == null ? Icons.restaurant_rounded : sufraVerdictIcon(match.verdict),
                  size: 18,
                  color: recipe.archived ? t.textTertiary : color,
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
                            recipe.name,
                            style: text.titleSmall?.copyWith(color: recipe.archived ? t.textTertiary : t.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (recipe.favorite) ...[
                          const SizedBox(width: Space.xs),
                          Icon(Icons.star_rounded, size: 14, color: t.gold),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(line, style: text.bodySmall?.copyWith(color: t.textTertiary)),
                    if (recipe.isImported)
                      Text(tx.source(recipe), style: text.labelSmall?.copyWith(color: t.textTertiary)),
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
