import 'dart:ui';

import '../ink/ink_build.dart';

/// Period headwear, drawn sitting on a head whose crown is at ([x], [y]),
/// [w] = hat width, [tilt] radians (+ = tipped forward/right).
abstract final class Hats {
  /// Straw boater: flat crown, wide brim, striped band (vaudeville).
  static void boater(
    InkBuild b,
    double x,
    double y,
    double w,
    double tilt, {
    required Color fill,
    required Color band,
  }) {
    final pen = b.pen
      ..save()
      ..rotateAbout(tilt, x, y)
      ..translate(x, y);
    b.layer();
    b.shape(fill);
    pen.ellipse(0, 0, w * 0.62, w * 0.1);
    b.shape(fill);
    pen.roundRect(-w * 0.34, -w * 0.3, w * 0.34, -w * 0.02, w * 0.05);
    b.shape(fill);
    pen.ellipse(0, -w * 0.3, w * 0.34, w * 0.06);
    b.fill(band);
    pen.roundRect(-w * 0.34, -w * 0.16, w * 0.34, -w * 0.05, w * 0.01);
    b.inkLine(b.lw * 0.6);
    pen
      ..moveTo(-w * 0.34, -w * 0.16)
      ..lineTo(w * 0.34, -w * 0.16);
    b.endLayer();
    pen.restore();
  }

  /// Bowler (derby): a dome with a curled brim.
  static void bowler(
    InkBuild b,
    double x,
    double y,
    double w,
    double tilt, {
    required Color fill,
    required Color band,
  }) {
    final pen = b.pen
      ..save()
      ..rotateAbout(tilt, x, y)
      ..translate(x, y);
    b.layer();
    b.shape(fill);
    pen
      ..moveTo(-w * 0.36, -w * 0.02)
      ..cubicTo(-w * 0.38, -w * 0.52, w * 0.38, -w * 0.52, w * 0.36, -w * 0.02)
      ..close();
    b.shape(fill);
    pen.ellipse(0, 0, w * 0.52, w * 0.08);
    b.fill(band);
    pen.roundRect(-w * 0.35, -w * 0.12, w * 0.35, -w * 0.04, w * 0.01);
    b.brushQuad(3, -w * 0.18, -w * 0.36, -w * 0.08, -w * 0.42, w * 0.06, -w * 0.4, b.lw * 0.9, color: b.colors.shine);
    b.endLayer();
    pen.restore();
  }

  /// Fedora with a pinched crown and a band; the brim dips at the front.
  static void fedora(
    InkBuild b,
    double x,
    double y,
    double w,
    double tilt, {
    required Color fill,
    required Color band,
  }) {
    final pen = b.pen
      ..save()
      ..rotateAbout(tilt, x, y)
      ..translate(x, y);
    b.layer();
    // Brim: wide, dipping toward +x (the front).
    b.shape(fill);
    pen
      ..moveTo(-w * 0.58, w * 0.02)
      ..cubicTo(-w * 0.5, -w * 0.1, w * 0.4, -w * 0.12, w * 0.62, w * 0.06)
      ..cubicTo(w * 0.55, w * 0.14, -w * 0.45, w * 0.12, -w * 0.58, w * 0.02)
      ..close();
    // Crown with the centre dent.
    b.shape(fill);
    pen
      ..moveTo(-w * 0.34, -w * 0.02)
      ..cubicTo(-w * 0.4, -w * 0.3, -w * 0.3, -w * 0.46, -w * 0.12, -w * 0.44)
      ..quadTo(0, -w * 0.36, w * 0.12, -w * 0.44)
      ..cubicTo(w * 0.3, -w * 0.46, w * 0.4, -w * 0.3, w * 0.34, -w * 0.02)
      ..close();
    b.fill(band);
    pen
      ..moveTo(-w * 0.35, -w * 0.13)
      ..quadTo(0, -w * 0.17, w * 0.35, -w * 0.13)
      ..lineTo(w * 0.34, -w * 0.03)
      ..quadTo(0, -w * 0.07, -w * 0.34, -w * 0.03)
      ..close();
    b.brushQuad(3, 0, -w * 0.38, w * 0.01, -w * 0.26, -w * 0.02, -w * 0.18, b.lw * 0.8);
    b.brushQuad(3, -w * 0.24, -w * 0.36, -w * 0.18, -w * 0.4, -w * 0.08, -w * 0.4, b.lw * 0.8, color: b.colors.shine);
    b.endLayer();
    pen.restore();
  }

  /// Fez (tarboosh): a truncated cone; the tassel is drawn by the caller
  /// (it swings on a spring). Returns nothing; the tassel root is at
  /// (x, y − 0.62·w) rotated by [tilt].
  static void fez(InkBuild b, double x, double y, double w, double tilt, {required Color fill}) {
    final pen = b.pen
      ..save()
      ..rotateAbout(tilt, x, y)
      ..translate(x, y);
    b.layer();
    b.shape(fill);
    pen
      ..moveTo(-w * 0.42, w * 0.02)
      ..lineTo(-w * 0.3, -w * 0.6)
      ..quadTo(0, -w * 0.68, w * 0.3, -w * 0.6)
      ..lineTo(w * 0.42, w * 0.02)
      ..quadTo(0, w * 0.1, -w * 0.42, w * 0.02)
      ..close();
    b.shape(fill);
    pen.ellipse(0, -w * 0.6, w * 0.3, w * 0.07);
    b.brushQuad(3, -w * 0.2, -w * 0.5, -w * 0.24, -w * 0.25, -w * 0.28, -w * 0.05, b.lw * 0.9, color: b.colors.shine);
    b.endLayer();
    pen.restore();
  }

  /// A stovepipe (top hat) of height [hgt].
  static void topHat(
    InkBuild b,
    double x,
    double y,
    double w,
    double hgt,
    double tilt, {
    required Color fill,
    required Color band,
  }) {
    final pen = b.pen
      ..save()
      ..rotateAbout(tilt, x, y)
      ..translate(x, y);
    b.layer();
    b.shape(fill);
    pen.ellipse(0, 0, w * 0.6, w * 0.1);
    b.shape(fill);
    pen
      ..moveTo(-w * 0.36, 0)
      ..lineTo(-w * 0.4, -hgt)
      ..quadTo(0, -hgt - w * 0.06, w * 0.4, -hgt)
      ..lineTo(w * 0.36, 0)
      ..close();
    b.shape(fill);
    pen.ellipse(0, -hgt, w * 0.4, w * 0.08);
    b.fill(band);
    pen
      ..moveTo(-w * 0.365, -w * 0.08)
      ..lineTo(-w * 0.38, -w * 0.26)
      ..lineTo(w * 0.38, -w * 0.26)
      ..lineTo(w * 0.365, -w * 0.08)
      ..close();
    b.brushQuad(
      3,
      -w * 0.24,
      -hgt * 0.9,
      -w * 0.27,
      -hgt * 0.6,
      -w * 0.25,
      -hgt * 0.35,
      b.lw * 0.9,
      color: b.colors.shine,
    );
    b.endLayer();
    pen.restore();
  }
}
