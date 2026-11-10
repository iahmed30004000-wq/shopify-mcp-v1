import 'package:flutter/widgets.dart';

/// Which side of the page the book's spine is on.
enum SpineSide { left, right }

/// The reading direction of the BOOK (not of the app's UI language).
///
/// An Arabic book is [rtl]: it opens from the right, the spine is on the
/// right, the free edge of a page is its left edge, and the page is turned by
/// dragging that edge over to the right. An English book is [ltr], mirrored.
/// A Arabic book read inside an English UI (or the reverse) must therefore
/// behave by its own language, which is why nothing here looks at the ambient
/// [Directionality].
enum BookDirection {
  rtl,
  ltr;

  bool get isRtl => this == BookDirection.rtl;

  TextDirection get textDirection => isRtl ? TextDirection.rtl : TextDirection.ltr;

  /// The spine of a single page (or of a facing pair, at its centre).
  SpineSide get spine => isRtl ? SpineSide.right : SpineSide.left;

  /// Unit x-direction a finger travels to turn FORWARD (free edge -> spine):
  /// +1 (left to right) for an Arabic book, -1 (right to left) for English.
  double get forwardSign => isRtl ? 1.0 : -1.0;

  static BookDirection fromTextDirection(TextDirection d) =>
      d == TextDirection.rtl ? BookDirection.rtl : BookDirection.ltr;
}

/// What the reader wants to do.
enum TurnIntent { next, previous }
