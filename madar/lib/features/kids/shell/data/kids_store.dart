import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/kids_logic.dart';

/// Where the kids shell keeps its state.
///
/// SharedPreferences, not the encrypted database, on purpose: the router asks
/// "is kids mode on?" on its very first frame (a relaunch must land inside the
/// shell), before the database has been unlocked. Nothing personal lives here:
/// a flag, a limit in minutes, seconds played today and the gate's pause.
abstract interface class KidsStore {
  /// Synchronous: the first frame needs it.
  KidsModeState read();

  /// Written on every change, so a dying battery loses at most a few seconds
  /// of play time.
  Future<void> write(KidsModeState state);
}

class PrefsKidsStore implements KidsStore {
  PrefsKidsStore(this._prefs);

  static const String key = 'kids.shell.v1';

  final SharedPreferences _prefs;

  @override
  KidsModeState read() {
    try {
      return KidsModeState.decode(_prefs.getString(key));
    } catch (_) {
      return KidsModeState.off;
    }
  }

  @override
  Future<void> write(KidsModeState state) async {
    await _prefs.setString(key, state.encode());
  }
}

/// For tests and previews.
class MemoryKidsStore implements KidsStore {
  MemoryKidsStore([this.state = KidsModeState.off]);

  KidsModeState state;
  int writes = 0;

  @override
  KidsModeState read() => state;

  @override
  Future<void> write(KidsModeState next) async {
    state = next;
    writes++;
  }
}

/// Android app pinning (screen pinning): the phone stays on Madar Kids until
/// the parent uses the system gesture.
abstract interface class KidsPinning {
  /// Whether this phone can pin from here at all.
  Future<bool> get supported;

  /// Whether the screen is pinned right now.
  Future<bool> isPinned();

  /// Asks Android to pin (it shows its own confirmation).
  Future<void> start();

  /// Ends the pinning (best effort; only the parent ever gets here).
  Future<void> stop();
}

/// [KidsPinning] over the tiny Kotlin channel (`KidsPinning.kt`, standard
/// `Activity.startLockTask()` / `stopLockTask()` and
/// `ActivityManager.lockTaskModeState`). Every call feature-detects: a
/// missing plugin (tests, iOS, an old build) means "not supported", never an
/// error the child could see.
class ChannelKidsPinning implements KidsPinning {
  ChannelKidsPinning([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'app.madar.orbit/kids_pinning';

  final MethodChannel _channel;
  bool? _supported;

  @override
  Future<bool> get supported async {
    final known = _supported;
    if (known != null) return known;
    try {
      final r = await _channel.invokeMethod<bool>('isPinned');
      return _supported = r != null;
    } on MissingPluginException {
      return _supported = false;
    } on PlatformException {
      return _supported = false;
    }
  }

  @override
  Future<bool> isPinned() async {
    try {
      return await _channel.invokeMethod<bool>('isPinned') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> start() async {
    try {
      await _channel.invokeMethod<bool>('start');
    } on MissingPluginException {
      // Not supported here: the offer simply does nothing.
    } on PlatformException {
      // Android refused (pinning switched off in its settings): nothing to do.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('stop');
    } on MissingPluginException {
      // Not supported here.
    } on PlatformException {
      // Already unpinned.
    }
  }
}

/// A pinning stand-in for tests.
class FakeKidsPinning implements KidsPinning {
  FakeKidsPinning({this.isSupported = true});

  final bool isSupported;
  bool pinned = false;
  int starts = 0;
  int stops = 0;

  @override
  Future<bool> get supported async => isSupported;

  @override
  Future<bool> isPinned() async => pinned;

  @override
  Future<void> start() async {
    starts++;
    if (isSupported) pinned = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    pinned = false;
  }
}
