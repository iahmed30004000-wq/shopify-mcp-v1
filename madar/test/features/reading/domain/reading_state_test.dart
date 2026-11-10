import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/reading/domain/highlight.dart';
import 'package:madar/features/reading/domain/reading_position.dart';

final _t = DateTime(2026, 11, 10, 9);

/// A stand-in for the reader's paginator: a page holds `charsPerPage`
/// characters, which is what a bigger text scale changes.
int _pageOf(int offset, int charsPerPage) => offset ~/ charsPerPage;

void main() {
  group('ReadingPosition / Bookmark', () {
    test('JSON round-trip keeps page and scroll offset', () {
      final p = ReadingPosition(bookId: 'b', page: 41, scrollOffsetFraction: 0.375, updatedAt: _t);
      expect(ReadingPosition.fromJson(p.toJson()), p);
      expect(ReadingPosition.fromJson(p.toJson()).scrollOffsetFraction, 0.375);
    });

    test('the scroll offset is clamped to 0..1', () {
      expect(ReadingPosition(bookId: 'b', page: 0, scrollOffsetFraction: 3, updatedAt: _t).scrollOffsetFraction, 1);
      expect(ReadingPosition(bookId: 'b', page: 0, scrollOffsetFraction: -1, updatedAt: _t).scrollOffsetFraction, 0);
      expect(ReadingPosition(bookId: 'b', page: 0, scrollOffsetFraction: double.nan, updatedAt: _t).scrollOffsetFraction, 0);
    });

    test('Bookmark round-trips, label optional', () {
      final b = Bookmark(id: 'k', bookId: 'b', page: 3, scrollOffsetFraction: 0.5, label: 'قبل الفصل', createdAt: _t);
      expect(Bookmark.fromJson(b.toJson()), b);
      expect(Bookmark.fromJson(b.toJson()).label, 'قبل الفصل');
      expect(Bookmark.fromJson(Bookmark(id: 'k2', bookId: 'b', page: 0, createdAt: _t).toJson()).label, isNull);
    });
  });

  group('Highlight', () {
    const text = 'The quick brown fox jumps over the lazy dog. The quick brown fox sleeps.';

    Highlight pick(int start, int end) => Highlight.fromSelection(
      id: 'h',
      bookId: 'b',
      sectionId: 'ch1',
      sectionText: text,
      start: start,
      end: end,
      createdAt: _t,
      note: 'ملاحظتي',
    );

    test('keeps the words and a short context, and round-trips', () {
      final h = pick(4, 9);
      expect(h.text, 'quick');
      expect(h.before, 'The ');
      expect(h.after, startsWith(' brown fox'));
      expect(Highlight.fromJson(h.toJson()), h);
      expect(Highlight.fromJson(h.toJson()).note, 'ملاحظتي');
    });

    test('an empty selection is refused', () {
      expect(() => pick(4, 4), throwsArgumentError);
    });

    test('unchanged text keeps the same offsets', () {
      final h = pick(4, 9);
      final r = reanchor(h, text);
      expect(r.outcome, ReanchorOutcome.unchanged);
      expect(r.highlight, h);
    });

    test('text inserted before shifts the highlight with it', () {
      final h = pick(4, 9);
      final shifted = 'NEW CHAPTER INTRO. $text';
      final r = reanchor(h, shifted);
      expect(r.outcome, ReanchorOutcome.moved);
      expect(r.highlight!.start, 4 + 'NEW CHAPTER INTRO. '.length);
      expect(shifted.substring(r.highlight!.start, r.highlight!.end), 'quick');
    });

    test('with two copies of the words the context picks the right one', () {
      // Second "quick brown fox" is followed by "sleeps".
      final secondStart = text.lastIndexOf('quick');
      final h = pick(secondStart, secondStart + 5);
      final edited = 'Preface. ${text.replaceFirst('The quick brown fox jumps', 'The quick brown fox leaps')}';
      final r = reanchor(h, edited);
      expect(r.outcome, ReanchorOutcome.moved);
      expect(edited.substring(r.highlight!.end, r.highlight!.end + 14), startsWith(' brown fox sle'));
      expect(r.highlight!.start, edited.lastIndexOf('quick'));
    });

    test('identical copies with no matching context: nearest copy, flagged ambiguous', () {
      final h = Highlight(
        id: 'h', bookId: 'b', sectionId: 's', start: 12, end: 15, text: 'cat', before: 'zzzzzz', after: 'qqqqqq', createdAt: _t,
      );
      final r = reanchor(h, 'a cat. aaaaaaaaa cat. bbbbbbbbbbbbbbbbbbbbbbbbbbb cat.');
      expect(r.outcome, ReanchorOutcome.ambiguous);
      expect(r.highlight!.start, 'a cat. aaaaaaaaa '.length);
    });

    test('words that are gone are reported lost, never silently moved', () {
      final r = reanchor(pick(4, 9), 'Completely different text.');
      expect(r.outcome, ReanchorOutcome.lost);
      expect(r.highlight, isNull);
    });

    test('survives re-pagination at another text scale (anchored by characters, not pages)', () {
      final section = List.generate(40, (i) => 'Sentence number $i is here.').join(' ');
      final start = section.indexOf('number 17');
      final h = Highlight.fromSelection(
        id: 'h', bookId: 'b', sectionId: 's', sectionText: section, start: start, end: start + 9, createdAt: _t,
      );
      // At scale 1.0 a page holds 200 characters, at 1.3 only 120: the page
      // number of the highlight changes, the highlight does not.
      final p10 = _pageOf(h.start, 200);
      final p13 = _pageOf(h.start, 120);
      expect(p10, isNot(p13));
      final r = reanchor(Highlight.fromJson(h.toJson()), section);
      expect(r.outcome, ReanchorOutcome.unchanged);
      expect(section.substring(r.highlight!.start, r.highlight!.end), 'number 17');
    });

    test('a highlight spanning a page break stays one highlight on both pages', () {
      final section = '${'x' * 195}break across pages${'y' * 100}';
      final h = Highlight.fromSelection(
        id: 'h', bookId: 'b', sectionId: 's', sectionText: section, start: 195, end: 213, createdAt: _t,
      );
      expect(_pageOf(h.start, 200), 0);
      expect(_pageOf(h.end - 1, 200), 1);
      expect(h.length, 18);
      // At a larger text scale the whole highlight sits on one page.
      expect(_pageOf(h.start, 400), _pageOf(h.end - 1, 400));
    });
  });
}
