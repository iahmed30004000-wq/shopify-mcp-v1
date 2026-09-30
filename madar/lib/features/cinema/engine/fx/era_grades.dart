import 'dart:ui';

import '../core/era.dart';
import '../core/era_skin.dart';

// Per-era film grade, halftone and hatching tables.
// Owner: FX agent (tune freely – pure const data, import only core types).

FilmGrade eraGrade(Era era) => switch (era) {
  Era.silent => const FilmGrade(
    projectionFps: 18,
    saturation: 0,
    contrast: 1.18,
    brightness: 0.02,
    grain: 0.7,
    grainSize: 1.6,
    flicker: 0.7,
    vignette: 0.65,
    gateWeave: 1.6,
    dust: 0.6,
    scratches: 0.55,
  ),
  Era.rubberHose => const FilmGrade(
    saturation: 0.08,
    contrast: 1.12,
    grain: 0.45,
    grainSize: 1.4,
    flicker: 0.3,
    vignette: 0.62,
    gateWeave: 0.9,
    dust: 0.35,
    scratches: 0.25,
  ),
  Era.noir => const FilmGrade(
    saturation: 0,
    contrast: 1.35,
    brightness: -0.03,
    grain: 0.4,
    flicker: 0.15,
    vignette: 0.75,
    gateWeave: 0.5,
    dust: 0.15,
    scratches: 0.1,
  ),
  Era.technicolor => const FilmGrade(
    saturation: 1.05,
    tint: Color(0xFFFFF0D8),
    tintStrength: 0.25,
    contrast: 1.08,
    grain: 0.26,
    grainSize: 1.2,
    flicker: 0.08,
    vignette: 0.4,
    gateWeave: 0.4,
    dust: 0.08,
    scratches: 0.05,
    halation: 0.35,
  ),
  Era.grindhouse => const FilmGrade(
    saturation: 0.85,
    tint: Color(0xFFFFC98A),
    tintStrength: 0.55,
    contrast: 1.28,
    brightness: 0.01,
    grain: 0.7,
    grainSize: 1.7,
    flicker: 0.35,
    vignette: 0.7,
    gateWeave: 1.4,
    dust: 0.7,
    scratches: 0.8,
    halation: 0.25,
  ),
  Era.vhs => const FilmGrade(
    process: FilmProcess.vhs,
    projectionFps: 30,
    saturation: 1.2,
    tint: Color(0xFFF0E0FF),
    tintStrength: 0.2,
    contrast: 1.1,
    grain: 0.1,
    vignette: 0.35,
    gateWeave: 0,
    dust: 0,
    scratches: 0,
    scanlines: 0.55,
    chromaShift: 1.8,
    chromaBleed: 3,
    tracking: 0.35,
    tapeWobble: 1.2,
  ),
};

HalftoneStyle eraHalftone(Era era) => switch (era) {
  Era.silent => const HalftoneStyle(cellSize: 4, strength: 0.6),
  Era.rubberHose => const HalftoneStyle(cellSize: 4.5, strength: 0.75),
  Era.noir => const HalftoneStyle(cellSize: 3.5, strength: 0.85),
  Era.technicolor => const HalftoneStyle(cellSize: 3.5, strength: 0.35, angle: 0.2618),
  Era.grindhouse => const HalftoneStyle(cellSize: 6, strength: 0.7),
  Era.vhs => const HalftoneStyle(cellSize: 3, strength: 0.5, shape: HalftoneShape.line, angle: 0),
};

CrosshatchStyle eraHatch(Era era) => switch (era) {
  Era.silent => const CrosshatchStyle(spacing: 4.5, lineWidth: 1, wobble: 1),
  Era.rubberHose => const CrosshatchStyle(spacing: 5, lineWidth: 1.2),
  Era.noir => const CrosshatchStyle(spacing: 4, lineWidth: 1.1, wobble: 0.5, strength: 0.95),
  Era.technicolor => const CrosshatchStyle(spacing: 6, lineWidth: 1, wobble: 0.4, strength: 0.4),
  Era.grindhouse => const CrosshatchStyle(spacing: 5.5, lineWidth: 1.4, wobble: 1.2),
  Era.vhs => const CrosshatchStyle(spacing: 6, lineWidth: 1, wobble: 0, strength: 0.5),
};
