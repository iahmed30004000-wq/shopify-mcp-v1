import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/ambient_motion.dart';
import '../../../core/i18n/formatters.dart';
import '../../orbit/render/astrolabe/astrolabe_shaders.dart';
import 'lock_astrolabe_painter.dart';

/// The lock screen's astrolabe at an assembly [progress] (0 = parts
/// scattered in depth, 1 = assembled), with the ignition flare, the
/// fingerprint-reading sweep and the error pulse. Unassembled parts float
/// gently while ambient motion is on.
///
/// [size] is the side of the square box; the dial itself is
/// `size / LockAstrolabePainter.boxFactor` wide (the margin is room for the
/// parts flying in).
class LockAstrolabe extends StatefulWidget {
  const LockAstrolabe({
    super.key,
    required this.progress,
    required this.size,
    this.ignite,
    this.scan,
    this.error,
    this.ruleAngle = -math.pi / 2,
    this.animate = true,
  });

  final Animation<double> progress;
  final Animation<double>? ignite;
  final Animation<double>? scan;
  final Animation<double>? error;
  final double size;
  final double ruleAngle;

  /// Ambient float and twinkle (off under reduced motion / battery saver).
  final bool animate;

  /// The canvas angle of [time] on the 24-hour dial (noon at the top,
  /// clockwise), where the rule settles.
  static double ruleAngleFor(DateTime time) => -math.pi / 2 + ((time.hour + time.minute / 60) - 12) / 24 * 2 * math.pi;

  @override
  State<LockAstrolabe> createState() => _LockAstrolabeState();
}

class _LockAstrolabeState extends State<LockAstrolabe> with SingleTickerProviderStateMixin {
  final LockDialCache _cache = LockDialCache();
  final ValueNotifier<double> _time = ValueNotifier(0);

  /// Frame-accurate time for the fingerprint sweep only (a few seconds).
  late final Ticker _ticker = createTicker(_tick);
  ui.FragmentShader? _brass;
  bool _disposed = false;

  /// The idle float and twinkle ride the app-wide [AmbientClock] (~30 Hz,
  /// timer-driven): a running [Ticker] would request a frame on every vsync
  /// – 90/120 Hz on today's phones – for as long as the lock screen is up.
  bool _ambientSubscribed = false;
  double _ambientBase = 0;
  double _tickerBase = 0;

  @override
  void initState() {
    super.initState();
    final programs = AstrolabePrograms.instance;
    if (programs != null) {
      _useBrass(programs);
    } else {
      unawaited(
        AstrolabePrograms.load().then((p) {
          if (!_disposed && mounted) setState(() => _useBrass(p));
        }, onError: (Object _) {}),
      );
    }
    widget.scan?.addListener(_sync);
  }

  void _useBrass(AstrolabePrograms programs) {
    _brass = programs.brass.fragmentShader()..setImageSampler(0, programs.noise, filterQuality: ui.FilterQuality.low);
  }

  bool _ambientAllowed = false;
  bool _tickersEnabled = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ambientAllowed = context.ambientMotion;
    _tickersEnabled = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(LockAstrolabe old) {
    super.didUpdateWidget(old);
    if (old.scan != widget.scan) {
      old.scan?.removeListener(_sync);
      widget.scan?.addListener(_sync);
    }
    _sync();
  }

  bool get _ambient => widget.animate && _ambientAllowed && _tickersEnabled;

  void _sync() {
    if (_disposed) return;
    final scanning = (widget.scan?.value ?? 0) > 0;
    // The sweep runs on the ticker (and the ticker pauses with TickerMode).
    if (scanning && !_ticker.isActive) {
      _tickerBase = _time.value;
      _ticker.start();
    } else if (!scanning && _ticker.isActive) {
      _ticker.stop();
    }
    final wantAmbient = _ambient && !scanning;
    final clock = AmbientClock.instance;
    if (wantAmbient && !_ambientSubscribed) {
      _ambientBase = _time.value - clock.seconds;
      clock.addListener(_onAmbient);
      _ambientSubscribed = true;
    } else if (!wantAmbient && _ambientSubscribed) {
      clock.removeListener(_onAmbient);
      _ambientSubscribed = false;
    }
  }

  void _onAmbient() => _time.value = _ambientBase + AmbientClock.instance.seconds;

  void _tick(Duration elapsed) => _time.value = _tickerBase + elapsed.inMicroseconds / 1e6;

  @override
  void dispose() {
    _disposed = true;
    widget.scan?.removeListener(_sync);
    if (_ambientSubscribed) AmbientClock.instance.removeListener(_onAmbient);
    _ticker.dispose();
    _time.dispose();
    _brass?.dispose();
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final look = LockDialLook.of(t);
    final arabicIndic = context.formatter.arabicIndic;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    final drift = widget.animate && _ambientAllowed ? 1.0 : 0.0;
    final listenables = <Listenable>[widget.progress, _time, ?widget.ignite, ?widget.scan, ?widget.error];
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge(listenables),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: LockAstrolabePainter(
            frame: LockDialFrame(
              progress: widget.progress.value,
              ignite: widget.ignite?.value ?? 0,
              scan: widget.scan?.value ?? 0,
              error: widget.error?.value ?? 0,
              time: _time.value,
              drift: drift,
              ruleAngle: widget.ruleAngle,
            ),
            look: look,
            cache: _cache,
            arabicIndic: arabicIndic,
            devicePixelRatio: dpr,
            brass: _brass,
          ),
        ),
      ),
    );
  }
}
