import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/painters/painters.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/wellbeing_providers.dart';
import '../domain/breathing.dart';
import '../domain/wellbeing_settings.dart';
import 'wellbeing_texts.dart';

/// Guided breathing – 4-7-8 or box (4-4-4-4) – around an astrolabe ring
/// that opens as you breathe in and closes as you breathe out. Each phase
/// change gives a haptic cue (and a soft sound when enabled). Under reduced
/// motion the ring stays still and only the phase arc and words change.
/// Finished (or stopped after a full cycle) sessions are logged on the
/// Health planet (`health.breathing`).
class BreathingScreen extends ConsumerStatefulWidget {
  const BreathingScreen({super.key, this.pattern, this.cycles, this.animateBackdrop = true});

  /// Pattern id (`478` or `box`); defaults to the last used.
  final String? pattern;
  final int? cycles;
  final bool animateBackdrop;

  @override
  ConsumerState<BreathingScreen> createState() => _BreathingScreenState();
}

enum _Run { idle, running, paused, finished }

class _BreathingScreenState extends ConsumerState<BreathingScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late BreathingPattern _pattern;
  late int _cycles;
  late bool _sound;
  _Run _run = _Run.idle;
  Duration _banked = Duration.zero;
  Duration _elapsed = Duration.zero;
  BreathState? _last;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(wellbeingSettingsProvider).value ?? const WellbeingSettings();
    _pattern = BreathingPattern.byId(widget.pattern ?? s.breathingPattern);
    _cycles = widget.cycles ?? s.breathingCycles;
    _sound = s.breathingSound;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  BreathState get _state => BreathingClock.at(_pattern, _elapsed, cycles: _cycles);

  void _onTick(Duration sinceStart) {
    final elapsed = _banked + sinceStart;
    final s = BreathingClock.at(_pattern, elapsed, cycles: _cycles);
    final last = _last;
    if (last == null || !s.samePhaseAs(last)) _cue(s);
    _last = s;
    setState(() => _elapsed = elapsed);
    if (s.finished) _finish();
  }

  void _cue(BreathState s) {
    if (s.finished) return;
    final (sfx, haptic) = switch (s.phase) {
      BreathPhase.inhale => (Sfx.toggleOn, Haptic.medium),
      BreathPhase.holdIn || BreathPhase.holdOut => (Sfx.countTick, Haptic.light),
      BreathPhase.exhale => (Sfx.toggleOff, Haptic.medium),
    };
    if (_sound) {
      Fx.fire(sfx, volume: 0.35, pitch: s.phase == BreathPhase.inhale ? 0.9 : 0.8, haptic: haptic);
    } else {
      Fx.instance?.haptics.fire(haptic);
    }
  }

  void _start() {
    Fx.fire(Sfx.tap);
    _logged = false;
    _banked = Duration.zero;
    _elapsed = Duration.zero;
    _last = null;
    setState(() => _run = _Run.running);
    _ticker
      ..stop()
      ..start();
    ref
        .read(wellbeingServiceProvider)
        .updateSettings(
          (s) => s.copyWith(breathingPattern: _pattern.id, breathingCycles: _cycles, breathingSound: _sound),
        );
  }

  void _pause() {
    Fx.fire(Sfx.toggleOff);
    _banked = _elapsed;
    _ticker.stop();
    setState(() => _run = _Run.paused);
  }

  void _resume() {
    Fx.fire(Sfx.toggleOn);
    _ticker
      ..stop()
      ..start();
    setState(() => _run = _Run.running);
  }

  Future<void> _stop() async {
    _ticker.stop();
    Fx.fire(Sfx.back);
    await _log();
    setState(() {
      _run = _Run.idle;
      _elapsed = Duration.zero;
      _banked = Duration.zero;
      _last = null;
    });
  }

  void _finish() {
    _ticker.stop();
    Fx.fire(Sfx.complete);
    if (!context.reducedMotion) Celebrate.burstFrom(context, kind: CelebrationKind.lightRain, intensity: 0.6);
    setState(() => _run = _Run.finished);
    _log();
  }

  int get _completedCycles {
    final s = _state;
    return s.finished ? _cycles : s.cycle;
  }

  Future<void> _log() async {
    if (_logged) return;
    final cycles = _completedCycles;
    if (cycles <= 0) return;
    _logged = true;
    await ref.read(wellbeingServiceProvider).logBreathing(pattern: _pattern.id, cycles: cycles, duration: _elapsed);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final tx = WbTexts.of(context);
    final reduced = context.reducedMotion;
    final active = _run == _Run.running || _run == _Run.paused;
    final s = _state;
    final idle = _run == _Run.idle;
    final expansion = idle ? 0.35 : (_run == _Run.finished ? 0.0 : (reduced ? 0.6 : s.expansion));
    final phaseProgress = reduced && active
        ? ((s.phaseSeconds - s.secondsLeft + 1) / s.phaseSeconds).clamp(0.0, 1.0)
        : s.phaseProgress;

    final String headline;
    final String sub;
    switch (_run) {
      case _Run.idle:
        headline = tx.patternName(_pattern);
        sub = l.wbBreathReady(tx.patternRhythm(_pattern));
      case _Run.finished:
        headline = l.wbBreathDone;
        sub = fmt.localizeDigits(l.wbBreathDoneBody(_cycles, fmt.formatInt(_cycles)));
      case _Run.running || _Run.paused:
        headline = tx.breathPhase(s.phase);
        sub = _run == _Run.paused
            ? l.wbBreathPaused
            : fmt.localizeDigits(l.wbBreathCycle(fmt.formatInt(s.cycle + 1), fmt.formatInt(_cycles)));
    }

    return MadarScaffold(
      title: l.wbBreathTitle,
      backdropSeed: 5.2,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        MadarButton.icon(
          icon: _sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          semanticLabel: _sound ? l.wbBreathSoundOn : l.wbBreathSoundOff,
          variant: MadarButtonVariant.ghost,
          sfx: _sound ? Sfx.toggleOff : Sfx.toggleOn,
          onPressed: () {
            setState(() => _sound = !_sound);
            ref.read(wellbeingServiceProvider).updateSettings((st) => st.copyWith(breathingSound: _sound));
          },
        ),
      ],
      body: LayoutBuilder(
        builder: (context, c) {
          final ringSize = math.min(c.maxWidth - Space.gutter * 2, math.min(380.0, c.maxHeight * 0.55));
          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - Space.s - Space.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedOpacity(
                    opacity: active ? 0.35 : 1,
                    duration: context.motion(MadarMotion.short),
                    child: IgnorePointer(
                      ignoring: active,
                      child: ChoicePills<String>.single(
                        options: [
                          for (final p in BreathingPattern.all)
                            ChoiceOption(value: p.id, label: '${tx.patternName(p)} · ${tx.patternRhythm(p)}'),
                        ],
                        selected: _pattern.id,
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _pattern = BreathingPattern.byId(v);
                            if (_run == _Run.finished) _run = _Run.idle;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.l),
                  Center(
                    child: Semantics(
                      liveRegion: true,
                      label: active ? '$headline. ${fmt.formatInt(s.secondsLeft)}' : headline,
                      child: SizedBox.square(
                        dimension: ringSize,
                        child: BreathRing(
                          pattern: _pattern,
                          state: s,
                          expansion: expansion,
                          phaseProgress: phaseProgress,
                          active: active,
                          rotation: reduced ? 0 : _elapsed.inMilliseconds / 60000 * math.pi / 6,
                          center: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                headline,
                                style: text.headlineSmall?.copyWith(color: t.textPrimary),
                                textAlign: TextAlign.center,
                              ),
                              if (active)
                                Text(
                                  fmt.formatInt(s.secondsLeft),
                                  style: text.displaySmall?.copyWith(color: t.gold, fontWeight: FontWeight.w300),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.m),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: t.textSecondary),
                  ),
                  const SizedBox(height: Space.l),
                  if (!active) ...[
                    Text(l.wbBreathCycles, style: text.titleSmall, textAlign: TextAlign.center),
                    const SizedBox(height: Space.s),
                    Center(
                      child: ChoicePills<int>.single(
                        options: [
                          for (final n in WellbeingSettings.cycleChoices)
                            ChoiceOption(value: n, label: fmt.formatInt(n)),
                        ],
                        selected: _cycles,
                        onChanged: (v) {
                          if (v != null) setState(() => _cycles = v);
                        },
                      ),
                    ),
                    const SizedBox(height: Space.l),
                    Center(
                      child: MadarButton(
                        label: _run == _Run.finished ? l.wbBreathAgain : l.wbBreathStart,
                        icon: Icons.play_arrow_rounded,
                        size: MadarButtonSize.large,
                        sfx: Sfx.tap,
                        onPressed: _start,
                      ),
                    ),
                    const SizedBox(height: Space.m),
                    Text(
                      l.wbBreathGentleNote,
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: t.textTertiary),
                    ),
                  ] else
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Space.m,
                      runSpacing: Space.s,
                      children: [
                        MadarButton(
                          label: l.wbBreathStop,
                          icon: Icons.stop_rounded,
                          variant: MadarButtonVariant.ghost,
                          sfx: Sfx.back,
                          onPressed: _stop,
                        ),
                        MadarButton(
                          label: _run == _Run.paused ? l.wbBreathResume : l.wbBreathPause,
                          icon: _run == _Run.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          size: MadarButtonSize.large,
                          variant: MadarButtonVariant.secondary,
                          sfx: _run == _Run.paused ? Sfx.toggleOn : Sfx.toggleOff,
                          onPressed: _run == _Run.paused ? _resume : _pause,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The breathing astrolabe: brass ticks around a rhythm ring (one arc per
/// phase, proportional to its seconds), a luminous head travelling the
/// current phase, and a glowing plate with rete rings that opens with the
/// breath.
class BreathRing extends StatelessWidget {
  const BreathRing({
    super.key,
    required this.pattern,
    required this.state,
    required this.expansion,
    required this.phaseProgress,
    required this.active,
    required this.rotation,
    this.center,
  });

  final BreathingPattern pattern;
  final BreathState state;
  final double expansion;
  final double phaseProgress;
  final bool active;
  final double rotation;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      excluding: center == null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _BreathPlatePainter(
              expansion: expansion,
              rotation: rotation,
              glow: t.accentGlow,
              accent: t.accent,
              ring: t.metalBrass,
              gold: t.metalGold,
              dark: t.isDark,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(2),
            child: CustomPaint(
              painter: AstrolabeTicksPainter(
                color: t.metalBrass.withValues(alpha: 0.55),
                majorColor: t.metalGold,
                showNumerals: false,
                rotation: rotation,
                innerRing: true,
              ),
            ),
          ),
          CustomPaint(
            painter: _RhythmPainter(
              pattern: pattern,
              stepIndex: state.stepIndex,
              phaseProgress: active ? phaseProgress : 0,
              active: active,
              colors: {
                BreathPhase.inhale: t.accent,
                BreathPhase.holdIn: t.gold,
                BreathPhase.exhale: Color.lerp(t.info, t.accent, 0.25)!,
                BreathPhase.holdOut: t.textTertiary,
              },
              track: t.glassBorder,
              head: t.textPrimary,
              rtl: Directionality.of(context) == TextDirection.rtl,
            ),
          ),
          if (center != null) Center(child: center),
        ],
      ),
    );
  }
}

class _BreathPlatePainter extends CustomPainter {
  _BreathPlatePainter({
    required this.expansion,
    required this.rotation,
    required this.glow,
    required this.accent,
    required this.ring,
    required this.gold,
    required this.dark,
  });

  final double expansion;
  final double rotation;
  final Color glow;
  final Color accent;
  final Color ring;
  final Color gold;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final r = outer * (0.34 + 0.4 * expansion);
    // Breath glow.
    canvas.drawCircle(
      c,
      r * 1.35,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: (dark ? 0.35 : 0.22) * (0.5 + 0.5 * expansion)),
            glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.35)),
    );
    // Plate.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: dark ? 0.32 : 0.2),
            accent.withValues(alpha: dark ? 0.08 : 0.05),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Rete rings (open with the breath).
    final rete = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ring.withValues(alpha: 0.45);
    for (final k in [1.0, 0.72, 0.46]) {
      canvas.drawCircle(c, r * k, rete);
    }
    // Four brass pins on the outer rete ring, turning slowly.
    for (var i = 0; i < 4; i++) {
      final a = rotation * 2 + i * math.pi / 2;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, 2.6, Paint()..color = gold.withValues(alpha: 0.8));
    }
    // Two fine ecliptic arcs crossing the plate.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = gold.withValues(alpha: 0.35);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -r * 0.18), width: r * 1.5, height: r * 1.1), arc);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BreathPlatePainter old) =>
      old.expansion != expansion ||
      old.rotation != rotation ||
      old.glow != glow ||
      old.accent != accent ||
      old.ring != ring ||
      old.dark != dark;
}

