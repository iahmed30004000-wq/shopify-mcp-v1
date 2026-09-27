import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../i18n/gen/app_localizations.dart';
import '../motion/motion.dart';
import '../sound/sound_api.dart';
import 'actions.dart';
import 'src/glass.dart';
import 'src/pressable.dart';

/// Shows a glass undo toast rising from the bottom of the screen with a
/// countdown ring and an Undo button.
///
/// Toasts stack gracefully: a newer toast slides in front and older ones
/// recede behind it (each keeps its own countdown). The overlay is resolved
/// synchronously, so [context] may unmount right after this call (e.g. a
/// deleted row).
///
/// Completes with `true` when the user tapped Undo (after [UndoableAction.undo]
/// finished), `false` when the toast expired or was swiped away.
Future<bool> showUndoToast(BuildContext context, UndoableAction action, {Duration? duration}) {
  return UndoToast.show(Overlay.of(context, rootOverlay: true), action, duration: duration);
}

/// Undo toast host (one per root overlay).
abstract final class UndoToast {
  static const defaultDuration = Duration(seconds: 5);

  /// Extra space kept free at the bottom (e.g. the app shell's navigation
  /// bar). Set once by the shell.
  static double bottomInset = 0;

  /// Max toasts visible at once (older ones beyond this still count down).
  static const int maxVisible = 3;

  static final Expando<_ToastHost> _hosts = Expando('undoToastHosts');

  static Future<bool> show(OverlayState overlay, UndoableAction action, {Duration? duration}) {
    final host = _hosts[overlay] ??= _ToastHost(overlay);
    return host.add(action, duration ?? defaultDuration);
  }

  /// Dismisses every toast on [overlay] (e.g. when the screen that owns the
  /// actions is torn down). Pending futures complete with `false`.
  static void dismissAll(OverlayState overlay) => _hosts[overlay]?.dismissAll();
}

class _ToastData {
  _ToastData(this.id, this.action, this.duration);
  final int id;
  final UndoableAction action;
  final Duration duration;
  final Completer<bool> completer = Completer<bool>();
  bool leaving = false;
}

class _ToastHost {
  _ToastHost(this.overlay);

  final OverlayState overlay;
  final ValueNotifier<List<_ToastData>> toasts = ValueNotifier(const []);
  OverlayEntry? _entry;
  int _nextId = 0;

  Future<bool> add(UndoableAction action, Duration duration) {
    final data = _ToastData(_nextId++, action, duration);
    toasts.value = [...toasts.value, data];
    if (_entry == null) {
      _entry = OverlayEntry(builder: (context) => _ToastStack(host: this));
      overlay.insert(_entry!);
    }
    return data.completer.future;
  }

  void finish(_ToastData data, bool undone) {
    if (!data.completer.isCompleted) data.completer.complete(undone);
  }

  void remove(_ToastData data) {
    finish(data, false);
    toasts.value = [...toasts.value.where((t) => t.id != data.id)];
    if (toasts.value.isEmpty) {
      _entry?.remove();
      _entry?.dispose();
      _entry = null;
    }
  }

  void dismissAll() {
    for (final t in toasts.value) {
      finish(t, false);
    }
    toasts.value = const [];
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }
}

class _ToastStack extends StatelessWidget {
  const _ToastStack({required this.host});

