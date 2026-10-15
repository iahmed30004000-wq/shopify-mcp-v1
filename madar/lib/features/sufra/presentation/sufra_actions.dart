import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../data/recipe_photos.dart';
import '../data/sufra_providers.dart';
import '../data/sufra_service.dart';
import '../domain/kitchen_units.dart';
import '../domain/pantry.dart';
import '../domain/pantry_match.dart';
import '../domain/recipe.dart';
import '../domain/sufra_settings.dart';
import 'sufra_texts.dart';

/// Room under a kitchen list for the floating button and the undo toast.
const double sufraBottomPadding = 112;

UndoableAction _undo(String label, SufraUndo undo) => UndoableAction(label: label, undo: undo);

/// Every write «السفرة»'s screens make, with the undo the service handed
/// back and the one sentence that goes with it.
///
/// Nothing in here decides whether a dish can be cooked – that is the pure
/// engine. What it does own is **telling her when a write did nothing**:
/// [useSome] is the one write Madar can refuse, and it says so in her
/// words instead of leaving the screen looking as though it worked.
abstract final class SufraActions {
  // -------------------------------------------------------- what is in the
  // house

  static List<FieldSpec> _itemFields(L10n l, List<String> places) => [
    FieldSpec.text(
      'name',
      l.sufraItemName,
      required: true,
      hint: l.sufraItemNameHint,
      icon: Icons.inventory_2_outlined,
      maxLength: 60,
      autofocus: true,
    ),
    FieldSpec.number('quantity', l.sufraItemQuantity, min: 0, max: 99999, decimals: 2, icon: Icons.numbers_rounded),
    FieldSpec.text('unit', l.sufraItemUnit, hint: l.sufraItemUnitHint, maxLength: 24, icon: Icons.straighten_rounded),
    FieldSpec.multiSelect(
      'place',
      l.sufraItemPlace,
      options: [for (final p in places) SelectOption(id: p, label: p)],
      allowAdd: true,
      maxCount: 1,
      icon: Icons.kitchen_outlined,
    ),
    FieldSpec.date('expires', l.sufraItemExpiry, icon: Icons.event_rounded),
    FieldSpec.number('lowAt', l.sufraItemLowAt, min: 0, max: 99999, decimals: 2, icon: Icons.trending_down_rounded),
    FieldSpec.toggle('low', l.sufraItemLowNow, icon: Icons.trending_down_rounded),
    FieldSpec.toggle('staple', l.sufraItemStaple, icon: Icons.push_pin_outlined),
    FieldSpec.multiSelect('aliases', l.sufraItemAliases, options: const [], allowAdd: true, icon: Icons.sell_outlined),
    FieldSpec.multiline('note', l.sufraItemNote, maxLength: 240),
  ];

  static PantryDraft _itemDraft(Map<String, Object?> v, {bool archived = false}) => PantryDraft(
    name: (v['name'] as String?)?.trim() ?? '',
    aliases: [...?(v['aliases'] as List<String>?)],
    quantity: (v['quantity'] as num?)?.toDouble(),
    unit: v['unit'] as String?,
    place: _firstOf(v['place']),
    lowAt: (v['lowAt'] as num?)?.toDouble(),
    low: v['low'] == true,
    expires: v['expires'] as DateTime?,
    staple: v['staple'] == true,
    note: v['note'] as String?,
    archived: archived,
  );

  static String? _firstOf(Object? value) {
    if (value is! List || value.isEmpty) return null;
    final first = value.first;
    final text = first is String ? first.trim() : '';
    return text.isEmpty ? null : text;
  }

