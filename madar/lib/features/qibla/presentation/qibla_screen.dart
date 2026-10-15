import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../../prayer/presentation/location_sheet.dart' show showPrayerLocationSheet;
import '../../prayer/presentation/widgets/prayer_widgets.dart' show PrayerLocationChip;
import '../application/qibla_compass_controller.dart';
import '../application/qibla_providers.dart';
import '../domain/compass_math.dart';
import '../domain/compass_quality.dart';
import '../domain/heading.dart';
import '../domain/qibla_fix.dart';
import 'qibla_labels.dart';
import 'widgets/calibration_prompt.dart';
import 'widgets/qibla_dial.dart';
import 'widgets/qibla_dial_painter.dart';

/// The qibla compass: a brass astrolabe that turns with the phone so its
/// Kaaba star-pointer and golden needle point to the qibla, with the
/// bearing, the distance, an accuracy estimate, the figure-eight prompt
/// and the sun / diagram fallbacks.
///
/// [place] overrides the prayer location (e.g. a travel destination); the
/// default follows `qiblaPlaceProvider`. The sensors run only while the
/// screen is visible and the app is in the foreground.
class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key, this.place});

  final QiblaPlace? place;

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> with WidgetsBindingObserver {
  late QiblaCompassController _controller;
  final ValueNotifier<double?> _facing = ValueNotifier(null);
  final ValueNotifier<Offset> _tilt = ValueNotifier(Offset.zero);
  bool _foreground = true;
  bool _visible = true;
  bool _landscape = false;
  int _alignSeen = 0;
  int _calibratedSeen = 0;
  bool _calibratedFlash = false;
  Timer? _flashTimer;
  QiblaDialStyle? _style;
  int? _styleKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final saver = ref.read(appSettingsProvider).powerMode == PowerMode.batterySaver;
    _controller = QiblaCompassController(
      source: ref.read(headingSourceProvider),
      place: widget.place ?? ref.read(qiblaPlaceProvider),
      clock: ref.read(qiblaClockProvider),
      batterySaver: saver,
    );
    _controller.live.addListener(_onLive);
    _controller.state.addListener(_onState);
    _controller.start();
    _onLive();
  }

  void _onLive() {
    final l = _controller.live.value;
    _facing.value = l.facing;
    _tilt.value = Offset(l.roll, l.pitch);
  }

  void _onState() {
    final s = _controller.value;
    if (s.alignCount != _alignSeen) {
      _alignSeen = s.alignCount;
      // A gentle chime and a light tap: facing the qibla.
      Fx.fire(Sfx.complete, volume: 0.7, haptic: Haptic.light);
    }
    if (s.calibratedCount != _calibratedSeen) {
      _calibratedSeen = s.calibratedCount;
      Fx.fire(Sfx.sparkle, haptic: Haptic.success);
      _flashTimer?.cancel();
      _calibratedFlash = true;
      _flashTimer = Timer(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _calibratedFlash = false);
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    _syncRunning();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    if (landscape != _landscape) {
      _landscape = landscape;
      _controller.setLandscape(landscape);
    }
    _syncRunning();
  }

  void _syncRunning() {
    if (_foreground && _visible) {
      _controller.start();
    } else {
      _controller.pause();
    }
  }

  @override
  void didUpdateWidget(QiblaScreen old) {
    super.didUpdateWidget(old);
    if (old.place != widget.place) _controller.setPlace(widget.place ?? ref.read(qiblaPlaceProvider));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashTimer?.cancel();
    _controller.live.removeListener(_onLive);
    _controller.state.removeListener(_onState);
    _controller.dispose();
    _facing.dispose();
    _tilt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final saver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    ref.listen<bool>(
      appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver),
      (_, next) => _controller.setBatterySaver(next),
    );
    if (widget.place == null) {
      ref.listen<QiblaPlace>(qiblaPlaceProvider, (_, next) => _controller.setPlace(next));
    }
    final s = _controller.value;
    return MadarScaffold(
      title: l.qiblaTitle,
      extendBodyBehindAppBar: true,
      animateBackdrop: !saver,
      backdropSeed: 0.61,
      body: Builder(
        builder: (context) {
          final pad = MediaQuery.paddingOf(context);
          return LayoutBuilder(
            builder: (context, viewport) {
              final top = pad.top + Space.s;
              final bottom = pad.bottom + Space.xl;
              final dialSize = (viewport.maxWidth - 2 * Space.gutter).clamp(200.0, 440.0);
              return SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, top, Space.gutter, bottom),
                child: ConstrainedBox(
                  // Fill the screen: the readouts sit at the bottom,
                  // the dial in the middle.
                  constraints: BoxConstraints(
                    minHeight: (viewport.maxHeight - top - bottom).clamp(0.0, double.infinity),
                  ),
                  child: IntrinsicHeight(
                    child: StaggerIn(
                      id: 'qibla',
                      children: [
                        Center(child: _placeHeader(context, s)),
                        const SizedBox(height: Space.m),
                        _QiblaStatus(state: s, calibratedFlash: _calibratedFlash),
                        const Spacer(),
                        Center(
                          child: SizedBox(width: dialSize, height: dialSize * 1.02, child: _dial(context, s)),
                        ),
                        const Spacer(),
                        // The figure-eight prompt takes the readouts'
                        // place while the compass needs calibrating.
                        AnimatedSwitcher(
                          duration: context.motion(MadarMotion.medium),
                          switchInCurve: MadarMotion.decelerate,
                          switchOutCurve: MadarMotion.accelerate,
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(
                              position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(a),
                              child: child,
                            ),
                          ),
                          child: s.showCalibration
                              ? QiblaCalibrationPrompt(
                                  interference: s.quality.interference,
                                  onLater: _controller.dismissCalibration,
                                )
                              : Column(
                                  key: const ValueKey('qibla-readouts'),
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _QiblaInfo(state: s),
                                    const SizedBox(height: Space.l),
                                    _QiblaFooter(controller: _controller, state: s),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _placeHeader(BuildContext context, QiblaCompassState s) {
    if (widget.place == null) {
      return PrayerLocationChip(onTap: () => unawaited(showPrayerLocationSheet(context)));
    }
    final t = context.tokens;
    final lang = Localizations.localeOf(context).languageCode;
    final name = s.fix.place.name(lang);
    if (name == null) return const SizedBox.shrink();
    return Text(
      L10n.of(context).qiblaFromPlace(name),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: t.textSecondary),
    );
  }

  Widget _dial(BuildContext context, QiblaCompassState s) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final kind = switch (s.mode) {
      QiblaMode.compass => QiblaDialKind.compass,
      QiblaMode.starting => QiblaDialKind.waiting,
      QiblaMode.sun => QiblaDialKind.sun,
      QiblaMode.diagram => QiblaDialKind.diagram,
    };
    final bearing = QiblaFormat.degrees(s.fix.bearing, fmt);
    final styleKey = Object.hash(t, l.localeName, fmt.arabicIndic);
    if (styleKey != _styleKey || _style == null) {
      _styleKey = styleKey;
      _style = QiblaDialStyle.of(
        t,
        cardinals: l.qiblaCardinals,
        arabicDigits: fmt.arabicIndic,
        degreeLabel: (d) => QiblaFormat.degrees(d, fmt),
      );
    }
    return QiblaDial(
      facing: _facing,
      tilt: _tilt,
      qiblaBearing: s.fix.bearing,
      kind: kind,
      aligned: s.aligned,
      sunAzimuth: s.sun.azimuth,
      showArrow: !s.fix.atKaaba,
      style: _style!,
      semanticLabel: l.qiblaDialLabel(bearing, l.qiblaPointName(CompassPoint.of(s.fix.bearing))),
    );
  }
}

/// The headline under the place: turn left / right, facing, reading, sun.
class _QiblaStatus extends StatelessWidget {
  const _QiblaStatus({required this.state, required this.calibratedFlash});

  final QiblaCompassState state;
  final bool calibratedFlash;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final s = state;
    final turn = s.turn;
    IconData? icon;
    String headline;
    var color = t.textPrimary;
    if (s.fix.atKaaba) {
      headline = l.qiblaAtKaaba;
      color = t.gold;
    } else {
      switch (s.mode) {
        case QiblaMode.starting:
          headline = l.qiblaReading;
          color = t.textSecondary;
        case QiblaMode.compass:
          if (s.aligned) {
            headline = l.qiblaFacing;
            color = t.gold;
            icon = Icons.check_circle_rounded;
          } else {
            final deg = QiblaFormat.degrees(turn!.abs(), fmt);
            headline = turn > 0 ? l.qiblaTurnRight(deg) : l.qiblaTurnLeft(deg);
            icon = turn > 0 ? Icons.rotate_right_rounded : Icons.rotate_left_rounded;
          }
        case QiblaMode.sun:
          final deg = QiblaFormat.degrees(turn!.abs(), fmt);
          headline = turn.abs() < 3 ? l.qiblaSunAhead : (turn > 0 ? l.qiblaSunRightOf(deg) : l.qiblaSunLeftOf(deg));
          icon = Icons.wb_sunny_rounded;
        case QiblaMode.diagram:
          headline = l.qiblaDiagramTitle;
          icon = Icons.explore_outlined;
      }
    }

    Widget chip;
    if (calibratedFlash) {
      chip = _Pill(
        key: const ValueKey('calibrated'),
        icon: Icons.check_rounded,
        label: l.qiblaCalibrated,
        color: t.success,
      );
    } else if (s.mode == QiblaMode.compass && s.holdFlat) {
      chip = _Pill(key: const ValueKey('flat'), icon: Icons.screen_rotation_alt_rounded, label: l.qiblaHoldFlat, color: t.warning);
    } else if (s.mode == QiblaMode.compass) {
      final q = s.quality;
      final c = switch (q.accuracy) {
        CompassAccuracy.high => t.success,
        CompassAccuracy.medium => t.info,
        CompassAccuracy.low => t.warning,
        CompassAccuracy.unreliable => t.danger,
      };
      chip = _Pill(
        key: ValueKey(q.accuracy),
        icon: Icons.gps_fixed_rounded,
        label: l.qiblaAccuracyChip(
          l.qiblaAccuracyName(q.accuracy),
          BidiIsolate.ltr('±${QiblaFormat.degrees(q.errorDeg.ceilToDouble(), fmt)}'),
        ),
        color: c,
      );
    } else if (s.unavailable != null) {
      chip = _Pill(
        key: ValueKey(s.unavailable),
        icon: Icons.explore_off_outlined,
        label: l.qiblaUnavailable(s.unavailable!),
        color: t.warning,
      );
    } else if (s.mode == QiblaMode.sun) {
      chip = _Pill(key: const ValueKey('sun'), icon: Icons.wb_sunny_outlined, label: l.qiblaSunTitle, color: t.gold);
    } else {
      chip = const SizedBox(height: 30);
    }

    // Announce arrivals and mode changes, not every degree of a turn.
    return Semantics(
      liveRegion: s.aligned || s.mode != QiblaMode.compass,
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.short),
            child: Row(
              key: ValueKey('$headline${s.aligned}'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 24, color: s.aligned ? t.gold : t.accent),
                  const SizedBox(width: Space.s),
                ],
                Flexible(
                  child: Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 22),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s),
          AnimatedSwitcher(duration: context.motion(MadarMotion.short), child: chip),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xs + 1, Space.m, Space.xs + 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusXL),
        color: Color.alphaBlend(color.withValues(alpha: 0.14), t.glassFill),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: Space.xs + 2),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bearing, distance and the current heading (or the sun) in one glass row.
class _QiblaInfo extends StatelessWidget {
  const _QiblaInfo({required this.state});

  final QiblaCompassState state;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final s = state;
    final tiles = <Widget>[
      _InfoTile(label: l.qiblaBearing, value: l.qiblaBearingText(s.fix.bearing, fmt), highlight: true),
      _InfoTile(label: l.qiblaDistance, value: l.qiblaDistanceText(s.fix.distanceKm, fmt)),
      if (s.mode == QiblaMode.compass && s.heading != null)
        _InfoTile(label: l.qiblaYourHeading, value: l.qiblaBearingText(s.heading!, fmt, decimals: 0)),
      if (s.mode == QiblaMode.sun)
        _InfoTile(label: l.qiblaSunBearing, value: l.qiblaBearingText(s.sun.azimuth, fmt, decimals: 0)),
    ];
    final t = context.tokens;
    return GlassPanel(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: Space.m),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, thickness: 0.8, color: t.glassBorder),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(color: t.textTertiary),
            ),
            const SizedBox(height: Space.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: text.titleMedium?.copyWith(
                  color: highlight ? t.gold : t.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Instructions for the fallback modes, the mode buttons and the magnetic
/// declination footnote.
class _QiblaFooter extends StatelessWidget {
  const _QiblaFooter({required this.controller, required this.state});

  final QiblaCompassController controller;
  final QiblaCompassState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final s = state;
    final body = text.bodyMedium?.copyWith(color: t.textSecondary, height: 1.5);
    final notes = <String>[];
    final buttons = <Widget>[];

    switch (s.mode) {
      case QiblaMode.starting:
        break;
      case QiblaMode.compass:
        if (s.sun.usable) {
          buttons.add(
            MadarButton(
              label: l.qiblaUseSun,
              icon: Icons.wb_sunny_outlined,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              onPressed: controller.useSun,
            ),
          );
        }
        if (s.quality.needsCalibration && s.calibrationDismissed) {
          buttons.add(
            MadarButton(
              label: l.qiblaCalibrateAction,
              icon: Icons.all_inclusive_rounded,
              variant: MadarButtonVariant.secondary,
              size: MadarButtonSize.small,
              sfx: Sfx.sheetOpen,
              onPressed: controller.requestCalibration,
            ),
          );
        }
      case QiblaMode.sun:
        notes.add(l.qiblaSunHowTo);
        if (s.sun.high) notes.add(l.qiblaSunHigh);
      case QiblaMode.diagram:
        final deg = QiblaFormat.degrees(s.fix.bearing, fmt);
        notes.add(s.fix.place.latitude < 0 ? l.qiblaDiagramHowToSouth(deg) : l.qiblaDiagramHowTo(deg));
    }
    if (s.mode == QiblaMode.sun || s.mode == QiblaMode.diagram) {
      final retry = s.unavailable != null;
      if (s.unavailable != HeadingUnavailableReason.noSensor) {
        buttons.add(
          MadarButton(
            label: retry ? l.qiblaRetry : l.qiblaUseCompass,
            icon: Icons.explore_rounded,
            variant: MadarButtonVariant.secondary,
            size: MadarButtonSize.small,
            sfx: Sfx.navigate,
            onPressed: controller.useCompass,
          ),
        );
      }
    }

    final declination = s.declination;
    final showDeclination = s.mode == QiblaMode.compass && declination.abs() >= 0.05;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final n in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: Text(n, textAlign: TextAlign.center, style: body),
          ),
        if (buttons.isNotEmpty)
          Wrap(alignment: WrapAlignment.center, spacing: Space.s, runSpacing: Space.s, children: buttons),
        if (showDeclination) ...[
          const SizedBox(height: Space.m),
          Text(
            l.qiblaDeclination(
              QiblaFormat.degrees(declination.abs(), fmt, decimals: 1),
              declination >= 0 ? l.qiblaEast : l.qiblaWest,
            ),
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: t.textTertiary, height: 1.45),
          ),
        ],
      ],
    );
  }
}
