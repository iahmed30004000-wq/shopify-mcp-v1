import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../design/themes.dart';
import '../../design/tokens.dart';
import '../../sound/sound_api.dart';
import '../motion.dart';
import 'particle_atlas.dart';
import 'particle_painter.dart';
import 'particle_system.dart';

/// The celebration effects.
enum CelebrationKind {
  /// Radial golden sparks with gravity and fade – completions.
  stardust,

  /// Warm embers rising and swaying – Maghrib, lanterns.
  lanternSparks,

  /// Thin falling streaks of light – streaks kept.
  lightRain,

  /// Sparkles igniting along a turning ring – prayer ignition.
  orbitalRing,
}

/// Theme colours of each celebration.
abstract final class CelebrationPalettes {
  static ParticlePalette of(CelebrationKind kind, MadarTokens t, {Color? color}) => switch (kind) {
    CelebrationKind.stardust => ParticlePalette(primary: color ?? t.gold, secondary: t.brass, hot: t.starTint),
    CelebrationKind.lanternSparks => ParticlePalette(primary: color ?? t.warning, secondary: t.gold, hot: t.starTint),
    CelebrationKind.lightRain => ParticlePalette(primary: color ?? t.highlight, secondary: t.accent, hot: t.starTint),
    CelebrationKind.orbitalRing => ParticlePalette(primary: color ?? t.accent, secondary: t.gold, hot: t.starTint),
  };
}

/// Controls a running ambient effect.
class CelebrationHandle {
  CelebrationHandle._(this._emitter);

  /// A handle to nothing (reduced motion, no overlay).
  static final CelebrationHandle none = CelebrationHandle._(null);

  final ParticleEmitter? _emitter;

  /// Still emitting.
  bool get isActive => _emitter?.isActive ?? false;

  /// Stops emitting; live particles finish their lives gracefully.
  void stop() => _emitter?.stop();
}

/// Fire-and-forget celebrations from anywhere below a [CelebrationOverlay].
///
/// ```dart
/// onTap: () {
///   Fx.fire(Sfx.complete);
///   Celebrate.burstFrom(context);             // from the tapped widget
/// }
/// Celebrate.burst(context, details.globalPosition, kind: CelebrationKind.orbitalRing);
/// final rain = Celebrate.ambient(context, kind: CelebrationKind.lightRain);
/// ```
///
/// Colours come from the theme tokens (override the dominant hue with
/// `color`). Under reduced motion there are no particles – a burst becomes a
/// single soft, motionless bloom of light, an ambient effect does nothing.
abstract final class Celebrate {
  /// One-shot effect at [globalPosition].
  static void burst(
    BuildContext context,
    Offset globalPosition, {
    CelebrationKind kind = CelebrationKind.stardust,
    Color? color,
    double intensity = 1,
    double? radius,
    Sfx? sfx,
  }) {
    if (sfx != null) Fx.fire(sfx);
    final overlay = CelebrationOverlay.maybeOf(context);
    if (overlay == null) return;
    final tokens = _tokens(context);
    overlay.burst(
      globalPosition,
      kind: kind,
      palette: CelebrationPalettes.of(kind, tokens, color: color),
      intensity: intensity,
      radius: radius,
      reduced: context.reducedMotion,
      additive: tokens.isDark,
    );
  }

