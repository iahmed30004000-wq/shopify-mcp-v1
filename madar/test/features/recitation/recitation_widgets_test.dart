import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_audio.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/recitation/recitation.dart';

import '../../core/i18n/text_scan.dart';
import 'recitation_test_app.dart';

Future<void> _frames(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// A screen with the mini player at the bottom.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Colors.transparent,
    body: Column(
      children: [
        Expanded(child: SizedBox()),
        NowPlayingBar(),
      ],
    ),
  );
}

void main() {
  group('settings screen', () {
    testWidgets('Arabic: reciter, defaults, downloads – Arabic-Indic digits only', (tester) async {
      _phone(tester);
      final h = await buildRecitationTestApp(
        tester,
        home: const RecitationSettingsScreen(),
        seed: (h) => h.seedDownloads(Reciters.abdulBasitMujawwad, surahs: [1, 112, 113, 114]),
      );
      await tester.pumpWidget(h.app);
      await _frames(tester);
      expect(find.text('التلاوة'), findsWidgets);
      expect(find.text('عبد الباسط عبد الصمد'), findsWidgets);
      expect(find.text('استمع إلى عيّنة'), findsOneWidget);
      expect(find.text('٤ سور محمّلة'), findsOneWidget);
      expect(find.text('تكرار كل آية'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('الاستماع دون اتصال'), 300);
      await _frames(tester, 4);
      expect(find.text('المصحف كاملًا بصوت عبد الباسط عبد الصمد'), findsOneWidget);
      expect(find.textContaining('من ١١٤ سورة'), findsOneWidget);
      expect(paintedStrings(tester).where(westernDigit.hasMatch), isEmpty);
      await _unmount(tester);
    });

    testWidgets('English: labels and Western digits', (tester) async {
      _phone(tester);
      final h = await buildRecitationTestApp(tester, home: const RecitationSettingsScreen(), language: 'en');
      await tester.pumpWidget(h.app);
      await _frames(tester);
      expect(find.text('Recitation'), findsWidgets);
      expect(find.text('Abdul Basit Abdus-Samad'), findsOneWidget);
      expect(find.text('Hear a sample'), findsOneWidget);
      expect(find.text('Repeat each ayah'), findsOneWidget);
      expect(find.text('Twice'), findsWidgets);
      expect(paintedStrings(tester).where(easternDigit.hasMatch), isEmpty);
      await _unmount(tester);
    });

    testWidgets('the sample plays al-Ikhlas with the basmala, and stops', (tester) async {
      _phone(tester);
      final h = await buildRecitationTestApp(tester, home: const RecitationSettingsScreen());
      await tester.pumpWidget(h.app);
      await _frames(tester);
      await tester.tap(find.text('استمع إلى عيّنة'));
      await _frames(tester, 6);
      expect(h.engine.sources, hasLength(5));
      expect(
        h.engine.sources.first.uri.toString(),
        'https://everyayah.com/data/Abdul_Basit_Mujawwad_128kbps/001001.mp3',
      );
      expect(h.engine.playing, isTrue);
      expect(h.haptics.fired, isNotEmpty);
      expect(find.text('إيقاف العيّنة'), findsOneWidget);
      // The mini player appears at the bottom while it plays.
      expect(find.byType(NowPlayingBar), findsOneWidget);
      expect(find.text('الإخلاص'), findsOneWidget);
      await tester.tap(find.text('إيقاف العيّنة'));
      await _frames(tester, 6);
      expect(h.player(tester).value, QuranPlayback.idle);
      await _unmount(tester);
    });

    testWidgets('choosing defaults saves them', (tester) async {
      _phone(tester);
      final h = await buildRecitationTestApp(tester, home: const RecitationSettingsScreen());
      await tester.pumpWidget(h.app);
      await _frames(tester);
      await tester.tap(find.text('٣ مرات').first);
      await _frames(tester, 4);
      final saved = await tester.runAsync(() => RecitationSettingsRepository(Repositories(h.db).keyValues).load());
      expect(saved!.repeatAyah, 3);
      await _unmount(tester);
    });

    testWidgets('the picker changes the reciter', (tester) async {
      _phone(tester);
      final h = await buildRecitationTestApp(tester, home: const RecitationSettingsScreen());
      await tester.pumpWidget(h.app);
      await _frames(tester);
      await tester.tap(find.text('تغيير القارئ'));
      await _frames(tester, 8);
      expect(find.text('مجوَّد'), findsWidgets);
      await tester.tap(find.text('مشاري راشد العفاسي'));
      await _frames(tester, 6);
      final saved = await tester.runAsync(() => RecitationSettingsRepository(Repositories(h.db).keyValues).load());
      expect(saved!.reciterId, 'alafasy');
      await _unmount(tester);
    });

    testWidgets('downloading starts only from the button', (tester) async {
      _phone(tester);
      final h = await buildRecitationTestApp(tester, home: const RecitationSettingsScreen());
      await tester.pumpWidget(h.app);
      await _frames(tester);
      expect(h.transport.requests, isEmpty);
      await tester.scrollUntilVisible(find.text('تنزيل المصحف'), 300);
      await _frames(tester, 2);
      await tester.tap(find.text('تنزيل المصحف'));
      await _frames(tester, 4);
      final s = h.downloadManager.summaryOf(Reciters.abdulBasitMujawwad.id);
      expect(s.active, greaterThan(0));
      await tester.runAsync(h.downloadManager.pauseAll);
      await _unmount(tester);
    });
  });

  group('mini player', () {
    testWidgets('hidden while idle; shows surah, ayah and reciter; next and stop', (tester) async {
      _phone(tester);
      final h = await buildRecitationTestApp(tester, home: const _Host());
      await tester.pumpWidget(h.app);
      await _frames(tester, 4);
      expect(find.byType(GlassPanel), findsNothing);
      h.player(tester).play(const AyahRange(AyahRef(67, 1), AyahRef(67, 3)));
      await _frames(tester, 8);
      expect(find.text('الملك'), findsOneWidget);
      expect(find.text('البسملة'), findsOneWidget);
      expect(find.text('عبد الباسط عبد الصمد'), findsOneWidget);
      h.engine.finishCurrent();
      await _frames(tester, 4);
      expect(find.text('الآية ١'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('الآية التالية'));
      await _frames(tester, 4);
      expect(find.text('الآية ٢'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('إيقاف التلاوة'));
      await _frames(tester, 8);
      expect(find.byType(GlassPanel), findsNothing);
      await _unmount(tester);
    });

    testWidgets('the adhan pauses it and says so; play resumes', (tester) async {
      _phone(tester);
      final h = await buildRecitationTestApp(tester, home: const _Host());
      await tester.pumpWidget(h.app);
      await _frames(tester, 2);
      h.player(tester).play(const AyahRange(AyahRef(18, 1), AyahRef(18, 10)));
      await _frames(tester, 6);
      final lease = h.container(tester).read(prayerMuteProvider).acquire('adhan screen');
      await _frames(tester, 4);
      expect(find.text('توقّفت للأذان – اضغط للمتابعة'), findsOneWidget);
      expect(h.engine.playing, isFalse);
      await tester.tap(find.bySemanticsLabel('تشغيل'));
      await _frames(tester, 4);
      expect(h.engine.playing, isTrue);
      lease.release();
      await h.player(tester).stop();
      await _unmount(tester);
    });

    testWidgets('English mini player', (tester) async {
      _phone(tester);
      final h = await buildRecitationTestApp(tester, home: const _Host(), language: 'en');
      await tester.pumpWidget(h.app);
      await _frames(tester, 2);
      h.player(tester).play(const AyahRange(AyahRef(2, 255), AyahRef(2, 257)), repeatAyah: 3);
      await _frames(tester, 8);
      expect(find.text('Al-Baqarah'), findsOneWidget);
      expect(find.text('Ayah 255'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      await h.player(tester).stop();
      await _unmount(tester);
    });
  });

  group('full player', () {
    testWidgets('opens from the bar; repeats change live; closes when stopped', (tester) async {
      _phone(tester);
      final h = await buildRecitationTestApp(tester, home: const _Host());
      await tester.pumpWidget(h.app);
      await _frames(tester, 2);
      h.player(tester).play(const AyahRange(AyahRef(112, 1), AyahRef(112, 4)));
      await _frames(tester, 6);
      await tester.tap(find.text('الإخلاص'));
      await _frames(tester, 10);
      expect(find.text('يُتلى الآن'), findsOneWidget);
      expect(find.byType(RecitationDial), findsOneWidget);
      expect(find.text('مرة واحدة'), findsNWidgets(2));
      await tester.tap(find.bySemanticsLabel('زيادة – الآية'));
      await _frames(tester, 6);
      expect(h.player(tester).state.ayahPasses, 2);
      expect(find.text('مرتان'), findsOneWidget);
      expect(h.sound.played, contains(Sfx.tap));
      await tester.tap(find.bySemanticsLabel('إيقاف مؤقت').last);
      await _frames(tester, 4);
      expect(h.engine.playing, isFalse);
      await h.player(tester).stop();
      await _frames(tester, 10);
      expect(find.text('يُتلى الآن'), findsNothing);
      await _unmount(tester);
    });
  });

  group('downloads screen', () {
    testWidgets('per-surah status and actions', (tester) async {
      _phone(tester);
      final h = await buildRecitationTestApp(
        tester,
        home: const RecitationDownloadsScreen(reciter: Reciters.abdulBasitMujawwad),
        seed: (h) => h.seedDownloads(Reciters.abdulBasitMujawwad, surahs: [1], partial: {2: 40}),
      );
      await tester.pumpWidget(h.app);
      await _frames(tester);
      expect(find.text('الفاتحة'), findsOneWidget);
      expect(find.textContaining('محمّلة'), findsWidgets);
      expect(find.textContaining('متوقّف مؤقتًا'), findsOneWidget);
      expect(find.text('١ من ١١٤ سورة'), findsOneWidget);
      expect(paintedStrings(tester).where(westernDigit.hasMatch), isEmpty);
      await _unmount(tester);
    });
  });
}
