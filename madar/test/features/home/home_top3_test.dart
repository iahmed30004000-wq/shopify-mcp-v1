// Today's Top 3 from the home panel: a task's long-press menu adds it to (or
// takes it off) Work's Top 3 – the limit of three holds, a full Top 3 offers
// Work's swap sheet, a card-linked task flags its card, and every change has
// its undo toast.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/work/work.dart' show CardDraft, WorkService;

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';
import '../orbit/presentation/orbit_scene_fixtures.dart' show hostPrayerSettings;

final _ar = lookupL10n(const Locale('ar'));
final _today = DateTime(testNow.year, testNow.month, testNow.day);

Future<void> _seed(MadarDatabase db, List<(String, bool)> tasks) async {
  await OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());
  var i = 0;
  for (final (title, top3) in tasks) {
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: title,
            window: const Value(PrayerWindow.dhuhr),
            date: Value(_today),
            planetKey: const Value('work'),
            isTop3: Value(top3),
            sortOrder: Value(i++),
          ),
        );
  }
}

Future<void> _openPanel(WidgetTester tester) async {
  final label = _ar.orbitUiPanelExpand;
  await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label));
  await settleApp(tester);
}

/// Lets the database work land (the undo toast stays up: no settling).
Future<void> _writes(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<Map<String, bool>> _flags(WidgetTester tester, TestApp app) async => {
  for (final t in (await tester.runAsync(() => app.repos.tasks.getAll()))!) t.title: t.isTop3,
};

void main() {
  testWidgets('the menu adds a task to the Top 3, with undo; and takes it off', (tester) async {
    final app = await pumpMadarApp(
      tester,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) => _seed(db, [('Review deck', false), ('Call supplier', false)]),
    );
    await _openPanel(tester);
    await tester.longPress(find.text('Review deck'));
    await settleApp(tester);
    await tester.tap(find.text(_ar.workTop3Add));
    await _writes(tester);
    expect(await _flags(tester, app), {'Review deck': true, 'Call supplier': false});
    expect(find.text(_ar.workTop3Added), findsOneWidget, reason: 'one undo toast');
    await tester.tap(find.text(_ar.actionUndo));
    await _writes(tester);
    expect((await _flags(tester, app))['Review deck'], isFalse);
    await tester.pump(const Duration(seconds: 6));

    await tester.longPress(find.text('Call supplier'));
    await settleApp(tester);
    await tester.tap(find.text(_ar.workTop3Add));
    await _writes(tester);
    await tester.pump(const Duration(seconds: 6));
    await tester.longPress(find.text('Call supplier'));
    await settleApp(tester);
    expect(find.text(_ar.workTop3Remove), findsOneWidget);
    await tester.tap(find.text(_ar.workTop3Remove));
    await _writes(tester);
    expect((await _flags(tester, app))['Call supplier'], isFalse);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a full Top 3 keeps three: the swap sheet trades one for the new task', (tester) async {
    final app = await pumpMadarApp(
      tester,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) => _seed(db, [('One', true), ('Two', true), ('Three', true), ('Four', false)]),
    );
    await _openPanel(tester);
    await tester.longPress(find.text('Four'));
    await settleApp(tester);
    await tester.tap(find.text(_ar.workTop3Add));
    await _writes(tester);
    expect(find.text(_ar.workTop3FullTitle), findsOneWidget, reason: "Work's swap sheet");
    expect((await _flags(tester, app)).values.where((f) => f), hasLength(3), reason: 'nothing changed yet');
    await tester.tap(find.descendant(of: find.byType(MoveSheet), matching: find.text('Two')));
    await _writes(tester);
    expect(await _flags(tester, app), {'One': true, 'Two': false, 'Three': true, 'Four': true});
    expect(find.text(_ar.workTop3Swapped), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a task that carries a card flags the card', (tester) async {
    late String cardId;
    final app = await pumpMadarApp(
      tester,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async {
        await OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());
        final work = WorkService(Repositories(db), clock: () => testNow);
        final board = await work.createBoard(name: 'Shop');
        final card = await work.addCard(board.id, const CardDraft(title: 'Ship the order'));
        await work.placeCard(card, PrayerWindow.dhuhr);
        cardId = card.id;
      },
    );
    await _openPanel(tester);
    await tester.longPress(find.text('Ship the order'));
    await settleApp(tester);
    await tester.tap(find.text(_ar.workTop3Add));
    await _writes(tester);
    final card = await tester.runAsync(() => app.repos.boardCards.byId(cardId));
    expect(card!.isTop3, isTrue);
    await _writes(tester);
    final task = (await tester.runAsync(() => app.repos.tasks.getAll(where: (t) => t.cardId.equals(cardId))))!.single;
    expect(task.isTop3, isTrue, reason: 'kept in step by the card ⇄ task sync');
    await tester.pump(const Duration(seconds: 6));
  });
}
