@Tags(['screenshot'])
// Rendering glass + cosmos shaders on a shared, loaded box can take minutes
// per shot.
@Timeout(Duration(minutes: 30))
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/search/search.dart';

import '../../helpers/screenshot_harness.dart';
import 'search_harness.dart';

const _dir = 'search';

/// A home-panel stand-in: the launcher pill and the app-bar icon.
class _LauncherPage extends StatelessWidget {
  const _LauncherPage();

  @override
  Widget build(BuildContext context) => const MadarScaffold(
    title: 'مَدار',
    actions: [SearchLauncher.icon()],
    body: Padding(
      padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, 0),
      child: Column(children: [SearchLauncher()]),
    ),
  );
}

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name, {
    Widget? home,
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    List<String> recent = const [],
    bool withQuran = false,
    String? query,
    Future<void> Function(WidgetTester tester)? then,
  }) async {
    final (app, _) = await buildSearchApp(
      tester,
      home: home,
      theme: theme,
      locale: locale,
      recent: recent,
      withQuran: withQuran,
    );
    await captureScreen(
      tester,
      app,
      '$_dir/$name',
      beforeCapture: query == null && then == null
          ? null
          : (tester) async {
              if (query != null) {
                await tester.enterText(find.byType(TextField), query);
                await settle(tester, frames: 16);
              }
              if (then != null) await then(tester);
            },
    );
  }

  testWidgets('recent searches (ar, lapis)', (tester) async {
    await shot(tester, 'search_recent_ar_lapis', recent: ['الطبيب', 'راتب أيلول', 'آية الكرسي', 'Istanbul']);
  });

  testWidgets('introduction (en, pearl)', (tester) async {
    await shot(tester, 'search_intro_en_pearl', theme: MadarThemeId.pearl, locale: const Locale('en'));
  });

  testWidgets('grouped results (ar, lapis)', (tester) async {
    await shot(tester, 'search_results_ar_lapis', query: 'الطبيب');
  });

  testWidgets('planet and module filters (ar, emerald)', (tester) async {
    await shot(
      tester,
      'search_filtered_ar_emerald',
      theme: MadarThemeId.emerald,
      query: 'دواء',
      then: (tester) async {
        final chip = find.byWidgetPredicate((w) => w is MadarChip && w.label.startsWith('الصحة ('));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await settle(tester, frames: 12);
      },
    );
  });

  testWidgets('Quran ayat with other results (ar, desert)', (tester) async {
    await shot(tester, 'search_quran_ar_desert', theme: MadarThemeId.desert, withQuran: true, query: 'الرحمن');
  });

  testWidgets('results with keyboard selection (en, pearl)', (tester) async {
    await shot(
      tester,
      'search_results_en_pearl',
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      query: 'blood',
      then: (tester) async {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await settle(tester, frames: 6);
      },
    );
  });

  testWidgets('no results (en, aurora)', (tester) async {
    await shot(tester, 'search_empty_en_aurora', theme: MadarThemeId.aurora, locale: const Locale('en'), query: 'giraffe');
  });

  testWidgets('launcher (ar, lapis)', (tester) async {
    await shot(tester, 'search_launcher_ar_lapis', home: const _LauncherPage());
  });
}