  /// Puts something in the house.
  static Future<void> addItem(BuildContext context, WidgetRef ref, {String? place}) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final v = await showEditSheet(
      context,
      title: l.sufraAddPantryItem,
      icon: Icons.add_shopping_cart_rounded,
      fields: _itemFields(l, _places(ref)),
      initial: {
        'place': ?(place == null ? null : [place]),
      },
    );
    if (v == null) return;
    final draft = _itemDraft(v);
    if (draft.name.isEmpty) return;
    final (row, undo) = await ref.read(sufraServiceProvider).addPantryItem(draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.sufraItemAdded(tx.name(row.name)), undo)));
  }

  /// Edits one item of the house.
  static Future<void> editItem(BuildContext context, WidgetRef ref, PantryItemRow row) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final v = await showEditSheet(
      context,
      title: l.sufraEditPantryItem,
      icon: Icons.edit_rounded,
      fields: _itemFields(l, _places(ref)),
      initial: {
        'name': row.name,
        'aliases': row.aliases,
        'quantity': row.quantity,
        'unit': row.unit,
        'place': [?row.place],
        'expires': row.expires,
        'lowAt': row.lowAt,
        'low': row.low,
        'staple': row.staple,
        'note': row.note,
      },
    );
    if (v == null) return;
    final draft = _itemDraft(v, archived: row.archived);
    if (draft.name.isEmpty) return;
    final undo = await ref.read(sufraServiceProvider).updatePantryItem(row, draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.sufraItemUpdated(tx.name(draft.name)), undo)));
  }

  /// «قلّت» / «رجعت تمام» – works even when she never typed a quantity.
  static Future<UndoableAction?> toggleLow(BuildContext context, WidgetRef ref, PantryItemRow row) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final undo = await ref.read(sufraServiceProvider).setLow(row, !row.low);
    Fx.fire(Sfx.toggleOn);
    return _undo(l.sufraItemUpdated(tx.name(row.name)), undo);
  }

  static Future<UndoableAction?> toggleStaple(BuildContext context, WidgetRef ref, PantryItemRow row) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final undo = await ref.read(sufraServiceProvider).setStaple(row, !row.staple);
    Fx.fire(Sfx.toggleOn);
    return _undo(l.sufraItemUpdated(tx.name(row.name)), undo);
  }

  /// «خلص» – zero left, which is what the matcher reads as missing.
  static Future<UndoableAction?> markOut(BuildContext context, WidgetRef ref, PantryItemRow row) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final undo = await ref.read(sufraServiceProvider).setQuantity(row, 0);
    Fx.fire(Sfx.complete);
    return _undo(l.sufraQuantityChanged(tx.name(row.name)), undo);
  }

  /// «استعملت منها»: takes an amount out of an item.
  ///
  /// `SufraService.useUp` is **silent** when it cannot convert her amount
  /// into the item's own unit, and when she never typed how much there is:
  /// it writes nothing and hands back a no-op undo. So the same two
  /// questions are asked here *before* the write, and she is told which one
  /// it is – «ما قدرت أنقّص الكمية…» – instead of a toast that pretends.
  static Future<void> useSome(BuildContext context, WidgetRef ref, PantryItemRow row) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final v = await showEditSheet(
      context,
      title: l.sufraUsedSome,
      subtitle: row.name,
      icon: Icons.remove_circle_outline_rounded,
      fields: [
        FieldSpec.number(
          'amount',
          l.sufraUsedHowMuch,
          required: true,
          min: 0,
          max: 99999,
          decimals: 2,
          icon: Icons.numbers_rounded,
        ),
        FieldSpec.text('unit', l.sufraItemUnit, hint: l.sufraItemUnitHint, maxLength: 24),
      ],
      initial: {'unit': row.unit},
    );
    if (v == null) return;
    final amount = (v['amount'] as num?)?.toDouble();
    if (amount == null || amount <= 0) return;
    final unit = (v['unit'] as String?)?.trim();
    final refusal = deductionRefusal(l, tx, row, unit);
    if (refusal != null) {
      if (!context.mounted) return;
      Fx.fire(Sfx.error);
      unawaited(showUndoToast(context, UndoableAction(label: refusal, undo: () async {})));
      return;
    }
    final undo = await ref.read(sufraServiceProvider).useUp(row, amount, unit: unit);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.sufraQuantityChanged(tx.name(row.name)), undo)));
  }

  /// Why taking [unit] out of [row] cannot be arithmetic – null when it
  /// can. The two cases are exactly the two silent exits of
  /// `SufraService.useUp`, so the screen can never report a write that did
  /// not happen.
  static String? deductionRefusal(L10n l, SufraTexts tx, PantryItemRow row, String? unit) {
    if (row.quantity == null) return l.sufraCouldNotDeductNoAmount(tx.name(row.name));
    if (unit == null || unit.trim().isEmpty) return null;
    final from = KitchenUnits.normalize(unit);
    final to = KitchenUnits.normalize(row.unit);
    if (KitchenUnits.convert(1, from, to) != null) return null;
    final have = row.unit?.trim();
    return have == null || have.isEmpty
        ? l.sufraCouldNotDeductNoUnit(tx.name(row.name))
        : l.sufraCouldNotDeductUnit(tx.name(row.name), tx.name(have));
  }

  static Future<UndoableAction?> toggleArchivedItem(BuildContext context, WidgetRef ref, PantryItemRow row) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final undo = await ref.read(sufraServiceProvider).setPantryArchived(row, !row.archived);
    Fx.fire(Sfx.toggleOn);
    return _undo(row.archived ? l.sufraItemUpdated(tx.name(row.name)) : l.sufraItemArchived(tx.name(row.name)), undo);
  }

  static Future<UndoableAction?> deleteItem(BuildContext context, WidgetRef ref, PantryItemRow row) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final undo = await ref.read(sufraServiceProvider).deletePantryItem(row);
    Fx.fire(Sfx.delete);
    return _undo(l.sufraItemDeleted(tx.name(row.name)), undo);
  }

  /// Her own words for the places she keeps things in, in the order she
  /// first used them.
  static List<String> _places(WidgetRef ref) {
    final out = <String>[];
    for (final s in ref.read(pantryBoardProvider).stocks) {
      final place = s.item.place?.trim();
      if (place != null && place.isNotEmpty && !out.contains(place)) out.add(place);
    }
    return out;
  }

  // ----------------------------------------------------------- her dishes

  static List<FieldSpec> _recipeFields(L10n l, List<String> tags) => [
    FieldSpec.text(
      'name',
      l.sufraRecipeName,
      required: true,
      hint: l.sufraRecipeNameHint,
      icon: Icons.restaurant_rounded,
      maxLength: 80,
      autofocus: true,
    ),
    FieldSpec.number('servings', l.sufraRecipeServings, min: 1, max: 200, icon: Icons.groups_rounded),
    FieldSpec.number(
      'minutes',
      l.sufraRecipeMinutes,
      min: 1,
      max: 1440,
      unit: l.sufraRecipeMinutesUnit,
      icon: Icons.schedule_rounded,
    ),
    FieldSpec.multiSelect(
      'tags',
      l.sufraRecipeTags,
      options: [for (final t in tags) SelectOption(id: t, label: t)],
      allowAdd: true,
      icon: Icons.label_outline_rounded,
    ),
    FieldSpec.multiline('steps', l.sufraRecipeSteps, hint: l.sufraRecipeStepsHint, maxLength: 4000),
    FieldSpec.text(
      'from',
      l.sufraRecipeFromWho,
      hint: l.sufraRecipeFromWhoHint,
      maxLength: 60,
      icon: Icons.person_outline_rounded,
    ),
    FieldSpec.toggle('favorite', l.sufraRecipeFavoriteField, icon: Icons.star_rounded),
    FieldSpec.multiline('notes', l.sufraRecipeNotes, maxLength: 600),
  ];

  static RecipeDraft _recipeDraft(Map<String, Object?> v, {required Recipe? from}) {
    final who = (v['from'] as String?)?.trim();
    return RecipeDraft(
      name: (v['name'] as String?)?.trim() ?? '',
      steps: _linesOf(v['steps'] as String?),
      servings: (v['servings'] as num?)?.round(),
      minutes: (v['minutes'] as num?)?.round(),
      tags: [...?(v['tags'] as List<String>?)],
      photos: from?.photos ?? const [],
      notes: v['notes'] as String?,
      // Her own dish unless it arrived from somewhere: a dish that came
      // from an answer keeps saying so, whatever she edits on it.
      source: from?.source ?? (who == null || who.isEmpty ? RecipeSource.mine : RecipeSource.imported),
      sourceName: who,
      favorite: v['favorite'] == true,
      archived: from?.archived ?? false,
    );
  }

  static List<String> _linesOf(String? text) => [
    for (final line in (text ?? '').split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  static Future<void> addRecipe(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final v = await showEditSheet(
      context,
      title: l.sufraAddRecipe,
      icon: Icons.restaurant_rounded,
      fields: _recipeFields(l, _tags(ref)),
    );
    if (v == null) return;
    final draft = _recipeDraft(v, from: null);
    if (draft.name.isEmpty) return;
    final (row, undo) = await ref.read(sufraServiceProvider).addRecipe(draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.sufraRecipeAdded(tx.name(row.name)), undo)));
  }

  static Future<void> editRecipe(BuildContext context, WidgetRef ref, Recipe recipe) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final service = ref.read(sufraServiceProvider);
    final row = await service.recipeRow(recipe.id);
    if (row == null || !context.mounted) return;
    final v = await showEditSheet(
      context,
      title: l.sufraEditRecipe,
      icon: Icons.edit_rounded,
      fields: _recipeFields(l, _tags(ref)),
      initial: {
        'name': row.name,
        'servings': row.servings,
        'minutes': row.minutes,
        'tags': row.tags,
        'steps': row.steps.join('\n'),
        'from': row.sourceName,
        'favorite': row.favorite,
        'notes': row.notes,
      },
    );
    if (v == null) return;
    final draft = _recipeDraft(v, from: recipe);
    if (draft.name.isEmpty) return;
    final undo = await service.updateRecipe(row, draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.sufraRecipeUpdated(tx.name(draft.name)), undo)));
  }

  static Future<UndoableAction?> toggleFavorite(BuildContext context, WidgetRef ref, Recipe recipe) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final service = ref.read(sufraServiceProvider);
    final row = await service.recipeRow(recipe.id);
    if (row == null) return null;
    final undo = await service.setRecipeFavorite(row, !row.favorite);
    Fx.fire(Sfx.toggleOn);
    return _undo(l.sufraRecipeUpdated(tx.name(row.name)), undo);
  }

  static Future<UndoableAction?> toggleArchivedRecipe(BuildContext context, WidgetRef ref, Recipe recipe) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final service = ref.read(sufraServiceProvider);
    final row = await service.recipeRow(recipe.id);
    if (row == null) return null;
    final undo = await service.setRecipeArchived(row, !row.archived);
    Fx.fire(Sfx.toggleOn);
    return _undo(l.sufraRecipeUpdated(tx.name(row.name)), undo);
  }

  static Future<UndoableAction?> duplicateRecipe(BuildContext context, WidgetRef ref, Recipe recipe) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final service = ref.read(sufraServiceProvider);
    final row = await service.recipeRow(recipe.id);
    if (row == null) return null;
    final (copy, undo) = await service.duplicateRecipe(row, name: l.sufraCopySuffix(row.name));
    Fx.fire(Sfx.complete);
    return _undo(l.sufraRecipeDuplicated(tx.name(copy.name)), undo);
  }

  /// Deletes a dish – and only once the undo chance has passed does it
  /// delete the photos she added, so undo brings the dish back whole.
  static Future<UndoableAction?> deleteRecipe(BuildContext context, WidgetRef ref, Recipe recipe) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final service = ref.read(sufraServiceProvider);
    final photos = ref.read(recipePhotosProvider);
    final row = await service.recipeRow(recipe.id);
    if (row == null) return null;
    final undo = await service.deleteRecipe(row);
    Fx.fire(Sfx.delete);
    if (!context.mounted) {
      await photos.remove(recipe.photos);
      return null;
    }
    final undone = await showUndoToast(context, _undo(l.sufraRecipeDeleted(tx.name(row.name)), undo));
    if (!undone && recipe.photos.isNotEmpty) await photos.remove(recipe.photos);
    return null;
  }

  static List<String> _tags(WidgetRef ref) {
    final out = <String>[];
    for (final r in ref.read(sufraBoardProvider).recipes) {
      for (final tag in r.tags) {
        final t = tag.trim();
        if (t.isNotEmpty && !out.contains(t)) out.add(t);
      }
    }
    return out;
  }

  // ------------------------------------------------------- the ingredients

  static List<FieldSpec> _ingredientFields(L10n l) => [
    FieldSpec.text(
      'name',
      l.sufraIngredientName,
      required: true,
      hint: l.sufraIngredientNameHint,
      icon: Icons.eco_outlined,
      maxLength: 60,
      autofocus: true,
    ),
    FieldSpec.number('quantity', l.sufraItemQuantity, min: 0, max: 99999, decimals: 2, icon: Icons.numbers_rounded),
    FieldSpec.text('unit', l.sufraItemUnit, hint: l.sufraItemUnitHint, maxLength: 24, icon: Icons.straighten_rounded),
    FieldSpec.toggle('optional', l.sufraIngredientOptional, icon: Icons.help_outline_rounded),
    FieldSpec.multiline('note', l.sufraItemNote, maxLength: 240),
  ];

  static IngredientDraft _ingredientDraft(Map<String, Object?> v) => IngredientDraft(
    name: (v['name'] as String?)?.trim() ?? '',
    quantity: (v['quantity'] as num?)?.toDouble(),
    unit: v['unit'] as String?,
    optional: v['optional'] == true,
    note: v['note'] as String?,
  );

  static Future<void> addIngredient(BuildContext context, WidgetRef ref, String recipeId) async {
    final l = L10n.of(context);
    final v = await showEditSheet(
      context,
      title: l.sufraAddIngredient,
      icon: Icons.add_rounded,
      fields: _ingredientFields(l),
    );
    if (v == null) return;
    final draft = _ingredientDraft(v);
    if (draft.name.isEmpty) return;
    final (_, undo) = await ref.read(sufraServiceProvider).addIngredient(recipeId, draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.sufraRecipeUpdated(SufraTexts.of(context).name(draft.name)), undo)));
  }

  /// Edits one ingredient line. [unit] pre-fills the unit – which is how
  /// «اكتبيها بنفس العيار» works: the pantry item's own unit is already in
  /// the field, so the comparison becomes arithmetic the moment she saves.
  static Future<void> editIngredient(
    BuildContext context,
    WidgetRef ref,
    RecipeIngredient ingredient, {
    String? unit,
  }) async {
    final l = L10n.of(context);
    final service = ref.read(sufraServiceProvider);
    final row = await service.ingredientRow(ingredient.id);
    if (row == null || !context.mounted) return;
    final v = await showEditSheet(
      context,
      title: l.sufraEditIngredient,
      icon: Icons.edit_rounded,
      fields: _ingredientFields(l),
      initial: {
        'name': row.name,
        'quantity': row.quantity,
        'unit': unit ?? row.unit,
        'optional': row.optional,
        'note': row.note,
      },
    );
    if (v == null) return;
    final draft = _ingredientDraft(v);
    if (draft.name.isEmpty) return;
    final undo = await service.updateIngredient(row, draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.sufraRecipeUpdated(SufraTexts.of(context).name(draft.name)), undo)));
  }

  static Future<UndoableAction?> deleteIngredient(
    BuildContext context,
    WidgetRef ref,
    RecipeIngredient ingredient,
  ) async {
    final l = L10n.of(context);
    final isolate = SufraTexts.of(context).name;
    final service = ref.read(sufraServiceProvider);
    final row = await service.ingredientRow(ingredient.id);
    if (row == null) return null;
    final undo = await service.deleteIngredient(row);
    Fx.fire(Sfx.delete);
    return _undo(l.sufraItemDeleted(isolate(row.name)), undo);
  }

  /// «خليها نفس «رز بسمتي»» – the one tap that fixes an ambiguous or a
  /// loose match for good: her ingredient word becomes one of that item's
  /// own names.
  static Future<void> makeAlias(BuildContext context, WidgetRef ref, PantryStock stock, String word) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final text = word.trim();
    if (text.isEmpty) return;
    final service = ref.read(sufraServiceProvider);
    final row = await service.pantryItem(stock.item.id);
    if (row == null) return;
    if (row.aliases.any((a) => PantryMatcher.sameWord(a, text)) || PantryMatcher.sameWord(row.name, text)) return;
    final undo = await service.updatePantryItem(
      row,
      PantryDraft(
        name: row.name,
        aliases: [...row.aliases, text],
        quantity: row.quantity,
        unit: row.unit,
        place: row.place,
        lowAt: row.lowAt,
        low: row.low,
        expires: row.expires,
        staple: row.staple,
        note: row.note,
        archived: row.archived,
      ),
    );
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.sufraAliasAdded(tx.name(text), tx.name(row.name)), undo)));
  }

  // ------------------------------------------------------------ her photos

  /// Picks an image, copies it into Madar's own folder and puts it on the
  /// dish. Every refusal is a sentence, never a silent no-op.
  static Future<void> addPhoto(BuildContext context, WidgetRef ref, Recipe recipe) async {
    final l = L10n.of(context);
    final service = ref.read(sufraServiceProvider);
    final result = await ref.read(recipePhotosProvider).pickAndImport();
    if (!context.mounted) return;
    if (!result.ok) {
      final error = result.error!;
      if (error == PhotoError.cancelled) return;
      Fx.fire(Sfx.error);
      final message = switch (error) {
        PhotoError.unsupported => l.sufraPhotoWrongKind,
        PhotoError.tooLarge => l.sufraPhotoTooBig,
        PhotoError.unreadable || PhotoError.cancelled => l.sufraPhotoFailed,
      };
      unawaited(showUndoToast(context, UndoableAction(label: message, undo: () async {})));
      return;
    }
    final row = await service.recipeRow(recipe.id);
    if (row == null || !context.mounted) {
      await ref.read(recipePhotosProvider).remove([result.fileName!]);
      return;
    }
    final undo = await service.setPhotos(row, [...row.photos, result.fileName!]);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    final photos = ref.read(recipePhotosProvider);
    final undone = await showUndoToast(context, _undo(l.sufraPhotoAdded, undo));
    if (undone) await photos.remove([result.fileName!]);
  }

  /// Takes one photo off the dish, and deletes the file once the undo
  /// chance has passed.
  static Future<void> removePhoto(BuildContext context, WidgetRef ref, Recipe recipe, String photo) async {
    final l = L10n.of(context);
    final service = ref.read(sufraServiceProvider);
    final photos = ref.read(recipePhotosProvider);
    final row = await service.recipeRow(recipe.id);
    if (row == null) return;
    final undo = await service.setPhotos(row, [
      for (final p in row.photos)
        if (p != photo) p,
    ]);
    if (!context.mounted) {
      await photos.remove([photo]);
      return;
    }
    Fx.fire(Sfx.delete);
    final undone = await showUndoToast(context, _undo(l.sufraPhotoRemoved, undo));
    if (!undone) await photos.remove([photo]);
  }

  // ----------------------------------------------------------- the cooking

  /// One tap: records the dish and takes out of the pantry **only** what
  /// could be compared with certainty (`cookFromMatch`). What it could not
  /// compare it leaves exactly as it was.
  static Future<void> cook(BuildContext context, WidgetRef ref, RecipeMatch match) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final deducted = match.checks.any(
      (c) => c.stock != null && c.comparison != null && c.comparison!.isKnown && c.ingredient.quantity != null,
    );
    final (row, undo) = await ref.read(sufraServiceProvider).cookFromMatch(match);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(
      showUndoToast(
        context,
        _undo(deducted ? l.sufraCookedAndTook(tx.name(row.name)) : l.sufraCookedToast(tx.name(row.name)), undo),
      ),
    );
  }

  /// Something she cooked without a recipe.
  static Future<void> cookFreeText(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final v = await showEditSheet(
      context,
      title: l.sufraCookFreeText,
      icon: Icons.soup_kitchen_outlined,
      fields: [
        FieldSpec.text(
          'name',
          l.sufraFreeTextName,
          required: true,
          hint: l.sufraFreeTextHint,
          maxLength: 80,
          autofocus: true,
          icon: Icons.restaurant_rounded,
        ),
        FieldSpec.date('day', l.sufraCookedDay, icon: Icons.event_rounded),
        FieldSpec.multiline('note', l.sufraItemNote, maxLength: 240),
      ],
      initial: {'day': ref.read(sufraTodayProvider)},
    );
    if (v == null) return;
    final name = (v['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return;
    final (row, undo) = await ref
        .read(sufraServiceProvider)
        .cookFreeText(name, day: v['day'] as DateTime?, note: v['note'] as String?);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.sufraCookedToast(tx.name(row.name)), undo)));
  }

  static Future<UndoableAction?> deleteCooked(BuildContext context, WidgetRef ref, CookedMealRow row) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final undo = await ref.read(sufraServiceProvider).deleteCooked(row);
    Fx.fire(Sfx.delete);
    return _undo(l.sufraCookedDeleted(tx.name(row.name)), undo);
  }

  // -------------------------------------------------------- her constraints

  static List<FieldSpec> _ruleFields(L10n l) => [
    FieldSpec.singleSelect(
      'kind',
      l.sufraRuleKindField,
      required: true,
      options: [
        SelectOption(id: KitchenRuleKind.allergy.name, label: l.sufraRuleAllergy, icon: Icons.dangerous_outlined),
        SelectOption(id: KitchenRuleKind.request.name, label: l.sufraRuleRequest, icon: Icons.campaign_outlined),
        SelectOption(id: KitchenRuleKind.avoid.name, label: l.sufraRuleAvoid, icon: Icons.do_not_disturb_on_outlined),
        SelectOption(id: KitchenRuleKind.prefer.name, label: l.sufraRulePrefer, icon: Icons.favorite_outline_rounded),
      ],
    ),
    FieldSpec.text(
      'term',
      l.sufraRuleTerm,
      required: true,
      hint: l.sufraRuleTermHint,
      maxLength: 60,
      autofocus: true,
      icon: Icons.sell_outlined,
    ),
    FieldSpec.text('who', l.sufraRuleWho, hint: l.sufraRuleWhoHint, maxLength: 40, icon: Icons.person_outline_rounded),
    FieldSpec.toggle('active', l.sufraRuleActive, icon: Icons.power_settings_new_rounded),
    FieldSpec.multiline('note', l.sufraRuleNote, maxLength: 240),
  ];

  static KitchenRuleDraft _ruleDraft(Map<String, Object?> v) => KitchenRuleDraft(
    kind: KitchenRuleKind.values.firstWhere((k) => k.name == v['kind'], orElse: () => KitchenRuleKind.avoid),
    term: (v['term'] as String?)?.trim() ?? '',
    who: v['who'] as String?,
    note: v['note'] as String?,
    active: v['active'] != false,
  );

  static Future<void> addRule(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final v = await showEditSheet(
      context,
      title: l.sufraAddRule,
      subtitle: l.sufraRuleHardNote,
      icon: Icons.rule_rounded,
      fields: _ruleFields(l),
      initial: {'kind': KitchenRuleKind.allergy.name, 'active': true},
    );
    if (v == null) return;
    final draft = _ruleDraft(v);
    if (draft.term.isEmpty) return;
    final (_, undo) = await ref.read(sufraServiceProvider).addRule(draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.sufraRuleAdded, undo)));
  }

  static Future<void> editRule(BuildContext context, WidgetRef ref, KitchenRuleRow row) async {
    final l = L10n.of(context);
    final v = await showEditSheet(
      context,
      title: l.sufraEditRule,
      subtitle: l.sufraRuleHardNote,
      icon: Icons.edit_rounded,
      fields: _ruleFields(l),
      initial: {'kind': row.kind.name, 'term': row.term, 'who': row.who, 'active': row.active, 'note': row.note},
    );
    if (v == null) return;
    final draft = _ruleDraft(v);
    if (draft.term.isEmpty) return;
    final undo = await ref.read(sufraServiceProvider).updateRule(row, draft);
    if (!context.mounted) return;
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.sufraRuleUpdated, undo)));
  }

  static Future<UndoableAction?> toggleRule(BuildContext context, WidgetRef ref, KitchenRuleRow row) async {
    final l = L10n.of(context);
    final undo = await ref.read(sufraServiceProvider).setRuleActive(row, !row.active);
    Fx.fire(Sfx.toggleOn);
    return _undo(l.sufraRuleUpdated, undo);
  }

  static Future<UndoableAction?> deleteRule(BuildContext context, WidgetRef ref, KitchenRuleRow row) async {
    final l = L10n.of(context);
    final undo = await ref.read(sufraServiceProvider).deleteRule(row);
    Fx.fire(Sfx.delete);
    return _undo(l.sufraRuleDeleted, undo);
  }

  // ------------------------------------------------------------ her settings

  static Future<void> setSettings(BuildContext context, WidgetRef ref, SufraSettings settings) async {
    final l = L10n.of(context);
    final undo = await ref.read(sufraServiceProvider).setSettings(settings);
    if (!context.mounted) return;
    Fx.fire(Sfx.toggleOn);
    unawaited(showUndoToast(context, _undo(l.sufraSettingsSaved, undo)));
  }

  // -------------------------------------------------------- the shopping list

  /// What is missing for a dish → that dish's own list (Part 3b's engine).
  /// Returns the list it went on, so the screen can offer to open it.
  static Future<String?> missingToList(BuildContext context, WidgetRef ref, RecipeMatch match) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final (list, added, undo) = await ref
        .read(sufraServiceProvider)
        .missingToList(match, listName: tx.recipeListName(match.recipe.name));
    if (!context.mounted) return list.id;
    Fx.fire(added == 0 ? Sfx.tap : Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.sufraAddedToList(added), undo)));
    return list.id;
  }

  /// What is low or finished in the house → the standing list of the house.
  static Future<String?> lowToHouseList(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final (list, added, undo) = await ref.read(sufraServiceProvider).lowToHouseList(listName: tx.houseListName);
    if (!context.mounted) return list.id;
    Fx.fire(added == 0 ? Sfx.tap : Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.sufraAddedToList(added), undo)));
    return list.id;
  }
}
