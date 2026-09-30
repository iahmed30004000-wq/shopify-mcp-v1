import 'dart:math' as math;

import '../../core/era_skin.dart';
import '../../core/rig.dart';
import '../ink/contour.dart';
import '../ink/ink_build.dart';
import '../motion/spring.dart';
import '../parts/extremities.dart';
import '../parts/face.dart';
import '../parts/hats.dart';
import '../toon_rig.dart';

/// **Inspector Mishmish** (المفتش مِشمِش) – the trench-coat detective cat of
/// *Noir Rooftops*. An original design: a lanky pale tabby (not a black
/// cat, no grin mask) in a belted, double-breasted trench coat with the
/// collar up, a fedora pulled low, world-weary half-lidded eyes, whiskers,
/// white gloves, spats, and a long striped tail that sways out from under
/// the coat.
///
/// [RigAction.walk] is a tiptoe sneak (crouched, paws up), [RigAction.run]
/// a coat-flapping sprint, [RigAction.jump] a long rooftop leap,
/// [RigAction.cheer] a hat tip. He idles with a slow tail sway and a
/// suspicious glance.
class DetectiveCat extends ToonRig {
  DetectiveCat({double height = 110, int seed = 0})
    : super(
        RigSpec(
          id: 'mishmish',
          body: RigBody.tall,
          height: height,
          bodyWidth: 0.6,
          limbLength: 0.56,
          limbWidth: 0.065,
          fill: PaletteRole.paper,
          trim: PaletteRole.highlight,
          accent: PaletteRole.accent,
          seed: seed,
        ),
        look: const ToonLook(
          hair: ToonHair.none,
          hat: ToonHat.none,
          bowTie: false,
          nose: NoseStyle.none,
          hatFill: PaletteRole.ink,
          shoeFill: PaletteRole.ink,
        ),
      ) {
    headR = height * 0.19;
  }

  final Spring1 _flap = Spring1();
  final Spring1 _hatTip = Spring1();
  late final Contour _coat = Contour(64);

  @override
  double get chainAnchorX => -bodyW * 0.28 + hip.x;
  @override
  double get chainAnchorY => -hipH + hip.y + 4 * u;
  @override
  double get chainRestX => -0.75 + math.sin(time * 1.3) * 0.15;
  @override
  double get chainRestY => 0.3 - math.sin(time * 1.9) * 0.55 - (action == RigAction.run ? 0.5 : 0);
  @override
  double get chainSegment => spec.height * 0.075;

  @override
  void shapePose() {
    final uu = u;
    switch (action) {
      case RigAction.walk:
        // The sneak: crouched low, leaning in, paws up by the chest.
        final ph = cycle;
        tHipY += 7 * uu;
        tTilt = 0.22;
        tHeadTilt = 0.1 + math.sin(ph) * 0.04;
        for (var i = 0; i < 2; i++) {
          final s = i == 0 ? -1.0 : 1.0;
          final p = ph + i * math.pi;
          tFoot[i * 2] = -spec.height * 0.2 * math.cos(p) + 4 * uu;
          tFoot[i * 2 + 1] = -spec.height * 0.13 * math.max(0.0, math.sin(p));
          footPitch[i] = 0.25 - 0.4 * math.sin(p);
          tHand[i * 2] = bodyW * 0.55 + s * 5 * uu + math.sin(p) * 3 * uu;
          tHand[i * 2 + 1] = -hipH + shoulderDY + 17 * uu + math.cos(p) * 2 * uu;
          handShape[i] = HandShape.open;
          handBend[i] = -1;
        }
        eyeState = EyeState.heavy;
      case RigAction.jump:
        // A long rooftop leap: stretched out, arms reaching forward.
        tTilt = 0.35;
        for (var i = 0; i < 2; i++) {
          tHand[i * 2] = bodyW * 0.5 + armLen * 0.7 + i * 4 * uu;
          tHand[i * 2 + 1] = -hipH + shoulderDY - armLen * 0.2;
          handShape[i] = HandShape.open;
          tFoot[i * 2] = -spec.height * 0.22 - i * 5 * uu;
          tFoot[i * 2 + 1] = -hipH * 0.4;
          footPitch[i] = 0.9;
        }
      case RigAction.cheer:
        // Tips the hat instead of hopping about.
        tHipY = 0;
        sqBias = 0;
        tTilt = -0.05;
        tHeadTilt = 0.12;
        mouthShape = MouthShape.smirk;
        tHand[2] = bodyW * 0.1;
        tHand[3] = -hipH + shoulderDY - headR * 2.4;
        handShape[1] = HandShape.grip;
        tHand[0] = -bodyW * 0.55;
        tHand[1] = -hipH + shoulderDY + armLen * 0.75;
        for (var i = 0; i < 2; i++) {
          tFoot[i * 2] = (i == 0 ? -1 : 1) * 9 * uu;
          tFoot[i * 2 + 1] = 0;
          footPitch[i] = 0;
        }
      default:
    }
  }

