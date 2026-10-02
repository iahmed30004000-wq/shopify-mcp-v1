// QiblaScreen and QiblaCard in Arabic and English with a fake compass at
// several headings, the calibration prompt, the fallbacks and the feedback.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/qibla/qibla.dart';

import '../../helpers/test_app.dart' show usePhoneSurface;
import 'qibla_test_app.dart';

/// Text finders that ignore the bidi isolates wrapped around numbers.
Finder _text(String expected) => find.byWidgetPredicate(
  (w) => w is Text && BidiIsolate.strip(w.data ?? '') == expected,
  description: 'text "$expected"',
);

Finder _textContaining(String part) => find.byWidgetPredicate(
  (w) => w is Text && BidiIsolate.strip(w.data ?? '').contains(part),
  description: 'text containing "$part"',
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('QiblaScreen (Arabic)', () {
    testWidgets('heading 70°: turn right ≈ 91°, bearing and distance in Arabic digits', (tester) async {
      usePhoneSurface(tester);
      final source = FakeHeadingSource(initial: readingAt(70));
      final setup = await buildQiblaTestApp(tester, home: const QiblaScreen(), source: source);
      await tester.pumpWidget(setup.app);
      await _settle(tester);
      expect(_textContaining('استدر يمينًا'), findsOneWidget);
      expect(_textContaining('٩١°'), findsOneWidget);
      // Bearing 160.7° (south) and 1,234 km.
      expect(_textContaining('١٦٠٫٧°'), findsWidgets);
      expect(_textContaining('١٬٢٣٤ كم'), findsOneWidget);
      expect(_textContaining('دقة عالية'), findsOneWidget);
      expect(_textContaining('الانحراف المغناطيسي'), findsOneWidget);
      expect(source.hasListener, isTrue);
    });

    testWidgets('heading 250°: turn left', (tester) async {
      usePhoneSurface(tester);
      final source = FakeHeadingSource(initial: readingAt(250));
      final setup = await buildQiblaTestApp(tester, home: const QiblaScreen(), source: source);
      await tester.pumpWidget(setup.app);
      await _settle(tester);
      expect(_textContaining('استدر يسارًا'), findsOneWidget);
      expect(_textContaining('٨٩°'), findsOneWidget);
    });

    testWidgets('turning onto the qibla: facing text, one gentle chime and haptic', (tester) async {
      usePhoneSurface(tester);
      final source = FakeHeadingSource(initial: readingAt(120));
      final setup = await buildQiblaTestApp(tester, home: const QiblaScreen(), source: source);
      await tester.pumpWidget(setup.app);
      await _settle(tester);
      setup.sound.played.clear();
      setup.haptics.fired.clear();
      source.emit(readingAt(ammanQibla + 1, ms: 100));
      await _settle(tester);
      expect(_text('اتجاهك الآن إلى القبلة'), findsOneWidget);
      expect(setup.sound.played, [Sfx.complete]);
      expect(setup.haptics.fired, [Haptic.light]);
      // Small wobble inside the band: no second chime.
      source.emit(readingAt(ammanQibla - 2, ms: 200));
      await _settle(tester);
      expect(setup.sound.played, [Sfx.complete]);
    });

    testWidgets('a disturbed field shows the figure-eight prompt; "later" hides it', (tester) async {
      usePhoneSurface(tester);
      final source = FakeHeadingSource();
      final setup = await buildQiblaTestApp(tester, home: const QiblaScreen(), source: source);
      await tester.pumpWidget(setup.app);
      for (var i = 0; i < 80; i++) {
        source.emit(disturbedAt(100, ms: i * 20));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await _settle(tester);
      expect(find.byKey(const ValueKey('qibla-calibration')), findsOneWidget);
      expect(_text('عايِر البوصلة'), findsOneWidget);
      expect(_textContaining('على شكل الرقم ٨'), findsOneWidget);
      await tester.tap(_text('لاحقًا'));
      await _settle(tester);
      expect(find.byKey(const ValueKey('qibla-calibration')), findsNothing);
      expect(_text('معايرة'), findsOneWidget); // bring it back
    });

    testWidgets('no magnetometer by day: the sun compass', (tester) async {
      usePhoneSurface(tester);
      final source = FakeHeadingSource(error: const HeadingUnavailable(HeadingUnavailableReason.noSensor));
      final setup = await buildQiblaTestApp(tester, home: const QiblaScreen(), source: source);
      await tester.pumpWidget(setup.app);
      await _settle(tester);
      expect(_textContaining('لا يحتوي هذا الهاتف على بوصلة'), findsOneWidget);
      expect(_textContaining('الشمس'), findsWidgets);
      expect(_textContaining('وجّه أعلى الهاتف نحوها'), findsOneWidget);
      expect(_text('اتجاه الشمس'), findsOneWidget);
      // No sensor: no "try again".
      expect(_text('أعد المحاولة'), findsNothing);
    });

    testWidgets('no magnetometer at night: the diagram with the Pole Star hint', (tester) async {
      usePhoneSurface(tester);
      final source = FakeHeadingSource(error: const HeadingUnavailable(HeadingUnavailableReason.noSensor));
      final setup = await buildQiblaTestApp(tester, home: const QiblaScreen(), source: source, now: qiblaNight);
      await tester.pumpWidget(setup.app);
      await _settle(tester);
      expect(_text('مخطط الاتجاه'), findsOneWidget);
      expect(_textContaining('النجم القطبي'), findsOneWidget);
      expect(_textContaining('١٦١°'), findsOneWidget);
    });

    testWidgets('a sensor error offers "try again", which restarts the compass', (tester) async {
      usePhoneSurface(tester);
      final source = FakeHeadingSource(error: const HeadingUnavailable(HeadingUnavailableReason.sensorError));
      final setup = await buildQiblaTestApp(tester, home: const QiblaScreen(), source: source);
      await tester.pumpWidget(setup.app);
      await _settle(tester);
      expect(_text('تعذّرت قراءة البوصلة.'), findsOneWidget);
      source
        ..error = null
        ..initial = readingAt(10);
      await tester.tap(_text('أعد المحاولة'));
      await _settle(tester);
      expect(_textContaining('استدر'), findsOneWidget);
    });

    testWidgets('the app going to the background stops the sensors', (tester) async {
      usePhoneSurface(tester);
      final source = FakeHeadingSource(initial: readingAt(70));
      final setup = await buildQiblaTestApp(tester, home: const QiblaScreen(), source: source);
      await tester.pumpWidget(setup.app);
      await _settle(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(source.hasListener, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(source.hasListener, isTrue);
    });
  });

  group('QiblaScreen (English)', () {
    testWidgets('headings 0 / 90 / 161 / 300 read correctly', (tester) async {
      usePhoneSurface(tester);
      final source = FakeHeadingSource(initial: readingAt(0));
      final setup = await buildQiblaTestApp(
        tester,
        home: const QiblaScreen(),
        source: source,
        locale: const Locale('en'),
        theme: MadarThemeId.pearl,
      );
      await tester.pumpWidget(setup.app);
      await _settle(tester);
      expect(_text('Turn right 161°'), findsOneWidget);
      expect(_textContaining('160.7° S'), findsOneWidget);
      expect(_text('1,234 km'), findsOneWidget);

      source.emit(readingAt(90, ms: 100));
      await _settle(tester);
      expect(_text('Turn right 71°'), findsOneWidget);

      source.emit(readingAt(161, ms: 200));
      await _settle(tester);
      expect(_text("You're facing the qibla"), findsOneWidget);

      source.emit(readingAt(300, ms: 300));
      await _settle(tester);
      expect(_text('Turn left 139°'), findsOneWidget);
      expect(_textContaining('300° NW'), findsOneWidget);
    });

    testWidgets('use the sun, then back to the compass', (tester) async {
      usePhoneSurface(tester);
      final source = FakeHeadingSource(initial: readingAt(40));
      final setup = await buildQiblaTestApp(
        tester,
        home: const QiblaScreen(),
        source: source,
        locale: const Locale('en'),
      );
      await tester.pumpWidget(setup.app);
      await _settle(tester);
      await tester.tap(_text('Use the sun'));
      await _settle(tester);
      expect(_textContaining('of the sun'), findsOneWidget);
      expect(source.hasListener, isFalse);
      await tester.ensureVisible(_text('Back to the compass'));
      await tester.tap(_text('Back to the compass'));
      await _settle(tester);
      expect(_textContaining('Turn right'), findsOneWidget);
    });

    testWidgets('a travel destination overrides the prayer location', (tester) async {
      usePhoneSurface(tester);
      final source = FakeHeadingSource(initial: readingAt(0));
      const london = QiblaPlace(latitude: 51.5074, longitude: -0.1278, nameAr: 'لندن', nameEn: 'London');
      final setup = await buildQiblaTestApp(
        tester,
        home: const QiblaScreen(place: london),
        source: source,
        locale: const Locale('en'),
      );
      await tester.pumpWidget(setup.app);
      await _settle(tester);
      expect(_text('From London'), findsOneWidget);
      expect(_textContaining('119.0° SE'), findsOneWidget);
      expect(_text('4,794 km'), findsOneWidget);
    });
  });

  group('QiblaCard', () {
    testWidgets('Arabic: bearing, distance and place; tap opens with a navigate sound', (tester) async {
      usePhoneSurface(tester);
      var opened = 0;
      final setup = await buildQiblaTestApp(
        tester,
        home: Scaffold(
          body: Center(child: QiblaCard(onOpen: () => opened++)),
        ),
        source: FakeHeadingSource(),
      );
      await tester.pumpWidget(setup.app);
      await _settle(tester);
      expect(_text('اتجاه القبلة'), findsOneWidget);
      expect(_textContaining('١٦٠٫٧° ج'), findsOneWidget);
      expect(_textContaining('١٬٢٣٤ كم'), findsOneWidget);
      expect(_textContaining('من عمّان'), findsOneWidget);
      setup.sound.played.clear();
      await tester.tap(find.byType(QiblaCard));
      await tester.pump();
      expect(opened, 1);
      expect(setup.sound.played, contains(Sfx.navigate));
    });

    testWidgets('English with a custom place', (tester) async {
      usePhoneSurface(tester);
      final setup = await buildQiblaTestApp(
        tester,
        home: Scaffold(
          body: Center(
            child: QiblaCard(
              onOpen: () {},
              place: const QiblaPlace(latitude: -6.2088, longitude: 106.8456, nameEn: 'Jakarta'),
            ),
          ),
        ),
        source: FakeHeadingSource(),
        locale: const Locale('en'),
      );
      await tester.pumpWidget(setup.app);
      await _settle(tester);
      expect(_text('295.2° NW'), findsOneWidget);
      expect(_textContaining('7,920 km · From Jakarta'), findsOneWidget);
    });
  });
}
