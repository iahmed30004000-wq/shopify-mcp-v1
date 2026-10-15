import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'era.dart';

/// Everything that makes a frame look and sound like its decade.
///
/// A skin is assembled per [Era] by `EraSkins.of` from per-aspect tables
/// that each engine agent owns (see ENGINE.md → "Era skins"):
///
/// | field                      | table file                    | owner  |
/// |----------------------------|-------------------------------|--------|
/// | [palette]                  | core/era_palettes.dart        | core   |
/// | [grade] [halftone] [hatch] | fx/era_grades.dart            | FX     |
/// | [ink]                      | rig/era_inks.dart             | rig    |
/// | [score]                    | audio/era_scores.dart         | audio  |
/// | [stage] [titles]           | stage/era_stages.dart         | stage  |
///
/// Skins are immutable; games may derive variants with [copyWith] (e.g. a
/// boss fight with a redder palette) but never mutate a shared one.
@immutable
class EraSkin {
  const EraSkin({
    required this.era,
    required this.palette,
    required this.grade,
    required this.halftone,
    required this.hatch,
    required this.ink,
    required this.score,
    required this.stage,
    required this.titles,
  });

  final Era era;
  final EraPalette palette;
  final FilmGrade grade;
  final HalftoneStyle halftone;
  final CrosshatchStyle hatch;
  final InkStyle ink;
  final ScoreStyle score;
  final StageStyle stage;
  final TitleStyle titles;

  EraSkin copyWith({
    EraPalette? palette,
    FilmGrade? grade,
    HalftoneStyle? halftone,
    CrosshatchStyle? hatch,
    InkStyle? ink,
    ScoreStyle? score,
    StageStyle? stage,
    TitleStyle? titles,
  }) => EraSkin(
    era: era,
    palette: palette ?? this.palette,
    grade: grade ?? this.grade,
    halftone: halftone ?? this.halftone,
    hatch: hatch ?? this.hatch,
    ink: ink ?? this.ink,
    score: score ?? this.score,
    stage: stage ?? this.stage,
    titles: titles ?? this.titles,
  );
}

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

/// Semantic colour roles. Characters and props name a role instead of a raw
/// colour so the same rig re-skins itself per era (a `paper` body is cream
/// in 1920s sepia, white in 1930s ink, pastel in 1950s Technicolor).
enum PaletteRole { ink, paper, shadow, midtone, highlight, accent, accent2, backdrop }

/// An era's colours. Monochrome eras keep [accent]/[accent2] inside the
/// ink → paper range (the film grade maps everything to that duotone anyway).
@immutable
class EraPalette {
  const EraPalette({
    required this.ink,
    required this.paper,
    required this.shadow,
    required this.midtone,
    required this.highlight,
    required this.accent,
    required this.accent2,
    required this.backdrop,
    required this.curtain,
    required this.curtainShade,
    required this.footlight,
  });

  /// Outlines, pupils, the iris mask; the dark end of the film duotone.
  final Color ink;

  /// Paper / film base; the light end of the film duotone.
  final Color paper;

  /// Shadow fill (under halftone / hatching).
  final Color shadow;

  /// Mid-tone fill (bodies, props).
  final Color midtone;

  /// Specular / rim light.
  final Color highlight;

  /// Primary accent (hero, UI emphasis).
  final Color accent;

  /// Secondary accent (villains, hazards).
  final Color accent2;

  /// Default world backdrop behind the play area.
  final Color backdrop;

  /// Stage dressing: curtain velvet, its fold shadow, footlight glow.
  final Color curtain;
  final Color curtainShade;
  final Color footlight;

  Color resolve(PaletteRole role) => switch (role) {
    PaletteRole.ink => ink,
    PaletteRole.paper => paper,
    PaletteRole.shadow => shadow,
    PaletteRole.midtone => midtone,
    PaletteRole.highlight => highlight,
    PaletteRole.accent => accent,
    PaletteRole.accent2 => accent2,
    PaletteRole.backdrop => backdrop,
  };
}

// ---------------------------------------------------------------------------
// Film grade (FX agent's knobs)
// ---------------------------------------------------------------------------

/// Which full-frame post shader grades the era.
enum FilmProcess {
  /// shaders/cinema/film_grade.frag (1920s–1970s).
  film,

  /// shaders/cinema/vhs.frag (1980s).
  vhs,
}

/// Post-processing parameters of an era (the values FilmFx feeds to
/// film_grade.frag / vhs.frag, see `shader_uniforms.dart`). All amounts are
/// 0..1 unless noted; sizes are logical px.
@immutable
class FilmGrade {
  const FilmGrade({
    this.process = FilmProcess.film,
    this.projectionFps = 24,
    this.saturation = 1,
    this.tint = const Color(0xFFFFFFFF),
    this.tintStrength = 0,
    this.contrast = 1,
    this.brightness = 0,
    this.posterize = 0,
    this.grain = 0.3,
    this.grainSize = 1.5,
    this.flicker = 0.3,
    this.vignette = 0.4,
    this.gateWeave = 1,
    this.dust = 0.3,
    this.scratches = 0.2,
    this.halation = 0,
    this.scanlines = 0,
    this.chromaShift = 0,
    this.chromaBleed = 0,
    this.tracking = 0,
    this.tapeWobble = 0,
  });

