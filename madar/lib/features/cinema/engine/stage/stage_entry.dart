import '../core/cinema_env.dart';
import '../core/cinema_kit.dart';
import '../core/stage.dart';
import 'placeholder_hud.dart';
import 'placeholder_overlays.dart';
import 'placeholder_stage.dart';
import 'placeholder_transitions.dart';

// Stage agent entry points – the ONLY symbols the standard kit imports from
// engine/stage/. Swap the placeholders for the real implementations here.

/// Curtains, proscenium, footlights, follow-spot.
StageFrame createStage(CinemaEnv env) => PlaceholderStage(env);

/// The era's HUD items.
HudKit createHudKit(CinemaEnv env) => PlaceholderHudKit(env);

/// Iris / burn / wipe transitions and intertitle cards.
CinemaTransitions createTransitions(CinemaEnv env) => PlaceholderTransitions(env);

/// Flutter overlays for every id in [CinemaOverlays.all].
Map<String, CinemaOverlayBuilder> createOverlays() => placeholderOverlays();
