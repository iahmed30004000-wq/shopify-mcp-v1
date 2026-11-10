import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/reading/presentation/page_turn/book_direction.dart';
import 'package:madar/features/reading/presentation/page_turn/spread_layout.dart';
import 'package:madar/features/reading/presentation/page_turn/turn_logic.dart';

void main() {
  group('direction mapping', () {
    test('an English book turns right-to-left: the finger moves left for "next"', () {
      expect(intentForDrag(BookDirection.ltr, -40), TurnIntent.next);
      expect(intentForDrag(BookDirection.ltr, 40), TurnIntent.previous);
      expect(BookDirection.ltr.spine, SpineSide.left);
      expect(BookDirection.ltr.forwardSign, -1);
    });

    test('an Arabic book opens from the right: spine right, the finger moves right for "next"', () {
      expect(intentForDrag(BookDirection.rtl, 40), TurnIntent.next);
      expect(intentForDrag(BookDirection.rtl, -40), TurnIntent.previous);
      expect(BookDirection.rtl.spine, SpineSide.right);
      expect(BookDirection.rtl.forwardSign, 1);
    });

    test('no movement is no intent', () {
      expect(intentForDrag(BookDirection.ltr, 0), isNull);
    });

    test('the book decides, never the UI: the mapping has no UI-direction input', () {
      // An Arabic book under an English UI and an English book under an
      // Arabic UI: the only input is the book's own direction.
      final arabicBookEnglishUi = BookDirection.rtl;
      final englishBookArabicUi = BookDirection.ltr;
      expect(intentForDrag(arabicBookEnglishUi, 10), TurnIntent.next);
      expect(intentForDrag(englishBookArabicUi, 10), TurnIntent.previous);
      expect(BookDirection.fromTextDirection(TextDirection.rtl), BookDirection.rtl);
      expect(BookDirection.fromTextDirection(TextDirection.ltr), BookDirection.ltr);
    });

    test('a mixed book (Arabic with English passages) follows its main language: one direction for the whole book', () {
      // A mixed book is still ONE BookDirection; the passages are laid out by
      // their own text direction inside the page.
      const mixed = BookDirection.rtl;
      for (final dx in [-120.0, -5.0, 5.0, 120.0]) {
        expect(intentForDrag(mixed, dx), dx > 0 ? TurnIntent.next : TurnIntent.previous);
      }
    });
  });

  group('tap zones', () {
    test('English: right edge next, left edge previous, middle nothing', () {
      expect(intentForTap(BookDirection.ltr, 390, 400), TurnIntent.next);
      expect(intentForTap(BookDirection.ltr, 10, 400), TurnIntent.previous);
      expect(intentForTap(BookDirection.ltr, 200, 400), isNull);
    });

    test('Arabic: left edge next, right edge previous', () {
      expect(intentForTap(BookDirection.rtl, 10, 400), TurnIntent.next);
      expect(intentForTap(BookDirection.rtl, 390, 400), TurnIntent.previous);
      expect(intentForTap(BookDirection.rtl, 200, 400), isNull);
    });

    test('zones are at least 48 wide even on a narrow reader', () {
      expect(intentForTap(BookDirection.ltr, 300 - 47, 300), TurnIntent.next);
      expect(intentForTap(BookDirection.ltr, 47, 300), TurnIntent.previous);
    });
  });

  group('grab point', () {
    const leaf = Rect.fromLTWH(0, 0, 300, 400);

    test('near the bottom or top the corner is grabbed, otherwise the edge at that height', () {
      expect(grabPoint(leaf: leaf, spine: SpineSide.left, startY: 380), const Offset(300, 400));
      expect(grabPoint(leaf: leaf, spine: SpineSide.left, startY: 20), const Offset(300, 0));
      expect(grabPoint(leaf: leaf, spine: SpineSide.left, startY: 200), const Offset(300, 200));
      expect(grabPoint(leaf: leaf, spine: SpineSide.right, startY: 380), const Offset(0, 400));
      expect(isCornerGrab(leaf, const Offset(300, 400)), isTrue);
      expect(isCornerGrab(leaf, const Offset(300, 200)), isFalse);
    });
  });

  group('commit decision', () {
    test('distance decides when slow; fling overrides', () {
      expect(shouldCommitTurn(travel: 0.3, velocityTowardCommit: 0), isTrue);
      expect(shouldCommitTurn(travel: 0.1, velocityTowardCommit: 0), isFalse);
      expect(shouldCommitTurn(travel: 0.02, velocityTowardCommit: 900), isTrue);
      expect(shouldCommitTurn(travel: 0.6, velocityTowardCommit: -900), isFalse);
    });
  });

  group('spreads', () {
    test('cover alone, then 1+2, 3+4; an odd last page stands alone', () {
      const s = PageSpreads(6); // pages 0..5
      expect(s.count, 4);
      expect([for (var p = 0; p < 6; p++) s.spreadOfPage(p)], [0, 1, 1, 2, 2, 3]);
      expect(s.startSidePage(0), isNull);
      expect(s.leafSidePage(0), 0);
      expect((s.startSidePage(1), s.leafSidePage(1)), (1, 2));
      expect((s.startSidePage(2), s.leafSidePage(2)), (3, 4));
      expect((s.startSidePage(3), s.leafSidePage(3)), (5, null));
      expect([for (var i = 0; i < 4; i++) s.firstPage(i)], [0, 1, 3, 5]);
    });

    test('counts for 0, 1, 2, 3 pages', () {
      expect(const PageSpreads(0).count, 0);
      expect(const PageSpreads(1).count, 1);
      expect(const PageSpreads(2).count, 2);
      expect(const PageSpreads(3).count, 2);
    });

    test('landscape by aspect ratio only', () {
      expect(PageSpreads.shouldSpread(const Size(800, 400), enabled: true), isTrue);
      expect(PageSpreads.shouldSpread(const Size(400, 800), enabled: true), isFalse);
      expect(PageSpreads.shouldSpread(const Size(800, 700), enabled: true), isFalse);
      expect(PageSpreads.shouldSpread(const Size(800, 400), enabled: false), isFalse);
    });

    test('rects: English leaf is the right half, Arabic the left half', () {
      final en = ReaderRects.compute(const Size(800, 400), BookDirection.ltr, spread: true);
      expect(en.leaf, const Rect.fromLTWH(400, 0, 400, 400));
      expect(en.other, const Rect.fromLTWH(0, 0, 400, 400));
      expect(en.spine, SpineSide.left);
      final ar = ReaderRects.compute(const Size(800, 400), BookDirection.rtl, spread: true);
      expect(ar.leaf, const Rect.fromLTWH(0, 0, 400, 400));
      expect(ar.other, const Rect.fromLTWH(400, 0, 400, 400));
      expect(ar.spine, SpineSide.right);
      final single = ReaderRects.compute(const Size(400, 800), BookDirection.rtl, spread: false);
      expect(single.leaf, const Rect.fromLTWH(0, 0, 400, 800));
      expect(single.other, isNull);
    });
  });
}
