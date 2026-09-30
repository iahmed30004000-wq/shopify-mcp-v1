import '../core/audio.dart';

/// Silent [MusicDirector] that records what it was asked to do (tests and
/// the demo can assert on [log]). Placeholder – the audio agent replaces it.
class SilentMusicDirector implements MusicDirector {
  SilentMusicDirector(this.context);

  final CinemaAudioContext context;

  /// Human-readable call log ("cue adventure 0.50", "stinger hit" …).
  final List<String> log = [];

  bool _ready = false;
  MusicMood? _mood;
  double _intensity = 0.5;
  bool ducked = false;
  bool prayerMuted = false;
  bool paused = false;

  @override
  Future<void> prepare() async => _ready = true;

  @override
  bool get isReady => _ready;

  @override
  MusicMood? get mood => _mood;

  @override
  double get intensity => _intensity;

  @override
  void cue(MusicMood mood, {double intensity = 0.5, Duration fade = const Duration(milliseconds: 600)}) {
    _mood = mood;
    _intensity = intensity;
    log.add('cue ${mood.name} ${intensity.toStringAsFixed(2)}');
  }

  @override
  void setIntensity(double intensity) => _intensity = intensity.clamp(0.0, 1.0);

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
  void stop({Duration fade = const Duration(milliseconds: 400)}) {
    _mood = null;
    log.add('stop');
  }

  @override
  Future<void> dispose() async {}
}

/// Silent [SfxBank] that records played sounds. Placeholder.
class SilentSfxBank implements SfxBank {
  SilentSfxBank(this.context);

  final CinemaAudioContext context;
  final List<CinemaSound> played = [];
  bool prayerMuted = false;
  bool _ready = false;

  @override
  Future<void> prepare() async => _ready = true;

  @override
  bool get isReady => _ready;

  @override
  void play(CinemaSound sound, {double volume = 1, double pitch = 1, double pan = 0}) {
    if (!prayerMuted) played.add(sound);
  }

  @override
  void setPrayerMuted(bool muted) => prayerMuted = muted;

  @override
  Future<void> dispose() async {}
}
