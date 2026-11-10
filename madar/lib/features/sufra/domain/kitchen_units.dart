/// Units in the kitchen, and the one rule that matters: **convert only
/// where the conversion is certain, and say "unknown" everywhere else.**
///
/// Pure Dart (no Flutter, no database).
///
/// A kilo is a thousand grams and a litre is a thousand millilitres – that
/// is arithmetic, and Madar does it. A *cup* of rice in grams is not: it
/// depends on the rice, the cup and how she filled it. An engine that
/// guessed it would put a wrong dish on her table and tell her she can
/// cook it, so this one refuses: the comparison comes back
/// [UnitMatch.unknown] and the matcher says «ما بعرف أحسب» instead of a
/// number.
///
/// The unit words are hers. [KitchenUnits.normalize] knows the spellings a
/// Jordanian kitchen actually writes («كيلو»، «كغم»، «kg»، «غم»، «لتر»،
/// «مل»، «حبة»، «علبة») and folds them onto one canonical word; anything
/// it does not know stays **her own word**, comparable only with itself.
library;

import 'package:meta/meta.dart';

import '../../search/domain/search_text.dart';

/// What a unit measures, as far as Madar is willing to claim.
enum UnitFamily {
  /// Kilograms and grams: convertible, exactly.
  mass,

  /// Litres and millilitres: convertible, exactly.
  volume,

  /// Things you count (حبة، علبة، رغيف، باكيت). Same word ⇒ comparable;
  /// never converted into mass or volume (a «علبة» of what, and how big?).
  count,

  /// A household measure (كوب، ملعقة، كاسة، رشة). Comparable with the same
  /// word only. **Never** converted into grams or millilitres: that number
  /// does not exist without knowing the ingredient.
  household,

  /// A word Madar does not recognise – hers. Comparable with itself only.
  other,
}

/// A unit after folding: the canonical word, what it measures, and how much
/// of the family's base unit one of it is (grams for [UnitFamily.mass],
/// millilitres for [UnitFamily.volume], 1 for everything else).
@immutable
class KitchenUnit {
  const KitchenUnit(this.canonical, this.family, this.inBase);

  /// A quantity with no unit at all («٣ بندورة»): comparable with any other
  /// unit-less quantity and with nothing else.
  static const KitchenUnit none = KitchenUnit('', UnitFamily.other, 1);

  /// The folded word this unit is known by.
  final String canonical;
  final UnitFamily family;

  /// One [canonical] in the family's base unit (1000 for a kilo, 1 for a
  /// gram, 1 for anything not convertible).
  final double inBase;

  /// Whether arithmetic across two different words of this family is
  /// allowed at all.
  bool get convertible => family == UnitFamily.mass || family == UnitFamily.volume;

  bool get isNone => canonical.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is KitchenUnit && other.canonical == canonical && other.family == family && other.inBase == inBase;

  @override
  int get hashCode => Object.hash(canonical, family, inBase);

  @override
  String toString() => 'KitchenUnit($canonical, ${family.name}, ×$inBase)';
}

/// The verdict of comparing two amounts.
enum UnitMatch {
  /// Same unit: compare the numbers as they are.
  same,

  /// Different words of one exact family (kg ↔ g, l ↔ ml): converted.
  converted,

  /// Madar will not claim a conversion. Not a failure of hers and not an
  /// error – a refusal to invent («كوب رز» against «كيلو رز»).
  unknown,
}

/// Two amounts made comparable, or honestly not.
@immutable
class UnitComparison {
  const UnitComparison(this.match, {this.have = 0, this.need = 0, this.unit = KitchenUnit.none});

  /// The refusal: nothing was converted and no number may be read off it.
  static const UnitComparison unknown = UnitComparison(UnitMatch.unknown);

  final UnitMatch match;

  /// How much there is, in [unit] (meaningless when [match] is unknown).
  final double have;

  /// How much the dish needs, in [unit].
  final double need;

  /// The unit both numbers are expressed in.
  final KitchenUnit unit;

  bool get isKnown => match != UnitMatch.unknown;

  /// Enough of it (only ever asked when [isKnown]).
  bool get enough => isKnown && have + _epsilon >= need;

  /// What is still missing, in [unit] – 0 when there is enough, null when
  /// Madar cannot say.
  double? get short {
    if (!isKnown) return null;
    final gap = need - have;
    return gap <= _epsilon ? 0 : KitchenUnits.round(gap);
  }

  /// Floating-point slack: a gram of a kilo, so `0.3 + 0.6 >= 0.9` holds.
  static const double _epsilon = 1e-6;

  @override
  String toString() => 'UnitComparison(${match.name}, $have/$need ${unit.canonical})';
}

/// Folding her unit words, and the only conversions Madar performs.
abstract final class KitchenUnits {
  /// Canonical mass words and what one of them is in grams.
  static const Map<String, double> _mass = {'كغم': 1000, 'غم': 1};

  /// Canonical volume words and what one of them is in millilitres.
  static const Map<String, double> _volume = {'لتر': 1000, 'مل': 1};

