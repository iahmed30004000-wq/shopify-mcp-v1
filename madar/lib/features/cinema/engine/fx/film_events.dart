import 'dart:math' as math;

import '../core/film_clock.dart';
import 'film_look.dart';

/// The things that happen to a print as it runs through the projector,
/// decided once per film frame (FilmClock.filmFrame) and read by
/// film_stock.frag: splices, frame slips, one-frame chemical blotches,
/// hairs caught in the gate and the reel-change cue marks.
///
/// Deterministic for a given seed (screenshots and tests are stable) and
/// allocation-free: [advance] only mutates fields. Positions are fractions
/// of the frame (x of width, y of height; [cueRadius] of width).
class FilmEvents {
  FilmEvents({int seed = 0}) : _seed = seed, _rng = math.Random(seed * 7919 + 17);

  final int _seed;
  math.Random _rng;

  /// Splice passing the gate this frame (0..1) and its line (fraction of
  /// height).
  double splice = 0;
  double spliceY = 0.5;

  /// Vertical misframe, fraction of height (the frame line rolls through).
  double frameSlip = 0;

  /// One-frame chemical stain strength (0..1).
  double blotch = 0;

  /// Cue mark strength (0 = hidden), centre and radius.
  double cue = 0;
  double cueX = 0.86;
  double cueY = 0.11;
  double cueRadius = 0.034;

  /// Hair in the gate strength (0 = none), root position and angle.
  double hair = 0;
  double hairX = 0;
  double hairY = 0;
  double hairAngle = 0;

  int _lastFrame = -1;
  int _slipFrames = 0;
  double _slipStep = 0;
  int _spliceFrames = 0;
  int _hairFrames = 0;
  int _cueFrames = 0;
  int _reelFrames = -1;
  int _changeoverIn = -1;

  /// Film frames of the next reel change (motor cue); for tests.
  int get framesToCue => _reelFrames;

  void reset() {
    _rng = math.Random(_seed * 7919 + 17);
    _lastFrame = -1;
    splice = 0;
    frameSlip = 0;
    blotch = 0;
    cue = 0;
    hair = 0;
    _slipFrames = 0;
    _spliceFrames = 0;
    _hairFrames = 0;
    _cueFrames = 0;
    _reelFrames = -1;
    _changeoverIn = -1;
  }

  /// Steps the events to [clock]'s film frame. [wear] (0..1) scales how
  /// often things happen; [damage] (FilmFrame.damage) makes the print fall
  /// apart; [reducedMotion] drops everything that jumps or flashes (slips,
  /// splice jumps, blotches) and keeps the calm wear (hairs, cue marks).
  void advance(FilmClock clock, FilmLook look, {double wear = 1, double damage = 0, bool reducedMotion = false}) {
    final frame = clock.filmFrame;
    if (frame < _lastFrame) reset();
    if (_lastFrame < 0) {
      _lastFrame = frame;
      _scheduleReel(look, clock.projectionFps);
      return;
    }
    // Catch up on skipped film frames (a slow tick), but never more than a
    // second's worth.
    final steps = math.min(frame - _lastFrame, clock.projectionFps.ceil());
    _lastFrame = frame;
    for (var i = 0; i < steps; i++) {
      _step(look, clock.projectionFps, wear, damage, reducedMotion);
    }
  }

