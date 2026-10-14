import 'package:flutter/widgets.dart';

import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../domain/constraints.dart';
import '../domain/no_repeat.dart';
import '../domain/pantry.dart';
import '../domain/pantry_match.dart';
import '../domain/recipe.dart';

/// Every sentence «السفرة» says, in her digits and with her own words
/// bidi-isolated – the same shape `ListTexts` and `NutritionTexts` have.
///
/// This is not UI: it holds no widget. It exists so the screens never
/// invent a sentence the engine did not mean, and so the one sentence that
/// matters most – «ما بعرف أحسب» when a unit cannot be converted – is
/// written once and tested.
@immutable
class SufraTexts {
  const SufraTexts(this.l, this.fmt);

  factory SufraTexts.of(BuildContext context) => SufraTexts(L10n.of(context), MadarFormatter.of(context));

  final L10n l;
  final MadarFormatter fmt;

  /// A word she typed, isolated so its own punctuation stays with it.
  String name(String? text) => BidiIsolate.isolate((text ?? '').trim());

  /// A quantity in her digits, without trailing zeros («١٫٥», «٢»).
  String quantity(double value) => fmt.formatNumber(value, maxDecimals: 3);

  /// «٢ كيلو» – an amount with her own unit word. **Empty when there is no
  /// amount**, which is how a missing-but-unknown amount reads: nothing,
  /// never a number Madar made up.
  String amount(double? value, String? unit) {
    final u = unit?.trim();
    if (value == null) return u == null || u.isEmpty ? '' : BidiIsolate.isolate(u);
    final q = quantity(value);
    return u == null || u.isEmpty ? q : BidiIsolate.isolate(fmt.localizeDigits(l.sufraAmountOf(q, u)));
  }

  /// What the whole dish is, in one line.
  String verdict(MatchVerdict verdict) => switch (verdict) {
    MatchVerdict.cookNow => l.sufraVerdictCookNow,
    MatchVerdict.nearly => l.sufraVerdictNearly,
    MatchVerdict.unsure => l.sufraVerdictUnsure,
    MatchVerdict.far => l.sufraVerdictFar,
  };

  /// «ناقص إشيين».
  String missingCount(int count) => fmt.localizeDigits(l.sufraMissingCount(count));

  /// What one ingredient says – and for the three verdicts Madar is not
  /// sure about, it says so instead of a number.
  String check(IngredientCheck c) {
    final ingredient = name(c.ingredient.name);
    switch (c.verdict) {
      case IngredientVerdict.have:
        return ingredient;
      case IngredientVerdict.missing:
        final needed = amount(c.shortBy, c.shortUnit);
        return needed.isEmpty
            ? fmt.localizeDigits(l.sufraMissingLineNoAmount(ingredient))
            : fmt.localizeDigits(l.sufraMissingLine(needed, ingredient));
      case IngredientVerdict.short:
        final comparison = c.comparison!;
        return fmt.localizeDigits(
          l.sufraShortLine(
            amount(comparison.have, c.shortUnit),
            amount(comparison.need, c.shortUnit),
            ingredient,
          ),
        );
      case IngredientVerdict.unknownUnit:
        return fmt.localizeDigits(
          l.sufraUnknownUnitLine(
            amount(c.ingredient.quantity, c.ingredient.unit),
            ingredient,
            name(c.stock?.item.unit),
          ),
        );
      case IngredientVerdict.unknownAmount:
        return l.sufraUnknownAmountLine(ingredient);
      case IngredientVerdict.ambiguous:
        return l.sufraAmbiguousLine(
          ingredient,
          [for (final s in c.candidates) name(s.item.name)].join(l.recordListSeparator),
        );
    }
  }

  /// «حسبتها من «رز بسمتي»» – shown on a loose match so she can fix it
  /// with an alias.
  String? loose(IngredientCheck c) =>
      c.loose && c.stock != null ? l.sufraLooseMatch(name(c.stock!.item.name)) : null;

  /// How an item in the house stands.
  String state(PantryState state) => switch (state) {
    PantryState.out => l.sufraStateOut,
    PantryState.low => l.sufraStateLow,
    PantryState.expired => l.sufraStateExpired,
    PantryState.expiringSoon => l.sufraStateExpiringSoon,
    PantryState.ok => l.sufraStateOk,
  };

  /// «باقي يومين» / «فات تاريخه من يوم» – null when she gave no date.
  String? expiry(PantryStock stock) {
    final days = stock.daysToExpiry;
    if (days == null) return null;
    return fmt.localizeDigits(days < 0 ? l.sufraExpiredDaysAgo(-days) : l.sufraExpiresInDays(days));
  }

