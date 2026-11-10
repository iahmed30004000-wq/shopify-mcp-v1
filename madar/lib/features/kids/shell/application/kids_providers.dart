import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart'
    show sharedPreferencesProvider;
import '../../../lock/application/lock_controller.dart';
import '../../../lock/data/biometric_auth.dart';
import '../data/kids_store.dart';
import '../domain/kids_logic.dart';

/// Where the kids shell's state is kept (SharedPreferences: readable on the
/// first frame, before the database is unlocked).
final kidsStoreProvider = Provider<KidsStore>(
  (ref) => PrefsKidsStore(ref.watch(sharedPreferencesProvider)),
);

/// Android app pinning (tests override it with [FakeKidsPinning]).
final kidsPinningProvider = Provider<KidsPinning>(
  (ref) => ChannelKidsPinning(),
);

/// The kids shell's wall clock (day changes, the gate's pause). Tests drive it.
final kidsClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Silent until voices exist: speaks the text with this id, if there is a
/// recording for it. [KidsSpeakButton] calls it.
final kidsSpeakProvider = Provider<Future<void> Function(String textId)>(
  (ref) => (textId) async {},
);

/// Kids mode: on or off, the daily limit, today's play time, the gate's pause.
/// Written on every change, so the battery dying loses nothing that matters:
/// on-or-off is written at once, play time at most ten seconds late.
final kidsModeProvider = NotifierProvider<KidsMode, KidsModeState>(
  KidsMode.new,
);

/// Just the on/off bit (what the router and the app lock watch).
final kidsModeOnProvider = Provider<bool>(
  (ref) => ref.watch(kidsModeProvider.select((s) => s.on)),
);

/// How the day's time stands: the status plus the seconds left (null = no
/// limit).
@immutable
class KidsTimeView {
  const KidsTimeView(this.status, this.remainingSeconds, this.usedSeconds);

  final ScreenTimeStatus status;
  final int? remainingSeconds;
  final int usedSeconds;

  /// Whole minutes left, rounded up (a minute is "left" until it is gone).
  int? get remainingMinutes {
    final s = remainingSeconds;
    return s == null ? null : (s + 59) ~/ 60;
  }
}

final kidsTimeProvider = Provider<KidsTimeView>((ref) {
  final s = ref.watch(kidsModeProvider);
  return KidsTimeView(
    ScreenTimeRules.statusOf(s.limitMinutes, s.ledger.usedSeconds),
    ScreenTimeRules.remainingSeconds(s.limitMinutes, s.ledger.usedSeconds),
    s.ledger.usedSeconds,
  );
});

/// True from the moment the parent enters kids mode until the pin-the-screen
/// offer has been answered (never survives a relaunch: the offer is for the
/// entry, not for every start).
final kidsPinOfferPendingProvider = NotifierProvider<_Flag, bool>(_Flag.new);

class _Flag extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// What the parent-only layers show over the shell.
enum KidsParentPhase { none, gate, corner }

final kidsParentPhaseProvider =
    NotifierProvider<KidsParentFlow, KidsParentPhase>(KidsParentFlow.new);

class KidsParentFlow extends Notifier<KidsParentPhase> {
  @override
  KidsParentPhase build() => KidsParentPhase.none;

  /// The lock button, the system Back at the root, «للأهل: زيادة الوقت».
  void openGate() => state = KidsParentPhase.gate;

  /// The PIN or the fingerprint was right.
  void verified() => state = KidsParentPhase.corner;

  void close() => state = KidsParentPhase.none;
}

class KidsMode extends Notifier<KidsModeState> {
  KidsStore get _store => ref.read(kidsStoreProvider);
  DateTime _now() => ref.read(kidsClockProvider)();

  /// Play seconds counted since the last write.
  int _unsavedSeconds = 0;

  @override
  KidsModeState build() {
    final stored = _store.read();
    return stored.copyWith(backoff: stored.backoff.normalizedAt(_now()));
  }

  void _commit(KidsModeState next) {
    if (next == state) return;
    state = next;
    _unsavedSeconds = 0;
    unawaited(_save(next));
  }

  Future<void> _save(KidsModeState next) async {
    try {
      await _store.write(next);
    } catch (e) {
      if (kDebugMode) debugPrint('Madar kids: state not saved: $e');
    }
  }

  /// One tap: the phone is the child's. The offer to pin the screen follows.
  void enter() {
    ref.read(kidsPinOfferPendingProvider.notifier).set(true);
    ref.read(kidsParentPhaseProvider.notifier).close();
    _commit(state.copyWith(on: true));
  }

  /// Only after the PIN or the fingerprint (see [KidsGate]).
  void leave() {
    ref.read(kidsPinOfferPendingProvider.notifier).set(false);
    ref.read(kidsParentPhaseProvider.notifier).close();
    _commit(state.copyWith(on: false, backoff: GateBackoff.none));
  }

