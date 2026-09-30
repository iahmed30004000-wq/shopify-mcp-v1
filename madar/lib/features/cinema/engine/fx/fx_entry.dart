import '../core/cinema_env.dart';
import '../core/film_fx.dart';
import 'placeholder_film_fx.dart';

// FX agent entry point – the ONLY symbol the standard kit imports from
// engine/fx/. Swap the placeholder for the real implementation here.

/// The [FilmFx] every CinemaGame uses (via CinemaEngine.standardKit).
FilmFx createFilmFx(CinemaEnv env) => PlaceholderFilmFx(env);
