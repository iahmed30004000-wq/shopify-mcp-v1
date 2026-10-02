// Visual critic pass for the import flow: renders the real screen with the
// real fonts and shaders and writes PNGs to madar/screenshots/import_*.png.
//
//   flutter test --tags screenshot test/features/import/import_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/import/import.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/import/import_controller.dart';
import 'package:madar/features/import/import_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/screenshot_harness.dart';

String fixture(String name) => File('test/fixtures/import/$name.json').readAsStringSync();

enum _Step { idle, preview, previewScrolled, done }

Future<void> _shot(WidgetTester tester, String name, {required Locale locale, required _Step step, String data = 'prototype_flat_ar', MadarThemeId theme = MadarThemeId.lapis}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await tester.runAsync(SharedPreferences.getInstance);
  final db = MadarDatabase(NativeDatabase.memory());
  addTearDown(() => tester.runAsync(db.close));
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db), sharedPreferencesProvider.overrideWithValue(prefs!)],
  );
  addTearDown(container.dispose);
  final labels = ImportLabels.forLanguage(locale.languageCode);

  Future<void> frames(int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  final file = await captureScreen(
    tester,
    UncontrolledProviderScope(
      container: container,
      child: madarScreenshotApp(theme: theme, locale: locale, home: const ImportScreen()),
    ),
    name,
    beforeCapture: step == _Step.idle
        ? null
        : (tester) async {
            final c = container.read(importControllerProvider.notifier);
            final analyzing = c.analyzeText(fixture(data), labels: labels, fileName: '$data.json');
            await frames(4);
            await analyzing;
            await frames(30);
            if (step == _Step.previewScrolled) {
              final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
              scrollable.position.jumpTo(scrollable.position.maxScrollExtent * 0.62);
              await frames(20);
            }
            if (step == _Step.done) {
              final committing = c.commit();
              await frames(6);
              await committing;
              await frames(30);
            }
          },
  );
  expect(file.existsSync(), isTrue);
}

void main() {
  const ar = Locale('ar');
  const en = Locale('en');

  testWidgets('import – idle, RTL', (t) => _shot(t, 'import_idle_rtl', locale: ar, step: _Step.idle));
  testWidgets('import – idle, LTR (Pearl)', (t) => _shot(t, 'import_idle_ltr_pearl', locale: en, step: _Step.idle, theme: MadarThemeId.pearl));
  testWidgets('import – preview, RTL', (t) => _shot(t, 'import_preview_rtl', locale: ar, step: _Step.preview));
  testWidgets('import – preview scrolled, RTL', (t) => _shot(t, 'import_preview_scrolled_rtl', locale: ar, step: _Step.previewScrolled));
  testWidgets('import – preview, LTR', (t) => _shot(t, 'import_preview_ltr', locale: en, step: _Step.preview, data: 'prototype_nested_en'));
  testWidgets('import – done, RTL', (t) => _shot(t, 'import_done_rtl', locale: ar, step: _Step.done));
}
