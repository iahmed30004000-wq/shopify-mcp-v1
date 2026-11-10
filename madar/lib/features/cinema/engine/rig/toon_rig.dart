import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/era_skin.dart';
import '../core/rig.dart';
import 'hose_rig.dart';
import 'ink/contour.dart';
import 'ink/ink_build.dart';
import 'motion/spring.dart';
import 'parts/emanata.dart';
import 'parts/extremities.dart';
import 'parts/face.dart';
import 'parts/hats.dart';
import 'parts/hose.dart';

/// Hair on top of a one-piece or separate head.
enum ToonHair { none, curl, tuft, sprout }

/// Headwear of a [ToonRig].
enum ToonHat { none, boater, bowler, fedora, fez, topHat }

/// Costume and features of a [ToonRig] (the parts [RigSpec] does not
/// describe). Everything is optional; [ToonLook.of] derives a default from
/// the spec.
@immutable
class ToonLook {
  const ToonLook({
    this.hair = ToonHair.curl,
    this.hat = ToonHat.none,
    this.bowTie = true,
    this.nose = NoseStyle.button,
    this.ears = false,
    this.buttons = 0,
    this.eyeScale = 1,
    this.lashes = 0,
    this.hatFill = PaletteRole.ink,
    this.shoeFill = PaletteRole.ink,
    this.limbFill,
  });

  /// The default look for a spec: a hair curl and a bow tie.
  factory ToonLook.of(RigSpec spec) => const ToonLook();

  final ToonHair hair;
  final ToonHat hat;
  final bool bowTie;
  final NoseStyle nose;

  /// Round ears on the sides of the head.
  final bool ears;

  /// Chest buttons (vest), 0 = none.
  final int buttons;
  final double eyeScale;
  final int lashes;
  final PaletteRole hatFill;
  final PaletteRole shoeFill;

  /// Hose fill (null = solid ink hoses, the 1930s default).
  final PaletteRole? limbFill;
}

