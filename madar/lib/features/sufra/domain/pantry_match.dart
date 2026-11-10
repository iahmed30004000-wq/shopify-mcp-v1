/// The heart of «السفرة»: given what is in the house, which dishes can she
/// cook **now**, which ones are one or two things away, and exactly what is
/// missing and how much.
///
/// Pure Dart (no Flutter, no database): the whole ranking is a function of
/// her recipes, her pantry, her cooked log and her constraints, so it is
/// testable on its own and the screens cannot change the answer.
///
/// ## What the matcher does
///
/// For every required ingredient of a dish it looks the word up in the
/// pantry (her item names and her own aliases, folded the way the app folds
/// Arabic), compares what is there against what the dish needs, and returns
/// one of [IngredientVerdict]. Then the dish gets one [MatchVerdict], a
/// coverage, the list of what is missing with amounts, the no-repeat hold,
/// and every constraint it breaches.
///
/// ## What the matcher refuses to do
///
/// * **It never invents a conversion.** Kilo ↔ gram and litre ↔ millilitre
///   are arithmetic and it does them. A cup of rice in grams is not: the
///   ingredient comes back [IngredientVerdict.unknownUnit] and the whole
///   dish becomes [MatchVerdict.unsure] – «ما بقدر أحسب», never a guess. A
///   wrong conversion would put a dish she cannot cook on her table.
/// * **It never fills in an amount she did not type.** «في رز» with no
///   number against «٢ كيلو رز» is [IngredientVerdict.unknownAmount], not
///   "enough".
/// * **It never picks between two pantry items.** When «رز» could be «رز
///   بسمتي» or «رز مصري» and neither is an exact match, that is
///   [IngredientVerdict.ambiguous] and it says which two.
/// * **It never filters on a time it does not know.** A dish with no
///   minutes written on it survives «عندي نص ساعة».
/// * **It holds nothing back silently.** A dish held by the no-repeat
///   window or by a constraint comes back with the reason attached, so the
///   screen can show it and she can override it.
///
/// A dish Madar is not sure about is never presented as cookable. That is
/// the whole design.
library;

import 'package:meta/meta.dart';

import '../../../core/domain/enums.dart';
import '../../search/domain/search_text.dart';
import 'constraints.dart';
import 'kitchen_units.dart';
import 'no_repeat.dart';
import 'pantry.dart';
import 'recipe.dart';

/// What the house says about one ingredient.
enum IngredientVerdict {
  /// It is there, and there is enough of it (or the dish gave no amount).
  have,

  /// It is there but not enough – [IngredientCheck.shortBy] says how much
  /// is missing.
  short,

  /// Not in the house at all, or finished.
  missing,

  /// There, but she never typed how much, and the dish asks for an amount.
  /// Madar will not claim it is enough.
  unknownAmount,

  /// There, with an amount, but the units cannot be compared («كوب» against
  /// «كيلو»). Madar will not invent the conversion.
  unknownUnit,

  /// More than one pantry item could be it and none matches exactly.
  ambiguous,
}

/// One ingredient, checked against the house.
@immutable
class IngredientCheck {
  const IngredientCheck({
    required this.ingredient,
    required this.verdict,
    this.stock,
    this.comparison,
    this.shortBy,
    this.shortUnit,
    this.candidates = const [],
    this.loose = false,
  });

  final RecipeIngredient ingredient;
  final IngredientVerdict verdict;

  /// The pantry item it resolved to (null when nothing did).
  final PantryStock? stock;

  /// The comparison behind the verdict (null when there was nothing to
  /// compare).
  final UnitComparison? comparison;

  /// How much is missing, in [shortUnit] – the full amount for a missing
  /// ingredient, the gap for a short one, **null** whenever Madar cannot
  /// say.
  final double? shortBy;

  /// The unit [shortBy] is in (her own word for it).
  final String? shortUnit;

  /// The pantry items that could have been it, when it is [ambiguous].
  final List<PantryStock> candidates;

  /// It matched a pantry item by containment rather than exactly («رز»
  /// found «رز بسمتي»). True so a screen can say so and she can fix it with
  /// an alias.
  final bool loose;

