// Phase 4 review – the integrated screenshot matrix: every Health surface
// inside the real app (router, lock, adhan host, real fonts and shaders),
// Arabic + English × Lapis, Pearl and Aurora, plus text scale 1.3 in
// Arabic/Lapis and English/Pearl, and the doctor report's PDF. Each scene
// is also measured for rendered WCAG contrast; misses are written to
// build/phase4_contrast/ for review.
//
//   TZ=Asia/Amman flutter test --tags screenshot test/features/health/review/phase4_integrated_screenshot_test.dart
//
// Narrow with P4_SCENES=hub,meds_today and P4_MATRIX=ar_lapis,en_pearl,x13.
@Tags(['screenshot'])
@Timeout(Duration(minutes: 90))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/app/app.dart' show MadarApp;
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/routing/router.dart' show routerProvider;
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/health/meds/meds.dart';
import 'package:madar/features/health/record/record.dart';
import 'package:madar/features/health/wellbeing/wellbeing.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';

import '../../../core/design/rendered_contrast.dart';
import '../../../helpers/screenshot_harness.dart';
import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';
import '../../orbit/presentation/orbit_scene_fixtures.dart';
import '../hub/hub_seed.dart';
import '../record/doctor_report_test.dart' show buildReport;
import '../record/record_seed.dart';

const _dir = 'phase4/integrated';

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _settleDb(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Ids the scenes need, filled while seeding.
class _Ids {
  String? levo;
  String? tsh;
}

/// A pain log with body-map points 20 minutes ago (the body-map scene).
Future<void> _painWithPoints(MadarDatabase db) async {
  final service = WellbeingService(Repositories(db), clock: () => hubTestNow);
  final repos = Repositories(db);
  final triggers = await repos.tagOptions.getAll(where: (t) => t.kind.equalsValue(TagKind.painTrigger));
  final locations = await repos.tagOptions.getAll(where: (t) => t.kind.equalsValue(TagKind.painLocation));
  await service.logPain(
    PainDraft(
      at: hubTestNow.subtract(const Duration(minutes: 20)),
      score: 6,
      locations: [locations[1].label, locations[3].label],
      triggers: [triggers[2].label],
      points: const [
        BodyPoint(0.5, 0.142, BodySide.back),
        BodyPoint(0.58, 0.2, BodySide.back),
        BodyPoint(0.4, 0.71, BodySide.front),
      ],
    ),
  );
}

ProviderContainer _containerOf(WidgetTester tester, Type screen) =>
    ProviderScope.containerOf(tester.element(find.byType(screen).first));

/// Scrolls the planet sheet so [target] sits [below] its top edge.
Future<void> _sheetTo(WidgetTester tester, Finder target, {double below = 60}) async {
  final scrollable = find
      .descendant(
        of: find.byType(PlanetModulePage),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var pass = 0; pass < 3; pass++) {
    await _frames(tester, 4);
    final dy = tester.getTopLeft(target).dy - tester.getTopLeft(scrollable).dy - below;
    if (dy.abs() < 2) break;
    position.jumpTo((position.pixels + dy).clamp(position.minScrollExtent, position.maxScrollExtent));
  }
  await _frames(tester, 12);
}

Future<void> _scrollLast(WidgetTester tester, double dy) async {
  final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
  await tester.drag(vertical.last, Offset(0, -dy), warnIfMissed: false);
  await _frames(tester, 20);
}

class _Scene {
  const _Scene(this.name, this.location, {this.before, this.seed = HubSeed.lived, this.trailing = 12});

  final String name;
  final String location;
  final Future<void> Function(WidgetTester tester, _Ids ids)? before;
  final HubSeed seed;
  final int trailing;
}

final _scenes = <_Scene>[
  _Scene('hub', '/planet/health', before: (tester, _) => _sheetTo(tester, find.byType(HealthAlertsBanner), below: 150)),
  _Scene('meds_today', '/meds'),
  _Scene(
    'med_editor',
    '/meds?tab=meds',
    before: (tester, ids) async {
      await _settleDb(tester);
      final container = _containerOf(tester, MedsScreen);
      final med = (await tester.runAsync(() => container.read(medsServiceProvider).med(ids.levo!)))!;
      showMedicationEditor(tester.element(find.byType(MedsScreen)), med: med);
      await _frames(tester, 24);
    },
  ),
  _Scene(
    'lab_chart',
    '/record',
    before: (tester, ids) async {
      ProviderScope.containerOf(tester.element(find.byType(MadarApp)))
          .read(routerProvider)
          .push('/record/lab/${ids.tsh}');
      await _settleDb(tester);
      await _frames(tester, 24);
    },
  ),
  _Scene('record', '/record'),
  _Scene(
    'pain_body_map',
    '/wellbeing?tab=pain',
    before: (tester, _) async {
      await _settleDb(tester);
      final container = _containerOf(tester, WellbeingScreen);
      final entries = (await tester.runAsync(() => container.read(wellbeingServiceProvider).watchPain().first))!;
      // Opened at its top: the score, the time and the whole body map.
      showPainLogSheet(tester.element(find.byType(WellbeingScreen)), entry: entries.first);
      await _frames(tester, 24);
    },
  ),
  _Scene('mood_charts', '/wellbeing', before: (tester, _) => _scrollLast(tester, 420)),
  _Scene(
    'breathing',
    '/wellbeing/breathing',
    before: (tester, _) async {
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await _frames(tester, 28);
    },
    trailing: 0,
  ),
  _Scene('insights', '/wellbeing?tab=insights'),
  _Scene('support', '/wellbeing', seed: HubSeed.lowMood),
];

Set<String>? _envSet(String key) {
  final v = Platform.environment[key];
  if (v == null || v.trim().isEmpty) return null;
  return v.split(',').map((s) => s.trim()).toSet();
}

Future<void> _shot(
  WidgetTester tester,
  _Scene scene, {
  required String lang,
  required MadarThemeId theme,
  double textScale = 1,
}) async {
  await preloadOrbitShaders(tester);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final ids = _Ids();
  final setup = await buildMadarTestApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
    initialLocation: scene.location,
    now: hubTestNow,
    beforePump: (MadarDatabase db) async {
      await seedHealthHub(db, lang: lang, seed: scene.seed);
      await _painWithPoints(db);
      final repos = Repositories(db);
      final meds = await repos.medications.getAll();
      ids.levo = meds.firstWhere((m) => m.name == (lang == 'ar' ? 'ليفوثيروكسين' : 'Levothyroxine')).id;
      ids.tsh = (await repos.labTests.getAll()).firstWhere((t) => t.name == 'TSH').id;
    },
    overrides: LockFixture.empty().overrides,
  );
  final boundary = GlobalKey();
  final scale = textScale == 1 ? '' : '_x${(textScale * 10).round()}';
  final name = '${scene.name}_${lang}_${theme.name}$scale';
  await captureScreen(
    tester,
    RepaintBoundary(key: boundary, child: setup.app),
    '$_dir/$name',
    beforeCapture: (tester) async {
      await _settleDb(tester);
      await _frames(tester, 12);
      if (scene.before != null) await scene.before!(tester, ids);
    },
    trailingFrames: scene.trailing,
  );
  final misses = [
    for (final c in await measureRenderedContrast(tester, boundary))
      if (!c.passes && !c.icon) c,
  ];
  final log = File('build/phase4_contrast/$name.txt');
  if (misses.isEmpty) {
    if (log.existsSync()) log.deleteSync();
  } else {
    log
      ..createSync(recursive: true)
      ..writeAsStringSync(misses.join('\n'));
  }
  // Overflow stripes are errors the binding reports; fail loudly on them.
  expect(tester.takeException(), isNull);
}

