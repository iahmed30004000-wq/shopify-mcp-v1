import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// How much of the scene's optional polish is rendered.
enum SceneQuality {
  /// Everything: lens flares, engraved star names, moon labels, depth of
  /// field and motion blur.
  high,

  /// No lens flares and no star names (the most expensive extras).
  balanced,

  /// Also no moon / planet labels while zoomed, no depth-of-field or motion
  /// blur, no twinkle.
  low,
}

/// Watches frame timings and lowers (or restores) the scene quality when the
/// raster thread cannot keep up (pure; fed from
/// `SchedulerBinding.addTimingsCallback`).
///
/// Samples are grouped in windows of [window] frames. When the 90th
/// percentile of a window's raster (or build) time is over the frame budget
/// in [downAfter] consecutive windows, quality steps down; when it stays well
/// under budget for [upAfter] windows, it steps back up (hysteresis, so it
/// never flickers).
class AdaptiveQuality {
  AdaptiveQuality({this.window = 48, this.downAfter = 2, this.upAfter = 6, double refreshRate = 60})
    : _budgetMs = budgetFor(refreshRate);

  /// The frame budget: the display's own below 60 Hz, never tighter than
  /// 60 fps (the quality gate) – a 120 Hz panel that holds 60 fps keeps its
  /// polish.
  static double budgetFor(double hz) => 1000 / math.min(hz, 60);

  final int window;
  final int downAfter;
  final int upAfter;

  SceneQuality _quality = SceneQuality.high;
  double _budgetMs;
  final List<double> _samples = [];
  int _over = 0, _under = 0;

  SceneQuality get quality => _quality;

  /// Frame budget in milliseconds (see [budgetFor]).
  double get budgetMs => _budgetMs;

  /// The display's refresh rate (60, 90, 120 Hz …).
  set refreshRate(double hz) {
    if (!hz.isFinite || hz < 20) return;
    _budgetMs = budgetFor(hz);
  }

  bool get lensFlare => _quality == SceneQuality.high;
  bool get starNames => _quality == SceneQuality.high;
  bool get zoomedLabels => _quality != SceneQuality.low;
  bool get depthOfField => _quality != SceneQuality.low;
  bool get motionBlur => _quality == SceneQuality.high;
  bool get twinkle => _quality != SceneQuality.low;

  /// Adds one frame's timings (ms); returns whether [quality] changed.
  bool addFrame({required double rasterMs, double buildMs = 0}) {
    _samples.add(math.max(rasterMs, buildMs));
    if (_samples.length < window) return false;
    final sorted = List<double>.of(_samples)..sort();
    _samples.clear();
    final p90 = sorted[(sorted.length * 0.9).floor().clamp(0, sorted.length - 1)];
    if (p90 > _budgetMs * 1.05) {
      _over++;
      _under = 0;
    } else if (p90 < _budgetMs * 0.55) {
      _under++;
      _over = 0;
    } else {
      _over = 0;
      _under = 0;
    }
    if (_over >= downAfter && _quality != SceneQuality.low) {
      _quality = SceneQuality.values[_quality.index + 1];
      _over = 0;
      return true;
    }
    if (_under >= upAfter && _quality != SceneQuality.high) {
      _quality = SceneQuality.values[_quality.index - 1];
      _under = 0;
      return true;
    }
    return false;
  }

  @visibleForTesting
  set debugQuality(SceneQuality q) => _quality = q;
}
