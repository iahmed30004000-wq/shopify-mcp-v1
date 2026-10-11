@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/ai_bridge/ai_bridge.dart';
import 'package:madar/features/data/data.dart' show dataClockProvider;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/screenshot_harness.dart';
import '../../../helpers/test_app.dart';
import 'plan_ui_harness.dart';

const _dir = 'ai_bridge';

/// How much of the fixture plan he has already decided.
enum PlanShotSeed {
  /// Nothing at all (a fresh install).
  none,

  /// The answer is in, nothing decided.
  imported,

  /// Four suggestions approved, two of them ticked – the owner's own
  /// example: «خطة تشرين الأول» at «٢ من ٤».
  halfDone,
}

class _FixedSettings extends AppSettingsController {
  _FixedSettings(this.initial);

  final AppSettings initial;

  @override
  AppSettings build() => initial;
}

void main() {
  /// Builds the screens over an in-memory database seeded to [seed], and
  /// hands back the plan's id for the screens that need one.
  Future<(Widget, String?)> build(
    WidgetTester tester, {
    required Widget Function(String? planId) home,
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    PlanShotSeed seed = PlanShotSeed.imported,
    double textScale = 1,
    List<Override> overrides = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    final db = await openTestDatabase(tester, languageCode: locale.languageCode);
    String? planId;
    await tester.runAsync(() async {
      if (seed == PlanShotSeed.none) return;
      await seedPlanData(db);
      planId = (await importForTest(db, encodeUiPlan())).id;
      if (seed != PlanShotSeed.halfDone) return;
      final service = PlanApplyService(Repositories(db), clock: () => planUiNow);
      final catalog = await AiBridgeRepository(Repositories(db)).loadCatalog(planUiNow);
      for (final id in ['h1', 't1', 'd1', 'e1']) {
        final plan = (await service.planById(planId!))!;
        final import = await service.reopen(plan, catalog: catalog);
        await service.applyItem(plan, import.preview(id)!);
      }
      final rows = await Repositories(db).appliedPlanItems.getAll(where: (t) => t.planId.equals(planId!));
      for (final row in rows.where((r) => r.itemKey == 'h1' || r.itemKey == 't1')) {
        await service.setDone(row, true);
      }
    });
    final sound = SilentSoundService();
    final haptics = RecordingHaptics();
    Fx.install(FeedbackService(sound, haptics));
    final arabic = locale.languageCode == 'ar';
    final app = ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        soundServiceProvider.overrideWithValue(sound),
        hapticsServiceProvider.overrideWithValue(haptics),
        databaseProvider.overrideWithValue(db),
        dataClockProvider.overrideWithValue(() => planUiNow),
        shareIntakeProvider.overrideWithValue(const NoShareIntake()),
        appSettingsProvider.overrideWith(() => _FixedSettings(AppSettings(languageCode: locale.languageCode))),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildMadarTheme(theme, arabic: arabic),
        locale: locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: MadarFormatScope(
            digits: DigitStyle.auto,
            child: MotionScope(reduced: false, child: CelebrationOverlay(child: child!)),
          ),
        ),
        home: Builder(builder: (_) => home(planId)),
      ),
    );
    return (app, planId);
  }

  Future<void> shot(
    WidgetTester tester,
    String name, {
    required Widget Function(String? planId) home,
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    PlanShotSeed seed = PlanShotSeed.imported,
    double textScale = 1,
    Future<void> Function(WidgetTester tester)? beforeCapture,
    int trailingFrames = 16,
  }) async {
    final (app, _) = await build(
      tester,
      home: home,
      theme: theme,
      locale: locale,
      seed: seed,
      textScale: textScale,
    );
    await captureScreen(
      tester,
      app,
      '$_dir/$name',
      trailingFrames: trailingFrames,
      beforeCapture: (tester) async {
        // Let the database rows reach the providers before the capture.
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (beforeCapture != null) await beforeCapture(tester);
      },
    );
  }

  Widget items(String? planId) => PlanScreen(planId: planId ?? 'none');
  Widget list(String? planId) => PlanScreen(planId: planId ?? 'none', initialTab: PlanTab.list);

  // ------------------------------------------------------ bringing it in ----

  testWidgets('import – Arabic, Lapis', (tester) async {
    await shot(tester, 'import_ar_lapis', home: (_) => const PlanImportScreen(), seed: PlanShotSeed.none);
  });

  testWidgets('import – English, Pearl', (tester) async {
    await shot(
      tester,
      'import_en_pearl',
      home: (_) => const PlanImportScreen(),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      seed: PlanShotSeed.none,
    );
  });

  testWidgets('import – text scale 1.3, Arabic, Aurora', (tester) async {
    await shot(
      tester,
      'import_ar_aurora_scale130',
      home: (_) => const PlanImportScreen(),
      theme: MadarThemeId.aurora,
      seed: PlanShotSeed.none,
      textScale: 1.3,
    );
  });

  testWidgets('import – a refused answer and its problems, Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'import_refused_ar_lapis',
      home: (_) => const PlanImportScreen(),
      seed: PlanShotSeed.none,
      beforeCapture: (tester) async {
        await tester.enterText(find.byKey(const ValueKey('aiPlan.paste')), notAPlanPayload);
        await planFrames(tester, n: 4);
        await tester.tap(find.byKey(const ValueKey('aiPlan.read')), warnIfMissed: false);
        await planFrames(tester, n: 16);
        await tester.drag(find.byType(ListView).first, const Offset(0, -320));
        await planFrames(tester, n: 8);
      },
      trailingFrames: 20,
    );
  });

  testWidgets('import – a refused answer, English, Pearl', (tester) async {
    await shot(
      tester,
      'import_refused_en_pearl',
      home: (_) => const PlanImportScreen(),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      seed: PlanShotSeed.none,
      beforeCapture: (tester) async {
        await tester.enterText(find.byKey(const ValueKey('aiPlan.paste')), notAPlanPayload);
        await planFrames(tester, n: 4);
        await tester.tap(find.byKey(const ValueKey('aiPlan.read')), warnIfMissed: false);
        await planFrames(tester, n: 16);
        await tester.drag(find.byType(ListView).first, const Offset(0, -320));
        await planFrames(tester, n: 8);
      },
      trailingFrames: 20,
    );
  });

  // -------------------------------------------------------- the review ----

  testWidgets('review – the plan`s header, Arabic, Lapis', (tester) async {
    await shot(tester, 'review_ar_lapis', home: items);
  });

  testWidgets('review – the plan`s header, English, Pearl', (tester) async {
    await shot(
      tester,
      'review_en_pearl',
      home: items,
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
    );
  });

  testWidgets('review – the cards, Arabic, Aurora', (tester) async {
    await shot(
      tester,
      'review_cards_ar_aurora',
      home: items,
      theme: MadarThemeId.aurora,
      beforeCapture: (tester) async {
        await tester.drag(find.byType(ListView).first, const Offset(0, -560));
        await planFrames(tester, n: 10);
      },
    );
  });

  testWidgets('review – a blocked and a refused card, Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'review_blocked_ar_lapis',
      home: items,
      beforeCapture: (tester) async {
        await tester.drag(find.byType(ListView).first, const Offset(0, -1700));
        await planFrames(tester, n: 10);
      },
    );
  });

  testWidgets('review – a refused card, English, Aurora', (tester) async {
    await shot(
      tester,
      'review_refused_en_aurora',
      home: items,
      theme: MadarThemeId.aurora,
      locale: const Locale('en'),
      beforeCapture: (tester) async {
        await tester.drag(find.byType(ListView).first, const Offset(0, -2600));
        await planFrames(tester, n: 10);
      },
    );
  });

  testWidgets('review – text scale 1.3, Arabic, Pearl', (tester) async {
    await shot(
      tester,
      'review_ar_pearl_scale130',
      home: items,
      theme: MadarThemeId.pearl,
      textScale: 1.3,
    );
  });

  // ------------------------------------------------------ the checklist ----

  testWidgets('checklist – two of four, Arabic, Lapis', (tester) async {
    await shot(tester, 'list_ar_lapis', home: list, seed: PlanShotSeed.halfDone);
  });

  testWidgets('checklist – two of four, English, Aurora', (tester) async {
    await shot(
      tester,
      'list_en_aurora',
      home: list,
      theme: MadarThemeId.aurora,
      locale: const Locale('en'),
      seed: PlanShotSeed.halfDone,
    );
  });

  testWidgets('checklist – two of four, Arabic, Pearl', (tester) async {
    await shot(tester, 'list_ar_pearl', home: list, theme: MadarThemeId.pearl, seed: PlanShotSeed.halfDone);
  });

  testWidgets('checklist – nothing approved yet, Arabic, Aurora', (tester) async {
    await shot(tester, 'list_empty_ar_aurora', home: list, theme: MadarThemeId.aurora);
  });

  testWidgets('checklist – text scale 1.3, Arabic, Lapis', (tester) async {
    await shot(tester, 'list_ar_lapis_scale130', home: list, seed: PlanShotSeed.halfDone, textScale: 1.3);
  });

  // --------------------------------------------------------- the history ----

  testWidgets('history – one plan, Arabic, Pearl', (tester) async {
    await shot(
      tester,
      'history_ar_pearl',
      home: (_) => PlanHistoryScreen(onImport: () {}, onOpenPlan: (_) {}),
      theme: MadarThemeId.pearl,
      seed: PlanShotSeed.halfDone,
    );
  });

  testWidgets('history – one plan, English, Lapis', (tester) async {
    await shot(
      tester,
      'history_en_lapis',
      home: (_) => PlanHistoryScreen(onImport: () {}, onOpenPlan: (_) {}),
      locale: const Locale('en'),
      seed: PlanShotSeed.halfDone,
    );
  });

  testWidgets('history – a fresh install, Arabic, Aurora', (tester) async {
    await shot(
      tester,
      'history_empty_ar_aurora',
      home: (_) => PlanHistoryScreen(onImport: () {}, onOpenPlan: (_) {}),
      theme: MadarThemeId.aurora,
      seed: PlanShotSeed.none,
    );
  });

  testWidgets('history – text scale 1.3, English, Pearl', (tester) async {
    await shot(
      tester,
      'history_en_pearl_scale130',
      home: (_) => PlanHistoryScreen(onImport: () {}, onOpenPlan: (_) {}),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      seed: PlanShotSeed.halfDone,
      textScale: 1.3,
    );
  });
}