  /// Satisfied: she has it and enough of it.
  bool get satisfied => verdict == IngredientVerdict.have;

  /// Madar cannot say either way.
  bool get unknown =>
      verdict == IngredientVerdict.unknownAmount ||
      verdict == IngredientVerdict.unknownUnit ||
      verdict == IngredientVerdict.ambiguous;

  /// Something to buy: not there, or not enough.
  bool get buy => verdict == IngredientVerdict.missing || verdict == IngredientVerdict.short;

  @override
  String toString() => 'IngredientCheck(${ingredient.name}, ${verdict.name})';
}

/// What the house says about a whole dish.
enum MatchVerdict {
  /// Everything required is there, in enough quantity.
  cookNow,

  /// A short list is missing, and every missing amount is known.
  nearly,

  /// At least one ingredient Madar cannot judge (a unit it will not
  /// convert, an amount she never typed, two items it will not choose
  /// between). Never shown as cookable.
  unsure,

  /// Too much is missing to call it near.
  far,
}

/// One dish, ranked.
@immutable
class RecipeMatch {
  const RecipeMatch({
    required this.recipe,
    required this.verdict,
    required this.checks,
    required this.coverage,
    required this.hold,
    required this.hits,
    required this.usesExpiring,
    this.scaledFor,
    this.preferred = false,
  });

  /// The dish, with its ingredients already scaled for the number eating
  /// when that could be worked out ([Recipe.forPeople]).
  final Recipe recipe;
  final MatchVerdict verdict;

  /// Every required ingredient, in her order. Optional ingredients are
  /// checked too and appear after the required ones.
  final List<IngredientCheck> checks;

  /// Required ingredients she has, over all required ingredients (0‥1).
  /// An ingredient Madar is unsure about counts as **not** covered: this
  /// number never flatters a dish.
  final double coverage;

  /// Why the no-repeat window holds it, or that it does not.
  final RepeatHold hold;

  /// Every constraint it breaches (empty when it breaches none).
  final List<ConstraintHit> hits;

  /// Pantry items near their expiry that this dish would use up – the
  /// reason to cook it tonight rather than tomorrow.
  final List<PantryStock> usesExpiring;

  /// How many it was scaled for (null when it was not scaled).
  final int? scaledFor;

  /// One of her «أفضّل» words, or his plan when the owner turned it on.
  final bool preferred;

  /// She can cook it now: nothing missing, nothing unsure, no hard
  /// constraint, and the window does not hold it.
  bool get cookable => verdict == MatchVerdict.cookNow && !blocked && !hold.held;

  /// A hard constraint says no (an allergy, a request for tonight).
  bool get blocked => hits.any((h) => h.hard);

  /// Held back for any reason she can override.
  bool get heldBack => hold.held || hits.isNotEmpty;

  /// What to buy, in her order – what a shopping list is made of.
  List<IngredientCheck> get shopping => [
    for (final c in checks)
      if (c.buy && !c.ingredient.optional) c,
  ];

  /// The ingredients Madar could not judge.
  List<IngredientCheck> get unsureChecks => [
    for (final c in checks)
      if (c.unknown && !c.ingredient.optional) c,
  ];

  /// How many required ingredients are missing or short.
  int get missingCount => shopping.length;

  @override
  String toString() => 'RecipeMatch(${recipe.name}, ${verdict.name}, missing $missingCount)';
}

/// The matcher.
abstract final class PantryMatcher {
  /// Up to this many missing ingredients still counts as «قريبة» – more
  /// than that and the dish is [MatchVerdict.far].
  static const int defaultNearlyLimit = 3;

