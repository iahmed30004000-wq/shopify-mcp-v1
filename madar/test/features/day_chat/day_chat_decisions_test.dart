// What his tap on one card really does, inside the real app (router,
// gates, app lock):
//
// * filing one piece writes that one feature's own row – read back from the
//   database – and leaves the other four alone;
// * the undo toast puts it back;
// * a second tap writes nothing and says so;
// * he can correct a piece first, and the edit sheet refuses a score that
//   cannot exist;
// * refusing writes nothing of his;
// * a number with no tracker becomes a tracker he owns, and the number
//   lands in it;
// * a sentence it could not read becomes his own note, in his own words;
// * a dose is never anything but his own note;
// * and every decision is still there after a restart.
//
// Split from `day_chat_screen_test.dart` so one test process stays small:
// each of these pumps the whole app.
@Timeout(Duration(minutes: 8))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/interaction/src/labels.dart' show KitLabels;
import 'package:madar/core/interaction/sheets/field_spec.dart' show FieldIssue, FieldIssueCode;
import 'package:madar/core/interaction/interaction.dart' show EditSheet;
import 'package:madar/features/custom_modules/custom_modules.dart' show CustomModulesService;
import 'package:madar/features/day_chat/day_chat.dart';

import '../../helpers/test_app.dart' show openTestDatabase;
import 'day_chat_app.dart';