  final FilmProcess process;

  /// Film frames per second: grain, weave, flicker, dust and scratches change
  /// once per film frame (18 for silent-era undercranking, 24 for sound film,
  /// 30 for video) – independent of the display's 60/120 Hz.
  final double projectionFps;

  /// 0 = pure ink→paper duotone (monochrome stock), 1 = source colours.
  final double saturation;
  final Color tint;
  final double tintStrength;

  /// 1 = neutral.
  final double contrast;

  /// Offset, 0 = neutral.
  final double brightness;

  /// Colour levels per channel, 0 = off (e.g. 6 for a limited-ink print).
  final double posterize;

  final double grain;

  /// Grain cell size in logical px.
  final double grainSize;
  final double flicker;
  final double vignette;

  /// Gate weave amplitude in logical px.
  final double gateWeave;
  final double dust;
  final double scratches;

  /// Brights bleeding a warm glow (Technicolor, grindhouse prints).
  final double halation;

  // --- VHS only (FilmProcess.vhs) ---
  final double scanlines;

  /// Red/blue channel offset in logical px.
  final double chromaShift;

  /// Horizontal colour smear in logical px.
  final double chromaBleed;

  /// Rolling tracking band strength.
  final double tracking;

  /// Horizontal tape wobble in logical px.
  final double tapeWobble;

  /// The same grade with every "damage" effect (grain, flicker, weave, dust,
  /// scratches, tracking, wobble) scaled by [amount] – used for the
  /// reduce-flicker accessibility setting and the clean LOD.
  FilmGrade scaled(double amount) {
    final a = amount.clamp(0.0, 1.0);
    return FilmGrade(
      process: process,
      projectionFps: projectionFps,
      saturation: saturation,
      tint: tint,
      tintStrength: tintStrength,
      contrast: contrast,
      brightness: brightness,
      posterize: posterize,
      grain: grain * a,
      grainSize: grainSize,
      flicker: flicker * a,
      vignette: vignette,
      gateWeave: gateWeave * a,
      dust: dust * a,
      scratches: scratches * a,
      halation: halation,
      scanlines: scanlines,
      chromaShift: chromaShift,
      chromaBleed: chromaBleed,
      tracking: tracking * a,
      tapeWobble: tapeWobble * a,
    );
  }
}

/// Dot shape of a halftone screen.
enum HalftoneShape { round, line }

/// Halftone shading (halftone.frag) used by rigs, props and backdrops.
@immutable
class HalftoneStyle {
  const HalftoneStyle({
    this.cellSize = 5,
    this.angle = 0.785398,
    this.shape = HalftoneShape.round,
    this.softness = 0.6,
    this.strength = 0.8,
  });

  /// Dot pitch in logical px (on screen, independent of world zoom).
  final double cellSize;

  /// Screen angle in radians (45° is the classic print angle).
  final double angle;
  final HalftoneShape shape;

  /// Dot edge softness in px.
  final double softness;

  /// Maximum tone (0..1) of the darkest shading.
  final double strength;
}

/// Pen hatching (crosshatch.frag).
@immutable
class CrosshatchStyle {
  const CrosshatchStyle({
    this.spacing = 5,
    this.angle = 0.9,
    this.lineWidth = 1.1,
    this.wobble = 0.8,
    this.strength = 0.85,
  });

  final double spacing;
  final double angle;
  final double lineWidth;
  final double wobble;
  final double strength;
}

// ---------------------------------------------------------------------------
// Ink (rig agent's knobs)
// ---------------------------------------------------------------------------

/// How forms are shaded under the ink line.
enum ShadingMode {
  /// Flat fills only.
  flat,

  /// Halftone dots in the shadows (1930s cartoon print).
  halftone,

  /// Pen hatching in the shadows (silent engravings, noir).
  crosshatch,

  /// Smooth painted gradients (1950s Technicolor cel paint).
  gradient,

  /// Glowing strokes on dark (1980s neon).
  neon,
}

/// The ink line of an era: how characters and props are drawn.
@immutable
class InkStyle {
  const InkStyle({
    this.lineWidth = 3,
    this.taper = 0.5,
    this.boilAmplitude = 0.8,
    this.boilFps = 12,
    this.shading = ShadingMode.halftone,
    this.shadeStrength = 0.6,
    this.dryness = 0.15,
    this.glow = 0,
  });

