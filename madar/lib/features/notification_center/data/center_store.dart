import 'package:flutter/foundation.dart';

import '../../../core/db/repositories/key_value_repository.dart';
import '../domain/center_models.dart';
import '../domain/center_policy.dart';
import '../domain/notification_history.dart';

/// An upcoming notification as the center last saw it – so the next look
/// can tell what arrived in between (and whether a mute or a skip held it).
@immutable
class WatchedNotice {
  const WatchedNotice(this.notice, this.state);

  final CenterNotice notice;
  final CenterItemState state;

  Map<String, Object?> toJson() => {'n': notice.toJson(), 's': state.name};

  static WatchedNotice? fromJson(Object? json) {
    if (json is! Map) return null;
    final n = CenterNotice.fromJson(json['n']);
    final s = CenterItemState.values.where((v) => v.name == json['s']).firstOrNull;
    if (n == null || s == null) return null;
    return WatchedNotice(n, s);
  }

  @override
  bool operator ==(Object other) => other is WatchedNotice && other.notice == notice && other.state == state;

  @override
  int get hashCode => Object.hash(notice, state);
}

/// The center's state in the encrypted key/value store (no schema change):
///
/// * `notificationCenter.history` – [NotificationHistory] (bounded);
/// * `notificationCenter.policy` – mutes, skips and snoozes ([CenterPolicy]);
/// * `notificationCenter.watch` – the upcoming list as last seen (bounded);
/// * `notificationCenter.seenAt` – when the Recent tab was last looked at.
class NotificationCenterStore {
  NotificationCenterStore(this.kv);

  final KeyValueRepository kv;

  static const String historyKey = 'notificationCenter.history';
  static const String policyKey = 'notificationCenter.policy';
  static const String watchKey = 'notificationCenter.watch';
  static const String seenKey = 'notificationCenter.seenAt';

  /// At most this many upcoming notifications are remembered.
  static const int watchLimit = 300;

  Future<NotificationHistory> history() async => NotificationHistory.fromJson(await kv.getJson(historyKey));

  Future<void> saveHistory(NotificationHistory history) => kv.setJson(historyKey, history.toJson());

  Future<CenterPolicy> policy() async => CenterPolicy.fromJson(await kv.getJson(policyKey));

  Future<void> savePolicy(CenterPolicy policy) => kv.setJson(policyKey, policy.toJson());

  Future<List<WatchedNotice>> watch() async {
    final raw = await kv.getJson(watchKey);
    if (raw is! List) return const [];
    return [for (final e in raw) ?WatchedNotice.fromJson(e)];
  }

  Future<void> saveWatch(List<WatchedNotice> watch) =>
      kv.setJson(watchKey, [for (final w in watch.take(watchLimit)) w.toJson()]);

  Future<DateTime?> seenAt() async {
    final raw = await kv.getJson(seenKey);
    return raw is int ? DateTime.fromMillisecondsSinceEpoch(raw) : null;
  }

  Future<void> saveSeenAt(DateTime at) => kv.setJson(seenKey, at.millisecondsSinceEpoch);
}
