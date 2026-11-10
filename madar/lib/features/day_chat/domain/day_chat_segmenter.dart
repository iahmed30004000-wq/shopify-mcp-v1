/// Cuts one typed line into the separate things he said.
///
/// He types his day the way he talks: «صرفت ٥ دنانير قهوة، صليت العصر
/// بالمسجد، تمرين صدر ٤×١٢، وجع الركبة ٦». Sometimes with commas, sometimes
/// with «و» glued to the next word, sometimes with nothing at all. The
/// segmenter finds the cuts and keeps, for every piece, the exact range of
/// the text **as he typed it**.
///
/// Pure Dart.
library;

import 'day_chat_piece.dart' show DayChatSpan;
import 'day_chat_text.dart';

/// One thing he said, with its place in his line.
class DayChatSegment {
  const DayChatSegment({
    required this.source,
    required this.span,
    required this.foldedStart,
    required this.foldedEnd,
  });

  /// His whole line, folded, with the way back to the raw text.
  final FoldedText source;

  /// Where this segment is in the raw text.
  final DayChatSpan span;

  /// Where it is in the folded text (the reader matches on this).
  final int foldedStart;
  final int foldedEnd;

  /// His own words.
  String get text => span.of(source.raw);

  /// The folded words (digits western, Arabic unified) the reader reads.
  String get folded => source.slice(foldedStart, foldedEnd);

  /// The raw span of a range of [folded] (offsets inside this segment).
  DayChatSpan rawSpanOf(int start, int end) =>
      source.rawSpan(foldedStart + start, foldedStart + end);

  @override
  String toString() => 'DayChatSegment(«$text», ${span.start}..${span.end})';
}

abstract final class DayChatSegmenter {
  /// Punctuation that always ends a piece. A full stop or a comma between
  /// two digits does not (it is «١٢٫٥» or «12,5»).
  static const Set<String> _breaks = {'\n', '\r', ',', ';', '؛', '!', '?', '؟', '…', '|', '•'};

  /// The words that start a new fact. Folded (no hamza on the alef, no
  /// marks): «أكلت» is «اكلت», «ألم» is «الم».
  static final RegExp _starter = RegExp(
    '^(?:'
    'صرفت|صرفنا|دفعت|دفعنا|اشتريت|اشترينا|شريت|شرينا|سددت|سددنا|'
    'قبضت|قبضنا|استلمت|ربحت|كسبت|'
    'اكلت|كلت|تغديت|اتغديت|تعشيت|اتعشيت|فطرت|افطرت|تفطرت|'
    'شربت|'
    'تمرنت|تدربت|تمرين|تمرينه|'
    'صليت|صلينا|فاتتني|فوتت|'
    'وجعني|اوجعني|بيوجعني|يوجعني|'
    'مزاجي|نفسيتي|'
    'كلمت|اتصلت|رنيت|زرت|بعتت|بعثت|راسلت|ارسلت|'
    'خلصت|خلصنا|انجزت|انهيت|'
    'لازم|ضروري|ذكرني|'
    'spent|paid|bought|ate|drank|prayed|called|visited|finished'
    r')(?![\p{L}\p{N}_])',
    unicode: true,
  );

  /// Words that start a fact but also begin with «و», so the conjunction
  /// rule must not cut them in half («وجع الركبة ٦», «وصلني حوالة»).
  static final RegExp _wawWord = RegExp(r'^(?:وجع|وجعني|وصلني|وصلتني|وزن|ورد|وقت)(?![\p{L}\p{N}_])', unicode: true);

  /// The segments of [raw], in the order he typed them. Empty input gives
  /// an empty list; a line with nothing but punctuation gives none either.
  static List<DayChatSegment> split(String raw) {
    final src = DayChatText.fold(raw);
    final f = src.folded;
    if (f.trim().isEmpty) return const [];
    final cuts = <int>[0];
    var wordsInSegment = 0;
    var i = 0;
    while (i < f.length) {
      final c = f[i];
      // 1. Hard punctuation.
      if (_breaks.contains(c) || (c == '.' && !_betweenDigits(f, i)) || (c == ',' && !_betweenDigits(f, i))) {
        if (i + 1 < f.length) cuts.add(i + 1);
        wordsInSegment = 0;
        i++;
        continue;
      }
      // 2. Word starts.
      if (_isWordStart(f, i)) {
        final rest = f.substring(i);
        var cut = false;
        var skipWaw = false;
        if (wordsInSegment > 0) {
          // «وصليت» / «و صليت»: the conjunction plus a starter.
          if (rest.codeUnitAt(0) == DayChatWaw.code && !_wawWord.hasMatch(rest)) {
            final tail = rest.substring(1);
            final after = tail.trimLeft();
            if (_starter.hasMatch(after)) {
              cut = true;
              // A conjunction standing alone belongs to neither piece.
              skipWaw = tail.length != after.length;
            }
          }
          // A starter verb on its own, with no punctuation before it: only
          // once the piece so far says something («خلصت تمرين صدر» stays
          // one piece, «صرفت ٥ قهوة صليت العصر» becomes two).
          if (!cut && wordsInSegment >= 2 && _starter.hasMatch(rest)) cut = true;
        }
        if (cut) {
          cuts.add(skipWaw ? i + (rest.length - rest.substring(1).trimLeft().length) : i);
          wordsInSegment = 1;
        } else {
          wordsInSegment++;
        }
        // Skip to the end of the word.
        while (i < f.length && _isWordChar(f.codeUnitAt(i))) {
          i++;
        }
        continue;
      }
      i++;
    }
    cuts.add(f.length);

    final out = <DayChatSegment>[];
    for (var k = 0; k + 1 < cuts.length; k++) {
      final (s, e) = DayChatText.trimRange(f, cuts[k], cuts[k + 1]);
      if (e <= s) continue;
      if (f.substring(s, e).trim().isEmpty) continue;
      out.add(DayChatSegment(source: src, span: src.rawSpan(s, e), foldedStart: s, foldedEnd: e));
    }
    return out;
  }

  static bool _betweenDigits(String f, int i) =>
      i > 0 && i + 1 < f.length && _isDigit(f.codeUnitAt(i - 1)) && _isDigit(f.codeUnitAt(i + 1));

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  static bool _isWordChar(int c) =>
      _isDigit(c) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      (c >= 0x0620 && c <= 0x064A) ||
      (c >= 0x0671 && c <= 0x06D3) ||
      c == 0x5F;

  static bool _isWordStart(String f, int i) =>
      _isWordChar(f.codeUnitAt(i)) && (i == 0 || !_isWordChar(f.codeUnitAt(i - 1)));
}

/// The Arabic conjunction, as one code unit.
abstract final class DayChatWaw {
  static const int code = 0x0648;
}
