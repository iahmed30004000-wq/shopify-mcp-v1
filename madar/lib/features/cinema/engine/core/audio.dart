import 'package:flutter/foundation.dart';

import '../../../../core/sound/sound_api.dart';
import 'era.dart';
import 'era_skin.dart';

/// The dramatic situation the score should underline.
enum MusicMood {
  /// Title card / menus.
  title,

  /// Gentle exploration.
  calm,

  /// Upbeat main gameplay.
  adventure,

  /// Suspense, danger approaching.
  tension,

  /// Full-on action.
  action,

  /// Boss fight.
  boss,

  /// Win jingle bed.
  victory,

  /// Loss bed.
  defeat,
}

/// Short musical punctuations played on top of (and in time with) the score.
enum Stinger { sceneStart, hit, pickup, bossIntro, bossDefeat, victory, defeat, drumroll, rimshot }

/// The engine's standard sound-effect palette (procedurally synthesised per
/// era – a 1930s "boing" is a slide whistle and a jaw harp, a 1980s one is a
/// synth sweep). Games needing more ask the architect for an additive enum
/// value.
enum CinemaSound {
  tap,
  jump,
  land,
  hit,
  hurt,
  coin,
  powerUp,
  whoosh,
  boing,
  pop,
  explosion,
  bell,
  honk,
  slideUp,
  slideDown,
  splat,
  zap,
  tick,
  cardFlip,
  cardDeal,
  diceRoll,
  piecePlace,
  typewriter,
  projector,
}

/// Haptic paired with each sound (CinemaGame.feedback fires both).
const Map<CinemaSound, Haptic> cinemaSoundHaptics = {
  CinemaSound.tap: Haptic.selection,
  CinemaSound.jump: Haptic.light,
  CinemaSound.land: Haptic.light,
  CinemaSound.hit: Haptic.medium,
  CinemaSound.hurt: Haptic.heavy,
  CinemaSound.coin: Haptic.selection,
  CinemaSound.powerUp: Haptic.success,
  CinemaSound.whoosh: Haptic.none,
  CinemaSound.boing: Haptic.light,
  CinemaSound.pop: Haptic.selection,
  CinemaSound.explosion: Haptic.heavy,
  CinemaSound.bell: Haptic.light,
  CinemaSound.honk: Haptic.light,
  CinemaSound.slideUp: Haptic.none,
  CinemaSound.slideDown: Haptic.none,
  CinemaSound.splat: Haptic.medium,
  CinemaSound.zap: Haptic.medium,
  CinemaSound.tick: Haptic.tick,
  CinemaSound.cardFlip: Haptic.selection,
  CinemaSound.cardDeal: Haptic.selection,
  CinemaSound.diceRoll: Haptic.light,
  CinemaSound.piecePlace: Haptic.light,
  CinemaSound.typewriter: Haptic.tick,
  CinemaSound.projector: Haptic.none,
};

/// What the audio implementations get from the engine.
///
/// Output goes through [sound] on the **games** bus: when it is a
/// `SoloudSoundService`, use `loadClip` / `playClip(category:
/// SoundCategory.games)` / `stopClip` (or SoLoud buffer streams gated by
/// `busGain(SoundCategory.games)`), so the global sound switch, the games
/// volume slider and the prayer mute apply automatically. Any other
/// SoundService (tests: `SilentSoundService`) means "stay silent".
/// Synthesis runs off the UI isolate (Isolate.run / compute), never in
/// update().
@immutable
class CinemaAudioContext {
  const CinemaAudioContext({required this.sound, required this.era, required this.score, this.seed = 0});

  final SoundService sound;
  final Era era;
  final ScoreStyle score;
  final int seed;
}

/// Procedural score conductor. Owner: audio agent (engine/audio/,
/// `createMusicDirector` in audio/audio_entry.dart).
///
/// All original compositions in the era's style (see [MusicStyle]); layers
/// fade in and out with [intensity]; stingers land on the next beat.
abstract interface class MusicDirector {
  /// Renders / loads the era's material (background isolate). Cues issued
  /// before it completes are remembered and start when ready.
  Future<void> prepare();

  bool get isReady;

  MusicMood? get mood;

  double get intensity;

  /// Moves the score to [mood] (cross-fading over [fade], on a bar line).
  void cue(MusicMood mood, {double intensity = 0.5, Duration fade = const Duration(milliseconds: 600)});

  /// 0..1: adds/removes layers and nudges the tempo within the mood.
  void setIntensity(double intensity);

  void stinger(Stinger stinger);

  /// Pause menu / dialogue: the score drops ~12 dB but keeps playing.
  void setDucked(bool ducked);

  /// Prayer mute (adhan / prayer): silent while true. The games bus is
  /// already muted by the SoundService; the director additionally stops
  /// scheduling stingers and resumes the bed seamlessly afterwards.
  void setPrayerMuted(bool muted);

  /// App backgrounded / scene frozen.
  void pause();
  void resume();

  /// Called once per game-loop tick (beat scheduling; no own Ticker/Timer
  /// churn). May be a no-op.
  void update(double dt);

  void stop({Duration fade = const Duration(milliseconds: 400)});

  Future<void> dispose();
}

/// Sound effects bank. Owner: audio agent (`createSfxBank` in
/// audio/audio_entry.dart).
abstract interface class SfxBank {
  /// Synthesises the era's kit (background isolate) and loads it.
  Future<void> prepare();

  bool get isReady;

  /// Fire-and-forget; implementations vary pitch slightly per call and cap
  /// polyphony per sound. [pan] −1..1.
  void play(CinemaSound sound, {double volume = 1, double pitch = 1, double pan = 0});

  void setPrayerMuted(bool muted);

  Future<void> dispose();
}