class _RhythmPainter extends CustomPainter {
  _RhythmPainter({
    required this.pattern,
    required this.stepIndex,
    required this.phaseProgress,
    required this.active,
    required this.colors,
    required this.track,
    required this.head,
    required this.rtl,
  });

  final BreathingPattern pattern;
  final int stepIndex;
  final double phaseProgress;
  final bool active;
  final Map<BreathPhase, Color> colors;
  final Color track;
  final Color head;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide / 2 * 0.82;
    final rect = Rect.fromCircle(center: c, radius: radius);
    final total = pattern.cycleSeconds.toDouble();
    const gap = 0.05;
    // Runs clockwise from the top in LTR, counter-clockwise in RTL (the
    // reading direction).
    final dir = rtl ? -1.0 : 1.0;
    var start = -math.pi / 2;
    for (var i = 0; i < pattern.steps.length; i++) {
      final (phase, secs) = pattern.steps[i];
      final sweep = 2 * math.pi * secs / total;
      final color = colors[phase]!;
      final current = active && i == stepIndex;
      final done = active && i < stepIndex;
      canvas.drawArc(
        rect,
        start + dir * gap / 2,
        dir * (sweep - gap),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 5
          ..color = color.withValues(alpha: done ? 0.6 : (current ? 0.22 : 0.3)),
      );
      if (current) {
        final s = dir * (sweep - gap) * phaseProgress;
        canvas.drawArc(
          rect,
          start + dir * gap / 2,
          s,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 5
            ..color = color,
        );
        final a = start + dir * gap / 2 + s;
        final p = c + Offset(math.cos(a), math.sin(a)) * radius;
        canvas.drawCircle(p, 11, Paint()..color = color.withValues(alpha: 0.3));
        canvas.drawCircle(p, 5.5, Paint()..color = head);
        canvas.drawCircle(
          p,
          5.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color,
        );
      }
      start += dir * sweep;
    }
  }

  @override
  bool shouldRepaint(_RhythmPainter old) =>
      old.pattern != pattern ||
      old.stepIndex != stepIndex ||
      old.phaseProgress != phaseProgress ||
      old.active != active ||
      old.rtl != rtl ||
      old.track != track;
}
