import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'era_skin.dart';
import 'film_clock.dart';

/// What a character is doing. The rig blends between action poses with
/// springy overlap (rubber-hose limbs never snap).
enum RigAction { idle, walk, run, jump, fall, land, hurt, attack, cheer, taunt, talk, defeated }

/// Face / eye state (pie-cut pupils change shape, brows tilt, mouth).
enum RigExpression { neutral, happy, angry, scared, surprised, dizzy, determined, sly }

/// Base body silhouettes of the procedural rig. Original shapes only – no
/// existing cartoon character's design (see ENGINE.md → Originality).
enum RigBody { bean, ball, egg, pear, tall }

/// Eye style. [pieCut] is the 1930s pupil with a wedge cut out.
enum RigEyes { pieCut, round, dots }

/// Data description of a procedural rubber-hose character.
///
/// Colours are [PaletteRole]s resolved against the current era palette, so
/// one spec re-skins itself per era. Special characters and bosses may use
/// richer builders published by the rig agent in engine/rig/ – they still
/// implement [RigCharacter].
@immutable
class RigSpec {
  const RigSpec({
    required this.id,
    this.body = RigBody.bean,
    this.height = 100,
    this.bodyWidth = 0.62,
    this.limbLength = 0.5,
    this.limbWidth = 0.085,
    this.fill = PaletteRole.paper,
    this.trim = PaletteRole.paper,
    this.accent = PaletteRole.accent,
    this.eyes = RigEyes.pieCut,
    this.gloves = true,
    this.shoes = true,
    this.bounciness = 1,
    this.seed = 0,
  });

  /// Stable id (used for seeds and debugging).
  final String id;
  final RigBody body;

  /// Total height in world units, feet to crown, standing idle.
  final double height;

  /// Body width relative to [height].
  final double bodyWidth;

  /// Arm/leg length relative to [height].
  final double limbLength;

  /// Hose thickness relative to [height].
  final double limbWidth;

  /// Body fill.
  final PaletteRole fill;

  /// Gloves and shoes.
  final PaletteRole trim;

  /// Details (bow tie, belt, hat band…).
  final PaletteRole accent;
  final RigEyes eyes;
  final bool gloves;
  final bool shoes;

  /// Squash & stretch / overshoot multiplier (0 = stiff, 1 = normal, 2 = jelly).
  final double bounciness;
  final int seed;
}

/// A procedural rubber-hose character: bezier hose limbs, squash & stretch,
/// pie-cut eyes, line boil – drawn with the era's ink.
///
/// Coordinate system: origin at the centre between the feet, y down (so the
/// character extends to negative y), 1 unit = 1 world unit. [paint] never
/// allocates (paths are rebuilt only when [FilmClock.boilChanged] or the
/// pose changed, and reused otherwise).
///
/// Owner: rig agent (implementations in engine/rig/, created by `createRig`
/// in rig/rig_entry.dart). Use it in a Flame world through `RigComponent`.
abstract interface class RigCharacter {
  RigSpec get spec;

  RigAction get action;

  /// Switches action (blended). Re-triggering the current action is a no-op
  /// unless [restart] (e.g. a second jump).
  void act(RigAction action, {bool restart = false});

  RigExpression get expression;
  set expression(RigExpression value);

  /// 1 = facing right (screen), -1 = facing left. Values in between are
  /// allowed while turning (the rig squashes through the turn).
  double get facing;
  set facing(double value);

  /// Ground speed in world units/s: drives walk/run cadence and lean.
  double get speed;
  set speed(double value);

  /// Where the pupils look: a direction in character space (need not be
  /// normalised); `null` = straight ahead / at the audience.
  void lookAt(Offset? direction);

  /// Squash (positive, e.g. landing) or stretch (negative, e.g. take-off)
  /// impulse; a spring brings the body back with overshoot. Volume is kept.
  void squash(double amount);

  /// Advances the rig (springs, cycles, blinks) by gameplay time.
  void update(double dt);

  /// Draws the character with the era's ink ([EraSkin.ink]), palette and
  /// shading. Boil jitter must be seeded from [FilmClock.boilFrame].
  void paint(Canvas canvas, EraSkin skin, FilmClock clock);

  /// Local bounds of the current pose (for culling and hit boxes).
  Rect get bounds;

  void dispose();
}
