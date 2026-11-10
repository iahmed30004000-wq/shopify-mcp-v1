import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

import 'support.dart';

void main() {
  group('layouts', () {
    test('sizes and the turtle structure', () {
      expect(MahjongLayout.of(MahjongLayoutId.turtle).length, 144);
      expect(MahjongLayout.of(MahjongLayoutId.pyramid).length, 132);
      expect(MahjongLayout.of(MahjongLayoutId.twinMinarets).length, 78);
      final t = MahjongLayout.of(MahjongLayoutId.turtle);
      final all = List<bool>.filled(144, true);
      expect([for (var i = 0; i < 144; i++) if (t.isFree(i, all)) i].length, 35);
      final top = t.slots.indexWhere((s) => s.z == 4);
      expect(t.isFree(top, all), isTrue);
      final under = [for (var i = 0; i < 144; i++) if (t.slots[i].z == 3) i];
      expect(under.length, 4);
      for (final u in under) {
        expect(t.above(u), [top]);
        expect(t.isFree(u, all), isFalse, reason: 'covered');
      }
      // A tile flanked on both sides is blocked; opening one side frees it.
      final leftEnd = t.slots.indexOf(const MahjongSlot(0, 7, 0));
      final flanked = t.slots.indexOf(const MahjongSlot(2, 6, 0));
      expect(t.isFree(flanked, all), isFalse);
      final opened = List<bool>.from(all)..[leftEnd] = false;
      expect(t.isFree(flanked, opened), isTrue);
    });

    test('no two slots of a layout overlap', () {
      for (final id in MahjongLayoutId.values) {
        final l = MahjongLayout.of(id);
        for (var i = 0; i < l.length; i++) {
          for (var j = i + 1; j < l.length; j++) {
            final a = l.slots[i], b = l.slots[j];
            final overlap = a.z == b.z && (a.x2 - b.x2).abs() < 2 && (a.y2 - b.y2).abs() < 2;
            expect(overlap, isFalse, reason: '$id $a $b');
          }
        }
      }
    });
  });

  test('matching: equal faces, any flower with any flower, any season with any season', () {
    expect(MahjongFaces.matches(5, 5), isTrue);
    expect(MahjongFaces.matches(5, 6), isFalse);
    expect(MahjongFaces.matches(34, 37), isTrue);
    expect(MahjongFaces.matches(38, 41), isTrue);
    expect(MahjongFaces.matches(37, 38), isFalse);
    expect(MahjongFaces.fullPairs().length, 72);
  });

  test('deals are solvable by construction on every layout (replayed)', () {
    for (final id in MahjongLayoutId.values) {
      final layout = MahjongLayout.of(id);
      for (var seed = 0; seed < 25; seed++) {
        final rng = SeededRng(seed);
        final pairs = MahjongFaces.fullPairs();
        rng.shuffle(pairs);
        pairs.removeRange(layout.length ~/ 2, pairs.length);
        final deal = MahjongDealer.construct(layout, List<int>.generate(layout.length, (i) => i), pairs, rng)!;
        final present = List<bool>.filled(layout.length, true);
        for (final (a, b) in deal.order) {
          expect(layout.isFree(a, present) && layout.isFree(b, present), isTrue, reason: '$id seed $seed');
          expect(MahjongFaces.matches(deal.faces[a], deal.faces[b]), isTrue);
          present[a] = false;
          present[b] = false;
        }
        expect(present.contains(true), isFalse);
      }
    }
  });

  test('game deals: every group count is even, and the performance budget', () {
    final times = <int>[];
    for (var seed = 0; seed < 20; seed++) {
      late MahjongGame g;
      times.add(timeMs(() => g = MahjongGame(MahjongConfig(seed: seed))));
      final counts = <int, int>{};
      for (final f in g.state.faces) {
        counts.update(MahjongFaces.group(f), (v) => v + 1, ifAbsent: () => 1);
      }
      expect(counts.values.every((c) => c.isEven), isTrue);
      expect(g.availableMoves(), isNotEmpty);
    }
    // Measured ≈ 3 ms average, < 50 ms worst on the development container.
    expect(median(times), lessThan(200));
  });

  test('illegal removals are rejected', () {
    final g = MahjongGame(const MahjongConfig(seed: 1));
    final layout = g.layout;
    final covered = [for (var i = 0; i < layout.length; i++) if (layout.slots[i].z == 3) i].first;
    final free = [for (var i = 0; i < layout.length; i++) if (g.isFree(i)) i];
    expect(g.apply(MahjongAction.remove(covered, free.first)), isFalse);
    expect(g.apply(MahjongAction.remove(free.first, free.first)), isFalse);
    final mismatch = [
      for (final a in free)
        for (final b in free)
          if (a < b && !MahjongFaces.matches(g.state.faces[a], g.state.faces[b])) (a, b),
    ].first;
    expect(g.apply(MahjongAction.remove(mismatch.$1, mismatch.$2)), isFalse);
    final m = g.availableMoves().first;
    expect(g.apply(MahjongAction.remove(m.$1, m.$2)), isTrue);
    expect(g.state.remaining, 142);
  });

  test('hints clear whole deals on every layout', () {
    for (final id in MahjongLayoutId.values) {
      for (var seed = 0; seed < 3; seed++) {
        final g = MahjongGame(MahjongConfig(layout: id, seed: seed, shuffles: 0));
        followHints(g);
        expect(g.isSolved, isTrue, reason: '$id seed $seed');
      }
    }
  });

  test('the search solver clears turtle deals without the dealer plan', () {
    for (var seed = 0; seed < 4; seed++) {
      final g = MahjongGame(MahjongConfig(seed: seed));
      final path = MahjongDealer.solve(g.layout, g.state.faces, g.state.present, nodeBudget: 50000);
      expect(path, isNotNull, reason: 'seed $seed');
      for (final (a, b) in path!) {
        expect(g.apply(MahjongAction.remove(a, b)), isTrue);
      }
      expect(g.isSolved, isTrue);
    }
  });

  test('after leaving the plan, hints still offer legal moves', () {
    final g = MahjongGame(const MahjongConfig(seed: 2));
    // Take a legal pair that is not one of the plan's pairs, if any.
    final plan = g.state.plan;
    final pairs = {for (var k = 0; k < plan.length; k += 2) (plan[k], plan[k + 1])};
    final off = g.availableMoves().where((m) => !pairs.contains(m) && !pairs.contains((m.$2, m.$1))).toList();
    if (off.isNotEmpty) g.apply(MahjongAction.remove(off.first.$1, off.first.$2));
    for (var i = 0; i < 10 && !g.isOver; i++) {
      final h = g.hint()!;
      expect(g.apply(h.action), isTrue);
    }
  });

  test('shuffle keeps tiles and positions, stays solvable, and is limited', () {
    final g = MahjongGame(const MahjongConfig(seed: 3, shuffles: 2));
    for (var i = 0; i < 10; i++) {
      final m = g.availableMoves().first;
      g.apply(MahjongAction.remove(m.$1, m.$2));
    }
    final before = [for (var i = 0; i < g.layout.length; i++) if (g.state.present[i]) g.state.faces[i]]..sort();
    final present = g.state.present;
    expect(g.apply(const MahjongAction.shuffle()), isTrue);
    final after = [for (var i = 0; i < g.layout.length; i++) if (g.state.present[i]) g.state.faces[i]]..sort();
    expect(after, before);
    expect(g.state.present, present);
    expect(g.state.shufflesLeft, 1);
    followHints(g);
    expect(g.isSolved, isTrue);
    final none = MahjongGame(const MahjongConfig(seed: 3, shuffles: 0));
    expect(none.apply(const MahjongAction.shuffle()), isFalse);
  });

  test('stuck detection and game over', () {
    // Remove pairs greedily from the worst end until stuck (or solved).
    for (var seed = 0; seed < 10; seed++) {
      final g = MahjongGame(MahjongConfig(seed: seed, shuffles: 0));
      while (!g.isOver) {
        final ms = g.availableMoves();
        final m = ms.last;
        g.apply(MahjongAction.remove(m.$1, m.$2));
      }
      expect(g.isSolved || g.isStuck, isTrue);
      if (!g.isSolved) expect(g.hint(), isNull, reason: 'no shuffles left');
    }
  });

  test('random play, undo, replay and JSON', () {
    final g = MahjongGame(const MahjongConfig(layout: MahjongLayoutId.pyramid, seed: 8));
    final rng = SeededRng(8);
    final log = <Map<String, Object?>>[];
    for (var i = 0; i < 200 && !g.isOver; i++) {
      final ms = g.availableMoves();
      final MahjongAction a = ms.isEmpty
          ? const MahjongAction.shuffle()
          : MahjongAction.remove(rng.pick(ms).$1, rng.pick(ms).$2);
      if (g.apply(a)) log.add(roundTripJson(a.toJson()));
      if (rng.nextInt(10) == 0 && g.undo()) log.clear();
    }
    expectJsonRoundTrip(g);
    final h = g.toJson();
    final restored = MahjongGame.fromJson(h);
    expect(restored.state.remaining, g.state.remaining);
  });
}
