// The export flow inside the real app, in Arabic and in English: «بياناتك»
// → «استشارة ذكاء اصطناعي» → the data package's own chooser → one file
// (or the clipboard) carrying his summary, the prompt and the answer shape.
//
// Nothing leaves the phone without a tap: the recording bridge sees nothing
// until he presses Copy or Share.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/interaction/interaction.dart' show SheetButton;
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/ai_bridge/ai_bridge.dart';
import 'package:madar/features/data/data.dart';
import 'package:drift/drift.dart' show Value;

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _asyncFrames(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A little of his own data, so the summary and the catalogue are not empty.
Future<void> _seed(MadarDatabase db) async {
  final repos = Repositories(db);
  await repos.budgetItems.insert(
    BudgetItemsCompanion.insert(name: 'بقالة', amountMilli: const Value(120000)),
  );
  await repos.foods.insert(FoodsCompanion.insert(name: 'مقلوبة', notes: const Value('ملاحظة خاصة')));
  await repos.habits.insert(HabitsCompanion.insert(name: 'مشي', active: const Value(false)));
}

Future<(TestApp, RecordingDataFileBridge)> _open(WidgetTester tester, {required String language}) async {
  final bridge = RecordingDataFileBridge();
  final app = await pumpMadarApp(
    tester,
    initialLocation: AppRoutes.dataCentre,
    settings: AppSettings(onboarded: true, languageCode: language),
    settle: false,
    beforePump: _seed,
    overrides: <Override>[
      ...LockFixture.empty().overrides,
      dataFileBridgeProvider.overrideWithValue(bridge),
      dataClockProvider.overrideWithValue(() => DateTime(2026, 10, 10, 9)),
    ],
  );
  await _asyncFrames(tester, 16);
  return (app, bridge);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await _frames(tester, 6);
  await tester.tap(finder.last);
  await _asyncFrames(tester, 14);
}

void main() {
  for (final language in ['ar', 'en']) {
    final l = lookupL10n(Locale(language));

    group('the export flow in $language', () {
      testWidgets('«بياناتك» offers the AI round trip, and it builds one file with the prompt', (tester) async {
        final (_, bridge) = await _open(tester, language: language);
        expect(find.text(l.dataCentreTitle), findsOneWidget);

        // The entry sits in the export section of the data centre.
        await _tapText(tester, l.aiPlanExportTitle);
        expect(find.byType(AiBridgeExportSheet), findsOneWidget);
        expect(find.text(l.aiPlanStepChoose), findsOneWidget);
        expect(find.text(l.aiPlanChooseFirst), findsOneWidget);
        expect(bridge.copied, isEmpty, reason: 'nothing leaves before a tap');
        expect(bridge.shared, isEmpty);

        // The chooser is the data package's own sheet, not a second one.
        await tester.tap(find.text(l.aiPlanChooseAction));
        await _asyncFrames(tester, 18);
        expect(find.byType(ExportPreviewSheet), findsOneWidget);
        expect(find.text(l.dataSummarySections), findsWidgets);

        // Confirm the sections and come back with the file ready.
        await tester.tap(find.widgetWithText(SheetButton, l.aiPlanExportTitle).last);
        await _asyncFrames(tester, 20);
        expect(find.byType(ExportPreviewSheet), findsNothing);
        expect(find.text(l.aiPlanFileReady), findsOneWidget);
        expect(find.text(l.aiPlanLeftOut), findsOneWidget);
        expect(find.text(l.aiPlanHowTo), findsOneWidget);

        // Copy: the clipboard carries the prompt and the request JSON.
        await tester.tap(find.widgetWithText(SheetButton, l.dataCopyAction).last);
        await _asyncFrames(tester, 12);
        expect(bridge.copied, hasLength(1));
        final text = bridge.copied.single;
        expect(text, contains('```json'));
        final json = jsonDecode(text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1)) as Map<String, Object?>;
        expect(json['madar'], madarRequestMarker);
        expect(json['language'], language);
        expect((json['instructions']! as List).join(' '), contains('reason'));
        expect(json['answerContract'], isNotNull);
        expect(json['answerExample'], isNotNull);
        expect(((json['myThings']! as Map)['budgetItems']! as List).single, containsPair('name', 'بقالة'));
        // His own note stayed on the phone.
        expect(text, isNot(contains('ملاحظة خاصة')));

        // Share: one JSON file, named after the day.
        await tester.tap(find.widgetWithText(SheetButton, l.dataShareAction).last);
        await _asyncFrames(tester, 12);
        expect(bridge.shared, hasLength(1));
        expect(bridge.shared.single.name, 'madar-ai-request-2026-10-10.json');
        expect(bridge.shared.single.mimeType, 'application/json');
        expect(bridge.shared.single.encrypted, isFalse);
        expect(tester.takeException(), isNull);
      });

      testWidgets('his question travels with the file when he types one', (tester) async {
        final (_, bridge) = await _open(tester, language: language);
        await _tapText(tester, l.aiPlanExportTitle);
        await tester.tap(find.text(l.aiPlanChooseAction));
        await _asyncFrames(tester, 18);
        await tester.tap(find.widgetWithText(SheetButton, l.aiPlanExportTitle).last);
        await _asyncFrames(tester, 18);

        await tester.enterText(find.byType(TextField).last, 'شو أحسن إشي أعمله الشهر الجاي؟');
        await _asyncFrames(tester, 16);
        await tester.tap(find.widgetWithText(SheetButton, l.dataCopyAction).last);
        await _asyncFrames(tester, 12);
        expect(bridge.copied.last, contains('شو أحسن إشي أعمله الشهر الجاي؟'));
        expect(tester.takeException(), isNull);
      });
    });
  }
}
