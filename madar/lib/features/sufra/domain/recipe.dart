/// Her recipes: ingredients with quantities, the method step by step, how
/// long it takes, how many it feeds, her photos and her own tags.
///
/// Pure Dart (no Flutter, no database). Madar ships **no recipes**: a fresh
/// install is empty and every dish in here is one she wrote or imported.
library;

import 'package:meta/meta.dart';

import '../../../core/domain/enums.dart';
import '../../search/domain/search_text.dart';
import 'kitchen_units.dart';

/// One ingredient line of a dish.
@immutable
class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.recipeId,
    required this.name,
    this.quantity,
    this.unit,
    this.optional = false,
    this.note,
    this.sortOrder = 0,
  });

  final String id;
  final String recipeId;

  /// Her own word, matched against a pantry item's name or alias.
  final String name;

  /// How much the dish needs. Null = "some", and then simply having the
  /// thing is enough.
  final double? quantity;
  final String? unit;

  /// She can cook it without this one.
  final bool optional;
  final String? note;
  final int sortOrder;

  KitchenUnit get kitchenUnit => KitchenUnits.normalize(unit);

  /// The folded word the matcher looks up.
  String get word => SearchText.fold(name);

  /// This line scaled for [factor] servings-worth (1 keeps it as it is).
  /// A line with no quantity stays without one: scaling "some" is still
  /// "some".
  RecipeIngredient scaled(double factor) => factor == 1 || quantity == null
      ? this
      : RecipeIngredient(
          id: id,
          recipeId: recipeId,
          name: name,
          quantity: KitchenUnits.round(quantity! * factor),
          unit: unit,
          optional: optional,
          note: note,
          sortOrder: sortOrder,
        );

  @override
  String toString() => 'RecipeIngredient($name, ${quantity ?? '؟'} ${unit ?? ''}${optional ? ', optional' : ''})';
}

/// One dish (a plain copy of a `recipes` row plus its ingredients).
@immutable
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    this.ingredients = const [],
    this.steps = const [],
    this.servings,
    this.minutes,
    this.tags = const [],
    this.photos = const [],
    this.notes,
    this.source = RecipeSource.mine,
    this.sourceName,
    this.favorite = false,
    this.archived = false,
  });

  final String id;
  final String name;

  /// In her own order.
  final List<RecipeIngredient> ingredients;

  /// The method, one entry per step.
  final List<String> steps;

  /// How many it feeds (null when she did not say).
  final int? servings;

  /// How long it takes in minutes (null when she did not say).
  final int? minutes;
  final List<String> tags;

  /// File paths of the photos she added. Never a URL.
  final List<String> photos;
  final String? notes;

  /// Hers, imported, or arrived through the «خطة مدار» file round trip.
  final RecipeSource source;

  /// Whose it is, in plain words – shown on an imported dish.
  final String? sourceName;
  final bool favorite;
  final bool archived;

  bool get isImported => source != RecipeSource.mine;

  /// Her tags, folded (what a constraint is matched against).
  List<String> get foldedTags => [
    for (final t in tags)
      if (SearchText.fold(t).isNotEmpty) SearchText.fold(t),
  ];

  /// The ingredients she must have (the optional ones never stop a dish).
  List<RecipeIngredient> get required => [
    for (final i in ingredients)
      if (!i.optional) i,
  ];

  /// How much to multiply the ingredients by to feed [people]. Null when
  /// the recipe never said how many it feeds – and then Madar does **not**
  /// scale: it would be inventing the base.
  double? factorFor(int? people) {
    final base = servings;
    if (people == null || base == null || base <= 0 || people <= 0) return null;
    return people / base;
  }

  /// This dish with its ingredients scaled for [people], or unchanged when
  /// [factorFor] cannot say.
  Recipe forPeople(int? people) {
    final factor = factorFor(people);
    if (factor == null || factor == 1) return this;
    return copyWith(
      ingredients: [for (final i in ingredients) i.scaled(factor)],
      servings: people,
    );
  }

  Recipe copyWith({List<RecipeIngredient>? ingredients, int? servings}) => Recipe(
    id: id,
    name: name,
    ingredients: ingredients ?? this.ingredients,
    steps: steps,
    servings: servings ?? this.servings,
    minutes: minutes,
    tags: tags,
    photos: photos,
    notes: notes,
    source: source,
    sourceName: sourceName,
    favorite: favorite,
    archived: archived,
  );

  @override
  String toString() => 'Recipe($id, $name, ${ingredients.length} ingredients)';
}
