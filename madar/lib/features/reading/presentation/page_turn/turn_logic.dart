import 'dart:ui';

import 'book_direction.dart';

/// Pure decisions of the page turn (gesture to intent, grab point, commit),
/// kept free of widgets so they can be tested with plain numbers.

/// Unit vector from a page's free edge towards its spine.
Offset towardSpine(SpineSide spine) => Offset(spine == SpineSide.left ? -1 : 1, 0);

/// A horizontal drag of [dx] (positive = finger moved right) means:
/// the finger travelling in [BookDirection.forwardSign]'s way is "next".
TurnIntent? intentForDrag(BookDirection direction, double dx) {
  if (dx == 0) return null;
  return (dx.sign == direction.forwardSign) ? TurnIntent.next : TurnIntent.previous;
}

/// A tap at [x] of a [width]-wide reader. The edge a book is turned by is its
/// free edge: the right edge of an English book, the left edge of an Arabic
/// one; the opposite edge goes back. The middle does nothing.
TurnIntent? intentForTap(
  BookDirection direction,
  double x,
  double width, {
  double edgeFraction = 0.2,
  double minZone = 48,
}) {
  if (width <= 0) return null;
  final zone = (width * edgeFraction).clamp(minZone, width / 2).toDouble();
  final nextOnRight = !direction.isRtl;
  if (x >= width - zone) return nextOnRight ? TurnIntent.next : TurnIntent.previous;
  if (x <= zone) return nextOnRight ? TurnIntent.previous : TurnIntent.next;
  return null;
}

/// Where the page is grabbed: on its free edge, at the touched height; near
/// the top or bottom the corner itself (a corner curl).
Offset grabPoint({
  required Rect leaf,
  required SpineSide spine,
  required double startY,
  double cornerBand = 0.28,
}) {
  final x = spine == SpineSide.left ? leaf.right : leaf.left;
  final band = leaf.height * cornerBand;
  final double y;
  if (startY >= leaf.bottom - band) {
    y = leaf.bottom;
  } else if (startY <= leaf.top + band) {
    y = leaf.top;
  } else {
    y = startY;
  }
  return Offset(x, y);
}

bool isCornerGrab(Rect leaf, Offset grab) => grab.dy <= leaf.top + 0.5 || grab.dy >= leaf.bottom - 0.5;

/// Where the grabbed point rests once the page lies fully turned over the
/// spine (it is a mirror image of [grab] across the spine line).
Offset restTouch(Rect leaf, SpineSide spine, Offset grab) {
  final u = towardSpine(spine);
  return grab + u * (2 * leaf.width);
}

/// 0 = page flat in place, 1 = fully turned over.
double turnProgress(Rect leaf, SpineSide spine, Offset grab, Offset touch) {
  if (leaf.width <= 0) return 0;
  final u = towardSpine(spine);
  final along = (touch - grab).dx * u.dx;
  return (along / (2 * leaf.width)).clamp(0.0, 1.0).toDouble();
}

/// Release decision. [travel] is how far the page already moved towards the
/// target it would reach if it completes (0..1 of the whole path),
/// [velocityTowardCommit] the finger speed towards completing (px/s, negative
/// when flinging back).
bool shouldCommitTurn({
  required double travel,
  required double velocityTowardCommit,
  double travelThreshold = 0.2,
  double flingVelocity = 700,
}) {
  if (velocityTowardCommit > flingVelocity) return true;
  if (velocityTowardCommit < -flingVelocity) return false;
  return travel > travelThreshold;
}
