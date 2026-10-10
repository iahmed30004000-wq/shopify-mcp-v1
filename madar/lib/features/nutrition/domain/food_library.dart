/// The food library: the foods the user defines once and reuses, Arabic-aware
/// lookup for quick entry, and portion arithmetic.
///
/// Pure Dart (no Flutter, no database): every function here is testable on
/// its own and holds nothing of ours about food – no nutrition facts, no
/// categories we invented. A food's tags are the user's own words.
library;

import 'package:meta/meta.dart';

import '../../search/domain/search_text.dart';

/// One food of the library (a plain copy of a `foods` row).
@immutable
class Food {
  const Food({
    required this.id,
    required this.name,
    this.notes,
    this.tags = const [],
    this.defaultPortion,
    this.unit,
    this.favorite = false,
    this.archived = false,
  });

  final String id;
  final String name;
  final String? notes;

  /// The user's own tags («حلو»، «مقلي»). Food rules match on these.
  final List<String> tags;

  /// How much he normally eats, in [unit].
  final double? defaultPortion;

  /// The user's own unit word («رغيف»، «كوب»). Never converted.
  final String? unit;
  final bool favorite;
  final bool archived;

  @override
  String toString() => 'Food($id, $name, ${tags.join('/')})';
}

/// A food that matched a query, with the quality of the match.
@immutable
class FoodMatch {
  const FoodMatch(this.food, this.score, {this.onTag = false});

  final Food food;

  /// 0‥1, bigger is better (see [FoodLookup]).
  final double score;

  /// The query matched one of the food's tags rather than its name.
  final bool onTag;

  @override
  String toString() => 'FoodMatch(${food.name}, ${score.toStringAsFixed(2)}${onTag ? ', tag' : ''})';
}

/// Arabic-aware lookup over the food library, for the "type two letters and
/// pick" entry box.
///
/// Folding is the app's own search folding ([SearchText]): harakat, tatweel
/// and alef forms are ignored, Arabic-Indic digits read as Western ones, and
/// Latin text is lower-cased – so «مقلي» finds «مَقلي», «بندوره» finds
/// «بندورة» and «١٢» finds «12».
///
/// Scores (highest wins):
/// * 1.00 – the whole folded name equals the query;
/// * 0.90 – the name starts with the query;
/// * 0.80 – a later word of the name starts with the query;
/// * 0.65 – the query appears anywhere in the folded name;
/// * 0.55 – a word of the name is the query with one typo (insert, delete,
///   replace or swap), only for queries of 3 letters or more;
/// * 0.45 – one of the user's tags starts with the query ([FoodMatch.onTag]).
///
/// Ties break on a usage count (when given), then favourites, then the
/// shorter name, then the name itself – so the food he logs most comes first.
abstract final class FoodLookup {
  /// Shortest query that may match with a typo.
  static const int minTypoQuery = 3;

  static const double scoreExact = 1;
  static const double scorePrefix = 0.9;
  static const double scoreWordPrefix = 0.8;
  static const double scoreContains = 0.65;
  static const double scoreTypo = 0.55;
  static const double scoreTag = 0.45;

