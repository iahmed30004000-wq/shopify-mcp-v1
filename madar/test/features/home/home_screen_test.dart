import 'package:drift/drift.dart' show Value;

import 'dart:ui' show SemanticsAction;

import 'package:flutter/services.dart' show JSONMethodCodec, MethodCall;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/home/home_screen.dart';
import 'package:madar/features/home/widgets/neglect_radar_card.dart';
import 'package:madar/features/home/widgets/task_panel.dart';
import 'package:madar/features/home/widgets/window_chips.dart';
import 'package:madar/features/orbit/data/orbit_providers.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/orbit/presentation/orbit_ui_providers.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/orbit/presentation/scene/orbit_scene.dart';
import 'package:madar/features/orbit/presentation/scene/scene_controller.dart';
import 'package:madar/features/orbit/presentation/scene/scene_governor.dart';
import 'package:madar/features/orbit/render/planets/planets.dart' show MoonFrame;

import '../../helpers/test_app.dart';
import '../orbit/data/orbit_fixtures.dart';
import '../orbit/presentation/orbit_scene_fixtures.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));
final _today = DateTime(testNow.year, testNow.month, testNow.day);

/// Prayer times that match the host clock (Amman's on an Amman host), so
/// 13:10 is in the Dhuhr window wherever the tests run.
Future<void> _prayerSettings(MadarDatabase db) =>
    OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());

Future<void> Function(MadarDatabase) _tasks(Map<PrayerWindow, List<String>> byWindow) => (db) async {
  await _prayerSettings(db);
  var i = 0;
  for (final e in byWindow.entries) {
    for (final title in e.value) {
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              title: title,
              window: Value(e.key),
              date: Value(_today),
              planetKey: const Value('work'),
              sortOrder: Value(i++),
            ),
          );
    }
  }
};

Future<void> _pumpFrames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The Android back button / gesture. Returns whether the app handled it –
/// false means the framework would let Android close Madar.
Future<bool> _systemBack(WidgetTester tester) async {
  var handled = true;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (data) {
      if (data != null) handled = const JSONMethodCodec().decodeEnvelope(data) as bool;
    },
  );
  await tester.pumpAndSettle();
  return handled;
}

OrbitSceneState _sceneState(WidgetTester tester) => tester.state<OrbitSceneState>(find.byType(OrbitScene));

SceneController _scene(WidgetTester tester) => _sceneState(tester).controller;

/// A world whose disc is on screen, tappable (not behind the dial) and
/// above the glass panel.
String _tappableWorld(WidgetTester tester) {
  final c = _scene(tester);
  final panelTop = tester.getTopLeft(find.byType(GlassPanel).first).dy;
  for (final b in c.planets.frameFor(c.viewport).bodies) {
    if (!b.visible || b.center.dy > panelTop - b.radius) continue;
    if (c.hitTest(b.center)?.planetKey == b.key) return b.key;
  }
  fail('no tappable world');
}

/// Opens the peeking panel (a tap on its grabber) so the task list shows.
Future<void> _openPanel(WidgetTester tester, [L10n? l]) async {
  final label = (l ?? _ar).orbitUiPanelExpand;
  await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label));
  await settleApp(tester);
}

Future<void> _flyTo(WidgetTester tester, String key) async {
  final disc = _scene(tester).planetDisc(key)!;
  await tester.tapAt(disc.$1);
  await tester.pump();
  await _pumpFrames(tester, 50);
  await settleApp(tester);
}

