import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/money.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/import/import.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/import/import_controller.dart';
import 'package:madar/features/import/import_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design/design_test_utils.dart';

String fixture(String name) => File('test/fixtures/import/$name.json').readAsStringSync();

class _Harness {
  _Harness(this.db, this.container);
  final MadarDatabase db;
  final ProviderContainer container;
  ImportController get controller => container.read(importControllerProvider.notifier);
  ImportState get state => container.read(importControllerProvider);
}

Future<_Harness> _pumpImport(WidgetTester tester, {Locale locale = const Locale('ar'), VoidCallback? onDone}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await tester.runAsync(SharedPreferences.getInstance);
  final db = MadarDatabase(NativeDatabase.memory());
  addTearDown(() => tester.runAsync(db.close));
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs!),
      importFilePickerProvider.overrideWithValue(() async => (name: 'madar-export.json', text: fixture('prototype_nested_en'))),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildMadarTheme(MadarThemeId.lapis, arabic: locale.languageCode == 'ar'),
        locale: locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        home: ImportScreen(onDone: onDone),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(db, container);
}

/// Lets the in-memory database work complete (it runs on microtasks, so
/// plain pumps drive it) and plays the finite animations (entrances,
/// counters) frame by frame.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  for (var i = 0; i < 13; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late ({SilentSoundService sound, RecordingHaptics haptics}) fx;
  setUp(() => fx = installRecordingFx());

  testWidgets('RTL: idle → paste → preview → import → done', (tester) async {
    var done = 0;
    final h = await _pumpImport(tester, onDone: () => done++);
    final l = lookupL10n(const Locale('ar'));
    expect(find.text(l.importHeroTitle), findsOneWidget);
    expect(Directionality.of(tester.element(find.text(l.importHeroTitle))), TextDirection.rtl);

    await tester.tap(find.text(l.importPasteToggle));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), fixture('prototype_flat_ar'));
    await tester.pump();
    await tester.ensureVisible(find.text(l.importAnalyzeAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.importAnalyzeAction));
    await settle(tester);

    expect(h.state.stage, ImportStage.preview);
    expect(find.text(l.importSectionsTitle), findsOneWidget);
    expect(find.text(l.importSectionMedications), findsOneWidget);
    // Counters finished counting, in Arabic-Indic digits.
    expect(find.text('٣'), findsWidgets);
    expect(fx.sound.played, contains(Sfx.sparkle));

    final total = h.state.plan!.report.totalPlanned;
    await tester.tap(find.text(MoneyText.toArabicIndic(l.importStartAction(total))));
    await settle(tester);
    await settle(tester);
    expect(h.state.stage, ImportStage.done);
    expect(find.text(l.importDoneTitle), findsOneWidget);
    expect(fx.sound.played, contains(Sfx.levelUp));
    final meds = h.db.select(h.db.medications).get();
    await tester.pump();
    expect(await meds, hasLength(3));

    await tester.tap(find.text(l.actionDone));
    await tester.pump();
    expect(done, 1);
  });

  testWidgets('LTR: picked file shows its name, shape and duplicate warning on re-import', (tester) async {
    final h = await _pumpImport(tester, locale: const Locale('en'));
    final l = lookupL10n(const Locale('en'));
    expect(Directionality.of(tester.element(find.text(l.importHeroTitle))), TextDirection.ltr);

    await tester.tap(find.text(l.importPickFile));
    await settle(tester);
    expect(find.text('madar-export.json'), findsOneWidget);
    expect(find.text(l.importShapeWrapped), findsOneWidget);
    expect(find.text(l.importShapeNested), findsOneWidget);
    expect(find.textContaining('350.000'), findsOneWidget); // budget total

    // Import it, then pick the same file again.
    final committing = h.controller.commit();
    await settle(tester);
    await committing;
    final picking = h.controller.pickFile(ImportLabels.of(l));
    await settle(tester);
    await picking;
    expect(find.text(l.importDuplicateTitle), findsOneWidget);
    expect(h.state.canImport, isFalse);
    await tester.tap(find.byType(Switch).evaluate().isEmpty ? find.text(l.importDuplicateAnyway) : find.byType(Switch));
    await tester.pumpAndSettle();
  });

  testWidgets('invalid JSON shows the failure state with a retry', (tester) async {
    final h = await _pumpImport(tester, locale: const Locale('en'));
    final l = lookupL10n(const Locale('en'));
    final analyzing = h.controller.analyzeText('{broken', labels: ImportLabels.of(l));
    await settle(tester);
    await analyzing;
    expect(find.text(l.importErrorInvalidJson), findsOneWidget);
    expect(fx.sound.played, contains(Sfx.error));
    await tester.tap(find.text(l.importTryAgain));
    await tester.pumpAndSettle();
    expect(find.text(l.importHeroTitle), findsOneWidget);
  });
}
