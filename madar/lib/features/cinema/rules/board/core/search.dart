/// Search-budget bookkeeping shared by the AIs.
library;

import 'game_types.dart';

/// Thrown inside a search to unwind when the budget is exhausted.
final class SearchAborted implements Exception {
  const SearchAborted();
}

/// Counts nodes and wall-clock time against an [AiBudget].
final class SearchClock {
  SearchClock(AiBudget budget) : maxNodes = budget.maxNodes, maxMicros = budget.maxTime?.inMicroseconds {
    if (maxMicros != null) _watch.start();
  }

  final int? maxNodes;
  final int? maxMicros;
  final Stopwatch _watch = Stopwatch();
  int nodes = 0;
  bool _stopped = false;

  /// Whether a limit has been reached (sticky).
  bool get stopped => _stopped;

  /// Counts one node; returns true when the budget is exhausted.
  bool tick() {
    nodes++;
    if (_stopped) return true;
    if (maxNodes != null && nodes >= maxNodes!) return _stopped = true;
    if (maxMicros != null && (nodes & 127) == 0 && _watch.elapsedMicroseconds >= maxMicros!) {
      return _stopped = true;
    }
    return false;
  }

  /// Re-checks the time without counting a node.
  bool checkTime() {
    if (_stopped) return true;
    if (maxMicros != null && _watch.elapsedMicroseconds >= maxMicros!) return _stopped = true;
    if (maxNodes != null && nodes >= maxNodes!) return _stopped = true;
    return false;
  }

  /// Fraction of the time budget used (0 when unlimited).
  double get timeFraction => maxMicros == null || maxMicros == 0 ? 0 : _watch.elapsedMicroseconds / maxMicros!;
}
