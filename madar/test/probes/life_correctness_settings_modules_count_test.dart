// Probe (Life integration, Settings › Life): the trackers row counts the
// trackers the user keeps. An archived tracker is put away (the trackers
// page lists it apart, the worlds and the reminders ignore it), so it must
// not be counted as one of "your trackers".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/custom_modules/custom_modules.dart';
import 'package:madar/features/settings/life_settings_section.dart';

import '../helpers/test_app.dart';
import '../features/lock/lock_test_utils.dart';

void main() {
  testWidgets('an archived tracker is not counted in Settings › Life', (tester) async {
    await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      initialLocation: AppRoutes.settings,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async {
        final modules = CustomModulesService(Repositories(db));
        final ids = <String>[];
        for (final name in ['Reading', 'Sleep', 'Old diet']) {
          ids.add(
            (await modules.createModule(
              ModuleTemplates.build(ModuleTemplateKey.readingLog, (t) => t.name).copyWith(name: name),
            )).id,
          );
        }
        await modules.setArchived(ids.last, true);
      },
    );
    final l = lookupL10n(const Locale('en'));
    const fmt = MadarFormatter(languageCode: 'en');
    final section = find.byType(LifeSettingsSection);
    await tester.scrollUntilVisible(section, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final row = find.descendant(of: section, matching: find.text(l.lifeHubSettingsModulesCount(2, fmt.formatInt(2))));
    final wrong = find.descendant(of: section, matching: find.text(l.lifeHubSettingsModulesCount(3, fmt.formatInt(3))));
    expect(wrong, findsNothing, reason: 'the archived "Old diet" is counted as a tracker');
    expect(row, findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}
