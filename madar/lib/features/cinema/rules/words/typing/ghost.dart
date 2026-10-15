/// Ghost opponents for the Typing Race: deterministic "typists" at three
/// speeds whose progress is a pure function of time and seed.
///
/// A ghost types at its nominal net speed with per-word rhythm variation
/// (±15 %) and short pauses between words, so two ghosts with different
/// seeds race visibly apart while finishing near their nominal time.
library;

import '../core/words_rng.dart';
import 'typing_text.dart';

/// Ghost speeds (net words per minute, 5 units per word).
enum GhostSpeed {
  /// A calm typist.
  slow(20),

  /// A regular typist.
  steady(35),

  /// A fast typist.
  swift(55);

  const GhostSpeed(this.wpm);

  /// Nominal net WPM.
  final int wpm;
}

/// A ghost for one passage.
final class GhostOpponent {
  /// Creates a ghost typing [target] at [speed].
  GhostOpponent({required this.speed, required TypingTarget target, required int seed}) : length = target.length {
    final rng = WordsRng(WordsRng.mix([seed, speed.wpm, target.length]));
    final msPerUnit = 60000.0 / (speed.wpm * 5);
    final raw = <double>[];
    var t = 0.0;
    var rhythm = 0.85 + rng.nextDouble() * 0.3;
    for (var i = 0; i < target.length; i++) {
      final isSpace = target.units[i] == ' ';
      if (isSpace) rhythm = 0.85 + rng.nextDouble() * 0.3;
      t += msPerUnit * rhythm * (isSpace ? 1.0 + rng.nextDouble() * 0.6 : 1.0);
      raw.add(t);
    }
    // Normalise so the finish matches the nominal speed exactly.
    final nominal = msPerUnit * target.length;
    final k = raw.isEmpty ? 1.0 : nominal / raw.last;
    _times = [for (final v in raw) (v * k).round()];
  }

  /// Speed.
  final GhostSpeed speed;

  /// Units in the passage.
  final int length;

  late final List<int> _times;

  /// Time (ms from the start) at which the ghost finishes.
  int get finishMs => _times.isEmpty ? 0 : _times.last;

  /// Units typed after [ms] milliseconds.
  int unitsAt(int ms) {
    var lo = 0, hi = _times.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_times[mid] <= ms) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Progress 0–1 after [ms] milliseconds.
  double progressAt(int ms) => length == 0 ? 1 : unitsAt(ms) / length;
}
