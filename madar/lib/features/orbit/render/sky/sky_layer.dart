import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/ambient_motion.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion.dart';
import '../../domain/scene_math.dart';
import 'sky_controller.dart';
import 'sky_model.dart';
import 'sky_painter.dart';
import 'sky_shaders.dart';
import 'sky_view.dart';

/// The living sky behind the whole Astrolabe Orbit: a real-time sky that
/// follows the actual sun over the user's location (dawn at Fajr, clear
/// day, golden hour, Maghrib glow), and at night the real starfield with the
/// Milky Way, the engraved names of the brightest stars and the moon in its
/// true phase.
///
/// Integration (scene mode): pass the scene's [controller] and drive it from
/// the scene's single ticker – `controller.advance(dt)`, plus
/// `controller.camera = orbitCamera`, `zoom`, `gyro`, `time` as they change.
/// The layer then never ticks by itself. Put [SkyFlareLayer] with the same
/// controller above the scene for the lens flares.
///
/// Standalone: without a controller the layer owns one that follows the
/// clock (or shows the fixed [time]) and runs its own ≤ 30 fps ticker for
/// the twinkle – only while ambient motion is allowed and motion is not
/// reduced; otherwise it paints one still.
class SkyLayer extends StatefulWidget {
  const SkyLayer({
    super.key,
    this.controller,
    this.time,
    this.observer = SkyObserver.amman,
    this.tone,
    this.camera = const OrbitCamera(),
    this.composition = const SkyComposition(),
    this.showStarNames = true,
    this.labelKeepOut,
    this.animate = true,
    this.starScale = 1,
  });

  /// The scene's controller (scene mode). Without it the layer owns one.
  final SkyController? controller;

  /// Standalone only: a fixed instant (null = follow the clock).
  final DateTime? time;

  /// Standalone only: where the sky is seen from.
  final SkyObserver observer;

  /// Theme inputs (default: from the ambient [MadarTokens]).
  final SkyTone? tone;

  /// Standalone only: the orbit camera the sky parallaxes with.
  final OrbitCamera camera;

  /// Standalone only: framing of the sky.
  final SkyComposition composition;

  /// Standalone only: engraved star names.
  final bool showStarNames;

  /// Standalone only: rect (local px) star names avoid.
  final Rect? labelKeepOut;

  /// Standalone only: run the layer's own twinkle ticker.
  final bool animate;

  /// Multiplies star sprite sizes.
  final double starScale;

  @override
  State<SkyLayer> createState() => _SkyLayerState();
}

