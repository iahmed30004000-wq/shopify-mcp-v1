import '../core/cinema_env.dart';
import '../core/film_fx.dart';
import 'film_settings.dart';
import 'reel_film_fx.dart';

// FX agent entry point – the ONLY symbol the standard kit imports from
// engine/fx/. Everything else the FX agent publishes (painters, line boil,
// looks, settings) is exported by engine/fx/fx.dart.

/// The [FilmFx] every CinemaGame uses (via CinemaEngine.standardKit): the
/// era's film stock (or videotape) with its reel events, at the player's
/// [FilmSettings.current] (quality, strength, battery saver).
FilmFx createFilmFx(CinemaEnv env) => ReelFilmFx.fromSettings(env, FilmSettings.current);
