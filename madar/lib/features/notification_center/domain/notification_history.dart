import 'package:flutter/foundation.dart';

import 'center_models.dart';

/// What happened to a notification that arrived (or should have).
enum HistoryStatus {
  /// It reached the tray (seen shown, or its moment passed).
  delivered,

  /// Its moment came while its group was muted: it never sounded.
  silenced,

  /// Snoozed from the center (it arrives again later as a new firing).
  snoozed,

  /// Opened – from the tray or the center.
  opened,

  /// Answered with one of its buttons.
  acted;

  /// A later record replaces an earlier one only when it ranks at least as
  /// high – a late "delivered" never erases an answer.
  int get rank => index;

  /// The user already dealt with it (it is not "new").
  bool get handled => this == snoozed || this == opened || this == acted;

  static HistoryStatus? byName(Object? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// One firing in the center's history.
@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.notice,
    required this.status,
    required this.recordedAt,
    this.actionId,
    this.hidden = false,
  });

  final CenterNotice notice;
  final HistoryStatus status;

  /// When the entry was last written.
  final DateTime recordedAt;

  /// The button that answered it ([HistoryStatus.acted]).
  final String? actionId;

  /// Dismissed or cleared from the center. Kept (until it ages out) so the
  /// same firing is never listed again.
  final bool hidden;

  String get key => notice.key;

  /// When it arrived (its scheduled moment, or when it was first recorded).
  DateTime get at => notice.at ?? recordedAt;

  HistoryEntry copyWith({
    CenterNotice? notice,
    HistoryStatus? status,
    DateTime? recordedAt,
    String? actionId,
    bool? hidden,
  }) => HistoryEntry(
    notice: notice ?? this.notice,
    status: status ?? this.status,
    recordedAt: recordedAt ?? this.recordedAt,
    actionId: actionId ?? this.actionId,
    hidden: hidden ?? this.hidden,
  );

  Map<String, Object?> toJson() => {
    'n': notice.toJson(),
    's': status.name,
    'r': recordedAt.millisecondsSinceEpoch,
    'a': ?actionId,
    if (hidden) 'h': 1,
  };

  static HistoryEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final notice = CenterNotice.fromJson(json['n']);
    final status = HistoryStatus.byName(json['s']);
    final r = json['r'];
    if (notice == null || status == null || r is! int) return null;
    final a = json['a'];
    return HistoryEntry(
      notice: notice,
      status: status,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(r),
      actionId: a is String ? a : null,
      hidden: json['h'] == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HistoryEntry &&
      other.notice == notice &&
      other.status == status &&
      other.recordedAt == recordedAt &&
      other.actionId == actionId &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(notice, status, recordedAt, actionId, hidden);

  @override
  String toString() => 'HistoryEntry(${notice.key} ${status.name}${hidden ? ' hidden' : ''})';
}

/// The center's bounded, in-app log of notifications that arrived and what
/// became of them (pure – persisted by `NotificationCenterStore`).
///
/// * One entry per firing ([CenterNotice.key]); re-recording updates it and
///   never downgrades its status ([HistoryStatus.rank]).
/// * At most [maxEntries] entries and nothing older than [maxAge] – the
///   oldest go first – so the stored JSON stays small.
@immutable
class NotificationHistory {
  const NotificationHistory([this.entries = const []]);

  static const int maxEntries = 150;
  static const Duration maxAge = Duration(days: 14);

  /// Newest first.
  final List<HistoryEntry> entries;

  static const empty = NotificationHistory();

  bool get isEmpty => entries.isEmpty;
  int get length => entries.length;

  /// The entries the center lists (not dismissed / cleared).
  List<HistoryEntry> get visible => [
    for (final e in entries)
      if (!e.hidden) e,
  ];

  HistoryEntry? operator [](String key) {
    for (final e in entries) {
      if (e.key == key) return e;
    }
    return null;
  }

  bool contains(String key) => this[key] != null;

  /// Adds [entry] or updates the entry of the same firing: texts missing on
  /// either side are merged; the status (and its action) change only when
  /// the new one ranks at least as high; a hidden entry stays hidden.
  NotificationHistory record(HistoryEntry entry, {required DateTime now}) {
    final i = entries.indexWhere((e) => e.key == entry.key);
    if (i < 0) return NotificationHistory([entry, ...entries]).bounded(now);
    final old = entries[i];
    final upgrade = entry.status.rank >= old.status.rank && entry.status != HistoryStatus.delivered;
    final merged = old.copyWith(
      notice: old.notice.mergedWith(entry.notice),
      status: upgrade ? entry.status : old.status,
      actionId: upgrade ? entry.actionId : old.actionId,
      recordedAt: upgrade ? entry.recordedAt : old.recordedAt,
    );
    if (merged == old) return this;
    final list = [...entries]..[i] = merged;
    return NotificationHistory(list);
  }

  /// Records a batch (see [record]).
  NotificationHistory recordAll(Iterable<HistoryEntry> batch, {required DateTime now}) {
    var h = this;
    for (final e in batch) {
      h = h.record(e, now: now);
    }
    return h;
  }

  /// Hides the entries of [keys] (dismiss / clear all).
  NotificationHistory hide(Iterable<String> keys) {
    final set = keys.toSet();
    if (!entries.any((e) => set.contains(e.key) && !e.hidden)) return this;
    return NotificationHistory([for (final e in entries) set.contains(e.key) ? e.copyWith(hidden: true) : e]);
  }

  /// Puts [previous] entries back as they were (undo of a dismiss / clear).
  NotificationHistory restore(Iterable<HistoryEntry> previous) {
    final byKey = {for (final e in previous) e.key: e};
    if (byKey.isEmpty) return this;
    final list = [for (final e in entries) byKey.remove(e.key) ?? e, ...byKey.values];
    list.sort(_newestFirst);
    return NotificationHistory(list);
  }

  /// Drops what aged out and keeps the newest [maxEntries].
  NotificationHistory bounded(DateTime now) {
    final oldest = now.subtract(maxAge);
    final list = [
      for (final e in entries)
        if (!e.at.isBefore(oldest)) e,
    ]..sort(_newestFirst);
    if (list.length > maxEntries) list.removeRange(maxEntries, list.length);
    if (list.length == entries.length && listEquals(list, entries)) return this;
    return NotificationHistory(list);
  }

  /// Not yet dealt with and arrived – or first recorded – after [seenAt]
  /// (when the user last looked at the Recent tab), up to [now].
  List<HistoryEntry> unread({required DateTime seenAt, required DateTime now}) => [
    for (final e in entries)
      if (!e.hidden &&
          !e.status.handled &&
          (e.at.isAfter(seenAt) || e.recordedAt.isAfter(seenAt)) &&
          !e.at.isAfter(now))
        e,
  ];

  static int _newestFirst(HistoryEntry a, HistoryEntry b) {
    final c = b.at.compareTo(a.at);
    return c != 0 ? c : b.notice.id.compareTo(a.notice.id);
  }

  List<Object?> toJson() => [for (final e in entries) e.toJson()];

  static NotificationHistory fromJson(Object? json) {
    if (json is! List) return empty;
    final list = [for (final raw in json) ?HistoryEntry.fromJson(raw)]..sort(_newestFirst);
    return NotificationHistory(list);
  }

  @override
  bool operator ==(Object other) => other is NotificationHistory && listEquals(other.entries, entries);

  @override
  int get hashCode => Object.hashAll(entries);
}
