import '../core/era.dart';
import '../core/era_skin.dart';

// Per-era ink line table. Owner: rig agent (tune freely – pure const data,
// import only core types).

InkStyle eraInk(Era era) => switch (era) {
  Era.silent => const InkStyle(
    lineWidth: 2.6,
    taper: 0.5,
    boilAmplitude: 1,
    shading: ShadingMode.crosshatch,
    shadeStrength: 0.55,
    dryness: 0.25,
  ),
  Era.rubberHose => const InkStyle(lineWidth: 3.4, taper: 0.6, boilAmplitude: 0.9, dryness: 0.12),
  Era.noir => const InkStyle(
    lineWidth: 2.8,
    boilAmplitude: 0.5,
    shading: ShadingMode.crosshatch,
    shadeStrength: 0.85,
    dryness: 0.1,
  ),
  Era.technicolor => const InkStyle(
    lineWidth: 2.4,
    taper: 0.4,
    boilAmplitude: 0.35,
    shading: ShadingMode.gradient,
    shadeStrength: 0.45,
    dryness: 0,
  ),
  Era.grindhouse => const InkStyle(lineWidth: 3, boilAmplitude: 1.1, shadeStrength: 0.65, dryness: 0.3),
  Era.vhs => const InkStyle(
    lineWidth: 2.2,
    taper: 0.1,
    boilAmplitude: 0.2,
    boilFps: 0,
    shading: ShadingMode.neon,
    shadeStrength: 0.5,
    dryness: 0,
    glow: 6,
  ),
};
