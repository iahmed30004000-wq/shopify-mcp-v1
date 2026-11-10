// Test doubles for the Film Reel Engine contracts. Core tests use these
// instead of the agents' placeholders so they keep passing while the agents
// replace their implementations.
import 'dart:ui' as ui;

import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';

class RecordingMusic implements MusicDirector {
  RecordingMusic(this.context);

  final CinemaAudioContext context;
  final List<String> log = [];
  bool ducked = false, prayerMuted = false, paused = false, disposed = false;
  MusicMood? _mood;
  double _intensity = 0.5;

  @override
  Future<void> prepare() async {}
  @override
  bool get isReady => true;
  @override
  MusicMood? get mood => _mood;
  @override
  double get intensity => _intensity;
  @override
  void cue(MusicMood mood, {double intensity = 0.5, Duration fade = const Duration(milliseconds: 600)}) {
    _mood = mood;
    log.add('cue ${mood.name}');
  }

  @override
  void setIntensity(double intensity) => _intensity = intensity;
  @override
  void stinger(Stinger stinger) => log.add('stinger ${stinger.name}');
  @override
  void setDucked(bool ducked) => this.ducked = ducked;
  @override
  void setPrayerMuted(bool muted) => prayerMuted = muted;
  @override
  void pause() => paused = true;
  @override
  void resume() => paused = false;
  @override
  void update(double dt) {}
  @override
  void stop({Duration fade = const Duration(milliseconds: 400)}) => log.add('stop');
  @override
  Future<void> dispose() async => disposed = true;
}

class RecordingSfx implements SfxBank {
  RecordingSfx(this.context);

  final CinemaAudioContext context;
  final List<CinemaSound> played = [];
  bool prayerMuted = false, disposed = false;

  @override
  Future<void> prepare() async {}
  @override
  bool get isReady => true;
  @override
  void play(CinemaSound sound, {double volume = 1, double pitch = 1, double pan = 0}) => played.add(sound);
  @override
  void setPrayerMuted(bool muted) => prayerMuted = muted;
  @override
  Future<void> dispose() async => disposed = true;
}

/// Blits the frame and counts calls (the render pipeline ran).
class CountingFilmFx implements FilmFx {
  CountingFilmFx(this.env);

  final CinemaEnv env;
  int applies = 0;
  int updates = 0;
  bool disposed = false;
  final ui.Paint _paint = ui.Paint();

  @override
  EraSkin get skin => env.skin;
  @override
  bool get isReady => true;
  @override
  double resolutionScale = 0.5;
  @override
  Future<void> load() async {}
  @override
  void update(double dt, FilmClock clock) => updates++;
  @override
  void apply(ui.Canvas canvas, ui.Image frame, ui.Rect dst, FilmClock clock, FilmFrame params) {
    applies++;
    canvas.drawImageRect(frame, ui.Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()), dst, _paint);
  }

  @override
  void dispose() => disposed = true;
}

class RecordingHaptics implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

/// A test kit: the standard stage/HUD/transitions/rig/overlays (integration)
/// with recording audio and a counting FilmFx.
class TestKit {
  final List<RecordingMusic> music = [];
  final List<RecordingSfx> sfx = [];
  final List<CountingFilmFx> fx = [];

  late final CinemaKit kit = CinemaEngine.standardKit.copyWith(
    filmFx: (env) {
      final f = CountingFilmFx(env);
      fx.add(f);
      return f;
    },
    music: (c) {
      final m = RecordingMusic(c);
      music.add(m);
      return m;
    },
    sfx: (c) {
      final s = RecordingSfx(c);
      sfx.add(s);
      return s;
    },
  );
}
