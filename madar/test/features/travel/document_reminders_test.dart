import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/core/notifications/notification_service.dart';
import 'package:madar/features/travel/data/travel_notifications.dart';
import 'package:madar/features/travel/domain/document_reminders.dart';
import 'package:madar/features/travel/domain/documents.dart';
import 'package:madar/features/travel/travel_texts.dart';

void main() {
  final now = DateTime(2026, 9, 29, 13, 10);
  DocFacts doc(String id, DateTime? expiry, {int remind = 30, String? name, String? holder}) =>
      DocFacts(id: id, name: name ?? id, expiry: expiry, remindDaysBefore: remind, holder: holder);

  group('planning', () {
    test('one reminder N days ahead and one on the day, at 10:00', () {
      final plans = DocumentReminderPlanner.plan([doc('passport', DateTime(2027, 1, 15))], now: now);
      expect(plans.map((p) => p.at), [DateTime(2026, 12, 16, 10), DateTime(2027, 1, 15, 10)]);
      expect(plans.map((p) => p.kind), [DocumentReminderKind.ahead, DocumentReminderKind.onDay]);
      expect(plans.first.daysLeft, 30);
      expect(plans.map((p) => p.id), [138000, 138001]);
    });

    test('only moments still ahead; no date, no reminder', () {
      final plans = DocumentReminderPlanner.plan([
        doc('a', DateTime(2026, 10, 10)), // 30 days ahead is already past
        doc('b', null),
        doc('c', DateTime(2026, 9, 1)), // expired
        doc('d', DateTime(2026, 9, 29)), // expires today at 10:00 – past
      ], now: now);
      expect(plans.map((p) => (p.doc.id, p.kind)), [('a', DocumentReminderKind.onDay)]);
    });

    test('"only on the day" skips the early one; each document keeps its slot', () {
      final plans = DocumentReminderPlanner.plan([
        doc('a', DateTime(2027, 5, 1), remind: 0),
        doc('b', DateTime(2027, 2, 1), remind: 7),
      ], now: now);
      expect(plans.map((p) => (p.doc.id, p.id)), [('b', 138002), ('b', 138003), ('a', 138001)]);
      expect(plans.every((p) => TravelReminderIds.owns(p.id)), isTrue);
      expect(plans.every((p) => TravelReminderIds.namespace.contains(p.id)), isTrue);
    });
  });

  group('scheduling through NotificationService', () {
    late FakeNotificationPlatform platform;
    late NotificationService service;
    late TravelDocumentNotifier notifier;

    setUp(() {
      platform = FakeNotificationPlatform();
      service = NotificationService(platform, clock: () => now);
      notifier = TravelDocumentNotifier(notifications: service, texts: () => TravelTexts.forLanguage('ar'));
    });

    tearDown(() => service.dispose());

    NotificationRequest foreign(int id) => NotificationRequest(
      namespace: NotificationNamespaces.reminders,
      id: id,
      channelId: 'madar.family.digest',
      title: 'other feature',
      body: 'kept',
      at: now.add(const Duration(days: 2)),
    );

    test('schedules Arabic texts on its own channel', () async {
      final report = await notifier.sync([
        doc('p', DateTime(2027, 1, 15), name: 'جواز السفر', holder: 'أنا'),
      ], now: now);
      expect(report.scheduled, 2);
      expect(platform.channels.keys, contains(TravelDocumentNotifier.channelId));
      final ahead = platform.scheduled[138000]!.request;
      expect(ahead.title, contains('جواز السفر'));
      expect(ahead.title, contains('٣٠'));
      expect(ahead.body, contains('٢٠٢٧'));
      expect(ahead.data['documentId'], 'p');
      expect(ahead.at, DateTime(2026, 12, 16, 10));
      expect(platform.scheduled[138001]!.request.body, contains('اليوم'));
    });

    test('re-planning cancels what is gone and leaves other features alone', () async {
      await service.schedule(foreign(130005));
      await notifier.sync([doc('a', DateTime(2027, 1, 15)), doc('b', DateTime(2027, 3, 1))], now: now);
      expect(platform.scheduled.keys, containsAll([130005, 138000, 138001, 138002, 138003]));

      // "b" deleted, "a" renewed: slot 1 disappears, slot 0 moves.
      final report = await notifier.sync([doc('a', DateTime(2028, 1, 15))], now: now);
      expect(report.cancelled, greaterThanOrEqualTo(2));
      expect(platform.scheduled.keys, containsAll([130005, 138000, 138001]));
      expect(platform.scheduled.containsKey(138002), isFalse);
      expect(platform.scheduled[138001]!.request.at, DateTime(2028, 1, 15, 10));

      // Unchanged plan: nothing rescheduled.
      final again = await notifier.sync([doc('a', DateTime(2028, 1, 15))], now: now);
      expect(again.scheduled, 0);
      expect(again.unchanged, 2);

      await notifier.cancelAll();
      expect(platform.scheduled.keys, [130005]);
    });

    test('English texts', () async {
      final en = TravelDocumentNotifier(notifications: service, texts: () => TravelTexts.forLanguage('en'));
      await en.sync([doc('v', DateTime(2026, 11, 10), name: 'Visa', remind: 14)], now: now);
      final r = platform.scheduled[138000]!.request;
      expect(BidiIsolate.strip(r.title), 'Visa: Expires in 14 days');
      expect(r.at, DateTime(2026, 10, 27, 10));
    });

    test('a tapped travel reminder names its document', () {
      final tap = NotificationTap(
        id: 138000,
        namespace: NotificationNamespaces.reminders.name,
        data: const {'feature': 'travel', 'documentId': 'p'},
      );
      expect(TravelReminderTaps.documentOf(tap), 'p');
      expect(
        TravelReminderTaps.documentOf(
          NotificationTap(id: 130001, namespace: NotificationNamespaces.reminders.name, data: const {}),
        ),
        isNull,
      );
    });
  });
}