/// Everything a chat piece can write, as it is in the database right now.
Future<Map<String, int>> _counts(DayChatApp app) async => {
  'transactions': (await app.repos.transactions.getAll()).length,
  'food_logs': (await app.repos.foodLogs.getAll()).length,
  'workout_logs': (await app.repos.workoutLogs.getAll()).length,
  'water_logs': (await app.repos.waterLogs.getAll()).length,
  'pain_entries': (await app.repos.painEntries.getAll()).length,
  'mood_entries': (await app.repos.moodEntries.getAll()).length,
  'contact_logs': (await app.repos.contactLogs.getAll()).length,
  'custom_entries': (await app.repos.customEntries.getAll()).length,
  'prayer_logs': (await app.repos.prayerLogs.getAll()).length,
  'tasks': (await app.repos.tasks.getAll()).length,
};

Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  testWidgets('filing one card writes that one row and leaves the others alone', (tester) async {
    final app = await pumpDayChat(tester);
    // What his data holds before a single word is typed (the seed gives him
    // one open task), so "nothing moved" is measured and not assumed.
    final fresh = await _counts(app);
    final pieces = await sendLine(tester, app, fiveFacts, expectPieces: 5);
    final expense = pieces.firstWhere((p) => p.kind == DayChatKind.expense);
    final before = await _counts(app);
    expect(before, fresh, reason: 'reading writes nothing');

    await tapCardButton(tester, 'file', expense.id);
    await dayChatUntil(
      tester,
      'the ledger entry',
      () => storedDay(app)?.stateOf(expense.id) == DayChatState.applied,
    );

    // Read back from the database, not from the screen.
    final rows = await app.repos.transactions.getAll();
    expect(rows, hasLength(1));
    expect(rows.single.amountMilli, 5000);
    expect(rows.single.kind, TxKind.expense);
    expect(rows.single.note, contains('قهوة'));

    // The other four are exactly as they were.
    final after = await _counts(app);
    for (final key in after.keys) {
      if (key == 'transactions') continue;
      expect(after[key], before[key], reason: '$key must not have moved');
    }
    // And the chat knows where it landed, so he can follow it.
    final decision = storedDay(app)!.decision(expense.id)!;
    expect(decision.refTable, 'transactions');
    expect(decision.refId, rows.single.id);
    expect(find.byKey(ValueKey('dayChat.open.${expense.id}')), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the undo toast takes it straight back out', (tester) async {
    final app = await pumpDayChat(tester);
    final pieces = await sendLine(tester, app, 'شربت كاسة مي');
    final water = pieces.single;
    await tapCardButton(tester, 'file', water.id);
    await dayChatUntil(tester, 'the water log', () => (storedDay(app)?.applied.length ?? 0) == 1);
    expect(await app.repos.waterLogs.getAll(), hasLength(1));

    await tester.tap(find.text(chatL10n('ar').actionUndo));
    await _settle(tester, frames: 20);
    await dayChatUntil(
      tester,
      'the water log gone again',
      () => storedDay(app)?.stateOf(water.id) == DayChatState.undone,
    );
    expect(await app.repos.waterLogs.getAll(), isEmpty);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a second tap on a filed card writes nothing', (tester) async {
    final app = await pumpDayChat(tester);
    final pieces = await sendLine(tester, app, 'شربت كاسة مي');
    final water = pieces.single;
    await tapCardButton(tester, 'file', water.id);
    await dayChatUntil(tester, 'the water log', () => (storedDay(app)?.applied.length ?? 0) == 1);
    final first = await app.repos.waterLogs.getAll();
    expect(first, hasLength(1));

    // The card no longer offers «سجّلها» at all; the engine is asked again
    // through the service, which is where the second tap would land.
    expect(find.byKey(ValueKey('dayChat.file.${water.id}')), findsNothing);
    final again = await app.app.container.read(dayChatServiceProvider).apply(water, day: dayChatToday);
    expect(again.alreadyApplied, isTrue);
    expect(await app.repos.waterLogs.getAll(), hasLength(1));
    expect((await app.repos.waterLogs.getAll()).single.id, first.single.id);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('he can correct a piece first, and a score that cannot exist is refused', (tester) async {
    final app = await pumpDayChat(tester);
    final pieces = await sendLine(tester, app, 'وجع الركبة ٦');
    final pain = pieces.single;
    expect(pain.kind, DayChatKind.pain);
    expect((pain.fact as PainFact).score, 6);

    await tapCardButton(tester, 'edit', pain.id);
    expect(find.text(chatL10n('ar').dayChatEditTitle), findsOneWidget);

    // 0–10 is the scale the wellbeing screens use, and the sheet holds it:
    // ١٢ cannot be saved, and it says why.
    // The sheet's own field – the chat's box is still on the tree behind it.
    final field = find.descendant(of: find.byType(EditSheet), matching: find.byType(TextField)).first;
    await tester.enterText(field, '12');
    await _settle(tester, frames: 6);
    await tester.tap(find.text(chatL10n('ar').actionSave), warnIfMissed: false);
    await _settle(tester, frames: 8);
    expect(find.text(chatL10n('ar').dayChatEditTitle), findsOneWidget, reason: 'the sheet refused to close');
    expect(
      find.text(
        KitLabels.issue(
          tester.element(find.text(chatL10n('ar').dayChatEditTitle)),
          const FieldIssue(FieldIssueCode.aboveMax, limit: 10),
        ),
      ),
      findsOneWidget,
    );

    // A score that can exist goes through, and it is the score he typed.
    await tester.enterText(field, '4');
    await _settle(tester, frames: 6);
    await tester.tap(find.text(chatL10n('ar').actionSave));
    await _settle(tester, frames: 12);
    expect(find.text(chatL10n('ar').dayChatEditTitle), findsNothing);
    // Still nothing written: the edit lives on the card until he files it.
    expect(await app.repos.painEntries.getAll(), isEmpty);

    await tapCardButton(tester, 'file', pain.id);
    await dayChatUntil(tester, 'the pain entry', () => (storedDay(app)?.applied.length ?? 0) == 1);
    final rows = await app.repos.painEntries.getAll();
    expect(rows, hasLength(1));
    expect(rows.single.score, 4, reason: 'his correction, not the reader’s six');
    expect(storedDay(app)!.decision(pain.id)!.edited, isTrue);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('refusing one card writes nothing of his', (tester) async {
    final app = await pumpDayChat(tester);
    final fresh = await _counts(app);
    final pieces = await sendLine(tester, app, 'صرفت ٥ دنانير قهوة');
    final expense = pieces.single;
    await tapCardButton(tester, 'reject', expense.id);
    await dayChatUntil(
      tester,
      'the refusal',
      () => storedDay(app)?.stateOf(expense.id) == DayChatState.rejected,
    );
    expect(await app.repos.transactions.getAll(), isEmpty);
    expect(await _counts(app), fresh);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a number with no tracker becomes a tracker of his, and the number lands in it', (tester) async {
    final app = await pumpDayChat(tester);
    final pieces = await sendLine(tester, app, 'وزني ٨٢');
    final sign = pieces.single;
    expect(sign.kind, DayChatKind.sign);
    expect(sign.canApply, isFalse, reason: 'it has nowhere to land yet');

    await reveal(tester, find.byKey(ValueKey('dayChat.card.${sign.id}')));
    expect(find.byKey(ValueKey('dayChat.file.${sign.id}')), findsNothing);
    expect(find.text(chatL10n('ar').dayChatSignBody), findsOneWidget);

    await tapCardButton(tester, 'tracker', sign.id);
    expect(find.text(chatL10n('ar').dayChatTrackerTitle), findsOneWidget);
    await tester.tap(find.text(chatL10n('ar').actionSave));
    await _settle(tester, frames: 20);
    await dayChatUntil(
      tester,
      'the new tracker and its first reading',
      () => storedDay(app)?.stateOf(sign.id) == DayChatState.applied,
    );

    final modules = await CustomModulesService(app.repos, clock: () => dayChatNow).modules();
    final made = modules.where((m) => m.name == 'وزني');
    expect(made, hasLength(1), reason: 'a tracker named with his own word');
    final entries = await app.repos.customEntries.getAll();
    expect(entries.where((e) => e.moduleId == made.single.id), hasLength(1));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a sentence it could not read becomes his own note, word for word', (tester) async {
    final app = await pumpDayChat(tester);
    final pieces = await sendLine(tester, app, 'غسلت السيارة');
    final unread = pieces.single;
    await tapCardButton(tester, 'note', unread.id);
    await dayChatUntil(
      tester,
      'the note',
      () => storedDay(app)?.stateOf(unread.id) == DayChatState.applied,
    );
    final tasks = await app.repos.tasks.getAll();
    final note = tasks.where((t) => t.title == 'غسلت السيارة');
    expect(note, hasLength(1), reason: 'his words, kept whole');
    // Nothing was invented out of it: no money, no measure, no tracker.
    final counts = await _counts(app);
    for (final key in counts.keys) {
      if (key == 'tasks') continue;
      expect(counts[key], 0, reason: key);
    }
    expect(counts['tasks'], 2, reason: 'his one open task, plus this note');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a dose is only ever his own note, and the card says so', (tester) async {
    final app = await pumpDayChat(tester);
    final pieces = await sendLine(tester, app, 'أخذت بنادول ٥٠٠ ملغ');
    final piece = pieces.single;
    // The engine already forced it; the screen must not dress it up as a
    // medical fact.
    expect(piece.kind, DayChatKind.note);
    expect(piece.flag, isNotNull);
    await reveal(tester, find.byKey(ValueKey('dayChat.card.${piece.id}')));
    expect(find.text(chatL10n('ar').dayChatGuardNote), findsOneWidget);
    expect(find.text(chatTexts(tester).where(piece)), findsWidgets);
    expect(find.text(chatTexts(tester).kind(DayChatKind.note)), findsOneWidget);

    await tapCardButton(tester, 'file', piece.id);
    await dayChatUntil(tester, 'the note', () => (storedDay(app)?.applied.length ?? 0) == 1);
    expect(storedDay(app)!.decision(piece.id)!.kind, DayChatKind.note);
    // Nowhere near the medical record.
    expect(await app.repos.medications.getAll(), isEmpty);
    expect(await app.repos.conditions.getAll(), isEmpty);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('every decision is still there after a restart', (tester) async {
    final db = await openTestDatabase(tester);
    await tester.runAsync(() => seedDayChat(db));
    final app = await pumpDayChat(tester, on: db, seed: false);
    final pieces = await sendLine(tester, app, fiveFacts, expectPieces: 5);
    final expense = pieces.firstWhere((p) => p.kind == DayChatKind.expense);
    final prayer = pieces.firstWhere((p) => p.kind == DayChatKind.prayer);
    await tapCardButton(tester, 'file', expense.id);
    await dayChatUntil(tester, 'the entry', () => storedDay(app)?.stateOf(expense.id) == DayChatState.applied);
    await tapCardButton(tester, 'reject', prayer.id);
    await dayChatUntil(tester, 'the refusal', () => storedDay(app)?.stateOf(prayer.id) == DayChatState.rejected);

    // A brand new app over the same data – which is what a restart is.
    final restarted = await pumpDayChat(tester, on: db, seed: false);
    await dayChatUntil(
      tester,
      'his line read again',
      () => readings(restarted).length == 1 && readings(restarted).single.pieces.length == 5,
    );
    final again = readings(restarted).single.pieces;
    // The same words give the same piece ids, so the decisions still fit.
    expect([for (final p in again) p.id], [for (final p in pieces) p.id]);
    final stored = storedDay(restarted)!;
    expect(stored.stateOf(expense.id), DayChatState.applied);
    expect(stored.stateOf(prayer.id), DayChatState.rejected);
    expect(stored.stateOf(pieces.last.id), DayChatState.pending);

    await reveal(tester, find.byKey(ValueKey('dayChat.card.${expense.id}')));
    final card = tester.widget<DayChatPieceCard>(find.byKey(ValueKey('dayChat.card.${expense.id}')));
    expect(card.state, DayChatState.applied);
    expect(find.byKey(ValueKey('dayChat.file.${expense.id}')), findsNothing);
    // And nothing was written twice by reading the day again.
    expect(await Repositories(db).transactions.getAll(), hasLength(1));
    await tester.pump(const Duration(seconds: 6));
  });
}
