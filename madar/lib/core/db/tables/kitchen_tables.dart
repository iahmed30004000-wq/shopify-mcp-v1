import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'converters.dart';

// ------------------------------------------- «السفرة» · the kitchen (v6) ----
//
// Part 5. The owner named the planet «السفرة» and it is for his wife: he
// gives her the app on her own phone, so this is a normal planet for both
// of them and on her copy it is the one she lives in.
//
// Her words, through him (2026-10-09): «بدو تكون محطوط عندها شو في بالبيت /
// وتعمل طبخات من المكونات الي بالبيت / يوبدلها طبخة بدون تكرار بتلعيارات
// وطريقة التحضير / ويحطلها محددات اذا في طلب خاص».
//
// Five tables, and not one of them holds anything of ours: a fresh install
// is **empty**. No recipe library is bundled, no ingredient dictionary, no
// unit table of the world's cups – every word in here is hers.
//
// **Why the pantry is not the shared list engine (Part 3b).** A list line
// (`record_list_items`) is something you tick once: a title, an optional
// quantity, an optional price, done / not done. A pantry item is **stock**:
// it has a quantity that goes down, a unit the matcher does arithmetic in,
// a place in the house, an expiry day, a low threshold and a "always keep
// this" mark – and it is never "done". Forcing it into a list line would
// mean four columns of meaning hidden in a note, and the matcher reading
// them back out by parsing text. So the pantry is its own table, and the
// **shopping list** that comes out of it is the list engine unchanged
// (`ListHost('pantry', PantryLists.houseId)` for the standing one,
// `ListHost('recipes', recipeId)` for "what is missing for this dish").
//
// **No health, no money.** Nothing here points at `foods`, `conditions`,
// `food_logs` or any money table. A `Food` (Part 4) and a pantry item are
// relatives, not the same thing: one is what he eats and rates against his
// own conditions, the other is what is in the cupboard. The diet tie-in of
// Part 4 is a setting the **owner** turns on, never a column in here.
//
// No tax, VAT, fee or zakat column exists here, and none ever will.

/// One thing that is in the house.
@DataClassName('PantryItemRow')
class PantryItems extends Table with Entity, Ordered {
  /// Her own word («رز»، «زيت»، «بندورة»).
  TextColumn get name => text()();

  /// Her own other names for the same thing («طماطم» for «بندورة»), so a
  /// recipe written with one word still finds it. Only ever hers: Madar
  /// ships no synonyms.
  TextColumn get aliases => text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  /// How much there is, in [unit]. Null means «في» without an amount – and
  /// the matcher treats that as "present, amount unknown" rather than
  /// inventing one.
  RealColumn get quantity => real().nullable()();

  /// Her own unit word («كيلو»، «غرام»، «لتر»، «حبة»، «كوب»). Converted
  /// only where a conversion is certain – see `KitchenUnits`.
  TextColumn get unit => text().nullable()();

  /// Where it is kept, in her words («الفريزر»، «خزانة المونة»).
  TextColumn get place => text().nullable()();

  /// At or below this much (in [unit]) it counts as low. Null = no
  /// threshold, so only [low] and a zero quantity can mark it.
  RealColumn get lowAt => real().nullable()();

  /// She marked it low herself – which works even when she never typed a
  /// quantity («الزيت قرب يخلص»).
  BoolColumn get low => boolean().withDefault(const Constant(false))();

  /// The expiry day (stored zone-free, like every calendar day in Madar).
  DateTimeColumn get expires => dateTime().map(const CalendarDayConverter()).nullable()();

  /// Always keep this in the house: when it finishes it goes on the
  /// shopping list by itself.
  BoolColumn get staple => boolean().withDefault(const Constant(false))();

  TextColumn get note => text().nullable()();

  /// Out of the pickers but kept for history.
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// One dish: hers, or one she imported.
@DataClassName('RecipeRow')
class Recipes extends Table with Entity, Ordered {
  /// Her own name for it («ملوخية»، «مقلوبة دجاج»).
  TextColumn get name => text()();

