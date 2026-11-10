import '../core/cinema_env.dart';
import '../core/cinema_kit.dart';
import '../core/stage.dart';
import 'hud/reel_hud_kit.dart';
import 'overlays/cinema_overlays.dart';
import 'reel_stage.dart';
import 'reel_transitions.dart';

// Stage agent entry points – the ONLY symbols the standard kit imports from
// engine/stage/. Everything else the stage agent publishes (materials,
// ornaments, bulbs, the stage beat, HUD pieces) is exported by
// engine/stage/stage_kit.dart.

/// Curtains with physics, the era's proscenium, marquee bulbs, footlights,
/// follow-spot.
StageFrame createStage(CinemaEnv env) => ReelStage(env);

/// The era's HUD items (rolling score, film-reel lives, burning film boss
/// bar, stopwatch, film-strip progress, pause button, labels).
HudKit createHudKit(CinemaEnv env) => ReelHudKit(env);

/// Iris / burn / tape-glitch transitions and the FX agent's intertitle cards.
CinemaTransitions createTransitions(CinemaEnv env) => ReelTransitions(env);

/// Flutter overlays for every id in [CinemaOverlays.all]: the projector
/// booth (pause) and the results marquee.
Map<String, CinemaOverlayBuilder> createOverlays() => reelOverlays();
