import 'dart:math' as math;
import 'dart:ui';

import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';

/// **Miftah** (مِفتاح, "wrench") – the night engineer of *Metropolis
/// Machine*. An original rubber-hose worker on the standard biped: overalls
/// with a bib and a tool belt, a soft flat cap with goggles pushed up on it,
/// a big open-end wrench in the near hand and a lantern swinging from the
/// far one on a short chain. The lantern glows (it is the only warm light
/// in the sepia hall) and swings with his motion on a spring.
///
/// Gameplay drives him through the [RigCharacter] contract plus [dashing]
/// (a lean-forward dash pose with the wrench tucked back).
class WorkerRig extends ToonRig {
  WorkerRig({double height = 112, int seed = 0})
    : super(
        RigSpec(
          id: 'miftah',
          body: RigBody.pear,
          height: height,
          bodyWidth: 0.64,
          limbLength: 0.5,
          limbWidth: 0.085,
          fill: PaletteRole.midtone,
          trim: PaletteRole.paper,
          accent: PaletteRole.accent,
          bounciness: 1.1,
          seed: seed,
        ),
        look: const ToonLook(hair: ToonHair.none, bowTie: false, buttons: 0, eyeScale: 1.08),
      );

  /// Dash pose (the game sets it while the dash lasts).
  bool dashing = false;

  final Spring1 _lanternSwing = Spring1();
  double _lastFarX = 0;

  @override
  double oneShotLength(RigAction action) => switch (action) {
    RigAction.attack => 0.32,
    _ => super.oneShotLength(action),
  };

  @override
  void animate(double h) {
    super.animate(h);
    // The lantern trails the far hand's motion and the run's bounce.
    final far = hands[0];
    final target = ((_lastFarX - far.x) * 0.9 - speed * 0.0012).clamp(-0.9, 0.9);
    _lastFarX = far.x;
    _lanternSwing.step(h, target, 9, 0.22);
  }

  @override
  void shapePose() {
    final h = spec.height, uu = h / 100;
    if (dashing) {
      tTilt = 0.62;
      tHeadTilt = -0.2;
      sqBias = -0.1;
      final shY = -hipH + shoulderDY;
      tHand[0] = -bodyW * 0.55;
      tHand[1] = shY + armLen * 0.55;
      tHand[2] = -bodyW * 0.2;
      tHand[3] = shY + armLen * 0.7;
      handShape[0] = HandShape.fist;
      handShape[1] = HandShape.grip;
      tFoot[0] = -16 * uu;
      tFoot[1] = -4 * uu;
      tFoot[2] = 14 * uu;
      tFoot[3] = -2 * uu;
      footPitch[0] = 0.5;
      footPitch[1] = -0.2;
      eyeState = EyeState.squeeze;
    } else if (action == RigAction.idle || action == RigAction.walk || action == RigAction.run) {
      // The lantern hand hangs a little lower, the wrench hand grips.
      tHand[1] += 4 * uu;
      handShape[1] = action == RigAction.idle ? HandShape.grip : handShape[1];
      handShape[0] = HandShape.grip;
    }
  }

  // ------------------------------------------------------------- drawing

  @override
  void drawTorso(InkBuild b) {
    super.drawTorso(b);
    final c = b.colors;
    final pen = b.pen;
    final cy = bodyCy, w = bodyW, hh = bodyH;
    final bib = Color.lerp(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.35)!;
    final tn = turn;
    b.layer();
    // Overall bib and straps.
    b.shape(bib, ink: 0.8);
    pen.roundRect(-w * 0.26 + w * 0.06 * tn, cy - hh * 0.42, w * 0.26 + w * 0.06 * tn, cy + hh * 0.1, w * 0.04);
    for (final s in const [-1.0, 1.0]) {
      final x = s * w * 0.17 + w * 0.06 * tn;
      b.shape(bib, ink: 0.7);
      pen
        ..moveTo(x - w * 0.05, cy - hh * 0.4)
        ..lineTo(x + s * w * 0.06 - w * 0.04, cy - hh * 0.62)
        ..lineTo(x + s * w * 0.06 + w * 0.04, cy - hh * 0.62)
        ..lineTo(x + w * 0.05, cy - hh * 0.4)
        ..close();
    }
    // Pocket with a folding rule sticking out.
    b.fill(c.fill(PaletteRole.shadow).withValues(alpha: 0.35));
    pen.roundRect(-w * 0.12 + w * 0.06 * tn, cy - hh * 0.3, w * 0.12 + w * 0.06 * tn, cy - hh * 0.12, w * 0.02);
    b.fill(c.fill(PaletteRole.paper));
    pen.roundRect(w * 0.02 + w * 0.06 * tn, cy - hh * 0.4, w * 0.08 + w * 0.06 * tn, cy - hh * 0.28, w * 0.01);
    // Tool belt.
    b.fill(c.fill(PaletteRole.shadow));
    pen.roundRect(-w * 0.48, cy + hh * 0.18, w * 0.48, cy + hh * 0.3, w * 0.02);
    Mechanics.rivet(b, w * 0.1 * tn, cy + hh * 0.24, w * 0.045);
    b.endLayer();
  }