  @override
  void animate(double h) {
    super.animate(h);
    // Coat tails flap against the motion.
    final target = -(speed.abs() / spec.height).clamp(0.0, 2.0) * 0.35 + hip.vy * 0.004 + (airborne ? -0.5 : 0);
    _flap.step(h, target, 11, 0.25);
    _hatTip.step(h, action == RigAction.cheer ? 1 : 0, 12, 0.5);
  }

  @override
  void drawBackAccessories(InkBuild b) {
    // The striped tail, from under the coat.
    final pen = b.pen;
    final c = b.colors;
    final tc = b.contour(0)..clear(closed: false);
    tc.addPen(pen, chainAnchorX, chainAnchorY);
    for (final p in chain) {
      tc.addPen(pen, p.x, p.y);
    }
    // A curl at the tip.
    final e = chain.last, p = chain[chain.length - 2];
    final ang = math.atan2(e.y - p.y, e.x - p.x);
    tc.addPen(pen, e.x + math.cos(ang - 1.2) * 5 * u, e.y + math.sin(ang - 1.2) * 5 * u);
    b.layer();
    tc.writeBrush(b.inkFill(), spec.height * 0.06 + b.lw * 2, taperIn: 0, taperOut: 0.25, minWidth: 0.55);
    tc.writeBrush(b.fill(c.fill(spec.fill)), spec.height * 0.06, taperIn: 0, taperOut: 0.25, minWidth: 0.45);
    for (var i = 1; i < chain.length; i++) {
      final q = chain[i], o = chain[i - 1];
      final a = math.atan2(q.y - o.y, q.x - o.x) + math.pi / 2;
      final w = spec.height * 0.028;
      b.brushQuad(
        3,
        q.x - math.cos(a) * w,
        q.y - math.sin(a) * w,
        q.x + (o.x - q.x) * 0.15,
        q.y + (o.y - q.y) * 0.15,
        q.x + math.cos(a) * w,
        q.y + math.sin(a) * w,
        b.lw * 1.1,
      );
    }
    b.endLayer();
  }

