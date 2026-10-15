import 'package:flutter/foundation.dart';

/// How much GPU the film pass may spend.
///
/// The film pass is one offscreen image and one full-screen shader draw per
/// frame; quality changes the offscreen resolution and which optical
/// effects run (see film_stock.frag's budget).
enum FilmQuality {
  /// Mid-range phones on battery saver, old GPUs: 0.6 × resolution, one
  /// texture fetch per pixel, single-octave grain, no soft focus, bloom or
  /// line boil.
  lowPower(resolutionScale: 0.6, shaderLevel: 0),

  /// The default on phones: 0.8 × resolution, every effect.
  balanced(resolutionScale: 0.8, shaderLevel: 1),

  /// Native resolution, every effect (tablets, screenshots, high-end).
  full(resolutionScale: 1, shaderLevel: 2);

  const FilmQuality({required this.resolutionScale, required this.shaderLevel});

  /// Offscreen resolution multiplier (on top of the device pixel ratio).
  final double resolutionScale;

  /// film_stock.frag's `uInk.a`: 0 low power, 1 balanced, 2 full.
  final double shaderLevel;

  /// One step cheaper (low power stays low power).
  FilmQuality get cheaper => switch (this) {
    FilmQuality.full => FilmQuality.balanced,
    _ => FilmQuality.lowPower,
  };
}

/// The FX agent's per-era extras on top of the core [FilmGrade]: how the
/// print is stylised (halftone screen, pen hatching, venetian-blind light,
/// three-strip dyes, faded dyes) and which reel events happen (splices,
/// frame slips, cue marks, hairs in the gate, chemical blotches).
///
/// Pure const data; `eraLook` in era_looks.dart holds one per era. Games may
/// derive variants with [copyWith] and hand them to `ReelFilmFx.look`.
/// Amounts are 0..1 unless noted; sizes are logical px.
@immutable
class FilmLook {
  const FilmLook({
    this.halftone = 0,
    this.halftoneCell = 4.5,
    this.screenAngle = 0.785398,
    this.hatch = 0,
    this.hatchSpacing = 5,
    this.lineBoil = 0,
    this.softFocus = 0,
    this.toe = 0,
    this.blinds = 0,
    this.blindsAngle = -0.42,
    this.blindsPeriod = 44,
    this.blindsDrift = 0.03,
    this.threeStrip = 0,
    this.dyeFade = 0,
    this.blackLift = 0,
    this.bloom = 0,
    this.gateCorner = 0,
    this.hotspot = 0,
    this.colourGrain = 0,
    this.age = 0,
    this.frameLine = 0,
    this.splicesPerMinute = 0,
    this.frameSlipsPerMinute = 0,
    this.blotchesPerMinute = 0,
    this.hairsPerMinute = 0,
    this.cueMarks = false,
    this.reelSeconds = 36,
  });

  /// 1930s print: an AM halftone screen over the mid and shadow tones.
  final double halftone;

  /// Halftone dot pitch in logical px.
  final double halftoneCell;

  /// Screen angle (halftone rows and hatch strokes) in radians.
  final double screenAngle;

  /// Engraving / noir: pen hatching replaces the shadow greys.
  final double hatch;

  /// Hatch line pitch in logical px.
  final double hatchSpacing;

  /// Whole-frame 12 fps line boil in px: every inked edge wobbles "on
  /// twos", in sync with FilmClock.boilFrame.
  final double lineBoil;

  /// Old-lens softness (silent era).
  final double softFocus;

  /// Black crush: a toe on the print curve (noir's inky shadows).
  final double toe;

  /// Venetian-blind light thrown across the set (noir).
  final double blinds;

  /// Direction of the slats' shadows (radians).
  final double blindsAngle;

  /// Slat pitch in logical px.
  final double blindsPeriod;

  /// Slow drift of the slat shadows in periods per second (a passing car's
  /// headlights, a swaying blind).
  final double blindsDrift;