  /// [burst] from the centre of the widget that owns [context] (an
  /// [orbitalRing] burst then rings that widget).
  static void burstFrom(
    BuildContext context, {
    CelebrationKind kind = CelebrationKind.stardust,
    Color? color,
    double intensity = 1,
    Sfx? sfx,
  }) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    burst(
      context,
      center,
      kind: kind,
      color: color,
      intensity: intensity,
      sfx: sfx,
      radius: box.size.shortestSide / 2 + 14,
    );
  }

  /// A timed (or, with a `null` [duration], open-ended) effect over [area]
  /// (global; defaults to the whole overlay). [center] / [radius] place the
  /// ring of [CelebrationKind.orbitalRing]. Returns a handle to stop it early.
  static CelebrationHandle ambient(
    BuildContext context, {
    required CelebrationKind kind,
    Duration? duration = const Duration(seconds: 4),
    Rect? area,
    Offset? center,
    double? radius,
    Color? color,
    double intensity = 1,
  }) {
    final overlay = CelebrationOverlay.maybeOf(context);
    if (overlay == null) return CelebrationHandle.none;
    final tokens = _tokens(context);
    return overlay.ambient(
      kind: kind,
      palette: CelebrationPalettes.of(kind, tokens, color: color),
      duration: duration,
      area: area,
      center: center,
      radius: radius,
      intensity: intensity,
      reduced: context.reducedMotion,
      additive: tokens.isDark,
    );
  }

  static MadarTokens _tokens(BuildContext context) =>
      Theme.of(context).extension<MadarTokens>() ?? MadarPalettes.tokensFor(MadarThemeId.lapis);
}

/// The app-wide celebration layer. Insert once near the root, inside the
/// [MotionScope], e.g.
/// `MaterialApp.router(builder: (context, child) => MotionScope(reduced: …, child: CelebrationOverlay(child: child!)))`.
///
/// One pooled particle system, one ticker and one `drawRawAtlas` call for
/// every effect on screen; the ticker sleeps whenever nothing is alive. The
/// layer never takes pointers or semantics.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key, required this.child, this.capacity = 720});

  final Widget child;

  /// Maximum particles alive at once.
  final int capacity;

  /// The overlay above [context], or the most recently mounted one.
  static CelebrationOverlayState? maybeOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_CelebrationScope>();
    if (scope != null) return scope.state;
    final mounted = CelebrationOverlayState._mounted;
    return mounted.isEmpty ? null : mounted.last;
  }

  @override
  State<CelebrationOverlay> createState() => CelebrationOverlayState();
}

class CelebrationOverlayState extends State<CelebrationOverlay> with SingleTickerProviderStateMixin {
  static final List<CelebrationOverlayState> _mounted = [];

  late final ParticleSystem _system = ParticleSystem(capacity: widget.capacity);
  late final Ticker _ticker = createTicker(_onTick);
  ParticleAtlas? _atlas;
  Duration _last = Duration.zero;
  bool _additive = true;

  /// The simulation (exposed for tests and diagnostics).
  @visibleForTesting
  ParticleSystem get system => _system;

  /// Whether the ticker is running.
  @visibleForTesting
  bool get isTicking => _ticker.isActive;

