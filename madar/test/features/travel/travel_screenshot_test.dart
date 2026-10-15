@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/travel/travel.dart';

import '../../helpers/screenshot_harness.dart';
import 'travel_harness.dart';

const _dir = 'phase6/travel';

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget Function(TravelScenario s) home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    bool seed = true,
    Future<void> Function(WidgetTester tester)? beforeCapture,
    Size size = const Size(412, 915),
  }) async {
    final lang = locale.languageCode;
    TravelScenario? s;
    final (app, _) = await buildTravelApp(
      tester,
      home: Builder(builder: (_) => home(s ?? TravelScenario())),
      theme: theme,
      locale: locale,
      overrides: [travelUsePrayerLocationProvider.overrideWithValue((context, place) async {})],
      beforePump: seed ? (MadarDatabase db) async => s = await seedTravelScenario(db, lang: lang) : null,
    );
    await captureScreen(tester, app, '$_dir/$name', beforeCapture: beforeCapture, logicalSize: size);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> frames(WidgetTester tester, [int n = 24]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await settle(tester);
    await tester.scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);
    await frames(tester);
  }

  const en = Locale('en');

  group('trip', () {
    testWidgets('under way: prayer times there first – Arabic, Lapis', (tester) async {
      await shot(tester, 'trip_current_ar_lapis', (s) => TripScreen(tripId: s.cairo), beforeCapture: settle);
    });

    testWidgets('under way – English, Pearl', (tester) async {
      await shot(
        tester,
        'trip_current_en_pearl',
        (s) => TripScreen(tripId: s.cairo),
        theme: MadarThemeId.pearl,
        locale: en,
        beforeCapture: settle,
      );
    });

    testWidgets('coming up: warnings and packing list – Arabic, Lapis (full length)', (tester) async {
      await shot(
        tester,
        'trip_upcoming_full_ar_lapis',
        (s) => TripScreen(tripId: s.istanbul),
        size: const Size(412, 2350),
        beforeCapture: settle,
      );
    });

    testWidgets('coming up: packing list – English, Pearl', (tester) async {
      await shot(
        tester,
        'trip_upcoming_en_pearl',
        (s) => TripScreen(tripId: s.istanbul),
        theme: MadarThemeId.pearl,
        locale: en,
        beforeCapture: settle,
      );
    });

    testWidgets('destination prayer times and qibla – Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'trip_prayer_ar_emerald',
        (s) => TripScreen(tripId: s.istanbul),
        theme: MadarThemeId.emerald,
        beforeCapture: (tester) => scrollTo(tester, find.byType(QiblaMiniDial)),
      );
    });

    testWidgets('destination prayer times – English, Desert', (tester) async {
      await shot(
        tester,
        'trip_prayer_en_desert',
        (s) => TripScreen(tripId: s.umrah),
        theme: MadarThemeId.desert,
        locale: en,
        beforeCapture: (tester) => scrollTo(tester, find.byType(QiblaMiniDial)),
      );
    });

    testWidgets('trip editor with a listed city – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'trip_sheet_ar_lapis',
        (s) => TripScreen(tripId: s.istanbul),
        beforeCapture: (tester) async {
          await settle(tester);
          await tester.tap(find.byIcon(Icons.edit_rounded).first);
          await frames(tester, 30);
        },
      );
    });
  });

  group('travel screen', () {
    testWidgets('trips – Arabic, Lapis', (tester) async {
      await shot(tester, 'trips_ar_lapis', (_) => const TravelScreen(showPast: true), beforeCapture: settle);
    });

    testWidgets('trips – English, Pearl', (tester) async {
      await shot(
        tester,
        'trips_en_pearl',
        (_) => const TravelScreen(showPast: true),
        theme: MadarThemeId.pearl,
        locale: en,
        beforeCapture: settle,
      );
    });

    testWidgets('trips – Arabic, Desert', (tester) async {
      await shot(tester, 'trips_ar_desert', (_) => const TravelScreen(), theme: MadarThemeId.desert, beforeCapture: settle);
    });

    testWidgets('no trips yet – Arabic, Pearl', (tester) async {
      await shot(
        tester,
        'trips_empty_ar_pearl',
        (_) => const TravelScreen(),
        theme: MadarThemeId.pearl,
        seed: false,
        beforeCapture: settle,
      );
    });

    testWidgets('documents – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'documents_ar_lapis',
        (_) => const TravelScreen(initialTab: TravelTab.documents),
        beforeCapture: settle,
      );
    });

    testWidgets('documents – English, Pearl', (tester) async {
      await shot(
        tester,
        'documents_en_pearl',
        (_) => const TravelScreen(initialTab: TravelTab.documents),
        theme: MadarThemeId.pearl,
        locale: en,
        beforeCapture: settle,
      );
    });

    testWidgets('documents – Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'documents_ar_emerald',
        (_) => const TravelScreen(initialTab: TravelTab.documents),
        theme: MadarThemeId.emerald,
        beforeCapture: settle,
      );
    });

    testWidgets('document editor – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'document_sheet_ar_lapis',
        (_) => const TravelScreen(initialTab: TravelTab.documents),
        beforeCapture: (tester) async {
          await settle(tester);
          await tester.tap(find.byType(DocumentTile).first);
          await frames(tester, 30);
        },
      );
    });
  });

  group('templates', () {
    testWidgets('templates – Arabic, Lapis', (tester) async {
      await shot(tester, 'templates_ar_lapis', (_) => const PackingTemplatesScreen(), beforeCapture: settle);
    });

    testWidgets('templates – English, Pearl', (tester) async {
      await shot(
        tester,
        'templates_en_pearl',
        (_) => const PackingTemplatesScreen(),
        theme: MadarThemeId.pearl,
        locale: en,
        beforeCapture: settle,
      );
    });

    testWidgets('template editor – Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'template_editor_ar_emerald',
        (s) => PackingTemplateScreen(templateId: s.essentials),
        theme: MadarThemeId.emerald,
        beforeCapture: settle,
      );
    });

    testWidgets('no templates, starter lists offered – Arabic, Pearl', (tester) async {
      await shot(
        tester,
        'templates_empty_ar_pearl',
        (_) => const PackingTemplatesScreen(),
        theme: MadarThemeId.pearl,
        seed: false,
        beforeCapture: settle,
      );
    });
  });

  group('hub card', () {
    Widget hub(TravelScenario s) => const MadarScaffold(
      title: '',
      body: Padding(padding: EdgeInsetsDirectional.all(Space.gutter), child: TravelTodayCard()),
    );

    testWidgets('today card – Arabic, Lapis', (tester) async {
      await shot(tester, 'today_card_ar_lapis', hub, size: const Size(412, 520), beforeCapture: settle);
    });

    testWidgets('today card – English, Pearl', (tester) async {
      await shot(
        tester,
        'today_card_en_pearl',
        hub,
        theme: MadarThemeId.pearl,
        locale: en,
        size: const Size(412, 520),
        beforeCapture: settle,
      );
    });
  });
}
