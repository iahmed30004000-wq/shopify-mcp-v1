import '../../core/cinema_kit.dart';
import 'projector_booth.dart';
import 'results_marquee.dart';

/// The stage agent's Flutter overlays: the intermission as a projection
/// booth and the results as a marquee with a ticket stub.
Map<String, CinemaOverlayBuilder> reelOverlays() => {
  CinemaOverlays.pause: (context, game) => ProjectorBoothOverlay(game: game),
  CinemaOverlays.results: (context, game) => ResultsMarqueeOverlay(game: game),
};
