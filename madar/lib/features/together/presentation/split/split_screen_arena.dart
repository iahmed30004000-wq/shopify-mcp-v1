import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/painters/painters.dart';
import '../../../../core/design/tokens.dart';
import '../../domain/play_modes.dart';

/// One half of a [SplitScreenArena], as its player sees it.
@immutable
final class SplitHalf {
  const SplitHalf({required this.participant, required this.quarterTurns, required this.size});

  /// 0 – the near / reading-start player; 1 – the far / other one.
  final int participant;

  /// Clockwise quarter turns applied to this half (2 = facing the far edge).
  final int quarterTurns;

  /// The half's size in its own (rotated) frame.
  final Size size;

  bool get rotated => quarterTurns % 4 != 0;

  @override
  bool operator ==(Object other) =>
      other is SplitHalf && other.participant == participant && other.quarterTurns == quarterTurns && other.size == size;

  @override
  int get hashCode => Object.hash(participant, quarterTurns, size);
}

enum SplitTouchPhase { down, move, up, cancel }

/// A touch in one half, in that half's own frame: (0, 0) is the top-left
/// corner as its player sees it, whichever way the half is turned.
@immutable
final class SplitTouch {
  const SplitTouch({
    required this.participant,
    required this.pointer,
    required this.phase,
    required this.position,
    required this.normalized,
    required this.timeStamp,
  });

  final int participant;
  final int pointer;
  final SplitTouchPhase phase;

  /// Clamped to the half (a finger sliding over the midline stays on the
  /// edge of its own half).
  final Offset position;

  /// [position] / half size, in 0..1.
  final Offset normalized;
  final Duration timeStamp;

  @override
  String toString() => 'SplitTouch(p$participant #$pointer ${phase.name} $position)';
}

/// The live touches of one half (pointer → position in the half's frame).
class SplitTouches extends ChangeNotifier {
  SplitTouches(this.participant);

  final int participant;
  final Map<int, Offset> _active = {};

  Map<int, Offset> get active => Map.unmodifiable(_active);

  bool get isTouched => _active.isNotEmpty;

  void _set(int pointer, Offset? position) {
    if (position == null) {
      if (_active.remove(pointer) == null) return;
    } else {
      _active[pointer] = position;
    }
    notifyListeners();
  }
}

/// Splits the screen between the two players.
///
/// * [SplitLayout.faceToFace]: top and bottom halves; the far half (player
///   1) is turned 180° so each player faces their side with the phone flat.
/// * [SplitLayout.sideBySide]: left and right halves, upright (landscape).
/// * [SplitLayout.endToEnd]: left and right halves turned towards the
///   short edges (landscape, flat, players at either end).
///
/// Every pointer belongs to the half it went down in, for its whole life:
/// both players can touch, drag and hold at the same time, and nothing one
/// does can cancel or steal the other's gesture (each half hit-tests on its
/// own; raw touches are read with a [Listener], which never enters the
/// gesture arena). Touches reach [onTouch] and [SplitScreenArena.touchesOf]
/// in the half's own frame, so a game written for "my side at the bottom"
/// works unchanged in either half.
///
/// Each half gets its own [MediaQuery]: its size, and safe-area padding only
/// on the device edges it touches, turned into its frame (the notch of the
/// top edge is the far player's bottom inset). [hudBuilder] draws over the
/// half inside that safe area.
class SplitScreenArena extends StatefulWidget {
  const SplitScreenArena({
    super.key,
    required this.halfBuilder,
    this.hudBuilder,
    this.center,
    this.layout = SplitLayout.faceToFace,
    this.onTouch,
    this.colors,
    this.dividerThickness = 3,
  });

  final Widget Function(BuildContext context, SplitHalf half) halfBuilder;
  final Widget Function(BuildContext context, SplitHalf half)? hudBuilder;

  /// Drawn on the midline, above both halves (e.g. a pause button).
  final Widget? center;
  final SplitLayout layout;
  final ValueChanged<SplitTouch>? onTouch;

  /// Tint of each participant's half edge (their player colours).
  final List<Color>? colors;
  final double dividerThickness;

  /// The touches of the half around [context].
  static SplitTouches touchesOf(BuildContext context) => _HalfScope.of(context).touches;

  /// The half around [context].
  static SplitHalf halfOf(BuildContext context) => _HalfScope.of(context).half;

