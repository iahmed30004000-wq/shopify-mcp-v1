import 'center_models.dart';
import 'center_policy.dart';
import 'notification_history.dart';

/// Classifies a notice into its group (the describer registry's
/// `groupOf`).
typedef GroupOf = NotificationGroup Function(CenterNotice notice);

/// Builds the center's two lists and their group sections from what the
/// platform reports, the policy and the history (pure – unit-tested).
abstract final class CenterLayout {
  /// How far ahead Upcoming looks.
  static const Duration horizon = Duration(days: 7);

  /// The upcoming notifications: every pending one due within [horizon] –
  /// muted or skipped ones marked as such (they are held back, not gone) –
  /// and the snoozed ones at their new time; soonest first.
  static List<CenterItem> upcoming({
    required Iterable<CenterNotice> pending,
    required CenterPolicy policy,
    required GroupOf groupOf,
    required DateTime now,
    Duration horizon = CenterLayout.horizon,
  }) {
    final end = now.add(horizon);
    bool inWindow(DateTime at) => at.isAfter(now) && !at.isAfter(end);
    final out = <CenterItem>[];
    final keys = <String>{};
    for (final s in policy.snoozed.values) {
      if (!inWindow(s.until)) continue;
      final n = s.again;
      if (!keys.add(n.key)) continue;
      out.add(CenterItem(notice: n, group: groupOf(n), state: CenterItemState.snoozed, until: s.until));
    }
    for (final n in pending) {
      final at = n.at;
      if (at == null || !inWindow(at) || !keys.add(n.key)) continue;
      final group = groupOf(n);
      final hold = policy.holdOf(n, group, now: now);
      out.add(
        CenterItem(
          notice: n,
          group: group,
          state: hold ?? CenterItemState.scheduled,
          until: hold == CenterItemState.muted ? policy.mutedUntil[group] : null,
        ),
      );
    }
    out.sort(_soonestFirst);
    return out;
  }

  /// The recent notifications: the history's visible entries (live while
  /// still in the tray) and anything shown the history has not recorded
  /// yet; newest first. Unread: not handled, and arrived – or first
  /// reached the center (an alarm Doze delayed past its moment) – after
  /// [seenAt].
  static List<CenterItem> recent({
    required NotificationHistory history,
    required Iterable<CenterNotice> active,
    required CenterPolicy policy,
    required GroupOf groupOf,
    required DateTime seenAt,
    required DateTime now,
  }) {
    final activeKeys = <String>{};
    final idsOnly = <int>{};
    for (final a in active) {
      a.at == null ? idsOnly.add(a.id) : activeKeys.add(a.key);
    }
    bool isLive(CenterNotice n) => activeKeys.contains(n.key) || idsOnly.contains(n.id);
    bool isNew(DateTime at) => at.isAfter(seenAt) && !at.isAfter(now);

    final out = <CenterItem>[];
    final keys = <String>{};
    for (final e in history.entries) {
      keys.add(e.key);
      if (e.hidden) continue;
      final live = isLive(e.notice);
      final state = switch (e.status) {
        HistoryStatus.delivered => live ? CenterItemState.live : CenterItemState.delivered,
        HistoryStatus.silenced => CenterItemState.silenced,
        HistoryStatus.snoozed => CenterItemState.deferred,
        HistoryStatus.opened => CenterItemState.opened,
        HistoryStatus.acted => CenterItemState.acted,
      };
      out.add(
        CenterItem(
          notice: e.notice,
          group: groupOf(e.notice),
          state: state,
          unread: !e.status.handled && (isNew(e.at) || (e.recordedAt.isAfter(seenAt) && !e.at.isAfter(now))),
          actionId: e.actionId,
          until: e.status == HistoryStatus.snoozed ? policy.snoozed[e.notice.id]?.until : null,
          live: live,
        ),
      );
    }
    for (final a in active) {
      if (a.at == null || keys.contains(a.key)) continue;
      keys.add(a.key);
      out.add(CenterItem(notice: a, group: groupOf(a), state: CenterItemState.live, unread: isNew(a.at!), live: true));
    }
    out.sort((a, b) => _soonestFirst(b, a));
    return out;
  }

  /// [items] by group, each group in the items' order. Upcoming sections
  /// are ordered by their soonest item (what comes next is on top), recent
  /// ones by their newest.
  static List<CenterSection> sections(List<CenterItem> items, {required CenterPolicy policy, required DateTime now}) {
    final byGroup = <NotificationGroup, List<CenterItem>>{};
    for (final item in items) {
      (byGroup[item.group] ??= []).add(item);
    }
    // Map iteration follows insertion: the first item of each group decides
    // its place, and [items] is already in the list's order.
    return [
      for (final e in byGroup.entries)
        CenterSection(group: e.key, items: List.unmodifiable(e.value), mutedUntil: policy.muteOf(e.key, now)),
    ];
  }

  /// How many recent items are new.
  static int unread(Iterable<CenterItem> recent) => recent.where((i) => i.unread).length;

  static int _soonestFirst(CenterItem a, CenterItem b) {
    final c = a.at.compareTo(b.at);
    return c != 0 ? c : a.id.compareTo(b.id);
  }
}
