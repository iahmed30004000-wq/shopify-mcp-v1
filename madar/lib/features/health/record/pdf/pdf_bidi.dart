/// Word-level bidi layout for the PDF renderer.
///
/// The `pdf` package shapes Arabic and orders a right-to-left line well when
/// the line is pure Arabic, but it scrambles lines that mix in Latin words
/// or numbers with separators (`Omega 3 مع الفطور`, `٨:٠٠ ص`), does not
/// mirror brackets, and its fonts have no glyphs for bidi controls. So each
/// line is split into words and laid out here, roughly following UAX #9 at
/// word level:
///
/// * in a right-to-left line, a group of Latin words (with the numbers and
///   symbols between them, and a Western number right after them – W7) is
///   kept left-to-right as one unit; every other word is its own unit,
///   placed right-to-left by an RTL `Wrap`;
/// * in a left-to-right line, a group of Arabic words (with whatever sits
///   between them) becomes one nested right-to-left unit.
///
/// Pure Dart; the renderer turns [BidiItem]s into widgets.
library;

/// A laid-out piece of a line.
sealed class BidiItem {
  const BidiItem();
}

/// One word (or a Latin group joined by spaces) drawn in one direction.
final class BidiWord extends BidiItem {
  const BidiWord(this.text, {required this.rtl});

  final String text;

  /// Drawn right-to-left (Arabic shaping applies).
  final bool rtl;

  @override
  bool operator ==(Object other) => other is BidiWord && other.text == text && other.rtl == rtl;

  @override
  int get hashCode => Object.hash(text, rtl);

  @override
  String toString() => '${rtl ? 'R' : 'L'}"$text"';
}

/// A nested unit in the opposite direction of its line.
final class BidiSpan extends BidiItem {
  const BidiSpan(this.items, {required this.rtl});

  final List<BidiItem> items;
  final bool rtl;

