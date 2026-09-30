/// The one clock every engine piece reads, advanced once per game-loop tick
/// by `CinemaGame.update` (never by anyone else, never with a second Ticker).
///
/// It keeps running while gameplay is paused – the projector keeps rolling
/// (grain dances, lines boil, curtains sway) under the intermission card.
///
/// * [time] – seconds since the scene started (display-rate independent:
///   the same at 60 and 120 Hz).
/// * [filmFrame] – frame index of the projected film (grain, flicker, weave,
///   dust change once per film frame at [projectionFps]).
/// * [boilFrame] – line-boil drawing index at [boilFps]: everything that
///   boils seeds its jitter with it, so all drawings re-ink together, like a
///   real cartoon shot "on twos". [boilChanged] is true on the ticks where it
///   advanced – rebuild cached paths only then.
/// * [tick] – game-loop tick counter (shader pools reset per tick).
class FilmClock {
  FilmClock({this.boilFps = 12, this.projectionFps = 24, this.seed = 0});

  /// Line-boil rate (0 = never boils).
  double boilFps;

  /// Projected film frames per second.
  double projectionFps;

  /// Per-scene random seed (shaders and procedural art mix it in).
  final double seed;

  double _time = 0;
  int _tick = 0;
  int _boilFrame = 0;
  int _filmFrame = 0;
  bool _boilChanged = true;

  double get time => _time;
  int get tick => _tick;
  int get boilFrame => _boilFrame;
  int get filmFrame => _filmFrame;
  bool get boilChanged => _boilChanged;

  void advance(double dt) {
    _time += dt;
    _tick++;
    final boil = boilFps > 0 ? (_time * boilFps).floor() : 0;
    _boilChanged = boil != _boilFrame;
    _boilFrame = boil;
    _filmFrame = (_time * projectionFps).floor();
  }

  void reset() {
    _time = 0;
    _tick = 0;
    _boilFrame = 0;
    _filmFrame = 0;
    _boilChanged = true;
  }
}
