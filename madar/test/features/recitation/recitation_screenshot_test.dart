@Tags(['screenshot'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/features/recitation/recitation.dart';

import '../../helpers/screenshot_harness.dart';
import 'recitation_test_app.dart';

const _dir = 'phase3/recitation';

/// Mid-listening: Abdul Basit's al-Mulk and a few surahs on the phone, al-Kahf
/// downloading.
void _library(RecitationHarness h) {
  h.seedDownloads(Reciters.abdulBasitMujawwad, surahs: [1, 36, 55, 56, 67, 112, 113, 114], partial: {18: 46});
  h.seedDownloads(Reciters.husaryMuallim, surahs: [78, 79, 80, 81, 82]);
}

Future<void> _downloadingKahf(RecitationHarness h) async {
  h.transport.gate = Completer<void>(); // never released: stays "downloading"
  await h.downloadManager.download(Reciters.abdulBasitMujawwad, [18]);
}

Future<void> _pumpFor(WidgetTester tester, Duration d) async {
  for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 50)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Plays al-Mulk 1–10, twice each ayah, and moves to 67:3 (second pass).
Future<void> _listen(WidgetTester tester, RecitationHarness h) async {
  unawaited(h.player(tester).play(const AyahRange(AyahRef(67, 1), AyahRef(67, 10)), repeatAyah: 2));
  await _pumpFor(tester, const Duration(milliseconds: 400));
  for (var i = 0; i < 6; i++) {
    h.engine.finishCurrent();
    await _pumpFor(tester, const Duration(milliseconds: 100));
  }
  h.engine.pos = const Duration(seconds: 3);
}

Future<void> _openSheet(WidgetTester tester) async {
  unawaited(showNowPlayingSheet(tester.element(find.byType(NowPlayingBar))));
  await _pumpFor(tester, const Duration(milliseconds: 1200));
}

Future<void> _scrollSheet(WidgetTester tester, double by) async {
  final scrollable = find.descendant(of: find.byType(NowPlayingSheet), matching: find.byType(Scrollable)).first;
  await tester.drag(scrollable, Offset(0, -by));
  await _pumpFor(tester, const Duration(milliseconds: 800));
}

Future<void> _stop(WidgetTester tester, RecitationHarness h) async {
  await h.player(tester).stop();
  await _pumpFor(tester, const Duration(milliseconds: 600));
}

void main() {
  testWidgets('settings ar lapis', (tester) async {
    final h = await buildRecitationTestApp(
      tester,
      home: const RecitationSettingsScreen(),
      seed: _library,
      afterLoad: _downloadingKahf,
    );
    await captureScreen(tester, h.app, '$_dir/settings_ar_lapis', settle: const Duration(milliseconds: 2000));
  });

  testWidgets('settings ar lapis – downloads', (tester) async {
    final h = await buildRecitationTestApp(
      tester,
      home: const RecitationSettingsScreen(),
      seed: _library,
      afterLoad: _downloadingKahf,
      settings: const RecitationSettings(repeatAyah: 3, gapSeconds: 4),
    );
    await captureScreen(
      tester,
      h.app,
      '$_dir/settings_ar_lapis_downloads',
      settle: const Duration(milliseconds: 2000),
      beforeCapture: (tester) async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -1100));
        await _pumpFor(tester, const Duration(milliseconds: 600));
      },
    );
  });

  testWidgets('settings en pearl – playing, mini player', (tester) async {
    final h = await buildRecitationTestApp(
      tester,
      home: const RecitationSettingsScreen(),
      theme: MadarThemeId.pearl,
      language: 'en',
      seed: _library,
      settings: const RecitationSettings(reciterId: 'minshawi.mujawwad'),
    );
    await captureScreen(
      tester,
      h.app,
      '$_dir/settings_en_pearl',
      settle: const Duration(milliseconds: 2000),
      beforeCapture: (tester) => _listen(tester, h),
    );
    await _stop(tester, h);
  });

  testWidgets('player ar lapis', (tester) async {
    final h = await buildRecitationTestApp(tester, home: const RecitationSettingsScreen(), seed: _library);
    await captureScreen(
      tester,
      h.app,
      '$_dir/player_ar_lapis',
      settle: const Duration(milliseconds: 1600),
      beforeCapture: (tester) async {
        await _listen(tester, h);
        await _openSheet(tester);
      },
    );
    await _stop(tester, h);
  });

  testWidgets('player ar lapis – controls', (tester) async {
    final h = await buildRecitationTestApp(tester, home: const RecitationSettingsScreen(), seed: _library);
    await captureScreen(
      tester,
      h.app,
      '$_dir/player_ar_lapis_controls',
      settle: const Duration(milliseconds: 1600),
      beforeCapture: (tester) async {
        await _listen(tester, h);
        h.player(tester).setSleepTimer(const Duration(minutes: 30));
        await _openSheet(tester);
        await _scrollSheet(tester, 600);
      },
    );
    await _stop(tester, h);
  });

  testWidgets('player en pearl', (tester) async {
    final h = await buildRecitationTestApp(
      tester,
      home: const RecitationSettingsScreen(),
      theme: MadarThemeId.pearl,
      language: 'en',
      seed: _library,
    );
    await captureScreen(
      tester,
      h.app,
      '$_dir/player_en_pearl',
      settle: const Duration(milliseconds: 1600),
      beforeCapture: (tester) async {
        await _listen(tester, h);
        await _openSheet(tester);
      },
    );
    await _stop(tester, h);
  });

  testWidgets('downloads ar emerald', (tester) async {
    final h = await buildRecitationTestApp(
      tester,
      home: const RecitationDownloadsScreen(reciter: Reciters.abdulBasitMujawwad),
      theme: MadarThemeId.emerald,
      seed: _library,
      afterLoad: _downloadingKahf,
    );
    await captureScreen(tester, h.app, '$_dir/downloads_ar_emerald', settle: const Duration(milliseconds: 1600));
  });

  testWidgets('downloads en pearl – al-Kahf downloading', (tester) async {
    final h = await buildRecitationTestApp(
      tester,
      home: const RecitationDownloadsScreen(reciter: Reciters.abdulBasitMujawwad),
      theme: MadarThemeId.pearl,
      language: 'en',
      seed: _library,
      afterLoad: _downloadingKahf,
    );
    await captureScreen(
      tester,
      h.app,
      '$_dir/downloads_en_pearl',
      settle: const Duration(milliseconds: 1600),
      beforeCapture: (tester) async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -1290));
        await _pumpFor(tester, const Duration(milliseconds: 600));
      },
    );
  });

  testWidgets('settings ar desert – paused for the adhan', (tester) async {
    final h = await buildRecitationTestApp(
      tester,
      home: const RecitationSettingsScreen(),
      theme: MadarThemeId.desert,
      seed: _library,
      settings: const RecitationSettings(reciterId: 'husary.muallim'),
    );
    PrayerMuteLease? lease;
    await captureScreen(
      tester,
      h.app,
      '$_dir/settings_ar_desert_adhan',
      settle: const Duration(milliseconds: 1600),
      beforeCapture: (tester) async {
        await _listen(tester, h);
        lease = h.container(tester).read(prayerMuteProvider).acquire('adhan quiet');
        await _pumpFor(tester, const Duration(milliseconds: 400));
      },
    );
    lease?.release();
    await _stop(tester, h);
  });

  testWidgets('reciter picker ar lapis', (tester) async {
    final h = await buildRecitationTestApp(tester, home: const RecitationSettingsScreen(), seed: _library);
    await captureScreen(
      tester,
      h.app,
      '$_dir/reciters_ar_lapis',
      settle: const Duration(milliseconds: 1600),
      beforeCapture: (tester) async {
        await tester.tap(find.text('تغيير القارئ'));
        await _pumpFor(tester, const Duration(milliseconds: 1200));
      },
    );
  });
}
