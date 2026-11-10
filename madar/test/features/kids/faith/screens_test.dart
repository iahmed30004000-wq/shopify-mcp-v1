// Prayer and wudu steps, stories, manners and adhkar: driven only by approved
// items; zero approved => the calm «قريبًا».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/faith/domain/kids_art.dart';
import 'package:madar/features/kids/faith/domain/kids_religious_item.dart';
import 'package:madar/features/kids/faith/presentation/kids_adhkar_screen.dart';
import 'package:madar/features/kids/faith/presentation/kids_steps_screen.dart';
import 'package:madar/features/kids/faith/presentation/kids_stories_screen.dart';
import 'package:madar/features/kids/faith/presentation/widgets/kids_scene_art.dart';

import 'faith_harness.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _show(WidgetTester tester, Widget screen, List<KidsReligiousItem> items, {double scale = 1.0}) async {
  _phone(tester);
  await tester.pumpWidget(faithApp(screen, overrides: contentOverrides(items), textScale: scale));
  await tester.pump();
}

Future<void> _tapNext(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

Finder _inBeads(String text) => find.descendant(of: find.byType(BeadCounter), matching: find.text(text));

void main() {
  group('steps', () {
    final steps = [
      item('w2', KidsReligiousKind.wuduStep, text: 'W-SECOND', order: 2, art: const [KidsArt.water]),
      item('w1', KidsReligiousKind.wuduStep, text: 'W-FIRST', order: 1, title: 'W-TITLE', art: const [KidsArt.water, KidsArt.drops]),
      item('w3', KidsReligiousKind.wuduStep, text: 'W-HIDDEN', order: 3, approved: false),
      item('p1', KidsReligiousKind.prayerStep, text: 'P-FIRST', order: 1),
    ];

    testWidgets('in order, one at a time, with the step badge; unapproved steps are skipped', (tester) async {
      await _show(tester, const PrayerWuduScreen(), steps);
      expect(find.text('W-FIRST'), findsOneWidget);
      expect(find.text('W-TITLE'), findsOneWidget);
      expect(find.text('١'), findsWidgets); // badge, Arabic-Indic
      expect(find.text('١ من ٢'), findsOneWidget); // two APPROVED wudu steps, not three
      await _tapNext(tester, 'التالي');
      expect(find.text('W-SECOND'), findsOneWidget);
      expect(find.text('٢ من ٢'), findsOneWidget);
      expect(find.text('W-HIDDEN'), findsNothing);
    });

    testWidgets('the prayer tab has its own steps', (tester) async {
      await _show(tester, const PrayerWuduScreen(), steps);
      await tester.tap(find.text('الصلاة'));
      await tester.pump();
      expect(find.text('P-FIRST'), findsOneWidget);
      expect(find.text('W-FIRST'), findsNothing);
    });

    testWidgets('a tab with nothing approved shows «قريبًا» inside it', (tester) async {
      await _show(tester, const PrayerWuduScreen(), [steps.first]);
      await tester.tap(find.text('الصلاة'));
      await tester.pump();
      expect(find.text('قريبًا'), findsOneWidget);
    });

    testWidgets('zero items: «قريبًا»', (tester) async {
      await _show(tester, const PrayerWuduScreen(), const []);
      expect(find.text('قريبًا'), findsOneWidget);
    });

    testWidgets('fits a phone at text scale 1.3', (tester) async {
      await _show(tester, const PrayerWuduScreen(), steps, scale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });

  group('stories (places, light and objects, never a figure)', () {
    final two = [
      item('a1', KidsReligiousKind.story, text: 'A-PAGE-1', group: 'a', title: 'A-NAME', order: 1, art: const [KidsArt.dunes, KidsArt.palm, KidsArt.lantern]),
      item('a2', KidsReligiousKind.story, text: 'A-PAGE-2', group: 'a', order: 2, art: const [KidsArt.lightColumn, KidsArt.path]),
      item('b1', KidsReligiousKind.story, text: 'B-PAGE-1', group: 'b', title: 'B-NAME', art: const [KidsArt.sea, KidsArt.ship]),
    ];

    testWidgets('with several stories a list comes first, then the pages', (tester) async {
      await _show(tester, const StoriesScreen(), two);
      expect(find.text('A-NAME'), findsOneWidget);
      expect(find.text('B-NAME'), findsOneWidget);
      expect(find.text('A-PAGE-1'), findsNothing);
      await tester.tap(find.text('A-NAME'));
      await tester.pump();
      expect(find.text('A-PAGE-1'), findsOneWidget);
      await _tapNext(tester, 'التالي');
      expect(find.text('A-PAGE-2'), findsOneWidget);
    });

    testWidgets('the illustration is made only of allow-listed art', (tester) async {
      await _show(tester, const StoriesScreen(), [two.first, two[1]]);
      final art = tester.widget<KidsSceneArt>(find.byType(KidsSceneArt));
      expect(art.art, everyElement(isA<KidsArt>()));
      expect({for (final a in art.art) a.name}.difference(kidsArtAllowList), isEmpty);
      expect(find.byType(KidsSceneArt), findsOneWidget);
    });

    testWidgets('one story goes straight to its pages', (tester) async {
      await _show(tester, const StoriesScreen(), [two.first, two[1]]);
      expect(find.text('A-PAGE-1'), findsOneWidget);
    });

    testWidgets('the painter draws every allowed art without error, at phone width', (tester) async {
      _phone(tester);
      await tester.pumpWidget(faithApp(const SingleChildScrollView(child: KidsSceneArt(art: KidsArt.values))));
      await tester.pumpWidget(faithApp(const SingleChildScrollView(child: KidsSceneArt(art: KidsArt.values, dayTone: true))));
      expect(tester.takeException(), isNull);
    });

    testWidgets('zero items: «قريبًا»', (tester) async {
      await _show(tester, const StoriesScreen(), const []);
      expect(find.text('قريبًا'), findsOneWidget);
    });
  });

  group('manners', () {
    testWidgets('approved cards only, in order', (tester) async {
      await _show(tester, const MannersScreen(), [
        item('m2', KidsReligiousKind.manner, text: 'M-SECOND', order: 2),
        item('m1', KidsReligiousKind.manner, text: 'M-FIRST', order: 1),
        item('m3', KidsReligiousKind.manner, text: 'M-HIDDEN', order: 3, approved: false),
      ]);
      expect(find.text('M-FIRST'), findsOneWidget);
      await _tapNext(tester, 'التالي');
      expect(find.text('M-SECOND'), findsOneWidget);
      expect(find.text('التالي'), findsOneWidget); // present but dead on the last card
      expect(find.text('M-HIDDEN'), findsNothing);
    });

    testWidgets('zero items: «قريبًا»', (tester) async {
      await _show(tester, const MannersScreen(), const []);
      expect(find.text('قريبًا'), findsOneWidget);
    });
  });

  group('adhkar', () {
    final list = [
      item('d1', KidsReligiousKind.dhikr, text: 'D-ONE', group: 'morning', repeat: 3, order: 1),
      item('d2', KidsReligiousKind.dhikr, text: 'D-TWO', group: 'morning', repeat: 100, order: 2),
      item('e1', KidsReligiousKind.dhikr, text: 'E-ONE', group: 'evening', repeat: 1),
      item('x', KidsReligiousKind.dhikr, text: 'D-HIDDEN', group: 'morning', repeat: 1, order: 9, approved: false),
    ];

    test('the bead ring maths: capped beads, proportional fill, never over-full', () {
      expect(BeadCounter.beadsShown(3), 3);
      expect(BeadCounter.beadsShown(100), BeadCounter.maxBeads);
      expect(BeadCounter.beadsShown(0), 1);
      expect(BeadCounter.beadsFilled(0, 3), 0);
      expect(BeadCounter.beadsFilled(1, 3), 1);
      expect(BeadCounter.beadsFilled(3, 3), 3);
      expect(BeadCounter.beadsFilled(50, 100), 20);
      expect(BeadCounter.beadsFilled(100, 100), BeadCounter.maxBeads);
      expect(BeadCounter.beadsFilled(999, 3), 3);
    });

    testWidgets('the circle fills with every tap and stops at the total', (tester) async {
      await _show(tester, const KidsAdhkarScreen(), list);
      expect(find.text('D-ONE'), findsOneWidget);
      expect(_inBeads('٠'), findsOneWidget);
      expect(_inBeads('من ٣'), findsOneWidget);
      for (var i = 1; i <= 3; i++) {
        await tester.tap(find.byType(BeadCounter));
        await tester.pump();
        expect(_inBeads('٠١٢٣'[i]), findsOneWidget);
      }
      expect(find.text('خلّص العدّ!'), findsOneWidget);
      await tester.tap(find.byType(BeadCounter), warnIfMissed: false);
      await tester.pump();
      expect(_inBeads('٣'), findsOneWidget); // did not go to 4
    });

    testWidgets('the count is kept when going to the next dhikr and back', (tester) async {
      await _show(tester, const KidsAdhkarScreen(), list);
      await tester.tap(find.byType(BeadCounter));
      await tester.pump();
      await _tapNext(tester, 'الذكر الجاي');
      expect(find.text('D-TWO'), findsOneWidget);
      expect(_inBeads('من ١٠٠'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pump();
      expect(_inBeads('١'), findsOneWidget);
    });

    testWidgets('morning and evening tabs; the unapproved dhikr is absent', (tester) async {
      await _show(tester, const KidsAdhkarScreen(), list);
      expect(find.text('D-HIDDEN'), findsNothing);
      await tester.tap(find.text('المساء'));
      await tester.pump();
      expect(find.text('E-ONE'), findsOneWidget);
    });

    testWidgets('zero items: «قريبًا»; fits a phone at text scale 1.3', (tester) async {
      await _show(tester, const KidsAdhkarScreen(), const []);
      expect(find.text('قريبًا'), findsOneWidget);
      await _show(tester, const KidsAdhkarScreen(), list, scale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });
}
