/// The FX agent's public toolkit (engine/fx/): the real FilmFx, the era
/// print looks, reel events, the film_stock shader, and the drawing helpers
/// other engine pieces and games may use.
///
/// * [ReelFilmFx] – the FilmFx the standard kit creates (`createFilmFx`).
///   Tune live: `strength` (0..1), `quality` ([FilmQuality]), `look`
///   ([FilmLook]), `adaptive`; force reel events via `events`
///   (`cueNow()`, `spliceNow()`).
/// * [FilmSettings] – the player's quality / strength / battery-saver
///   choice that `createFilmFx` starts every game with.
/// * [FilmLook] / `eraLook(era)` – per-era print stylisation and events.
/// * [IntertitlePainter] – era title cards (ornate, art deco, noir, marquee,
///   VHS OSD), Arabic + English, drawn in code.
/// * [IrisPainter], [BurnPainter], [LeaderPainter] – iris wipes (circle,
///   heart, star, keyhole), the film burning in the gate, the countdown
///   leader.
/// * [LineBoil], [BoilPen], [BoiledPath] – the 12 fps line boil for inked
///   shapes.
/// * [FilmTestCardPainter] – a calibration card for judging a look.
library;

export 'era_looks.dart';
export 'film_events.dart';
export 'film_look.dart';
export 'film_settings.dart';
export 'film_stock_shader.dart';
export 'fx_labels.dart';
export 'reel_film_fx.dart';
export 'test_card_painter.dart';
export 'transition_painters.dart';
export 'intertitle_painter.dart';
export 'line_boil.dart';
