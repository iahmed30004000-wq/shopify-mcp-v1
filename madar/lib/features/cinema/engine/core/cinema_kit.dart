import 'package:flutter/widgets.dart';

import 'audio.dart';
import 'cinema_env.dart';
import 'cinema_game.dart';
import 'film_fx.dart';
import 'rig.dart';
import 'stage.dart';

/// Flutter overlay (menus with real buttons and semantics) shown above a
/// running game via Flame's overlay manager.
typedef CinemaOverlayBuilder = Widget Function(BuildContext context, CinemaGame game);

/// Overlay ids every kit must provide.
abstract final class CinemaOverlays {
  /// Intermission card: resume / restart / leave.
  static const pause = 'cinema.pause';

  /// End-of-show card: score, best, play again / leave.
  static const results = 'cinema.results';

  static const all = [pause, results];
}

/// The engine's implementation registry: one factory per contract.
///
/// `CinemaEngine.standardKit` (engine/cinema_engine.dart) wires each agent's
/// entry point; tests build kits with fakes or swap single pieces with
/// [copyWith].
@immutable
class CinemaKit {
  const CinemaKit({
    required this.filmFx,
    required this.stage,
    required this.hud,
    required this.transitions,
    required this.music,
    required this.sfx,
    required this.rig,
    required this.overlays,
  });

  final FilmFx Function(CinemaEnv env) filmFx;
  final StageFrame Function(CinemaEnv env) stage;
  final HudKit Function(CinemaEnv env) hud;
  final CinemaTransitions Function(CinemaEnv env) transitions;
  final MusicDirector Function(CinemaAudioContext context) music;
  final SfxBank Function(CinemaAudioContext context) sfx;
  final RigCharacter Function(RigSpec spec) rig;
  final Map<String, CinemaOverlayBuilder> overlays;

  CinemaKit copyWith({
    FilmFx Function(CinemaEnv env)? filmFx,
    StageFrame Function(CinemaEnv env)? stage,
    HudKit Function(CinemaEnv env)? hud,
    CinemaTransitions Function(CinemaEnv env)? transitions,
    MusicDirector Function(CinemaAudioContext context)? music,
    SfxBank Function(CinemaAudioContext context)? sfx,
    RigCharacter Function(RigSpec spec)? rig,
    Map<String, CinemaOverlayBuilder>? overlays,
  }) => CinemaKit(
    filmFx: filmFx ?? this.filmFx,
    stage: stage ?? this.stage,
    hud: hud ?? this.hud,
    transitions: transitions ?? this.transitions,
    music: music ?? this.music,
    sfx: sfx ?? this.sfx,
    rig: rig ?? this.rig,
    overlays: overlays ?? this.overlays,
  );
}
