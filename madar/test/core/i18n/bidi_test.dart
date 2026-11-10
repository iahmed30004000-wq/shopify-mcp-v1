// Mixed Arabic / English text: first-strong direction for the user's own
// words, and isolation of embedded names so neighbouring punctuation and
// numbers never jump.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/formatters.dart';

/// Left edge of the glyph for the code unit at [index] when [text] is laid
/// out in a paragraph of [direction].
double _xOf(String text, int index, TextDirection direction, {TextDirection? content}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: const TextStyle(fontSize: 20)),
    textDirection: content ?? direction,
  )..layout();
  final boxes = painter.getBoxesForSelection(TextSelection(baseOffset: index, extentOffset: index + 1));
  painter.dispose();
  return boxes.first.left;
}

void main() {
  group('BidiIsolate.directionOf (dir="auto")', () {
    test('the first strong character decides', () {
      expect(BidiIsolate.directionOf('Call Mum!'), TextDirection.ltr);
      expect(BidiIsolate.directionOf('الاتصال بالوالدة'), TextDirection.rtl);
      expect(BidiIsolate.directionOf('3 x Call'), TextDirection.ltr);
      expect(BidiIsolate.directionOf('١٢ مهمة'), TextDirection.rtl);
      expect(BidiIsolate.directionOf('(Ahmed) أحمد'), TextDirection.ltr);
      expect(BidiIsolate.directionOf('«أحمد» Ahmed'), TextDirection.rtl);
      expect(BidiIsolate.directionOf('Ünïcödé'), TextDirection.ltr);
      expect(BidiIsolate.directionOf('Привет'), TextDirection.ltr);
      expect(BidiIsolate.directionOf('שלום'), TextDirection.rtl);
    });

    test('no strong character → no opinion', () {
      expect(BidiIsolate.directionOf(''), isNull);
      expect(BidiIsolate.directionOf('123 – 456'), isNull);
      expect(BidiIsolate.directionOf('!?'), isNull);
    });

    test('isolation marks are not strong', () {
      expect(BidiIsolate.directionOf(BidiIsolate.isolate('Ahmed')), TextDirection.ltr);
    });

    test('Arabic-Indic digits, harakat and Arabic punctuation are weak, not strong (bidi P2)', () {
      // A title that starts with a year in the user's digits is still English.
      expect(BidiIsolate.directionOf('٢٠٢٦ Budget'), TextDirection.ltr);
      expect(BidiIsolate.directionOf('۱۲ Main St'), TextDirection.ltr);
      expect(BidiIsolate.directionOf('٪٥٠ off'), TextDirection.ltr);
      expect(BidiIsolate.directionOf('ً، Hi'), TextDirection.ltr);
      expect(BidiIsolate.directionOf('١٢٣'), isNull);
    });

    test('scripts beyond Latin, Greek and Cyrillic', () {
      expect(BidiIsolate.directionOf('東京 trip'), TextDirection.ltr);
      expect(BidiIsolate.directionOf('Tiếng Việt'), TextDirection.ltr);
      expect(BidiIsolate.directionOf('नमस्ते'), TextDirection.ltr);
      expect(BidiIsolate.directionOf('🙂 أهلًا'), TextDirection.rtl);
      expect(BidiIsolate.directionOf('ܫܠܡܐ'), TextDirection.rtl); // Syriac
    });

    test('directional marks are strong; isolated runs are skipped', () {
      expect(BidiIsolate.directionOf('‏123 abc'), TextDirection.rtl);
      expect(BidiIsolate.directionOf('‎١٢ مهمة'), TextDirection.ltr);
      // A Latin name isolated at the start of an Arabic sentence.
      expect(BidiIsolate.directionOf('${BidiIsolate.isolate('Ahmed')} يتصل بك'), TextDirection.rtl);
      expect(BidiIsolate.directionOf('${BidiIsolate.isolate('أحمد')} is calling'), TextDirection.ltr);
    });
  });

  group('rendering (the reason it matters)', () {
    test('"Call Mum!" in an Arabic layout keeps its "!" at the end when laid out by its own direction', () {
      const title = 'Call Mum!';
      final bang = title.indexOf('!');
      // Naively in an RTL paragraph the "!" jumps to the far left.
      expect(_xOf(title, bang, TextDirection.rtl), lessThan(_xOf(title, 0, TextDirection.rtl)));
      // With the first-strong direction it stays after "Mum".
      final own = BidiIsolate.directionOf(title);
      expect(
        _xOf(title, bang, TextDirection.rtl, content: own),
        greaterThan(_xOf(title, 0, TextDirection.rtl, content: own)),
      );
    });

    test('an isolated Latin name inside Arabic keeps the Arabic punctuation after it', () {
      final sentence = 'تواصلت مع ${BidiIsolate.isolate('Ahmed 2')}.';
      final painter = TextPainter(
        text: TextSpan(text: sentence, style: const TextStyle(fontSize: 20)),
        textDirection: TextDirection.rtl,
      )..layout();
      final dot = sentence.lastIndexOf('.');
      final a = sentence.indexOf('A');
      final dotBox = painter.getBoxesForSelection(TextSelection(baseOffset: dot, extentOffset: dot + 1)).first;
      final aBox = painter.getBoxesForSelection(TextSelection(baseOffset: a, extentOffset: a + 1)).first;
      // In RTL the sentence ends on the left: the full stop sits left of the
      // whole name, not between "Ahmed" and "2".
      expect(dotBox.left, lessThan(aBox.left));
      painter.dispose();
    });
  });
}
