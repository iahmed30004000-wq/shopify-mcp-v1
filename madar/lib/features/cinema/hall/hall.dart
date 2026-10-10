/// The Madar Cinema hall – the hub, the game screen and the Saved Games
/// entry point.
///
/// * [CinemaHallScreen] – the movie-palace lobby (marquee, Now Showing,
///   programme with filters, ticket book, Saved Games shelf).
/// * [CinemaGameScreen] – plays one programme entry by id, full screen, with
///   persistent records (`CinemaGameScreen.route(id)` opens it through an
///   iris).
/// * [SavedGamesScreen] – the user's web games (built by the Saved Games
///   feature, lib/features/saved_games; re-exported here).
/// * Records: [CinemaRecords], [CinemaRecordsStore] ([KvCinemaRecordsStore]
///   under `cinema.records`), [cinemaRecordsProvider].
library;

export '../../saved_games/saved_games.dart' show SavedGamesScreen, SavedGamesShelf;
export 'cinema_game_screen.dart' show CinemaGameScreen, IrisRouteTransition, NotOpenYetStage;
export 'cinema_hall_screen.dart' show CinemaHallScreen;
export 'cinema_records.dart';
export 'cinema_store.dart';
