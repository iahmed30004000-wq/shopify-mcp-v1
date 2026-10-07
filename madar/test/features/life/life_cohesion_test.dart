// Cohesion of the Life worlds' planet pages with the rest of the Astrolabe
// Orbit, as a reader sees the page: one name for a world on one page, the
// Neglect Radar agreeing with the Family card about the same person, a
// person's own initial on their orb, meters read in full. Real fonts.
//
// Three checks are SKIPPED until the owner's design pass (next week): they
// are layout choices, not defects – the Body hub showing today's water and
// fast in two adjacent cards, the Life hubs' 2-across tools vs the 3-column
// grid of Faith/Health/Money, and Growth's "All goals" both as the card's
// link and as a tool tile.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_gate.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/widgets/widgets.dart' show GlassCard;
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/family/presentation/widgets/family_widgets.dart' show personInitial;
import 'package:madar/features/money/hub/money_hub.dart' show MoneyTools;
import 'package:madar/features/orbit/presentation/planet/life_hubs.dart' show WorkHub;
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';

import '../body/body_harness.dart' show bodyTestNow;
import '../body/body_seed.dart';
import '../family/family_seed.dart';
import '../growth/growth_harness.dart' show growthTestNow, seedScenario;
import '../lock/lock_test_utils.dart';
import '../../helpers/screenshot_harness.dart' show loadMadarFonts;
import '../../helpers/test_app.dart';

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _planet(
  WidgetTester tester,
  String key,
  String lang, {
  DateTime? now,
  Future<void> Function(MadarDatabase db)? seed,
}) async {
  usePhoneSurface(tester);
  final db = await openTestDatabase(tester, languageCode: lang);
  if (seed != null) await tester.runAsync(() => seed(db));
  final setup = await buildMadarTestApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang),
    initialLocation: AppRoutes.planetOf(key),
    now: now,
    database: false,
    overrides: [databaseUnlockProvider.overrideWithValue(AsyncValue.data(db)), ...LockFixture.empty().overrides],
  );
  await tester.pumpWidget(setup.app);
  await _frames(tester, 40);
}

/// Every text of the planet sheet, built while scrolling it end to end.
Future<List<String>> _sheetTexts(WidgetTester tester) async {
  final sheet = find
      .descendant(
        of: find.byType(PlanetModulePage),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      )
      .first;
  final position = tester.state<ScrollableState>(sheet).position;
  final texts = <String>{};
  for (var i = 0; i < 24; i++) {
    for (final e in find.descendant(of: sheet, matching: find.byType(RichText)).evaluate()) {
      texts.add((e.widget as RichText).text.toPlainText());
    }
    if (position.pixels >= position.maxScrollExtent - 1) break;
    position.jumpTo((position.pixels + 300).clamp(0, position.maxScrollExtent));
    await _frames(tester, 6);
  }
  return texts.toList();
}

/// Scrolls the planet sheet until [target] is built and on screen.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  final sheet = find
      .descendant(
        of: find.byType(PlanetModulePage),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      )
      .first;
  final position = tester.state<ScrollableState>(sheet).position;
  for (var i = 0; i < 24 && target.evaluate().isEmpty; i++) {
    position.jumpTo((position.pixels + 300).clamp(0, position.maxScrollExtent));
    await _frames(tester, 6);
  }
  await _frames(tester, 10);
}

/// The width of the glass tile holding [label] inside [hub].
double _tileWidth(WidgetTester tester, Type hub, String label) {
  final tile = find.ancestor(
    of: find.descendant(of: find.byType(hub), matching: find.text(label)),
    matching: find.byType(GlassCard),
  );
  return tester.getSize(tile.first).width;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await _frames(tester, 4);
}

/// Skipped until the design pass with the owner (next week): a layout
/// choice, not a defect (see the header).
const _design = true;

