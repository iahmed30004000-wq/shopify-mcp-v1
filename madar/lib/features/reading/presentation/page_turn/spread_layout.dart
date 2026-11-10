import 'dart:ui';

import 'book_direction.dart';

/// How the pages are grouped when two face each other (a phone held sideways).
///
/// Spread 0 is the cover: page 0 alone, on the side where reading continues
/// (the right half of an English book, the left half of an Arabic one: it is
/// the mirror of a real book lying open). Spread s >= 1 holds pages
/// (2s-1, 2s): the first in reading order sits on the reading-start side
/// (left for English, right for Arabic). So pages 1+2, 3+4 ... face each
/// other, and an odd last page stands alone.
class PageSpreads {
  const PageSpreads(this.pageCount);

  final int pageCount;

  int get count => pageCount <= 0 ? 0 : 1 + pageCount ~/ 2;

  int spreadOfPage(int page) => (page + 1) ~/ 2;

  /// The lowest page shown by spread [s] (what "current page" reports).
  int firstPage(int s) => s <= 0 ? 0 : 2 * s - 1;

  /// Page on the reading-start side of spread [s] (null on the cover).
  int? startSidePage(int s) {
    final p = 2 * s - 1;
    return (p >= 0 && p < pageCount) ? p : null;
  }

  /// Page on the reading-end side of spread [s]: the one that is turned.
  int? leafSidePage(int s) {
    final p = 2 * s;
    return (p >= 0 && p < pageCount) ? p : null;
  }

  static bool shouldSpread(Size size, {required bool enabled, double minAspect = 1.2}) {
    if (!enabled || size.isEmpty) return false;
    return size.width / size.height >= minAspect;
  }
}

/// Screen rectangles of a reader of [size].
class ReaderRects {
  const ReaderRects._({
    required this.spread,
    required this.leaf,
    required this.other,
    required this.spine,
    required this.backBounds,
    required this.full,
  });

  factory ReaderRects.compute(Size size, BookDirection direction, {required bool spread}) {
    final full = Offset.zero & size;
    if (!spread) {
      return ReaderRects._(
        spread: false,
        leaf: full,
        other: null,
        spine: direction.spine,
        backBounds: full,
        full: full,
      );
    }
    final half = size.width / 2;
    final left = Rect.fromLTWH(0, 0, half, size.height);
    final right = Rect.fromLTWH(half, 0, half, size.height);
    // English: the turned leaf is the right half (spine at the centre, on its
    // left). Arabic: the left half (spine on its right).
    return ReaderRects._(
      spread: true,
      leaf: direction.isRtl ? left : right,
      other: direction.isRtl ? right : left,
      spine: direction.isRtl ? SpineSide.right : SpineSide.left,
      backBounds: full,
      full: full,
    );
  }

  final bool spread;

  /// The rectangle that is turned (the whole reader when single).
  final Rect leaf;

  /// The static facing half (spread only).
  final Rect? other;
  final SpineSide spine;

  /// Where the back of the leaf may be drawn (it crosses the spine in a
  /// spread; in a single page it would be off-screen anyway).
  final Rect backBounds;
  final Rect full;
}