void main() {
  final only = _envSet('P4_SCENES');
  final matrix = _envSet('P4_MATRIX');
  bool want(String key) => matrix == null || matrix.contains(key);

  for (final scene in _scenes) {
    if (only != null && !only.contains(scene.name)) continue;
    for (final lang in ['ar', 'en']) {
      for (final theme in const [MadarThemeId.lapis, MadarThemeId.pearl, MadarThemeId.aurora]) {
        if (!want('${lang}_${theme.name}')) continue;
        testWidgets('${scene.name} $lang ${theme.name}', (tester) => _shot(tester, scene, lang: lang, theme: theme));
      }
    }
    if (want('x13')) {
      testWidgets(
        '${scene.name} ar lapis ×1.3',
        (tester) => _shot(tester, scene, lang: 'ar', theme: MadarThemeId.lapis, textScale: 1.3),
      );
      testWidgets(
        '${scene.name} en pearl ×1.3',
        (tester) => _shot(tester, scene, lang: 'en', theme: MadarThemeId.pearl, textScale: 1.3),
      );
    }
  }

  if (only == null || only.contains('report')) {
    for (final lang in ['ar', 'en']) {
      test('doctor report PDF ($lang)', () async {
        final db = testDatabase(languageCode: lang, seed: false);
        addTearDown(db.close);
        await seedRecord(db, arabic: lang == 'ar');
        final file = await buildReport(db, lang);
        File('screenshots/$_dir/report_$lang.pdf')
          ..createSync(recursive: true)
          ..writeAsBytesSync(file.bytes);
      });
    }
  }
}
