// The pure rules of the kids shell: what is stored, how screen time is
// counted, and how the parent gate backs off. No Flutter, no storage, no
// clock of its own: everything is handed `now`, so the boundary, midnight and
// clock-change cases are plain unit tests.
import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;

/// `yyyymmdd` of [d] in local time: the key of "today" for the daily limit.
int kidsDayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// How the day's play time stands against the parent's limit.
enum ScreenTimeStatus {
  /// No limit set (0 minutes): never ends.
  off,

  /// Time left, and plenty of it.
  playing,

  /// [ScreenTimeRules.warningSeconds] or less left: the gentle pill.
  warning,

  /// The limit is reached: the end screen.
  ended,
}

/// The foreground seconds the child has played on one day.
@immutable
class ScreenTimeLedger {
  const ScreenTimeLedger({this.dayKey = 0, this.usedSeconds = 0});

  static const ScreenTimeLedger empty = ScreenTimeLedger();

  /// The day [usedSeconds] belongs to ([kidsDayKey]); 0 before any play.
  final int dayKey;
  final int usedSeconds;

  /// The ledger as of [now]: a LATER calendar day starts at zero (midnight).
  /// The same or an EARLIER day changes nothing, so turning the phone's clock
  /// back never hands out a fresh day.
  ScreenTimeLedger rolledTo(DateTime now) {
    final key = kidsDayKey(now);
    if (key > dayKey) return ScreenTimeLedger(dayKey: key);
    return this;
  }

  /// [seconds] more play as of [now] (midnight first, never negative).
  ScreenTimeLedger add(int seconds, DateTime now) {
    final rolled = rolledTo(now);
    final more = seconds < 0 ? 0 : seconds;
    return ScreenTimeLedger(
      dayKey: rolled.dayKey,
      usedSeconds: rolled.usedSeconds + more,
    );
  }

  Map<String, Object?> toJson() => {'day': dayKey, 'used': usedSeconds};