  /// Everything a Jordanian kitchen writes, onto one canonical word. Both
  /// sides are folded at load ([SearchText.fold] turns ة into ه, drops
  /// harakat and tatweel, reads Arabic-Indic digits as Western), so the
  /// table may be written here the way she would write it.
  static const Map<String, String> _spellings = {
    // mass – the one family Madar converts inside, exactly
    'كيلو': 'كغم', 'كيلوغرام': 'كغم', 'كيلو غرام': 'كغم', 'كغ': 'كغم', 'كجم': 'كغم',
    'kg': 'كغم', 'kilo': 'كغم', 'kilogram': 'كغم', 'kgs': 'كغم',
    'غرام': 'غم', 'جرام': 'غم', 'جم': 'غم', 'g': 'غم', 'gr': 'غم', 'gram': 'غم', 'grams': 'غم',
    // volume – likewise
    'ليتر': 'لتر', 'l': 'لتر', 'lt': 'لتر', 'liter': 'لتر', 'litre': 'لتر',
    'ملل': 'مل', 'مليلتر': 'مل', 'ml': 'مل', 'milliliter': 'مل', 'millilitre': 'مل',
    // things you count: same word compares, nothing converts
    'حبات': 'حبة', 'piece': 'حبة', 'pieces': 'حبة', 'pc': 'حبة',
    'علب': 'علبة', 'can': 'علبة', 'tin': 'علبة',
    'باكت': 'باكيت', 'ارغفة': 'رغيف', 'دجاجة': 'فرخة',
    // household measures: compare with themselves, NEVER into grams
    'اكواب': 'كوب', 'cup': 'كوب', 'cups': 'كوب',
    'ملاعق': 'ملعقة', 'ملعقة كبيرة': 'ملعقة', 'spoon': 'ملعقة', 'tbsp': 'ملعقة',
    'tsp': 'ملعقة صغيرة', 'pinch': 'رشة',
  };

  /// Things you count, in her words.
  static const List<String> _countedWords = [
    'حبة', 'علبة', 'باكيت', 'كيس', 'ربطة', 'رغيف', 'صدر', 'فرخة',
  ];

  /// Household measures – the ones Madar refuses to turn into grams.
  static const List<String> _householdWords = ['كوب', 'كاسة', 'فنجان', 'ملعقة', 'ملعقة صغيرة', 'رشة'];

  /// [_spellings] with both sides folded, plus every canonical word mapped
  /// to itself, so a word she already wrote canonically is found too.
  static final Map<String, String> _lookup = {
    for (final w in [..._mass.keys, ..._volume.keys, ..._countedWords, ..._householdWords])
      SearchText.fold(w): SearchText.fold(w),
    for (final MapEntry(:key, :value) in _spellings.entries) SearchText.fold(key): SearchText.fold(value),
  };

  static final Map<String, double> _massFolded = {
    for (final MapEntry(:key, :value) in _mass.entries) SearchText.fold(key): value,
  };

  static final Map<String, double> _volumeFolded = {
    for (final MapEntry(:key, :value) in _volume.entries) SearchText.fold(key): value,
  };

  static final Set<String> _counted = {for (final w in _countedWords) SearchText.fold(w)};
  static final Set<String> _household = {for (final w in _householdWords) SearchText.fold(w)};

  /// Her word as a [KitchenUnit]. An empty or whitespace-only word is
  /// [KitchenUnit.none]; a word Madar does not know keeps its own folded
  /// spelling in [UnitFamily.other], so «شنينة» only ever compares with
  /// «شنينة».
  static KitchenUnit normalize(String? raw) {
    final folded = SearchText.fold(raw ?? '');
    if (folded.isEmpty) return KitchenUnit.none;
    final canonical = _lookup[folded] ?? folded;
    final mass = _massFolded[canonical];
    if (mass != null) return KitchenUnit(canonical, UnitFamily.mass, mass);
    final volume = _volumeFolded[canonical];
    if (volume != null) return KitchenUnit(canonical, UnitFamily.volume, volume);
    if (_counted.contains(canonical)) return KitchenUnit(canonical, UnitFamily.count, 1);
    if (_household.contains(canonical)) return KitchenUnit(canonical, UnitFamily.household, 1);
    return KitchenUnit(canonical, UnitFamily.other, 1);
  }

  /// Whether the same two words were written («كيلو» and «kg» are).
  static bool sameWord(String? a, String? b) => normalize(a) == normalize(b);

  /// [amount] of [from] expressed in [to], or null when Madar will not
  /// claim the conversion.
  ///
  /// It converts inside [UnitFamily.mass] and [UnitFamily.volume] only, and
  /// returns the number unchanged when the two units are the same word.
  /// Everything else – a cup into grams, a tin into millilitres, one of her
  /// own words into another – is null, on purpose.
  static double? convert(double amount, KitchenUnit from, KitchenUnit to) {
    if (from == to) return round(amount);
    if (from.family != to.family) return null;
    if (!from.convertible) return null;
    return round(amount * from.inBase / to.inBase);
  }

  /// Compares what is in the house against what the dish needs.
  ///
  /// * both amounts null-free and in comparable units → [UnitMatch.same]
  ///   or [UnitMatch.converted], with both numbers in the **needed** unit,
  ///   so «ناقص ٣٠٠ غم» is read straight off it;
  /// * units that cannot be converted → [UnitComparison.unknown]. No
  ///   number is produced, ever.
  static UnitComparison compare({
    required double have,
    required String? haveUnit,
    required double need,
    required String? needUnit,
  }) {
    final from = normalize(haveUnit);
    final to = normalize(needUnit);
    final converted = convert(have, from, to);
    if (converted == null) return UnitComparison.unknown;
    return UnitComparison(
      from == to ? UnitMatch.same : UnitMatch.converted,
      have: converted,
      need: round(need),
      unit: to,
    );
  }

  /// Two decimals, so 0.1 + 0.2 never shows as 0.30000000000000004 (the
  /// same rule `Portions.round` uses in Part 4).
  static double round(double v) => double.parse(v.toStringAsFixed(2));
}