  /// Technicolor dye transfer: pure saturated separations, deep key blacks.
  final double threeStrip;

  /// Faded chromogenic print: the cyan dye fades first (magenta cast).
  final double dyeFade;

  /// Milky blacks of a worn or faded print.
  final double blackLift;

  /// Soft bloom of the brights (wide, neutral; Technicolor).
  final double bloom;

  /// Rounded corners of the projector aperture in logical px (0 = none).
  final double gateCorner;

  /// Brighter centre from the projector lamp.
  final double hotspot;

  /// 0 = monochrome grain, 1 = independent grain per dye layer.
  final double colourGrain;

  /// Blotchy uneven density of an old print (nitrate age).
  final double age;

  /// The black frame line peeking at the top/bottom under gate weave.
  final double frameLine;

  /// Splices passing through the gate (a bright tape line, a jump).
  final double splicesPerMinute;

  /// Frame slips: the loop is lost and the frame line rolls through.
  final double frameSlipsPerMinute;

  /// One-frame chemical stains / emulsion lifts.
  final double blotchesPerMinute;

  /// Hairs caught in the gate (they stay a few seconds).
  final double hairsPerMinute;

  /// Cigarette-burn reel-change cue marks (motor cue, then changeover cue).
  final bool cueMarks;

  /// Game-time "reel" length between cue-mark pairs, in seconds.
  final double reelSeconds;

  /// A look with no print stylisation and no reel events (a clean print).
  static const clean = FilmLook();

  FilmLook copyWith({
    double? halftone,
    double? halftoneCell,
    double? screenAngle,
    double? hatch,
    double? hatchSpacing,
    double? lineBoil,
    double? softFocus,
    double? toe,
    double? blinds,
    double? blindsAngle,
    double? blindsPeriod,
    double? blindsDrift,
    double? threeStrip,
    double? dyeFade,
    double? blackLift,
    double? bloom,
    double? gateCorner,
    double? hotspot,
    double? colourGrain,
    double? age,
    double? frameLine,
    double? splicesPerMinute,
    double? frameSlipsPerMinute,
    double? blotchesPerMinute,
    double? hairsPerMinute,
    bool? cueMarks,
    double? reelSeconds,
  }) => FilmLook(
    halftone: halftone ?? this.halftone,
    halftoneCell: halftoneCell ?? this.halftoneCell,
    screenAngle: screenAngle ?? this.screenAngle,
    hatch: hatch ?? this.hatch,
    hatchSpacing: hatchSpacing ?? this.hatchSpacing,
    lineBoil: lineBoil ?? this.lineBoil,
    softFocus: softFocus ?? this.softFocus,
    toe: toe ?? this.toe,
    blinds: blinds ?? this.blinds,
    blindsAngle: blindsAngle ?? this.blindsAngle,
    blindsPeriod: blindsPeriod ?? this.blindsPeriod,
    blindsDrift: blindsDrift ?? this.blindsDrift,
    threeStrip: threeStrip ?? this.threeStrip,
    dyeFade: dyeFade ?? this.dyeFade,
    blackLift: blackLift ?? this.blackLift,
    bloom: bloom ?? this.bloom,
    gateCorner: gateCorner ?? this.gateCorner,
    hotspot: hotspot ?? this.hotspot,
    colourGrain: colourGrain ?? this.colourGrain,
    age: age ?? this.age,
    frameLine: frameLine ?? this.frameLine,
    splicesPerMinute: splicesPerMinute ?? this.splicesPerMinute,
    frameSlipsPerMinute: frameSlipsPerMinute ?? this.frameSlipsPerMinute,
    blotchesPerMinute: blotchesPerMinute ?? this.blotchesPerMinute,
    hairsPerMinute: hairsPerMinute ?? this.hairsPerMinute,
    cueMarks: cueMarks ?? this.cueMarks,
    reelSeconds: reelSeconds ?? this.reelSeconds,
  );
}
