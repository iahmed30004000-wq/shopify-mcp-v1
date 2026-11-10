// The religious gate: dark behind the flag, and an unapproved item is never
// rendered (the child sees a calm «قريبًا»).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/core/kids_section.dart';
import 'package:madar/features/kids/faith/domain/kids_religious_item.dart';
import 'package:madar/features/kids/faith/faith.dart';

import 'faith_harness.dart';

final _all = [juzAmmaSection, prayerWuduSection, storiesOfProphetsSection, mannersSection, kidsAdhkarSection];

void main() {
  group('the home', () {
    test('five sections, unique ids, every one religious', () {
      expect(_all.map((s) => s.id).toSet(), hasLength(5));
      expect(_all.every((s) => s.religious), isTrue);
    });

    test('with the flag false NONE of them is in visibleKidsSectionsProvider', () {
      final c = ProviderContainer(overrides: [kidsSectionsProvider.overrideWithValue(_all)]);
      addTearDown(c.dispose);
      expect(c.read(kidsReligiousUnlockedProvider), isFalse); // the default
      expect(c.read(visibleKidsSectionsProvider), isEmpty);
    });

    test('with the flag true they all appear', () {
      final c = ProviderContainer(
        overrides: [
          kidsSectionsProvider.overrideWithValue(_all),
          kidsReligiousUnlockedProvider.overrideWithValue(true),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(visibleKidsSectionsProvider), hasLength(5));
    });
  });

  // One approved item per screen, so a screen showing anything is visible.
  final approved = [
    item('w', KidsReligiousKind.wuduStep, text: 'WUDU-TEXT', order: 1),
    item('p', KidsReligiousKind.prayerStep, text: 'PRAYER-TEXT', order: 1),
    item('s', KidsReligiousKind.story, text: 'STORY-TEXT', group: 'g1'),
    item('m', KidsReligiousKind.manner, text: 'MANNER-TEXT'),
    item('d', KidsReligiousKind.dhikr, text: 'DHIKR-TEXT', group: 'morning', repeat: 3),
  ];
  const texts = ['WUDU-TEXT', 'STORY-TEXT', 'MANNER-TEXT', 'DHIKR-TEXT'];
  final screens = <String, KidsSection>{
    'WUDU-TEXT': prayerWuduSection,
    'STORY-TEXT': storiesOfProphetsSection,
    'MANNER-TEXT': mannersSection,
    'DHIKR-TEXT': kidsAdhkarSection,
  };

  group('the screens', () {
    for (final t in texts) {
      final section = screens[t]!;
      testWidgets('${section.id}: flag closed => calm «قريبًا», the text is not in the tree', (tester) async {
        await tester.pumpWidget(
          faithApp(Builder(builder: section.builder), overrides: contentOverrides(approved, unlocked: false)),
        );
        await tester.pump();
        expect(find.text('قريبًا'), findsOneWidget);
        expect(find.text(t), findsNothing);
      });

      testWidgets('${section.id}: flag open but item unapproved => «قريبًا»', (tester) async {
        final unapproved = [
          for (final i in approved)
            item(i.id, i.kind, approved: false, text: i.arabicText, group: i.group, repeat: i.repeat, order: i.order),
        ];
        await tester.pumpWidget(faithApp(Builder(builder: section.builder), overrides: contentOverrides(unapproved)));
        await tester.pump();
        expect(find.text('قريبًا'), findsOneWidget);
        expect(find.text(t), findsNothing);
      });

      testWidgets('${section.id}: flag open and approved => shown', (tester) async {
        await tester.pumpWidget(faithApp(Builder(builder: section.builder), overrides: contentOverrides(approved)));
        await tester.pump();
        expect(find.text(t), findsOneWidget);
        expect(find.text('قريبًا'), findsNothing);
      });

      testWidgets('${section.id}: an approved item that breaks the contract (no source) is not shown either', (
        tester,
      ) async {
        final bad = [
          for (final i in approved)
            if (i.arabicText == t)
              KidsReligiousItem(
                id: i.id,
                kind: i.kind,
                arabicText: i.arabicText,
                source: '',
                reviewer: 'R',
                reviewedOn: signedOn,
                group: i.group,
                repeat: i.repeat,
              ),
        ];
        await tester.pumpWidget(faithApp(Builder(builder: section.builder), overrides: contentOverrides(bad)));
        await tester.pump();
        expect(find.text(t), findsNothing);
        expect(find.text('قريبًا'), findsOneWidget);
      });
    }

    testWidgets('juz amma: flag closed => «قريبًا» even with surahs configured', (tester) async {
      await tester.pumpWidget(
        faithApp(
          Builder(builder: juzAmmaSection.builder),
          overrides: [
            ...quranOverrides(),
            kidsReligiousUnlockedProvider.overrideWithValue(false),
            kidsJuzAmmaSurahsProvider.overrideWithValue(const [114]),
            kidsAyahAudioProvider.overrideWithValue(FakeKidsAudio()),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('قريبًا'), findsOneWidget);
    });
  });
}
