/// Text helpers of the day chat: a fold that remembers where every letter
/// came from (so a piece's span still points at his own words), and the name
/// matching the reader uses to recognise his own things.
///
/// The folding rules are the search engine's (`SearchText`), the person
/// matching is the family's (`FamilyTexts.matchForm`) and the digits are
/// `LocalizedNumbers`'. Nothing here is a second folder: it adds the one
/// thing `SearchText.fold` does not promise – an index back into the raw
/// text.
library;

import 'package:meta/meta.dart';

import '../../../core/interaction/numbers.dart';
import '../../search/domain/search_text.dart';
import 'day_chat_piece.dart' show DayChatSpan;

/// His line, folded for matching, with the way back to what he typed.
@immutable
class FoldedText {
  const FoldedText(this.raw, this.folded, this.origins);

  /// The text exactly as he typed it.
  final String raw;

  /// Folded: Arabic-Indic and Persian digits as `0-9`, every alef form as
  /// `ا`, `ة`→`ه`, `ى ئ ی`→`ي`, `ؤ`→`و`, `ک`→`ك`, ASCII lower-cased, and
  /// Arabic marks, tatweel and invisible characters dropped.
  final String folded;

  /// For each code unit of [folded], the index in [raw] it came from.
  final List<int> origins;

  bool get isEmpty => folded.trim().isEmpty;

  /// The raw range of the folded range `[start, end)`.
  DayChatSpan rawSpan(int start, int end) {
    if (origins.isEmpty) return const DayChatSpan(0, 0);
    final s = start.clamp(0, origins.length - 1);
    if (end <= start) return DayChatSpan(origins[s], origins[s]);
    final e = (end - 1).clamp(0, origins.length - 1);
    return DayChatSpan(origins[s], origins[e] + 1);
  }

  /// The folded text of a folded range.
  String slice(int start, int end) =>
      folded.substring(start.clamp(0, folded.length), end.clamp(0, folded.length));
}

abstract final class DayChatText {
  /// Arabic short vowels, shadda, sukun, the dagger alef, tatweel and the
  /// Quranic annotation signs.
  static final RegExp _marks = RegExp('[ً-ٰٟـۖ-ۭ]');

  /// Bidi marks and isolates, the zero-width characters and the BOM.
  static final RegExp _invisible = RegExp(
    '[\u200B-\u200F\u202A-\u202E\u2066-\u2069\u061C\uFEFF]',
    unicode: true,
  );

  static bool _drop(int c) =>
      _marks.hasMatch(String.fromCharCode(c)) || _invisible.hasMatch(String.fromCharCode(c));

  /// Folds [raw] for matching and keeps the way back to it.
  static FoldedText fold(String raw) {
    final digits = LocalizedNumbers.normalizeDigits(raw);
    final out = StringBuffer();
    final origins = <int>[];
    for (var i = 0; i < digits.length; i++) {
      final c = digits.codeUnitAt(i);
      if (_drop(c)) continue;
      out.writeCharCode(switch (c) {
        0x0622 || 0x0623 || 0x0625 || 0x0671 => 0x0627,
        0x0629 => 0x0647,
        0x0649 || 0x0626 || 0x06CC => 0x064A,
        0x0624 => 0x0648,
        0x06A9 => 0x0643,
        0x00A0 || 0x202F || 0x2007 => 0x20,
        >= 0x41 && <= 0x5A => c + 32,
        _ => c,
      });
      origins.add(i);
    }
    return FoldedText(raw, out.toString(), origins);
  }

  /// Whitespace and the punctuation a piece never starts or ends with.
  static final RegExp _edges = RegExp(r'[\s ،؛,;:\-–—…\.!؟?"«»\(\)\[\]ـ]+', unicode: true);

  /// [start]..[end] of [text] without its leading and trailing whitespace
  /// and punctuation.
  static (int, int) trimRange(String text, int start, int end) {
    var s = start, e = end;
    while (s < e && _edges.hasMatch(text[s])) {
      s++;
    }
    while (e > s && _edges.hasMatch(text[e - 1])) {
      e--;
    }
    return (s, e);
  }

  /// The search engine's words of [text] (folded, Arabic-aware).
  static List<String> terms(String text) => SearchText.terms(text);

  /// One comparable key for a name he typed and a name he saved: the search
  /// engine's words, in order, joined by one space. «أمي» and «امي» match,
  /// «غداء» and «غدا» do not.
  static String nameKey(String text) => terms(text).join(' ');

  /// True when [needle]'s words appear, in order and whole, inside
  /// [haystack]'s words – «تقرير الشغل» matches his task «تقرير الشغل
  /// للمدير».
  static bool containsWords(String haystack, String needle) {
    final n = terms(needle);
    if (n.isEmpty) return false;
    final h = terms(haystack);
    if (n.length > h.length) return false;
    for (var i = 0; i + n.length <= h.length; i++) {
      var hit = true;
      for (var j = 0; j < n.length; j++) {
        if (h[i + j] != n[j]) {
          hit = false;
          break;
        }
      }
      if (hit) return true;
    }
    return false;
  }

  /// The range of [needle] inside [text] (its own words, Arabic folded), or
  /// null – so a module's name can point at the exact letters he typed.
  static (int, int)? rangeOf(String text, String needle) {
    final n = terms(needle);
    if (n.isEmpty) return null;
    final tokens = SearchText.tokenize(text);
    for (var i = 0; i + n.length <= tokens.length; i++) {
      var hit = true;
      for (var j = 0; j < n.length; j++) {
        if (tokens[i + j].term != n[j]) {
          hit = false;
          break;
        }
      }
      if (hit) return (tokens[i].start, tokens[i + n.length - 1].end);
    }
    return null;
  }
}
