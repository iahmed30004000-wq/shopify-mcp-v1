import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_envelope.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/core/notifications/notification_service.dart';
import 'package:madar/features/adhkar/adhkar.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';

import 'adhkar_harness.dart';

Uint8List _mp3Frames(int frames, {bool xing = false, int xingFrames = 0, bool id3 = false}) {
  const frameLen = 417; // 128 kbps, 44.1 kHz, MPEG-1 Layer III
  final b = BytesBuilder();
  if (id3) {
    b.add([...ascii.encode('ID3'), 3, 0, 0, 0, 0, 0, 10]);
    b.add(List.filled(10, 0));
  }
  for (var f = 0; f < frames; f++) {
    final frame = Uint8List(frameLen);
    frame.setAll(0, [0xFF, 0xFB, 0x90, 0x44]);
    if (xing && f == 0) {
      frame.setAll(4 + 32, ascii.encode('Xing'));
      frame.setAll(4 + 36, [0, 0, 0, 1]);
      frame.setAll(4 + 40, [
        (xingFrames >> 24) & 255,
        (xingFrames >> 16) & 255,
        (xingFrames >> 8) & 255,
        xingFrames & 255,
      ]);
    }
    b.add(frame);
  }
  return b.toBytes();
}

Uint8List _flac({int sampleRate = 44100, int totalSamples = 88200}) {
  final info = Uint8List(34);
  info[10] = (sampleRate >> 12) & 0xFF;
  info[11] = (sampleRate >> 4) & 0xFF;
  info[12] = ((sampleRate & 0xF) << 4) | (1 << 1);
  info[13] = 0xF0 | ((totalSamples >> 32) & 0xF);
  info.setAll(14, [
    (totalSamples >> 24) & 255,
    (totalSamples >> 16) & 255,
    (totalSamples >> 8) & 255,
    totalSamples & 255,
  ]);
  return Uint8List.fromList([...ascii.encode('fLaC'), 0x00, 0x00, 0x00, 34, ...info, ...List.filled(64, 0)]);
}

DayTimes _day(DateTime d) => DayTimes(
  day: d,
  fajr: DateTime(d.year, d.month, d.day, 4, 50),
  sunrise: DateTime(d.year, d.month, d.day, 6, 12),
  dhuhr: DateTime(d.year, d.month, d.day, 11, 55),
  asr: DateTime(d.year, d.month, d.day, 15, 20),
  maghrib: DateTime(d.year, d.month, d.day, 17, 45),
  isha: DateTime(d.year, d.month, d.day, 19, 5),
);

