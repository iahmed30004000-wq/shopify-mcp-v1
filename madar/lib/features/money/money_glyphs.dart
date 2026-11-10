/// Glyph choices shared by every Money screen (pure Dart).
library;

/// How Money writes amounts in Arabic-Indic digits.
///
/// The app's numerals font (IBM Plex Sans Arabic) draws the Arabic
/// thousands separator `٬` (U+066C) and the decimal separator `٫` (U+066B)
/// as two near-identical commas, so `١٬٨٧٨٫٧٥٠` (1,878.750) reads like
/// 1,878,750 at a glance. Money groups thousands with a narrow no-break
/// space instead – `١ ٨٧٨٫٧٥٠` – which leaves the decimal comma as the only
/// comma in an amount. The space is a common number separator in the bidi
/// algorithm (like `٬`), so the amount stays one run in right-to-left text,
/// and every Money parser already ignores it.
abstract final class MoneyGlyphs {
  /// The thousands separator of Arabic-Indic amounts (U+202F).
  static const String arabicGroup = ' ';

  /// [text] with every Arabic thousands separator replaced by [arabicGroup].
  static String legibleGroups(String text) => text.replaceAll('٬', arabicGroup);
}
