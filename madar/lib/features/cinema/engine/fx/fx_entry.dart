import '../core/cinema_env.dart';
import '../core/film_fx.dart';
import 'reel_film_fx.dart';

// FX agent entry point – the ONLY symbol the standard kit imports from
// engine/fx/. Everything else the FX agent publishes (painters, line boil,
// looks) is exported by engine/fx/fx.dart.

/// The [FilmFx] every CinemaGame uses (via CinemaEngine.standardKit): the
/// era's film stock (or videotape) with its reel events.
FilmFx createFilmFx(CinemaEnv env) => ReelFilmFx(env);