class _SkyLayerState extends State<SkyLayer> with SingleTickerProviderStateMixin {
  late SkyController _controller;
  bool _owns = false;
  final SkyRenderCache _cache = SkyRenderCache();
  SkyPrograms? _programs;
  Ticker? _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _attach();
    final programs = SkyPrograms.instance;
    if (programs != null) {
      _bind(programs);
    } else {
      unawaited(
        SkyPrograms.load().then((p) {
          if (!mounted) return;
          setState(() => _bind(p));
        }, onError: (Object _) {}),
      );
    }
  }

  void _bind(SkyPrograms p) {
    _programs = p;
    _cache.attach(p);
  }

  void _attach() {
    final external = widget.controller;
    _owns = external == null;
    _controller =
        external ??
        SkyController(
          time: widget.time,
          observer: widget.observer,
          camera: widget.camera,
          composition: widget.composition,
          showStarNames: widget.showStarNames,
          clock: widget.time == null ? DateTime.now : null,
        );
    if (_owns) _controller.labelKeepOut = widget.labelKeepOut;
    _controller.backdrop.addListener(_onBackdrop);
  }

  void _detach() {
    _controller.backdrop.removeListener(_onBackdrop);
    if (_owns) _controller.dispose();
  }

  Object? _describedKey;

  /// The spoken description only changes with the mood or the moon.
  static Object? _describeKey(SkyState? s) =>
      s == null ? null : (s.mood, s.moonUp, s.moonPhaseName, (s.moonIllumination * 100).round());

  void _onBackdrop() {
    final key = _describeKey(_controller.state);
    if (key != _describedKey && mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller
      ..tone = widget.tone ?? SkyTone.fromTokens(context.tokens)
      ..reducedMotion = context.reducedMotion
      ..arabicNames = Localizations.maybeLocaleOf(context)?.languageCode != 'en';
    _syncTicker();
  }

  @override
  void didUpdateWidget(SkyLayer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _detach();
      _attach();
      _controller
        ..tone = widget.tone ?? SkyTone.fromTokens(context.tokens)
        ..reducedMotion = context.reducedMotion;
    } else if (_owns) {
      if (widget.time != null) _controller.time = widget.time!;
      _controller
        ..observer = widget.observer
        ..camera = widget.camera
        ..composition = widget.composition
        ..showStarNames = widget.showStarNames
        ..labelKeepOut = widget.labelKeepOut;
    }
    if (widget.tone != null) _controller.tone = widget.tone;
    _syncTicker();
  }

  void _syncTicker() {
    final run = _owns && widget.animate && context.ambientMotion;
    if (run) {
      _ticker ??= createTicker(_tick);
      if (!_ticker!.isActive) {
        _last = Duration.zero;
        _ticker!.start();
      }
    } else {
      _ticker?.stop();
    }
    if (_owns) _controller.still = !run;
  }

  void _tick(Duration elapsed) {
    final dt = elapsed - _last;
    // The sky alone never needs more than ~30 fps.
    if (dt < const Duration(milliseconds: 32)) return;
    _last = elapsed;
    _controller.advance(dt);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _detach();
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      container: true,
      image: true,
      label: _semantics(context),
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: SkyBackdropPainter(controller: _controller, cache: _cache, devicePixelRatio: dpr),
                size: Size.infinite,
              ),
            ),
            RepaintBoundary(
              child: CustomPaint(
                painter: SkyStarsPainter(controller: _controller, programs: _programs, starScale: widget.starScale),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _semantics(BuildContext context) {
    final s = _controller.state;
    _describedKey = _describeKey(s);
    if (s == null) return null;
    return SkyDescriptions.describe(L10n.of(context), context.formatter, s);
  }
}

/// Lens flares over the whole scene (put it above every scene layer, with
/// the same controller as the [SkyLayer]; set `controller.coreStar` to the
/// core star's centre in this layer's coordinates).
class SkyFlareLayer extends StatefulWidget {
  const SkyFlareLayer({super.key, required this.controller});

  final SkyController controller;

  @override
  State<SkyFlareLayer> createState() => _SkyFlareLayerState();
}

class _SkyFlareLayerState extends State<SkyFlareLayer> {
  FlareShaderSet? _shaders;

  @override
  void initState() {
    super.initState();
    final programs = SkyPrograms.instance;
    if (programs != null) {
      _shaders = FlareShaderSet(programs);
    } else {
      unawaited(
        SkyPrograms.load().then((p) {
          if (!mounted) return;
          setState(() => _shaders = FlareShaderSet(p));
        }, onError: (Object _) {}),
      );
    }
  }

  @override
  void dispose() {
    _shaders?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: SkyFlarePainter(controller: widget.controller, shaders: _shaders),
          size: Size.infinite,
        ),
      ),
    ),
  );
}

/// Localised words for the sky (screen readers, settings).
abstract final class SkyDescriptions {
  static String mood(L10n l10n, SkyMood m) => switch (m) {
    SkyMood.night => l10n.skyMoodNight,
    SkyMood.dawn => l10n.skyMoodDawn,
    SkyMood.sunrise => l10n.skyMoodSunrise,
    SkyMood.day => l10n.skyMoodDay,
    SkyMood.goldenHour => l10n.skyMoodGoldenHour,
    SkyMood.sunset => l10n.skyMoodSunset,
    SkyMood.dusk => l10n.skyMoodDusk,
  };

  static String moonPhase(L10n l10n, MoonPhaseName p) => switch (p) {
    MoonPhaseName.newMoon => l10n.skyMoonNew,
    MoonPhaseName.waxingCrescent => l10n.skyMoonWaxingCrescent,
    MoonPhaseName.firstQuarter => l10n.skyMoonFirstQuarter,
    MoonPhaseName.waxingGibbous => l10n.skyMoonWaxingGibbous,
    MoonPhaseName.full => l10n.skyMoonFull,
    MoonPhaseName.waningGibbous => l10n.skyMoonWaningGibbous,
    MoonPhaseName.lastQuarter => l10n.skyMoonLastQuarter,
    MoonPhaseName.waningCrescent => l10n.skyMoonWaningCrescent,
  };

  /// "Sky now: night. Moon: full moon, 98% lit" (localised digits).
  static String describe(L10n l10n, MadarFormatter f, SkyState s) {
    final moon = s.moonUp
        ? l10n.skyMoonPhase(moonPhase(l10n, s.moonPhaseName), f.formatPercent(s.moonIllumination))
        : l10n.skyMoonBelow;
    return l10n.skySemantics(mood(l10n, s.mood), moon);
  }
}
