/// The FX agent's public toolkit (engine/fx/): the real FilmFx, the era
/// print looks, reel events, the film_stock shader, and the drawing helpers
/// other engine pieces and games may use.
///
/// * [ReelFilmFx] – the FilmFx the standard kit creates (`createFilmFx`).
///   Tune live: `strength` (0..1), `quality` ([FilmQuality]), `look`
///   ([FilmLook]), `adaptive`; force reel events via `events`
///   (`cueNow()`, `spliceNow()`).
/// * [FilmLook] / `eraLook(era)` – per-era print stylisation and events.
/// * [FilmTestCardPainter] – a calibration card for judging a look.
library;

export 'era_looks.dart';
export 'film_events.dart';
export 'film_look.dart';
export 'film_stock_shader.dart';
export 'reel_film_fx.dart';
export 'test_card_painter.dart';
export 'intertitle_painter.dart';
export 'line_boil.dart';
