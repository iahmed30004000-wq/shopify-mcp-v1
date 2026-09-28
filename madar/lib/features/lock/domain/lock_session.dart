import 'package:flutter/widgets.dart' show AppLifecycleState;

/// Where the app lock stands.
enum LockPhase {
  /// The app is visible (lock disarmed, or unlocked).
  open,

  /// The lock screen covers the app (which stays mounted underneath).
  locked,

  /// Authenticated: the lock screen is playing its opening animation over
  /// the (now visible) app.
  revealing,
}

/// The app lock's pure state machine: cold start, background time-out,
/// the privacy shield and the unlock hand-off. No Flutter bindings, no
/// storage – the controller feeds it lifecycle events and a clock.
///
/// * Armed (lock enabled and a PIN set): every cold start is [LockPhase.locked].
/// * Leaving the app (`hidden` / `paused`) records the wall-clock time;
///   coming back after at least [lockAfter] locks again ([lockAfter] zero:
///   every time). A clock that moved backwards also locks – when in doubt,
///   lock. The wall clock is used on purpose: the monotonic clock stops
///   while the phone sleeps.
/// * `inactive` (recents, the notification shade, a system dialog) raises a
///   privacy [shielded] cover over an open app, so the recents thumbnail
///   never shows personal data; `resumed` lowers it.
/// * While [suspended] (an authentication prompt or a file picker the app
///   opened itself) the app is not really being left: no privacy cover, and
///   the time-out is stretched to at least [suspendedGrace] – but never
///   dropped, so a picker or a sticky fingerprint prompt left open while the
///   owner walks away still locks when the app comes back.
class LockSession {
  // ignore_for_file: prefer_initializing_formals
  LockSession({required DateTime Function() clock, required bool armed, required Duration lockAfter})
    : _clock = clock,
      _armed = armed,
      _lockAfter = lockAfter;

  /// The shortest time-out while the app is in one of its own external
  /// flows ([suspend]): long enough to pick a file or read a permission
  /// screen, short enough that a flow left open never keeps Madar unlocked.
  static const Duration suspendedGrace = Duration(minutes: 10);

  final DateTime Function() _clock;
  bool _armed;
  Duration _lockAfter;
  LockPhase _phase = LockPhase.open;
  bool _shielded = false;
  DateTime? _leftAt;
  bool _leftSuspended = false;
  int _suspensions = 0;

  LockPhase get phase => _phase;
  bool get armed => _armed;
  bool get shielded => _shielded;
  Duration get lockAfter => _lockAfter;
  bool get suspended => _suspensions > 0;

  /// When the app was last left (null while in the foreground).
  DateTime? get leftAt => _leftAt;

  /// Whether a background stay from [leftAt] to [now] requires unlocking.
  static bool shouldLock({required DateTime leftAt, required DateTime now, required Duration lockAfter}) {
    if (now.isBefore(leftAt)) return true;
    return now.difference(leftAt) >= lockAfter;
  }

  /// A cold launch: locked when armed.
  void coldStart() {
    _phase = _armed ? LockPhase.locked : LockPhase.open;
    _shielded = false;
    _leftAt = null;
    _leftSuspended = false;
  }

  /// Arms or disarms the lock. Arming never locks by itself (the owner is
  /// here, they just set it up) unless [lockNow]; disarming opens the app.
  void setArmed(bool armed, {bool lockNow = false}) {
    _armed = armed;
    if (!armed) {
      _phase = LockPhase.open;
      _shielded = false;
      _leftAt = null;
      _leftSuspended = false;
    } else if (lockNow) {
      _phase = LockPhase.locked;
    }
  }

  set lockAfter(Duration value) => _lockAfter = value < Duration.zero ? Duration.zero : value;

  void suspend() => _suspensions++;

  void unsuspend() {
    if (_suspensions > 0) _suspensions--;
  }

  /// Feeds a lifecycle change.
  void onLifecycle(AppLifecycleState state) {
    if (!_armed) return;
    switch (state) {
      case AppLifecycleState.inactive:
        if (!suspended && _phase != LockPhase.locked) _shielded = true;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_leftAt == null) {
          _leftAt = _clock();
          _leftSuspended = suspended;
        }
        if (!suspended && _phase != LockPhase.locked) _shielded = true;
      case AppLifecycleState.resumed:
        final left = _leftAt;
        // A flow's result (a picked file) often arrives just before
        // `resumed`, so the grace follows how the app was left, not whether
        // the flow is still open.
        final limit = _leftSuspended && _lockAfter < suspendedGrace ? suspendedGrace : _lockAfter;
        _leftAt = null;
        _leftSuspended = false;
        _shielded = false;
        if (left != null && _phase != LockPhase.locked && shouldLock(leftAt: left, now: _clock(), lockAfter: limit)) {
          _phase = LockPhase.locked;
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  /// A successful authentication: the lock screen starts opening.
  void authenticated() {
    if (_phase == LockPhase.locked) _phase = LockPhase.revealing;
  }

  /// The opening animation finished.
  void revealed() {
    if (_phase == LockPhase.revealing) _phase = LockPhase.open;
  }

  /// Locks immediately (e.g. a "lock now" action) when armed.
  void lock() {
    if (_armed) {
      _phase = LockPhase.locked;
      _shielded = false;
    }
  }
}
