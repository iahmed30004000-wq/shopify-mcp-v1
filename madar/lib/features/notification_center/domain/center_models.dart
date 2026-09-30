import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_envelope.dart';
import '../../../core/notifications/notification_models.dart';

/// The sections of the notification center, in their fixed, calm order.
enum NotificationGroup {
  prayer,
  adhkar,
  medications,
  health,
  money,
  family,
  travel,
  wird,
  customModules,
  other;

  static NotificationGroup? byName(Object? name) {
    for (final g in values) {
      if (g.name == name) return g;
    }
    return null;
  }
}

/// One notification, normalised from whatever holds it – the platform's
/// pending list, the tray, a tap, a request on its way to the platform or
/// the center's own history: which feature posted it (namespace + data),
/// when it fires (or fired) and the texts it shows.
@immutable
class CenterNotice {
  const CenterNotice({
    required this.id,
    this.namespace,
    this.at,
    this.data = const {},
    this.title,
    this.body,
    this.channelId,
  });

  final int id;

  /// The feature's namespace (`adhan`, `meds`, `reminders` …); null for a
  /// foreign or legacy payload.
  final String? namespace;

  /// When it fires / fired (UTC instant from the envelope).
  final DateTime? at;

  /// The feature's own data (the envelope's `d`).
  final Map<String, Object?> data;

  /// What the notification shows (the feature wrote it in the UI language
  /// of the moment it was scheduled).
  final String? title;
  final String? body;
  final String? channelId;

  /// Identity of one firing: an id is reused on other days, a firing is not.
  String get key => keyOf(id, at);

  static String keyOf(int id, DateTime? at) => '$id@${at?.millisecondsSinceEpoch ?? 0}';

  /// The instant a [key] was made for (null for an unknown time).
  static DateTime? atOfKey(String key) {
    final i = key.indexOf('@');
    final ms = i < 0 ? null : int.tryParse(key.substring(i + 1));
    return ms == null || ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  factory CenterNotice.fromPayload(int id, String? payload, {String? title, String? body, String? channelId}) {
    final tap = NotificationEnvelope.decode(payload, id: id);
    return CenterNotice(
      id: id,
      namespace: tap.namespace,
      at: tap.at,
      data: tap.data,
      title: _text(title),
      body: _text(body),
      channelId: channelId ?? tap.channelId,
    );
  }

  factory CenterNotice.fromRequest(NotificationRequest r) => CenterNotice(
    id: r.id,
    namespace: r.namespace.name,
    at: DateTime.fromMillisecondsSinceEpoch(r.at.toUtc().millisecondsSinceEpoch, isUtc: true),
    data: r.data,
    title: _text(r.title),
    body: _text(r.body),
    channelId: r.channelId,
  );

  factory CenterNotice.fromTap(NotificationTap tap) =>
      CenterNotice(id: tap.id ?? 0, namespace: tap.namespace, at: tap.at, data: tap.data, channelId: tap.channelId);

  static String? _text(String? s) => s == null || s.trim().isEmpty ? null : s;

  /// The tap a feature's own helpers understand (`MedsNotificationTaps`,
  /// `AdhanEvent.fromTap` …), optionally with one of its buttons.
  NotificationTap toTap({String? actionId}) =>
      NotificationTap(id: id, namespace: namespace, data: data, actionId: actionId, channelId: channelId, at: at);

  CenterNotice copyWith({DateTime? at, String? title, String? body}) => CenterNotice(
    id: id,
    namespace: namespace,
    at: at ?? this.at,
    data: data,
    title: title ?? this.title,
    body: body ?? this.body,
    channelId: channelId,
  );

  /// Fills texts this notice lacks from [other] (same firing).
  CenterNotice mergedWith(CenterNotice other) => CenterNotice(
    id: id,
    namespace: namespace ?? other.namespace,
    at: at ?? other.at,
    data: data.isEmpty ? other.data : data,
    title: title ?? other.title,
    body: body ?? other.body,
    channelId: channelId ?? other.channelId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'ns': ?namespace,
    if (at != null) 'at': at!.millisecondsSinceEpoch,
    if (data.isNotEmpty) 'd': data,
    't': ?title,
    'b': ?body,
    'c': ?channelId,
  };

  static CenterNotice? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! int) return null;
    final at = json['at'];
    final d = json['d'];
    String? s(Object? v) => v is String ? v : null;
    return CenterNotice(
      id: id,
      namespace: s(json['ns']),
      at: at is int ? DateTime.fromMillisecondsSinceEpoch(at, isUtc: true) : null,
      data: d is Map ? Map<String, Object?>.from(d) : const {},
      title: s(json['t']),
      body: s(json['b']),
      channelId: s(json['c']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CenterNotice &&
      other.id == id &&
      other.namespace == namespace &&
      other.at?.millisecondsSinceEpoch == at?.millisecondsSinceEpoch &&
      mapEquals(other.data, data) &&
      other.title == title &&
      other.body == body &&
      other.channelId == channelId;

  @override
  int get hashCode => Object.hash(id, namespace, at?.millisecondsSinceEpoch, title, body, channelId, data.length);

  @override
  String toString() => 'CenterNotice($namespace#$id @ ${at?.toIso8601String()} "$title")';
}

/// Where a notification of the center stands.
enum CenterItemState {
  /// Pending with the system, will arrive at its time.
  scheduled,

  /// Pending, but held back: its group is muted at its time.
  muted,

  /// Pending, but the user asked for this one not to arrive.
  skipped,

  /// Snoozed from the center; arrives again at [CenterItem.until].
  snoozed,

  /// Arrived and still shown in the system tray.
  live,

  /// Arrived (no longer in the tray, or never seen there).
  delivered,

  /// Its moment came while its group was muted: it never sounded.
  silenced,

  /// Snoozed from the center: it went away and comes back at
  /// [CenterItem.until].
  deferred,

  /// Opened (the notification or its row).
  opened,

  /// Answered with one of its buttons ([CenterItem.actionId]).
  acted;

  bool get isUpcoming => index <= snoozed.index;
}

/// One row of the center.
@immutable
class CenterItem {
  const CenterItem({
    required this.notice,
    required this.group,
    required this.state,
    this.unread = false,
    this.actionId,
    this.until,
    this.live = false,
  });

  final CenterNotice notice;
  final NotificationGroup group;
  final CenterItemState state;

  /// Arrived after the user last looked at the Recent tab and not handled.
  final bool unread;

  /// The button that answered it ([CenterItemState.acted]).
  final String? actionId;

  /// A snooze's new time, or the end of the mute holding it.
  final DateTime? until;

  /// Still in the system tray (its buttons can still act on it).
  final bool live;

  String get key => notice.key;
  int get id => notice.id;

  /// Its moment: when it fires (upcoming), fired (recent) or – snoozed –
  /// arrives again.
  DateTime get at => (state == CenterItemState.snoozed ? until : null) ?? notice.at ?? DateTime(1970);

  @override
  bool operator ==(Object other) =>
      other is CenterItem &&
      other.notice == notice &&
      other.group == group &&
      other.state == state &&
      other.unread == unread &&
      other.actionId == actionId &&
      other.until == until &&
      other.live == live;

  @override
  int get hashCode => Object.hash(notice, group, state, unread, actionId, until, live);

  @override
  String toString() => 'CenterItem(${group.name} ${state.name} ${notice.key})';
}

/// The items of one group, in time order.
@immutable
class CenterSection {
  const CenterSection({required this.group, required this.items, this.mutedUntil});

  final NotificationGroup group;
  final List<CenterItem> items;

  /// The group is muted until then.
  final DateTime? mutedUntil;

  int get count => items.length;
}