  @override
  void drawHead(InkBuild b, double x, double y, double r) {
    super.drawHead(b, x, y, r);
    final c = b.colors;
    final pen = b.pen;
    final tn = turn;
    final cap = c.fill(PaletteRole.accent);
    final dark = c.fill(PaletteRole.shadow);
    final tl = -0.06 + headTilt.value * 0.3;
    pen
      ..save()
      ..rotateAbout(tl, x, y - r * 0.8)
      ..translate(x + r * 0.08 * tn, y - r * 0.72);
    b.layer();
    // A soft flat cap: the dome slumps forward, the peak juts out.
    b.shape(cap);
    pen
      ..moveTo(-r * 1.02, r * 0.1)
      ..cubicTo(-r * 1.1, -r * 0.5, -r * 0.3, -r * 0.78, r * 0.3, -r * 0.7)
      ..cubicTo(r * 0.85, -r * 0.62, r * 1.08, -r * 0.3, r * 1.0, r * 0.05)
      ..quadTo(0, r * 0.22, -r * 1.02, r * 0.1)
      ..close();
    b.shape(dark);
    pen
      ..moveTo(r * 0.2, r * 0.0)
      ..quadTo(r * 1.0, -r * 0.12, r * 1.55 + b.ja(61, 0.4), r * 0.2)
      ..quadTo(r * 1.0, r * 0.3, r * 0.25, r * 0.16)
      ..close();
    // Goggles pushed up on the cap.
    for (final s in const [-0.42, 0.42]) {
      b.shape(dark);
      pen.circle(s * r + r * 0.1 * tn, -r * 0.42, r * 0.3);
      b.shape(c.glass, ink: 0.6);
      pen.circle(s * r + r * 0.1 * tn, -r * 0.42, r * 0.19);
    }
    b.inkLine(b.lw * 0.7);
    pen
      ..moveTo(-r * 0.72 + r * 0.1 * tn, -r * 0.42)
      ..quadTo(-r * 1.0, -r * 0.3, -r * 0.98, r * 0.0)
      ..moveTo(r * 0.72 + r * 0.1 * tn, -r * 0.42)
      ..quadTo(r * 1.0, -r * 0.3, r * 0.98, r * 0.0);
    b.brushQuad(3, -r * 0.5, -r * 0.5, 0, -r * 0.62, r * 0.4, -r * 0.5, b.lw * 0.7, color: c.shine);
    b.endLayer();
    pen.restore();
  }

  @override
  void drawFrontAccessories(InkBuild b) {
    final h = spec.height;
    final c = b.colors;
    // The wrench rides the near hand, swinging through a strike.
    final near = hands[1];
    final swing = _swing();
    final hx = near.x, hy = near.y;
    // Approximate forearm direction: from the shoulder root to the hand.
    final shY = shoulderDY;
    final rootX = bx(bodyW * 0.4, shY), rootY = by(bodyW * 0.4, shY);
    final angle = math.atan2(hy - rootY, hx - rootX);
    _wrench(b, hx, hy, angle + swing, Color.lerp(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.45)!, h);
    // The lantern hangs from the far hand.
    final far = hands[0];
    _lantern(b, far.x, far.y + h * 0.02, _lanternSwing.value, h);
  }