void main() {
  // Real glyph widths (the test font's square glyphs would truncate more).
  setUpAll(loadMadarFonts);
  for (final lang in ['ar', 'en']) {
    testWidgets('planet work $lang: one name for the world on its own page', (tester) async {
      await _planet(tester, 'work', lang);
      final texts = await _sheetTexts(tester);
      await _unmount(tester);
      final planet = lang == 'ar' ? 'الكوكب' : 'planet';
      final world = lang == 'ar' ? 'العالم' : 'world';
      final saysPlanet = texts.where((s) => s.contains(planet)).toList();
      final saysWorld = texts.where((s) => s.contains(world)).toList();
      expect(
        saysPlanet.isNotEmpty && saysWorld.isNotEmpty,
        isFalse,
        reason: 'the same page calls the world both "$planet" ($saysPlanet) and "$world" ($saysWorld)',
      );
    });

    testWidgets('planet body $lang: today\'s water and fast are read once', (tester) async {
      await _planet(
        tester,
        'body',
        lang,
        now: bodyTestNow,
        seed: (db) => seedBody(db, BodySeed.full, now: bodyTestNow, arabic: lang == 'ar'),
      );
      final texts = await _sheetTexts(tester);
      await _unmount(tester);
      // The seed's water today is 1,250 ml; the running fast is 14:35 long.
      final water = texts.where((s) => RegExp(r'1[.,]25\b|1,250|١٫٢٥|١٬٢٥٠').hasMatch(s)).toList();
      final fast = texts.where((s) => RegExp(r'14:35|١٤:٣٥').hasMatch(s)).toList();
      expect(
        (water: water, fast: fast),
        predicate<({List<String> water, List<String> fast})>((r) => r.water.length <= 1 && r.fast.length <= 1),
        reason:
            'the Body hub repeats today\'s water ($water) and the fast ($fast) in adjacent cards, in different units/precision',
      );
    }, skip: _design);
  }

  testWidgets('planet family ar: the Radar speaks of mum the way her card does', (tester) async {
    await _planet(tester, 'family', 'ar', now: familyTestNow, seed: (db) => seedFamily(db));
    final texts = await _sheetTexts(tester);
    await _unmount(tester);
    final card = texts.where((s) => s.contains('فات الموعد بـ٣ أيام')).toList();
    final radar = texts
        .map((s) => s.replaceAll(RegExp('[\u2066-\u2069]'), ''))
        .where((s) => s.startsWith('أمي') && s.contains('متأخر'))
        .toList();
    expect(card, isNotEmpty, reason: 'the Family card states mum\'s overdue days');
    expect(
      radar,
      isEmpty,
      reason:
          'the Radar row uses the masculine "متأخر" for a woman ("أمي") and a different wording than her card ($card)',
    );
  });

  testWidgets('planet work vs money en: the tools wear one seal (same tile size)', (tester) async {
    final l = lookupL10n(const Locale('en'));
    await _planet(tester, 'money', 'en');
    await _reveal(tester, find.descendant(of: find.byType(MoneyTools), matching: find.text(l.moneyHubToolLedger)));
    final money = _tileWidth(tester, MoneyTools, l.moneyHubToolLedger);
    await _unmount(tester);
    await _planet(tester, 'work', 'en');
    await _reveal(tester, find.descendant(of: find.byType(WorkHub), matching: find.text(l.workBoards)));
    final work = _tileWidth(tester, WorkHub, l.workBoards);
    await _unmount(tester);
    expect(
      work,
      moreOrLessEquals(money, epsilon: 1),
      reason:
          'a Work tool tile is ${work.toStringAsFixed(1)} dp wide, a Money tool tile ${money.toStringAsFixed(1)} dp '
          '(Faith, Health and Money lay their tools on a 3-column grid; the Life hubs stretch 2 tools across the row)',
    );
  }, skip: _design);

  test('family avatars: the initial is the person\'s, not a title or kinship word', () {
    // The sample family (family_seed.dart) as the user names them: in Arabic
    // four of six orbs read «أ» (أمي، أخي أحمد، أختي ليلى، أبو يوسف) and the
    // engineer reads «م» (from «م.»); in English Mr. Jones reads «M».
    expect(
      {
        'Mr. Jones': personInitial('Mr. Jones'),
        'م. خالد': personInitial('م. خالد'),
        'أختي ليلى': personInitial('أختي ليلى'),
        'أخي أحمد': personInitial('أخي أحمد'),
      },
      {'Mr. Jones': 'J', 'م. خالد': 'خ', 'أختي ليلى': 'ل', 'أخي أحمد': 'أ'},
    );
  });

  testWidgets('planet family en: a waiting moon\'s meter reads in full', (tester) async {
    final l = lookupL10n(const Locale('en'));
    await _planet(tester, 'family', 'en', now: familyTestNow, seed: (db) => seedFamily(db, arabic: false));
    await _reveal(tester, find.text(l.orbitUiMoonWaiting));
    final meters = find.text(l.orbitUiMoonWaiting);
    final cut = <String>[
      for (final e in meters.evaluate())
        if (tester
            .renderObject<RenderParagraph>(
              find.descendant(of: find.byWidget(e.widget), matching: find.byType(RichText)).first,
            )
            .didExceedMaxLines)
          (e.widget as Text).data ?? '',
    ];
    final found = meters.evaluate().length;
    await _unmount(tester);
    expect(found, greaterThan(0), reason: 'the sample family has moons nobody has tended yet');
    expect(
      cut,
      isEmpty,
      reason: '"${l.orbitUiMoonWaiting}" is cut to "Waiting on …" in $found moon rows of the Family world',
    );
  });

  testWidgets('planet growth en: one door per screen, named once', (tester) async {
    final l = lookupL10n(const Locale('en'));
    await _planet(
      tester,
      'growth',
      'en',
      now: growthTestNow,
      seed: (db) => seedScenario(db, lang: 'en'),
    );
    final sheet = find
        .descendant(
          of: find.byType(PlanetModulePage),
          matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
        )
        .first;
    final position = tester.state<ScrollableState>(sheet).position;
    final doors = <Element>{};
    for (var i = 0; i < 24; i++) {
      doors.addAll(find.descendant(of: sheet, matching: find.text(l.growthCardOpenAll)).evaluate());
      if (position.pixels >= position.maxScrollExtent - 1) break;
      position.jumpTo((position.pixels + 300).clamp(0, position.maxScrollExtent));
      await _frames(tester, 6);
    }
    final count = doors.length;
    await _unmount(tester);
    expect(
      count,
      lessThanOrEqualTo(1),
      reason:
          '"${l.growthCardOpenAll}" appears $count times on the Growth hub (the card\'s header link and a tool tile), both to /growth',
    );
  }, skip: _design);
}
