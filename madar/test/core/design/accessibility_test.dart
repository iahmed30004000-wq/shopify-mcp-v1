// Accessibility of the design components: 48 dp touch targets around small
// visuals, legible switch states in every theme (Pearl included), and the
// metal tokens that keep rendered brass bright while text stays legible.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/contrast.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/sound/sound_api.dart';

import 'design_test_utils.dart';

void main() {
  group('48 dp touch targets', () {
    testWidgets('a small button keeps its 36 dp look inside a 48 dp target', (tester) async {
      installRecordingFx();
      var taps = 0;
      await pumpMadar(
        tester,
        MadarButton.icon(
          icon: Icons.tune_rounded,
          semanticLabel: 'Settings',
          size: MadarButtonSize.small,
          onPressed: () => taps++,
        ),
      );
      final target = tester.getRect(find.byType(MadarPressable));
      expect(target.size, const Size(48, 48));
      final visual = tester.getRect(find.byType(AnimatedContainer));
      expect(visual.size, const Size(36, 36));
      expect(visual.center, target.center);
      // A tap in the margin, outside the painted circle, still counts.
      await tester.tapAt(target.topLeft + const Offset(2, 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('the target never changes how a stretched button lays out', (tester) async {
      await pumpMadar(
        tester,
        SizedBox(
          width: 300,
          child: MadarButton(label: 'Skip', size: MadarButtonSize.small, onPressed: () {}),
        ),
      );
      // Tight width from the parent: the visual still fills it, only the
      // height gains the 48 dp target.
      expect(tester.getSize(find.byType(AnimatedContainer)), const Size(300, 36));
      expect(tester.getSize(find.byType(MadarPressable)), const Size(300, 48));
    });

    testWidgets('medium and large buttons are unchanged', (tester) async {
      await pumpMadar(tester, MadarButton(label: 'Save', onPressed: () {}));
      expect(tester.getSize(find.byType(MadarPressable)).height, 48);
      await pumpMadar(tester, MadarButton(label: 'Save', size: MadarButtonSize.large, onPressed: () {}));
      await tester.pump(const Duration(seconds: 1)); // the size change animates
      expect(tester.getSize(find.byType(MadarPressable)).height, 56);
    });

    testWidgets('tappable chips get a 48 dp target; read-only chips stay compact', (tester) async {
      await pumpMadar(tester, MadarChip(label: 'Daily', dense: true, onSelected: (_) {}));
      expect(tester.getSize(find.byType(MadarPressable)).height, 48);
      expect(tester.getSize(find.byType(CustomPaint).last).height, 32);
      await pumpMadar(tester, const MadarChip(label: 'JSON', dense: true, sfx: null));
      expect(tester.getSize(find.byType(MadarPressable)).height, 32);
    });

    testWidgets('chip rows keep their visual rhythm (targets touch, pills do not)', (tester) async {
      await pumpMadar(
        tester,
        SizedBox(
          width: 200,
          child: ChoicePills<int>.single(
            options: [for (var i = 0; i < 6; i++) ChoiceOption(value: i, label: 'Option $i')],
            selected: 0,
            onChanged: (_) {},
          ),
        ),
      );
      final tops = {
        for (final e in find.byType(MadarPressable).evaluate()) tester.getRect(find.byWidget(e.widget)).top,
      };
      final sorted = tops.toList()..sort();
      // Rows of 48 dp targets, flush: a 10 dp gap between the 38 dp pills.
      expect(sorted[1] - sorted[0], 48);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('a long chip label ellipsises instead of overflowing at large text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpMadar(
        tester,
        SizedBox(
          width: 160,
          child: ChoicePills<int>.single(
            options: const [ChoiceOption(value: 0, label: 'A remarkably long option label')],
            selected: 0,
            onChanged: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(MadarPressable)).width, lessThanOrEqualTo(160));
    });

    testWidgets('the switch is a 48 dp tall target', (tester) async {
      await pumpMadar(tester, MadarSwitch(value: false, onChanged: (_) {}, semanticLabel: 'Sound'));
      expect(tester.getSize(find.byType(MadarSwitch)), const Size(54, 48));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  });

  group('switch states read in every theme', () {
    for (final id in MadarThemeId.values) {
      test('${id.name}: the thumb stands out from the glass it sits on (off) and the track shows "on"', () {
        final t = MadarPalettes.tokensFor(id);
        final c = MadarSwitchColors.of(t);
        final glass = MadarContrast.over(t.glassFill, t.space1);
        final trackOff = MadarContrast.over(c.track, glass);
        // Off: the thumb is the visible indicator (WCAG 1.4.11: 3:1).
        expect(MadarContrast.ratio(c.thumbOff, trackOff), greaterThanOrEqualTo(3), reason: 'thumb vs track');
        expect(MadarContrast.ratio(c.thumbOff, glass), greaterThanOrEqualTo(3), reason: 'thumb vs glass');
        // On: the accent-flooded track against the page.
        expect(MadarContrast.ratio(t.accent, glass), greaterThanOrEqualTo(3), reason: 'accent track vs glass');
      });
    }
  });

  group('metal tokens', () {
    test('night themes: the metal is the gold itself', () {
      for (final id in MadarThemeId.values.where((id) => id != MadarThemeId.pearl)) {
        final t = MadarPalettes.tokensFor(id);
        expect(t.metalGold, t.gold);
        expect(t.metalBrass, t.brass);
      }
    });

    test('Pearl: polished brass for rendering, deep ink gold for text', () {
      final t = MadarPalettes.tokensFor(MadarThemeId.pearl);
      expect(t.metalGold, isNot(t.gold));
      expect(t.metalGold.computeLuminance(), greaterThan(t.gold.computeLuminance()));
      expect(MadarContrast.ratio(t.gold, t.space0), greaterThanOrEqualTo(4.5));
    });

    test('metals survive copyWith and cross-fade with the theme', () {
      final pearl = MadarPalettes.tokensFor(MadarThemeId.pearl);
      final lapis = MadarPalettes.tokensFor(MadarThemeId.lapis);
      expect(pearl.copyWith(accent: const Color(0xFF123456)).metalGold, pearl.metalGold);
      expect(pearl.lerp(lapis, 0).metalGold, pearl.metalGold);
      expect(pearl.lerp(lapis, 1).metalGold, lapis.metalGold);
      expect(pearl.lerp(lapis, 0.5).metalGold, Color.lerp(pearl.metalGold, lapis.metalGold, 0.5));
      // Part of equality (a theme with other metals is another theme).
      expect(pearl, isNot(pearl.lerp(lapis, 0.5)));
    });
  });

  testWidgets('tapping a small button still sounds and vibrates through Fx', (tester) async {
    final fx = installRecordingFx();
    await pumpMadar(
      tester,
      MadarButton(label: 'Skip', size: MadarButtonSize.small, variant: MadarButtonVariant.ghost, onPressed: () {}),
    );
    await tester.tap(find.byType(MadarButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(fx.sound.played, [Sfx.tap]);
    expect(fx.haptics.fired, isNotEmpty);
  });
}
