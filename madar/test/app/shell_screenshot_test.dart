// Visual critic pass for the app shell: onboarding, home and settings over
// the real cosmos with the real fonts. Writes PNGs to madar/screenshots/.
//
//   flutter test --tags screenshot test/app/shell_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_gate.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/settings/app_settings.dart';

import '../helpers/screenshot_harness.dart';
import '../helpers/test_app.dart';

typedef _Task = ({String title, String? planet, bool done, String? notes});

const _tasksAr = <_Task>[
  (title: 'مراجعة عرض المشروع قبل الاجتماع', planet: 'work', done: false, notes: null),
  (title: 'الاتصال بالوالدة', planet: 'family', done: false, notes: null),
  (title: 'وِرد القرآن: جزء عمّ', planet: 'faith', done: true, notes: null),
  (title: 'مشي هادئ ٣٠ دقيقة', planet: 'body', done: false, notes: 'بعد الغداء مباشرة'),
  (title: 'دفع فاتورة الإنترنت', planet: 'money', done: false, notes: null),
];

const _tasksEn = <_Task>[
  (title: 'Review the project deck', planet: 'work', done: false, notes: null),
  (title: 'Call Mum', planet: 'family', done: false, notes: null),
  (title: 'Quran: one juz', planet: 'faith', done: true, notes: null),
  (title: 'Calm 30-minute walk', planet: 'body', done: false, notes: 'Right after lunch'),
  (title: 'Pay the internet bill', planet: 'money', done: false, notes: null),
];

Future<void> Function(MadarDatabase db) _seedTasks(List<_Task> tasks) => (db) async {
  final day = DateTime(testNow.year, testNow.month, testNow.day);
  for (final (i, t) in tasks.indexed) {
    final row = await db
        .into(db.tasks)
        .insertReturning(
          TasksCompanion.insert(
            title: t.title,
            window: const Value(PrayerWindow.dhuhr),
            date: Value(day),
            planetKey: Value(t.planet),
            notes: Value(t.notes),
            done: Value(t.done),
            doneAt: Value(t.done ? testNow : null),
            sortOrder: Value(i),
          ),
        );
    if (i == 1) {
      await db
          .into(db.reminders)
          .insert(
            RemindersCompanion.insert(
              ownerTable: 'tasks',
              ownerId: row.id,
              rule: const {'kind': 'prayer', 'window': 'asr', 'offsetMin': 10},
            ),
          );
    }
  }
};

void main() {
  testWidgets('onboarding step 1 – Arabic, Lapis', (tester) async {
    final setup = await buildMadarTestApp(tester, settings: const AppSettings());
    await captureScreen(tester, setup.app, 'shell_onboarding_welcome_ar');
  });

  testWidgets('onboarding step 2 – Arabic, Aurora', (tester) async {
    final setup = await buildMadarTestApp(tester, settings: const AppSettings(themeId: MadarThemeId.aurora));
    await captureScreen(
      tester,
      setup.app,
      'shell_onboarding_style_ar_aurora',
      beforeCapture: (tester) async {
        await tester.tap(find.text('لنبدأ'));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
    );
  });

  testWidgets('onboarding step 3 – English, Desert', (tester) async {
    final setup = await buildMadarTestApp(
      tester,
      settings: const AppSettings(languageCode: 'en', themeId: MadarThemeId.desert),
    );
    await captureScreen(
      tester,
      setup.app,
      'shell_onboarding_start_en_desert',
      beforeCapture: (tester) async {
        await tester.tap(find.text('Skip'));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
    );
  });

  testWidgets('home – Arabic, Lapis', (tester) async {
    final setup = await buildMadarTestApp(tester, beforePump: _seedTasks(_tasksAr));
    await captureScreen(tester, setup.app, 'shell_home_ar_lapis');
  });

  testWidgets('home – English, Emerald', (tester) async {
    final setup = await buildMadarTestApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en', themeId: MadarThemeId.emerald),
      beforePump: _seedTasks(_tasksEn),
    );
    await captureScreen(tester, setup.app, 'shell_home_en_emerald');
  });

  testWidgets('home – empty window, Arabic, Desert', (tester) async {
    final setup = await buildMadarTestApp(
      tester,
      settings: const AppSettings(onboarded: true, themeId: MadarThemeId.desert),
    );
    await captureScreen(tester, setup.app, 'shell_home_empty_ar_desert');
  });

  testWidgets('settings – Arabic, Pearl', (tester) async {
    final setup = await buildMadarTestApp(
      tester,
      settings: const AppSettings(onboarded: true, themeId: MadarThemeId.pearl),
      initialLocation: '/settings',
    );
    await captureScreen(tester, setup.app, 'shell_settings_ar_pearl');
  });

  testWidgets('appearance – English, Lapis', (tester) async {
    final setup = await buildMadarTestApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      initialLocation: '/settings/appearance',
    );
    await captureScreen(tester, setup.app, 'shell_appearance_en_lapis');
  });

  testWidgets('sound – Arabic, Emerald', (tester) async {
    final setup = await buildMadarTestApp(
      tester,
      settings: const AppSettings(onboarded: true, themeId: MadarThemeId.emerald),
      initialLocation: '/settings/sound',
    );
    await captureScreen(tester, setup.app, 'shell_sound_ar_emerald');
  });

  testWidgets('splash – Arabic, Lapis', (tester) async {
    final pending = Completer<MadarDatabase>();
    final setup = await buildMadarTestApp(
      tester,
      database: false,
      overrides: [databaseOpenerProvider.overrideWithValue((_) => pending.future)],
    );
    await captureScreen(tester, setup.app, 'shell_splash_ar', settle: const Duration(milliseconds: 1500));
  });
}
