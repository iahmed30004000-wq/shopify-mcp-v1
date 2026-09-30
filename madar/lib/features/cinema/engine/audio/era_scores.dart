import '../core/era.dart';
import '../core/era_skin.dart';

// Per-era score table. Owner: audio agent (tune freely – pure const data,
// import only core types).

ScoreStyle eraScore(Era era) => switch (era) {
  Era.silent => const ScoreStyle(style: MusicStyle.ragtime, tempo: 100, swing: 0.1, rootMidi: 60, lofi: 0.8, crackle: 0.7),
  Era.rubberHose => const ScoreStyle(style: MusicStyle.swing, tempo: 168, swing: 0.6, rootMidi: 58, lofi: 0.6, crackle: 0.5),
  Era.noir => const ScoreStyle(
    style: MusicStyle.noirJazz,
    tempo: 76,
    swing: 0.55,
    rootMidi: 55,
    minor: true,
    lofi: 0.35,
    crackle: 0.2,
  ),
  Era.technicolor => const ScoreStyle(style: MusicStyle.bigBand, tempo: 132, swing: 0.4, rootMidi: 60, lofi: 0.15),
  Era.grindhouse => const ScoreStyle(
    style: MusicStyle.funk,
    tempo: 104,
    swing: 0.15,
    rootMidi: 52,
    minor: true,
    lofi: 0.3,
    crackle: 0.25,
  ),
  Era.vhs => const ScoreStyle(style: MusicStyle.synthwave, tempo: 112, rootMidi: 57, minor: true, lofi: 0.2),
};