  double _swing() {
    if (action != RigAction.attack) return dashing ? -1.1 : -0.35;
    final t = actionTime;
    if (t < 0.05) return Bounce.lerp(-0.35, -1.3, t / 0.05);
    if (t < 0.2) return Bounce.lerp(-1.3, 0.75, Bounce.out((t - 0.05) / 0.15));
    return Bounce.lerp(0.75, -0.35, Bounce.smooth((t - 0.2) / 0.12));
  }

  void _wrench(InkBuild b, double x, double y, double angle, Color metal, double h) {
    final pen = b.pen
      ..save()
      ..translate(x, y)
      ..rotate(angle);
    final len = h * 0.46, w = h * 0.045;
    b.layer();
    b.shape(metal);
    pen.roundRect(-w * 2.2, -w, len * 0.74, w, w * 0.7);
    // Open-end jaw.
    b.shape(metal);
    pen
      ..moveTo(len * 0.6, -w * 2.4)
      ..lineTo(len * 0.95, -w * 2.5)
      ..lineTo(len * 1.06, -w * 1.25)
      ..lineTo(len * 0.86, -w * 0.85)
      ..lineTo(len * 0.86, w * 0.85)
      ..lineTo(len * 1.06, w * 1.25)
      ..lineTo(len * 0.95, w * 2.5)
      ..lineTo(len * 0.6, w * 2.4)
      ..close();
    // Ring end on the handle's tail.
    b.shape(metal);
    pen.circle(-w * 2.2, 0, w * 1.5);
    b.fill(b.colors.dark);
    pen.circle(-w * 2.2, 0, w * 0.6);
    b.brushQuad(3, len * 0.05, -w * 0.45, len * 0.35, -w * 0.6, len * 0.6, -w * 0.45, b.lw * 0.5, color: b.colors.shine);
    b.endLayer();
    // The swing's whoosh.
    if (emanata && action == RigAction.attack && actionTime > 0.05 && actionTime < 0.2) {
      b.layer();
      for (var i = 0; i < 3; i++) {
        final r = len * (0.75 + i * 0.18);
        b.brushQuad(
          2,
          math.cos(-1.1) * r,
          math.sin(-1.1) * r,
          math.cos(-0.55) * r * 1.05,
          math.sin(-0.55) * r * 1.05,
          math.cos(0.1) * r,
          math.sin(0.1) * r,
          b.lw * (0.9 - i * 0.2),
          taperIn: 0.3,
          taperOut: 0.3,
        );
      }
      b.endLayer();
    }
    pen.restore();
  }

  void _lantern(InkBuild b, double x, double y, double swing, double h) {
    final c = b.colors;
    final pen = b.pen
      ..save()
      ..translate(x, y)
      ..rotate(swing);
    final s = h * 0.1;
    final dark = c.fill(PaletteRole.shadow);
    // Warm halo (no outline).
    b.layer();
    b.shape(c.hot.withValues(alpha: 0.22), ink: 0);
    pen.circle(0, s * 1.75, s * 1.7 + b.ja(71, 1.2));
    b.endLayer();
    b.layer();
    b.inkLine(b.lw * 0.7);
    pen
      ..circle(0, s * 0.3, s * 0.26)
      ..moveTo(0, s * 0.56)
      ..lineTo(0, s * 0.92);
    b.shape(dark);
    pen.roundRect(-s * 0.46, s * 0.9, s * 0.46, s * 1.16, s * 0.12);
    b.shape(c.hot, ink: 0.8);
    pen.roundRect(-s * 0.5, s * 1.12, s * 0.5, s * 2.32, s * 0.14);
    b.shape(dark);
    pen.roundRect(-s * 0.56, s * 2.28, s * 0.56, s * 2.52, s * 0.1);
    b.inkLine(b.lw * 0.55);
    pen
      ..moveTo(-s * 0.2, s * 1.14)
      ..lineTo(-s * 0.2, s * 2.3)
      ..moveTo(s * 0.2, s * 1.14)
      ..lineTo(s * 0.2, s * 2.3);
    // The flame flickers on the boil.
    b.fill(c.fill(PaletteRole.highlight));
    pen.ellipse(b.ja(72, 0.4), s * 1.74 + b.ja(73, 0.3), s * 0.15, s * 0.3 + b.ja(74, 0.6).abs());
    b.inkFill(c.dark);
    pen.ellipse(0, s * 1.86, s * 0.05, s * 0.09);
    b.endLayer();
    pen.restore();
  }
}
