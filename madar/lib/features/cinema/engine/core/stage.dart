import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show EdgeInsets;

import 'era_skin.dart';
import 'film_clock.dart';

// ---------------------------------------------------------------------------
// Stage frame: curtains, proscenium, footlights, follow-spot.
// ---------------------------------------------------------------------------

/// The theatre around the play area. Owner: stage agent (engine/stage/,
/// `createStage` in stage/stage_entry.dart).
///
/// CinemaGame calls [layout] on every resize, [update] once per tick (also
/// while paused), [paintBack] BEHIND the world (stage floor, wings, back
/// wall around the opening) and [paintFront] IN FRONT of it (curtains,
/// valance, proscenium, footlights). Everything is in screen (logical px)
/// space; the world is clipped to [playRect] by the camera.
abstract interface class StageFrame {
  /// [screen] = game widget size; [safe] = system insets (status bar,
  /// notch, gesture bar) the HUD must avoid – curtains may extend under them.
  void layout(Size screen, EdgeInsets safe);

  /// The proscenium opening where the world is visible (the camera's
  /// viewport). Stable while the curtains move.
  Rect get playRect;

  /// Where HUD slots may be placed (inside the safe area, clear of curtains
  /// and footlights).
  Rect get hudRect;

  /// 0 = closed, 1 = open.
  double get curtainOpen;

  Future<void> openCurtains({Duration? duration});
  Future<void> closeCurtains({Duration? duration});

  /// Follow-spot target in screen px (`null` = off). Ignored by eras without
  /// a spotlight.
  void spotlight(Offset? target);

  /// Footlight pulse (e.g. on a hit or a big score), 0..1.
  void pulse(double amount);

  void update(double dt, FilmClock clock);
  void paintBack(Canvas canvas);
  void paintFront(Canvas canvas);
  void dispose();
}

// ---------------------------------------------------------------------------
// HUD
// ---------------------------------------------------------------------------

/// HUD anchor slots inside [StageFrame.hudRect]. "start"/"end" follow the
/// reading direction (start = right in Arabic). Items in the same slot are
/// laid out side by side from the slot's edge inward.
enum HudSlot { topStart, topCenter, topEnd, bottomStart, bottomCenter, bottomEnd }

/// What the HUD shows. Gameplay writes it (plain fields, no notifications);
/// HUD items read it every frame and animate changes themselves (e.g. a
/// score counter rolling up).
class HudModel {
  int score = 0;
  int? best;
  int lives = 3;
  int maxLives = 3;

  /// Boss health 0..1; `null` hides the boss bar.
  double? bossHealth;

  /// Localised boss name for the bar.
  String? bossName;

  /// Level progress 0..1; `null` hides it.
  double? progress;

  /// Countdown; `null` hides the timer.
  Duration? timeLeft;
  int combo = 0;
}

/// Everything a HUD item may read while painting.
class HudContext {
  HudContext({required this.skin, required this.clock, required this.model, required this.direction});

  final EraSkin skin;
  final FilmClock clock;
  final HudModel model;
  TextDirection direction;

  /// UI scale for small/large screens (1 at 412 logical px width).
  double scale = 1;
}

/// One HUD element (score, hearts, boss bar, pause button…). Owner of the
/// real items: stage agent (via [HudKit]). Painted in screen space inside
/// the film frame, so it gets grain and flicker like everything else.
abstract class HudItem {
  /// Desired size in logical px.
  Size layoutSize(HudContext ctx);

  void update(double dt, HudContext ctx) {}

  void paint(Canvas canvas, Rect rect, HudContext ctx);

  /// Whether [onTap] should receive taps inside the item's rect.
  bool get interactive => false;

  /// Returns true when the tap was handled.
  bool onTap(Offset local, HudContext ctx) => false;

  void dispose() {}
}

/// Factory of the standard HUD items of an era. Owner: stage agent
/// (`createHudKit` in stage/stage_entry.dart).
abstract interface class HudKit {
  /// Score counter (reads [HudModel.score] / [HudModel.best]).
  HudItem score();

  /// Lives (reads [HudModel.lives] / [HudModel.maxLives]).
  HudItem lives();

  /// Boss health bar with name plate (hidden while bossHealth is null).
  HudItem bossBar();

  /// Countdown (hidden while timeLeft is null).
  HudItem timer();

  /// Level progress (hidden while progress is null).
  HudItem progress();

  /// The pause button (interactive).
  HudItem pauseButton(VoidCallback onPressed);

  /// Free text (localised by the caller; read every frame, re-laid out only
  /// when it changes).
  HudItem label(String Function() text);
}

// ---------------------------------------------------------------------------
// Transitions & intertitles
// ---------------------------------------------------------------------------

enum IntertitleKind { title, chapter, dialogue, theEnd, gameOver, intermission }

/// A title card. Text is already localised by the game (ARB strings).
@immutable
class IntertitleCard {
  const IntertitleCard({required this.text, this.subtitle, this.kind = IntertitleKind.title});

  final String text;
  final String? subtitle;
  final IntertitleKind kind;
}

/// Iris-in/out, burn, wipes and intertitle cards. Owner: stage agent
/// (`createTransitions` in stage/stage_entry.dart), using iris.frag /
/// burn.frag / paper.frag through the core uniform writers.
///
/// The transition layer is painted above the HUD but BELOW the film grade,
/// so grain and flicker dance on the black and on the cards. Futures
/// complete when the animation finishes (driven by [update], i.e. game
/// time – they freeze while the app is backgrounded).
abstract interface class CinemaTransitions {
  /// True while something is animating or a card is showing.
  bool get isActive;

  /// 0 = scene fully visible, 1 = fully covered.
  double get coverage;

  /// Opens from black onto the scene around [focus] (screen px; default
  /// play-area centre) in the era's transition style.
  Future<void> irisIn({Offset? focus, Duration? duration});

  /// Closes to black around [focus].
  Future<void> irisOut({Offset? focus, Duration? duration});

  /// Shows [card] over black for [hold] (default: reading time for the
  /// text), then returns to the previous coverage.
  Future<void> intertitle(IntertitleCard card, {Duration? hold});

  /// Instantly fully covered (scene start before the first iris-in).
  void cover();

  /// Instantly clear; completes pending futures.
  void clear();

  void layout(Size screen, Rect playRect);
  void update(double dt, FilmClock clock);
  void paint(Canvas canvas);
  void dispose();
}
