/// The stage agent's public toolkit (engine/stage/): the real theatre
/// behind the StageFrame / HudKit / CinemaTransitions / overlay contracts,
/// and the house-style drawing pieces the hall and games may reuse.
///
/// * [ReelStage] – the StageFrame the standard kit creates (`createStage`):
///   curtains with physics ([CurtainMotion]), the era's proscenium
///   ([ProsceniumPainter]), marquee bulbs ([BulbAtlas]), footlights,
///   follow-spot; [StageBeat] lets Flutter overlays repaint on game time.
/// * [StageLayout] – the theatre's measurements for a screen.
/// * [StageMaterials] – an era's gilt, wall, bulb and neon colours.
/// * [Ornaments] – orbit emblem, sunburst, stars, laurels, neon tubes.
library;

export 'bulb_atlas.dart';
export 'curtain_motion.dart';
export 'hud/hud_paint.dart';
export 'hud/reel_hud_kit.dart';
export 'overlays/cinema_overlays.dart';
export 'overlays/overlay_kit.dart';
export 'overlays/projector_booth.dart';
export 'overlays/results_marquee.dart';
export 'proscenium.dart';
export 'reel_stage.dart';
export 'reel_transitions.dart';
export 'stage_layout.dart';
export 'stage_materials.dart';
export 'stage_ornaments.dart';
