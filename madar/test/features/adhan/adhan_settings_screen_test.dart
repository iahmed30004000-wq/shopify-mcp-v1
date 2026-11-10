import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/features/adhan/adhan.dart';
import 'package:madar/features/adhan/presentation/adhan_settings_screen.dart';

import '../../core/i18n/text_scan.dart';
import 'adhan_test_app.dart';

final _now = DateTime.utc(2026, 9, 28, 11, 12); // 14:12 in Amman

Future<void> _frames(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<AdhanHarness> _pump(
  WidgetTester tester, {
  String language = 'ar',
  FakeAdhanSystem? system,
  FakeBatteryGate? battery,
}) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = await buildAdhanTestApp(
    tester,
    home: const AdhanHost(child: AdhanSettingsScreen()),
    now: _now,
    language: language,
    system: system,
    battery: battery,
  );
  await tester.pumpWidget(h.app);
  await _frames(tester);
  return h;
}

Future<AdhanSettings> _stored(AdhanHarness h, WidgetTester tester) async =>
    (await tester.runAsync(() => AdhanSettingsRepository(Repositories(h.db).keyValues).load()))!;

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('Arabic: next adhan, the five prayers with their times, Arabic-Indic digits', (tester) async {
    final h = await _pump(tester);
    expect(find.text('الأذان القادم'), findsOneWidget);
    expect(find.text('الفجر'), findsWidgets);
    expect(find.text('المغرب'), findsWidgets);
    expect(find.textContaining('٦:٣٢'), findsWidgets);
    expect(h.platform.scheduled, isNotEmpty, reason: 'opening the app plans the alarms');
    expect(paintedStrings(tester).where(westernDigit.hasMatch), isEmpty);
    await _unmount(tester);
  });

  testWidgets('English: Western digits only', (tester) async {
    await _pump(tester, language: 'en');
    expect(find.text('Next adhan'), findsOneWidget);
    expect(find.text('Maghrib'), findsWidgets);
    expect(paintedStrings(tester).where(easternDigit.hasMatch), isEmpty);
    await _unmount(tester);
  });

  testWidgets('the next adhan counts down while the screen is open', (tester) async {
    var now = _now;
    tester.view.physicalSize = const Size(412, 915) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = await buildAdhanTestApp(
      tester,
      home: const AdhanHost(child: AdhanSettingsScreen()),
      now: _now,
      clock: () => now,
      language: 'en',
    );
    await tester.pumpWidget(h.app);
    await _frames(tester);
    expect(find.text('in 1h 39m'), findsOneWidget);
    now = now.add(const Duration(minutes: 2));
    await tester.pump(const Duration(minutes: 2));
    await _frames(tester, 3);
    expect(find.text('in 1h 37m'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('switching a prayer off stores it and cancels its alarms', (tester) async {
    final h = await _pump(tester);
    final asrAlarms = h.platform.scheduled.values.where((s) => s.request.title.contains('العصر')).length;
    expect(asrAlarms, greaterThan(0));
    final asrRow = find.ancestor(of: find.text('العصر'), matching: find.byType(ActionableItem)).first;
    await tester.tap(find.descendant(of: asrRow, matching: find.byType(MadarSwitch)));
    await _frames(tester, 10);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _frames(tester, 10);
    expect((await _stored(h, tester)).alertOf(AdhanSlot.asr).adhan, isFalse);
    expect(h.platform.scheduled.values.where((s) => s.request.title.contains('العصر')), isEmpty);
    await _unmount(tester);
  });

  testWidgets('a reminder is set from the prayer sheet', (tester) async {
    final h = await _pump(tester);
    await tester.tap(find.text('المغرب').first);
    await _frames(tester);
    expect(find.text('أذان المغرب'), findsOneWidget);
    await tester.tap(find.text('١٠ د').last);
    await _frames(tester, 4);
    await tester.tap(find.text('حفظ'));
    await _frames(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _frames(tester);
    expect((await _stored(h, tester)).alertOf(AdhanSlot.maghrib).preMinutes, 10);
    expect(h.platform.scheduled.values.any((s) => s.request.title == 'المغرب بعد ١٠ دقائق'), isTrue);
    await _unmount(tester);
  });

  testWidgets('permission card: live status and a request', (tester) async {
    final battery = FakeBatteryGate(exempt: false);
    final h = await _pump(tester, system: FakeAdhanSystem(fullScreen: false), battery: battery);
    expect(find.text('ليُرفَع الأذان في وقته'), findsOneWidget);
    expect(find.text('اسمح'), findsNWidgets(2));
    await tester.tap(find.text('اسمح').last);
    await _frames(tester);
    expect(battery.requests, 1);
    expect(find.text('اسمح'), findsOneWidget);
    h.system.fullScreen = true;
    await tester.tap(find.text('اسمح'));
    await _frames(tester);
    expect(find.text('الأذان جاهز؛ كل ما يحتاجه مسموح'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('permission card: a refusal in the system dialog turns the button into the settings page', (tester) async {
    var now = _now;
    tester.view.physicalSize = const Size(412, 915) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final battery = FakeBatteryGate(grantOnRequest: false)..onRequest = () => now = now.add(const Duration(seconds: 4));
    final h = await buildAdhanTestApp(
      tester,
      home: const AdhanHost(child: AdhanSettingsScreen()),
      now: _now,
      clock: () => now,
      battery: battery,
    );
    await tester.pumpWidget(h.app);
    await _frames(tester);
    await tester.tap(find.text('اسمح'));
    await _frames(tester);
    expect(battery.requests, 1);
    expect(h.system.opened, isEmpty, reason: '"Don\'t allow" is respected');
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('رفضتَه في نافذة أندرويد؛ فعّله من الإعدادات متى شئت'), findsOneWidget);
    await tester.tap(find.text('الإعدادات'));
    await _frames(tester);
    expect(h.system.opened, ['battery']);
    await _unmount(tester);
  });

  testWidgets('test adhan now schedules a real adhan in seconds', (tester) async {
    final h = await _pump(tester);
    await tester.dragUntilVisible(find.text('جرّب الأذان الآن'), find.byType(ListView).first, const Offset(0, -300));
    await _frames(tester, 4);
    await tester.tap(find.text('جرّب الأذان الآن'));
    await _frames(tester);
    final test = h.platform.scheduled[AdhanIds.test];
    expect(test, isNotNull);
    expect(test!.request.fullScreen, isTrue);
    expect(test.request.at, _now.add(const Duration(seconds: 10)));
    expect(find.text('سيُرفَع الأذان بعد ١٠ ثوانٍ'), findsOneWidget);
    // Madar is still open when it fires: the adhan screen comes up.
    await tester.pump(const Duration(seconds: 10));
    await _frames(tester);
    expect(find.byType(AdhanScreen), findsOneWidget);
    expect(find.text('تجربة أذان'), findsOneWidget);
    await _unmount(tester);
  });
}
