import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/recipe_photos.dart';
import '../../data/sufra_providers.dart';
import '../../domain/pantry_match.dart';
import '../../domain/recipe.dart';
import '../sufra_actions.dart';
import '../sufra_texts.dart';
import '../widgets/sufra_dish.dart';
import '../widgets/sufra_widgets.dart';

/// One dish: what the house says about every ingredient of it, her method
/// step by step, her photos, and where it came from.
///
/// This is where a refusal becomes a fix: an ingredient Madar could not
/// judge carries the one tap that makes the comparison possible – write it
/// in the same measure, say how much there is, or tell Madar that two of
/// her words mean one thing.
class RecipeScreen extends ConsumerWidget {
  const RecipeScreen({super.key, required this.recipeId, this.animateBackdrop = true});

  final String recipeId;
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = SufraTexts.of(context);
    final p = SufraPalette.of(context);
    final text = Theme.of(context).textTheme;
    final recipe = ref.watch(recipeProvider(recipeId)).value;
    if (recipe == null) {
      return MadarScaffold(
        title: l.sufraRecipesTitle,
        animateBackdrop: animateBackdrop,
        body: Center(
          child: AnimatedEmptyState(
            key: const ValueKey('sufra.recipe.gone'),
            kind: EmptyStateKind.noData,
            title: l.sufraRecipeGone,
          ),
        ),
      );
    }
    // A dish a hard rule blocks is not on the board at all (it is not on
    // offer); it is still *hers*, so her own screen shows it with the word
    // and the person behind the refusal.
    final match = ref.watch(recipeMatchProvider(recipeId)) ?? _blocked(ref, recipeId);
    final checks = match?.checks ?? const <IngredientCheck>[];
    final held = match == null ? null : tx.held(match.hold);
    final freeFrom = match == null ? null : tx.freeFrom(match.hold);
    final facts = [
      ?tx.servings(recipe.servings),
      ?tx.minutes(recipe.minutes),
      if (match != null) ?tx.scaledFor(match.scaledFor),
    ].join(l.commonFactSeparator);

