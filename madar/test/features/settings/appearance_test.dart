// Appearance: the theme carousel always shows the chosen theme, and the
// accent picker (planet swatches + a free hue rail) shows every colour as the
// theme will really use it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/contrast.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/settings/appearance_screen.dart';
import 'package:madar/features/settings/widgets/appearance_pickers.dart';

import '../../core/i18n/text_scan.dart';
import '../../helpers/test_app.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

Finder _card(MadarThemeId id) => find.byWidgetPredicate((w) => w is ThemePreviewCard && w.id == id);

void main() {
  group('ThemeCarousel.offsetFor', () {
    double offset(int i, {double viewport = 412}) =>
        ThemeCarousel.offsetFor(i, count: 5, cardWidth: 104, viewport: viewport, paddingStart: 20, paddingEnd: 20);

    test('the first card needs no scroll, the last one scrolls to the end', () {
      expect(offset(0), 0);
      // 20 + 5·104 + 4·12 + 20 = 608 → max 196.
      expect(offset(4), 196);
    });

    test('a middle card is centred', () {
      // Card 2 starts at 20 + 2·116 = 252; centre 304 → 304 − 206 = 98.
      expect(offset(2), 98);
    });

    test('a viewport wider than the row never scrolls', () {
      expect(offset(4, viewport: 800), 0);
    });
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('the chosen theme card is in view on arrival ($lang, Pearl – the last card)', (tester) async {
      await pumpMadarApp(
        tester,
        settings: AppSettings(onboarded: true, themeId: MadarThemeId.pearl, languageCode: lang),
        initialLocation: AppRoutes.appearance,
        settle: false,
      );
      await pumpFrames(tester);
      final rect = tester.getRect(_card(MadarThemeId.pearl));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(412));
    });
  }

  testWidgets('picking a theme scrolls its card into view', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.appearance, settle: false);
    await pumpFrames(tester);
    // Aurora (4th) is partly off-screen at the reading end in Arabic: tap
    // the sliver that shows.
    final screen = Offset.zero & const Size(412, 915);
    final visible = tester.getRect(_card(MadarThemeId.aurora)).intersect(screen);
    expect(visible.width, lessThan(104));
    await tester.tapAt(visible.center);
    await pumpFrames(tester);
    expect(app.settings.themeId, MadarThemeId.aurora);
    final rect = tester.getRect(_card(MadarThemeId.aurora));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(412));
    await settleApp(tester);
  });

  testWidgets('under reduced motion the carousel jumps to the chosen card (no glide)', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, motion: MotionPreference.reduced, languageCode: 'en'),
      initialLocation: AppRoutes.appearance,
      settle: false,
    );
    await pumpFrames(tester);
    final list = find.descendant(of: find.byType(ThemeCarousel), matching: find.byType(Scrollable));
    final position = tester.state<ScrollableState>(list).position;
    expect(position.pixels, 0);
    app.updateSettings((s) => s.copyWith(themeId: MadarThemeId.pearl));
    await tester.pump();
    await tester.pump();
    // Already there on the next frame, no animation running.
    expect(position.pixels, position.maxScrollExtent);
    expect(position.isScrollingNotifier.value, isFalse);
    await settleApp(tester);
  });

  group('following the device (light/dark pairing)', () {
    test('a dark theme becomes the dark-mode pairing; Pearl means "Pearl always"', () {
      const following = AppSettings(followSystem: true, themeId: MadarThemeId.emerald);
      final desert = pickTheme(following, MadarThemeId.desert);
      expect(desert.followSystem, isTrue);
      expect(desert.themeId, MadarThemeId.desert);
      expect(desert.effectiveTheme(Brightness.light), MadarThemeId.pearl);
      expect(desert.effectiveTheme(Brightness.dark), MadarThemeId.desert);

      final pearl = pickTheme(following, MadarThemeId.pearl);
      expect(pearl.followSystem, isFalse);
      expect(pearl.effectiveTheme(Brightness.dark), MadarThemeId.pearl);

      // Not following: a plain choice.
      expect(pickTheme(const AppSettings(), MadarThemeId.pearl).themeId, MadarThemeId.pearl);
    });

    testWidgets('the cards show which theme serves light mode and which dark mode', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final app = await pumpMadarApp(
        tester,
        settings: const AppSettings(
          onboarded: true,
          followSystem: true,
          themeId: MadarThemeId.emerald,
          languageCode: 'en',
        ),
        initialLocation: AppRoutes.appearance,
        settle: false,
      );
      await pumpFrames(tester);
      // The light device shows Pearl …
      expect(tester.element(_card(MadarThemeId.emerald)).tokens.brightness, Brightness.light);
      ThemePreviewCard card(MadarThemeId id) => tester.widget<ThemePreviewCard>(_card(id));
      expect(card(MadarThemeId.emerald).modeLabel, _en.settingsThemeDarkMode);
      expect(card(MadarThemeId.emerald).selected, isTrue);
      expect(card(MadarThemeId.lapis).modeBadge, isNull);
      // Screen readers hear the pairing with the name.
      final handle = tester.ensureSemantics();
      final sep = _en.interactionListSeparator;
      expect(find.bySemanticsLabel('${_en.designThemeEmerald}$sep${_en.settingsThemeDarkMode}'), findsOneWidget);
      handle.dispose();

      // Pearl, at the far end of the row, wears the sun …
      await tester.drag(find.byType(ThemeCarousel), const Offset(-400, 0));
      await pumpFrames(tester);
      expect(card(MadarThemeId.pearl).modeLabel, _en.settingsThemeLightMode);
      expect(card(MadarThemeId.pearl).modeBadge, Icons.light_mode_rounded);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

      // … and choosing Pearl explicitly stops following.
      await tester.tap(_card(MadarThemeId.pearl));
      await tester.pump();
      expect(app.settings.followSystem, isFalse);
      expect(app.settings.themeId, MadarThemeId.pearl);
      expect(find.byIcon(Icons.light_mode_rounded), findsNothing);
      await settleApp(tester);
    });
  });

  group('accent picker', () {
    testWidgets('swatches are labelled per planet and set the raw planet colour', (tester) async {
      final app = await pumpMadarApp(tester, initialLocation: AppRoutes.appearance, settle: false);
      await pumpFrames(tester);
      final handle = tester.ensureSemantics();
      final health = find.bySemanticsLabel(_ar.settingsAccentPlanet(_ar.planetHealth));
      await tester.ensureVisible(health);
      await tester.pump();
      await tester.tap(health);
      await tester.pump();
      expect(app.settings.customAccent, PlanetPalettes.health.surface);
      expect(app.sound.played, contains(Sfx.tap));

      await tester.tap(find.bySemanticsLabel(_ar.settingsAccentDefault));
      await tester.pump();
      expect(app.settings.customAccent, isNull);
      handle.dispose();
      await settleApp(tester);
    });

    testWidgets('on Pearl the swatches show the deepened, legible colour', (tester) async {
      await pumpMadarApp(
        tester,
        settings: const AppSettings(onboarded: true, themeId: MadarThemeId.pearl, languageCode: 'en'),
        initialLocation: AppRoutes.appearance,
        settle: false,
      );
      await pumpFrames(tester);
      final surface = MadarPalettes.tokensFor(MadarThemeId.pearl).space0;
      final shown = [
        for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(of: find.byType(AccentPicker), matching: find.byType(DecoratedBox)),
        ))
          if (box.decoration case BoxDecoration(gradient: RadialGradient(:final colors))) colors.last,
      ];
      expect(shown, hasLength(9));
      for (final c in shown) {
        expect(MadarContrast.ratio(c, surface), greaterThanOrEqualTo(4.5), reason: '$c');
      }
      // The pale mint Money swatch is shown as deep teal, not as picked.
      expect(shown, isNot(contains(PlanetPalettes.money.surface)));
    });

    testWidgets('the hue rail picks any colour, with a tick every 30° and a drop on release', (tester) async {
      final app = await pumpMadarApp(
        tester,
        settings: const AppSettings(onboarded: true, languageCode: 'en'),
        initialLocation: AppRoutes.appearance,
        settle: false,
      );
      await pumpFrames(tester);
      final rail = find.descendant(of: find.byType(AccentHueRail), matching: find.byType(Slider));
      await tester.ensureVisible(rail);
      await tester.pump();
      app.sound.played.clear();
      final r = tester.getRect(rail);
      // Drag from a third of the way to two thirds: ~120° → ~240°.
      final g = await tester.startGesture(Offset(r.left + 24 + (r.width - 48) / 3, r.center.dy));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(Offset((r.width - 48) / 30, 0));
        await tester.pump();
      }
      await g.up();
      await pumpFrames(tester);
      final picked = app.settings.customAccent!;
      final hue = HSLColor.fromColor(picked).hue;
      expect(hue, inInclusiveRange(200, 280));
      expect(picked, AccentPicker.colorForHue(hue));
      expect(app.sound.played, contains(Sfx.countTick));
      expect(app.sound.played.last, Sfx.drop);
      // The app's accent is the pick, adjusted for Lapis (already legible).
      expect(tester.element(rail).tokens.accent, MadarPalettes.resolve(MadarThemeId.lapis, accent: picked).accent);
      await settleApp(tester);
    });

    testWidgets('dragging the hue rail previews locally and saves once, on release', (tester) async {
      final app = await pumpMadarApp(
        tester,
        settings: const AppSettings(onboarded: true, languageCode: 'ar'),
        initialLocation: AppRoutes.appearance,
        settle: false,
      );
      await pumpFrames(tester);
      final rail = find.descendant(of: find.byType(AccentHueRail), matching: find.byType(Slider));
      await tester.ensureVisible(rail);
      await tester.pump();
      final saved = <AppSettings>[];
      final sub = app.container.listen(appSettingsProvider, (_, next) => saved.add(next));
      addTearDown(sub.close);
      final before = tester.element(rail).tokens.accent;
      final r = tester.getRect(rail);
      final g = await tester.startGesture(Offset(r.center.dx, r.center.dy));
      Color? thumbMidDrag;
      for (var i = 0; i < 12; i++) {
        await g.moveBy(Offset(-(r.width - 48) / 40, 0));
        await tester.pump(const Duration(milliseconds: 16));
        thumbMidDrag = tester
            .widget<SliderTheme>(find.descendant(of: find.byType(AccentHueRail), matching: find.byType(SliderTheme)))
            .data
            .thumbColor;
      }
      // Mid-drag: the thumb wears the hue under the finger, but nothing was
      // saved and the app is not re-themed on every pointer move (each save
      // is a disk write and a whole-app theme animation).
      expect(saved, isEmpty);
      expect(tester.element(rail).tokens.accent, before);
      expect(thumbMidDrag, isNot(before));
      await g.up();
      await tester.pump();
      expect(saved, hasLength(1));
      final picked = saved.single.customAccent!;
      expect(thumbMidDrag, MadarPalettes.resolve(MadarThemeId.lapis, accent: picked).accent);
      await settleApp(tester);
      // After the save the thumb stays where the finger left it.
      final slider = tester.widget<Slider>(rail);
      expect(slider.value, closeTo(HSLColor.fromColor(picked).hue, 1.5));
    });

    testWidgets('the hue rail reads its value to screen readers in the UI language', (tester) async {
      await pumpMadarApp(
        tester,
        settings: const AppSettings(onboarded: true, languageCode: 'en', customAccent: Color(0xFF3399FF)),
        initialLocation: AppRoutes.appearance,
        settle: false,
      );
      await pumpFrames(tester);
      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(find.bySemanticsLabel(_en.settingsAccentCustom).last);
      expect(node.value, startsWith('Hue '));
      expect(node.flagsCollection.isSlider, isTrue);
      handle.dispose();
    });
  });

  testWidgets('the hue rail runs from the reading start in both directions', (tester) async {
    for (final lang in ['ar', 'en']) {
      await pumpMadarApp(
        tester,
        settings: AppSettings(onboarded: true, languageCode: lang),
        initialLocation: AppRoutes.appearance,
        settle: false,
      );
      await pumpFrames(tester);
      final rail = find.descendant(of: find.byType(AccentHueRail), matching: find.byType(Slider));
      expect(Directionality.of(tester.element(rail)), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      await settleApp(tester);
    }
  });
}