  /// The matches for [query], best first. An empty or whitespace-only query
  /// returns [favoritesFirst] (the quick-pick list), not an error.
  ///
  /// [usage] maps a food id to how often it was logged (see
  /// `FoodLogStats.useCountById`); it only breaks ties. Archived foods are
  /// left out unless [includeArchived].
  static List<FoodMatch> search(
    Iterable<Food> foods,
    String query, {
    Map<String, int> usage = const {},
    int limit = 20,
    bool includeArchived = false,
  }) {
    final pool = [
      for (final f in foods)
        if (includeArchived || !f.archived) f,
    ];
    final q = SearchText.fold(query);
    if (q.isEmpty) return [for (final f in favoritesFirst(pool, usage: usage, limit: limit)) FoodMatch(f, 0)];
    final out = <FoodMatch>[];
    for (final food in pool) {
      final m = score(food, q);
      if (m != null) out.add(m);
    }
    out.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byUse = (usage[b.food.id] ?? 0).compareTo(usage[a.food.id] ?? 0);
      if (byUse != 0) return byUse;
      if (a.food.favorite != b.food.favorite) return a.food.favorite ? -1 : 1;
      final byLength = a.food.name.length.compareTo(b.food.name.length);
      return byLength != 0 ? byLength : a.food.name.compareTo(b.food.name);
    });
    return out.length <= limit ? out : out.sublist(0, limit);
  }

  /// How well [food] matches an **already folded** query, or null.
  static FoodMatch? score(Food food, String foldedQuery) {
    final q = foldedQuery;
    if (q.isEmpty) return null;
    final name = SearchText.fold(food.name);
    if (name == q) return FoodMatch(food, scoreExact);
    if (name.startsWith(q)) return FoodMatch(food, scorePrefix);
    final words = name.split(' ');
    for (final w in words) {
      if (w.startsWith(q)) return FoodMatch(food, scoreWordPrefix);
    }
    if (name.contains(q)) return FoodMatch(food, scoreContains);
    if (q.length >= minTypoQuery) {
      for (final w in words) {
        if (SearchText.withinOneEdit(w, q)) return FoodMatch(food, scoreTypo);
      }
    }
    for (final tag in food.tags) {
      final t = SearchText.fold(tag);
      if (t.isNotEmpty && (t == q || t.startsWith(q))) return FoodMatch(food, scoreTag, onTag: true);
    }
    return null;
  }

  /// The quick-pick list for an empty query: favourites first, then the most
  /// logged, then the user's own order.
  static List<Food> favoritesFirst(Iterable<Food> foods, {Map<String, int> usage = const {}, int limit = 20}) {
    final list = [
      for (final f in foods)
        if (!f.archived) f,
    ];
    final order = {for (var i = 0; i < list.length; i++) list[i].id: i};
    list.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      final byUse = (usage[b.id] ?? 0).compareTo(usage[a.id] ?? 0);
      if (byUse != 0) return byUse;
      return order[a.id]!.compareTo(order[b.id]!);
    });
    return list.length <= limit ? list : list.sublist(0, limit);
  }

  /// Every tag the user has used, folded-deduplicated, in the spelling he
  /// used most recently, sorted by how many foods carry it then
  /// alphabetically. Feeds the tag picker and the rule editor.
  static List<String> tagsOf(Iterable<Food> foods) {
    final counts = <String, int>{};
    final spelling = <String, String>{};
    for (final f in foods) {
      for (final tag in f.tags) {
        final key = SearchText.fold(tag);
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
        spelling[key] = tag.trim();
      }
    }
    final keys = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : spelling[a]!.compareTo(spelling[b]!);
      });
    return [for (final k in keys) spelling[k]!];
  }

  /// Whether [a] and [b] are the same word for the user (folded equality) –
  /// used to match a tag written in a rule against a tag on a food.
  static bool sameWord(String? a, String? b) {
    if (a == null || b == null) return false;
    final fa = SearchText.fold(a);
    return fa.isNotEmpty && fa == SearchText.fold(b);
  }
}

/// Portion arithmetic. Units are the user's own words, so amounts are only
/// ever added **inside one unit**; nothing is converted between units and no
/// calories or nutrients exist anywhere in Madar.
abstract final class Portions {
  /// Label used for amounts logged without a unit.
  static const String noUnit = '';

  /// The portion an entry really stands for: what was logged, else the
  /// food's default, else null.
  static double? effective(double? logged, {Food? food}) => logged ?? food?.defaultPortion;

  /// The unit an entry really uses: what was logged, else the food's.
  static String? unitOf(String? logged, {Food? food}) {
    final u = logged?.trim();
    if (u != null && u.isNotEmpty) return u;
    final f = food?.unit?.trim();
    return f == null || f.isEmpty ? null : f;
  }

  /// Totals per unit over [amounts] (unit → sum). Entries without an amount
  /// are skipped; entries without a unit land under [noUnit]. Units that
  /// differ only in spelling («كوب» / «كُوب») are merged, keeping the first
  /// spelling seen.
  static Map<String, double> sumByUnit(Iterable<({double? amount, String? unit})> amounts) {
    final sums = <String, double>{};
    final spelling = <String, String>{};
    for (final a in amounts) {
      final amount = a.amount;
      if (amount == null) continue;
      final raw = a.unit?.trim() ?? noUnit;
      final key = raw.isEmpty ? noUnit : SearchText.fold(raw);
      spelling.putIfAbsent(key, () => raw);
      sums[key] = (sums[key] ?? 0) + amount;
    }
    return {for (final e in sums.entries) spelling[e.key]!: round(e.value)};
  }

  /// [amount] scaled by [factor] (e.g. half a planned portion), rounded to
  /// two decimals. Null stays null.
  static double? scale(double? amount, double factor) => amount == null ? null : round(amount * factor);

  /// Two decimals, so 0.1 + 0.2 never shows as 0.30000000000000004.
  static double round(double v) => double.parse(v.toStringAsFixed(2));

  /// Whether [logged] reaches a rule's threshold [minPortion]. A rule with a
  /// threshold never fires on an entry with no amount: the user did not say
  /// how much, so Madar does not guess.
  static bool reaches(double? logged, double minPortion) => logged != null && logged >= minPortion;
}