  /// Key of a participant's half (tests, overlays).
  static ValueKey<String> halfKey(int participant) => ValueKey('together-split-half-$participant');

  /// Clockwise quarter turns of [participant]'s half.
  static int quarterTurnsFor(SplitLayout layout, int participant, {required bool physicalLeft}) => switch (layout) {
    SplitLayout.faceToFace => participant == 1 ? 2 : 0,
    SplitLayout.sideBySide => 0,
    // Left half: its bottom faces the left edge; right half: the right edge.
    SplitLayout.endToEnd => physicalLeft ? 1 : 3,
  };

  /// [physical] insets expressed in the frame of content turned by
  /// [quarterTurns] clockwise.
  static EdgeInsets rotateInsets(EdgeInsets physical, int quarterTurns) => switch (quarterTurns % 4) {
    1 => EdgeInsets.fromLTRB(physical.top, physical.right, physical.bottom, physical.left),
    2 => EdgeInsets.fromLTRB(physical.right, physical.bottom, physical.left, physical.top),
    3 => EdgeInsets.fromLTRB(physical.bottom, physical.left, physical.top, physical.right),
    _ => physical,
  };

  @override
  State<SplitScreenArena> createState() => _SplitScreenArenaState();
}

class _SplitScreenArenaState extends State<SplitScreenArena> {
  final List<SplitTouches> _touches = [SplitTouches(0), SplitTouches(1)];