  /// Outline width in world units for a 100-unit-tall character.
  final double lineWidth;

  /// 0 = uniform line, 1 = strong brush pressure variation.
  final double taper;

  /// Control-point jitter (world units) re-rolled every boil frame.
  final double boilAmplitude;

  /// Line boil rate: drawings are re-inked this many times per second
  /// (12 = "on twos", the classic rate). 0 disables boil.
  final double boilFps;
  final ShadingMode shading;
  final double shadeStrength;

  /// Dry-brush texture of the ink (ink_line.frag), 0 = solid.
  final double dryness;

  /// Neon glow radius (world units), 0 = none.
  final double glow;
}

// ---------------------------------------------------------------------------
// Score (audio agent's knobs)
// ---------------------------------------------------------------------------

/// Procedural music style of an era (all compositions are original,
/// generated from period-style harmony and rhythm – never quotations).
enum MusicStyle {
  /// Silent-film piano: stride / ragtime left hand, syncopated melody.
  ragtime,

  /// 1930s hot jazz / swing: clarinet, muted trumpet, tuba bass, banjo.
  swing,

  /// 1940s noir: slow walking bass, brushed drums, muted trumpet, vibes.
  noirJazz,

  /// 1950s big band / mambo: brass section hits, saxes, bongos.
  bigBand,

  /// 1970s grindhouse funk: wah guitar, clavinet, breakbeats.
  funk,

  /// 1980s synthwave: arpeggiated saws, gated drums, analog bass.
  synthwave,
}

@immutable
class ScoreStyle {
  const ScoreStyle({
    required this.style,
    this.tempo = 120,
    this.swing = 0,
    this.rootMidi = 57,
    this.minor = false,
    this.lofi = 0.3,
    this.crackle = 0,
  });

  final MusicStyle style;

  /// Beats per minute at intensity 0.5.
  final double tempo;

  /// 0 = straight eighths, 1 = full triplet swing.
  final double swing;

  /// Tonal centre as a MIDI note number.
  final int rootMidi;
  final bool minor;

  /// Period playback degradation (band-limit, wow & flutter), 0..1.
  final double lofi;

  /// Gramophone / optical-track crackle, 0..1.
  final double crackle;
}

// ---------------------------------------------------------------------------
// Stage & titles (stage agent's knobs)
// ---------------------------------------------------------------------------

/// The architecture framing the play area.
enum ProsceniumStyle {
  /// 1920s picture-palace plaster and gilt.
  picturePalace,

  /// 1930s art-deco sunbursts and stepped chrome.
  artDeco,

  /// 1940s shadowy arch with venetian-blind light.
  noirArch,

  /// 1950s space-age boomerangs and starbursts.
  atomic,

  /// 1970s marquee bulbs and peeling paint.
  marquee,

  /// 1980s neon tubes on a perspective grid.
  neon,
}

enum CurtainKind { velvet, painted, tattered, neon }

@immutable
class StageStyle {
  const StageStyle({
    required this.proscenium,
    this.curtain = CurtainKind.velvet,
    this.curtainFolds = 7,
    this.sideWidth = 0.09,
    this.valanceHeight = 0.075,
    this.footlights = 9,
    this.footlightHeight = 0.055,
    this.footlightFlicker = 0.3,
    this.spotlight = true,
  });

  final ProsceniumStyle proscenium;
  final CurtainKind curtain;

  /// Velvet folds per side panel.
  final int curtainFolds;

  /// Width of each side curtain when open, as a fraction of screen width.
  final double sideWidth;

  /// Height of the top valance as a fraction of screen height.
  final double valanceHeight;

  /// Number of footlight bulbs along the stage lip.
  final int footlights;

  /// Height of the footlight strip as a fraction of screen height.
  final double footlightHeight;
  final double footlightFlicker;

  /// Whether a follow-spot is available.
  final bool spotlight;
}

/// Decoration of intertitle cards and HUD plaques.
enum TitleFrame { ornate, artDeco, plain, marquee, osd }

/// How scenes open and close.
enum EraTransition { iris, burn, wipe, glitch }

/// Iris opening shape (iris.frag's uStyle.x).
enum IrisShape { circle, heart, star, keyhole }

@immutable
class TitleStyle {
  const TitleStyle({
    required this.fontFamily,
    this.weight = FontWeight.w700,
    this.frame = TitleFrame.artDeco,
    this.letterSpacing = 0,
    this.transition = EraTransition.iris,
    this.irisShape = IrisShape.circle,
  });

  /// One of the bundled families: 'Amiri' (ornate naskh), 'ReemKufi'
  /// (display kufi), 'PlexArabic' (clean sans). Zero font files are added
  /// by the engine – everything else is drawn.
  final String fontFamily;
  final FontWeight weight;
  final TitleFrame frame;
  final double letterSpacing;
  final EraTransition transition;
  final IrisShape irisShape;
}
