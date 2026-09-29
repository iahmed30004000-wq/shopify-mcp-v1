@Tags(['screenshot'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/family/family.dart';

import '../../helpers/screenshot_harness.dart';
import 'family_harness.dart';
import 'family_seed.dart';

const _dir = 'phase6/family';

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

/// The Family planet hub stand-in: the compact card on a page.
class _CardPage extends StatelessWidget {
  const _CardPage();

  @override
  Widget build(BuildContext context) => const MadarScaffold(
    title: '',
    body: Padding(
      padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, 0),
      child: Align(alignment: Alignment.topCenter, child: FamilyTodayCard()),
    ),
  );
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
    final (app, _) = await buildFamilyApp(tester, home: home, theme: theme, locale: locale, beforePump: beforePump);
    await captureScreen(tester, app, '$_dir/$name', beforeCapture: beforeCapture, logicalSize: size);
  }

  Future<void> seedAr(MadarDatabase db) async => seedFamily(db);
  Future<void> seedEn(MadarDatabase db) async => seedFamily(db, arabic: false);

  Future<String> mumId(MadarDatabase db) async =>
      (await Repositories(db).people.getAll()).firstWhere((p) => p.relation == 'mother').id;

  group('family list', () {
    testWidgets('Arabic, Lapis', (tester) async {
      await shot(tester, 'list_ar_lapis', const FamilyScreen(), beforePump: seedAr);
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(
        tester,
        'list_en_pearl',
        const FamilyScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
      );
    });

    testWidgets('Arabic, Pearl, scrolled', (tester) async {
      await shot(
        tester,
        'list_scrolled_ar_pearl',
        const FamilyScreen(),
        theme: MadarThemeId.pearl,
        beforePump: seedAr,
        beforeCapture: (tester) => tester.drag(find.byType(ListView), const Offset(0, -520)),
      );
    });

    testWidgets('Arabic, Desert, manual order', (tester) async {
      await shot(
        tester,
        'list_manual_ar_desert',
        const FamilyScreen(),
        theme: MadarThemeId.desert,
        beforePump: (db) async {
          await seedFamily(db);
          await FamilyService(Repositories(db)).saveSettings(const FamilySettings(sortMode: FamilySortMode.manual));
        },
      );
    });

    testWidgets('empty, English, Emerald', (tester) async {
      await shot(
        tester,
        'empty_en_emerald',
        const FamilyScreen(),
        theme: MadarThemeId.emerald,
        locale: const Locale('en'),
      );
    });
  });

  group('person', () {
    for (final (name, theme, locale, scroll) in [
      ('person_ar_lapis', MadarThemeId.lapis, const Locale('ar'), 0.0),
      ('person_stats_ar_lapis', MadarThemeId.lapis, const Locale('ar'), -560.0),
      ('person_en_pearl', MadarThemeId.pearl, const Locale('en'), 0.0),
      ('person_history_en_pearl', MadarThemeId.pearl, const Locale('en'), -1100.0),
      ('person_ar_aurora', MadarThemeId.aurora, const Locale('ar'), -560.0),
    ]) {
      testWidgets(name, (tester) async {
        late String id;
        await shot(
          tester,
          name,
          Builder(builder: (_) => PersonScreen(personId: id)),
          theme: theme,
          locale: locale,
          beforePump: (db) async {
            await seedFamily(db, arabic: locale.languageCode == 'ar');
            id = await mumId(db);
          },
          beforeCapture: scroll == 0 ? null : (tester) => tester.drag(find.byType(ListView), Offset(0, scroll)),
        );
      });
    }
  });

  group('contacted sheet', () {
    for (final (name, theme, locale, pickWhen) in [
      ('contacted_ar_lapis', MadarThemeId.lapis, const Locale('ar'), null),
      ('contacted_yesterday_ar_desert', MadarThemeId.desert, const Locale('ar'), 'yesterday'),
      ('contacted_en_pearl', MadarThemeId.pearl, const Locale('en'), 'yesterday'),
    ]) {
      testWidgets(name, (tester) async {
        final ar = locale.languageCode == 'ar';
        await shot(
          tester,
          name,
          _SheetHost((context) => showContactedSheet(context, name: ar ? 'أمي' : 'Mum', channel: ContactChannel.call)),
          theme: theme,
          locale: locale,
          beforeCapture: pickWhen == null
              ? null
              : (tester) async {
                  await tester.tap(find.text(ar ? 'أمس' : 'Yesterday'));
                  await tester.pump(const Duration(milliseconds: 400));
                  await tester.enterText(find.byType(TextField), ar ? 'اطمأننت على صحتها' : 'Checked on her health');
                },
        );
      });
    }
  });

  group('person sheet', () {
    testWidgets('new person, Arabic, Pearl', (tester) async {
      await shot(
        tester,
        'person_sheet_ar_pearl',
        _SheetHost((context) => showPersonSheet(context)),
        theme: MadarThemeId.pearl,
        beforeCapture: (tester) async {
          await tester.enterText(find.byType(TextField).first, 'أمي');
          await tester.pump();
          await tester.tap(find.text('أمي').last);
          await tester.pump(const Duration(milliseconds: 300));
          FocusManager.instance.primaryFocus?.unfocus();
        },
      );
    });

    testWidgets('edit, English, Lapis', (tester) async {
      late PersonRow mum;
      await shot(
        tester,
        'person_sheet_edit_en_lapis',
        _SheetHost((context) => showPersonSheet(context, person: mum)),
        locale: const Locale('en'),
        beforePump: (db) async {
          await seedFamily(db, arabic: false);
          mum = (await Repositories(db).people.getAll()).first;
        },
      );
    });
  });

  group('today card', () {
    testWidgets('Arabic, Lapis', (tester) async {
      await shot(tester, 'today_card_ar_lapis', const _CardPage(), beforePump: seedAr, size: const Size(412, 560));
    });

    testWidgets('English, Pearl', (tester) async {
      await shot(
        tester,
        'today_card_en_pearl',
        const _CardPage(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: seedEn,
        size: const Size(412, 560),
      );
    });
  });

  group('reminder settings', () {
    testWidgets('Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'settings_ar_emerald',
        _SheetHost((context) => showFamilySettingsSheet(context, settings: const FamilySettings())),
        theme: MadarThemeId.emerald,
      );
    });
  });
}