  void _step(FilmLook look, double fps, double wear, double damage, bool reduced) {
    final perFrame = 1 / (60 * math.max(fps, 1));
    final boost = 1 + damage * 5;
    final w = wear.clamp(0.0, 1.0);

    // Splices: a bright tape line for a frame or two, often with a jump.
    if (_spliceFrames > 0) {
      _spliceFrames--;
      splice = _spliceFrames > 0 ? 1 : 0;
    } else {
      splice = 0;
      if (_chance(look.splicesPerMinute * perFrame * boost * w)) {
        _spliceFrames = 1 + (_rng.nextDouble() < 0.4 ? 1 : 0);
        splice = reduced ? 0.4 : 1;
        spliceY = 0.15 + _rng.nextDouble() * 0.7;
        if (!reduced && _rng.nextDouble() < 0.35) _startSlip(0.08 + _rng.nextDouble() * 0.12);
      }
    }

    // Frame slips: the frame line rolls up through the picture, then the
    // projectionist re-frames.
    if (_slipFrames > 0) {
      _slipFrames--;
      frameSlip = math.max(0, frameSlip - _slipStep);
      if (_slipFrames == 0) frameSlip = 0;
    } else if (!reduced && _chance(look.frameSlipsPerMinute * perFrame * boost * w)) {
      _startSlip(0.2 + _rng.nextDouble() * 0.45);
    }

    // One-frame blotches.
    blotch = !reduced && _chance(look.blotchesPerMinute * perFrame * boost * w) ? 0.6 + _rng.nextDouble() * 0.4 : 0;

    // Hairs in the gate: stay for a few seconds near an edge.
    if (_hairFrames > 0) {
      _hairFrames--;
      if (_hairFrames == 0) hair = 0;
    } else if (_chance(look.hairsPerMinute * perFrame * w * (1 + damage))) {
      _hairFrames = ((1.5 + _rng.nextDouble() * 3.5) * fps).round();
      hair = 0.75 + _rng.nextDouble() * 0.25;
      final edge = _rng.nextInt(4);
      final along = 0.15 + _rng.nextDouble() * 0.7;
      switch (edge) {
        case 0: // left
          hairX = 0;
          hairY = along;
          hairAngle = -0.5 + _rng.nextDouble();
        case 1: // right
          hairX = 1;
          hairY = along;
          hairAngle = math.pi - 0.5 + _rng.nextDouble();
        case 2: // top
          hairX = along;
          hairY = 0;
          hairAngle = math.pi / 2 - 0.5 + _rng.nextDouble();
        default: // bottom
          hairX = along;
          hairY = 1;
          hairAngle = -math.pi / 2 - 0.5 + _rng.nextDouble();
      }
    }

    // Reel change: motor cue, then (a few seconds later) the changeover cue,
    // each shown for four frames in the top-right corner.
    if (_cueFrames > 0) {
      _cueFrames--;
      cue = _cueFrames > 0 ? 1 : 0;
    } else {
      cue = 0;
    }
    if (!look.cueMarks || w <= 0) return;
    if (_changeoverIn > 0) {
      _changeoverIn--;
      if (_changeoverIn == 0) {
        _showCue();
        _changeoverIn = -1;
        _scheduleReel(look, fps);
      }
    } else if (_reelFrames > 0) {
      _reelFrames--;
      if (_reelFrames == 0) {
        _showCue();
        _changeoverIn = (fps * (3 + _rng.nextDouble())).round();
      }
    }
  }

  void _showCue() {
    _cueFrames = 5;
    cue = 1;
    cueRadius = 0.03 + _rng.nextDouble() * 0.01;
    cueX = 0.855 + _rng.nextDouble() * 0.03;
    cueY = 0.1 + _rng.nextDouble() * 0.03;
  }

  void _scheduleReel(FilmLook look, double fps) {
    final seconds = look.reelSeconds * (0.8 + _rng.nextDouble() * 0.4);
    _reelFrames = math.max(1, (seconds * fps).round());
  }

  void _startSlip(double amount) {
    frameSlip = amount;
    _slipFrames = 4 + _rng.nextInt(4);
    _slipStep = amount / _slipFrames;
  }

  bool _chance(double p) => p > 0 && _rng.nextDouble() < p;

  /// Forces a reel change now (a game's "new reel" moment, or tests).
  void cueNow() {
    _showCue();
    _changeoverIn = -1;
  }

  /// Forces a splice with a frame slip on the next film frame's read
  /// (e.g. a boss slams the ground).
  void spliceNow({double y = 0.5, double slip = 0.25}) {
    splice = 1;
    spliceY = y;
    _spliceFrames = 2;
    if (slip > 0) _startSlip(slip);
  }
}