  @override
  void drawTorso(InkBuild b) {
    final c = b.colors;
    final pen = b.pen;
    final coat = c.fill(PaletteRole.midtone), belt = c.fill(PaletteRole.shadow), fur = c.fill(spec.fill);
    final w = bodyW, uu = u;
    final top = shoulderDY - 2 * uu, waist = -9 * uu, hem = 11 * uu;
    final tn = turn;
    final flap = _flap.value;
    // Coat tails (the back one flies out behind).
    b.layer();
    b.shape(coat);
    pen
      ..save()
      ..rotateAbout(flap * 0.6, -w * 0.3, waist)
      ..moveTo(-w * 0.46, waist)
      ..lineTo(-w * 0.62, hem + b.ja(80))
      ..quadTo(-w * 0.35, hem + 2 * uu, -w * 0.05, hem)
      ..lineTo(0, waist)
      ..close()
      ..restore();
    b.shape(coat);
    pen
      ..save()
      ..rotateAbout(flap * 0.25, w * 0.2, waist)
      ..moveTo(0, waist)
      ..lineTo(w * 0.02, hem + 1 * uu)
      ..quadTo(w * 0.3, hem + 2 * uu, w * 0.55, hem + b.ja(81))
      ..lineTo(w * 0.44, waist)
      ..close()
      ..restore();
    b.endLayer();
    // Up-turned collar behind the head.
    b.layer();
    b.shape(coat);
    pen
      ..moveTo(-w * 0.42, top + 2 * uu)
      ..lineTo(-w * 0.5, top - 12 * uu)
      ..lineTo(-w * 0.1, top - 3 * uu)
      ..lineTo(w * 0.12, top - 3 * uu)
      ..lineTo(w * 0.52, top - 12 * uu)
      ..lineTo(w * 0.44, top + 2 * uu)
      ..close();
    b.endLayer();
    // The coat body: shoulder pads down to the belt.
    final cc = _coat..clear();
    cc.cubic(
      pen,
      -w * 0.5,
      top + 3 * uu,
      -w * 0.52,
      top - 1 * uu,
      w * 0.52,
      top - 1 * uu,
      w * 0.5,
      top + 3 * uu,
      samples: 10,
    );
    cc.cubic(
      pen,
      w * 0.5,
      top + 3 * uu,
      w * 0.5,
      top + 10 * uu,
      w * 0.44,
      waist - 4 * uu,
      w * 0.42,
      waist + 3 * uu,
      samples: 6,
      skipFirst: true,
    );
    cc.cubic(
      pen,
      w * 0.42,
      waist + 3 * uu,
      w * 0.2,
      waist + 5 * uu,
      -w * 0.2,
      waist + 5 * uu,
      -w * 0.44,
      waist + 3 * uu,
      samples: 6,
      skipFirst: true,
    );
    cc.cubic(
      pen,
      -w * 0.44,
      waist + 3 * uu,
      -w * 0.46,
      waist - 4 * uu,
      -w * 0.52,
      top + 10 * uu,
      -w * 0.5,
      top + 3 * uu,
      samples: 6,
      skipFirst: true,
    );
    cc.length--;
    cc.wobble(b.amp * 0.6, b.frame, b.seed, 81);
    b.layer();
    b.blob(cc, coat, depth: w * 0.18, threshold: 0.25);
    // Fur at the open neck, lapels, buttons, belt, pocket.
    final nx = w * 0.12 * tn;
    b.fill(fur);
    pen
      ..moveTo(nx - w * 0.14, top + 1 * uu)
      ..lineTo(nx + w * 0.14, top + 1 * uu)
      ..lineTo(nx, top + 9 * uu)
      ..close();
    b.brushQuad(2, nx - w * 0.16, top + 1 * uu, nx - w * 0.1, top + 6 * uu, nx - w * 0.02, top + 12 * uu, b.lw * 0.9);
    b.brushQuad(2, nx + w * 0.16, top + 1 * uu, nx + w * 0.1, top + 6 * uu, nx + w * 0.02, top + 12 * uu, b.lw * 0.9);
    b.brushQuad(2, nx - w * 0.16, top + 1 * uu, nx - w * 0.3, top + 5 * uu, nx - w * 0.2, top + 9 * uu, b.lw * 0.8);
    b.brushQuad(2, nx + w * 0.16, top + 1 * uu, nx + w * 0.3, top + 5 * uu, nx + w * 0.2, top + 9 * uu, b.lw * 0.8);
    for (var i = 0; i < 2; i++) {
      for (var k = -1; k <= 1; k += 2) {
        b.inkFill(c.dark);
        pen.circle(nx + k * w * 0.1, top + (13 + i * 5) * uu, 1.1 * uu);
      }
    }
    b.fill(belt);
    pen.roundRect(-w * 0.45, waist - 2 * uu, w * 0.45, waist + 2.5 * uu, 1 * uu);
    b.inkLine(b.lw * 0.6);
    pen.roundRect(nx - 2.5 * uu, waist - 2.5 * uu, nx + 2.5 * uu, waist + 3 * uu, 0.6 * uu);
    b.brushQuad(
      3,
      w * 0.12 + nx,
      waist - 7 * uu,
      w * 0.25 + nx,
      waist - 7.5 * uu,
      w * 0.36 + nx,
      waist - 6.5 * uu,
      b.lw * 0.8,
    );
    b.endLayer();
  }

