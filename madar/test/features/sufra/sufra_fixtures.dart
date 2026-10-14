// Small builders for «السفرة»'s pure engines. Nothing here is a real
// recipe of hers: they are made-up test words, and the app ships none.
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/sufra/sufra.dart';

final today = DateTime(2026, 10, 14);

PantryItem item(
  String name, {
  double? quantity,
  String? unit,
  String? place,
  double? lowAt,
  bool low = false,
  DateTime? expires,
  bool staple = false,
  bool archived = false,
  List<String> aliases = const [],
  String? id,
}) => PantryItem(
  id: id ?? 'p-$name',
  name: name,
  aliases: aliases,
  quantity: quantity,
  unit: unit,
  place: place,
  lowAt: lowAt,
  low: low,
  expires: expires,
  staple: staple,
  archived: archived,
);

RecipeIngredient ing(
  String name, {
  double? quantity,
  String? unit,
  bool optional = false,
  String recipeId = 'r1',
  int sortOrder = 0,
}) => RecipeIngredient(
  id: 'i-$recipeId-$name',
  recipeId: recipeId,
  name: name,
  quantity: quantity,
  unit: unit,
  optional: optional,
  sortOrder: sortOrder,
);

Recipe dish(
  String id,
  String name, {
  List<RecipeIngredient> ingredients = const [],
  List<String> steps = const [],
  int? servings,
  int? minutes,
  List<String> tags = const [],
  bool favorite = false,
  bool archived = false,
  RecipeSource source = RecipeSource.mine,
  String? sourceName,
}) => Recipe(
  id: id,
  name: name,
  ingredients: [for (final i in ingredients) RecipeIngredient(
    id: i.id,
    recipeId: id,
    name: i.name,
    quantity: i.quantity,
    unit: i.unit,
    optional: i.optional,
    note: i.note,
    sortOrder: i.sortOrder,
  )],
  steps: steps,
  servings: servings,
  minutes: minutes,
  tags: tags,
  favorite: favorite,
  archived: archived,
  source: source,
  sourceName: sourceName,
);

CookedMeal cooked(String recipeId, DateTime day, {String name = 'طبخة', bool overrode = false}) =>
    CookedMeal(id: 'c-$recipeId-${day.toIso8601String()}', recipeId: recipeId, name: name, day: day, overrode: overrode);

KitchenRule rule(
  KitchenRuleKind kind,
  String term, {
  String? who,
  bool active = true,
  String? id,
}) => KitchenRule(id: id ?? 'k-$term', kind: kind, term: term, who: who, active: active);

PantryBoard board(List<PantryItem> items, {DateTime? on, int warningDays = 3}) =>
    PantryBoard.of(items, today: on ?? today, warningDays: warningDays);
