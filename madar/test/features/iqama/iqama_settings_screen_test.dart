// The «الإقامة» settings screen in Arabic and in English: the five
// offsets, Friday's own, each prayer's switch, the sound and the one
// snooze – and that what he changes is stored and re-plans the alarms.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/iqama/iqama.dart';

import '../../core/i18n/text_scan.dart';
import '../adhan/adhan_test_app.dart';

final _now = DateTime.utc(2026, 9, 28, 11, 12); // 14:12 in Amman

Future<void> _frames(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// `ensureVisible` can park a control under the frosted app bar, where a
/// tap lands on the header. Nudge the list until it is really pressable.
Future<Finder> _pressable(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await _frames(tester, 6);
  for (var i = 0; i < 8 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 80));
    await _frames(tester, 4);
  }
  expect(target.hitTestable(), findsOneWidget, reason: 'the control never cleared the header');
  return target.hitTestable();
}

Future<AdhanHarness> _pump(WidgetTester tester, {String language = 'ar', IqamaSettings? iqama}) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = await buildAdhanTestApp(
    tester,
    home: const IqamaSettingsScreen(),
    now: _now,
    language: language,
  );
  if (iqama != null) {
    await tester.runAsync(() => IqamaSettingsRepository(Repositories(h.db).keyValues).save(iqama));
  }
  await tester.pumpWidget(h.app);
  await _frames(tester);
  return h;
}

Future<IqamaSettings> _stored(AdhanHarness h, WidgetTester tester) async =>
    (await tester.runAsync(() => IqamaSettingsRepository(Repositories(h.db).keyValues).load()))!;

Future<void> _settle(WidgetTester tester) async {
  await _frames(tester, 10);
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await _frames(tester, 10);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

List<FakeScheduled> _iqamas(AdhanHarness h) =>
    h.platform.scheduled.values.where((s) => IqamaIds.namespace.contains(s.request.id)).toList();

void main() {
  testWidgets('Arabic: the five prayers, Friday, the default quarter hour, Arabic-Indic digits', (tester) async {
    final h = await _pump(tester);
    expect(find.text('الإقامة'), findsWidgets);
    for (final name in ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('الجمعة'), findsOneWidget);
    expect(find.textContaining('بعد الأذان بـ١٥ دقيقة'), findsWidgets);
    expect(paintedStrings(tester).where(westernDigit.hasMatch), isEmpty);
    await _settle(tester);
    expect(_iqamas(h), isNotEmpty, reason: 'opening the screen plans the iqamas');
    expect(_iqamas(h).first.request.title, 'قامت الصلاة');
    await _unmount(tester);
  });

  testWidgets('English: Western digits only, Friday named', (tester) async {
    await _pump(tester, language: 'en');
    expect(find.text('Iqama'), findsWidgets);
    expect(find.text('Maghrib'), findsOneWidget);
    expect(find.text('Friday (Jumuah)'), findsOneWidget);
    expect(find.textContaining('15 minutes after the adhan'), findsWidgets);
    expect(paintedStrings(tester).where(easternDigit.hasMatch), isEmpty);
    await _unmount(tester);
  });

  testWidgets('switching one prayer off stores it and cancels only its own iqamas', (tester) async {
    final h = await _pump(tester);
    await _settle(tester);
    final asrIds = _iqamas(h).where((s) => s.request.body.contains('العصر')).map((s) => s.request.id).toSet();
    expect(asrIds, isNotEmpty);

    final switchFinder = find.descendant(
      of: find.byKey(const ValueKey('iqama-asr')),
      matching: find.byType(MadarSwitch),
    );
    await tester.tap(await _pressable(tester, switchFinder));
    await _settle(tester);

    expect((await _stored(h, tester)).of(AdhanSlot.asr).on, isFalse);
    expect(_iqamas(h).where((s) => asrIds.contains(s.request.id)), isEmpty);
    expect(_iqamas(h), isNotEmpty, reason: 'the other prayers still call');
    await _unmount(tester);
  });

  testWidgets('a prayer\'s own offset is set from its sheet and re-plans the alarm', (tester) async {
    final h = await _pump(tester);
    await _settle(tester);
    await tester.tap(await _pressable(tester, find.text('المغرب')));
    await _frames(tester);
    expect(find.text('إقامة المغرب'), findsOneWidget);
    await tester.tap(find.text('٥ د').last);
    await _frames(tester, 4);
    await tester.tap(find.text('حفظ'));
    await _settle(tester);

    expect((await _stored(h, tester)).of(AdhanSlot.maghrib).minutes, 5);
    final maghrib = _iqamas(h).where((s) => s.request.body.contains('المغرب')).toList();
    expect(maghrib, isNotEmpty);
    // Maghrib on 28 Sep 2026 in Amman: the iqama is five minutes after it.
    for (final s in maghrib) {
      final tap = NotificationEnvelope.decode(s.payload, id: s.request.id);
      expect(s.request.at.difference(IqamaNotificationTaps.prayerAtOf(tap)!), const Duration(minutes: 5));
    }
    await _unmount(tester);
  });

  testWidgets('Friday\'s Dhuhr is edited on its own and leaves the other days alone', (tester) async {
    final h = await _pump(tester);
    await _settle(tester);
    await tester.tap(await _pressable(tester, find.text('الجمعة')));
    await _frames(tester);
    await tester.tap(find.text('٣٠ د').last);
    await _frames(tester, 4);
    await tester.tap(find.text('حفظ'));
    await _settle(tester);

    final stored = await _stored(h, tester);
    expect(stored.jumuah.minutes, 30);
    expect(stored.of(AdhanSlot.dhuhr).minutes, 15, reason: 'the other days are untouched');
    await _unmount(tester);
  });

  testWidgets('the sound, the vibration and the one snooze are his to choose', (tester) async {
    final h = await _pump(tester);
    await _settle(tester);
    expect(find.text('صوت الإقامة'), findsOneWidget);
    expect(find.text('طول «بعد شوي»'), findsOneWidget);
    expect(find.text('مرّة وحدة بس، وما بتتكرّر'), findsOneWidget);
    await tester.tap(await _pressable(tester, find.text('١٠ د').last));
    await _settle(tester);
    expect((await _stored(h, tester)).snoozeMinutes, 10);
    await _unmount(tester);
  });

  testWidgets('restored settings are armed as they come back', (tester) async {
    // A restore writes the rows, then the re-plan hook runs: the offsets
    // and the switches of the backup are what gets armed.
    final h = await _pump(
      tester,
      iqama: const IqamaSettings(jumuah: IqamaPrayer(minutes: 35), snoozeMinutes: 10)
          .withPrayer(AdhanSlot.fajr, const IqamaPrayer(minutes: 25))
          .withPrayer(AdhanSlot.isha, const IqamaPrayer(on: false)),
    );
    await _settle(tester);
    final armed = _iqamas(h);
    expect(armed, isNotEmpty);
    expect(armed.where((s) => s.request.body.contains('العشاء')), isEmpty, reason: 'Isha came back off');
    for (final s in armed.where((s) => s.request.body.contains('الفجر'))) {
      final tap = NotificationEnvelope.decode(s.payload, id: s.request.id);
      expect(s.request.at.difference(IqamaNotificationTaps.prayerAtOf(tap)!), const Duration(minutes: 25));
    }
    expect(find.textContaining('بعد الأذان بـ٢٥ دقيقة'), findsWidgets);
    await _unmount(tester);
  });
}
