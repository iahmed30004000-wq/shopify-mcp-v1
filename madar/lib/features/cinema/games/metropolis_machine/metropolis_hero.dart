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
    // The wrench rides the near hand: carried head-forward, tucked back in
    // a dash, and chopped overhead through a strike.
    final near = hands[1];
    _wrench(b, near.x, near.y, _wrenchAngle(), Color.lerp(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.45)!, h);
    // The lantern hangs from the far hand.
    final far = hands[0];
    _lantern(b, far.x, far.y + h * 0.02, _lanternSwing.value, h);
  }

  /// Absolute wrench angle in design space (facing +x, y down).
  double _wrenchAngle() {
    const rest = 0.55, back = math.pi - 0.25, raised = -2.25, down = 0.95;
    if (action != RigAction.attack) {
      if (dashing) return back;
      return rest + math.sin(time * 2) * 0.04;
    }
    final t = actionTime;
    if (t < 0.05) return Bounce.lerp(rest, raised, Bounce.smooth(t / 0.05));
    if (t < 0.2) return Bounce.lerp(raised, down, Bounce.out((t - 0.05) / 0.15));
    return Bounce.lerp(down, rest, Bounce.smooth((t - 0.2) / 0.12));
  }

  void _wrench(InkBuild b, double x, double y, double angle, Color metal, double h) {
    final pen = b.pen
      ..save()
      ..translate(x, y)
      ..rotate(angle);
    final len = h * 0.36, w = h * 0.042;
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
    // The swing's whoosh: arcs trailing behind the head.
    if (emanata && action == RigAction.attack && actionTime > 0.07 && actionTime < 0.2) {
      b.layer();
      for (var i = 0; i < 3; i++) {
        final r = len * (0.8 + i * 0.2);
        b.brushQuad(
          2,
          math.cos(-1.3) * r,
          math.sin(-1.3) * r,
          math.cos(-0.7) * r * 1.08,
          math.sin(-0.7) * r * 1.08,
          math.cos(-0.1) * r,
          math.sin(-0.1) * r,
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
    final brass = Color.lerp(c.fill(PaletteRole.accent2), c.fill(PaletteRole.paper), 0.3)!;
    // Warm halo (no outline), breathing on the boil.
    b.layer();
    b.shape(c.hot.withValues(alpha: 0.3), ink: 0);
    pen.circle(0, s * 1.8, s * 2.1 + b.ja(71, 1.4));
    b.endLayer();
    b.layer();
    // Ring and chain.
    b.inkLine(b.lw * 0.8);
    pen
      ..circle(0, s * 0.3, s * 0.28)
      ..moveTo(0, s * 0.58)
      ..lineTo(0, s * 0.95);
    // Cap, glass bulb, base.
    b.shape(brass);
    pen
      ..moveTo(-s * 0.55, s * 1.2)
      ..lineTo(0, s * 0.85)
      ..lineTo(s * 0.55, s * 1.2)
      ..close();
    b.shape(c.hot, ink: 0.9);
    pen.capsule(0, s * 1.5, 0, s * 2.15, s * 0.58, s * 0.5);
    b.shape(brass);
    pen.roundRect(-s * 0.5, s * 2.5, s * 0.5, s * 2.75, s * 0.1);
    b.inkLine(b.lw * 0.5);
    pen
      ..moveTo(-s * 0.42, s * 1.3)
      ..lineTo(-s * 0.42, s * 2.5)
      ..moveTo(s * 0.42, s * 1.3)
      ..lineTo(s * 0.42, s * 2.5);
    // The flame flickers on the boil.
    b.fill(c.fill(PaletteRole.highlight));
    pen
      ..moveTo(0, s * 2.35)
      ..quadTo(-s * 0.3, s * 1.95, b.ja(72, 0.5), s * (1.45 + b.ja(73, 0.3).abs()))
      ..quadTo(s * 0.3, s * 1.95, 0, s * 2.35)
      ..close();
    b.inkFill(c.dark);
    pen.ellipse(0, s * 2.1, s * 0.06, s * 0.1);
    b.endLayer();
    pen.restore();
  }
}
