/// What the typist must type, unit by unit, with Arabic tashkeel handling.
///
/// A passage is split into comparable UNITS:
///
/// * [TashkeelMode.ignore] (default) – one unit per base character (letter,
///   space, punctuation, digit). Tashkeel, tatweel, the superscript alef and
///   Quranic annotation signs are not typed; ٱ counts as ا; runs of spaces
///   (and the no-break spaces around Quranic pause marks) are one space.
/// * [TashkeelMode.strict] – one unit per grapheme cluster: a base character
///   plus its harakat (fatha … sukun, tanwin, shadda), compared regardless of
///   the order the marks were typed in. Quranic annotation signs and the
///   superscript alef are never required.
///
/// With [TypingTarget.lenientHamza] (default on) letters are compared after
/// folding (ا/أ/إ/آ, ى/ي, ة/ه) so hamza-seat slips are forgiven; turn it off
/// for spelling practice. A unit – not a keystroke – is the "character" of
/// the WPM formulas, so tashkeel never inflates speed.
library;

import '../core/arabic_text.dart';

/// Tashkeel handling.
enum TashkeelMode {
  /// Type letters only.
  ignore,

  /// Type letters with their harakat.
  strict,
}

/// A target passage.
final class TypingTarget {
  /// Prepares [text] for typing.
  TypingTarget(this.text, {this.mode = TashkeelMode.ignore, this.lenientHamza = true})
    : units = List.unmodifiable(unitsOf(text, mode));

  /// The passage as displayed (verbatim).
  final String text;

  /// Tashkeel mode.
  final TashkeelMode mode;

  /// Fold hamza / alef / taa-marbuta / alef-maqsura spellings when comparing.
  final bool lenientHamza;

  /// The units to type.
  final List<String> units;

  /// Number of units.
  int get length => units.length;

  /// Number of words (space-separated).
  int get wordCount => units.isEmpty ? 0 : units.where((u) => u == ' ').length + 1;

  /// Splits any text into units for [mode]. Trailing spaces are dropped
  /// when [trimEnd] (targets); typed input keeps a final space.
  static List<String> unitsOf(String text, TashkeelMode mode, {bool trimEnd = true}) {
    final out = <String>[];
    void addSpace() {
      if (out.isNotEmpty && out.last != ' ') out.add(' ');
    }

    for (final cluster in ArabicText.clusters(text)) {
      final base = cluster.codeUnitAt(0);
      if (base == 0x20 || base == 0xA0 || base == 0x09 || base == 0x0A || base == 0x202F || base == 0x2009) {
        addSpace();
        continue;
      }
      if (ArabicText.isMark(base) || base == ArabicText.tatweel) continue; // stray mark (e.g. a pause sign)
      final letter = ArabicText.plain(String.fromCharCode(base));
      if (letter.isEmpty) continue;
      if (mode == TashkeelMode.ignore) {
        out.add(letter);
      } else {
        final marks = [for (final cu in cluster.codeUnits.skip(1)) if (ArabicText.isHaraka(cu)) cu]..sort(_markOrder);
        out.add(letter + String.fromCharCodes(marks));
      }
    }
    while (trimEnd && out.isNotEmpty && out.last == ' ') {
      out.removeLast();
    }
    return out;
  }

  // Shadda first, then the vowel / tanwin / sukun.
  static int _markOrder(int a, int b) => (a == 0x0651 ? -1 : a).compareTo(b == 0x0651 ? -1 : b);

  String _norm(String unit) {
    if (!lenientHamza || unit.isEmpty) return unit;
    return ArabicText.foldLetter(unit[0]) + unit.substring(1);
  }

  /// Whether [typed] (one unit, marks in any order) is right at [index].
  bool matches(int index, String typed) {
    if (index < 0 || index >= units.length) return false;
    final u = typed == ' ' ? const [' '] : unitsOf(typed, mode);
    return u.length == 1 && _norm(units[index]) == _norm(u.single);
  }
}
