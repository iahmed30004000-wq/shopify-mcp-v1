/// Madar Cinema's procedural audio (the audio agent's public surface).
///
/// Games normally need nothing from here: `CinemaGame.music` and
/// `CinemaGame.feedback(CinemaSound)` cover scoring and effects. Import this
/// library for the extras:
///
/// ```dart
/// import 'package:madar/features/cinema/engine/audio/cinema_audio.dart';
///
/// game.sfx.playExtra(CinemaSfx.crowdCheer);       // theatre / sports sounds
/// CinemaAudioWarmup.warm(Era.noir, sound);        // pre-render on poster tap
/// ```
///
/// How it works:
/// * **Music** – [ProceduralMusicDirector]: every mood of the era's
///   [MusicStyle] is composed from a style grammar (chord progressions,
///   bass, comping and drum patterns, a phrase-level melody generator with
///   an originality guard) and rendered offline by a small synthesiser into
///   2–3 stems (bed / lead / hot) with a seamless circular loop and an
///   optional intro. Stems are scheduled sample-accurately on SoLoud's
///   engine clock; intensity fades the layers; cues change on bar lines;
///   stingers land on the beat, transposed onto the sounding chord.
/// * **Effects** – [ProceduralSfxBank]: the era-voiced [CinemaSound] palette
///   plus [CinemaSfx] extras, with per-call pitch variation and polyphony
///   caps.
/// * Everything plays on the games bus: the sound switch, the games volume
///   and prayer mute apply; with any other SoundService (tests) it is silent
///   and renders nothing.
library;

export 'music/score.dart' show StemSpec;
export 'runtime/cue_source.dart' show CachingCueSource, CueSource, InlineCueSource, IsolateCueSource;
export 'runtime/mixer.dart' show CinemaMixer, SilentCinemaMixer, SoloudCinemaMixer, mixerFor;
export 'runtime/music_director.dart' show ProceduralMusicDirector;
export 'runtime/sfx_bank.dart' show CinemaSfxExtras, ProceduralSfxBank;
export 'runtime/warmup.dart' show CinemaAudioWarmup;
export 'sfx/sfx_synth.dart' show CinemaSfx;
