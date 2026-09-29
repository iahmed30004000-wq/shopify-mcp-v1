import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';

/// One listening session, ready to be logged.
@immutable
class ListeningSummary {
  const ListeningSummary({
    required this.startedAt,
    required this.endedAt,
    required this.listened,
    required this.first,
    required this.last,
    required this.ayat,
    required this.reciterId,
  });

  final DateTime startedAt;
  final DateTime endedAt;

  /// Time audio was actually playing (pauses, buffering and gaps excluded).
  final Duration listened;

  /// Lowest and highest ayah heard.
  final AyahRef first;
  final AyahRef last;

  /// Distinct ayat heard.
  final int ayat;
  final String reciterId;

  @override
  String toString() => 'ListeningSummary($first-$last, $ayat ayat, ${listened.inSeconds}s, $reciterId)';
}

/// Accumulates real listening time and the ayat heard between flushes.
/// Pure: the player feeds it transitions with timestamps.
class ListeningTracker {
  ListeningTracker({this.minimum = const Duration(seconds: 15)});

  /// Sessions shorter than this are dropped (a tap to preview).
  final Duration minimum;

  DateTime? _startedAt;
  DateTime? _since;
  DateTime? _lastEvent;
  Duration _listened = Duration.zero;
  final Set<AyahRef> _heard = {};
  String? _reciterId;

  bool get isEmpty => _startedAt == null;
  Duration listenedAt(DateTime now) => _listened + (_since == null ? Duration.zero : now.difference(_since!));

  /// Audio started (true) or stopped (false) sounding at [at].
  void setAudible(bool audible, DateTime at) {
    _lastEvent = at;
    if (audible) {
      _startedAt ??= at;
      _since ??= at;
    } else if (_since != null) {
      final d = at.difference(_since!);
      if (!d.isNegative) _listened += d;
      _since = null;
    }
  }

  /// A recitation of [ayah] began (by [reciterId]).
  void heard(AyahRef ayah, String reciterId, DateTime at) {
    _startedAt ??= at;
    _reciterId ??= reciterId;
    _heard.add(ayah);
  }

  /// Ends the session at [at]: its summary when it is long enough (null
  /// otherwise), and a fresh tracker state either way.
  ListeningSummary? flush(DateTime at) {
    setAudible(false, at);
    final started = _startedAt;
    final listened = _listened;
    final heard = _heard.toList()..sort();
    final reciter = _reciterId;
    final ended = _lastEvent ?? at;
    _startedAt = null;
    _since = null;
    _lastEvent = null;
    _listened = Duration.zero;
    _heard.clear();
    _reciterId = null;
    if (started == null || heard.isEmpty || reciter == null || listened < minimum) return null;
    return ListeningSummary(
      startedAt: started,
      endedAt: ended,
      listened: listened,
      first: heard.first,
      last: heard.last,
      ayat: heard.length,
      reciterId: reciter,
    );
  }
}
