import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/adhan.dart';
import 'package:madar/features/adhan/presentation/widgets/adhan_halo.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';

import '../../core/i18n/text_scan.dart';
import 'adhan_test_app.dart';

DateTime _maghrib() => PrayerSchedule(ammanPrayerSettings).timesFor(DateTime(2026, 9, 28)).maghrib.toUtc();

Future<AdhanHarness> _pump(
  WidgetTester tester, {
  required AdhanEvent event,
  required DateTime now,
  String language = 'ar',
  AdhanSettings settings = const AdhanSettings(),
  void Function()? onClose,
}) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = await buildAdhanTestApp(
    tester,
    home: AdhanScreen(event: event, onClose: onClose ?? () {}),
    now: now,
    language: language,
    settings: settings,
  );
  await tester.pumpWidget(h.app);
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return h;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  final at = _maghrib();

  testWidgets('Arabic: the prayer in calligraphy, its time, the adhan sounding', (tester) async {
    final h = await _pump(
      tester,
      event: adhanEventFor(AdhanSlot.maghrib, prayerAt: at),
      now: at.add(const Duration(seconds: 3)),
    );
    expect(find.text('المغرب'), findsOneWidget);
    expect(find.text('حان الآن وقت صلاة'), findsOneWidget);
    expect(find.text('٦:٣٢ م'), findsOneWidget);
    expect(find.textContaining('التنبيه يصدح الآن'), findsOneWidget, reason: 'a tone (not a recording) is sounding');
    expect(find.text('إيقاف الأذان'), findsOneWidget);
    expect(find.text('صلّيتُ'), findsOneWidget);
    expect(find.text('دعاء ما بعد الأذان'), findsNothing);
    expect(h.sound.prayerMuted, isTrue, reason: 'game music and ambience are muted while it shows');
    expect(paintedStrings(tester).where(westernDigit.hasMatch), isEmpty);
    await _unmount(tester);
    expect(h.sound.prayerMuted, isFalse);
    expect(h.system.lockScreenMode, isFalse);
  });

  testWidgets('English: Latin name with the Arabic calligraphy, Western digits', (tester) async {
    await _pump(
      tester,
      event: adhanEventFor(AdhanSlot.maghrib, prayerAt: at),
      now: at.add(const Duration(seconds: 3)),
      language: 'en',
    );
    expect(find.text('Maghrib'), findsOneWidget);
    expect(find.text('المغرب'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^6:32\sPM$')), findsOneWidget);
    expect(find.text('Stop adhan'), findsOneWidget);
    expect(paintedStrings(tester).where(easternDigit.hasMatch), isEmpty);
    await _unmount(tester);
  });

  testWidgets('Stop silences the notification and shows the supplication', (tester) async {
    final h = await _pump(
      tester,
      event: adhanEventFor(AdhanSlot.maghrib, prayerAt: at),
      now: at.add(const Duration(seconds: 3)),
    );
    await tester.tap(find.text('إيقاف الأذان'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(h.platform.cancelled, [100003]);
    expect(find.text('دعاء ما بعد الأذان'), findsOneWidget);
    expect(find.textContaining('اللَّهُمَّ رَبَّ هَذِهِ الدَّعْوَةِ'), findsOneWidget);
    expect(find.text('رواه البخاري (٦١٤)'), findsOneWidget);
    expect(find.text('إيقاف الأذان'), findsNothing);
    expect(h.haptics.fired, isNotEmpty);
    await _unmount(tester);
  });

  testWidgets('the supplication follows by itself when the adhan ends', (tester) async {
    await _pump(
      tester,
      event: adhanEventFor(AdhanSlot.maghrib, prayerAt: at),
      now: at.add(const Duration(seconds: 3)),
    );
    expect(find.text('دعاء ما بعد الأذان'), findsNothing);
    await tester.pump(TanbihTone.brass.length);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('دعاء ما بعد الأذان'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('opened long after the adhan: straight to the supplication', (tester) async {
    await _pump(
      tester,
      event: adhanEventFor(AdhanSlot.maghrib, prayerAt: at),
      now: at.add(const Duration(minutes: 7)),
      language: 'en',
    );
    expect(find.text('Supplication after the adhan'), findsOneWidget);
    expect(find.textContaining('O Allah, Lord of this perfect call'), findsOneWidget);
    expect(find.text('Sahih al-Bukhari, 614'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('"Stop" pressed on the notification opens silenced', (tester) async {
    final h = await _pump(
      tester,
      event: adhanEventFor(AdhanSlot.maghrib, prayerAt: at, actionId: AdhanActions.stop),
      now: at.add(const Duration(seconds: 3)),
    );
    expect(find.text('دعاء ما بعد الأذان'), findsOneWidget);
    expect(h.platform.cancelled, contains(100003));
    await _unmount(tester);
  });

  testWidgets('I prayed logs the prayer day and closes', (tester) async {
    var closed = 0;
    final h = await _pump(
      tester,
      event: adhanEventFor(AdhanSlot.maghrib, prayerAt: at),
      now: at.add(const Duration(minutes: 5)),
      onClose: () => closed++,
    );
    await tester.tap(find.text('صلّيتُ'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(h.prayed, [(DateTime(2026, 9, 28), Prayer.maghrib)]);
    expect(find.text('تقبّل الله منك'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(closed, 1);
    await _unmount(tester);
  });

  testWidgets('reminder: live countdown and snooze before the adhan', (tester) async {
    var closed = 0;
    final h = await _pump(
      tester,
      event: adhanEventFor(
        AdhanSlot.maghrib,
        kind: AdhanKind.preAdhan,
        prayerAt: at,
        firedAt: at.subtract(const Duration(minutes: 10)),
        sound: null,
        minutesBefore: 10,
      ),
      now: at.subtract(const Duration(minutes: 9, seconds: 30)),
      onClose: () => closed++,
    );
    expect(find.text('استعدّ لصلاة'), findsOneWidget);
    expect(find.text('الأذان بعد ٩:٣٠'), findsOneWidget);
    expect(find.text('إيقاف الأذان'), findsNothing);
    expect(find.text('صلّيتُ'), findsNothing, reason: 'not before its time');
    await tester.tap(find.text('ذكّرني بعد ٥ دقائق'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final snooze = h.platform.scheduled[AdhanIds.snooze];
    expect(snooze, isNotNull);
    expect(snooze!.request.at, at.subtract(const Duration(minutes: 4, seconds: 30)));
    expect(find.text('سأذكّرك بعد ٥ دقائق'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(closed, 1);
    await _unmount(tester);
  });

  testWidgets('the countdown ticks without rebuilding the sky and the astrolabe', (tester) async {
    var now = at.subtract(const Duration(minutes: 9, seconds: 30));
    tester.view.physicalSize = const Size(412, 915) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = await buildAdhanTestApp(
      tester,
      home: AdhanScreen(
        event: adhanEventFor(
          AdhanSlot.maghrib,
          kind: AdhanKind.preAdhan,
          prayerAt: at,
          firedAt: at.subtract(const Duration(minutes: 10)),
          sound: null,
          minutesBefore: 10,
        ),
        onClose: () {},
      ),
      now: now,
      clock: () => now,
    );
    await tester.pumpWidget(h.app);
    await tester.pump(const Duration(seconds: 2));
    final halo = tester.widget(find.byType(AdhanHalo));
    final sky = tester.widget(find.byType(CosmosBackdrop));
    expect(find.text('الأذان بعد ٩:٣٠'), findsOneWidget);

    for (var i = 1; i <= 3; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('الأذان بعد ٩:٢٧'), findsOneWidget, reason: 'the countdown is live');
    expect(identical(tester.widget(find.byType(AdhanHalo)), halo), isTrue, reason: 'no per-second rebuild of the hero');
    expect(identical(tester.widget(find.byType(CosmosBackdrop)), sky), isTrue);
    await _unmount(tester);
  });

  testWidgets('sunrise alert offers "I prayed Fajr"', (tester) async {
    final sunrise = PrayerSchedule(ammanPrayerSettings).timesFor(DateTime(2026, 9, 28)).sunrise.toUtc();
    final h = await _pump(
      tester,
      event: adhanEventFor(AdhanSlot.sunrise, kind: AdhanKind.sunrise, prayerAt: sunrise, sound: null),
      now: sunrise.add(const Duration(seconds: 10)),
      language: 'en',
    );
    expect(find.text('Sunrise'), findsOneWidget);
    expect(find.text('Fajr time has ended'), findsOneWidget);
    await tester.tap(find.text('I prayed Fajr'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(h.prayed.single.$2, Prayer.fajr);
    await tester.pump(const Duration(seconds: 2));
    await _unmount(tester);
  });

  testWidgets('no notification sounding → the adhan plays in the app', (tester) async {
    final h = await _pump(
      tester,
      event: adhanEventFor(AdhanSlot.maghrib, prayerAt: at).copyWith(playInApp: true),
      now: at.add(const Duration(seconds: 1)),
    );
    expect(h.audio.played, [const AdhanSoundRef.tone(TanbihTone.brass)]);
    await _unmount(tester);
    expect(h.audio.stops, greaterThan(0));
  });

  test('screen model: phases, lengths and when "I prayed" makes sense', () {
    final m = AdhanScreenModel(kind: AdhanKind.adhan, firedAt: at, soundLength: const Duration(seconds: 15));
    expect(m.initialPhase(at.add(const Duration(seconds: 5))), AdhanPhase.calling);
    expect(m.initialPhase(at.add(const Duration(seconds: 20))), AdhanPhase.after);
    expect(m.initialPhase(at, silenced: true), AdhanPhase.after);
    expect(m.soundingLeft(at.add(const Duration(seconds: 5))), const Duration(seconds: 10));
    expect(
      AdhanScreenModel(kind: AdhanKind.preAdhan, firedAt: at, soundLength: Duration.zero).initialPhase(at),
      AdhanPhase.reminder,
    );
    expect(AdhanScreenModel.soundLengthOf(const AdhanSoundRef.silent(), const AdhanSettings()), Duration.zero);
    expect(
      AdhanScreenModel.soundLengthOf(const AdhanSoundRef.file('gone1234'), const AdhanSettings()),
      AdhanScreenModel.unknownRecording,
    );
    expect(
      AdhanScreenModel.canMarkPrayed(AdhanKind.adhan, AdhanSlot.asr, at, at.subtract(const Duration(minutes: 1))),
      isFalse,
    );
    expect(AdhanScreenModel.canMarkPrayed(AdhanKind.test, AdhanSlot.asr, at, at), isFalse);
    expect(AdhanScreenModel.prayedSlot(AdhanSlot.sunrise), AdhanSlot.fajr);
  });

  test('NotificationNamespaces owns the adhan ids', () {
    expect(NotificationNamespaces.owning(AdhanIds.test), NotificationNamespaces.adhan);
    expect(AdhanIds.isOneOff(AdhanIds.snooze), isTrue);
    expect(AdhanIds.isOneOff(100001), isFalse);
  });
}
