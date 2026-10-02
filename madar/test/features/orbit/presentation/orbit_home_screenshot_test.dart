// The Astrolabe Orbit home, rendered for visual review:
//   TZ=Asia/Amman flutter test --tags screenshot test/features/orbit/presentation
// (Amman's prayer times and sky; on another host the prayer settings follow
// the host's UTC offset so the clock still reads like Amman's day.)
@Tags(['screenshot'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/scene/orbit_scene.dart';

import '../../../helpers/test_app.dart';
import '../data/orbit_fixtures.dart';
import 'orbit_scene_fixtures.dart';

/// A few everyday tasks in every window of the day (in the UI language).
Future<void> _seedTasks(Repositories r, DateTime now, {required bool arabic}) async {
  final day = DateTime(now.year, now.month, now.day);
  final tasks = <PrayerWindow, List<(String, String, String?, bool)>>{
    PrayerWindow.fajr: [
      ('ورد القرآن: جزء عمّ', 'Quran wird: Juz Amma', 'faith', true),
      ('أذكار الصباح', 'Morning adhkar', 'faith', false),
    ],
    PrayerWindow.duha: [
      ('مراجعة عرض المشروع', 'Review the project deck', 'work', false),
      ('دفع فاتورة الإنترنت', 'Pay the internet bill', 'money', false),
    ],
    PrayerWindow.dhuhr: [
      ('الاتصال بالوالدة', 'Call Mum', 'family', false),
      ('مكالمة المورّد', 'Supplier call', 'work', true),
      ('مشي هادئ ٣٠ دقيقة', 'Calm 30-minute walk', 'body', false),
    ],
    PrayerWindow.asr: [
      ('قراءة ٢٠ صفحة', 'Read 20 pages', 'growth', false),
      ('تجهيز حقيبة إسطنبول', 'Pack for Istanbul', 'travel', false),
    ],
    PrayerWindow.maghrib: [
      ('زيارة الجدة', 'Visit Grandma', 'family', false),
      ('أذكار المساء', 'Evening adhkar', 'faith', true),
    ],
    PrayerWindow.isha: [
      ('تحضير غداء الغد', "Prep tomorrow's lunch", 'health', false),
      ('ورد الليل', 'Night wird', 'faith', false),
      ('مراجعة المصاريف', 'Review the spending', 'money', false),
    ],
  };
  var order = 0;
  for (final e in tasks.entries) {
    for (final (ar, en, planet, done) in e.value) {
      await r.tasks.insert(
        TasksCompanion.insert(
          title: arabic ? ar : en,
          window: Value(e.key),
          date: Value(day),
          planetKey: Value(planet),
          done: Value(done),
          doneAt: Value(done ? now.subtract(const Duration(minutes: 20)) : null),
          sortOrder: Value(order++),
        ),
      );
    }
  }
}

Future<SceneShots> _home(
  WidgetTester tester,
  DateTime now, {
  MadarThemeId theme = MadarThemeId.lapis,
  String lang = 'ar',
  bool thriving = true,
  bool tasks = true,
  String initialLocation = '/',
}) async {
  final setup = await buildMadarTestApp(
    tester,
    now: now,
    settings: AppSettings(onboarded: true, themeId: theme, languageCode: lang),
    initialLocation: initialLocation,
    beforePump: (MadarDatabase db) async {
      final r = Repositories(db);
      await OrbitRepository(r).setPrayerSettings(hostPrayerSettings());
      await seedLivedIn(r, now: now, thriving: thriving, arabic: lang == 'ar');
      if (tasks) await _seedTasks(r, now, arabic: lang == 'ar');
    },
  );
  final shots = SceneShots(tester);
  await shots.start(setup.app, settle: const Duration(milliseconds: 2200));
  return shots;
}

OrbitSceneState _scene(WidgetTester tester) => tester.state<OrbitSceneState>(find.byType(OrbitScene));

DateTime _at(int h, int m) => DateTime(2026, 9, 27, h, m);

Future<void> _flight(WidgetTester tester, String key, String name) async {
  final shots = await _home(tester, _at(12, 30));
  final c = _scene(tester).controller;
  await shots.snap('orbit_flyin_${name}_0');
  await tester.tapAt(c.planetDisc(key)!.$1);
  await tester.pump();
  await shots.frames(const Duration(milliseconds: 364));
  await shots.snap('orbit_flyin_${name}_50');
  await shots.frames(const Duration(milliseconds: 420));
  await shots.snap('orbit_flyin_${name}_100');
  await shots.frames(const Duration(milliseconds: 1500));
  await shots.snap('orbit_flyin_${name}_page');
  shots.finish();
}

/// A real two-finger pinch around [focal], spreading by [spread] px.
Future<void> _pinch(WidgetTester tester, SceneShots shots, Offset focal, {double spread = 160}) async {
  final a = await tester.startGesture(focal - const Offset(24, 0));
  final b = await tester.startGesture(focal + const Offset(24, 0));
  for (var i = 1; i <= 12; i++) {
    final d = spread / 2 * i / 12;
    await a.moveTo(focal - Offset(24 + d, 0));
    await b.moveTo(focal + Offset(24 + d, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await a.up();
  await b.up();
  await shots.frames(const Duration(milliseconds: 900));
}

void main() {
  group('home through the day (Lapis, Arabic)', () {
    for (final (name, h, m) in [('0535', 5, 35), ('1230', 12, 30), ('1840', 18, 40), ('2230', 22, 30)]) {
      testWidgets('home at $h:$m', (tester) async {
        final shots = await _home(tester, _at(h, m));
        await shots.snap('orbit_home_ar_lapis_$name');
        shots.finish();
      });
    }
  });

  testWidgets('home, Pearl, English, 12:30', (tester) async {
    final shots = await _home(tester, _at(12, 30), theme: MadarThemeId.pearl, lang: 'en');
    await shots.snap('orbit_home_en_pearl_1230');
    shots.finish();
  });

  testWidgets('home, Pearl, Arabic, 22:30: an indigo night with light ink', (tester) async {
    final shots = await _home(tester, _at(22, 30), theme: MadarThemeId.pearl, lang: 'ar');
    await shots.snap('orbit_home_ar_pearl_2230');
    shots.finish();
  });

  testWidgets('home, Aurora, Arabic, 22:30', (tester) async {
    final shots = await _home(tester, _at(22, 30), theme: MadarThemeId.aurora);
    await shots.snap('orbit_home_ar_aurora_2230');
    shots.finish();
  });

  testWidgets('a world behind the dial is ghosted over it (and tappable there)', (tester) async {
    final shots = await _home(tester, _at(21, 10));
    final c = _scene(tester).controller;
    // At rest no world is ever mostly hidden: tilt the camera down to the
    // orbital plane, then let the orbits run on until one is.
    c.rig
      ..begin()
      ..dragBy(Offset(0, -c.viewport.height * 0.3), c.viewport, baseElevation: c.baseCamera.elevation);
    String? ghost;
    for (var i = 0; i < 600 && ghost == null; i++) {
      c.planets.advanceSeconds(0.5);
      c.refresh();
      for (final b in c.planets.frameFor(c.viewport).bodies) {
        if (b.ghosted && b.coreOcclusion > 0.72) ghost = b.key;
      }
    }
    expect(ghost, isNotNull);
    await shots.frames(const Duration(milliseconds: 200));
    final b = c.planets.frameFor(c.viewport).body(ghost!)!;
    expect(c.hitTest(b.center)?.planetKey, ghost);
    await shots.snap('orbit_home_ghost');
    shots.finish();
  });

  testWidgets('fly-in to Faith', (tester) => _flight(tester, 'faith', 'faith'));

  testWidgets('fly-in to Travel', (tester) => _flight(tester, 'travel', 'travel'));

  group('thriving vs neglected (16:00)', () {
    for (final thriving in [true, false]) {
      final name = thriving ? 'thriving' : 'neglected';
      testWidgets('home, $name', (tester) async {
        final shots = await _home(tester, _at(16, 0), thriving: thriving);
        await shots.snap('orbit_home_ar_lapis_$name');
        shots.finish();
      });

      testWidgets('Family page, $name', (tester) async {
        final shots = await _home(tester, _at(16, 0), thriving: thriving, initialLocation: '/planet/family');
        await shots.snap('orbit_planet_family_$name');
        shots.finish();
      });
    }
  });

  testWidgets('Money page, Pearl, English (left to right)', (tester) async {
    final shots = await _home(
      tester,
      _at(12, 30),
      theme: MadarThemeId.pearl,
      lang: 'en',
      thriving: false,
      initialLocation: '/planet/money',
    );
    await shots.snap('orbit_planet_money_en_pearl');
    shots.finish();
  });

  group('gestures and sheets', () {
    testWidgets('pinch into a world (Family) – moons named, back-to-orbit button', (tester) async {
      final shots = await _home(tester, _at(12, 30));
      final c = _scene(tester).controller;
      await _pinch(tester, shots, c.planetDisc('family')!.$1, spread: 120);
      await shots.snap('orbit_zoom_family');
      shots.finish();
    });

    testWidgets('pinch into the astrolabe – the dial up close', (tester) async {
      final shots = await _home(tester, _at(18, 40));
      final c = _scene(tester).controller;
      await _pinch(tester, shots, c.coreCenter, spread: 220);
      await shots.snap('orbit_zoom_astrolabe');
      shots.finish();
    });

    testWidgets('long-press a world: the customisation sheet', (tester) async {
      final shots = await _home(tester, _at(12, 30));
      final c = _scene(tester).controller;
      // Money when it is in front of the dial, otherwise the first world
      // that is (a world hidden behind the brass is not pressable).
      final key = ['money', 'faith', 'work', 'family'].firstWhere((k) {
        final d = c.planetDisc(k);
        return d != null && c.hitTest(d.$1)?.planetKey == k;
      });
      await tester.longPressAt(c.planetDisc(key)!.$1);
      await shots.frames(const Duration(milliseconds: 900));
      expect(find.byType(InteractionSheetFrame), findsOneWidget);
      await shots.snap('orbit_customize_$key');
      // Name & look: the preview recolours and renames live.
      await tester.tap(find.text(lookupL10n(const Locale('ar')).orbitUiEditLook));
      await shots.frames(const Duration(milliseconds: 900));
      await tester.enterText(
        find.descendant(of: find.byType(EditSheet), matching: find.byType(TextField)).first,
        'كنز',
      );
      await shots.frames(const Duration(milliseconds: 400));
      await shots.snap('orbit_customize_look_$key');
      shots.finish();
    });

    testWidgets('tap a prayer pointer: the prayer sheet', (tester) async {
      final shots = await _home(tester, _at(18, 40));
      final c = _scene(tester).controller;
      await tester.tapAt(c.prayerRect(Prayer.maghrib)!.center);
      await shots.frames(const Duration(milliseconds: 900));
      await shots.snap('orbit_prayer_sheet_maghrib');
      shots.finish();
    });
  });
}
