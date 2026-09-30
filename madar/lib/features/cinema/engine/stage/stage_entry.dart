import '../core/cinema_env.dart';
import '../core/cinema_kit.dart';
import '../core/stage.dart';
import 'placeholder_hud.dart';
import 'placeholder_overlays.dart';
import 'placeholder_transitions.dart';
import 'reel_stage.dart';

// Stage agent entry points – the ONLY symbols the standard kit imports from
// engine/stage/. Everything else the stage agent publishes (materials,
// ornaments, bulbs, the stage beat) is exported by engine/stage/stage_kit.dart.

/// Curtains, proscenium, footlights, follow-spot.
StageFrame createStage(CinemaEnv env) => ReelStage(env);

/// The era's HUD items.
HudKit createHudKit(CinemaEnv env) => PlaceholderHudKit(env);

/// Iris / burn / wipe transitions and intertitle cards.
CinemaTransitions createTransitions(CinemaEnv env) => PlaceholderTransitions(env);

/// Flutter overlays for every id in [CinemaOverlays.all].
Map<String, CinemaOverlayBuilder> createOverlays() => placeholderOverlays();
