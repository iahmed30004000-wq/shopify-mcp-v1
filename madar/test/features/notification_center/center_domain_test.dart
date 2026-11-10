import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/adhkar/domain/adhkar_models.dart';
import 'package:madar/features/notification_center/notification_center.dart';

import 'nc_fixtures.dart';

CenterNotice noticeOf(NotificationRequest r) =>
    CenterNotice.fromPayload(r.id, NotificationEnvelope.encode(r), title: r.title, body: r.body);

void main() {
  final registry = NotificationDescriberRegistry(builtInDescribers());
  final groupOf = registry.groupOf;
  final now = ncNow;

  group('notice', () {
    test('round-trips the envelope, the texts and JSON; a firing is id@instant', () {
      final r = adhkar(AdhkarCategoryId.morning, ncAt(1, 5, 30));
      final n = noticeOf(r);
      expect(n.id, r.id);
      expect(n.namespace, 'adhkar');
      expect(n.at, r.at.toUtc());
      expect(n.data, {'set': 'morning'});
      expect(n.title, r.title);
      expect(n.channelId, r.channelId);
      expect(n.key, '${r.id}@${r.at.millisecondsSinceEpoch}');
      expect(CenterNotice.atOfKey(n.key), r.at.toUtc());
      expect(CenterNotice.fromJson(n.toJson()), n);
      expect(CenterNotice.fromRequest(r), n);
      final tap = n.toTap(actionId: 'x');
      expect(tap.namespace, 'adhkar');
      expect(tap.actionId, 'x');
      expect(tap.data, {'set': 'morning'});
    });
  });

  group('layout', () {
    final pending = [
      noticeOf(adhanCall(AdhanSlot.maghrib, ncAt(0, 18, 12))),
      noticeOf(adhanCall(AdhanSlot.isha, ncAt(0, 19, 40))),
      noticeOf(medsDose(ncAt(0, 20))),
      noticeOf(adhkar(AdhkarCategoryId.morning, ncAt(1, 5, 30))),
      noticeOf(moneyDue(ncAt(3, 9))),
      noticeOf(travelDoc(ncAt(12, 10))), // beyond the week
      noticeOf(wird(ncAt(0, 12))), // already past
    ];

    test('upcoming: the next 7 days, soonest first, grouped by feature with counts', () {
      final items = CenterLayout.upcoming(pending: pending, policy: CenterPolicy.empty, groupOf: groupOf, now: now);
      expect(items.map((i) => i.group), [
        NotificationGroup.prayer,
        NotificationGroup.prayer,
        NotificationGroup.medications,
        NotificationGroup.adhkar,
        NotificationGroup.money,
      ]);
      expect(items.every((i) => i.state == CenterItemState.scheduled), isTrue);
      final sections = CenterLayout.sections(items, policy: CenterPolicy.empty, now: now);
      expect(sections.map((s) => (s.group, s.count)), [
        (NotificationGroup.prayer, 2),
        (NotificationGroup.medications, 1),
        (NotificationGroup.adhkar, 1),
        (NotificationGroup.money, 1),
      ]);
    });

    test('muted and skipped items stay listed, marked; snoozed ones appear at their new time', () {
      final dose = pending[2];
      final policy = CenterPolicy.empty
          .mute(NotificationGroup.prayer, ncAt(0, 19))
          .skip(dose)
          .snooze(SnoozedNotice(notice: noticeOf(wird(ncAt(0, 12))), until: ncAt(0, 13, 40)));
      final items = CenterLayout.upcoming(pending: pending, policy: policy, groupOf: groupOf, now: now);
      final byKind = {for (final i in items) i.notice.key: i};
      expect(items.first.group, NotificationGroup.wird);
      expect(items.first.state, CenterItemState.snoozed);
      expect(items.first.at, ncAt(0, 13, 40));
      expect(byKind[pending[0].key]!.state, CenterItemState.muted, reason: 'Maghrib is inside the mute');
      expect(byKind[pending[0].key]!.until, ncAt(0, 19));
      expect(byKind[pending[1].key]!.state, CenterItemState.scheduled, reason: 'Isha is after it');
      expect(byKind[dose.key]!.state, CenterItemState.skipped);
      final sections = CenterLayout.sections(items, policy: policy, now: now);
      expect(sections.firstWhere((s) => s.group == NotificationGroup.prayer).mutedUntil, ncAt(0, 19));
      expect(sections.firstWhere((s) => s.group == NotificationGroup.money).mutedUntil, isNull);
    });

    test('recent: history and the tray, newest first; live, unread and handled', () {
      final seenAt = ncAt(0, 9);
      final shownDose = noticeOf(medsDose(ncAt(0, 12, 50)));
      final oldAdhkar = noticeOf(adhkar(AdhkarCategoryId.morning, ncAt(0, 5, 30)));
      final opened = noticeOf(appointment(ncAt(0, 11)));
      final hidden = noticeOf(moneyDue(ncAt(0, 10)));
      final history = const NotificationHistory().recordAll([
        // Recorded when it arrived (before the last look).
        HistoryEntry(notice: oldAdhkar, status: HistoryStatus.delivered, recordedAt: ncAt(0, 5, 31)),
        HistoryEntry(notice: opened, status: HistoryStatus.opened, recordedAt: now),
        HistoryEntry(notice: hidden, status: HistoryStatus.delivered, recordedAt: now, hidden: true),
      ], now: now);
      final items = CenterLayout.recent(
        history: history,
        active: [shownDose],
        policy: CenterPolicy.empty,
        groupOf: groupOf,
        seenAt: seenAt,
        now: now,
      );
      expect(items.map((i) => i.notice.key), [shownDose.key, opened.key, oldAdhkar.key]);
      expect(items[0].state, CenterItemState.live);
      expect(items[0].live, isTrue);
      expect(items[0].unread, isTrue);
      expect(items[1].state, CenterItemState.opened);
      expect(items[1].unread, isFalse, reason: 'opened = handled');
      expect(items[2].unread, isFalse, reason: 'arrived before the tab was last seen');
      expect(CenterLayout.unread(items), 1);
    });
  });

  group('history', () {
    // Recorded when it arrived (the center records arrivals as it sees them).
    HistoryEntry entry(int i, {HistoryStatus status = HistoryStatus.delivered, DateTime? at}) => HistoryEntry(
      notice: CenterNotice(
        id: 110000 + i,
        namespace: 'adhkar',
        at: at ?? now.subtract(Duration(minutes: i)),
      ),
      status: status,
      recordedAt: at ?? now.subtract(Duration(minutes: i)),
    );

    test('is bounded: at most maxEntries, newest kept, nothing older than two weeks', () {
      var h = NotificationHistory.empty;
      for (var i = 0; i < NotificationHistory.maxEntries + 40; i++) {
        h = h.record(entry(i), now: now);
      }
      expect(h.length, NotificationHistory.maxEntries);
      expect(h.entries.first.notice.id, 110000, reason: 'the newest');
      expect(h.entries.last.notice.id, 110000 + NotificationHistory.maxEntries - 1);
      h = h.record(entry(999, at: now.subtract(const Duration(days: 15))), now: now);
      expect(h.contains(entry(999, at: now.subtract(const Duration(days: 15))).key), isFalse);
      // Two weeks less an hour later, only the last hour's 61 entries are left.
      final later = h.bounded(now.add(const Duration(days: 14)).subtract(const Duration(minutes: 60)));
      expect(later.length, 61);
      expect(later.entries.every((e) => !e.at.isBefore(now.subtract(const Duration(minutes: 60)))), isTrue);
    });

    test('one entry per firing; statuses only move up; texts merge; hidden stays hidden', () {
      final bare = entry(1);
      var h = NotificationHistory.empty.record(bare, now: now);
      h = h.record(
        bare.copyWith(
          notice: bare.notice.copyWith(title: 'Morning adhkar'),
          status: HistoryStatus.acted,
          actionId: 'a',
        ),
        now: now,
      );
      h = h.record(bare, now: now); // a late "delivered" never erases the answer
      expect(h.length, 1);
      expect(h[bare.key]!.status, HistoryStatus.acted);
      expect(h[bare.key]!.actionId, 'a');
      expect(h[bare.key]!.notice.title, 'Morning adhkar');
      h = h.hide([bare.key]);
      expect(h.visible, isEmpty);
      h = h.record(bare.copyWith(status: HistoryStatus.acted), now: now);
      expect(h[bare.key]!.hidden, isTrue);
      final restored = h.restore([bare]);
      expect(restored.visible.single.status, HistoryStatus.delivered);
    });

    test('unread: not handled, after the last look, not in the future', () {
      final h = NotificationHistory.empty.recordAll([
        entry(1),
        entry(2, status: HistoryStatus.opened),
        entry(3, status: HistoryStatus.silenced),
        entry(200),
        entry(4, at: now.add(const Duration(hours: 1))),
      ], now: now);
      final unread = h.unread(seenAt: now.subtract(const Duration(minutes: 100)), now: now);
      expect(unread.map((e) => e.notice.id), [110001, 110003]);
      // Due before the last look but only recorded after it (Doze delayed
      // the alarm; the center saw it late): the user has not seen it.
      final late = h.record(
        HistoryEntry(
          notice: const CenterNotice(
            id: 110300,
            namespace: 'adhkar',
          ).copyWith(at: now.subtract(const Duration(hours: 3))),
          status: HistoryStatus.delivered,
          recordedAt: now.subtract(const Duration(minutes: 5)),
        ),
        now: now,
      );
      expect(late.unread(seenAt: now.subtract(const Duration(minutes: 100)), now: now).map((e) => e.notice.id), [
        110001,
        110003,
        110300,
      ]);
    });

    test('survives JSON, ignoring junk', () {
      final h = NotificationHistory.empty.recordAll([entry(1), entry(2, status: HistoryStatus.acted)], now: now);
      expect(NotificationHistory.fromJson(h.toJson()), h);
      expect(NotificationHistory.fromJson([...h.toJson(), 'junk', {}]).length, 2);
      expect(NotificationHistory.fromJson('nope'), NotificationHistory.empty);
    });
  });

  group('policy', () {
    final n = noticeOf(medsDose(ncAt(0, 20)));

    test('a mute holds what is due before its end, not after', () {
      final p = CenterPolicy.empty.mute(NotificationGroup.medications, ncAt(0, 21));
      expect(p.mutes(NotificationGroup.medications, ncAt(0, 20)), isTrue);
      expect(p.mutes(NotificationGroup.medications, ncAt(0, 21)), isFalse);
      expect(p.mutes(NotificationGroup.prayer, ncAt(0, 20)), isFalse);
      expect(p.holdOf(n, NotificationGroup.medications, now: now), CenterItemState.muted);
      expect(p.muteOf(NotificationGroup.medications, now), ncAt(0, 21));
      expect(p.muteOf(NotificationGroup.medications, ncAt(0, 21)), isNull);
      expect(p.unmute(NotificationGroup.medications).holdOf(n, NotificationGroup.medications, now: now), isNull);
    });

    test('skips are per firing; pruning forgets what is over', () {
      final p = CenterPolicy.empty
          .skip(n)
          .mute(NotificationGroup.family, ncAt(0, 14))
          .snooze(SnoozedNotice(notice: n, until: ncAt(0, 13, 30)));
      expect(p.skips(n), isTrue);
      expect(p.skips(n.copyWith(at: ncAt(1, 20).toUtc())), isFalse, reason: 'tomorrow is another firing');
      final later = p.pruned(ncAt(0, 22));
      expect(later.isEmpty, isTrue);
      expect(p.pruned(now), p);
    });

    test('survives JSON', () {
      final p = CenterPolicy.empty
          .skip(n)
          .mute(NotificationGroup.prayer, ncAt(1, 7))
          .snooze(SnoozedNotice(notice: n, until: ncAt(0, 14)));
      expect(CenterPolicy.fromJson(p.toJson()), p);
      expect(CenterPolicy.fromJson(null), CenterPolicy.empty);
    });

    test('mute lengths', () {
      expect(MuteLength.hour.endFrom(now), now.add(const Duration(hours: 1)));
      expect(MuteLength.fourHours.endFrom(now), now.add(const Duration(hours: 4)));
      expect(MuteLength.untilMorning.endFrom(now), DateTime(2026, 10, 1, 7));
      expect(MuteLength.untilMorning.endFrom(DateTime(2026, 9, 30, 1, 30)), DateTime(2026, 9, 30, 7));
      expect(MuteLength.week.endFrom(now), now.add(const Duration(days: 7)));
    });
  });
}