  /// «طبختيها قبل يومين» – null when the window does not hold it.
  String? held(RepeatHold hold) =>
      hold.held && hold.daysAgo != null ? fmt.localizeDigits(l.sufraHeldByWindow(hold.daysAgo!)) : null;

  /// «بترجع بالاقتراحات يوم …» – null when it is not held.
  String? freeFrom(RepeatHold hold) {
    final day = hold.freeFrom;
    return day == null ? null : l.sufraFreeFrom(fmt.formatDate(day));
  }

  /// Why a dish was held back by one of her constraints.
  String breach(ConstraintHit hit) {
    final term = name(hit.term);
    return switch (hit.breach) {
      ConstraintBreach.allergy => hit.who == null
          ? l.sufraBreachAllergyAnyone(term)
          : l.sufraBreachAllergy(term, name(hit.who)),
      ConstraintBreach.request => l.sufraBreachRequest(term),
      ConstraintBreach.avoid => l.sufraBreachAvoid(term),
      ConstraintBreach.tooLong => l.sufraBreachTooLong,
      ConstraintBreach.missingTag => l.sufraBreachMissingTag(term),
      ConstraintBreach.diet => l.sufraBreachDiet(term),
    };
  }

  /// What one of her rules is called.
  String ruleKind(KitchenRuleKind kind) => switch (kind) {
    KitchenRuleKind.allergy => l.sufraRuleAllergy,
    KitchenRuleKind.avoid => l.sufraRuleAvoid,
    KitchenRuleKind.prefer => l.sufraRulePrefer,
    KitchenRuleKind.request => l.sufraRuleRequest,
  };

  /// Where a dish came from – and an imported one always says whose.
  String source(Recipe recipe) {
    final label = switch (recipe.source) {
      RecipeSource.mine => l.sufraSourceMine,
      RecipeSource.imported => l.sufraSourceImported,
      RecipeSource.ai => l.sufraSourceAi,
    };
    final who = recipe.sourceName?.trim();
    return who == null || who.isEmpty ? label : '$label · ${l.sufraSourceFrom(name(who))}';
  }

  /// «تكفي ٥ أشخاص» – null when she did not say.
  String? servings(int? count) => count == null ? null : fmt.localizeDigits(l.sufraServings(count));

  /// «٤٥ دقيقة» – null when she did not say.
  String? minutes(int? count) => count == null ? null : fmt.localizeDigits(l.sufraMinutes(count));

  /// «محسوبة لـ١٢ شخص» – null when nothing was scaled.
  String? scaledFor(int? people) => people == null ? null : fmt.localizeDigits(l.sufraScaledFor(people));

  /// «بتستهلك لبن قبل ما يخلص تاريخه» – the reason to cook it tonight.
  String? usesExpiring(RecipeMatch match) => match.usesExpiring.isEmpty
      ? null
      : l.sufraUsesExpiring([for (final s in match.usesExpiring) name(s.item.name)].join(l.recordListSeparator));

  /// «٤ أشخاص» – a number of people in her digits.
  String people(int count) => fmt.localizeDigits(l.sufraPeopleCount(count));

  /// «٣ إشيا» – a plain count of things, in her digits.
  String things(int count) => fmt.localizeDigits(l.sufraThingsCount(count));

  /// «بـ٣ أيام» – how early an expiry warns.
  String daysBefore(int count) => fmt.localizeDigits(l.sufraDaysBefore(count));

  /// «٧ إشيا بالبيت».
  String pantryCount(int count) => fmt.localizeDigits(l.sufraPantryCount(count));

  /// «٤ طبخات».
  String recipesCount(int count) => fmt.localizeDigits(l.sufraRecipesCount(count));

  /// «طبختيها ٣ مرات».
  String cookedTimes(int count) => fmt.localizeDigits(l.sufraCookedTimes(count));

  /// Her window, as a chip («يومين», «بلا حد»).
  String window(int days) => fmt.localizeDigits(l.sufraWindowDays(days));

  /// Her window choices, in her digits.
  List<(int, String)> get windowChoices => [for (final d in NoRepeat.windowChoices) (d, window(d))];

  /// The default name of the standing list of the house.
  String get houseListName => l.sufraHouseListName;

  /// The default name of a dish's own missing-list.
  String recipeListName(String dish) => l.sufraRecipeListName(name(dish));

  /// «انضافوا إشيين للقائمة».
  String addedToList(int count) => fmt.localizeDigits(l.sufraAddedToList(count));
}