  final _ToastHost host;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottom = math.max(mq.viewInsets.bottom, mq.viewPadding.bottom) + Space.l + UndoToast.bottomInset;
    return Positioned(
      left: Space.gutter,
      right: Space.gutter,
      bottom: bottom,
      // The root overlay sits above every Material: give the toast the
      // theme's text defaults (no fallback "missing Material" underline).
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ValueListenableBuilder<List<_ToastData>>(
              valueListenable: host.toasts,
              builder: (context, toasts, _) {
                final live = toasts.where((t) => !t.leaving).toList();
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    for (final t in toasts)
                      _ToastCard(
                        key: ValueKey(t.id),
                        data: t,
                        host: host,
                        depth: t.leaving ? 0 : live.length - 1 - live.indexOf(t),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({super.key, required this.data, required this.host, required this.depth});

  final _ToastData data;
  final _ToastHost host;

  /// 0 = front-most.
  final int depth;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController.unbounded(vsync: this);
  late final AnimationController _countdown;
  late final AnimationController _exit = AnimationController(vsync: this);
  double _dragY = 0;
  bool _undone = false;
  bool _busy = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(vsync: this, duration: widget.data.duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _leave();
      });
    _exit.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.host.remove(widget.data);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Screen-reader users need longer to reach the button.
    if (MediaQuery.accessibleNavigationOf(context)) {
      _countdown.duration = widget.data.duration * 3;
    }
    if (context.reducedMotion) {
      _enter.value = 1;
    } else {
      _enter.value = 0;
      _enter.animateWith(SpringSimulation(MadarMotion.bouncy, 0, 1, 0));
    }
    _countdown.forward();
  }

  void _leave({Duration? delay}) {
    if (widget.data.leaving) return;
    widget.data.leaving = true;
    _countdown.stop();
    final base = context.motion(MadarMotion.short);
    final pre = delay ?? Duration.zero;
    _exit.duration = base + pre;
    _exitStart = pre.inMicroseconds / (_exit.duration!.inMicroseconds);
    // Rebuild siblings so the next toast comes forward.
    widget.host.toasts.value = [...widget.host.toasts.value];
    _exit.forward(from: 0);
  }

  double _exitStart = 0;

  Future<void> _undo() async {
    if (_busy || widget.data.leaving) return;
    _busy = true;
    _countdown.stop();
    Fx.fire(Sfx.undo);
    try {
      await widget.data.action.undo();
      if (!mounted) {
        widget.host.finish(widget.data, true);
        return;
      }
      widget.host.finish(widget.data, true);
      setState(() => _undone = true);
      _leave(delay: context.reducedMotion ? Duration.zero : const Duration(milliseconds: 650));
    } catch (_) {
      Fx.fire(Sfx.error);
      _busy = false;
      if (mounted && !widget.data.leaving) _countdown.forward();
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _dragY = math.max(-12, _dragY + d.delta.dy));
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dragY > 36 || d.velocity.pixelsPerSecond.dy > 500) {
      Fx.fire(Sfx.swipe);
      _leave();
    } else {
      setState(() => _dragY = 0);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _countdown.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final depth = widget.depth;
    final hidden = depth >= UndoToast.maxVisible;
    final front = depth == 0;
    final motion = context.motion(MadarMotion.medium);

    final card = _ToastBody(
      label: _undone ? l10n.interactionUndone : widget.data.action.label,
      undone: _undone,
      countdown: _countdown,
      interactive: front && !_undone,
      onUndo: _undo,
      blur: front,
    );

    Widget body = Listener(
      onPointerDown: (_) {
        if (front && !widget.data.leaving && !_busy) _countdown.stop();
      },
      onPointerUp: (_) {
        if (!widget.data.leaving && !_busy) _countdown.forward();
      },
      onPointerCancel: (_) {
        if (!widget.data.leaving && !_busy) _countdown.forward();
      },
      child: GestureDetector(
        onVerticalDragUpdate: front ? _onDragUpdate : null,
        onVerticalDragEnd: front ? _onDragEnd : null,
        child: card,
      ),
    );

    // One announced node per toast (label + remaining time); the Undo button
    // is its own node so screen readers can reach it directly.
    body = Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: front,
      label: _undone ? l10n.interactionUndone : widget.data.action.label,
      hint: _undone
          ? null
          : l10n.interactionUndoAvailable(_countdown.duration?.inSeconds ?? widget.data.duration.inSeconds),
      child: body,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _exit]),
      builder: (context, child) {
        final e = _enter.value;
        final x = _exit.value <= _exitStart ? 0.0 : ((_exit.value - _exitStart) / (1 - _exitStart)).clamp(0.0, 1.0);
        final exitCurve = MadarMotion.accelerate.transform(x);
        final rise = (1 - e) * 90 + exitCurve * 70 + _dragY;
        final opacity = (e.clamp(0.0, 1.0) * (1 - exitCurve)).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, rise),
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: AnimatedSlide(
        duration: motion,
        curve: MadarMotion.emphasized,
        offset: Offset(0, hidden ? -0.36 : -0.16 * depth),
        child: AnimatedScale(
          duration: motion,
          curve: MadarMotion.emphasized,
          scale: 1 - 0.05 * math.min(depth, UndoToast.maxVisible),
          child: AnimatedOpacity(
            duration: motion,
            opacity: hidden ? 0 : (1 - 0.3 * depth).clamp(0.0, 1.0),
            // Toasts behind the front one are decoration until they return.
            child: IgnorePointer(
              ignoring: !front,
              child: ExcludeSemantics(excluding: !front, child: body),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastBody extends StatelessWidget {
  const _ToastBody({
    required this.label,
    required this.undone,
    required this.countdown,
    required this.interactive,
    required this.onUndo,
    required this.blur,
  });

  final String label;
  final bool undone;
  final Animation<double> countdown;
  final bool interactive;
  final VoidCallback onUndo;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(t.radiusXL);
    final motion = context.motion(MadarMotion.short);
    return InteractionGlass(
      borderRadius: radius,
      blur: blur,
      dense: true,
      glowColor: t.glassShadow,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.s, Space.s, Space.s),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            SizedBox.square(
              dimension: 40,
              child: AnimatedSwitcher(
                duration: motion,
                transitionBuilder: (child, a) => ScaleTransition(
                  scale: a,
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: undone
                    ? Icon(Icons.check_rounded, key: const ValueKey('done'), color: t.success, size: 22)
                    : ExcludeSemantics(
                        key: const ValueKey('ring'),
                        child: _CountdownRing(progress: countdown),
                      ),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: AnimatedSwitcher(
                duration: motion,
                layoutBuilder: (current, previous) =>
                    Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                // Announced by the toast's own semantics node.
                child: ExcludeSemantics(
                  key: ValueKey(label),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.s),
            AnimatedOpacity(
              duration: motion,
              opacity: undone ? 0 : 1,
              child: KitPressable(
                onTap: interactive ? onUndo : null,
                sfx: null,
                semanticLabel: l10n.actionUndo,
                excludeSemantics: true,
                child: Container(
                  height: 40,
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
                  decoration: BoxDecoration(
                    color: t.accentSoft,
                    borderRadius: BorderRadius.circular(t.radiusXL),
                    border: Border.all(color: t.accent.withValues(alpha: 0.45), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.undo_rounded, size: 18, color: t.accent),
                      const SizedBox(width: Space.xs),
                      Text(l10n.actionUndo, style: text.labelLarge?.copyWith(color: t.accent)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Depleting ring with the remaining whole seconds in its centre.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final controller = progress as AnimationController;
          final total = controller.duration ?? UndoToast.defaultDuration;
          final remaining = (1 - progress.value) * total.inMilliseconds / 1000;
          final seconds = remaining.ceil().clamp(0, 999);
          return CustomPaint(
            painter: CountdownRingPainter(
              remaining: 1 - progress.value,
              track: t.glassBorder,
              arc: t.accent,
              glow: t.accentGlow,
            ),
            child: Center(
              child: Text('$seconds', style: MadarTypography.numerals(t, size: 13, color: t.textPrimary)),
            ),
          );
        },
      ),
    );
  }
}

/// Paints the countdown ring (public for tests / reuse).
class CountdownRingPainter extends CustomPainter {
  const CountdownRingPainter({required this.remaining, required this.track, required this.arc, required this.glow});

  /// 1 → 0 as time runs out.
  final double remaining;
  final Color track, arc, glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 3;
    if (r <= 0) return;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = track,
    );
    final sweep = 2 * math.pi * remaining.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = arc,
    );
    final end = -math.pi / 2 + sweep;
    final tip = c + Offset(math.cos(end), math.sin(end)) * r;
    canvas.drawCircle(
      tip,
      3.2,
      Paint()
        ..color = glow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(tip, 1.6, Paint()..color = arc);
  }

  @override
  bool shouldRepaint(CountdownRingPainter old) =>
      old.remaining != remaining || old.track != track || old.arc != arc || old.glow != glow;
}
