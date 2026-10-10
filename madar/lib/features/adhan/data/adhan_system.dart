import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The alarm stream's volume (the adhan plays on it).
@immutable
class AlarmVolume {
  const AlarmVolume(this.current, this.max);

  final int current;
  final int max;

  bool get muted => current <= 0;
  double get fraction => max <= 0 ? 0 : (current / max).clamp(0.0, 1.0);
}

/// Madar's own Android bits for the adhan (MainActivity.kt, channel
/// `app.madar.orbit/adhan`): lock-screen mode, full-screen-intent status,
/// alarm volume, the muezzin sound folder / content URIs and deep links to
/// system settings. Every call degrades gracefully where the channel is
/// missing (tests, other platforms).
abstract interface class AdhanSystem {
  /// Allows the activity over the lock screen and keeps the screen on (only
  /// while the adhan screen shows).
  Future<void> setLockScreenMode(bool enabled);

  Future<bool> isKeyguardLocked();

  /// Android 14+: whether full-screen intents are allowed (true below 14).
  Future<bool> canUseFullScreenIntent();

  Future<AlarmVolume?> alarmVolume();

  /// Absolute path of the folder the sound provider serves (null → use the
  /// app's support directory).
  Future<String?> soundsDirectory();

  /// A `content://` URI for recording [fileName] in the sound folder,
  /// readable by the system (null if the file is missing).
  Future<String?> soundUri(String fileName);

  Future<bool> openSoundSettings();
  Future<bool> openNotificationSettings({String? channelId});
  Future<bool> openFullScreenIntentSettings();
  Future<bool> openBatterySettings();
}

/// [AdhanSystem] over the platform channel.
class MethodChannelAdhanSystem implements AdhanSystem {
  const MethodChannelAdhanSystem({this.channel = const MethodChannel('app.madar.orbit/adhan')});

  final MethodChannel channel;

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    if (!_android) return null;
    try {
      return await channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('AdhanSystem.$method failed: ${e.message}');
      return null;
    }
  }

  @override
  Future<void> setLockScreenMode(bool enabled) => _call<void>('lockScreen', {'enabled': enabled});

  @override
  Future<bool> isKeyguardLocked() async => await _call<bool>('isKeyguardLocked') ?? false;

  @override
  Future<bool> canUseFullScreenIntent() async => await _call<bool>('canUseFullScreenIntent') ?? true;

  @override
  Future<AlarmVolume?> alarmVolume() async {
    final m = await _call<Map<Object?, Object?>>('alarmVolume');
    final c = m?['current'], x = m?['max'];
    return c is int && x is int ? AlarmVolume(c, x) : null;
  }

  @override
  Future<String?> soundsDirectory() => _call<String>('soundsDirectory');

  @override
  Future<String?> soundUri(String fileName) => _call<String>('soundUri', {'name': fileName});

  @override
  Future<bool> openSoundSettings() async => await _call<bool>('openSoundSettings') ?? false;

  @override
  Future<bool> openNotificationSettings({String? channelId}) async =>
      await _call<bool>('openNotificationSettings', {'channelId': channelId}) ?? false;

  @override
  Future<bool> openFullScreenIntentSettings() async => await _call<bool>('openFullScreenIntentSettings') ?? false;

  @override
  Future<bool> openBatterySettings() async => await _call<bool>('openBatterySettings') ?? false;
}

/// In-memory [AdhanSystem] for tests.
class FakeAdhanSystem implements AdhanSystem {
  FakeAdhanSystem({this.fullScreen = true, this.volume = const AlarmVolume(5, 7), this.directory});

  bool fullScreen;
  AlarmVolume? volume;
  String? directory;
  bool lockScreenMode = false;
  bool keyguardLocked = false;
  final List<String> opened = [];

  /// Every [setLockScreenMode] call, in order.
  final List<bool> lockScreenCalls = [];

  @override
  Future<void> setLockScreenMode(bool enabled) async {
    lockScreenCalls.add(enabled);
    lockScreenMode = enabled;
  }

  @override
  Future<bool> isKeyguardLocked() async => keyguardLocked;

  @override
  Future<bool> canUseFullScreenIntent() async => fullScreen;

  @override
  Future<AlarmVolume?> alarmVolume() async => volume;

  @override
  Future<String?> soundsDirectory() async => directory;

  @override
  Future<String?> soundUri(String fileName) async => 'content://app.madar.orbit.adhansounds/$fileName';

  @override
  Future<bool> openSoundSettings() async {
    opened.add('sound');
    return true;
  }

  @override
  Future<bool> openNotificationSettings({String? channelId}) async {
    opened.add('notifications:${channelId ?? ''}');
    return true;
  }

  @override
  Future<bool> openFullScreenIntentSettings() async {
    opened.add('fullScreen');
    return true;
  }

  @override
  Future<bool> openBatterySettings() async {
    opened.add('battery');
    return true;
  }
}
