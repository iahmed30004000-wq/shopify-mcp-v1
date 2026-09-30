import 'dart:math' as math;
import 'dart:ui' as ui;

import 'era_skin.dart';
import 'film_clock.dart';

/// Per-frame film parameters written by gameplay and read by [FilmFx].
///
/// One mutable instance per game (`CinemaGame.film`) – no per-frame
/// allocation. Gameplay "kicks" transient effects; they decay by themselves.
class FilmFrame {
  /// White-out to paper, 0..1 (hits, lightning, camera flash).
  double flash = 0;

  /// Projector shake, 0..1 (explosions, boss stomps).
  double shake = 0;

  /// Extra dust & scratches (or VHS glitch), 0..1 (player hurt, "reel damage").
  double damage = 0;

  /// Fade to ink/black, 0..1 – set explicitly (not decayed).
  double fade = 0;

  /// Global strength of the film look, 0 = clean frame, 1 = full era look.
  /// Scaled down by the reduce-flicker accessibility setting and LOD.
  double intensity = 1;

  /// Accessibility: no flicker / flashing (MediaQuery.disableAnimations or
  /// the user's reduced-motion setting). FilmFx must honour it: no
  /// exposure flicker, flashes capped at 0.35, damage effects halved.
  bool reduceFlicker = false;

  /// Adds transient effects (max-combined with what is already running).
  void kick({double flash = 0, double shake = 0, double damage = 0}) {
    this.flash = math.max(this.flash, flash.clamp(0.0, 1.0));
    this.shake = math.max(this.shake, shake.clamp(0.0, 1.0));
    this.damage = math.max(this.damage, damage.clamp(0.0, 1.0));
  }

  /// Exponential decay of the transient effects (called by CinemaGame).
  void decay(double dt) {
    flash *= math.exp(-dt * 9);
    shake *= math.exp(-dt * 6);
    damage *= math.exp(-dt * 2.5);
    if (flash < 0.002) flash = 0;
    if (shake < 0.002) shake = 0;
    if (damage < 0.002) damage = 0;
  }

  /// Effective flash after accessibility limits.
  double get safeFlash => reduceFlicker ? math.min(flash, 0.35) : flash;
}

/// Applies an era's post-processing to a rendered frame.
///
/// `CinemaGame.render` records the whole scene (world, stage, HUD,
/// transitions) into a picture, rasterises it once with
/// `Picture.toImageSync` at `devicePixelRatio × resolutionScale`, and hands
/// the image to [apply], which must draw it into [dst] through the era's
/// full-frame shader (film_grade.frag or vhs.frag via a FragmentShader that
/// samples the image – works on Skia and Impeller; do NOT use
/// ImageFilter.shader, which is Impeller-only).
///
/// Owner: FX agent (implementation in engine/fx/, created by
/// `createFilmFx` in fx/fx_entry.dart).
abstract interface class FilmFx {
  EraSkin get skin;

  /// True once the shader programs are loaded; until then CinemaGame renders
  /// the scene ungraded (never blank).
  bool get isReady;

  Future<void> load();

  /// Offscreen resolution multiplier on top of the device pixel ratio
  /// (1 = native; 0.75 is the mid-range-phone LOD). Read every frame.
  double get resolutionScale;
  set resolutionScale(double value);

  /// Advances per-frame state (dust positions, flicker targets). Called once
  /// per tick, also while gameplay is paused.
  void update(double dt, FilmClock clock);

  /// Draws [frame] (the rasterised scene, physical pixels) into [dst]
  /// (logical px of [canvas]) with the era look. Must not allocate per call
  /// (reuse FragmentShader / Paint instances).
  void apply(ui.Canvas canvas, ui.Image frame, ui.Rect dst, FilmClock clock, FilmFrame params);

  void dispose();
}