  /// The method, step by step, in her words – one entry per step.
  TextColumn get steps => text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  /// How many people it feeds (null when she did not say). The matcher
  /// scales the ingredients by it when she cooks for more.
  IntColumn get servings => integer().nullable()();

  /// How long it takes, in minutes (null when she did not say).
  IntColumn get minutes => integer().nullable()();

  /// Her own tags («سريع»، «رمضان»، «للأولاد»).
  TextColumn get tags => text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  /// Photos she added: file paths inside the app's own storage. Never a
  /// URL and never fetched.
  TextColumn get photos => text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  TextColumn get notes => text().nullable()();

  /// Where it came from. Hers by default; an imported one says so.
  TextColumn get source => textEnum<RecipeSource>().withDefault(Constant(RecipeSource.mine.name))();

  /// Who or what it came from, in plain words («خالتي أم محمد»، «خطة مدار
  /// ٢٠٢٦-١٠-١٤»، «كتاب الطبخ»). Shown on an imported dish so she always
  /// knows whose recipe she is cooking.
  TextColumn get sourceName => text().nullable()();

  /// Pinned for the quick picks.
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();

  /// Out of the suggestions but kept (an old dish she stopped cooking).
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// One ingredient line of a recipe.
@DataClassName('RecipeIngredientRow')
class RecipeIngredients extends Table with Entity, Ordered {
  TextColumn get recipeId => text()();

  /// Her own word for it – matched against a pantry item's name or one of
  /// its aliases, folded the way the app's search folds Arabic.
  TextColumn get name => text()();

  /// How much the dish needs, in [unit]. Null = "some", and then having
  /// the thing at all is enough.
  RealColumn get quantity => real().nullable()();

  TextColumn get unit => text().nullable()();

  /// She can cook it without this one (a garnish). An optional ingredient
  /// that is missing never stops a dish.
  BoolColumn get optional => boolean().withDefault(const Constant(false))();

  TextColumn get note => text().nullable()();
}

/// One dish actually cooked, on the day it was cooked. This is the history
/// «بدون تكرار» rests on: a real log, not a guess from a suggestion.
@DataClassName('CookedMealRow')
class CookedMeals extends Table with Entity {
  /// The recipe, or null for something she cooked without one.
  TextColumn get recipeId => text().nullable()();

  /// The dish's name as it should read in the history, so the log survives
  /// renaming or deleting the recipe.
  TextColumn get name => text()();

  /// The day it was cooked (zone-free calendar day).
  DateTimeColumn get day => dateTime().map(const CalendarDayConverter())();

  /// How many it fed (null when she did not say).
  IntColumn get servings => integer().nullable()();

  /// She chose it although the no-repeat window held it back. Kept so the
  /// history is honest about what she decided.
  BoolColumn get overrode => boolean().withDefault(const Constant(false))();

  TextColumn get note => text().nullable()();
}

/// One standing constraint of hers: an allergy, something to avoid, a
/// preference, or a special request from someone at the table.
///
/// **Never a diagnosis and never a dose.** A rule is a word she wrote plus
/// who it is for; Madar holds the word out of the suggestions and says so.
/// It carries no medical meaning of ours and no advice.
@DataClassName('KitchenRuleRow')
class KitchenRules extends Table with Entity, Ordered {
  TextColumn get kind => textEnum<KitchenRuleKind>().withDefault(Constant(KitchenRuleKind.avoid.name))();

  /// The word it is about – an ingredient name or one of her recipe tags
  /// («فول سوداني»، «حار»). Matched folded, like everything else.
  TextColumn get term => text()();

  /// Who it is for, in her words («أحمد»، «الكل»). Shown with the reason a
  /// dish was held back, so she knows why.
  TextColumn get who => text().nullable()();

  TextColumn get note => text().nullable()();

  /// Off while it does not apply (a guest who is not here tonight).
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}
