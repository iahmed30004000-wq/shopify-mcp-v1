import 'dart:convert';

import 'notification_models.dart';

/// The JSON payload Madar stores with every notification.
///
/// ```json
/// {"ns":"adhan","v":1,"c":"<channel id>","at":1790000000000,"late":300000,
///  "ls":1,"h":"<content hash>","d":{…feature data…}}
/// ```
///
/// * `ns`, `d` – which feature posted it and its data (handed back on tap).
/// * `c`, `h` – channel and content hash: the envelope string changes
///   whenever anything the user would see or hear changes, so
///   [NotificationService.sync] can compare pending notifications by payload
///   alone (the plugin reports only id/title/body/payload).
/// * `at` – scheduled instant (ms since epoch, UTC).
/// * `late` – drop-if-late window in ms: `AdhanBootGuard.kt` removes such
///   alarms from the plugin's reboot cache once they are later than this.
/// * `ls` – may show over the lock screen (MainActivity only honours it for
///   one of Madar's own, currently posted notifications).
///
/// Keep the keys in sync with `android/app/src/main/kotlin/…/AdhanBootGuard.kt`
/// and `MainActivity.kt`.
abstract final class NotificationEnvelope {
  static const version = 1;

  static String encode(NotificationRequest r) {
    final map = <String, Object?>{
      'ns': r.namespace.name,
      'v': version,
      'c': r.channelId,
      'at': r.at.toUtc().millisecondsSinceEpoch,
      if (r.dropIfLateBy != null) 'late': r.dropIfLateBy!.inMilliseconds,
      if (r.fullScreen) 'ls': 1,
      'h': contentHash(r.contentSignature),
      'd': r.data,
    };
    return jsonEncode(map);
  }

  /// Decodes a payload; foreign or malformed payloads become a tap with no
  /// namespace and the raw payload under `raw`.
  static NotificationTap decode(String? payload, {int? id, String? actionId, bool fromLaunch = false}) {
    if (payload == null || payload.isEmpty) {
      return NotificationTap(id: id, namespace: null, data: const {}, actionId: actionId, fromLaunch: fromLaunch);
    }
    try {
      final raw = jsonDecode(payload);
      if (raw is Map && raw['ns'] is String) {
        final at = raw['at'];
        final d = raw['d'];
        return NotificationTap(
          id: id,
          namespace: raw['ns'] as String,
          data: d is Map ? Map<String, Object?>.from(d) : const {},
          actionId: actionId,
          channelId: raw['c'] is String ? raw['c'] as String : null,
          at: at is int ? DateTime.fromMillisecondsSinceEpoch(at, isUtc: true) : null,
          fromLaunch: fromLaunch,
        );
      }
    } on FormatException {
      // fall through
    }
    return NotificationTap(id: id, namespace: null, data: {'raw': payload}, actionId: actionId, fromLaunch: fromLaunch);
  }

  /// A short, stable FNV-1a hash (hex) of [s].
  static String contentHash(String s) {
    var h = 0x811c9dc5;
    for (final unit in utf8.encode(s)) {
      h ^= unit;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}