  @override
  bool operator ==(Object other) {
    if (other is! BidiSpan || other.rtl != rtl || other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(rtl, Object.hashAll(items));

  @override
  String toString() => '${rtl ? 'R' : 'L'}[${items.join(' ')}]';
}

enum _Dir { r, l, n }

abstract final class PdfBidi {
  static final RegExp _controls = RegExp(r'[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]');
  static final RegExp _spaces = RegExp(r'[\t\u2000-\u200A\u202F\u205F\u3000]');

  /// Removes bidi / zero-width controls (no glyphs in the font), turns
  /// exotic spaces into plain ones and rewrites what the pdf package's bidi
  /// step cannot take (it throws on compatibility ligatures such as `…`,
  /// `ﷲ`, `ﻷ` and on a haraka right after a hamza letter such as `أُ`).
  static String clean(String text) {
    final s = text.replaceAll(_controls, '').replaceAll(_spaces, ' ').replaceAll('\r', '');
    final out = StringBuffer();
    var afterHamza = false;
    for (final c in s.runes) {
      final isMark = (c >= 0x064B && c <= 0x065F) || c == 0x0670;
      if (isMark && afterHamza) continue;
      afterHamza = c >= 0x0622 && c <= 0x0626;
      final mapped = _compat[c];
      if (mapped != null) {
        out.write(mapped);
      } else if ((c >= 0xFBDD && c <= 0xFDFF) || c == 0xFE70 || c == 0xFE71 || _unsafePunct.contains(c)) {
        // Other compatibility forms: dropped.
      } else {
        out.writeCharCode(c);
      }
    }
    return out.toString();
  }

  /// A last-resort cleaning, used only if a report failed to lay out with
  /// [clean]: every haraka dropped and anything outside basic Latin,
  /// Latin-1, Arabic letters / digits and a few dashes replaced by a space.
  static String strict(String text) {
    final out = StringBuffer();
    for (final c in clean(text).runes) {
      if ((c >= 0x064B && c <= 0x065F) || c == 0x0670) continue;
      final ok =
          (c >= 0x20 && c <= 0x7E) ||
          c == 0x0A ||
          (c >= 0xA0 && c <= 0x24F) ||
          (c >= 0x0600 && c <= 0x064A) ||
          (c >= 0x0660 && c <= 0x066D) ||
          (c >= 0x0671 && c <= 0x06D3) ||
          (c >= 0x06F0 && c <= 0x06F9) ||
          c == 0x2013 ||
          c == 0x2014 ||
          c == 0x2022 ||
          c == 0x2212;
      out.write(ok ? String.fromCharCode(c) : ' ');
    }
    return out.toString();
  }

  static const Map<int, String> _compat = {
    0x2026: '...',
    0x2025: '..',
    0x203C: '!!',
    0x2047: '??',
    0x2048: '?!',
    0x2049: '!?',
    0x2033: '"',
    0x2036: '"',
    0x2057: '"',
    0x2034: '"',
    0x2037: '"',
    0x2017: '_',
    0x203E: '-',
    0x0675: 'ا',
    0x0676: 'و',
    0x0677: 'ۇ',
    0x0678: 'ى',
    0xFEF5: 'لآ',
    0xFEF6: 'لآ',
    0xFEF7: 'لأ',
    0xFEF8: 'لأ',
    0xFEF9: 'لإ',
    0xFEFA: 'لإ',
    0xFEFB: 'لا',
    0xFEFC: 'لا',
    0xFDF2: 'الله',
  };

  static const Set<int> _unsafePunct = {
    0x2017, 0x2025, 0x2026, 0x2033, 0x2034, 0x2036, 0x2037, 0x203C, 0x203E, 0x2047, 0x2048, 0x2049, 0x2057, //
  };

  static bool isArabicLetter(int c) =>
      (c >= 0x0621 && c <= 0x064A) ||
      (c >= 0x066E && c <= 0x06D3) ||
      c == 0x06D5 ||
      (c >= 0x06FA && c <= 0x06FF) ||
      (c >= 0x0750 && c <= 0x077F) ||
      (c >= 0x08A0 && c <= 0x08FF) ||
      (c >= 0xFB50 && c <= 0xFDFF) ||
      (c >= 0xFE70 && c <= 0xFEFC);

  static bool isLatinLetter(int c) =>
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      (c >= 0xC0 && c <= 0x24F && c != 0xD7 && c != 0xF7) ||
      (c >= 0x370 && c <= 0x4FF) ||
      c == 0xB5; // µ

  static bool _hasWesternDigit(String s) => s.codeUnits.any((c) => c >= 0x30 && c <= 0x39);

  static _Dir _dirOf(String token) {
    var l = false;
    for (final c in token.runes) {
      if (isArabicLetter(c)) return _Dir.r;
      if (isLatinLetter(c)) l = true;
    }
    return l ? _Dir.l : _Dir.n;
  }

  /// Whether [text] contains an Arabic letter.
  static bool hasArabic(String text) => text.runes.any(isArabicLetter);

  /// Swaps paired brackets – the pdf package does not mirror them in
  /// right-to-left words.
  static String mirror(String s) {
    const pairs = {'(': ')', ')': '(', '[': ']', ']': '[', '{': '}', '}': '{'};
    final b = StringBuffer();
    for (final ch in s.split('')) {
      b.write(pairs[ch] ?? ch);
    }
    return b.toString();
  }

  /// A line (no newlines) as one plain word when it needs no reordering,
  /// else as items for a `Wrap` in the line's direction.
  static List<BidiItem> layout(String line, {required bool rtl}) {
    final tokens = clean(line).split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return const [];
    final dirs = [for (final t in tokens) _dirOf(t)];
    final base = rtl ? _Dir.r : _Dir.l;
    final other = rtl ? _Dir.l : _Dir.r;
    // Only base-direction words: the pdf package lays it out itself.
    if (dirs.every((d) => d == base)) {
      return [BidiWord(rtl ? mirror(tokens.join(' ')) : tokens.join(' '), rtl: rtl)];
    }
    if (!rtl && dirs.every((d) => d != _Dir.r)) return [BidiWord(tokens.join(' '), rtl: false)];

    final items = <BidiItem>[];
    var i = 0;
    while (i < tokens.length) {
      if (dirs[i] == other) {
        // An opposite-direction group: to the last opposite word before the
        // next base-direction word.
        var end = i;
        for (var j = i + 1; j < tokens.length && dirs[j] != base; j++) {
          if (dirs[j] == other) end = j;
        }
        // W7: a Western number right after a Latin group joins it.
        if (rtl && end + 1 < tokens.length && dirs[end + 1] == _Dir.n && _hasWesternDigit(tokens[end + 1])) end++;
        final group = tokens.sublist(i, end + 1);
        if (rtl) {
          items.add(BidiWord(group.join(' '), rtl: false));
        } else {
          items.add(
            group.length == 1
                ? BidiWord(mirror(group.single), rtl: true)
                : BidiSpan([
                    for (var k = i; k <= end; k++)
                      dirs[k] == _Dir.r ? BidiWord(mirror(tokens[k]), rtl: true) : BidiWord(tokens[k], rtl: false),
                  ], rtl: true),
          );
        }
        i = end + 1;
      } else if (dirs[i] == _Dir.r) {
        items.add(BidiWord(mirror(tokens[i]), rtl: true));
        i++;
      } else {
        // Latin words and neutrals in a left-to-right line, or a neutral
        // (number, symbol) in a right-to-left line: drawn left-to-right.
        items.add(BidiWord(tokens[i], rtl: false));
        i++;
      }
    }
    return items;
  }
}
