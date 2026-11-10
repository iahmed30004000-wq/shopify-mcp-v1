import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An answer another app handed to Madar: text shared out of Gemini or
/// ChatGPT, or the contents of a `.json` file opened with Madar.
///
/// Nothing is fetched: Android hands Madar the text (or the file it may
/// read), exactly like the share sheet hands a link to Saved Games.
class SharedPlanPayload {
  const SharedPlanPayload(this.text, {this.name});

  final String text;

  /// The file's name, when it came as a file.
  final String? name;
}

/// The Android side of the share intent (`app.madar.orbit/share`,
/// `ShareIntakeChannel.kt`): `ACTION_SEND` of `text/plain` or
/// `application/json`, and `ACTION_VIEW` of a `.json` file.
abstract interface class ShareIntake {
  /// What was shared before the app was running, once (null when nothing
  /// was, which is every ordinary launch).
  Future<SharedPlanPayload?> takeLaunchShare();

  /// What is shared into a running Madar.
  Stream<SharedPlanPayload> get shares;
}

/// [ShareIntake] over the method channel. Off Android (tests, other
/// platforms) the channel has no handler: nothing ever arrives.
class MethodChannelShareIntake implements ShareIntake {
  MethodChannelShareIntake({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onCall);
  }

  static const String channelName = 'app.madar.orbit/share';

  final MethodChannel _channel;
  final StreamController<SharedPlanPayload> _shares = StreamController.broadcast();

  @override
  Stream<SharedPlanPayload> get shares => _shares.stream;

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method == 'shared') {
      final payload = _payloadOf(call.arguments);
      if (payload != null) _shares.add(payload);
    }
    return null;
  }

  @override
  Future<SharedPlanPayload?> takeLaunchShare() async {
    try {
      return _payloadOf(await _channel.invokeMethod<Object?>('takeLaunchShare'));
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static SharedPlanPayload? _payloadOf(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    if (text is! String || text.trim().isEmpty) return null;
    final name = raw['name'];
    return SharedPlanPayload(text, name: name is String && name.trim().isNotEmpty ? name : null);
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_shares.close());
  }
}

/// Nothing is ever shared in (every platform but Android, and every test
/// that does not say otherwise).
class NoShareIntake implements ShareIntake {
  const NoShareIntake();

  @override
  Future<SharedPlanPayload?> takeLaunchShare() async => null;

  @override
  Stream<SharedPlanPayload> get shares => const Stream.empty();
}

/// The share intent, on Android only. Tests override it with a fake.
final shareIntakeProvider = Provider<ShareIntake>((ref) {
  if (kIsWeb || !Platform.isAndroid) return const NoShareIntake();
  final intake = MethodChannelShareIntake();
  ref.onDispose(intake.dispose);
  return intake;
});

/// An answer that arrived and is waiting to be read.
///
/// The share router puts it here and opens «استيراد خطة»; the screen takes
/// it, because reading an answer needs his language (the plan's default
/// name) and a screen he can see the problems on.
final pendingSharedPlanProvider = NotifierProvider<PendingSharedPlan, SharedPlanPayload?>(PendingSharedPlan.new);

class PendingSharedPlan extends Notifier<SharedPlanPayload?> {
  @override
  SharedPlanPayload? build() => null;

  void offer(SharedPlanPayload payload) => state = payload;

  /// Reads it once: a second screen never re-imports the same share.
  SharedPlanPayload? take() {
    final payload = state;
    state = null;
    return payload;
  }
}