/// The procedural rubber-hose biped behind [createRig]: a one-piece bean /
/// ball / egg, or a pear / tall torso with a separate bobbing head; bezier
/// hose limbs with follow-through; gloves and shoes; a full face; all
/// twelve [RigAction]s on the 1930s bounce.
///
/// Subclasses (the detective cat) reuse the skeleton and override the
/// drawing hooks ([drawTorso], [drawHead], [drawBackAccessories],
/// [drawFrontAccessories]) and [shapePose].
class ToonRig extends HoseRig {
  ToonRig(super.spec, {ToonLook? look}) : look = look ?? ToonLook.of(spec) {
    final h = spec.height;
    separateHead = spec.body == RigBody.pear || spec.body == RigBody.tall;
    legLen = h * spec.limbLength * (spec.body == RigBody.tall ? 0.72 : 0.68);
    armLen = h * spec.limbLength * 0.66;
    hipH = legLen * 0.88;
    limbW = h * spec.limbWidth;
    switch (spec.body) {
      case RigBody.bean:
        bodyW = h * spec.bodyWidth * 0.86;
        bodyH = (h * 0.95 - hipH) / 0.9;
        taper = 0.08;
        bend = 0.1;
      case RigBody.ball:
        bodyW = h * math.max(0.66, spec.bodyWidth * 1.1);
        bodyH = bodyW * 1.02;
        taper = 0;
        bend = 0;
      case RigBody.egg:
        bodyW = h * spec.bodyWidth * 0.8;
        bodyH = (h * 0.95 - hipH) / 0.9;
        taper = 0.2;
        bend = 0.04;
      case RigBody.pear:
        bodyW = h * spec.bodyWidth * 0.74;
        bodyH = h * 0.32;
        taper = 0.36;
        bend = 0.06;
        headR = h * 0.205;
      case RigBody.tall:
        bodyW = h * spec.bodyWidth * 0.6;
        bodyH = h * 0.36;
        taper = -0.1;
        bend = 0.04;
        box = 0.25;
        headR = h * 0.165;
    }
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      hands[i].snap(side * bodyW * 0.6, -hipH - bodyH * 0.1);
      feet[i].snap(side * h * 0.1, 0);
    }
    for (final p in chain) {
      p.snap(0, -h);
    }
  }

  final ToonLook look;
  late final bool separateHead;
  late final double legLen, armLen, hipH, limbW;
  late final double bodyW, bodyH;
  double taper = 0, bend = 0, box = 0, headR = 0;

  // Springs (design space: facing +x, feet at y = 0, y down).
  final Spring2 hip = Spring2();
  final Spring1 tilt = Spring1();
  final Spring1 headTilt = Spring1();
  final Spring2 headLag = Spring2();
  final List<Spring2> hands = [Spring2(), Spring2()];
  final List<Spring2> feet = [Spring2(), Spring2()];

  /// A 5-link follow-through chain (hair curl, tail, scarf, tassel…).
  final List<Spring2> chain = [for (var i = 0; i < 5; i++) Spring2()];

  // Pose targets (written by the pose each step).
  double tHipX = 0, tHipY = 0, tTilt = 0, tHeadTilt = 0, sqBias = 0;
  final Float64List tHand = Float64List(4), tFoot = Float64List(4);
  final Float64List footPitch = Float64List(2);
  final List<HandShape> handShape = [HandShape.open, HandShape.open];
  final Float64List handBend = Float64List.fromList([1, -1]);
  final Float64List legBend = Float64List.fromList([1, 1]);
  double mouthOpen = 0;
  EyeState eyeState = EyeState.auto;
  MouthShape mouthShape = MouthShape.auto;
  double lookBiasY = 0;
  bool airborne = false;

  /// Dust puff timers per foot (seconds since contact, ≥ 1 = none).
  final Float64List dustAge = Float64List.fromList([1, 1]);
  final Float64List dustX = Float64List(2);
  final Float64List _lastFootY = Float64List(2);

  final Face face = Face();

  double get u => spec.height / 100;

  /// Rest shoulder / hip-root positions relative to the hip point.
  double get shoulderDY => separateHead ? -bodyH * 0.62 : -bodyH * 0.34;
  double get bodyCy => separateHead ? -bodyH * 0.45 : -bodyH * 0.4;

  // --------------------------------------------------------------- pose

  @override
  void animate(double h) {
    _pose();
    shapePose();
    // Springs.
    hip.step(h, tHipX, tHipY, 24, 0.55);
    tilt.step(h, tTilt, 18, 0.5);
    headTilt.step(h, tHeadTilt, 16, 0.42);
    headLag.step(h, 0, 0, 15, 0.35);
    // The head lags the hip's motion (a bobble).
    headLag.kick(-hip.vx * h * 9, -hip.vy * h * 9);
    for (var i = 0; i < 2; i++) {
      hands[i].step(h, tHand[i * 2], tHand[i * 2 + 1], 30, 0.46);
      feet[i].step(h, tFoot[i * 2], tFoot[i * 2 + 1], 44, 0.72);
      // Dust where a running foot lands.
      final fy = feet[i].y;
      if (_lastFootY[i] < -spec.height * 0.03 && fy >= -spec.height * 0.012 && action == RigAction.run) {
        dustAge[i] = 0;
        dustX[i] = feet[i].x - spec.height * 0.06;
      }
      _lastFootY[i] = fy;
      if (dustAge[i] < 1) dustAge[i] += h * 2.6;
    }
    if (sqBias != 0) squashSpring.step(h, sqBias, 10, 1);
    // Follow-through chain: each link springs toward a point hanging off
    // the previous one (gravity + drag against the motion).
    _chain(h);
  }

  void _chain(double h) {
    final anchorX = chainAnchorX, anchorY = chainAnchorY;
    var px = anchorX, py = anchorY;
    final seg = chainSegment;
    for (var i = 0; i < chain.length; i++) {
      final c = chain[i];
      final tx = px + chainRestX * seg - (hip.vx * 0.02 + speed * 0.0006 * seg) * (i + 1) * 0.4;
      final ty = py + chainRestY * seg - hip.vy * 0.004 * (i + 1);
      c.step(h, tx, ty, 26 - i * 3.0, 0.3);
      // Keep the link length.
      final dx = c.x - px, dy = c.y - py;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > seg * 1.25) {
        c
          ..x = px + dx / d * seg * 1.25
          ..y = py + dy / d * seg * 1.25;
      }
      px = c.x;
      py = c.y;
    }
  }

  /// Where the chain hangs from (design space) and its rest direction.
  double get chainAnchorX => 0;
  double get chainAnchorY => -hipH + hip.y + bodyCy - bodyH * 0.5 - (separateHead ? headR * 1.6 : 0);
  double get chainRestX => -0.35;
  double get chainRestY => -0.55;
  double get chainSegment => spec.height * 0.035;

  /// Hook for subclasses: adjust the targets after the standard pose.
  void shapePose() {}

  void _pose() {
    final h = spec.height;
    final uu = u;
    final t = actionTime;
    final bt = beat;
    final hop = Bounce.hop(bt), contact = Bounce.contact(bt);
    final shY = -hipH + bodyCy * 0 + shoulderDY;
    final shX = bodyW * 0.44;
    airborne = false;
    eyeState = EyeState.auto;
    mouthShape = MouthShape.auto;
    mouthOpen = talkLevel;
    lookBiasY = 0;
    sqBias = 0;
    tHipX = 0;
    tHeadTilt = 0;
    handBend[0] = 1;
    handBend[1] = -1;
    legBend[0] = 1;
    legBend[1] = 1;
    for (var i = 0; i < 2; i++) {
      handShape[i] = HandShape.open;
      footPitch[i] = 0;
    }

    switch (action) {
      case RigAction.idle:
        // The 1930s bounce: down on every beat, hang at the top.
        tHipY = (1 - hop) * 5.5 * uu;
        tTilt = math.sin(bt * math.pi) * 0.05;
        tHeadTilt = math.sin(bt * math.pi) * 0.09;
        sqBias = contact * 0.13 - hop * 0.04;
        for (var i = 0; i < 2; i++) {
          final s = i == 0 ? -1.0 : 1.0;
          _hand(i, s * (shX + 7 * uu + hop * 4 * uu), shY + armLen * 0.78 - hop * 3 * uu + (1 - hop) * 6 * uu);
          _foot(i, s * 10 * uu, 0);
          handShape[i] = HandShape.open;
        }
        footPitch[1] = -0.35 * hop; // toe tap on the beat
        // Now and then: a little whistle.
        final w = (time % 9.0);
        if (w > 6.2 && w < 8.2) {
          mouthShape = MouthShape.oh;
          tHeadTilt += 0.1;
        }
      case RigAction.walk:
        final ph = cycle;
        tHipY = -3.4 * uu * math.sin(ph).abs() + 1.5 * uu;
        tTilt = 0.07 + math.sin(ph * 2) * 0.02;
        tHeadTilt = math.sin(ph * 2 + 0.6) * 0.05;
        for (var i = 0; i < 2; i++) {
          final s = i == 0 ? -1.0 : 1.0;
          final pi = ph + i * math.pi;
          final stride = h * 0.15, lift = h * 0.11;
          _foot(i, -stride * math.cos(pi) + s * 3 * uu, -lift * math.max(0.0, math.sin(pi)));
          footPitch[i] = -0.35 * math.sin(pi);
          final sw = math.cos(pi);
          _hand(i, s * shX * 0.7 + sw * armLen * 0.55 + 4 * uu, shY + armLen * (0.72 - 0.12 * sw * sw));
        }
      case RigAction.run:
        final ph = cycle;
        airborne = false;
        tHipY = -3 * uu - 4 * uu * math.sin(ph).abs();
        tTilt = 0.12 + (speed.abs() / h).clamp(0.0, 3.0) * 0.045 + math.sin(ph * 2) * 0.03;
        tHeadTilt = 0.08;
        sqBias = -0.05;
        for (var i = 0; i < 2; i++) {
          final s = i == 0 ? -1.0 : 1.0;
          final pi = ph + i * math.pi;
          final stride = h * 0.21, lift = h * 0.17;
          final sn = math.sin(pi);
          _foot(i, -stride * math.cos(pi) + 6 * uu, sn > 0 ? -lift * sn : -lift * 0.08 * -sn);
          footPitch[i] = -0.5 * sn + 0.1;
          final sw = math.cos(pi);
          _hand(i, s * shX * 0.25 + sw * armLen * 0.72 + 10 * uu, shY + armLen * (0.42 - 0.3 * sw));
          handShape[i] = HandShape.fist;
          handBend[i] = -1;
        }
      case RigAction.jump:
        airborne = true;
        tHipY = -2 * uu;
        tTilt = -0.06 + Bounce.span(t, 0.1, 0.4) * 0.12;
        sqBias = -0.07;
        lookBiasY = -0.4;
        for (var i = 0; i < 2; i++) {
          final s = i == 0 ? -1.0 : 1.0;
          _hand(i, s * (shX + 6 * uu), shY - armLen * 0.82 + math.sin(t * 9 + i) * 2 * uu);
          handShape[i] = HandShape.wave;
          _foot(i, s * 7 * uu - 3 * uu, -hipH * 0.55 - 4 * uu);
          footPitch[i] = 0.55;
        }
        if (mouthOpen < 0.3) mouthShape = MouthShape.grin;
      case RigAction.fall:
        airborne = true;
        tHipY = 0;
        tTilt = 0.04;
        sqBias = 0.02;
        lookBiasY = 0.8;
        for (var i = 0; i < 2; i++) {
          final s = i == 0 ? -1.0 : 1.0;
          _hand(i, s * (shX + armLen * 0.55), shY - armLen * 0.45 + math.sin(time * 17 + i * 2) * 4 * uu);
          handShape[i] = HandShape.wave;
          _foot(i, s * 9 * uu + math.sin(time * 15 + i) * 3 * uu, -hipH * 0.12 + 2 * uu);
          footPitch[i] = -0.25;
        }
      case RigAction.land:
        final k = 1 - Bounce.span(t, 0, 0.3);
        tHipY = 7 * uu * k;
        tTilt = 0.1 * k;
        for (var i = 0; i < 2; i++) {
          final s = i == 0 ? -1.0 : 1.0;
          _hand(i, s * (shX + armLen * 0.75), shY + armLen * 0.15);
          _foot(i, s * 15 * uu, 0);
          legBend[i] = s;
        }
      case RigAction.hurt:
        final k = 1 - Bounce.span(t, 0.1, 0.6);
        tHipX = -7 * uu * k;
        tHipY = -2 * uu * k;
        tTilt = -0.4 * k;
        tHeadTilt = -0.2 * k;
        eyeState = t < 0.4 ? EyeState.squeeze : EyeState.auto;
        mouthShape = MouthShape.open;
        mouthOpen = 0.9;
        for (var i = 0; i < 2; i++) {
          final s = i == 0 ? -1.0 : 1.0;
          _hand(i, -shX * 0.4 + s * armLen * 0.45 - armLen * 0.35 * k, shY - armLen * (0.55 + 0.35 * k));
          handShape[i] = HandShape.wave;
          _foot(i, s * 15 * uu + 4 * uu * k, i == 1 ? -9 * uu * k : 0);
          footPitch[i] = -0.3 * k;
        }
      case RigAction.attack:
        final wind = Bounce.span(t, 0, 0.12), strike = Bounce.span(t, 0.12, 0.22), back = Bounce.span(t, 0.26, 0.46);
        final reach = strike * (1 - back);
        tTilt = -0.16 * wind * (1 - strike) + 0.24 * reach;
        tHipX = 5 * uu * reach;
        mouthShape = reach > 0.3 ? MouthShape.grimace : MouthShape.auto;
        _hand(0, shX * 0.2 + 6 * uu, shY + 4 * uu);
        handShape[0] = HandShape.fist;
        final hx = shX - armLen * 0.45 * wind * (1 - strike) + armLen * 1.55 * reach;
        _hand(1, hx, shY + 2 * uu - 6 * uu * wind * (1 - strike));
        handShape[1] = HandShape.fist;
        handBend[1] = -1;
        for (var i = 0; i < 2; i++) {
          final s = i == 0 ? -1.0 : 1.0;
          _foot(i, s * 13 * uu + 3 * uu * reach * s, 0);
        }
      case RigAction.cheer:
        // Hops on every beat, fists pumping.
        tHipY = -hop * 5 * uu;
        sqBias = contact * 0.1 - hop * 0.05;
        tTilt = math.sin(bt * math.pi) * 0.05;
        tHeadTilt = math.sin(bt * math.pi) * 0.1;
        mouthShape = MouthShape.grin;
        for (var i = 0; i < 2; i++) {
          final s = i == 0 ? -1.0 : 1.0;
          final pump = math.sin(bt * math.pi * 2 + i * math.pi);
          _hand(i, s * (shX + 7 * uu), shY - armLen * (0.7 + 0.22 * pump));
          handShape[i] = i == 1 ? HandShape.thumbsUp : HandShape.fist;
          _foot(i, s * 10 * uu, -hop * 9 * uu);
          footPitch[i] = 0.3 * hop;
        }
      case RigAction.taunt:
        // Hands on hips, nose up, laughing at double time.
        final fast = Bounce.hop(bt * 2);
        tHipY = (1 - fast) * 2 * uu;
        tTilt = -0.12;
        tHeadTilt = -0.16 + fast * 0.05;
        eyeState = EyeState.shut;
        mouthShape = MouthShape.grin;
        mouthOpen = 0.4 + fast * 0.5;
        for (var i = 0; i < 2; i++) {
          final s = i == 0 ? -1.0 : 1.0;
          _hand(i, s * bodyW * 0.48, -hipH + bodyCy * 0.35);
          handShape[i] = HandShape.fist;
          handBend[i] = -s;
          _foot(i, s * 11 * uu, 0);
        }
        footPitch[1] = -0.4 * fast;
      case RigAction.talk:
        tHipY = (1 - hop) * 1.5 * uu;
        tHeadTilt = math.sin(bt * math.pi) * 0.07;
        final syll = (math.sin(time * 19) * 0.5 + 0.5) * (math.sin(time * 5.3) * 0.3 + 0.7);
        mouthOpen = math.max(talkLevel, syll);
        mouthShape = MouthShape.open;
        final gest = math.sin(bt * math.pi * 0.5).abs();
        _hand(0, -(shX + 6 * uu), shY + armLen * 0.78);
        _hand(1, shX + armLen * 0.55, shY + armLen * (0.1 - 0.25 * gest));
        handShape[1] = gest > 0.6 ? HandShape.point : HandShape.open;
        for (var i = 0; i < 2; i++) {
          final s = i == 0 ? -1.0 : 1.0;
          _foot(i, s * 10 * uu, 0);
        }
      case RigAction.defeated:
        final k = Bounce.out(t / 0.4);
        tHipY = hipH * 0.75 * k;
        tTilt = -0.12 * k;
        tHeadTilt = -0.12 * k + math.sin(time * 3) * 0.05;
        eyeState = EyeState.cross;
        mouthShape = MouthShape.tongue;
        for (var i = 0; i < 2; i++) {
          final s = i == 0 ? -1.0 : 1.0;
          _hand(i, s * (shX + armLen * 0.35), -2 * uu);
          handShape[i] = HandShape.open;
          _foot(i, 12 * uu + i * 12 * uu, 0);
          footPitch[i] = -0.6 * k;
        }
    }
    // Pupils: games' lookAt wins; otherwise the pose's bias.
    if (expression == RigExpression.dizzy && eyeState == EyeState.auto) eyeState = EyeState.spiral;
  }

  void _hand(int i, double x, double y) {
    tHand[i * 2] = x;
    tHand[i * 2 + 1] = y;
  }

  void _foot(int i, double x, double y) {
    tFoot[i * 2] = x;
    tFoot[i * 2 + 1] = y;
  }

  @override
  void update(double dt) {
    // Locomotion cadence from speed (cycles/s).
    final h = spec.height;
    final cadence = switch (action) {
      RigAction.walk => (speed.abs() / (h * 0.6)).clamp(0.9, 2.2),
      RigAction.run => (speed.abs() / (h * 0.85)).clamp(1.5, 3.4),
      _ => 0.0,
    };
    cycle += dt * cadence * math.pi * 2;
    super.update(dt);
  }

  // -------------------------------------------------------------- build

  late final Contour _body = Contour(64);

  @override
  void build(RigPaintContext ctx) {
    final b = ink;
    final h = spec.height;
    b.begin(ctx, size: h, boilFrame: boilFrame);
    final pen = b.pen;
    final d = dir;
    final tn = turn;

    // Squash & stretch about the feet (or the middle when airborne).
    final s = squashAmount;
    final sy = (1 - s).clamp(0.62, 1.45);
    final sx = 1 / sy;
    final pivotY = airborne ? -hipH - bodyH * 0.4 : 0.0;
    pen
      ..reset()
      ..translate(0, pivotY)
      ..scale(sx, sy)
      ..translate(0, -pivotY)
      ..scale(d, 1);
    setBounds(-h * 0.55, -h * 1.12, h * 0.55, 0);
    b.shadeAcross(Rect.fromLTWH(-h * 0.4, -h, h * 0.8, h));

    final hipX = hip.x, hipY = -hipH + hip.y;
    final tl = tilt.value;
    // Body frame: rotate about the hip.
    _fx = hipX;
    _fy = hipY;
    _fc = math.cos(tl);
    _fs = math.sin(tl);
    final shY = shoulderDY;
    _far = tn > 0.3;
    final far = _far;
    final shFront = bodyW * 0.44;
    // Shoulder roots, front view → side view.
    _sh0 = Bounce.lerp(-shFront, -bodyW * 0.3, tn);
    // The near arm roots near the front edge in a side view (a shoulder
    // deep inside the belly draws a hook across it).
    _sh1 = Bounce.lerp(shFront, bodyW * 0.4, tn);
    _hp0 = Bounce.lerp(-bodyW * 0.2, -bodyW * 0.06, tn);
    _hp1 = Bounce.lerp(bodyW * 0.2, bodyW * 0.08, tn);

    // Dust behind, then the far limbs.
    if (emanata) {
      for (var i = 0; i < 2; i++) {
        if (dustAge[i] < 1) Emanata.dust(b, dustX[i], 0, h * 0.09, dustAge[i]);
      }
      if (action == RigAction.run && speed.abs() > h * 0.8) {
        Emanata.speedLines(
          b,
          -bodyW * 0.7,
          hipY - bodyH * 0.8,
          hipY + bodyH * 0.1,
          1,
          ((speed.abs() - h * 0.8) / h).clamp(0.3, 1.0),
        );
      }
      if (action == RigAction.hurt && actionTime < 0.22) {
        Emanata.impact(b, bx(-bodyW * 0.1, bodyCy), by(-bodyW * 0.1, bodyCy), h * 0.42);
      }
    }
    drawBackAccessories(b);
    if (far) drawArm(b, 0);
    drawLeg(b, 0);
    drawLeg(b, 1);

    // Torso (or the whole one-piece body with the face).
    pen
      ..save()
      ..translate(hipX, hipY)
      ..rotate(tl);
    drawTorso(b);
    pen.restore();

    // Head.
    final headX = bx(bodyW * 0.03 * tn, shY - headR * 0.8) + headLag.x;
    final headY = by(bodyW * 0.03 * tn, shY - headR * 0.8) + headLag.y;
    if (separateHead) {
      pen
        ..save()
        ..translate(headX, headY)
        ..rotate(tl * 0.4 + headTilt.value);
      drawHead(b, 0, 0, headR);
      pen.restore();
    } else {
      pen
        ..save()
        ..translate(hipX, hipY)
        ..rotate(tl)
        ..rotateAbout(headTilt.value * 0.5, 0, bodyCy);
      drawFaceOnBody(b);
      pen.restore();
    }
    drawFrontAccessories(b);

    if (!far) drawArm(b, 0);
    drawArm(b, 1);

    // Feelings.
    if (emanata) {
      final top = separateHead ? headY - headR : by(0, bodyCy - bodyH * 0.5);
      final cx = separateHead ? headX : bx(0, bodyCy);
      final r = separateHead ? headR : bodyW * 0.5;
      if (expression == RigExpression.dizzy || action == RigAction.defeated) {
        Emanata.dizzyStars(b, cx, top - r * 0.25, r * 0.9, time);
      }
      if (expression == RigExpression.scared) {
        Emanata.sweat(b, cx + r * 0.9, top + r * 0.5, h * 0.06, 1, (time * 1.6) % 1);
      }
      if (expression == RigExpression.surprised && expressionTime < 0.9) {
        Emanata.shock(
          b,
          cx,
          separateHead ? headY : by(0, bodyCy - bodyH * 0.18),
          r,
          Bounce.backOut(expressionTime / 0.25),
        );
      }
      if (expression == RigExpression.angry) {
        Emanata.steam(b, cx - r * 0.7, top + r * 0.2, h * 0.05, (time * 1.4) % 1, drift: -0.3);
        Emanata.steam(b, cx + r * 0.7, top + r * 0.2, h * 0.05, (time * 1.4 + 0.5) % 1, drift: 0.3);
      }
      if (action == RigAction.cheer) Emanata.sparkles(b, cx, top + r * 0.2, r * 1.4, time);
      if (action == RigAction.idle && mouthShape == MouthShape.oh) {
        Emanata.note(b, cx + r * 0.9, top + r * 0.4, h * 0.08, (time % 9.0 - 6.2) / 2);
      }
    }
    b.endLayer();
  }

  // Body frame of the current drawing (hip point + tilt) and limb roots.
  double _fx = 0, _fy = 0, _fc = 1, _fs = 0;
  double _sh0 = 0, _sh1 = 0, _hp0 = 0, _hp1 = 0;
  bool _far = false;

  /// Maps a point of the (tilted) body frame – origin at the hip – to
  /// design space.
  double bx(double x, double y) => _fx + x * _fc - y * _fs;
  double by(double x, double y) => _fy + x * _fs + y * _fc;

  /// Draws arm [i] (0 = far/back, 1 = near/front) with its glove.
  void drawArm(InkBuild b, int i) {
    final h = spec.height;
    final c = b.colors;
    final shY = shoulderDY;
    final limbFill = look.limbFill == null ? null : c.fill(look.limbFill!);
    final ox = i == 0 ? _sh0 : _sh1;
    final rootX = bx(ox * 0.92, shY), rootY = by(ox * 0.92, shY);
    final hs = hands[i];
    final tip = Hose.draw(
      b,
      rootX: rootX,
      rootY: rootY,
      tipX: hs.x,
      tipY: hs.y,
      length: armLen,
      width: limbW,
      bend: handBend[i],
      midX: (-hs.vx * 0.018).clamp(-armLen * 0.3, armLen * 0.3),
      midY: (-hs.vy * 0.018).clamp(-armLen * 0.3, armLen * 0.3),
      fill: limbFill,
      salt: 10 + i * 4,
    );
    if (spec.gloves) {
      Extremities.glove(
        b,
        x: tip.x,
        y: tip.y,
        angle: tip.angle,
        size: h * 0.078,
        fill: c.fill(spec.trim),
        shape: handOverride(i) ?? handShape[i],
        thumb: Extremities.thumbFront(tip.angle) * (i == 0 && !_far ? -1 : 1),
        salt: 20 + i * 8,
      );
    }
  }

  /// Draws leg [i] with its shoe.
  void drawLeg(InkBuild b, int i) {
    final h = spec.height;
    final c = b.colors;
    final limbFill = look.limbFill == null ? null : c.fill(look.limbFill!);
    final ox = i == 0 ? _hp0 : _hp1;
    final rootX = bx(ox, bodyH * 0.02), rootY = by(ox, bodyH * 0.02);
    final f = feet[i];
    final ankleY = math.min(f.y - (spec.shoes ? h * 0.045 : 0), 0.0);
    Hose.draw(
      b,
      rootX: rootX,
      rootY: rootY,
      tipX: f.x,
      tipY: ankleY,
      length: legLen,
      width: limbW * 1.05,
      bend: legBend[i] * (i == 0 ? 1 : 1),
      midX: (-f.vx * 0.01).clamp(-legLen * 0.2, legLen * 0.2),
      midY: 0,
      fill: limbFill,
      salt: 30 + i * 4,
    );
    if (spec.shoes) {
      Extremities.shoe(
        b,
        x: f.x,
        y: ankleY,
        size: h * 0.075,
        fill: c.fill(look.shoeFill),
        pitch: footPitch[i],
        salt: 40 + i * 4,
      );
    }
  }

  // --------------------------------------------------------- draw hooks

  /// The torso (pen at the hip, rotated with the body).
  void drawTorso(InkBuild b) {
    final c = b.colors;
    final pen = b.pen;
    final cy = bodyCy;
    final body = _body..clear();
    body.blob(pen, 0, cy, bodyW / 2, bodyH / 2, taper: taper, bend: bend, box: box, samples: 40);
    body.wobble(b.amp, b.frame, b.seed, 1);
    b.layer();
    b.blob(body, c.fill(spec.fill), depth: bodyW * 0.16, threshold: 0.28);
    if (look.buttons > 0) {
      for (var i = 0; i < look.buttons; i++) {
        b.inkFill();
        pen.circle(bodyW * 0.08 * turn, cy + bodyH * (0.05 + i * 0.16), spec.height * 0.018);
      }
    }
    b.endLayer();
    if (look.bowTie) _bowTie(b, bodyW * 0.1 * turn, separateHead ? cy - bodyH * 0.36 : cy + bodyH * 0.14);
  }

  void _bowTie(InkBuild b, double x, double y) {
    final pen = b.pen;
    final c = b.colors;
    final s = spec.height * 0.062;
    final flap = math.sin(time * 6) * 0.05;
    b.layer();
    b.shape(c.fill(spec.accent));
    pen
      ..moveTo(x, y)
      ..quadTo(x - s * 0.6, y - s * (0.9 + flap), x - s * 1.3, y - s * 0.75 + b.ja(51, 0.4))
      ..quadTo(x - s * 1.45, y, x - s * 1.3, y + s * 0.8)
      ..quadTo(x - s * 0.6, y + s * 0.8, x, y)
      ..close();
    b.shape(c.fill(spec.accent));
    pen
      ..moveTo(x, y)
      ..quadTo(x + s * 0.6, y - s * (0.9 - flap), x + s * 1.3, y - s * 0.75)
      ..quadTo(x + s * 1.45, y, x + s * 1.3, y + s * 0.8 + b.ja(52, 0.4))
      ..quadTo(x + s * 0.6, y + s * 0.8, x, y)
      ..close();
    b.shape(c.fill(spec.accent));
    pen.ellipse(x, y, s * 0.36, s * 0.42);
    b.brushQuad(3, x - s * 1.0, y - s * 0.3, x - s * 0.7, y, x - s * 1.0, y + s * 0.3, b.lw * 0.6);
    b.brushQuad(3, x + s * 1.0, y - s * 0.3, x + s * 0.7, y, x + s * 1.0, y + s * 0.3, b.lw * 0.6);
    b.endLayer();
  }

  /// The face painted on a one-piece body (pen at the hip).
  void drawFaceOnBody(InkBuild b) {
    final r = bodyW * 0.5;
    final cy = bodyCy - bodyH * (spec.body == RigBody.ball ? 0.12 : 0.24);
    _hair(b, bodyW * 0.08 * turn, bodyCy - bodyH * 0.5 + b.lw * 0.2, r);
    _setupFace(b, bodyW * 0.02, cy, r * 0.92);
    face.draw(b);
    _hat(b, bodyW * 0.06 * turn, bodyCy - bodyH * 0.47, bodyW * 0.95);
  }

  /// A separate head centred at ([x], [y]) of radius [r] (pen rotated with
  /// the head).
  void drawHead(InkBuild b, double x, double y, double r) {
    final c = b.colors;
    final pen = b.pen;
    final head = _body..clear();
    head.blob(pen, x, y, r * 1.02, r * 0.96, taper: 0.06, samples: 36);
    head.wobble(b.amp * 0.8, b.frame, b.seed, 3);
    b.layer();
    if (look.ears) {
      b.shape(c.fill(spec.fill));
      pen
        ..circle(x - r * 0.95, y - r * 0.05, r * 0.28)
        ..circle(x + r * 0.95, y - r * 0.05, r * 0.28);
    }
    b.blob(head, c.fill(spec.fill), depth: r * 0.3, threshold: 0.28);
    b.endLayer();
    _hair(b, x + r * 0.15 * turn, y - r * 0.95, r);
    _setupFace(b, x, y + r * 0.02, r);
    face.draw(b);
    _hat(b, x + r * 0.12 * turn, y - r * 0.8, r * 1.9);
  }

  void _setupFace(InkBuild b, double x, double y, double r) {
    face
      ..cx = x
      ..cy = y
      ..r = r
      ..turn = turn
      ..expression = expression
      ..eyes = spec.eyes
      ..eyeScale = look.eyeScale * (separateHead ? 1.05 : 1.2)
      ..mouthW = separateHead ? 0.9 : 1.08
      ..blink = blinkAmount
      ..lookX = lookSpring.x
      ..lookY = (lookSpring.y + lookBiasY).clamp(-1.0, 1.0)
      ..eyeState = eyeState
      ..spin = time * 6
      ..tremble = expression == RigExpression.scared ? spec.height * 0.006 : 0
      ..nose = look.nose
      ..skin = b.colors.fill(spec.fill)
      ..mouth = mouthShape
      ..mouthOpen = mouthOpen
      ..lashes = look.lashes
      ..salt = 200;
  }

  void _hair(InkBuild b, double x, double y, double r) {
    final pen = b.pen;
    switch (look.hair) {
      case ToonHair.none:
        return;
      case ToonHair.curl:
        // A single spring-loaded kiss-curl, swinging on the chain.
        final sway = ((chain[2].x - chainAnchorX) * 0.25).clamp(-r * 0.3, r * 0.3);
        final ct = b.contour(2)..clear(closed: false);
        ct.cubic(
          pen,
          x - r * 0.02,
          y + r * 0.06,
          x + sway * 0.2,
          y - r * 0.2,
          x + r * 0.05 + sway,
          y - r * 0.36,
          x + r * 0.24 + sway,
          y - r * 0.34,
          samples: 8,
        );
        // Then a spiral turning back in on itself.
        final ox = x + r * 0.2 + sway, oy = y - r * 0.24;
        for (var i = 1; i <= 14; i++) {
          final k = i / 14;
          final a = -math.pi * 0.5 + k * math.pi * 1.7;
          final rr = r * 0.11 * (1 - k * 0.55);
          ct.addPen(pen, ox + math.cos(a) * rr + r * 0.04 * (1 - k), oy + math.sin(a) * rr);
        }
        b.layer();
        b.brush(ct, b.lw * 1.7, taperIn: 0.02, taperOut: 0.45, press: 0.35, minWidth: 0.3);
        b.endLayer();
      case ToonHair.tuft:
        b.layer();
        for (var i = -1; i <= 1; i++) {
          b.brushQuad(
            2,
            x + i * r * 0.12,
            y + r * 0.04,
            x + i * r * 0.3,
            y - r * 0.3,
            x + i * r * 0.36 + b.ja(70 + i),
            y - r * 0.42,
            b.lw * 1.6,
            taperIn: 0.05,
            taperOut: 0.8,
          );
        }
        b.endLayer();
      case ToonHair.sprout:
        b.layer();
        b.brushQuad(
          2,
          x,
          y + r * 0.04,
          x - r * 0.1,
          y - r * 0.3,
          x + r * 0.05,
          y - r * 0.42,
          b.lw * 1.3,
          taperIn: 0.05,
          taperOut: 0.2,
        );
        b.shape(b.colors.fill(spec.accent));
        pen
          ..ellipse(x - r * 0.12, y - r * 0.44, r * 0.14, r * 0.07, -0.5)
          ..ellipse(x + r * 0.2, y - r * 0.48, r * 0.14, r * 0.07, 0.4);
        b.endLayer();
    }
  }

  void _hat(InkBuild b, double x, double y, double w) {
    final c = b.colors;
    final fill = c.fill(look.hatFill);
    final band = c.fill(spec.accent);
    final tl = 0.08 + headTilt.value * 0.3;
    switch (look.hat) {
      case ToonHat.none:
        return;
      case ToonHat.boater:
        Hats.boater(b, x, y, w, tl, fill: fill, band: band);
      case ToonHat.bowler:
        Hats.bowler(b, x, y, w * 0.9, tl, fill: fill, band: band);
      case ToonHat.fedora:
        Hats.fedora(b, x, y, w, tl, fill: fill, band: band);
      case ToonHat.fez:
        Hats.fez(b, x, y, w * 0.6, tl, fill: fill);
      case ToonHat.topHat:
        Hats.topHat(b, x, y, w * 0.8, w * 0.7, tl, fill: fill, band: band);
    }
  }

  /// Drawn before the far limbs (tails, capes).
  void drawBackAccessories(InkBuild b) {}

  /// Drawn after the head, before the near arm.
  void drawFrontAccessories(InkBuild b) {}
}