  @override
  void dispose() {
    for (final t in _touches) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final tokens = context.tokens;
    final colors = widget.colors ?? [tokens.accent, tokens.secondary];
    final gap = widget.dividerThickness;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final pad = mq.padding;
        final viewPad = mq.viewPadding;

        Widget half(int participant, Rect rect, {required bool touchesTop, required bool touchesBottom, required bool touchesLeft, required bool touchesRight, required int turns}) {
          EdgeInsets edges(EdgeInsets p) => EdgeInsets.fromLTRB(
            touchesLeft ? p.left : 0,
            touchesTop ? p.top : 0,
            touchesRight ? p.right : 0,
            touchesBottom ? p.bottom : 0,
          );
          final odd = turns.isOdd;
          final size = odd ? Size(rect.height, rect.width) : rect.size;
          final spec = SplitHalf(participant: participant, quarterTurns: turns, size: size);
          return Positioned.fromRect(
            rect: rect,
            child: ClipRect(
              child: RotatedBox(
                key: SplitScreenArena.halfKey(participant),
                quarterTurns: turns,
                child: MediaQuery(
                  data: mq.copyWith(
                    size: size,
                    padding: SplitScreenArena.rotateInsets(edges(pad), turns),
                    viewPadding: SplitScreenArena.rotateInsets(edges(viewPad), turns),
                    viewInsets: EdgeInsets.zero,
                  ),
                  child: _HalfScope(
                    half: spec,
                    touches: _touches[participant],
                    child: _HalfTouchLayer(
                      half: spec,
                      touches: _touches[participant],
                      onTouch: widget.onTouch,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Builder(builder: (context) => widget.halfBuilder(context, spec)),
                          if (widget.hudBuilder != null)
                            SafeArea(child: Builder(builder: (context) => widget.hudBuilder!(context, spec))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final List<Widget> halves;
        final Rect divider;
        switch (widget.layout) {
          case SplitLayout.faceToFace:
            final hh = (h - gap) / 2;
            halves = [
              half(1, Rect.fromLTWH(0, 0, w, hh), touchesTop: true, touchesBottom: false, touchesLeft: true, touchesRight: true, turns: 2),
              half(0, Rect.fromLTWH(0, hh + gap, w, hh), touchesTop: false, touchesBottom: true, touchesLeft: true, touchesRight: true, turns: 0),
            ];
            divider = Rect.fromLTWH(0, hh, w, gap);
          case SplitLayout.sideBySide || SplitLayout.endToEnd:
            final hw = (w - gap) / 2;
            // Participant 0 sits at the reading start.
            final p0Left = !rtl;
            Rect rectOf(int p) => (p == 0) == p0Left ? Rect.fromLTWH(0, 0, hw, h) : Rect.fromLTWH(hw + gap, 0, hw, h);
            halves = [
              for (final p in const [0, 1])
                half(
                  p,
                  rectOf(p),
                  touchesTop: true,
                  touchesBottom: true,
                  touchesLeft: (p == 0) == p0Left,
                  touchesRight: (p == 0) != p0Left,
                  turns: SplitScreenArena.quarterTurnsFor(widget.layout, p, physicalLeft: (p == 0) == p0Left),
                ),
            ];
            divider = Rect.fromLTWH(hw, 0, gap, h);
        }

        return Stack(
          children: [
            ...halves,
            Positioned.fromRect(
              rect: divider,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _MidlinePainter(
                    horizontal: widget.layout == SplitLayout.faceToFace,
                    a: colors[1],
                    b: colors[0],
                    gold: tokens.metalGold,
                  ),
                ),
              ),
            ),
            if (widget.center != null)
              Positioned.fromRect(
                rect: Rect.fromCenter(center: divider.center, width: 64, height: 64),
                child: Center(child: widget.center),
              ),
          ],
        );
      },
    );
  }
}

class _HalfScope extends InheritedWidget {
  const _HalfScope({required this.half, required this.touches, required super.child});

  final SplitHalf half;
  final SplitTouches touches;

  static _HalfScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_HalfScope>();
    assert(scope != null, 'not inside a SplitScreenArena half');
    return scope!;
  }

  @override
  bool updateShouldNotify(_HalfScope oldWidget) => oldWidget.half != half || oldWidget.touches != touches;
}

/// Reads the raw pointers of one half (never in the gesture arena, so it
/// cannot steal or be stolen from) and reports them in the half's frame.
class _HalfTouchLayer extends StatelessWidget {
  const _HalfTouchLayer({required this.half, required this.touches, required this.onTouch, required this.child});

  final SplitHalf half;
  final SplitTouches touches;
  final ValueChanged<SplitTouch>? onTouch;
  final Widget child;

  void _report(PointerEvent e, SplitTouchPhase phase) {
    final size = half.size;
    final p = Offset(
      e.localPosition.dx.clamp(0.0, math.max(0.0, size.width)),
      e.localPosition.dy.clamp(0.0, math.max(0.0, size.height)),
    );
    touches._set(e.pointer, phase == SplitTouchPhase.down || phase == SplitTouchPhase.move ? p : null);
    onTouch?.call(
      SplitTouch(
        participant: half.participant,
        pointer: e.pointer,
        phase: phase,
        position: p,
        normalized: Offset(
          size.width <= 0 ? 0 : p.dx / size.width,
          size.height <= 0 ? 0 : p.dy / size.height,
        ),
        timeStamp: e.timeStamp,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (e) => _report(e, SplitTouchPhase.down),
    onPointerMove: (e) => _report(e, SplitTouchPhase.move),
    onPointerUp: (e) => _report(e, SplitTouchPhase.up),
    onPointerCancel: (e) => _report(e, SplitTouchPhase.cancel),
    child: child,
  );
}

class _MidlinePainter extends CustomPainter {
  _MidlinePainter({required this.horizontal, required this.a, required this.b, required this.gold});

  final bool horizontal;
  final Color a;
  final Color b;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: horizontal ? Alignment.topCenter : AlignmentDirectional.centerStart.resolve(TextDirection.ltr),
      end: horizontal ? Alignment.bottomCenter : Alignment.centerRight,
      colors: [a, gold, b],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    final c = rect.center;
    final r = math.max(size.shortestSide * 3.2, 9.0);
    canvas.drawCircle(
      c,
      r * 1.6,
      Paint()
        ..color = gold.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r),
    );
    canvas.drawPath(
      IslamicGeometry.starPath(center: c, radius: r, points: 8),
      Paint()..color = gold,
    );
  }

  @override
  bool shouldRepaint(_MidlinePainter old) =>
      old.horizontal != horizontal || old.a != a || old.b != b || old.gold != gold;
}

/// Game-UI helper: a pointer-friendly region inside a half that reports
/// drags in the half's frame (built on [SplitScreenArena.touchesOf]).
class SplitTouchBuilder extends StatelessWidget {
  const SplitTouchBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, Map<int, Offset> touches) builder;

  @override
  Widget build(BuildContext context) {
    final touches = SplitScreenArena.touchesOf(context);
    return ListenableBuilder(listenable: touches, builder: (context, _) => builder(context, touches.active));
  }
}