  /// One dish against the house.
  ///
  /// [people] scales the ingredients when the recipe says how many it
  /// feeds; when it does not, nothing is scaled (scaling without a base
  /// would be inventing one).
  static RecipeMatch match(
    Recipe recipe, {
    required PantryBoard pantry,
    KitchenConstraints constraints = KitchenConstraints.none,
    Iterable<CookedMeal> cookedLog = const [],
    RepeatHold? hold,
    int nearlyLimit = defaultNearlyLimit,
    DateTime? today,
  }) {
    final day = today ?? pantry.today;
    final people = constraints.people;
    final factor = recipe.factorFor(people);
    final scaled = recipe.forPeople(people);
    final scaledFor = factor == null || factor == 1 ? null : people;

    final checks = <IngredientCheck>[
      for (final i in scaled.ingredients)
        if (!i.optional) _check(i, pantry),
      for (final i in scaled.ingredients)
        if (i.optional) _check(i, pantry),
    ];
    final required = [
      for (final c in checks)
        if (!c.ingredient.optional) c,
    ];
    final satisfied = required.where((c) => c.satisfied).length;
    final unknown = required.where((c) => c.unknown).length;
    final buy = required.where((c) => c.buy).length;
    final coverage = required.isEmpty ? 1.0 : satisfied / required.length;
    final verdict = unknown > 0
        ? MatchVerdict.unsure
        : buy == 0
        ? MatchVerdict.cookNow
        : buy <= nearlyLimit
        ? MatchVerdict.nearly
        : MatchVerdict.far;

    return RecipeMatch(
      recipe: scaled,
      verdict: verdict,
      checks: List.unmodifiable(checks),
      coverage: coverage,
      hold:
          hold ??
          NoRepeat.check(
            cookedLog,
            recipeId: recipe.id,
            today: day,
            windowDays: constraints.windowDays,
          ),
      hits: List.unmodifiable(_hits(scaled, checks, constraints)),
      usesExpiring: List.unmodifiable(_expiring(checks)),
      scaledFor: scaledFor,
      preferred: _preferred(scaled, checks, constraints),
    );
  }

  /// Every dish against the house, best first.
  ///
  /// Order: the dishes she can cook now, then the near ones (fewest missing
  /// first), then the ones Madar is unsure about, then the far ones. Inside
  /// a group: a dish that uses something about to go off comes first, then
  /// one of her «أفضّل» words, then a favourite, then her own order.
  ///
  /// A dish a **hard** constraint blocks (an allergy, a request for
  /// tonight) is left out unless [includeBlocked]; one the no-repeat window
  /// holds is kept but sent to the end, so she can always override it.
  /// Archived dishes are never suggested.
  static List<RecipeMatch> rank(
    Iterable<Recipe> recipes, {
    required PantryBoard pantry,
    KitchenConstraints constraints = KitchenConstraints.none,
    Iterable<CookedMeal> cookedLog = const [],
    int nearlyLimit = defaultNearlyLimit,
    DateTime? today,
    int limit = 0,
    bool includeBlocked = false,
    bool includeArchived = false,
  }) {
    final pool = [
      for (final r in recipes)
        if (includeArchived || !r.archived) r,
    ];
    final day = today ?? pantry.today;
    final holds = NoRepeat.checkAll(
      cookedLog,
      recipeIds: [for (final r in pool) r.id],
      today: day,
      windowDays: constraints.windowDays,
    );
    final out = <RecipeMatch>[];
    for (final recipe in pool) {
      final m = match(
        recipe,
        pantry: pantry,
        constraints: constraints,
        hold: constraints.ignoreNoRepeat ? RepeatHold.free : (holds[recipe.id] ?? RepeatHold.free),
        nearlyLimit: nearlyLimit,
        today: day,
      );
      if (m.blocked && !includeBlocked) continue;
      out.add(m);
    }
    final order = {for (var i = 0; i < pool.length; i++) pool[i].id: i};
    out.sort((a, b) => _compare(a, b, order));
    return limit <= 0 || out.length <= limit ? out : out.sublist(0, limit);
  }

  /// The dishes she can cook right now, in order.
  static List<RecipeMatch> cookNow(List<RecipeMatch> ranked) => [
    for (final m in ranked)
      if (m.cookable) m,
  ];

  /// The near misses: everything missing is known and short.
  static List<RecipeMatch> nearly(List<RecipeMatch> ranked) => [
    for (final m in ranked)
      if (m.verdict == MatchVerdict.nearly && !m.blocked && !m.hold.held) m,
  ];

