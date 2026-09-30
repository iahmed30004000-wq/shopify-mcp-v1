@Tags(['screenshot'])
// Rendering glass + cosmos shaders on a shared, loaded CI box can take
// minutes per shot; the default 10-minute timeout is too tight there.
@Timeout(Duration(minutes: 30))
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/custom_modules/custom_modules.dart';

import '../../helpers/screenshot_harness.dart';
import 'custom_harness.dart';

const _dir = 'phase6/custom';

/// Opens a sheet over an empty page once the first frame is up.
class _SheetHost extends StatefulWidget {
  const _SheetHost(this.open);

  final Future<void> Function(BuildContext context) open;

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(widget.open(context)));
  }

  @override
  Widget build(BuildContext context) => const MadarScaffold(title: '', body: SizedBox.shrink());
}

/// A planet hub stand-in: the compact card on a page.
class _CardPage extends StatelessWidget {
  const _CardPage(this.planetKey);

  final String planetKey;

  @override
  Widget build(BuildContext context) => MadarScaffold(
    title: '',
    body: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, 0),
      child: Column(
        children: [
          CustomModulesCard(planetKey: planetKey),
          const SizedBox(height: Space.l),
          // A planet without modules: the "create one here" prompt.
          const CustomModulesCard(planetKey: 'travel'),
        ],
      ),
    ),
  );
}

/// Shows [ModuleScreen] for the module seeded from [key].
class _ModulePage extends StatefulWidget {
  const _ModulePage(this.ids, this.key0);

  final Map<ModuleTemplateKey, String> ids;
  final ModuleTemplateKey key0;