void main() {
  testWidgets('shows the current window’s tasks and switches windows from the chips', (tester) async {
    await pumpMadarApp(
      tester,
      beforePump: _tasks({
        PrayerWindow.dhuhr: ['Review deck', 'Call Mum'],
        PrayerWindow.asr: ['Evening walk'],
      }),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OrbitScene), findsOneWidget);
    // The panel peeks: the list shows once it is opened.
    expect(find.text('Review deck'), findsNothing);
    await _openPanel(tester);
    // 13:10 → Dhuhr window.
    expect(find.text('Review deck'), findsOneWidget);
    expect(find.text('Call Mum'), findsOneWidget);
    expect(find.text('Evening walk'), findsNothing);
    // Real times: no "approximate" badge any more.
    expect(find.text(_ar.homePlaceholderBadge), findsNothing);

    final asrChip = find.text(_ar.windowAsr).first;
    await tester.ensureVisible(asrChip);
    await settleApp(tester);
    await tester.tap(asrChip);
    await settleApp(tester);
    expect(find.text('Evening walk'), findsOneWidget);
    expect(find.text('Review deck'), findsNothing);
  });

  testWidgets('window chips carry the real prayer times and the next prayer’s countdown', (tester) async {
    await pumpMadarApp(tester, beforePump: _prayerSettings);
    final times = PrayerSchedule(hostPrayerSettings()).timesFor(testNow);
    final fmt = MadarFormatter(languageCode: 'ar');
    // Maghrib's chip shows its start time …
    expect(find.text(fmt.formatTime(times.maghrib)), findsOneWidget);
    // … Asr (the next prayer) its countdown instead.
    final countdown = _ar.orbitUiInDuration(fmt.formatDurationWords(_ar, times.asr.difference(testNow)));
    expect(find.text(countdown), findsOneWidget);
    expect(find.text(fmt.formatTime(times.asr)), findsNothing);
    // The current window's chip is selected and marked "now".
    expect(find.bySemanticsLabel(RegExp('${RegExp.escape(_ar.windowDhuhr)}.*${_ar.homeNow}')), findsOneWidget);
  });

  testWidgets('swipe right completes with a celebration and can be undone', (tester) async {
    final app = await pumpMadarApp(
      tester,
      beforePump: _tasks({
        PrayerWindow.dhuhr: ['Review deck'],
      }),
    );
    await _openPanel(tester);
    await tester.drag(find.text('Review deck'), const Offset(300, 0));
    await _pumpFrames(tester, 40);
    await tester.pump();
    var row = (await tester.runAsync(() => app.repos.tasks.getAll()))!.single;
    expect(row.done, isTrue);
    expect(app.sound.played, contains(Sfx.complete));
    expect(find.text(_ar.homeTaskCompleted), findsOneWidget);
    // Logged through the orbit's completion hook: the Work world pulses.
    final activity = (await tester.runAsync(() => app.repos.activity.since(_today)))!;
    expect(activity.single.planetKey, 'work');
    expect(activity.single.kind, 'task.done');
    await _pumpFrames(tester, 20);
    expect(_scene(tester).planets.living.pulseOf('work'), greaterThan(0));

    await tester.tap(find.text(_ar.actionUndo));
    await _pumpFrames(tester, 40);
    await settleApp(tester);
    row = (await tester.runAsync(() => app.repos.tasks.getAll()))!.single;
    expect(row.done, isFalse);
    expect((await tester.runAsync(() => app.repos.activity.since(_today)))!, isEmpty);
  });

  testWidgets('long-press → delete removes the task; undo brings it back', (tester) async {
    final app = await pumpMadarApp(
      tester,
      beforePump: _tasks({
        PrayerWindow.dhuhr: ['Review deck', 'Call Mum'],
      }),
    );
    await _openPanel(tester);
    await tester.longPress(find.text('Call Mum'));
    await settleApp(tester);
    await tester.tap(find.text(_ar.actionDelete));
    await tester.pump();
    await _pumpFrames(tester, 60);
    expect(app.sound.played, contains(Sfx.delete));
    expect((await tester.runAsync(() => app.repos.tasks.getAll()))!.map((t) => t.title), ['Review deck']);
    await tester.pump();
    expect(find.text(_ar.itemDeleted), findsOneWidget);

    await tester.tap(find.text(_ar.actionUndo));
    await _pumpFrames(tester, 40);
    await settleApp(tester);
    expect((await tester.runAsync(() => app.repos.tasks.getAll()))!.map((t) => t.title), ['Review deck', 'Call Mum']);
    expect(find.text('Call Mum'), findsOneWidget);
  });

  testWidgets('long-press → duplicate adds a copy right after the original', (tester) async {
    final app = await pumpMadarApp(
      tester,
      beforePump: _tasks({
        PrayerWindow.dhuhr: ['Review deck', 'Call Mum'],
      }),
    );
    await _openPanel(tester);
    await tester.longPress(find.text('Review deck'));
    await settleApp(tester);
    await tester.tap(find.text(_ar.actionDuplicate));
    await _pumpFrames(tester, 40);
    await settleApp(tester);
    expect((await tester.runAsync(() => app.repos.tasks.getAll()))!.map((t) => t.title), [
      'Review deck',
      'Review deck',
      'Call Mum',
    ]);
  });

  testWidgets('the quick-add bar creates a task in the window in view', (tester) async {
    final app = await pumpMadarApp(tester, beforePump: _prayerSettings);
    await _openPanel(tester);
    expect(find.text(_ar.homeEmptyTitle), findsOneWidget);
    await tester.enterText(
      find.descendant(of: find.byType(QuickAddBar), matching: find.byType(TextField)),
      'اشتري خبز',
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await settleApp(tester);
    final task = (await tester.runAsync(() => app.repos.tasks.getAll()))!.single;
    expect(task.window, PrayerWindow.dhuhr);
    expect(task.date, _today);
    expect(find.text(task.title), findsOneWidget);
    expect(find.text(_ar.homeEmptyTitle), findsNothing);
  });

  testWidgets('the quick-add bar records an expense (English UI)', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      beforePump: _prayerSettings,
    );
    await _openPanel(tester, _en);
    expect(find.text(_en.homeRadarTitle), findsOneWidget);
    await tester.enterText(
      find.descendant(of: find.byType(QuickAddBar), matching: find.byType(TextField)),
      'spent 5 JD coffee',
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await settleApp(tester);
    final tx = (await tester.runAsync(() => app.repos.transactions.getAll()))!.single;
    expect(tx.amountMilli, 5000);
    expect((await tester.runAsync(() => app.repos.wallets.getAll()))!.single.name, _en.homeDefaultWallet);
  });

  testWidgets('the empty window’s add button opens the edit sheet and saves a task', (tester) async {
    final app = await pumpMadarApp(tester, beforePump: _prayerSettings);
    await _openPanel(tester);
    expect(app.sound.played, contains(Sfx.sheetOpen));
    await tester.tap(find.text(_ar.homeAddTask));
    await settleApp(tester);
    expect(find.text(_ar.homeTaskTitleField), findsWidgets);
    final field = find.descendant(
      of: find.ancestor(of: find.text(_ar.homeTaskTitleField).first, matching: find.byType(Column)).first,
      matching: find.byType(TextField),
    );
    await tester.enterText(field.first, 'Plan the week');
    await tester.pump();
    await tester.tap(find.text(_ar.actionSave));
    await settleApp(tester);
    final task = (await tester.runAsync(() => app.repos.tasks.getAll()))!.single;
    expect(task.title, 'Plan the week');
    expect(task.window, PrayerWindow.dhuhr);
    expect(task.date, _today);
    expect(find.text('Plan the week'), findsOneWidget);
  });

  testWidgets('dragging the panel header expands it over the orbit and back', (tester) async {
    final app = await pumpMadarApp(
      tester,
      beforePump: _tasks({
        PrayerWindow.dhuhr: ['Review deck'],
      }),
    );
    final panel = find.byType(GlassPanel).first;
    final collapsed = tester.getTopLeft(panel).dy;
    // The orbit owns the upper ~57 % of the screen.
    expect(collapsed / 915, closeTo(HomeScreen.collapsedPanelTop, 0.01));
    await tester.drag(find.byType(WindowChips), const Offset(0, -400));
    await settleApp(tester);
    final expanded = tester.getTopLeft(panel).dy;
    expect(expanded, lessThan(collapsed - 200));
    expect(app.sound.played, contains(Sfx.sheetOpen));
    await tester.drag(find.byType(WindowChips), const Offset(0, 500));
    await settleApp(tester);
    expect(tester.getTopLeft(panel).dy, closeTo(collapsed, 1));
  });

  group('back from a planet', () {
    Future<TestApp> home(WidgetTester tester) => pumpMadarApp(
      tester,
      beforePump: (db) async {
        await _prayerSettings(db);
        await seedLivedIn(Repositories(db), now: testNow, thriving: false);
      },
    );

    double panelTop(WidgetTester tester) => tester.getTopLeft(find.byType(GlassPanel).first).dy;

    testWidgets('the panel comes back exactly as open as it was left', (tester) async {
      final app = await home(tester);
      final collapsed = panelTop(tester);

      // Open the panel (its Neglect Radar cards are how a world is reached
      // from an open panel), then fly to a world and come back.
      await tester.drag(find.byType(WindowChips), const Offset(0, -400));
      await settleApp(tester);
      final expanded = panelTop(tester);
      expect(expanded, lessThan(collapsed - 200));

      app.router.go(AppRoutes.planetOf('family'));
      await _pumpFrames(tester, 60);
      await settleApp(tester);
      expect(find.byType(PlanetModulePage), findsOneWidget);
      expect(await _systemBack(tester), isTrue, reason: 'back leaves the planet, it never leaves Madar');
      await _pumpFrames(tester, 60);
      await settleApp(tester);
      expect(app.location, AppRoutes.home);
      expect(panelTop(tester), closeTo(expanded, 1), reason: 'the extent it rested at');

      // And a peeking panel comes back peeking.
      await tester.drag(find.byType(WindowChips), const Offset(0, 500));
      await settleApp(tester);
      expect(panelTop(tester), closeTo(collapsed, 1));
      app.router.go(AppRoutes.planetOf('work'));
      await _pumpFrames(tester, 60);
      await settleApp(tester);
      expect(await _systemBack(tester), isTrue);
      await _pumpFrames(tester, 60);
      await settleApp(tester);
      expect(panelTop(tester), closeTo(collapsed, 1), reason: 'never stuck open over the sky');
    });

    testWidgets('back closes an open panel first, and only then may leave Madar', (tester) async {
      final app = await home(tester);
      final collapsed = panelTop(tester);
      await tester.drag(find.byType(WindowChips), const Offset(0, -400));
      await settleApp(tester);
      expect(panelTop(tester), lessThan(collapsed - 200));

      // First back: the panel closes, the app stays.
      expect(await _systemBack(tester), isTrue, reason: 'an open panel swallows the back press');
      await _pumpFrames(tester, 60);
      await settleApp(tester);
      expect(panelTop(tester), closeTo(collapsed, 1));
      expect(app.location, AppRoutes.home);

      // Only now does back leave the app.
      expect(await _systemBack(tester), isFalse, reason: 'plain, peeking home: back leaves Madar');
    });

    testWidgets('while a planet is open, back only flies home', (tester) async {
      final app = await home(tester);
      app.router.go(AppRoutes.planetOf('family'));
      await _pumpFrames(tester, 60);
      await settleApp(tester);
      expect(await _systemBack(tester), isTrue);
      await _pumpFrames(tester, 60);
      await settleApp(tester);
      expect(app.location, AppRoutes.home);
      expect(find.byType(PlanetModulePage), findsNothing);
    });
  });

  group('the orbit', () {
    testWidgets('tapping a world flies into its page; back flies out again', (tester) async {
      final app = await pumpMadarApp(tester, beforePump: _prayerSettings);
      final key = _tappableWorld(tester);
      final c = _scene(tester);
      final overview = c.camera;
      await _flyTo(tester, key);
      expect(app.location, AppRoutes.planetOf(key));
      expect(find.byType(PlanetModulePage), findsOneWidget);
      expect(app.sound.played, contains(Sfx.navigate));
      final flight = app.container.read(orbitFlightProvider);
      expect(flight.key, key);
      expect(c.flightKey, key);
      expect(c.flightProgress, 1);
      // The world fills the top of the screen behind the page.
      final disc = c.planetDisc(key)!;
      expect(disc.$2, greaterThan(140));
      // Home's panel stepped aside, the orbit scene is still underneath.
      expect(flight.progress.value, 1);
      // (slid down and offstage: not painted, not hit-tested, no semantics)
      expect(find.byType(TaskPanel), findsNothing);
      expect(find.byType(TaskPanel, skipOffstage: false), findsOneWidget);
      expect(find.byType(OrbitScene), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(_ar.orbitUiBackToOrbit));
      await tester.pump();
      await _pumpFrames(tester, 50);
      await settleApp(tester);
      expect(app.location, AppRoutes.home);
      expect(find.byType(PlanetModulePage), findsNothing);
      expect(flight.active, isFalse);
      expect(c.flightKey, isNull);
      expect(c.camera.distance, closeTo(overview.distance, 1e-6));
      expect(app.sound.played, contains(Sfx.back));
    });

    testWidgets('a deep link opens a planet page over home; back returns home', (tester) async {
      final app = await pumpMadarApp(tester, beforePump: _prayerSettings, initialLocation: '/planet/family');
      expect(find.byType(PlanetModulePage), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(_ar.planetFamily), findsWidgets);
      expect(_scene(tester).flightKey, 'family');
      app.router.pop();
      await _pumpFrames(tester, 50);
      await settleApp(tester);
      expect(app.location, AppRoutes.home);
      expect(find.byType(PlanetModulePage), findsNothing);
    });

    testWidgets('the Neglect Radar lists the three weakest worlds; a tap flies there', (tester) async {
      final app = await pumpMadarApp(
        tester,
        beforePump: (db) async {
          await _prayerSettings(db);
          await seedLivedIn(Repositories(db), now: testNow, thriving: false);
        },
      );
      await tester.pump(const Duration(milliseconds: 400));
      await settleApp(tester);
      // Peeking, the radar is one line: its weakest world.
      final snapshot = app.container.read(orbitRepositoryProvider).snapshot(now: testNow);
      final radar = (await tester.runAsync(() => snapshot))!.radar;
      expect(radar, hasLength(3));
      expect(find.textContaining(radar.first.text, findRichText: true), findsOneWidget);
      expect(find.textContaining(radar.last.text, findRichText: true), findsNothing);
      // Opened, its three cards.
      await _openPanel(tester);
      final strip = find.byType(NeglectRadarStrip);
      expect(strip, findsOneWidget);
      for (final e in radar) {
        expect(find.descendant(of: strip, matching: find.text(e.text)), findsOneWidget);
      }
      await tester.tap(find.descendant(of: strip, matching: find.text(radar.first.text)));
      await tester.pump();
      await _pumpFrames(tester, 50);
      await settleApp(tester);
      expect(app.location, startsWith('/planet/${radar.first.planetKey}'));
      expect(find.byType(PlanetModulePage), findsOneWidget);
      // The reason is listed on the planet's page too (below the world's own
      // module – Faith's hub is tall).
      final reason = find.descendant(of: find.byType(PlanetModulePage), matching: find.text(radar.first.text));
      await tester.scrollUntilVisible(
        reason,
        300,
        scrollable: find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first,
      );
      expect(reason, findsOneWidget);
    });

    testWidgets('a moon opens its planet page with that record highlighted', (tester) async {
      final app = await pumpMadarApp(
        tester,
        beforePump: (db) async {
          await _prayerSettings(db);
          await seedLivedIn(Repositories(db), now: testNow, thriving: true);
        },
      );
      await tester.pump(const Duration(milliseconds: 400));
      await settleApp(tester);
      final c = _scene(tester);
      final family = app.container.read(sceneSnapshotProvider).value!.planet('family')!;
      expect(family.moons, isNotEmpty);
      final moon = family.moons.first;
      // Pinch-free: the scene's own hit test finds the moon on screen once
      // its orbit brings it out from behind the dial.
      SceneHit? hit;
      for (var step = 0; step < 200; step++) {
        final m = c.planets.frameFor(c.viewport).moon(moon.id)!;
        final behindDial =
            m.depth > c.planets.frameFor(c.viewport).coreDepth &&
            (m.center - c.coreRect.center).distance < c.coreRadius;
        if (m.visible && !behindDial) {
          hit = c.hitTest(m.center);
          break;
        }
        c.planets.advanceSeconds(2);
        c.refresh();
      }
      expect(hit?.kind, anyOf(SceneHitKind.moon, SceneHitKind.planet));
      // Open it the way a tap does.
      app.router.go(AppRoutes.planetOf('family', item: moon.id));
      await _pumpFrames(tester, 50);
      await settleApp(tester);
      expect(find.text(moon.label), findsWidgets);
      expect(find.textContaining(_ar.orbitUiMoonSelected), findsOneWidget);
      expect(c.planets.selectedMoonId, moon.id);
    });

    testWidgets('on a world\'s page its moons up in the hero are tappable: the record opens', (tester) async {
      final app = await pumpMadarApp(
        tester,
        initialLocation: '/planet/family',
        beforePump: (db) async {
          await _prayerSettings(db);
          await seedLivedIn(Repositories(db), now: testNow, thriving: true);
        },
      );
      await _pumpFrames(tester, 50);
      await settleApp(tester);
      final state = _sceneState(tester);
      final c = state.controller;
      expect(c.flightKey, 'family');
      // Moons orbit: wait (in scene time) for one to come round in front,
      // on screen and above the page's sheet.
      final reach = Rect.fromLTRB(0, 0, c.viewport.width, c.viewport.height * PlanetModulePage.sheetTop).deflate(16);
      MoonFrame? found;
      for (var step = 0; step < 200 && found == null; step++) {
        final f = c.planets.frameFor(c.viewport);
        for (final m in f.body('family')!.moons) {
          if (m.visible && m.radius > 4 && reach.contains(m.center) && c.hitTest(m.center)?.moon?.id == m.moon.id) {
            found = m;
            break;
          }
        }
        if (found == null) {
          c.planets.advanceSeconds(2);
          c.refresh();
        }
      }
      expect(found, isNotNull, reason: 'a moon of the hero world comes into reach');
      final moon = found!.moon;
      final center = found.center;
      // Scene → global (the page sits above the scene in its own route).
      final box = tester.renderObject<RenderBox>(find.byType(OrbitScene));
      final global = box.localToGlobal(center);
      expect(state.globalToScene(global), offsetMoreOrLessEquals(center, epsilon: 0.01));
      expect(app.container.read(orbitFlightProvider).toScene(global), offsetMoreOrLessEquals(center, epsilon: 0.01));
      await tester.tapAt(global);
      // The sheet opens once the record is read from the database.
      // Up to ~4 s of real time: the record read can be slow on a loaded machine.
      for (var i = 0; i < 400 && find.byType(InteractionSheetFrame).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await settleApp(tester);
      expect(find.byType(InteractionSheetFrame), findsOneWidget);
      expect(find.text(moon.label), findsWidgets);
      expect(c.planets.selectedMoonId, moon.id);
      expect(app.sound.played, contains(Sfx.tap));
    });

    testWidgets('tapping a prayer pointer logs the prayer; its pointer ignites', (tester) async {
      final app = await pumpMadarApp(tester, beforePump: _prayerSettings);
      final c = _scene(tester);
      final rect = c.prayerRect(Prayer.dhuhr)!;
      expect(c.hitTest(rect.center)?.prayer, Prayer.dhuhr);
      await tester.tapAt(rect.center);
      await settleApp(tester);
      expect(find.text(_ar.orbitUiPrayerPrayed), findsOneWidget);
      await tester.tap(find.text(_ar.orbitUiPrayerPrayed));
      await tester.pump();
      await _pumpFrames(tester, 30);
      expect(find.text(_ar.orbitUiPrayerLogged(_ar.prayerDhuhr)), findsOneWidget);
      await settleApp(tester);
      final logs = (await tester.runAsync(() => app.repos.prayerLogs.getAll()))!;
      expect(logs.single.prayer, Prayer.dhuhr);
      expect(logs.single.status, PrayerStatus.prayed);
      final activity = (await tester.runAsync(() => app.repos.activity.since(_today)))!;
      expect(activity.single.planetKey, 'faith');
      await tester.pump(const Duration(milliseconds: 400));
      await _pumpFrames(tester, 60);
      expect(c.astrolabeState!.prayed, contains(Prayer.dhuhr));
      expect(c.astrolabe.ignition(Prayer.dhuhr), 1);
    });

    testWidgets('long-press a world to customise it: hide with undo', (tester) async {
      final app = await pumpMadarApp(tester, beforePump: _prayerSettings);
      final key = _tappableWorld(tester);
      await tester.longPressAt(_scene(tester).planetDisc(key)!.$1);
      await settleApp(tester);
      expect(app.sound.played, contains(Sfx.pickUp));
      expect(find.text(_ar.orbitUiHide), findsOneWidget);
      await tester.tap(find.text(_ar.orbitUiHide));
      await tester.pump();
      await _pumpFrames(tester, 30);
      final row = (await tester.runAsync(() => app.repos.planets.getAll()))!.firstWhere((p) => p.key == key);
      expect(row.hidden, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      await _pumpFrames(tester, 30);
      expect(_scene(tester).planets.bodies.map((b) => b.key), isNot(contains(key)));
      await tester.tap(find.text(_ar.actionUndo));
      await _pumpFrames(tester, 40);
      await tester.pump(const Duration(milliseconds: 400));
      await settleApp(tester);
      expect(_scene(tester).planets.bodies.map((b) => b.key), contains(key));
    });

    testWidgets('battery saver shows a captured still of the scene', (tester) async {
      await pumpMadarApp(
        tester,
        settings: const AppSettings(onboarded: true, powerMode: PowerMode.batterySaver),
        beforePump: _prayerSettings,
      );
      await _pumpFrames(tester, 5);
      final c = _scene(tester);
      expect(c.governor.wantsTicker, isFalse);
      expect(find.descendant(of: find.byType(OrbitScene), matching: find.byType(RawImage)), findsOneWidget);
    });

    testWidgets('large text keeps the panel intact', (tester) async {
      await pumpMadarApp(
        tester,
        beforePump: _tasks({
          PrayerWindow.dhuhr: ['Review deck'],
        }),
        settle: false,
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await settleApp(tester);
      expect(tester.takeException(), isNull);

      expect(find.text(_ar.windowDhuhr), findsWidgets);
    });

    testWidgets('screen readers get the worlds, the dial and the prayers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpMadarApp(tester, beforePump: _prayerSettings);
      // Every world: name, state and balance, with tap / long-press actions.
      final faith = find.semantics.byPredicate(
        (n) => n.label.contains(_ar.planetFaith) && n.getSemanticsData().hasAction(SemanticsAction.longPress),
      );
      expect(faith, findsOne);
      expect(faith.evaluate().single.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      // The astrolabe: the current window and the next prayer's countdown.
      expect(find.semantics.byLabel(RegExp(RegExp.escape(_ar.astrolabeWindowNow(_ar.windowDhuhr)))), findsOne);
      // The five prayer pointers are buttons that log the prayer.
      for (final p in [_ar.prayerFajr, _ar.prayerDhuhr, _ar.prayerAsr, _ar.prayerMaghrib, _ar.prayerIsha]) {
        final node = find.semantics.byLabel(RegExp('^${RegExp.escape(p)}:'));
        expect(node, findsOne, reason: p);
        expect(node.evaluate().single.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      }
      handle.dispose();
    });
  });

  group('reset view', () {
    Finder resetPill() => find.bySemanticsLabel(_ar.orbitUiRecenter);
    Finder pillButton() => find.byWidgetPredicate((w) => w is MadarButton && w.semanticLabel == _ar.orbitUiRecenter);

    /// The pill is faded in and takes touches.
    bool pillShown(WidgetTester tester) {
      final fade = tester.widget<AnimatedOpacity>(
        find.ancestor(of: pillButton(), matching: find.byType(AnimatedOpacity)).first,
      );
      final ignore = tester.widget<IgnorePointer>(
        find.ancestor(of: pillButton(), matching: find.byType(IgnorePointer)).first,
      );
      return fade.opacity == 1 && !ignore.ignoring;
    }

    /// A point on empty sky inside the scene's band (no world, moon, pointer
    /// or dial; clear of the reset pill).
    Offset emptySky(WidgetTester tester) {
      final c = _scene(tester);
      final band = c.sceneRect;
      final pill = tester.getRect(pillButton()).inflate(40);
      for (var y = band.top + 60; y < band.bottom - 20; y += 10) {
        for (var x = 24.0; x < band.right - 24; x += 10) {
          final p = Offset(x, y);
          if (c.hitTest(p) != null || pill.contains(p)) continue;
          final near = c.planets.frameFor(c.viewport).bodies.any((b) => (b.center - p).distance < b.radius * 2 + 20);
          if (!near && (p - c.coreCenter).distance > c.coreRadius * 1.1) return p;
        }
      }
      fail('no empty sky');
    }

    Future<void> settleRig(WidgetTester tester) async {
      final c = _scene(tester);
      for (var i = 0; i < 400 && (c.rig.isMoving || c.planets.respreading); i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await _pumpFrames(tester, 30);
    }

    testWidgets('hidden at the overview; a clear pill once the view is turned; it puts everything back', (
      tester,
    ) async {
      final app = await pumpMadarApp(tester, beforePump: _prayerSettings);
      final c = _scene(tester);
      final overview = c.camera;
      expect(pillShown(tester), isFalse, reason: 'nothing to reset on a fresh start');
      expect(find.semantics.byLabel(_ar.orbitUiRecenter), findsNothing);

      // Turn and tilt the orbit.
      final g = await tester.startGesture(emptySky(tester));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(-14, 6));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await _pumpFrames(tester, 30);
      expect(c.rig.isAway, isTrue);
      expect(pillShown(tester), isTrue);
      expect(resetPill(), findsOneWidget);
      final size = tester.getSize(resetPill());
      expect(size.height, greaterThanOrEqualTo(48), reason: 'a real touch target');
      expect(size.width, lessThan(72), reason: 'an icon, not a pill with text over the sky');
      expect(find.text(_ar.orbitUiRecenter), findsNothing, reason: 'icon only – the name is the screen reader\'s');
      expect(find.descendant(of: pillButton(), matching: find.byIcon(Icons.restart_alt_rounded)), findsOneWidget);
      // Names never slide under it.
      expect(c.planets.labelKeepOut, isNotEmpty);

      app.sound.played.clear();
      await tester.tap(resetPill());
      await tester.pump();
      await _pumpFrames(tester, 20);
      expect(app.sound.played, [Sfx.navigate], reason: 'one sound, not two');
      expect(pillShown(tester), isFalse, reason: 'it steps aside while the view springs home – no blinking back');
      await settleRig(tester);
      expect((c.rig.yaw, c.rig.tilt, c.rig.zoom), (0, 0, 0));
      expect(c.camera.distance, closeTo(overview.distance, 1e-9));
      expect(c.camera.elevation, closeTo(overview.elevation, 0.02), reason: 'only the drift’s breath differs');
      expect(pillShown(tester), isFalse);
      expect(find.semantics.byLabel(_ar.orbitUiRecenter), findsNothing, reason: 'screen readers no longer meet it');
      expect(c.planets.labelKeepOut, isEmpty);
    });

    testWidgets('a double tap on empty sky resets too; a single one does nothing', (tester) async {
      final app = await pumpMadarApp(tester, beforePump: _prayerSettings);
      final c = _scene(tester);
      // A real two-finger pinch on the dial.
      final focal = c.coreCenter;
      final a = await tester.startGesture(focal - const Offset(24, 0));
      final b = await tester.startGesture(focal + const Offset(24, 0));
      for (var i = 1; i <= 10; i++) {
        await a.moveTo(focal - Offset(24 + 3.0 * i, 0));
        await b.moveTo(focal + Offset(24 + 3.0 * i, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await _pumpFrames(tester, 20);
      expect(c.rig.zoom, greaterThan(0.2));
      expect(pillShown(tester), isTrue);
      expect(resetPill(), findsOneWidget);
      final sky = emptySky(tester);

      await tester.tapAt(sky);
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.rig.zoom, greaterThan(0.2), reason: 'one tap on the sky is not a reset');
      expect(app.location, AppRoutes.home);

      await tester.tapAt(sky);
      await tester.pump(const Duration(milliseconds: 90));
      await tester.tapAt(sky + const Offset(6, -4));
      await tester.pump();
      expect(c.rig.isHoming, isTrue);
      await settleRig(tester);
      expect(c.rig.zoom, 0);
      expect(c.rig.zoomKey, isNull);
      expect(pillShown(tester), isFalse);
    });

    testWidgets('two quick taps on a world are never a reset', (tester) async {
      final app = await pumpMadarApp(tester, beforePump: _prayerSettings);
      final c = _scene(tester);
      c.rig
        ..begin()
        ..dragBy(const Offset(-80, 0), c.viewport, baseElevation: c.baseCamera.elevation)
        ..end();
      await _pumpFrames(tester, 10);
      final key = _tappableWorld(tester);
      await tester.tapAt(c.planetDisc(key)!.$1);
      await tester.pump();
      expect(c.rig.isHoming, isFalse);
      await _pumpFrames(tester, 50);
      await settleApp(tester);
      expect(app.location, AppRoutes.planetOf(key));
    });

    testWidgets('worlds drifted into each other: the pill offers itself and re-spreads them', (tester) async {
      await pumpMadarApp(tester, beforePump: _prayerSettings);
      AmbientMotion.debugOverride = true;
      addTearDown(() => AmbientMotion.debugOverride = null);
      final c = _scene(tester);
      // Minutes of orbiting at different speeds.
      for (var s = 0; s < 900 && !c.planets.crowded(c.viewport); s++) {
        c.planets.advanceSeconds(1);
      }
      c.refresh();
      expect(c.planets.crowded(c.viewport), isTrue);
      expect(c.rig.isAway, isFalse, reason: 'the camera never moved');
      // A touch wakes the idle scene (it re-reads the ambient switch).
      await tester.tap(find.byType(OrbitScene), warnIfMissed: false);
      await _pumpFrames(tester, 90);
      expect(pillShown(tester), isTrue);
      expect(resetPill(), findsOneWidget);
      await tester.tap(resetPill());
      await tester.pump();
      await settleRig(tester);
      expect(c.planets.crowded(c.viewport), isFalse, reason: 'back to the even layout of a fresh start');
      expect(pillShown(tester), isFalse);
    });

    testWidgets('a pinch cut off by leaving the app never comes back stuck mid-zoom', (tester) async {
      final app = await pumpMadarApp(tester, beforePump: _prayerSettings);
      final c = _scene(tester);
      // Two fingers pinching deep into the dial …
      final focal = c.coreCenter;
      final a = await tester.startGesture(focal - const Offset(24, 0));
      final b = await tester.startGesture(focal + const Offset(24, 0));
      for (var i = 1; i <= 12; i++) {
        await a.moveTo(focal - Offset(24 + 5.0 * i, 0));
        await b.moveTo(focal + Offset(24 + 5.0 * i, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(c.rig.zoom, greaterThan(0.3));
      expect(c.rig.interacting, isTrue);
      // … when the app is left (the gesture's end never arrives in time).
      for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
      expect(c.rig.interacting, isFalse, reason: 'the touch is let go');
      for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      // The late end of that touch changes nothing (no fling, no page).
      await a.up();
      await b.up();
      await tester.pump();
      await settleRig(tester);
      expect(c.rig.zoom, 0, reason: 'springs back out to the whole system');
      expect(c.rig.zoomKey, isNull);
      expect(c.rig.isMoving, isFalse);
      expect(app.location, AppRoutes.home);
      expect(c.rig.interacting, isFalse);
      // Nothing keeps the scene at full rate.
      for (var i = 0; i < 400 && c.governor.mode == SceneMode.live; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(c.governor.mode, isNot(SceneMode.live));
    });

    testWidgets('reduced motion: the reset is a cut', (tester) async {
      await pumpMadarApp(
        tester,
        settings: const AppSettings(onboarded: true, motion: MotionPreference.reduced),
        beforePump: _prayerSettings,
      );
      final c = _scene(tester);
      final overview = c.camera;
      final g = await tester.startGesture(emptySky(tester));
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(-20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await _pumpFrames(tester, 30);
      expect(pillShown(tester), isTrue);
      expect(resetPill(), findsOneWidget);
      await tester.tap(resetPill());
      await tester.pump();
      expect(c.rig.isMoving, isFalse);
      expect(c.camera.azimuth, closeTo(overview.azimuth, 1e-9));
      await settleApp(tester);
      expect(pillShown(tester), isFalse);
    });
  });

  group('power', () {
    testWidgets('touching the scene runs it at full rate; the idle drift at 30 fps', (tester) async {
      await pumpMadarApp(tester, beforePump: _prayerSettings);
      AmbientMotion.debugOverride = true;
      addTearDown(() => AmbientMotion.debugOverride = null);
      final c = _scene(tester);
      // A finger on the orbit: full rate.
      final g = await tester.startGesture(const Offset(200, 200));
      await g.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(c.governor.mode, SceneMode.live);
      final r1 = c.governor.rendered;
      for (var i = 0; i < 30; i++) {
        await g.moveBy(const Offset(1, 0));
        await tester.pump(const Duration(microseconds: 16667));
      }
      expect(c.governor.rendered - r1, greaterThanOrEqualTo(29));
      await g.up();
      // Let go: once everything has settled the scene idles at 30 fps.
      for (var i = 0; i < 400 && c.governor.mode != SceneMode.idle; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(c.governor.mode, SceneMode.idle);
      final r0 = c.governor.rendered;
      var mutedAfterStep = 0, steps = 0;
      for (var i = 0; i < 60; i++) {
        final before = c.governor.rendered;
        await tester.pump(const Duration(microseconds: 16667));
        if (c.governor.rendered > before) {
          steps++;
          // Right after an idle step the ticker is muted: the scene asks for
          // no frame until the next 1/30 s step is due.
          if (_sceneState(tester).debugTicker.muted) mutedAfterStep++;
        }
      }
      expect(c.governor.rendered - r0, inInclusiveRange(28, 32));
      expect(mutedAfterStep, steps);
    });

    testWidgets('with ambient motion on from the start, an idle home schedules no frames between steps', (
      tester,
    ) async {
      // As on a device: every decorative loop is allowed from the first frame
      // (the glass sheen, the empty-state illustration …) – none of them may
      // keep home drawing at the display rate while the scene idles.
      AmbientMotion.debugOverride = true;
      addTearDown(() => AmbientMotion.debugOverride = null);
      await pumpMadarApp(tester, beforePump: _prayerSettings, settle: false);
      for (var i = 0; i < 20; i++) {
        await tester.pump();
      }
      final c = _scene(tester);
      for (var i = 0; i < 600 && c.governor.mode != SceneMode.idle; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(c.governor.mode, SceneMode.idle);
      // Let the entrances finish.
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      var muted = 0, scheduledWhileMuted = 0;
      final r0 = c.governor.rendered;
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(microseconds: 8333));
        if (_sceneState(tester).debugTicker.muted) {
          muted++;
          if (SchedulerBinding.instance.hasScheduledFrame) scheduledWhileMuted++;
        }
      }
      expect(c.governor.rendered - r0, inInclusiveRange(28, 32), reason: '30 fps over one second at 120 Hz');
      expect(muted, greaterThan(60));
      expect(scheduledWhileMuted, 0, reason: 'nothing else on home asks for frames');
    });

    testWidgets('holding the phone (gyro tremor) does not keep the scene live', (tester) async {
      await pumpMadarApp(tester, beforePump: _prayerSettings);
      AmbientMotion.debugOverride = true;
      addTearDown(() => AmbientMotion.debugOverride = null);
      final c = _scene(tester);
      // A touch wakes the scene (it re-reads the ambient-motion switch).
      final g = await tester.startGesture(const Offset(200, 200));
      await g.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await g.up();
      for (var i = 0; i < 400 && c.governor.mode != SceneMode.idle; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(c.governor.mode, SceneMode.idle);
      // Hand tremor: ±0.03 rad/s, well inside the dead zone.
      for (var i = 0; i < 60; i++) {
        c.gyro.addRates(i.isEven ? 0.03 : -0.03, i.isEven ? -0.025 : 0.025, 1 / 60);
        await tester.pump(const Duration(microseconds: 16667));
        expect(c.isAnimating, isFalse);
      }
      expect(c.governor.mode, SceneMode.idle);
    });

    testWidgets('an opaque page over home and a backgrounded app pause the scene', (tester) async {
      await pumpMadarApp(tester, beforePump: _prayerSettings);
      final c = _scene(tester);
      expect(c.governor.mode, isNot(SceneMode.paused));
      await tester.tap(find.bySemanticsLabel(_ar.homeOpenSettings));
      await settleApp(tester);
      expect(c.governor.mode, SceneMode.paused);
      await tester.tap(find.bySemanticsLabel(_ar.actionBack));
      await settleApp(tester);
      expect(c.governor.mode, isNot(SceneMode.paused));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(c.governor.mode, SceneMode.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(c.governor.mode, isNot(SceneMode.paused));
    });

    testWidgets('reduced motion keeps the scene static but interactive', (tester) async {
      final app = await pumpMadarApp(
        tester,
        settings: const AppSettings(onboarded: true, motion: MotionPreference.reduced),
        beforePump: _prayerSettings,
      );
      final c = _scene(tester);
      expect(c.reducedMotion, isTrue);
      expect(c.governor.wantsTicker, isFalse);
      final before = c.planetDisc('faith')!.$1;
      await tester.pump(const Duration(seconds: 2));
      expect(c.planetDisc('faith')!.$1, before);
      final key = _tappableWorld(tester);
      await tester.tapAt(c.planetDisc(key)!.$1);
      await settleApp(tester);
      expect(app.location, AppRoutes.planetOf(key));
      expect(find.byType(PlanetModulePage), findsOneWidget);
    });
  });
}