  /// One suggestion for tonight: the best dish she can cook now, else the
  /// nearest miss, else null («ما في اشي بقدر أقترحه» – and the screen
  /// shows the warm empty state instead of a made-up dish).
  static RecipeMatch? tonight(List<RecipeMatch> ranked) {
    for (final m in ranked) {
      if (m.cookable) return m;
    }
    for (final m in ranked) {
      if (!m.blocked && !m.hold.held && m.verdict == MatchVerdict.nearly) return m;
    }
    return null;
  }

  // ------------------------------------------------------------ internals --

  static const Map<MatchVerdict, int> _verdictRank = {
    MatchVerdict.cookNow: 0,
    MatchVerdict.nearly: 1,
    MatchVerdict.unsure: 2,
    MatchVerdict.far: 3,
  };

  static int _compare(RecipeMatch a, RecipeMatch b, Map<String, int> order) {
    // Held back by the window: always last, whatever else it is.
    if (a.hold.held != b.hold.held) return a.hold.held ? 1 : -1;
    // A soft constraint (one of her «أبعد عنه» words) after the clean ones.
    final aSoft = a.hits.isNotEmpty, bSoft = b.hits.isNotEmpty;
    if (aSoft != bSoft) return aSoft ? 1 : -1;
    final byVerdict = _verdictRank[a.verdict]!.compareTo(_verdictRank[b.verdict]!);
    if (byVerdict != 0) return byVerdict;
    final byMissing = a.missingCount.compareTo(b.missingCount);
    if (byMissing != 0) return byMissing;
    final aExpiring = a.usesExpiring.isNotEmpty, bExpiring = b.usesExpiring.isNotEmpty;
    if (aExpiring != bExpiring) return aExpiring ? -1 : 1;
    if (a.preferred != b.preferred) return a.preferred ? -1 : 1;
    final byCoverage = b.coverage.compareTo(a.coverage);
    if (byCoverage != 0) return byCoverage;
    if (a.recipe.favorite != b.recipe.favorite) return a.recipe.favorite ? -1 : 1;
    return (order[a.recipe.id] ?? 0).compareTo(order[b.recipe.id] ?? 0);
  }

  /// One ingredient against the pantry.
  static IngredientCheck _check(RecipeIngredient ingredient, PantryBoard pantry) {
    final word = ingredient.word;
    if (word.isEmpty) {
      return IngredientCheck(ingredient: ingredient, verdict: IngredientVerdict.missing);
    }
    var loose = false;
    var stock = pantry.exact(word);
    if (stock == null) {
      final candidates = pantry.contains(word);
      if (candidates.isEmpty) {
        return IngredientCheck(
          ingredient: ingredient,
          verdict: IngredientVerdict.missing,
          shortBy: ingredient.quantity,
          shortUnit: ingredient.unit,
        );
      }
      if (candidates.length > 1) {
        // Two things in the house could be it. Choosing would be guessing.
        return IngredientCheck(
          ingredient: ingredient,
          verdict: IngredientVerdict.ambiguous,
          candidates: candidates,
        );
      }
      stock = candidates.single;
      loose = true;
    }
    if (stock.isOut) {
      return IngredientCheck(
        ingredient: ingredient,
        verdict: IngredientVerdict.missing,
        stock: stock,
        shortBy: ingredient.quantity,
        shortUnit: ingredient.unit,
        loose: loose,
      );
    }
    final need = ingredient.quantity;
    if (need == null) {
      // The dish says «شوية»: having it at all is enough.
      return IngredientCheck(ingredient: ingredient, verdict: IngredientVerdict.have, stock: stock, loose: loose);
    }
    final have = stock.item.quantity;
    if (have == null) {
      return IngredientCheck(
        ingredient: ingredient,
        verdict: IngredientVerdict.unknownAmount,
        stock: stock,
        loose: loose,
      );
    }
    final comparison = KitchenUnits.compare(
      have: have,
      haveUnit: stock.item.unit,
      need: need,
      needUnit: ingredient.unit,
    );
    if (!comparison.isKnown) {
      return IngredientCheck(
        ingredient: ingredient,
        verdict: IngredientVerdict.unknownUnit,
        stock: stock,
        comparison: comparison,
        loose: loose,
      );
    }
    if (comparison.enough) {
      return IngredientCheck(
        ingredient: ingredient,
        verdict: IngredientVerdict.have,
        stock: stock,
        comparison: comparison,
        loose: loose,
      );
    }
    return IngredientCheck(
      ingredient: ingredient,
      verdict: IngredientVerdict.short,
      stock: stock,
      comparison: comparison,
      shortBy: comparison.short,
      shortUnit: ingredient.unit,
      loose: loose,
    );
  }

