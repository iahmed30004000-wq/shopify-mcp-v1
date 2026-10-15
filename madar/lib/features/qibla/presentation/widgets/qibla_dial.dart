import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/motion/motion_kit.dart';
import '../../../orbit/render/astrolabe/astrolabe_shaders.dart';
import '../../domain/compass_math.dart';
import 'qibla_dial_painter.dart';

/// The rotating qibla astrolabe.
///
/// The dial turns so its north points north ([facing] is the true bearing
/// at the top of the screen; null = north up) and its engraved Kaaba
/// star-pointer points to the qibla at [qiblaBearing]. The golden needle
/// floats on its own spring toward the qibla, and [aligned] lights the
/// needle and the kursi. Reduced motion uses critically damped springs (no
/// overshoot) and no parallax.
class QiblaDial extends StatefulWidget {
  const QiblaDial({
    super.key,
    required this.facing,
    required this.qiblaBearing,
    required this.style,
    this.kind = QiblaDialKind.compass,
    this.aligned = false,
    this.tilt,
    this.sunAzimuth,
    this.showArrow = true,
    this.detail = true,
    this.semanticLabel,
  });

  /// True bearing at the top of the screen (sensor rate), or null for a
  /// north-up dial.
  final ValueListenable<double?> facing;
  final double qiblaBearing;
  final QiblaDialStyle style;
  final QiblaDialKind kind;
  final bool aligned;

  /// (roll, pitch) elevations in degrees for the parallax.
  final ValueListenable<Offset>? tilt;
  final double? sunAzimuth;
  final bool showArrow;
  final bool detail;
  final String? semanticLabel;

  @override
  State<QiblaDial> createState() => _QiblaDialState();
}

class _QiblaDialState extends State<QiblaDial> with TickerProviderStateMixin {
  late final SpringValue _dial;
  late final SpringValue _needle;
  late final SpringValue _glow;
  final ValueNotifier<Offset> _tilt = ValueNotifier(Offset.zero);
  final QiblaDialEngraving _engraving = QiblaDialEngraving();
  QiblaBrass? _brass;
  bool _reduced = false;

  /// A real needle: a little inertia and a soft wobble; the dial follows the
  /// hand more tightly.
  static final _dialSpring = SpringDescription.withDampingRatio(mass: 1, stiffness: 240, ratio: 0.8);
  static final _needleSpring = SpringDescription.withDampingRatio(mass: 1, stiffness: 120, ratio: 0.58);
  static final _reducedSpring = SpringDescription.withDampingRatio(mass: 1, stiffness: 320, ratio: 1.0);

  @override
  void initState() {
    super.initState();
    final (dial, needle) = _targets(null, null);
    _dial = SpringValue(
      vsync: this,
      value: dial,
      spring: _dialSpring,
      tolerance: const Tolerance(distance: 0.01, velocity: 0.01),
    );
    _needle = SpringValue(
      vsync: this,
      value: needle,
      spring: _needleSpring,
      tolerance: const Tolerance(distance: 0.01, velocity: 0.01),
    );
    _glow = SpringValue(vsync: this, value: widget.aligned ? 1 : 0, spring: MadarMotion.gentle);
    widget.facing.addListener(_onFacing);
    widget.tilt?.addListener(_onTilt);
    _loadBrass();
  }

  void _loadBrass() {
    final programs = AstrolabePrograms.instance;
    if (programs != null) {
      _brass = QiblaBrass(programs);
      return;
    }
    unawaited(
      AstrolabePrograms.load().then((p) {
        if (!mounted || _brass != null) return;
        setState(() => _brass = QiblaBrass(p));
      }, onError: (Object _) {}),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = context.reducedMotion;
    if (reduced != _reduced) {
      _reduced = reduced;
      _dial.spring = reduced ? _reducedSpring : _dialSpring;
      _needle.spring = reduced ? _reducedSpring : _needleSpring;
      if (reduced) _tilt.value = Offset.zero;
    }
  }

  @override
  void didUpdateWidget(QiblaDial old) {
    super.didUpdateWidget(old);
    if (old.facing != widget.facing) {
      old.facing.removeListener(_onFacing);
      widget.facing.addListener(_onFacing);
    }
    if (old.tilt != widget.tilt) {
      old.tilt?.removeListener(_onTilt);
      widget.tilt?.addListener(_onTilt);
    }
    if (old.qiblaBearing != widget.qiblaBearing || old.kind != widget.kind) _onFacing();
    if (old.aligned != widget.aligned) _glow.animateTo(widget.aligned ? 1 : 0);
  }

  /// Unwrapped spring targets: the dial turns by −facing, the needle sits
  /// at (qibla − facing) on screen – each the short way round from where it
  /// is now.
  (double, double) _targets(double? currentDial, double? currentNeedle) {
    final facing = widget.facing.value ?? 0;
    final dial = -facing;
    final needle = widget.qiblaBearing - facing;
    return (
      currentDial == null ? CircularMath.wrap180(dial) : CircularMath.unwrapNear(dial, currentDial),
      currentNeedle == null ? CircularMath.wrap180(needle) : CircularMath.unwrapNear(needle, currentNeedle),
    );
  }

  void _onFacing() {
    final (dial, needle) = _targets(_dial.target, _needle.target);
    // A still phone: ignore sub-tenth-of-a-degree wobble so an idle dial
    // schedules no frames.
    if (!_dial.isAnimating &&
        !_needle.isAnimating &&
        (dial - _dial.target).abs() < 0.1 &&
        (needle - _needle.target).abs() < 0.1) {
      return;
    }
    _dial.animateTo(dial);
    _needle.animateTo(needle);
  }

  void _onTilt() {
    if (_reduced || !widget.detail) return;
    final t = widget.tilt!.value;
    // Elevations (deg) → −1…1, eased toward the new value.
    final target = Offset(-_sinDeg(t.dx), _sinDeg(t.dy));
    _tilt.value = Offset.lerp(_tilt.value, target, 0.25)!;
  }

  static double _sinDeg(double d) => math.sin(d.clamp(-90.0, 90.0) * math.pi / 180);

  @override
  void dispose() {
    widget.facing.removeListener(_onFacing);
    widget.tilt?.removeListener(_onTilt);
    _dial.dispose();
    _needle.dispose();
    _glow.dispose();
    _tilt.dispose();
    _engraving.dispose();
    _brass?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final waiting = widget.kind == QiblaDialKind.waiting;
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: QiblaDialPainter(
            dial: _dial,
            needle: _needle,
            glow: _glow,
            tilt: _tilt,
            style: widget.style,
            engraving: _engraving,
            kind: widget.kind,
            qiblaBearing: widget.qiblaBearing,
            devicePixelRatio: dpr,
            brass: _brass,
            sunAzimuth: widget.sunAzimuth,
            showArrow: widget.showArrow,
            needleOpacity: waiting ? 0.4 : 1,
            detail: widget.detail,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
