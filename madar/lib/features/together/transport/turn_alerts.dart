/// "Your turn" – a local notification while the app runs in the background
/// (no push service, no server): posted when the partner's move makes it
/// this phone's turn, removed when the app comes back, the turn passes or
/// the game ends.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_service.dart';
import '../protocol/session.dart';

/// Together Mode's notification ids: [namespace] 170000–170999 (after the
/// notification centre's 160000–160999).
abstract final class TogetherNotifications {
  static const NotificationNamespace namespace = NotificationNamespace('together', 170000, 170999);

  /// The one "your turn" notification (replaced, never stacked).
  static const int yourTurnId = 170000;

  static const String groupId = 'madar.together';
  static const String channelPrefix = 'madar.together.';
  static const String turnChannelId = 'madar.together.turn.1';
}

/// The texts of a "your turn" alert, in the UI language.
@immutable
final class TogetherTurnTexts {
  const TogetherTurnTexts({
    required this.groupName,
    required this.channelName,
    required this.channelDescription,
    required this.title,
    required this.body,
  });

  final String groupName;
  final String channelName;
  final String channelDescription;
  final String title;
  final String body;
}

class TogetherTurnAlerts {
  TogetherTurnAlerts({required this.notifications, required this.foreground});

  final NotificationService notifications;

  /// Whether the app is in the foreground (`appForegroundProvider`).
  final ValueListenable<bool> foreground;

  bool _channelReady = false;

  Future<void> _ensureChannel(TogetherTurnTexts t) async {
    if (_channelReady) return;
    await notifications.ensureChannelGroup(TogetherNotifications.groupId, t.groupName);
    await notifications.ensureChannels([
      NotificationChannelSpec(
        id: TogetherNotifications.turnChannelId,
        name: t.channelName,
        description: t.channelDescription,
        importance: NotificationImportance.high,
        groupId: TogetherNotifications.groupId,
      ),
    ], prunePrefix: TogetherNotifications.channelPrefix);
    _channelReady = true;
  }

  /// Watches [session] until the returned function is called. Never asks
  /// for the notification permission mid-game: without it nothing is shown.
  VoidCallback watch<S, M>(TogetherSession<S, M> session, {required TogetherTurnTexts Function() texts}) {
    var shown = false;
    var stopped = false;

    Future<void> show() async {
      try {
        if (!await notifications.notificationsEnabled()) return;
        final t = texts();
        await _ensureChannel(t);
        if (stopped || foreground.value || !session.canPlay()) return;
        await notifications.show(
          NotificationRequest(
            namespace: TogetherNotifications.namespace,
            id: TogetherNotifications.yourTurnId,
            channelId: TogetherNotifications.turnChannelId,
            title: t.title,
            body: t.body,
            at: DateTime.now(),
            category: NotificationCategory.event,
            timeout: const Duration(hours: 6),
            data: const {'k': 'turn'},
          ),
        );
        shown = true;
      } on Object catch (e) {
        debugPrint('Together: your-turn alert failed: $e');
      }
    }

    Future<void> clear() async {
      if (!shown) return;
      shown = false;
      try {
        await notifications.cancel(TogetherNotifications.yourTurnId);
      } on Object {
        // Already gone.
      }
    }

    final sub = session.events.listen((e) {
      switch (e) {
        case SessionFinished() || PeerLeft() || SessionFailed():
          unawaited(clear());
        case MoveApplied(remote: true) || StateResynced() || SessionStarted():
          if (!foreground.value && !shown && session.canPlay()) unawaited(show());
        default:
          if (!session.canPlay()) unawaited(clear());
      }
    });

    void onForeground() {
      if (foreground.value) unawaited(clear());
    }

    foreground.addListener(onForeground);
    return () {
      if (stopped) return;
      stopped = true;
      unawaited(sub.cancel());
      foreground.removeListener(onForeground);
      unawaited(clear());
    };
  }
}
