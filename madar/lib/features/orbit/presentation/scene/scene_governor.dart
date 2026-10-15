import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// How the Astrolabe Orbit renders right now.
enum SceneMode {
  /// Full display rate: the user is touching the scene or something
  /// animates (a fly-in, a pulse, a spring, an inertial spin).
  live,

  /// Nothing but the slow cinematic drift: 30 fps (every other vsync on a
  /// 60 Hz panel, every fourth at 120 Hz).
  idle,

  /// A planet page is open over the scene (the fly-in has landed): the scene
  /// is its blurred backdrop – only the hero world turning slowly – so it
  /// steps at 10 fps (its full-screen depth-of-field blurs are redone at a
  /// third of the idle rate).
  backdrop,

  /// Not visible (covered by an opaque route, app in the background,
  /// TickerMode off): no ticker at all.
  paused,

  /// Battery saver: the scene is shown as a captured still (refreshed once
  /// a minute); no ticker.
  still,

  /// Reduced motion or decorative motion switched off: a static, fully
  /// interactive scene; the ticker only runs while something animates.
  frozen,
}

/// Everything the governor decides from.
@immutable
class SceneInputs {
  const SceneInputs({
    this.visible = true,
    this.interacting = false,
    this.animating = false,
    this.batterySaver = false,
    this.reducedMotion = false,
    this.ambient = true,
    this.pageOpen = false,
  });

  /// On screen: TickerMode on, app resumed, not covered by an opaque route.
  final bool visible;

  /// A finger is on the scene (drag, pinch) or an inertial spin runs.
  final bool interacting;

  /// A one-shot animation runs (fly-in/out, pulse, morph, spring, label fade).
  final bool animating;

  /// AppSettings.powerMode == batterySaver.
  final bool batterySaver;

  /// Reduced motion (system or in-app).
  final bool reducedMotion;

  /// Never-ending decorative motion allowed (AmbientMotion.enabled – off
  /// under `flutter test`).
  final bool ambient;

  /// A planet page is open over the scene and its fly-in has landed.
  final bool pageOpen;

  SceneInputs copyWith({
    bool? visible,
    bool? interacting,
    bool? animating,
    bool? batterySaver,
    bool? reducedMotion,
    bool? ambient,
    bool? pageOpen,
  }) => SceneInputs(
    visible: visible ?? this.visible,
    interacting: interacting ?? this.interacting,
    animating: animating ?? this.animating,
    batterySaver: batterySaver ?? this.batterySaver,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    ambient: ambient ?? this.ambient,
    pageOpen: pageOpen ?? this.pageOpen,
  );

  @override
  bool operator ==(Object other) =>
      other is SceneInputs &&
      other.visible == visible &&
      other.interacting == interacting &&
      other.animating == animating &&
      other.batterySaver == batterySaver &&
      other.reducedMotion == reducedMotion &&
      other.ambient == ambient &&
      other.pageOpen == pageOpen;

  @override
  int get hashCode => Object.hash(visible, interacting, animating, batterySaver, reducedMotion, ambient, pageOpen);

  @override
  String toString() =>
      'SceneInputs(visible: $visible, interacting: $interacting, animating: $animating, '
      'batterySaver: $batterySaver, reducedMotion: $reducedMotion, ambient: $ambient, pageOpen: $pageOpen)';
}

/// The scene's power / frame-rate state machine (pure; unit-tested).
///
/// * [mode] follows from the [SceneInputs] (see [modeFor]);
/// * [wantsTicker] says whether the scene's single ticker should run;
/// * [admit] is called on every vsync with the time since the previous one
///   and returns the seconds to advance the scene this frame – or null to
///   skip the frame (idle mode renders at [idleFps]).
class SceneGovernor {
  SceneGovernor({this.idleFps = 30, this.backdropFps = 10, SceneInputs inputs = const SceneInputs()})
    : _inputs = inputs,
      _mode = modeFor(inputs);

  /// Frame rate of the idle drift.
  final double idleFps;

  /// Frame rate behind an open planet page ([SceneMode.backdrop]).
  final double backdropFps;

  /// The rate the ticker steps at in a throttled mode (idle / backdrop).
  double get stepFps => _mode == SceneMode.backdrop ? backdropFps : idleFps;

  /// Longest step the scene advances in one frame (after a hitch or a
  /// resume the world does not jump ahead).
  static const maxStep = 0.1;

  SceneInputs _inputs;
  SceneMode _mode;
  double _pending = 0;

  /// Frames the scene advanced / skipped (diagnostics and tests).
  int rendered = 0, skipped = 0;

  SceneInputs get inputs => _inputs;
  SceneMode get mode => _mode;

  /// The ticker should run (live, idle or behind a page).
  bool get wantsTicker => _mode == SceneMode.live || _mode == SceneMode.idle || _mode == SceneMode.backdrop;

  /// Pure mapping from inputs to mode.
  static SceneMode modeFor(SceneInputs i) {
    if (!i.visible) return SceneMode.paused;
    if (i.interacting || i.animating) return SceneMode.live;
    if (i.batterySaver) return SceneMode.still;
    if (i.reducedMotion || !i.ambient) return SceneMode.frozen;
    if (i.pageOpen) return SceneMode.backdrop;
    return SceneMode.idle;
  }

  /// Applies new [inputs]; returns whether the mode changed.
  bool update(SceneInputs inputs) {
    _inputs = inputs;
    final next = modeFor(inputs);
    if (next == _mode) return false;
    final wasTicking = wantsTicker;
    _mode = next;
    if (!wasTicking) _pending = 0;
    return true;
  }

  /// One vsync [dt] seconds after the previous one: the seconds to advance
  /// the scene now, or null to skip this frame.
  double? admit(double dt) {
    if (!wantsTicker || !dt.isFinite || dt <= 0) return null;
    if (_mode == SceneMode.live) {
      final step = math.min(_pending + dt, maxStep);
      _pending = 0;
      rendered++;
      return step;
    }
    _pending += dt;
    // Half a 120 Hz vsync of tolerance so 2 × 16.6 ms counts as 1/30 s.
    if (_pending + 0.004 < 1 / stepFps) {
      skipped++;
      return null;
    }
    final step = math.min(_pending, maxStep);
    _pending = 0;
    rendered++;
    return step;
  }

  /// Forgets any partially accumulated idle time (e.g. after a resume).
  void reset() => _pending = 0;
}

/// The scene's clock: turns the ticker's elapsed time into per-vsync steps.
class SceneClock {
  Duration? _last;

  /// Seconds the scene has advanced in total.
  double seconds = 0;

  /// Vsyncs seen since the ticker (re)started.
  int frames = 0;

  /// The vsync at [elapsed] (the ticker's clock): seconds since the previous
  /// vsync (0 for the first one after a restart).
  double tick(Duration elapsed) {
    final last = _last;
    _last = elapsed;
    frames++;
    if (last == null) return 0;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    return dt.isFinite && dt > 0 ? dt : 0;
  }

  /// Records that the scene advanced by [dt].
  void advanced(double dt) => seconds += dt;

  /// The ticker stopped: the next vsync starts a new run.
  void restart() {
    _last = null;
    frames = 0;
  }
}
