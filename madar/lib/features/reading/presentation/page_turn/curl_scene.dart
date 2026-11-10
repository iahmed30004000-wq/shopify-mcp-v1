import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'curl_geometry.dart';
import 'spread_layout.dart';

/// Everything one turn needs to be drawn, and the single place the moving
/// touch point lives. The painters listen to it directly, so a frame of the
/// drag repaints without rebuilding any widget.
///
/// The images (all optional: a missing one is drawn as blank paper) are
/// clones owned by the scene and released by [dispose]:
///  * [front]: the leaf's front (the page that is being turned),
///  * [under]: the page that appears under it,
///  * [back]: spread only, the real page on the back of the leaf,
///  * [other]: spread only, the static facing page.
/// In a single-page reader the back of the leaf is its own front, mirrored.
class CurlScene extends ChangeNotifier {
  CurlScene({
    required this.rects,
    required this.grab,
    required Offset touch,
    required this.paperTint,
    this.front,
    this.under,
    this.back,
    this.other,
  }) : shadowExtent = rects.leaf.width * 0.07 {
    _geometry = _make(touch);
  }

  final ReaderRects rects;
  final Offset grab;
  final Color paperTint;
  final double shadowExtent;
  final ui.Image? front;
  final ui.Image? under;
  final ui.Image? back;
  final ui.Image? other;

  late CurlGeometry _geometry;

  CurlGeometry get geometry => _geometry;

  CurlGeometry _make(Offset touch) => CurlGeometry(
    leaf: rects.leaf,
    spine: rects.spine,
    grab: grab,
    touch: touch,
    backBounds: rects.backBounds,
    shadowExtent: shadowExtent,
  );

  void moveTouch(Offset touch) {
    _geometry = _make(touch);
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    front?.dispose();
    under?.dispose();
    back?.dispose();
    other?.dispose();
    super.dispose();
  }
}