void main() {
  group('audio probe', () {
    test('WAV: format and length from the header', () {
      final wav = silentWav(samples: 16000); // 2 s at 8 kHz, 8-bit mono
      expect(AudioProbe.sniff(wav), DhikrAudioFormat.wav);
      expect(AudioProbe.duration(wav), const Duration(seconds: 2));
    });

    test('MP3: constant bit rate estimate, Xing frame count, ID3 skipped', () {
      final cbr = _mp3Frames(100);
      expect(AudioProbe.sniff(cbr), DhikrAudioFormat.mp3);
      expect(AudioProbe.duration(cbr)!.inMilliseconds, closeTo(100 * 1152 / 44.1, 30));
      final vbr = _mp3Frames(3, xing: true, xingFrames: 1000, id3: true);
      expect(AudioProbe.sniff(vbr), DhikrAudioFormat.mp3);
      expect(AudioProbe.duration(vbr)!.inMilliseconds, closeTo(1000 * 1152 / 44.1, 2));
    });

    test('FLAC: STREAMINFO total samples over the sample rate', () {
      final flac = _flac();
      expect(AudioProbe.sniff(flac), DhikrAudioFormat.flac);
      expect(AudioProbe.duration(flac), const Duration(seconds: 2));
    });

    test('anything else is unsupported', () {
      expect(AudioProbe.sniff(Uint8List.fromList(utf8.encode('OggS not really audio at all'))), isNull);
      expect(AudioProbe.sniff(Uint8List(4)), isNull);
      expect(AudioProbe.duration(Uint8List(100)), isNull);
    });
  });

  group('reminders', () {
    test('morning after Fajr and evening after Asr, only ahead of now, in order', () {
      final now = DateTime(2026, 9, 28, 10, 0);
      final plan = AdhkarReminderPlanner.plan(
        settings: const AdhkarReminderSettings(
          morning: true,
          evening: true,
          morningOffsetMin: 20,
          eveningOffsetMin: 30,
        ),
        timesFor: _day,
        now: now,
        days: 2,
      );
      expect(plan.map((r) => (r.category, r.at)), [
        (AdhkarCategoryId.evening, DateTime(2026, 9, 28, 15, 50)),
        (AdhkarCategoryId.morning, DateTime(2026, 9, 29, 5, 10)),
        (AdhkarCategoryId.evening, DateTime(2026, 9, 29, 15, 50)),
      ]);
      expect(plan.first.id, 'adhkar.evening.2026-09-28');
      expect(
        plan.first.notificationId,
        AdhkarReminder(category: AdhkarCategoryId.evening, at: plan.first.at).notificationId,
      );
      expect(plan.map((r) => r.notificationId).toSet(), hasLength(3));
    });

    test('notification ids sit in the adhkar id block, unique and stable across a year of plans', () {
      final seen = <int, String>{};
      for (var d = 0; d < AdhkarReminder.idCycleDays; d++) {
        for (final c in [AdhkarCategoryId.morning, AdhkarCategoryId.evening]) {
          final r = AdhkarReminder(category: c, at: DateTime(2026, 9, 28 + d, c == AdhkarCategoryId.morning ? 5 : 15));
          expect(NotificationNamespaces.adhkar.contains(r.notificationId), isTrue, reason: r.id);
          expect(seen[r.notificationId], isNull, reason: '${r.id} collides with ${seen[r.notificationId]}');
          seen[r.notificationId] = r.id;
        }
      }
      // The same reminder re-planned later keeps its id (the service then
      // leaves the pending alarm alone).
      final a = AdhkarReminder(category: AdhkarCategoryId.morning, at: DateTime(2026, 10, 1, 5, 10));
      final b = AdhkarReminder(category: AdhkarCategoryId.morning, at: DateTime(2026, 10, 1, 5, 30));
      expect(a.notificationId, b.notificationId);
    });

    group('through the notification service', () {
      late FakeNotificationPlatform platform;
      late NotificationService service;
      late NotificationAdhkarReminderScheduler scheduler;
      final now = DateTime(2026, 9, 28, 10, 0);
      final plan = AdhkarReminderPlanner.plan(
        settings: const AdhkarReminderSettings(morning: true, evening: true),
        timesFor: _day,
        now: now,
      );
      final notices = [
        for (final r in plan) AdhkarReminderNotice(reminder: r, title: 'T ${r.category.name}', body: 'B'),
      ];

      setUp(() {
        platform = FakeNotificationPlatform();
        service = NotificationService(platform, clock: () => now);
        scheduler = NotificationAdhkarReminderScheduler(
          notifications: service,
          texts: () => (group: 'الأذكار', name: 'تذكير الأذكار', description: 'بعد الفجر وبعد العصر'),
        );
      });

      test('a week of reminders is scheduled on its channel; re-planning changes nothing', () async {
        expect(notices, hasLength(13));
        await scheduler.replaceAll(notices);
        expect(platform.scheduled.keys.toSet(), {for (final n in notices) n.id});
        final channel = platform.channels[NotificationAdhkarReminderScheduler.channelId]!;
        expect(channel.name, 'تذكير الأذكار');
        expect(channel.importance, NotificationImportance.high);
        final first = platform.scheduled[notices.first.id]!.request;
        expect(first.at, notices.first.at);
        expect(first.title, 'T evening');
        expect(first.data, {'set': 'evening'});
        expect(first.category, NotificationCategory.reminder);
        final log = platform.scheduleLog.length;
        await scheduler.replaceAll(notices);
        expect(platform.scheduleLog.length, log, reason: 'identical reminders are left alone');
        await scheduler.replaceAll(notices.where((n) => n.reminder.category == AdhkarCategoryId.morning).toList());
        expect(platform.scheduled.values.every((f) => f.request.data['set'] == 'morning'), isTrue);
        await scheduler.cancelAll();
        expect(platform.scheduled, isEmpty);
      });

      test('a tap opens the reminded set; other features\' taps are ignored', () {
        final request = NotificationAdhkarReminderScheduler.requestFor(notices.first);
        final tap = NotificationEnvelope.decode(NotificationEnvelope.encode(request), id: request.id);
        expect(AdhkarReminderTaps.categoryOf(tap), AdhkarCategoryId.evening);
        expect(
          AdhkarReminderTaps.categoryOf(const NotificationTap(id: 1, namespace: 'adhan', data: {'set': 'morning'})),
          isNull,
        );
      });

      test('permission: asked only when notifications are off', () async {
        expect(await scheduler.ensurePermission(), isTrue);
        expect(platform.requestNotificationsCalls, 0);
        platform.enabled = false;
        expect(await scheduler.ensurePermission(), isFalse);
        expect(platform.requestNotificationsCalls, 1);
      });
    });

    test('nothing when both are off (the fresh-install default)', () {
      expect(
        AdhkarReminderPlanner.plan(settings: const AdhkarReminderSettings(), timesFor: _day, now: DateTime(2026)),
        isEmpty,
      );
    });

    test('settings JSON is tolerant', () {
      const s = AdhkarReminderSettings(morning: true, eveningOffsetMin: 45);
      expect(AdhkarReminderSettings.fromJson(s.toJson()), s);
      expect(
        AdhkarReminderSettings.fromJson({'morning': 'yes', 'morningOffsetMin': 999}),
        const AdhkarReminderSettings(),
      );
      expect(AdhkarReminderSettings.fromJson(null), const AdhkarReminderSettings());
      // "At the adhan" is no longer offered (it would chime over the adhan):
      // a stored 0 moves to the nearest choice.
      expect(AdhkarReminderSettings.fromJson({'morning': true, 'morningOffsetMin': 0}).morningOffsetMin, 10);
      expect(AdhkarReminderSettings.offsets.every((m) => m >= 10), isTrue);
    });
  });
}