  /// The parent's daily limit in minutes (0 = none).
  void setLimit(int minutes) {
    final clamped = minutes.clamp(0, ScreenTimeRules.maxLimitMinutes);
    _commit(state.copyWith(limitMinutes: clamped));
  }

  /// One stepper tap: five minutes more or less (read from the live state, so
  /// two quick taps are two steps).
  void stepLimit({required bool up}) =>
      setLimit(ScreenTimeRules.stepped(state.limitMinutes, up: up));

  /// Counts [seconds] of foreground play (zero just rolls midnight). Writes
  /// every ten seconds, and at once when the limit is reached or [flush].
  void play(int seconds, {bool flush = false}) {
    final now = _now();
    final before = state;
    final ledger = before.ledger.add(seconds, now);
    if (ledger == before.ledger && !flush) return;
    final ended =
        ScreenTimeRules.statusOf(before.limitMinutes, ledger.usedSeconds) ==
            ScreenTimeStatus.ended &&
        ScreenTimeRules.statusOf(
              before.limitMinutes,
              before.ledger.usedSeconds,
            ) !=
            ScreenTimeStatus.ended;
    final dayChanged = ledger.dayKey != before.ledger.dayKey;
    state = before.copyWith(ledger: ledger);
    _unsavedSeconds += seconds;
    if (flush || ended || dayChanged || _unsavedSeconds >= 10) {
      _unsavedSeconds = 0;
      unawaited(_save(state));
    }
  }

  void _setBackoff(GateBackoff next) => _commit(state.copyWith(backoff: next));

  /// The result of one try at the parent gate. Wrong PINs are counted here
  /// (three in a row: a calm pause); the app lock's own back-off still
  /// applies underneath.
  Future<GateResult> tryPin(String pin) async {
    final now = _now();
    final backoff = state.backoff.normalizedAt(now);
    if (backoff != state.backoff) _setBackoff(backoff);
    if (backoff.pausedAt(now)) return GateResult.paused(backoff.remaining(now));

    final lock = ref.read(lockControllerProvider.notifier);
    final record = await lock.load();
    if (record == null) return const GateResult(GateOutcome.unavailable);
    // No PIN exists any more (it can only have been removed from outside the
    // shell): do not lock the parent in for good.
    if (!record.hasPin) return const GateResult(GateOutcome.accepted);

    final r = await lock.checkPin(pin, unlock: false);
    if (!ref.mounted) return const GateResult(GateOutcome.unavailable);
    switch (r.check) {
      case PinCheck.accepted:
        _setBackoff(GateBackoff.none);
        return const GateResult(GateOutcome.accepted);
      case PinCheck.wrong:
        final next = state.backoff.afterWrong(_now());
        _setBackoff(next);
        return next.pausedAt(_now())
            ? GateResult.paused(next.remaining(_now()))
            : const GateResult(GateOutcome.wrong);
      case PinCheck.lockedOut:
        return GateResult.paused(r.lockout);
      case PinCheck.busy:
        return const GateResult(GateOutcome.busy);
      case PinCheck.unavailable:
        return const GateResult(GateOutcome.unavailable);
    }
  }

  /// The fingerprint, only when the owner has switched it on for Madar and the
  /// phone has one enrolled; otherwise null (PIN only).
  Future<GateResult?> tryFingerprint(BiometricPromptText text) async {
    final lock = ref.read(lockControllerProvider.notifier);
    if (!await fingerprintAvailable()) return null;
    final outcome = await lock.authenticateWithBiometrics(text, unlock: false);
    if (!ref.mounted) return null;
    if (outcome == BiometricOutcome.success) {
      _setBackoff(GateBackoff.none);
      return const GateResult(GateOutcome.accepted);
    }
    return const GateResult(GateOutcome.wrong);
  }

  /// A fingerprint is enrolled in the phone AND switched on in Madar's lock.
  Future<bool> fingerprintAvailable() async {
    final lock = ref.read(lockControllerProvider.notifier);
    final record = await lock.load();
    if (record == null || !record.hasPin || !record.biometrics) return false;
    // The parent may have enrolled a finger since the answer was cached (the
    // lock host that normally refreshes it is not mounted in kids mode).
    ref.invalidate(biometricAvailabilityProvider);
    try {
      return await ref.read(biometricAvailabilityProvider.future) ==
          BiometricAvailability.available;
    } catch (_) {
      return false;
    }
  }
}

enum GateOutcome { accepted, wrong, paused, unavailable, busy }

@immutable
class GateResult {
  const GateResult(this.outcome, {this.pause = Duration.zero});

  factory GateResult.paused(Duration pause) =>
      GateResult(GateOutcome.paused, pause: pause);

  final GateOutcome outcome;
  final Duration pause;

  bool get accepted => outcome == GateOutcome.accepted;
}