    return MadarScaffold(
      title: recipe.name,
      backdropSeed: 9.4,
      animateBackdrop: animateBackdrop,
      actions: [
        MadarButton.icon(
          key: const ValueKey('sufra.recipe.edit'),
          icon: Icons.edit_rounded,
          semanticLabel: l.sufraEditRecipe,
          size: MadarButtonSize.small,
          sfx: Sfx.sheetOpen,
          onPressed: () => SufraActions.editRecipe(context, ref, recipe),
        ),
      ],
      body: ListView(
        key: PageStorageKey('sufra.recipe.$recipeId'),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, sufraBottomPadding),
        children: [
          // What the house says about it today, with the cook tap and the
          // missing-to-list tap – the same card the suggestions screen
          // shows, so one dish reads the same everywhere.
          if (match != null)
            SufraDishCard(match: match, showChecks: false, onOpen: null)
          else
            SufraCard(
              title: recipe.name,
              icon: Icons.restaurant_rounded,
              child: Text(facts, style: text.bodySmall?.copyWith(color: t.textTertiary)),
            ),
          if (held != null) ...[
            const SizedBox(height: Space.s),
            SufraNote([held, ?freeFrom].join(l.commonFactSeparator), icon: Icons.history_rounded),
          ],
          // Her photos, Madar's own copies.
          SufraSectionTitle(
            l.sufraPhotosTitle,
            icon: Icons.photo_camera_outlined,
            trailing: MadarButton(
              key: const ValueKey('sufra.recipe.addPhoto'),
              label: l.sufraAddPhoto,
              icon: Icons.add_a_photo_outlined,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              sfx: Sfx.sheetOpen,
              onPressed: () => SufraActions.addPhoto(context, ref, recipe),
            ),
          ),
          if (recipe.photos.isEmpty)
            SufraCard(child: SufraNote(l.sufraNoPhotos, icon: Icons.photo_camera_outlined))
          else
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recipe.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.s),
                itemBuilder: (context, i) => RecipePhotoTile(recipe: recipe, photo: recipe.photos[i]),
              ),
            ),
          // The ingredients, each judged against the house.
          SufraSectionTitle(
            l.sufraIngredientsTitle,
            icon: Icons.eco_outlined,
            trailing: MadarButton(
              key: const ValueKey('sufra.recipe.addIngredient'),
              label: l.sufraAddIngredient,
              icon: Icons.add_rounded,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              sfx: Sfx.sheetOpen,
              onPressed: () => SufraActions.addIngredient(context, ref, recipe.id),
            ),
          ),
          if (recipe.ingredients.isEmpty)
            SufraCard(child: SufraNote(l.sufraNoIngredients, icon: Icons.info_outline_rounded))
          else
            SufraCard(
              key: const ValueKey('sufra.recipe.ingredients'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The card at the top already says Madar cannot work the
                  // dish out; here each line says which ingredient did it.
                  for (final check in checks)
                    SufraCheckLine(
                      key: ValueKey('sufra.recipe.check.${check.ingredient.id}'),
                      check: check,
                      onFix: (c) => _fix(context, ref, c),
                    ),
                  // No match yet (the board is still loading): her own
                  // lines, without a verdict Madar has not computed.
                  if (checks.isEmpty)
                    for (final i in recipe.ingredients)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.xs),
                        child: Text(
                          [tx.name(i.name), tx.amount(i.quantity, i.unit)].where((s) => s.isNotEmpty).join(' · '),
                          style: text.bodyMedium,
                        ),
                      ),
                  const SizedBox(height: Space.s),
                  Wrap(
                    spacing: Space.s,
                    runSpacing: Space.xs,
                    children: [
                      for (final i in recipe.ingredients)
                        MadarChip(
                          key: ValueKey('sufra.recipe.ingredient.${i.id}'),
                          label: tx.name(i.name),
                          icon: Icons.edit_rounded,
                          dense: true,
                          onSelected: (_) => SufraActions.editIngredient(context, ref, i),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          // Her method, as she wrote it.
          SufraSectionTitle(l.sufraStepsTitle, icon: Icons.format_list_numbered_rounded),
          SufraCard(
            key: const ValueKey('sufra.recipe.steps'),
            child: recipe.steps.isEmpty
                ? SufraNote(l.sufraNoSteps, icon: Icons.info_outline_rounded)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < recipe.steps.length; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: i == recipe.steps.length - 1 ? 0 : Space.m),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                label: l.sufraStepNumber(tx.fmt.formatInt(i + 1)),
                                child: SufraPill(label: tx.fmt.formatInt(i + 1), color: p.pantry, dense: true),
                              ),
                              const SizedBox(width: Space.s),
                              Expanded(child: Text(recipe.steps[i], style: text.bodyMedium)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          if (recipe.notes != null && recipe.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: Space.s),
            SufraCard(child: Text(recipe.notes!.trim(), style: text.bodyMedium)),
          ],
        ],
      ),
    );
  }

  /// The dish's match when a hard rule keeps it off the board.
  static RecipeMatch? _blocked(WidgetRef ref, String recipeId) {
    for (final m in ref.watch(blockedMatchesProvider)) {
      if (m.recipe.id == recipeId) return m;
    }
    return null;
  }

  /// The fix behind a refusal: the unit comes from the pantry item itself
  /// (so saving makes the comparison arithmetic), a missing amount is typed
  /// on the item, and an ambiguous word is settled by an alias – which the
  /// line's own chips do.
  void _fix(BuildContext context, WidgetRef ref, IngredientCheck check) {
    switch (check.verdict) {
      case IngredientVerdict.unknownUnit:
        unawaited(SufraActions.editIngredient(context, ref, check.ingredient, unit: check.stock?.item.unit));
      case IngredientVerdict.unknownAmount:
        final id = check.stock?.item.id;
        if (id == null) return;
        unawaited(_editStock(context, ref, id));
      case IngredientVerdict.ambiguous:
      case IngredientVerdict.have:
      case IngredientVerdict.short:
      case IngredientVerdict.missing:
        break;
    }
  }

  /// Opens the editor of the pantry item behind an ingredient, so she can
  /// type how much there is.
  static Future<void> _editStock(BuildContext context, WidgetRef ref, String itemId) async {
    final row = await ref.read(sufraServiceProvider).pantryItem(itemId);
    if (row == null || !context.mounted) return;
    await SufraActions.editItem(context, ref, row);
  }
}

/// One photo she added: Madar's own copy, resolved from the dish's stored
/// file name. A file that is gone says so instead of showing a broken box.
class RecipePhotoTile extends ConsumerWidget {
  const RecipePhotoTile({super.key, required this.recipe, required this.photo});

  final Recipe recipe;
  final String photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = SufraTexts.of(context);
    return FutureBuilder<File?>(
      future: ref.watch(recipePhotosProvider).fileOf(photo),
      builder: (context, snapshot) {
        final file = snapshot.data;
        return GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(t.radiusM),
          semanticLabel: l.sufraPhotoOf(tx.name(recipe.name)),
          onTap: () => SufraActions.removePhoto(context, ref, recipe, photo),
          child: SizedBox(
            width: 128,
            height: 128,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(t.radiusM),
              child: file == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Space.s),
                        child: Text(
                          snapshot.connectionState == ConnectionState.waiting ? '' : l.sufraPhotoMissing,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.textTertiary),
                        ),
                      ),
                    )
                  : Image.file(file, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          ),
        );
      },
    );
  }
}
