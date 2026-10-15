/// Turning what is missing into shopping lines – pure, so the arithmetic
/// that decides «ناقص ٣٠٠ غم رز» is tested without a database and the list
/// engine stays the only thing that stores a list.
library;

import 'package:meta/meta.dart';

import '../../search/domain/search_text.dart';
import 'pantry.dart';
import 'pantry_match.dart';

/// One line to buy: her word for the thing, and how much – when, and only
/// when, Madar actually knows how much.
@immutable
class ShoppingLine {
  const ShoppingLine({required this.title, this.quantity, this.unit, this.note});

  final String title;

  /// How much to buy. **Null whenever Madar cannot say** – a dish that
  /// needs a cup of something the house keeps in kilos puts the thing on
  /// the list without a number rather than with a wrong one.
  final double? quantity;
  final String? unit;

  /// Why it is on the list, in her words (filled by the screens layer,
  /// which owns the strings).
  final String? note;

  @override
  String toString() => 'ShoppingLine($title${quantity == null ? '' : ' $quantity ${unit ?? ''}'})';
}

/// The pure half of «القائمة من الطبخة اللي قريبة».
abstract final class ShoppingLines {
  /// What is missing for [match], as lines.
  ///
  /// A missing ingredient carries the whole amount the dish needs, a short
  /// one carries the gap, and an ingredient Madar is unsure about (a unit
  /// it will not convert, an amount she never typed, two pantry items it
  /// will not choose between) is on the list **without a number** when
  /// [includeUnsure] – because the honest line is «رز» and not «رز ٢ كيلو»
  /// Madar made up. Optional ingredients are never added.
  static List<ShoppingLine> ofMatch(RecipeMatch match, {bool includeUnsure = true}) => [
    for (final c in match.checks)
      if (!c.ingredient.optional && c.buy)
        ShoppingLine(title: c.ingredient.name, quantity: c.shortBy, unit: c.shortUnit),
    if (includeUnsure)
      for (final c in match.checks)
        if (!c.ingredient.optional && c.unknown) ShoppingLine(title: c.ingredient.name),
  ];

  /// What is low or finished in the house, as lines. A staple that finished
  /// is on the list even when she never set a threshold.
  ///
  /// The amount is her low threshold when she set one (buy enough to get
  /// back over it), else nothing – never a number Madar invented.
  static List<ShoppingLine> ofPantry(PantryBoard pantry) => [
    for (final s in pantry.toBuy)
      ShoppingLine(
        title: s.item.name,
        quantity: s.item.lowAt,
        unit: s.item.lowAt == null ? null : s.item.unit,
      ),
  ];

  /// [lines] with the ones already on the list (by folded title) dropped,
  /// so adding the same near match twice does not double the list.
  static List<ShoppingLine> without(Iterable<ShoppingLine> lines, Iterable<String> existingTitles) {
    final seen = {
      for (final t in existingTitles)
        if (SearchText.fold(t).isNotEmpty) SearchText.fold(t),
    };
    final out = <ShoppingLine>[];
    for (final line in lines) {
      final key = SearchText.fold(line.title);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(line);
    }
    return out;
  }
}
