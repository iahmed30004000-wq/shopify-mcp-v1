/// Madar Cinema – the Film Reel Engine.
///
/// Games import this file only. It exports the core contracts and wires
/// each engine agent's entry point into the standard [CinemaKit].
/// Architecture, ownership and budgets: lib/features/cinema/ENGINE.md.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio/audio_entry.dart';
import 'core/cinema_kit.dart';
import 'core/score.dart';
import 'fx/fx_entry.dart';
import 'rig/rig_entry.dart';
import 'stage/stage_entry.dart';

export 'core/core.dart';
export 'cinema_game_view.dart';

abstract final class CinemaEngine {
  /// The kit built from every agent's entry point (fx/fx_entry.dart,
  /// rig/rig_entry.dart, audio/audio_entry.dart, stage/stage_entry.dart).
  static final CinemaKit standardKit = CinemaKit(
    filmFx: createFilmFx,
    stage: createStage,
    hud: createHudKit,
    transitions: createTransitions,
    music: createMusicDirector,
    sfx: createSfxBank,
    rig: createRig,
    overlays: createOverlays(),
  );
}

/// The kit CinemaGameView builds games with (override in tests).
final cinemaKitProvider = Provider<CinemaKit>((ref) => CinemaEngine.standardKit);

/// Where finished shows are reported. In-memory by default; the hall
/// overrides it with the persistent store (hall/cinema_store.dart).
final cinemaScoreSinkProvider = Provider<ScoreSink>((ref) => MemoryScoreSink());
