// Regression test for B4 (APK #15): the "+" for tasks only showed while the
// window was empty, so after the first task there was no way to add another
// one from the panel's list.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';

import '../../helpers/test_app.dart';
import '../orbit/presentation/orbit_scene_fixtures.dart' show hostPrayerSettings;

final _ar = lookupL10n(const Locale('ar'));
final _today = DateTime(testNow.year, testNow.month, testNow.day);

/// Prayer times that match the host clock, so 13:10 is in Dhuhr's window.
Future<void> _prayerSettings(MadarDatabase db) =>
    OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());

/// [count] Dhuhr tasks for today.
Future<void> Function(MadarDatabase) _dhuhrTasks(int count) => (db) async {
  await _prayerSettings(db);
  for (var i = 0; i < count; i++) {
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: 'مهمة ${i + 1}',
            window: const Value(PrayerWindow.dhuhr),
            date: Value(_today),
            sortOrder: Value(i),
          ),
        );
  }
};

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate((w) => w is Semantics && w.properties.label == _ar.orbitUiPanelExpand),
  );
  await settleApp(tester);
}

void main() {
  for (final count in [1, 5]) {
    testWidgets('a window with $count task(s) still offers "add a task"', (tester) async {
      final app = await pumpMadarApp(tester, beforePump: _dhuhrTasks(count));
      await _openPanel(tester);
      expect(find.text('مهمة 1'), findsOneWidget, reason: 'the list, not the empty state');

      final add = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == _ar.homeAddTask);
      expect(add, findsWidgets, reason: 'the add affordance survives a non-empty list');

      // The same flow the empty state opens: the task edit sheet, saving a task.
      await tester.ensureVisible(add.first);
      await settleApp(tester);
      await tester.tap(add.first);
      await settleApp(tester);
      expect(find.text(_ar.homeTaskTitleField), findsWidgets);
      final field = find.descendant(
        of: find.ancestor(of: find.text(_ar.homeTaskTitleField).first, matching: find.byType(Column)).first,
        matching: find.byType(TextField),
      );
      await tester.enterText(field.first, 'Plan the week');
      await tester.pump();
      await tester.tap(find.text(_ar.actionSave));
      await settleApp(tester);
      final titles = (await tester.runAsync(() => app.repos.tasks.getAll()))!.map((t) => t.title);
      expect(titles, contains('Plan the week'));
      expect(titles.length, count + 1);
    });
  }
}
