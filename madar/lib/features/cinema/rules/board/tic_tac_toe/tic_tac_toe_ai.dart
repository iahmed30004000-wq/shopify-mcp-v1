/// Tic-tac-toe AI: exact minimax (memoised over all 3^9 boards).
///
/// * hard – perfect play; a random choice among equally optimal moves
///   (quickest win / slowest loss);
/// * medium – wins or blocks when it can, otherwise optimal half the time;
/// * easy – takes a win half the time, otherwise random.
library;

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';
import 'tic_tac_toe_rules.dart';

final Map<int, int> _memo = {};

int _key(List<int> cells) {
  var k = 0;
  for (final c in cells) {
    k = k * 3 + c;
  }
  return k;
}

/// Value for the player to move ([v] = 1 or 2): +(10 - empties … ) for a
/// win, 0 draw, negative for a loss. Faster wins score higher.
int _solve(List<int> cells, int v) {
  final key = _key(cells) * 3 + v;
  final cached = _memo[key];
  if (cached != null) return cached;
  var empties = 0;
  for (final c in cells) {
    if (c == 0) empties++;
  }
  var best = -100;
  for (var i = 0; i < 9; i++) {
    if (cells[i] != 0) continue;
    cells[i] = v;
    int score;
    if (ticTacToeLine(cells, v).isNotEmpty) {
      score = empties; // win now; more empties = sooner
    } else if (empties == 1) {
      score = 0;
    } else {
      score = -_solve(cells, 3 - v);
    }
    cells[i] = 0;
    if (score > best) best = score;
  }
  if (empties == 0) best = 0;
  _memo[key] = best;
  return best;
}

/// Minimax value of each legal move for the player to move.
Map<int, int> ticTacToeMoveValues(TicTacToeState s) {
  final cells = [...s.cells];
  final v = s.currentPlayer + 1;
  var empties = 0;
  for (final c in cells) {
    if (c == 0) empties++;
  }
  final out = <int, int>{};
  for (var i = 0; i < 9; i++) {
    if (cells[i] != 0) continue;
    cells[i] = v;
    out[i] = ticTacToeLine(cells, v).isNotEmpty ? empties : (empties == 1 ? 0 : -_solve(cells, 3 - v));
    cells[i] = 0;
  }
  return out;
}

final class TicTacToeAi implements BoardAi<TicTacToeState, TicTacToeMove> {
  const TicTacToeAi();

  @override
  TicTacToeMove chooseMove(TicTacToeState state, AiLevel level, BoardRng rng, [AiBudget budget = AiBudget.phone]) {
    final legal = ticTacToeRules.legalMoves(state);
    if (legal.isEmpty) throw StateError('no legal moves');
    final v = state.currentPlayer + 1;
    int? winningCell(int who) {
      for (final m in legal) {
        final cells = [...state.cells]..[m.cell] = who;
        if (ticTacToeLine(cells, who).isNotEmpty) return m.cell;
      }
      return null;
    }

    switch (level) {
      case AiLevel.easy:
        final win = winningCell(v);
        if (win != null && rng.nextBool()) return TicTacToeMove(win);
        return rng.pick(legal);
      case AiLevel.medium:
        final win = winningCell(v) ?? winningCell(3 - v);
        if (win != null) return TicTacToeMove(win);
        if (rng.nextBool()) return rng.pick(legal);
        return _optimal(state, rng);
      case AiLevel.hard:
        return _optimal(state, rng);
    }
  }

  TicTacToeMove _optimal(TicTacToeState state, BoardRng rng) {
    final values = ticTacToeMoveValues(state);
    final best = values.values.reduce((a, b) => a > b ? a : b);
    final options = [
      for (final e in values.entries)
        if (e.value == best) e.key,
    ];
    return TicTacToeMove(rng.pick(options));
  }
}
