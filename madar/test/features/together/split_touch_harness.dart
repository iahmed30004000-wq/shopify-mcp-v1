// Test harness for split-screen games: simultaneous multi-touch in both
// halves of a SplitScreenArena, addressed in each half's own frame.
//
//   final harness = SplitTouchHarness(tester);
//   await harness.simultaneousDrags([
//     SplitPath(0, const Offset(0.2, 0.8), const Offset(0.8, 0.8)),
//     SplitPath(1, const Offset(0.5, 0.9), const Offset(0.5, 0.2)),
//   ]);
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/together/together.dart';

/// A finger's path inside one half, in normalised half coordinates
/// (0..1, as that half's player sees it).
class SplitPath {
  const SplitPath(this.participant, this.from, this.to);

  final int participant;
  final Offset from;
  final Offset to;
}

class SplitTouchHarness {
  SplitTouchHarness(this.tester);

  final WidgetTester tester;
  int _nextPointer = 20;

  RenderBox _half(int participant) =>
      tester.renderObject<RenderBox>(find.byKey(SplitScreenArena.halfKey(participant)));

  /// Global position of the normalised point [n] of [participant]'s half,
  /// through the half's rotation.
  Offset globalIn(int participant, Offset n) {
    final box = _half(participant);
    // The RotatedBox's child is laid out in the half's own frame.
    final child = (box as RenderRotatedBox).child!;
    return child.localToGlobal(Offset(n.dx * child.size.width, n.dy * child.size.height));
  }

  /// Presses every path at once, moves all fingers together in [steps]
  /// interleaved steps, then lifts them together.
  Future<void> simultaneousDrags(List<SplitPath> paths, {int steps = 8}) async {
    final gestures = <TestGesture>[];
    for (final p in paths) {
      gestures.add(
        await tester.startGesture(globalIn(p.participant, p.from), pointer: _nextPointer++, kind: PointerDeviceKind.touch),
      );
    }
    await tester.pump(const Duration(milliseconds: 16));
    for (var s = 1; s <= steps; s++) {
      for (var i = 0; i < paths.length; i++) {
        final p = paths[i];
        final n = Offset.lerp(p.from, p.to, s / steps)!;
        await gestures[i].moveTo(globalIn(p.participant, n));
      }
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (final g in gestures) {
      await g.up();
    }
    await tester.pump();
  }

  /// Taps both points at the same moment (down, down, up, up).
  Future<void> simultaneousTaps(List<(int participant, Offset at)> taps) async {
    final gestures = <TestGesture>[];
    for (final (p, n) in taps) {
      gestures.add(await tester.startGesture(globalIn(p, n), pointer: _nextPointer++));
    }
    await tester.pump(const Duration(milliseconds: 30));
    for (final g in gestures) {
      await g.up();
    }
    await tester.pump(const Duration(milliseconds: 30));
  }
}