  static ScreenTimeLedger fromJson(Object? json) {
    if (json is! Map) return empty;
    final day = json['day'];
    final used = json['used'];
    return ScreenTimeLedger(
      dayKey: day is int && day > 0 ? day : 0,
      usedSeconds: used is int && used > 0 ? used : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScreenTimeLedger &&
      other.dayKey == dayKey &&
      other.usedSeconds == usedSeconds;

  @override
  int get hashCode => Object.hash(dayKey, usedSeconds);
}

/// The daily-limit arithmetic.
abstract final class ScreenTimeRules {
  /// Where the gentle pill starts: five minutes before the end.
  static const int warningSeconds = 300;

  /// The stepper's range in the parent corner (0 = off).
  static const int maxLimitMinutes = 240;
  static const int stepMinutes = 5;

  /// Seconds of play left today ([limitMinutes] 0 = unlimited: null).
  static int? remainingSeconds(int limitMinutes, int usedSeconds) {
    if (limitMinutes <= 0) return null;
    final left = limitMinutes * 60 - usedSeconds;
    return left < 0 ? 0 : left;
  }

  /// At exactly the limit the time is over (limit - 1 second still plays).
  static ScreenTimeStatus statusOf(int limitMinutes, int usedSeconds) {
    final left = remainingSeconds(limitMinutes, usedSeconds);
    if (left == null) return ScreenTimeStatus.off;
    if (left <= 0) return ScreenTimeStatus.ended;
    if (left <= warningSeconds) return ScreenTimeStatus.warning;
    return ScreenTimeStatus.playing;
  }

  /// A tick's worth of play: the time since the last tick, but never more than
  /// [maxStepSeconds] and never negative. A clock that jumps (set forward, set
  /// back, a summer-time change) therefore neither burns the child's time nor
  /// gives any back.
  static int tickSeconds(
    DateTime last,
    DateTime now, {
    int maxStepSeconds = 2,
  }) {
    final ms = now.difference(last).inMilliseconds;
    if (ms <= 0) return 0;
    final seconds = (ms / 1000).round();
    return seconds > maxStepSeconds ? maxStepSeconds : seconds;
  }

  /// The limit one stepper tap away ([up] more, else less), kept in range.
  static int stepped(int limitMinutes, {required bool up}) {
    final next = limitMinutes + (up ? stepMinutes : -stepMinutes);
    if (next < 0) return 0;
    if (next > maxLimitMinutes) return maxLimitMinutes;
    return next;
  }
}

/// The parent gate's wrong-PIN pause: three wrong tries in a row cost a calm
/// [pause]; then three more are free again. Kept in storage so killing the app
/// never hands the child fresh tries.
@immutable
class GateBackoff {
  const GateBackoff({this.failures = 0, this.pausedUntilMs});

  static const GateBackoff none = GateBackoff();
  static const int freeTries = 3;
  static const Duration pause = Duration(seconds: 30);

  /// Wrong tries since the last pause or success.
  final int failures;
  final int? pausedUntilMs;

  /// Time left of the pause at [now] (zero when none).
  Duration remaining(DateTime now) {
    final until = pausedUntilMs;
    if (until == null) return Duration.zero;
    final left = until - now.millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : Duration.zero;
  }

  bool pausedAt(DateTime now) => remaining(now) > Duration.zero;

  /// After a wrong PIN at [now]: the third one starts the pause.
  GateBackoff afterWrong(DateTime now) {
    final n = failures + 1;
    if (n >= freeTries) {
      return GateBackoff(pausedUntilMs: now.add(pause).millisecondsSinceEpoch);
    }
    return GateBackoff(failures: n, pausedUntilMs: pausedUntilMs);
  }

  /// A clock turned back must not stretch the pause: one that would outlast
  /// [pause] from [now] is re-anchored to it.
  GateBackoff normalizedAt(DateTime now) {
    final until = pausedUntilMs;
    if (until == null) return this;
    final left = until - now.millisecondsSinceEpoch;
    if (left > pause.inMilliseconds) {
      return GateBackoff(
        failures: failures,
        pausedUntilMs: now.add(pause).millisecondsSinceEpoch,
      );
    }
    return this;
  }

  Map<String, Object?> toJson() => {'f': failures, 'u': pausedUntilMs};

  static GateBackoff fromJson(Object? json) {
    if (json is! Map) return none;
    final f = json['f'];
    final u = json['u'];
    return GateBackoff(
      failures: f is int && f > 0 ? f : 0,
      pausedUntilMs: u is int ? u : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GateBackoff &&
      other.failures == failures &&
      other.pausedUntilMs == pausedUntilMs;

  @override
  int get hashCode => Object.hash(failures, pausedUntilMs);
}

/// Everything the kids shell keeps on the phone.
@immutable
class KidsModeState {
  const KidsModeState({
    this.on = false,
    this.limitMinutes = 0,
    this.ledger = ScreenTimeLedger.empty,
    this.backoff = GateBackoff.none,
  });

  static const KidsModeState off = KidsModeState();

  /// Kids mode is on: the adult app is unreachable until the parent leaves.
  final bool on;

  /// The parent's daily limit in minutes; 0 = no limit.
  final int limitMinutes;
  final ScreenTimeLedger ledger;
  final GateBackoff backoff;

  KidsModeState copyWith({
    bool? on,
    int? limitMinutes,
    ScreenTimeLedger? ledger,
    GateBackoff? backoff,
  }) => KidsModeState(
    on: on ?? this.on,
    limitMinutes: limitMinutes ?? this.limitMinutes,
    ledger: ledger ?? this.ledger,
    backoff: backoff ?? this.backoff,
  );

  String encode() => jsonEncode({
    'v': 1,
    'on': on,
    'limit': limitMinutes,
    'ledger': ledger.toJson(),
    'gate': backoff.toJson(),
  });

  /// A missing or damaged record is [off] (nothing to keep a child inside),
  /// but a record that says "on" survives any damage elsewhere in it.
  static KidsModeState decode(String? raw) {
    if (raw == null || raw.isEmpty) return off;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return off;
      final limit = j['limit'];
      return KidsModeState(
        on: j['on'] == true,
        limitMinutes: limit is int && limit > 0
            ? limit.clamp(0, ScreenTimeRules.maxLimitMinutes)
            : 0,
        ledger: ScreenTimeLedger.fromJson(j['ledger']),
        backoff: GateBackoff.fromJson(j['gate']),
      );
    } catch (_) {
      // Damaged beyond reading: if it still says "on", stay on.
      return raw.contains('"on":true') ? const KidsModeState(on: true) : off;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is KidsModeState &&
      other.on == on &&
      other.limitMinutes == limitMinutes &&
      other.ledger == ledger &&
      other.backoff == backoff;

  @override
  int get hashCode => Object.hash(on, limitMinutes, ledger, backoff);
}
