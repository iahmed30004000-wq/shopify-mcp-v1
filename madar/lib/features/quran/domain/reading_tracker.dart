import 'dart:math' as math;

import 'package:meta/meta.dart';

/// What one reading session amounted to.
@immutable
class ReadingSummary {
  const ReadingSummary({required this.startedAt, required this.endedAt, required this.seconds, required this.seen});

  final DateTime startedAt;
  final DateTime endedAt;

  /// Real reading time: gaps longer than the idle timeout are not counted.
  final int seconds;

  /// Absolute indices of the ayat that stayed on screen long enough to be
  /// read.
  final Set<int> seen;

  int get firstIndex => seen.reduce(math.min);
  int get lastIndex => seen.reduce(math.max);
}

/// Counts only real reading: time between signs of life (page turns,
/// scrolling, taps) up to [idleTimeout], stopped while the app is in the
/// background; an ayah counts as read once it stayed on screen for
/// [minDwell]. Pure logic – the caller supplies the clock.
class ReadingTracker {
  ReadingTracker({
    this.idleTimeout = const Duration(minutes: 4),
    this.minDwell = const Duration(seconds: 6),
    this.minSeconds = 30,
  });

  /// A longer silence means the reader put the phone down.
  final Duration idleTimeout;

  /// How long an ayah must stay visible to count as read.
  final Duration minDwell;

  /// A session shorter than this is not worth recording.
  final int minSeconds;

  DateTime? _startedAt;
  DateTime? _lastEvent;
  bool _paused = false;
  int _milliseconds = 0;
  final Set<int> _seen = {};
  Set<int> _visible = {};
  DateTime? _visibleSince;

  bool get isActive => _startedAt != null && !_paused;
  int get seconds => _milliseconds ~/ 1000;
  Set<int> get seen => Set.unmodifiable(_seen);

  void _account(DateTime now) {
    final last = _lastEvent;
    if (last != null && !_paused) {
      final gap = now.difference(last);
      if (!gap.isNegative && gap <= idleTimeout) _milliseconds += gap.inMilliseconds;
    }
    _lastEvent = now;
  }

  void _settleVisible(DateTime now, {bool resetSince = true}) {
    final since = _visibleSince;
    if (since != null && !_paused && now.difference(since) >= minDwell) _seen.addAll(_visible);
    if (resetSince) _visibleSince = now;
  }

  /// Any sign of life (scroll, tap, page turn).
  void activity(DateTime now) {
    _startedAt ??= now;
    _account(now);
  }

  /// The ayat now on screen (replaces the previous set).
  void show(Iterable<int> ayat, DateTime now) {
    _startedAt ??= now;
    _account(now);
    final next = ayat.toSet();
    if (next.length == _visible.length && next.containsAll(_visible)) return;
    _settleVisible(now);
    _visible = next;
  }

  /// The app went to the background (or the reader was covered).
  void pause(DateTime now) {
    if (_paused) return;
    _account(now);
    _settleVisible(now);
    _paused = true;
  }

  void resume(DateTime now) {
    if (!_paused) return;
    _paused = false;
    _lastEvent = now;
    _visibleSince = now;
  }

  /// Ends the session: returns its summary when it holds real reading
  /// ([minSeconds] and at least one ayah), and starts afresh.
  ReadingSummary? flush(DateTime now) {
    if (_startedAt == null) return null;
    _account(now);
    _settleVisible(now);
    final summary = seconds >= minSeconds && _seen.isNotEmpty
        ? ReadingSummary(startedAt: _startedAt!, endedAt: now, seconds: seconds, seen: Set.of(_seen))
        : null;
    _startedAt = _paused ? null : now;
    _milliseconds = 0;
    _seen.clear();
    _visibleSince = now;
    return summary;
  }
}
