import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/settings/appearance_screen.dart';
import 'package:madar/features/settings/licenses_screen.dart';
import 'package:madar/features/settings/sound_settings_screen.dart';
import 'package:madar/features/settings/widgets/appearance_pickers.dart';

import '../../helpers/test_app.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

void main() {
  testWidgets('settings hub lists every section and opens appearance', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.settings);
    for (final title in [
      _ar.settingsPersonal,
      _ar.settingsSectionMotionPower,
      _ar.dataCentreTitle,
      _ar.settingsAbout,
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    // The inline money, life and system-shell groups sit between health and
    // motion.
    for (final title in [
      _ar.moneyHubSettingsSection,
      _ar.lifeHubSettingsSection,
      _ar.ncTitle,
      _ar.widgetsSettingsTitle,
      _ar.togetherTitle,
      _ar.systemShellAiSection,
    ]) {
      await tester.scrollUntilVisible(find.text(title).first, 200, scrollable: find.byType(Scrollable).first);
      expect(find.text(title), findsWidgets, reason: title);
    }
    await tester.tap(find.text(_ar.settingsAppearance).last);
    await settleApp(tester);
    expect(find.byType(AppearanceScreen), findsOneWidget);
    expect(app.location, AppRoutes.appearance);
  });

  testWidgets('motion and power pills change settings instantly', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.settings);
    await tester.ensureVisible(find.text(_ar.settingsMotionReduced));
    await tester.pump();
    await tester.tap(find.text(_ar.settingsMotionReduced));
    await tester.pump();
    expect(app.settings.motion, MotionPreference.reduced);
    await tester.ensureVisible(find.text(_ar.settingsPowerSaver));
    await tester.pump();
    await tester.tap(find.text(_ar.settingsPowerSaver));
    await tester.pump();
    expect(app.settings.powerMode, PowerMode.batterySaver);
    await settleApp(tester);
  });

  testWidgets('appearance: theme card, language and digits apply live', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.appearance);
    await tester.tap(find.byWidgetPredicate((w) => w is ThemePreviewCard && w.id == MadarThemeId.desert));
    await tester.pump();
    expect(app.settings.themeId, MadarThemeId.desert);

    final western = find.text('${_ar.settingsDigitsWestern} 123');
    await tester.ensureVisible(western);
    await tester.pump();
    await tester.tap(western);
    await tester.pump();
    expect(app.settings.digits, DigitStyle.western);

    await tester.ensureVisible(find.text(_ar.settingsLanguageEnglish));
    await tester.pump();
    await tester.tap(find.text(_ar.settingsLanguageEnglish));
    await tester.pump();
    expect(app.settings.languageCode, 'en');
    expect(Directionality.of(tester.element(find.byType(AppearanceScreen))), TextDirection.ltr);
    expect(find.text(_en.settingsAppearance), findsWidgets);
    await settleApp(tester);
  });

  testWidgets('sound: switches drive the sound and haptics services', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.sound);
    expect(find.byType(SoundSettingsScreen), findsOneWidget);
    expect(app.sound.enabled, isTrue);
    await tester.tap(find.byType(MadarSwitch).first);
    await tester.pump();
    expect(app.settings.soundEnabled, isFalse);
    expect(app.sound.enabled, isFalse);

    await tester.tap(find.byType(MadarSwitch).at(1));
    await tester.pump();
    expect(app.settings.hapticsEnabled, isFalse);
    expect(app.haptics.enabled, isFalse);
    await settleApp(tester);
  });

  testWidgets('sound: a volume slider sets its category', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.sound);
    final slider = find.byType(Slider).at(1); // ambience
    await tester.ensureVisible(slider);
    await tester.pump();
    final r = tester.getRect(slider);
    await tester.tapAt(Offset(r.left + r.width * 0.2, r.center.dy));
    await settleApp(tester);
    final v = app.settings.volumes[SoundCategory.ambient]!;
    expect(v, isNot(0.5));
    expect(app.sound.volumeOf(SoundCategory.ambient), v);
  });

  testWidgets('licences list the four bundled fonts', (tester) async {
    await pumpMadarApp(tester, initialLocation: AppRoutes.licenses);
    expect(find.byType(LicensesScreen), findsOneWidget);
    for (final credit in madarFontCredits) {
      expect(find.text(credit.name(_ar)), findsOneWidget);
    }
  });

  testWidgets('Settings › Import and › Design gallery return to Settings on back', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.settings);
    await tester.ensureVisible(find.text(_ar.settingsImport));
    await tester.pump();
    await tester.tap(find.text(_ar.settingsImport));
    await settleApp(tester);
    expect(app.location, AppRoutes.import);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.settings);

    await tester.ensureVisible(find.text(_ar.designGalleryTitle));
    await tester.pump();
    await tester.tap(find.text(_ar.designGalleryTitle));
    // The gallery animates forever: pump instead of settling.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(app.location, AppRoutes.gallery);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(app.location, AppRoutes.settings);
    await settleApp(tester);
  });

  testWidgets('a system back from a settings page is heard (Sfx.back)', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.settings);
    await tester.tap(find.text(_ar.settingsAppearance).last);
    await settleApp(tester);
    expect(app.location, AppRoutes.appearance);
    app.sound.played.clear();
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.settings);
    expect(app.sound.played, contains(Sfx.back));
  });

  testWidgets('About opens the open-source licence page', (tester) async {
    await pumpMadarApp(tester, initialLocation: AppRoutes.settings);
    await tester.ensureVisible(find.text(_ar.settingsLicenses));
    await tester.pump();
    await tester.tap(find.text(_ar.settingsLicenses));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('navigating rows use the self-mirroring chevron (points left in Arabic)', (tester) async {
    await pumpMadarApp(tester, initialLocation: AppRoutes.settings);
    // chevron_right is declared matchTextDirection: Icon mirrors it under
    // RTL. Picking chevron_left for RTL flipped it back to '>'.
    expect(Icons.chevron_right_rounded.matchTextDirection, isTrue);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
    final icon = tester.element(find.byIcon(Icons.chevron_right_rounded).first);
    expect(Directionality.of(icon), TextDirection.rtl);
  });
}
