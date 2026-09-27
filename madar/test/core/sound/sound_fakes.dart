import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:madar/core/sound/audio_engine.dart';
import 'package:madar/core/sound/haptics.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/core/sound/sound_kit.dart';
import 'package:madar/core/sound/synth/synth.dart';

/// Records every engine call; voices/sources are sequential ints.
class FakeAudioEngine implements AudioEngine {
  FakeAudioEngine({this.initError, this.initHangs = false});

  final Object? initError;
  final bool initHangs;

  bool initialized = false;
  bool shutDown = false;
  int prewarms = 0;
  final List<String> calls = [];
  final Map<int, String> loaded = {};
  final List<int> unloaded = [];
  final Set<int> lowPassSources = {};
  final Map<int, FakeVoice> voices = {};
  int _nextSource = 0;
  int _nextVoice = 100;

  @override
  Future<void> init() async {
    calls.add('init');
    if (initHangs) await Completer<void>().future;
    if (initError != null) throw initError!;
    initialized = true;
  }

  @override
  Future<int> load(String name, Uint8List wav) async {
    final id = _nextSource++;
    loaded[id] = name;
    calls.add('load $name');
    return id;
  }

  @override
  Future<void> unload(int source) async {
    unloaded.add(source);
    loaded.remove(source);
    calls.add('unload $source');
  }

  @override
  void enableLowPass(int source) => lowPassSources.add(source);

  @override
  int play(
    int source, {
    double volume = 1.0,
    double pan = 0.0,
    double speed = 1.0,
    bool looping = false,
    bool paused = false,
    bool protect = false,
    double? lowPassHz,
  }) {
    if (!loaded.containsKey(source)) return -1;
    final id = _nextVoice++;
    voices[id] = FakeVoice(
      source: source,
      name: loaded[source]!,
      volume: volume,
      speed: speed,
      looping: looping,
      paused: paused,
      protect: protect,
      lowPassHz: lowPassHz,
    );
    calls.add('play ${loaded[source]}');
    return id;
  }

  @override
  void setVolume(int voice, double volume) => voices[voice]?.volume = volume;

  @override
  void fadeVolume(int voice, double to, Duration time) {
    final v = voices[voice];
    if (v == null) return;
    v.volume = to;
    v.fades.add((to, time));
  }

  @override
  void setPaused(int voice, bool paused) => voices[voice]?.paused = paused;

  @override
  void stop(int voice) => voices[voice]?.stopped = true;

  @override
  void stopAfter(int voice, Duration delay) => voices[voice]?.stopped = true;

  @override
  void setLowPass(int voice, double hz, {Duration fade = Duration.zero}) => voices[voice]?.lowPassHz = hz;

  @override
  Future<void> prewarm() async => prewarms++;

  @override
  Future<void> shutdown() async => shutDown = true;

  Iterable<FakeVoice> voicesOf(String nameContains) => voices.values.where((v) => v.name.contains(nameContains));
}

class FakeVoice {
  FakeVoice({
    required this.source,
    required this.name,
    required this.volume,
    required this.speed,
    required this.looping,
    required this.paused,
    required this.protect,
    required this.lowPassHz,
  });

  final int source;
  final String name;
  double volume;
  final double speed;
  final bool looping;
  bool paused;
  final bool protect;
  double? lowPassHz;
  bool stopped = false;
  final List<(double, Duration)> fades = [];
}

/// Manually driven clock + timers.
class FakeTime {
  Duration now = Duration.zero;
  final List<FakeTimer> _timers = [];

  Duration clock() => now;

  Timer timer(Duration delay, void Function() callback) {
    final t = FakeTimer(now + delay, callback);
    _timers.add(t);
    return t;
  }

  void schedule(Duration delay, void Function() action) => timer(delay, action);

  /// Advances time, firing due timers in order.
  void advance(Duration d) {
    final end = now + d;
    while (true) {
      final due = _timers.where((t) => t.isActive && t.due <= end).toList()..sort((a, b) => a.due.compareTo(b.due));
      if (due.isEmpty) break;
      final t = due.first;
      now = t.due;
      t.fire();
    }
    now = end;
    _timers.removeWhere((t) => !t.isActive);
  }

  int get pending => _timers.where((t) => t.isActive).length;
}

class FakeTimer implements Timer {
  FakeTimer(this.due, this._callback);

  final Duration due;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// A tiny kit (one 0.5 s tone per Sfx) so service tests don't synthesise.
SoundKit tinyKit(String profileId) {
  final wavs = <Sfx, Uint8List>{};
  for (final sfx in Sfx.values) {
    const n = 22050;
    final l = Float64List(n);
    for (var i = 0; i < n; i++) {
      l[i] = 0.1 * SineTable.at(i * 440 / 44100);
    }
    wavs[sfx] = Wav.encodePcm16([l, l], sampleRate: 44100);
  }
  return SoundKit(profileId: profileId, sampleRate: 44100, wavs: wavs, renderTime: Duration.zero);
}

Uint8List tinyAmbient(String profileId) => Wav.encodePcm16([Float64List(2400), Float64List(2400)], sampleRate: 24000);

/// Records haptic primitives with timestamps.
class FakeHapticDriver implements HapticDriver {
  FakeHapticDriver(this.time);

  final FakeTime time;
  final List<(String, Duration)> events = [];

  List<String> get names => [for (final e in events) e.$1];

  @override
  void selectionClick() => events.add(('selection', time.now));
  @override
  void lightImpact() => events.add(('light', time.now));
  @override
  void mediumImpact() => events.add(('medium', time.now));
  @override
  void heavyImpact() => events.add(('heavy', time.now));
}

/// SoundService spy for the settings sync.
class SpySoundService implements SoundService, SoundLifecycleAware {
  final List<String> calls = [];
  final Map<SoundCategory, double> volumes = {};
  bool _enabled = true;
  bool? foreground;

  @override
  bool get enabled => _enabled;
  @override
  set enabled(bool value) {
    _enabled = value;
    calls.add('enabled $value');
  }

  @override
  bool prayerMuted = false;

  @override
  Future<void> init() async {}
  @override
  void play(Sfx sfx, {double volume = 1.0, double pitch = 1.0}) => calls.add('play ${sfx.name}');
  @override
  Future<void> setProfile(String profileId) async => calls.add('profile $profileId');
  @override
  Future<void> startAmbient() async => calls.add('startAmbient');
  @override
  Future<void> stopAmbient() async => calls.add('stopAmbient');
  @override
  void swell(double amount) {}
  @override
  double volumeOf(SoundCategory category) => volumes[category] ?? 1;
  @override
  void setVolume(SoundCategory category, double value) {
    volumes[category] = value;
    calls.add('volume ${category.name} $value');
  }

  @override
  void setPrayerMute(bool muted) => prayerMuted = muted;
  @override
  Future<void> dispose() async {}

  @override
  void onAppLifecycleChanged({required bool foreground}) {
    this.foreground = foreground;
    calls.add('foreground $foreground');
  }
}

class SpyHaptics implements HapticsService {
  @override
  bool enabled = true;
  final List<Haptic> fired = [];

  @override
  void fire(Haptic haptic) {
    if (kDebugMode) fired.add(haptic);
  }
}
