import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/ambient_motion.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/motion/particles/celebration.dart';
import '../../../../core/sound/sound_api.dart';
import 'astrolabe_cache.dart';
import 'astrolabe_controller.dart';
import 'astrolabe_geometry.dart';
import 'astrolabe_painter.dart';
import 'astrolabe_palette.dart';
import 'astrolabe_shaders.dart';
import 'astrolabe_state.dart';

/// Called when a prayer pointer ignites, with the pointer tip in global
/// coordinates (for a celebration burst).
typedef AstrolabePrayerLit = void Function(Prayer prayer, Offset globalTip);

/// The astrolabe centrepiece of the Astrolabe Orbit: a brass-and-gold 24-hour
/// prayer dial around the user's core star (see [AstrolabePainter]).
///
/// Integration:
/// * call `AstrolabePrograms.warmUp()` during the splash so the first frame
///   never compiles a shader;
/// * pass a [controller] driven by the scene's single ticker
///   (`controller.advance(dt)`; `controller.isAnimating` tells when a
///   one-shot animation needs full frame rate, otherwise 30 fps is plenty)
///   and rebuild with a new [state] whenever it changes (once a second for
///   the countdown) – or push states into the controller directly. Without a
///   controller the layer runs its own ticker (standalone use) while ambient
///   motion is allowed, at 30 fps when idle and never while hidden;
/// * [tilt] (or `controller.tilt`) tilts the disc in perspective;
/// * [repaint] adds the scene's own repaint signal (camera, frame clock);
/// * battery saver: draw an `AstrolabeStill.render(...)` image instead.
///
/// When a prayer gets logged its pointer ignites over 0.8 s: [onPrayerLit]
/// is called after the frame (default: `Fx.fire(Sfx.prayerLit)` plus a
/// Celebrate orbitalRing burst at the pointer). Tapping a pointer or its name
/// fires `Sfx.tap` and calls [onPrayerTap]; nothing else is claimed, so the
/// scene's gestures work across the astrolabe.
class AstrolabeLayer extends StatefulWidget {
  const AstrolabeLayer({
    super.key,
    required this.state,
    this.controller,
    this.repaint,
    this.tilt,
    this.onPrayerLit,
    this.onPrayerTap,
    this.celebrate = true,
    this.animate = true,
    this.showMakersMark = true,
    this.palette,
  });

  /// What the dial shows. A different object is pushed into the controller
  /// (newly logged prayers ignite); the same object is ignored.
  final AstrolabeState state;

  /// The scene's controller (advanced by the scene's ticker); null → the
  /// layer owns one and ticks it itself.
  final AstrolabeController? controller;

  /// Extra repaint signal merged with the controller's.
  final Listenable? repaint;

  /// Disc tilt (gyro parallax / camera); null leaves the controller's tilt.
  final AstrolabeTilt? tilt;

  /// Replaces the default ignition feedback (see the class docs).
  final AstrolabePrayerLit? onPrayerLit;

  /// Opens a prayer (its pointer or engraved name was tapped).
  final ValueChanged<Prayer>? onPrayerTap;

  /// Default ignition feedback (sound + particles) when [onPrayerLit] is null.
  final bool celebrate;

  /// Standalone mode only: run the layer's own ticker.
  final bool animate;

  /// Engrave the maker's mark on the lower hub ring (large dials).
  final bool showMakersMark;

  /// Overrides the colours (default: derived from the theme's tokens).
  final AstrolabePalette? palette;

  @override
  State<AstrolabeLayer> createState() => _AstrolabeLayerState();
}

