import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/home/home_screen.dart';
import 'package:madar/features/home/widgets/window_chips.dart';

import '../../helpers/test_app.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));
final _today = DateTime(testNow.year, testNow.month, testNow.day);

Future<void> Function(MadarDatabase) _tasks(Map<PrayerWindow, List<String>> byWindow) => (db) async {
  var i = 0;
  for (final e in byWindow.entries) {
    for (final title in e.value) {
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              title: title,
              window: Value(e.key),
              date: Value(_today),
              planetKey: const Value('work'),
              sortOrder: Value(i++),
            ),
          );
    }
  }
};

Future<void> _pumpFrames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('shows the current window’s tasks and switches windows from the chips', (tester) async {
    await pumpMadarApp(
      tester,
      beforePump: _tasks({
        PrayerWindow.dhuhr: ['Review deck', 'Call Mum'],
        PrayerWindow.asr: ['Evening walk'],
      }),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    // 13:10 → Dhuhr window.
    expect(find.text('Review deck'), findsOneWidget);
    expect(find.text('Call Mum'), findsOneWidget);
    expect(find.text('Evening walk'), findsNothing);
    expect(find.text(_ar.homePlaceholderBadge), findsOneWidget);

    final asrChip = find.text(_ar.windowAsr).first;
    await tester.ensureVisible(asrChip);
    await settleApp(tester);
    await tester.tap(asrChip);
    await settleApp(tester);
    expect(find.text('Evening walk'), findsOneWidget);
    expect(find.text('Review deck'), findsNothing);
  });

  testWidgets('swipe right completes with a celebration and can be undone', (tester) async {
    final app = await pumpMadarApp(
      tester,
      beforePump: _tasks({
        PrayerWindow.dhuhr: ['Review deck'],
      }),
    );
    await tester.drag(find.text('Review deck'), const Offset(300, 0));
    await _pumpFrames(tester, 40);
    await tester.pump();
    var row = (await tester.runAsync(() => app.repos.tasks.getAll()))!.single;
    expect(row.done, isTrue);
    expect(app.sound.played, contains(Sfx.complete));
    expect(find.text(_ar.homeTaskCompleted), findsOneWidget);
    final activity = (await tester.runAsync(() => app.repos.activity.since(_today)))!;
    expect(activity.single.planetKey, 'work');

    await tester.tap(find.text(_ar.actionUndo));
    await _pumpFrames(tester, 40);
    await settleApp(tester);
    row = (await tester.runAsync(() => app.repos.tasks.getAll()))!.single;
    expect(row.done, isFalse);
  });

  testWidgets('long-press → delete removes the task; undo brings it back', (tester) async {
    final app = await pumpMadarApp(
      tester,
      beforePump: _tasks({
        PrayerWindow.dhuhr: ['Review deck', 'Call Mum'],
      }),
    );
    await tester.longPress(find.text('Call Mum'));
    await settleApp(tester);
    await tester.tap(find.text(_ar.actionDelete));
    await tester.pump();
    await _pumpFrames(tester, 60);
    expect(app.sound.played, contains(Sfx.delete));
    expect((await tester.runAsync(() => app.repos.tasks.getAll()))!.map((t) => t.title), ['Review deck']);
    await tester.pump();
    expect(find.text(_ar.itemDeleted), findsOneWidget);

    await tester.tap(find.text(_ar.actionUndo));
    await _pumpFrames(tester, 40);
    await settleApp(tester);
    expect((await tester.runAsync(() => app.repos.tasks.getAll()))!.map((t) => t.title), ['Review deck', 'Call Mum']);
    expect(find.text('Call Mum'), findsOneWidget);
  });

  testWidgets('long-press → duplicate adds a copy right after the original', (tester) async {
    final app = await pumpMadarApp(
      tester,
      beforePump: _tasks({
        PrayerWindow.dhuhr: ['Review deck', 'Call Mum'],
      }),
    );
    await tester.longPress(find.text('Review deck'));
    await settleApp(tester);
    await tester.tap(find.text(_ar.actionDuplicate));
    await _pumpFrames(tester, 40);
    await settleApp(tester);
    expect((await tester.runAsync(() => app.repos.tasks.getAll()))!.map((t) => t.title), [
      'Review deck',
      'Review deck',
      'Call Mum',
    ]);
  });

  testWidgets('the quick-add bar creates a task in the window in view', (tester) async {
    final app = await pumpMadarApp(tester);
    expect(find.text(_ar.homeEmptyTitle), findsOneWidget);
    await tester.enterText(
      find.descendant(of: find.byType(QuickAddBar), matching: find.byType(TextField)),
      'اشتري خبز',
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await settleApp(tester);
    final task = (await tester.runAsync(() => app.repos.tasks.getAll()))!.single;
    expect(task.window, PrayerWindow.dhuhr);
    expect(task.date, _today);
    expect(find.text(task.title), findsOneWidget);
    expect(find.text(_ar.homeEmptyTitle), findsNothing);
  });

  testWidgets('the quick-add bar records an expense (English UI)', (tester) async {
    final app = await pumpMadarApp(tester, settings: const AppSettings(onboarded: true, languageCode: 'en'));
    expect(find.text(_en.homeRadarTitle), findsOneWidget);
    await tester.enterText(
      find.descendant(of: find.byType(QuickAddBar), matching: find.byType(TextField)),
      'spent 5 JD coffee',
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await settleApp(tester);
    final tx = (await tester.runAsync(() => app.repos.transactions.getAll()))!.single;
    expect(tx.amountMilli, 5000);
    expect((await tester.runAsync(() => app.repos.wallets.getAll()))!.single.name, _en.homeDefaultWallet);
  });

  testWidgets('the add button opens the edit sheet and saves a task', (tester) async {
    final app = await pumpMadarApp(tester);
    await tester.tap(find.byWidgetPredicate((w) => w is MadarButton && w.semanticLabel == _ar.homeAddTask));
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
    final task = (await tester.runAsync(() => app.repos.tasks.getAll()))!.single;
    expect(task.title, 'Plan the week');
    expect(task.window, PrayerWindow.dhuhr);
    expect(task.date, _today);
    expect(find.text('Plan the week'), findsOneWidget);
  });

  testWidgets('dragging the panel header expands it over the astrolabe and back', (tester) async {
    final app = await pumpMadarApp(
      tester,
      beforePump: _tasks({
        PrayerWindow.dhuhr: ['Review deck'],
      }),
    );
    final panel = find.byType(GlassPanel).first;
    final collapsed = tester.getTopLeft(panel).dy;
    await tester.drag(find.byType(WindowChips), const Offset(0, -400));
    await settleApp(tester);
    final expanded = tester.getTopLeft(panel).dy;
    expect(expanded, lessThan(collapsed - 200));
    expect(app.sound.played, contains(Sfx.sheetOpen));
    await tester.drag(find.byType(WindowChips), const Offset(0, 500));
    await settleApp(tester);
    expect(tester.getTopLeft(panel).dy, closeTo(collapsed, 1));
  });
}
