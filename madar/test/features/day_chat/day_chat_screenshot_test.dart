// Visual critic pass for Part 7's chat: the real screen with the real fonts
// and shaders, in Arabic and English, across Lapis, Pearl and Aurora, plus
// text scale 1.3. PNGs land in madar/screenshots/day_chat/.
//
//   flutter test --tags screenshot test/features/day_chat/day_chat_screenshot_test.dart
@Tags(['screenshot'])
@Timeout(Duration(minutes: 20))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/features/day_chat/day_chat.dart';

import '../../helpers/screenshot_harness.dart';
import 'day_chat_shot_harness.dart';

const _dir = 'day_chat';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  Future<void> shot(
    WidgetTester tester,
    String name, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    DayChatShot seed = DayChatShot.day,
    DayChatTab tab = DayChatTab.chat,
    double textScale = 1,
    Future<void> Function(WidgetTester tester)? beforeCapture,
  }) async {
    final (app, _) = await buildDayChatShot(
      tester,
      home: DayChatScreen(initialTab: tab, animateBackdrop: false),
      theme: theme,
      locale: locale,
      shot: seed,
      textScale: textScale,
    );
    await captureScreen(
      tester,
      app,
      '$_dir/$name',
      beforeCapture: (tester) async {
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (beforeCapture != null) await beforeCapture(tester);
      },
    );
  }

  // ------------------------------------------------- the invitation

  testWidgets('an empty chat – Arabic, Lapis', (tester) async {
    await shot(tester, 'empty_ar_lapis', seed: DayChatShot.empty);
  });

  testWidgets('an empty chat – English, Pearl', (tester) async {
    await shot(
      tester,
      'empty_en_pearl',
      seed: DayChatShot.empty,
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
    );
  });

  // ------------------------------------------------- his day in one line

  testWidgets('his five facts – Arabic, Lapis', (tester) async {
    await shot(tester, 'day_ar_lapis');
  });

  testWidgets('his five facts – English, Pearl', (tester) async {
    await shot(tester, 'day_en_pearl', theme: MadarThemeId.pearl, locale: const Locale('en'));
  });

  testWidgets('his five facts – Arabic, Aurora, text scale 1.3', (tester) async {
    await shot(tester, 'day_ar_aurora_x13', theme: MadarThemeId.aurora, textScale: 1.3);
  });

  testWidgets('one filed, one refused – Arabic, Pearl', (tester) async {
    await shot(tester, 'decided_ar_pearl', seed: DayChatShot.decided, theme: MadarThemeId.pearl);
  });

  // ------------------------- a gap, a sentence it could not read, a number

  testWidgets('what it could not settle – Arabic, Lapis', (tester) async {
    await shot(tester, 'awkward_ar_lapis', seed: DayChatShot.awkward);
  });

  testWidgets('what it could not settle – English, Aurora', (tester) async {
    await shot(
      tester,
      'awkward_en_aurora',
      seed: DayChatShot.awkward,
      theme: MadarThemeId.aurora,
      locale: const Locale('en'),
    );
  });

  testWidgets('what it could not settle – Arabic, Pearl, text scale 1.3', (tester) async {
    await shot(
      tester,
      'awkward_ar_pearl_x13',
      seed: DayChatShot.awkward,
      theme: MadarThemeId.pearl,
      textScale: 1.3,
    );
  });

  // ------------------------------------------------- «شو صار اليوم؟»

  testWidgets('his day read back – Arabic, Lapis', (tester) async {
    await shot(tester, 'summary_ar_lapis', seed: DayChatShot.decided, tab: DayChatTab.summary);
  });

  testWidgets('his day read back – English, Aurora', (tester) async {
    await shot(
      tester,
      'summary_en_aurora',
      seed: DayChatShot.decided,
      tab: DayChatTab.summary,
      theme: MadarThemeId.aurora,
      locale: const Locale('en'),
    );
  });

  testWidgets('an empty day read back – Arabic, Pearl', (tester) async {
    await shot(
      tester,
      'summary_empty_ar_pearl',
      seed: DayChatShot.empty,
      tab: DayChatTab.summary,
      theme: MadarThemeId.pearl,
    );
  });
}