  @override
  State<_ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends State<_ModulePage> {
  @override
  Widget build(BuildContext context) => ModuleScreen(moduleId: widget.ids[widget.key0]!);
}

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    Future<void> Function(MadarDatabase db)? beforePump,
    Future<void> Function(WidgetTester tester)? beforeCapture,
    Size size = const Size(412, 915),
  }) async {
    final (app, _) = await buildCustomApp(tester, home: home, theme: theme, locale: locale, beforePump: beforePump);
    await captureScreen(tester, app, '$_dir/$name', beforeCapture: beforeCapture, logicalSize: size);
  }

  /// Seeds, then builds the page for a seeded module.
  Future<void> moduleShot(
    WidgetTester tester,
    String name,
    ModuleTemplateKey key, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    ModuleChartConfig? chart,
    Future<void> Function(WidgetTester tester)? beforeCapture,
  }) async {
    final ids = <ModuleTemplateKey, String>{};
    await shot(
      tester,
      name,
      Builder(builder: (context) => ids.isEmpty ? const SizedBox.shrink() : _ModulePage(ids, key)),
      theme: theme,
      locale: locale,
      beforePump: (db) async {
        ids.addAll(await seedCustom(db, languageCode: locale.languageCode));
        if (chart != null) {
          await CustomModulesService(Repositories(db)).setChart(ids[key]!, chart);
        }
      },
      beforeCapture: beforeCapture,
    );
  }

  Future<void> seedAr(MadarDatabase db) async => seedCustom(db);
  Future<void> seedEn(MadarDatabase db) async => seedCustom(db, languageCode: 'en');

  Future<void> scroll(WidgetTester tester, double dy) =>
      tester.drag(find.byType(Scrollable).first, Offset(0, -dy), warnIfMissed: false);

  group('modules list', () {
    testWidgets('Arabic, Lapis', (tester) async {
      await shot(tester, 'list_ar_lapis', const CustomModulesScreen(), beforePump: seedAr);
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(
        tester,
        'list_en_pearl',
        const CustomModulesScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
      );
    });

    testWidgets('Empty, Arabic, Emerald', (tester) async {
      await shot(tester, 'empty_ar_emerald', const CustomModulesScreen(), theme: MadarThemeId.emerald);
    });

    testWidgets('Empty, English, Pearl', (tester) async {
      await shot(
        tester,
        'empty_en_pearl',
        const CustomModulesScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });
  });

  group('module page', () {
    testWidgets('tracker, bars, Arabic, Lapis', (tester) async {
      await moduleShot(tester, 'tracker_bar_ar_lapis', ModuleTemplateKey.readingLog);
    });

    testWidgets('tracker entries, Arabic, Lapis', (tester) async {
      await moduleShot(
        tester,
        'tracker_entries_ar_lapis',
        ModuleTemplateKey.readingLog,
        beforeCapture: (tester) => scroll(tester, 760),
      );
    });

    testWidgets('tracker, line, English, Pearl', (tester) async {
      await moduleShot(
        tester,
        'tracker_line_en_pearl',
        ModuleTemplateKey.sleepLog,
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });

    testWidgets('habit streak, Arabic, Desert', (tester) async {
      await moduleShot(tester, 'habit_streak_ar_desert', ModuleTemplateKey.dailyHabit, theme: MadarThemeId.desert);
    });

    testWidgets('heat calendar 90 days, Arabic, Pearl', (tester) async {
      await moduleShot(
        tester,
        'heat_ar_pearl',
        ModuleTemplateKey.readingLog,
        theme: MadarThemeId.pearl,
        chart: const ModuleChartConfig(type: ModuleChartType.heat, fieldId: 'f2', range: 90),
      );
    });

    testWidgets('heat calendar 30 days, English, Lapis', (tester) async {
      await moduleShot(
        tester,
        'heat_en_lapis',
        ModuleTemplateKey.dhikrCounter,
        locale: const Locale('en'),
        chart: const ModuleChartConfig(type: ModuleChartType.heat, fieldId: 'f2', range: 30),
      );
    });

    testWidgets('list, Arabic, Lapis', (tester) async {
      await moduleShot(tester, 'list_module_ar_lapis', ModuleTemplateKey.giftIdeas);
    });

    testWidgets('list, English, Desert', (tester) async {
      await moduleShot(
        tester,
        'list_module_en_desert',
        ModuleTemplateKey.giftIdeas,
        theme: MadarThemeId.desert,
        locale: const Locale('en'),
      );
    });
  });

  group('builder', () {
    Future<void> builderShot(
      WidgetTester tester,
      String name,
      ModuleTemplateKey? key, {
      MadarThemeId theme = MadarThemeId.lapis,
      Locale locale = const Locale('ar'),
      Future<void> Function(WidgetTester tester)? beforeCapture,
    }) async {
      final ids = <ModuleTemplateKey, String>{};
      await shot(
        tester,
        name,
        Builder(
          builder: (context) => key == null
              ? const ModuleBuilderScreen()
              : (ids.isEmpty ? const SizedBox.shrink() : ModuleBuilderScreen(moduleId: ids[key])),
        ),
        theme: theme,
        locale: locale,
        beforePump: (db) async => ids.addAll(await seedCustom(db, languageCode: locale.languageCode)),
        beforeCapture: beforeCapture,
      );
    }

    testWidgets('edit, Arabic, Lapis', (tester) async {
      await builderShot(tester, 'builder_ar_lapis', ModuleTemplateKey.readingLog);
    });

    testWidgets('edit, fields and chart, English, Pearl', (tester) async {
      await builderShot(
        tester,
        'builder_fields_en_pearl',
        ModuleTemplateKey.sleepLog,
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforeCapture: (tester) => scroll(tester, 820),
      );
    });

    testWidgets('fields, Arabic, Aurora', (tester) async {
      await builderShot(
        tester,
        'builder_fields_ar_aurora',
        ModuleTemplateKey.dhikrCounter,
        theme: MadarThemeId.aurora,
        beforeCapture: (tester) => scroll(tester, 820),
      );
    });

    testWidgets('new, Arabic, Emerald', (tester) async {
      await builderShot(tester, 'builder_new_ar_emerald', null, theme: MadarThemeId.emerald);
    });
  });

  group('sheets', () {
    Future<void> sheetShot(
      WidgetTester tester,
      String name,
      Future<void> Function(BuildContext context, Map<ModuleTemplateKey, ModuleDefinition> modules, List<ModuleEntry> sleep) open, {
      MadarThemeId theme = MadarThemeId.lapis,
      Locale locale = const Locale('ar'),
    }) async {
      final modules = <ModuleTemplateKey, ModuleDefinition>{};
      final sleep = <ModuleEntry>[];
      await shot(
        tester,
        name,
        Builder(builder: (context) => _SheetHost((ctx) => open(ctx, modules, sleep))),
        theme: theme,
        locale: locale,
        beforePump: (db) async {
          final ids = await seedCustom(db, languageCode: locale.languageCode);
          final service = CustomModulesService(Repositories(db));
          for (final e in ids.entries) {
            modules[e.key] = (await service.module(e.value))!;
          }
          sleep.addAll(await service.entries(ids[ModuleTemplateKey.sleepLog]!));
        },
      );
    }

    testWidgets('new entry, Arabic, Lapis', (tester) async {
      await sheetShot(
        tester,
        'entry_ar_lapis',
        (context, m, _) => showEntrySheet(context, module: m[ModuleTemplateKey.readingLog]!, now: customTestNow),
      );
    });

    testWidgets('edit entry, English, Pearl', (tester) async {
      await sheetShot(
        tester,
        'entry_edit_en_pearl',
        (context, m, sleep) => showEntrySheet(
          context,
          module: m[ModuleTemplateKey.sleepLog]!,
          entry: sleep.first,
          now: customTestNow,
        ),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });

    testWidgets('list item, Arabic, Desert', (tester) async {
      await sheetShot(
        tester,
        'entry_item_ar_desert',
        (context, m, _) => showEntrySheet(context, module: m[ModuleTemplateKey.giftIdeas]!, now: customTestNow),
        theme: MadarThemeId.desert,
      );
    });

    testWidgets('field editor, Arabic, Pearl', (tester) async {
      await sheetShot(
        tester,
        'field_editor_ar_pearl',
        (context, m, _) => showFieldEditorSheet(context, field: m[ModuleTemplateKey.dhikrCounter]!.field('f1')!),
        theme: MadarThemeId.pearl,
      );
    });

    testWidgets('field editor number, English, Lapis', (tester) async {
      await sheetShot(
        tester,
        'field_editor_en_lapis',
        (context, m, _) => showFieldEditorSheet(context, field: m[ModuleTemplateKey.sleepLog]!.field('f3')!),
        locale: const Locale('en'),
      );
    });

    testWidgets('type picker, Arabic, Lapis', (tester) async {
      await sheetShot(tester, 'type_picker_ar_lapis', (context, _, _) => showFieldTypePicker(context));
    });

    testWidgets('template gallery, Arabic, Lapis', (tester) async {
      await sheetShot(tester, 'gallery_ar_lapis', (context, _, _) => showTemplateGallery(context));
    });

    testWidgets('template gallery, English, Pearl', (tester) async {
      await sheetShot(
        tester,
        'gallery_en_pearl',
        (context, _, _) => showTemplateGallery(context),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });
  });

  group('planet card', () {
    testWidgets('Arabic, Lapis', (tester) async {
      await shot(tester, 'card_ar_lapis', const _CardPage('growth'), beforePump: seedAr);
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(
        tester,
        'card_en_pearl',
        const _CardPage('growth'),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
      );
    });
  });
}