  /// Every constraint this dish breaches.
  static List<ConstraintHit> _hits(Recipe recipe, List<IngredientCheck> checks, KitchenConstraints c) {
    final out = <ConstraintHit>[];
    final words = <String>{
      for (final check in checks) check.ingredient.word,
      ...recipe.foldedTags,
    }..removeWhere((w) => w.isEmpty);

    for (final rule in c.activeRules) {
      if (rule.encourages) continue;
      if (!_touches(words, rule.word)) continue;
      out.add(
        ConstraintHit(
          rule.kind == KitchenRuleKind.allergy
              ? ConstraintBreach.allergy
              : rule.kind == KitchenRuleKind.request
              ? ConstraintBreach.request
              : ConstraintBreach.avoid,
          term: rule.term,
          who: rule.who,
          rule: rule,
        ),
      );
    }
    // Time: only when the dish actually says how long it takes.
    final minutes = recipe.minutes;
    final limit = c.maxMinutes;
    if (minutes != null && limit != null && minutes > limit) {
      out.add(const ConstraintHit(ConstraintBreach.tooLong));
    }
    // Tags she asked for tonight.
    for (final tag in c.mustTagWords) {
      if (!recipe.foldedTags.contains(tag)) {
        out.add(ConstraintHit(ConstraintBreach.missingTag, term: tag));
      }
    }
    // His plan, and only when the owner turned it on.
    if (c.diet.on) {
      for (final word in c.diet.avoidWords) {
        if (_touches(words, word)) {
          out.add(ConstraintHit(ConstraintBreach.diet, term: word, who: c.diet.label));
        }
      }
    }
    return out;
  }

  static bool _preferred(Recipe recipe, List<IngredientCheck> checks, KitchenConstraints c) {
    final words = <String>{
      for (final check in checks) check.ingredient.word,
      ...recipe.foldedTags,
    }..removeWhere((w) => w.isEmpty);
    for (final rule in c.activeRules) {
      if (rule.encourages && _touches(words, rule.word)) return true;
    }
    if (c.diet.on) {
      for (final word in c.diet.preferWords) {
        if (_touches(words, word)) return true;
      }
    }
    return false;
  }

  /// Whether any of [words] is the same as [term] or holds it (so an
  /// allergy to «فول سوداني» also catches «زبدة فول سوداني»). Deliberately
  /// generous: for an allergy, catching too much is safe and catching too
  /// little is not.
  static bool _touches(Set<String> words, String term) {
    if (term.isEmpty) return false;
    for (final w in words) {
      if (w == term || w.contains(term) || term.contains(w)) return true;
    }
    return false;
  }

  /// The pantry items near their expiry that this dish would use.
  static List<PantryStock> _expiring(List<IngredientCheck> checks) {
    final out = <String, PantryStock>{};
    for (final c in checks) {
      final stock = c.stock;
      if (stock == null) continue;
      if (stock.state == PantryState.expiringSoon || stock.state == PantryState.expired) {
        out[stock.item.id] = stock;
      }
    }
    return out.values.toList();
  }

  /// Whether two words are the same word for her (exposed for the screens:
  /// the ingredient editor uses it to offer an alias).
  static bool sameWord(String? a, String? b) {
    if (a == null || b == null) return false;
    final fa = SearchText.fold(a);
    return fa.isNotEmpty && fa == SearchText.fold(b);
  }
}