class _AstrolabeLayerState extends State<AstrolabeLayer> with SingleTickerProviderStateMixin {
  late AstrolabeController _controller;
  bool _ownsController = false;
  final AstrolabeRenderCache _cache = AstrolabeRenderCache();
  AstrolabeShaderSet? _shaders;
  Ticker? _ticker;
  Duration _last = Duration.zero;
  final GlobalKey _paintKey = GlobalKey();
  AstrolabePainter? _painter;

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
    _controller.update(widget.state, animate: false);
    if (widget.tilt != null) _controller.tilt = widget.tilt!;
    final programs = AstrolabePrograms.instance;
    if (programs != null) {
      _shaders = AstrolabeShaderSet(programs);
    } else {
      unawaited(
        AstrolabePrograms.load().then((p) {
          if (!mounted) return;
          setState(() => _shaders = AstrolabeShaderSet(p));
        }, onError: (Object _) {}),
      );
    }
  }

  void _attach(AstrolabeController? external) {
    _ownsController = external == null;
    _controller = external ?? AstrolabeController();
    _controller.addIgniteListener(_onIgnite);
  }

  void _detach() {
    _controller.removeIgniteListener(_onIgnite);
    if (_ownsController) _controller.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.reducedMotion = context.reducedMotion;
    _syncTicker();
  }

  @override
  void didUpdateWidget(AstrolabeLayer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _detach();
      _attach(widget.controller);
      _controller.update(widget.state, animate: false);
    } else if (!identical(old.state, widget.state)) {
      _controller.update(widget.state);
    }
    if (widget.tilt != null && widget.tilt != old.tilt) _controller.tilt = widget.tilt!;
    _syncTicker();
  }

  void _syncTicker() {
    final run = _ownsController && widget.animate && AmbientMotion.enabled && !context.reducedMotion;
    if (run) {
      _ticker ??= createTicker(_tick);
      if (!_ticker!.isActive) {
        _last = Duration.zero;
        _ticker!.start();
      }
    } else {
      _ticker?.stop();
    }
  }

  void _tick(Duration elapsed) {
    final dt = elapsed - _last;
    _last = elapsed;
    // Idle astrolabe: ~30 fps is plenty; animations run at full rate.
    if (!_controller.isAnimating && dt < const Duration(milliseconds: 30)) {
      _last -= dt;
      return;
    }
    _controller.advance(dt);
  }

  void _onIgnite(Prayer prayer) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final global = _globalTip(prayer);
      final custom = widget.onPrayerLit;
      if (custom != null) {
        custom(prayer, global ?? Offset.zero);
        return;
      }
      if (!widget.celebrate) return;
      if (global == null) {
        Fx.fire(Sfx.prayerLit);
        return;
      }
      Celebrate.burst(context, global, kind: CelebrationKind.orbitalRing, sfx: Sfx.prayerLit, radius: _pointerRadius());
    });
  }

  double _pointerRadius() {
    final box = _paintKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return 24;
    return AstrolabeGeometry.radiusFor(box.size) * 0.09 + 10;
  }

  Offset? _globalTip(Prayer prayer) {
    final box = _paintKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final size = box.size;
    final state = _controller.state;
    if (state == null) return null;
    final center = size.center(Offset.zero);
    final radius = AstrolabeGeometry.radiusFor(size);
    var tip = AstrolabeGeometry.pointerTip(center, radius, state.fractionOf(prayer));
    final tilt = _controller.tilt;
    if (!tilt.isFlat) tip = AstrolabeGeometry.project(AstrolabeGeometry.tiltMatrix(center, radius, tilt), tip);
    return box.localToGlobal(tip);
  }

  void _onTapUp(TapUpDetails details) {
    final box = _paintKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final prayer = _painter?.prayerAt(details.localPosition, box.size);
    if (prayer != null) _tapPrayer(prayer);
  }

  void _tapPrayer(Prayer prayer) {
    final onTap = widget.onPrayerTap;
    if (onTap == null) return;
    Fx.fire(Sfx.tap);
    onTap(prayer);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _detach();
    _shaders?.dispose();
    _cache.dispose();
    super.dispose();
  }

  static String _summary(AstrolabeState s) {
    final labels = s.labels;
    final l10n = labels.l10n;
    return l10n.astrolabeSemantics(
      l10n.astrolabeWindowNow(labels.windowName(s.window.window)),
      s.spokenCountdown,
      labels.formatter.formatInt(s.prayedCount),
      labels.formatter.formatInt(AstrolabeGeometry.prayers.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette ?? AstrolabePalette.fromTokens(context.tokens);
    final l10n = widget.state.labels.l10n;
    final painter = _painter = AstrolabePainter(
      controller: _controller,
      palette: palette,
      cache: _cache,
      shaders: _shaders,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      makersMark: widget.showMakersMark ? l10n.astrolabeMakersMark : null,
      semanticsState: widget.state,
      onPrayerTap: widget.onPrayerTap == null ? null : _tapPrayer,
      repaint: widget.repaint,
    );
    Widget child = CustomPaint(key: _paintKey, painter: painter, size: Size.infinite);
    if (widget.onPrayerTap != null) {
      // Only taps on a pointer or its name are claimed (see the painter's
      // hitTest); everything else reaches the orbit scene.
      child = GestureDetector(behavior: HitTestBehavior.deferToChild, onTapUp: _onTapUp, child: child);
    }
    return Semantics(
      container: true,
      label: _summary(widget.state),
      child: RepaintBoundary(child: child),
    );
  }
}