  @override
  void drawHead(InkBuild b, double x, double y, double r) {
    final c = b.colors;
    final pen = b.pen;
    final fur = c.fill(spec.fill), inner = c.fill(PaletteRole.shadow), hat = c.fill(PaletteRole.ink);
    final tn = turn;
    // Ears (poking out beside the hat), head with cheek fluff.
    b.layer();
    for (var k = -1; k <= 1; k += 2) {
      final ex = x + k * r * 0.72 + tn * r * 0.1;
      b.shape(fur);
      pen
        ..moveTo(ex - r * 0.3, y - r * 0.45)
        ..quadTo(ex + k * r * 0.25, y - r * 1.2, ex + k * r * 0.42 + b.ja(90 + k), y - r * 1.3)
        ..quadTo(ex + k * r * 0.45, y - r * 0.7, ex + r * 0.3, y - r * 0.3)
        ..close();
    }
    final hc = b.contour(1)..clear();
    hc.blob(pen, x, y, r * 1.1, r * 0.9, taper: 0.08, box: 0.12, samples: 36);
    hc.wobble(b.amp * 0.8, b.frame, b.seed, 3);
    b.blob(hc, fur, depth: r * 0.3, threshold: 0.28);
    for (var k = -1; k <= 1; k += 2) {
      final cx = x + k * r * 1.02;
      b.shape(fur);
      pen
        ..moveTo(cx - k * r * 0.1, y - r * 0.05)
        ..lineTo(cx + k * r * 0.26, y + r * 0.12)
        ..lineTo(cx + k * r * 0.02, y + r * 0.2)
        ..lineTo(cx + k * r * 0.22, y + r * 0.34)
        ..lineTo(cx - k * r * 0.12, y + r * 0.42)
        ..close();
    }
    // Inner ears.
    for (var k = -1; k <= 1; k += 2) {
      final ex = x + k * r * 0.72 + tn * r * 0.1;
      b.fill(inner);
      pen
        ..moveTo(ex - r * 0.12, y - r * 0.6)
        ..quadTo(ex + k * r * 0.2, y - r * 1.05, ex + k * r * 0.33, y - r * 1.12)
        ..quadTo(ex + k * r * 0.3, y - r * 0.75, ex + r * 0.12, y - r * 0.55)
        ..close();
    }
    // Tabby stripes on the cheeks.
    for (var k = -1; k <= 1; k += 2) {
      for (var i = 0; i < 2; i++) {
        final sx = x + k * r * (0.95 - i * 0.12), sy = y + r * (0.02 + i * 0.16);
        b.brushQuad(
          2,
          sx,
          sy,
          sx - k * r * 0.12,
          sy + r * 0.02,
          sx - k * r * 0.22,
          sy + r * 0.07,
          b.lw * 1.2,
          taperIn: 0.1,
          taperOut: 0.8,
        );
      }
    }
    b.endLayer();
    // Muzzle puffs.
    final mx = x + tn * r * 0.34, my = y + r * 0.38;
    b.layer();
    b.shape(c.fill(PaletteRole.highlight), ink: 0.7);
    pen
      ..ellipse(mx - r * 0.2, my, r * 0.26, r * 0.2)
      ..ellipse(mx + r * 0.2, my, r * 0.26, r * 0.2);
    b.endLayer();
    // Face (eyes, brows, mouth).
    face
      ..cx = x
      ..cy = y - r * 0.02
      ..r = r * 0.95
      ..turn = tn
      ..expression = expression
      ..eyes = spec.eyes
      ..eyeScale = 1.1
      ..eyeGap = 0.12
      ..eyeY = -0.04
      ..blink = blinkAmount
      ..lookX = lookSpring.x
      ..lookY = (lookSpring.y + lookBiasY).clamp(-1.0, 1.0)
      ..eyeState = eyeState == EyeState.auto && expression == RigExpression.neutral ? EyeState.heavy : eyeState
      ..spin = time * 6
      ..tremble = expression == RigExpression.scared ? spec.height * 0.006 : 0
      ..nose = NoseStyle.none
      ..skin = fur
      ..mouth = mouthShape == MouthShape.auto && expression == RigExpression.neutral ? MouthShape.smirk : mouthShape
      ..mouthOpen = mouthOpen
      ..mouthY = 0.7
      ..mouthW = 0.55
      ..salt = 200;
    // A finer pen for the features: the eyes read under the brim.
    final lw0 = b.lw;
    b.lw = lw0 * 0.72;
    face.draw(b);
    b.lw = lw0;
    // Nose and whiskers.
    b.layer();
    b.shape(c.dark, ink: 0.5);
    pen
      ..moveTo(mx - r * 0.1, my - r * 0.14)
      ..lineTo(mx + r * 0.1, my - r * 0.14)
      ..quadTo(mx + r * 0.02, my - r * 0.02, mx, my)
      ..quadTo(mx - r * 0.02, my - r * 0.02, mx - r * 0.1, my - r * 0.14)
      ..close();
    for (var k = -1; k <= 1; k += 2) {
      for (var i = -1; i <= 1; i++) {
        final wx = mx + k * r * 0.35, wy = my + i * r * 0.08;
        final droop = expression == RigExpression.sly || expression == RigExpression.happy ? -0.06 : 0.04;
        b.brushQuad(
          3,
          wx,
          wy,
          wx + k * r * 0.35,
          wy + i * r * 0.06 + droop * r,
          wx + k * r * 0.7,
          wy + i * r * 0.16 + b.ja(95 + i + k * 3, 0.5),
          b.lw * 0.55,
          taperIn: 0.1,
          taperOut: 0.7,
        );
      }
    }
    b.endLayer();
    // The fedora, pulled low (tipped up and off the head when cheering).
    final tip = _hatTip.value;
    Hats.fedora(
      b,
      x + r * 0.08 + tip * r * 0.4,
      y - r * 0.74 - tip * r * 0.9,
      r * 2.15,
      0.1 - tip * 0.5,
      fill: hat,
      band: c.fill(PaletteRole.accent2),
    );
  }
}