  @override
  void initState() {
    super.initState();
    _mounted.add(this);
  }

  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion switched on: everything in flight goes at once.
    final reduced = context.reducedMotion;
    if (reduced && !_reduced && !_system.isIdle) _system.clear();
    _reduced = reduced;
  }

  Offset _toLocal(Offset global) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize && box.attached) return box.globalToLocal(global);
    return global;
  }

  Size get _size {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.size;
    return MediaQuery.maybeSizeOf(context) ?? Size.zero;
  }

  void _setAdditive(bool additive) {
    if (additive == _additive) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      // Called while building: apply after this frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _additive = additive);
      });
      return;
    }
    setState(() => _additive = additive);
  }

  /// One-shot effect at a global position (see [Celebrate.burst]).
  void burst(
    Offset globalPosition, {
    required CelebrationKind kind,
    required ParticlePalette palette,
    double intensity = 1,
    double? radius,
    bool reduced = false,
    bool additive = true,
  }) {
    _setAdditive(additive);
    final p = _toLocal(globalPosition);
    if (reduced) {
      _system.flash(p.dx, p.dy, palette.primary, radius: radius ?? 64, duration: 0.5, grow: 0);
    } else {
      switch (kind) {
        case CelebrationKind.stardust:
          ParticlePresets.stardustBurst(_system, p.dx, p.dy, palette, intensity: intensity);
        case CelebrationKind.lanternSparks:
          ParticlePresets.lanternSparksBurst(_system, p.dx, p.dy, palette, intensity: intensity);
        case CelebrationKind.lightRain:
          ParticlePresets.lightRainBurst(_system, p.dx, p.dy, palette, intensity: intensity);
        case CelebrationKind.orbitalRing:
          ParticlePresets.orbitalRingBurst(_system, p.dx, p.dy, radius ?? 64, palette, intensity: intensity);
      }
    }
    _wake();
  }

  /// Timed effect (see [Celebrate.ambient]).
  CelebrationHandle ambient({
    required CelebrationKind kind,
    required ParticlePalette palette,
    Duration? duration = const Duration(seconds: 4),
    Rect? area,
    Offset? center,
    double? radius,
    double intensity = 1,
    bool reduced = false,
    bool additive = true,
  }) {
    _setAdditive(additive);
    final size = _size;
    final localArea = area == null
        ? Offset.zero & size
        : Rect.fromPoints(_toLocal(area.topLeft), _toLocal(area.bottomRight));
    final c = center == null ? localArea.center : _toLocal(center);
    final r = radius ?? math.min(140.0, localArea.shortestSide * 0.3);
    if (reduced) {
      if (kind == CelebrationKind.orbitalRing) {
        _system.flash(c.dx, c.dy, palette.primary, radius: r, duration: 0.7, grow: 0);
        _wake();
      }
      return CelebrationHandle.none;
    }
    final seconds = duration == null ? null : duration.inMicroseconds / Duration.microsecondsPerSecond;
    final k = intensity.clamp(0.2, 3.0);
    // Density follows the area so phones and tablets feel the same.
    final areaK = (localArea.width / 400).clamp(0.5, 2.5);
    final ParticleEmitter emitter = switch (kind) {
      CelebrationKind.stardust => StardustDriftEmitter(
        area: localArea,
        palette: palette,
        rate: 14 * k * areaK,
        duration: seconds,
      ),
      CelebrationKind.lanternSparks => LanternSparksEmitter(
        area: Rect.fromLTRB(localArea.left, localArea.bottom - 60, localArea.right, localArea.bottom),
        palette: palette,
        rate: 30 * k * areaK,
        duration: seconds,
        travel: localArea.height * 0.7,
      ),
      CelebrationKind.lightRain => LightRainEmitter(
        area: localArea,
        palette: palette,
        rate: 34 * k * areaK,
        duration: seconds,
      ),
      CelebrationKind.orbitalRing => OrbitalRingEmitter(
        cx: c.dx,
        cy: c.dy,
        radius: r,
        palette: palette,
        rate: 90 * k,
        duration: seconds,
      ),
    };
    if (kind == CelebrationKind.orbitalRing) {
      ParticlePresets.orbitalRingBurst(_system, c.dx, c.dy, r, palette, intensity: 0.6 * k);
    }
    _system.addEmitter(emitter);
    _wake();
    return CelebrationHandle._(emitter);
  }

  /// Removes everything at once.
  void clear() => _system.clear();

  void _wake() {
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond).clamp(0.0, 1 / 24);
    _last = elapsed;
    _system.step(dt);
    if (_system.isIdle) _ticker.stop();
  }

  @override
  void dispose() {
    _mounted.remove(this);
    _ticker.dispose();
    _system.dispose();
    _atlas?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atlas = _atlas ??= ParticleAtlas.create();
    return _CelebrationScope(
      state: this,
      child: Stack(
        fit: StackFit.passthrough,
        alignment: Alignment.center,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ParticlePainter(system: _system, atlas: atlas, additive: _additive),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CelebrationScope extends InheritedWidget {
  const _CelebrationScope({required this.state, required super.child});

  final CelebrationOverlayState state;

  @override
  bool updateShouldNotify(_CelebrationScope oldWidget) => false;
}
