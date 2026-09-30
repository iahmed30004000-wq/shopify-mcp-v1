import '../core/era.dart';
import 'film_look.dart';

// Per-era print looks and reel events (the FX agent's extras on top of the
// core FilmGrade in era_grades.dart). Pure const data – tune freely.

FilmLook eraLook(Era era) => switch (era) {
  // 1920s: a well-travelled nitrate print on an 18 fps projector – soft old
  // lens, uneven lamp, rounded aperture, blotchy density, hairs, splices.
  Era.silent => const FilmLook(
    softFocus: 0.35,
    lineBoil: 0.35,
    gateCorner: 26,
    hotspot: 0.9,
    age: 0.55,
    frameLine: 0.8,
    splicesPerMinute: 3,
    frameSlipsPerMinute: 0.8,
    blotchesPerMinute: 2,
    hairsPerMinute: 2.5,
    cueMarks: true,
    reelSeconds: 48,
  ),
  // 1930s: crisp black ink on cream stock, a halftone screen in the greys
  // (the lobby-card print), everything boiling on twos.
  Era.rubberHose => const FilmLook(
    halftone: 0.85,
    halftoneCell: 4,
    lineBoil: 0.4,
    gateCorner: 12,
    hotspot: 0.35,
    age: 0.2,
    frameLine: 0.4,
    splicesPerMinute: 1.2,
    frameSlipsPerMinute: 0.25,
    hairsPerMinute: 1,
    cueMarks: true,
    reelSeconds: 60,
  ),
  // 1940s: silver-rich stock, inky blacks, pen-hatched shadows and light
  // through venetian blinds.
  Era.noir => const FilmLook(
    toe: 0.5,
    hatch: 0.7,
    hatchSpacing: 4.2,
    screenAngle: 0.6,
    blinds: 0.85,
    blindsAngle: -0.42,
    blindsPeriod: 42,
    lineBoil: 0.15,
    hotspot: 0.45,
    age: 0.12,
    splicesPerMinute: 0.6,
    hairsPerMinute: 0.5,
    cueMarks: true,
    reelSeconds: 72,
  ),
  // 1950s: three-strip dye transfer – pure saturated colour, deep key
  // blacks, soft bloom; an almost pristine print.
  Era.technicolor => const FilmLook(
    threeStrip: 0.8,
    bloom: 0.45,
    hotspot: 0.2,
    colourGrain: 0.4,
    splicesPerMinute: 0.2,
    cueMarks: true,
    reelSeconds: 90,
  ),
  // 1970s: a warm, faded, abused exploitation print – magenta shift, milky
  // blacks, colour grain, heavy scratches, splices, slips, stains and cue
  // marks.
  Era.grindhouse => const FilmLook(
    dyeFade: 0.5,
    blackLift: 0.1,
    colourGrain: 0.85,
    hotspot: 0.4,
    age: 0.3,
    frameLine: 0.6,
    lineBoil: 0.2,
    splicesPerMinute: 5,
    frameSlipsPerMinute: 1.5,
    blotchesPerMinute: 4,
    hairsPerMinute: 2,
    cueMarks: true,
    reelSeconds: 30,
  ),
  // 1980s: videotape (vhs.frag) – no print, no reel events.
  Era.vhs => FilmLook.clean,
};
