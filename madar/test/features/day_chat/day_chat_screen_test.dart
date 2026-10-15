// The daily chat as he sees it, inside the real app (router, gates, app
// lock), in Arabic and English:
//
// * a fresh install opens an empty chat with a warm invitation and no
//   sample conversation;
// * his five-fact line comes back as five cards, each underlining the
//   exact stretch of his own sentence it was read from;
// * a piece that still needs him cannot be filed and says what is missing;
// * a sentence it could not read offers its three ways out, and the AI one
//   only ever **opens** Part 3's sheet – no transport is asked anywhere;
// * «شو صار اليوم؟» on a full day and on an empty one.
@Timeout(Duration(minutes: 6))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/features/ai_bridge/ai_bridge.dart' show AiBridgeExportSheet;
import 'package:madar/features/day_chat/day_chat.dart';

import 'day_chat_app.dart';

/// The stretches of his own line the bubble underlines, in order.
List<String> underlined(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.descendant(of: find.byType(DayChatBubble), matching: find.byType(Text)).first,
  );
  final span = text.textSpan;
  final out = <String>[];
  span?.visitChildren((child) {
    if (child is TextSpan && child.style?.decoration == TextDecoration.underline) out.add(child.text ?? '');
    return true;
  });
  return out;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  for (final lang in ['ar', 'en']) {
    final l = chatL10n(lang);

    group(lang, () {
      testWidgets('a fresh install opens an empty chat and invites him', (tester) async {
        final app = await pumpDayChat(tester, lang: lang, seed: false);
        expect(find.byType(DayChatScreen), findsOneWidget);
        expect(find.text(l.dayChatTitle), findsOneWidget);
        expect(find.text(l.dayChatEmptyTitle), findsOneWidget);
        expect(find.text(l.dayChatEmptyBody), findsOneWidget);
        // Nothing of anybody's: no card, no bubble, no sample day.
        expect(find.byType(DayChatPieceCard), findsNothing);
        expect(find.byType(DayChatBubble), findsNothing);
        expect(readings(app), isEmpty);
        // And the box is there, empty, waiting.
        expect(find.byKey(const ValueKey('dayChat.input')), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(DayChatScreen))),
          lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(app.transport.requests, isEmpty);
        await tester.pump(const Duration(seconds: 6));
      });

      testWidgets('his five facts come back as five cards, each pointing at his own words', (tester) async {
        final app = await pumpDayChat(tester, lang: lang);
        final pieces = await sendLine(tester, app, fiveFacts, expectPieces: 5);
        expect([for (final p in pieces) p.kind], [
          DayChatKind.expense,
          DayChatKind.prayer,
          DayChatKind.workout,
          DayChatKind.pain,
          DayChatKind.water,
        ]);

        // The underline in his bubble is exactly the engine's span – not a
        // search for his words, not a guess.
        expect(underlined(tester), [for (final p in pieces) p.span.of(fiveFacts)]);
        expect(underlined(tester).first, 'صرفت ٥ دنانير قهوة');

        // Every piece really has a card, and the card quotes those words.
        final tx = chatTexts(tester);
        for (final piece in pieces) {
          await reveal(tester, find.byKey(ValueKey('dayChat.card.${piece.id}')));
          expect(find.byKey(ValueKey('dayChat.card.${piece.id}')), findsOneWidget, reason: piece.kind.name);
          final card = tester.widget<DayChatPieceCard>(find.byKey(ValueKey('dayChat.card.${piece.id}')));
          expect(card.state, DayChatState.pending);
          expect(find.text(tx.title(piece)), findsOneWidget, reason: 'what it would write');
          expect(find.text(tx.where(piece)), findsWidgets, reason: 'where it would land');
          expect(find.text(tx.name(piece.text)), findsOneWidget, reason: 'his own words, quoted');
          // The one decision is his, and there is only ever one of it.
          expect(find.byKey(ValueKey('dayChat.file.${piece.id}')), findsOneWidget);
        }

        // Nothing was written by reading: his data is still untouched.
        expect(await app.repos.transactions.getAll(), isEmpty);
        expect(await app.repos.waterLogs.getAll(), isEmpty);
        expect(app.transport.requests, isEmpty);
        await tester.pump(const Duration(seconds: 6));
      });

      testWidgets('a piece that still needs him cannot be filed, and says why', (tester) async {
        final app = await pumpDayChat(tester, lang: lang);
        final pieces = await sendLine(tester, app, 'صرفت على القهوة');
        final piece = pieces.single;
        expect(piece.kind, DayChatKind.expense);
        expect(piece.canApply, isFalse);
        expect(piece.needsHim, isTrue);

        await reveal(tester, find.byKey(ValueKey('dayChat.card.${piece.id}')));
        // No «سجّلها» at all – the screen cannot offer what the engine refuses.
        expect(find.byKey(ValueKey('dayChat.file.${piece.id}')), findsNothing);
        // It says what is missing, and the one tap that fixes it.
        expect(find.text(l.dayChatNeedsYou), findsOneWidget);
        expect(find.text(chatTexts(tester).gap(piece.gaps.first)), findsOneWidget);
        expect(find.byKey(ValueKey('dayChat.edit.${piece.id}')), findsOneWidget);
        expect(find.byKey(ValueKey('dayChat.reject.${piece.id}')), findsOneWidget);

        expect(await app.repos.transactions.getAll(), isEmpty);
        expect(app.transport.requests, isEmpty);
        await tester.pump(const Duration(seconds: 6));
      });

      testWidgets('a sentence it could not read offers three ways out, and sends nothing by itself', (tester) async {
        final app = await pumpDayChat(tester, lang: lang);
        final pieces = await sendLine(tester, app, 'غسلت السيارة');
        final piece = pieces.single;
        expect(piece.kind, DayChatKind.unread);

        await reveal(tester, find.byKey(ValueKey('dayChat.card.${piece.id}')));
        expect(find.text(chatTexts(tester).kind(DayChatKind.unread)), findsOneWidget);
        expect(find.byKey(ValueKey('dayChat.note.${piece.id}')), findsOneWidget);
        expect(find.byKey(ValueKey('dayChat.reword.${piece.id}')), findsOneWidget);
        expect(find.byKey(ValueKey('dayChat.askAi.${piece.id}')), findsOneWidget);
        // Never offered as something to file as a fact.
        expect(find.byKey(ValueKey('dayChat.file.${piece.id}')), findsNothing);
        expect(find.text(l.dayChatAiOffline), findsOneWidget);

        // His explicit tap opens Part 3's own sheet with that one sentence
        // as his question – and even then nothing has gone anywhere.
        await tapCardButton(tester, 'askAi', piece.id);
        expect(find.byType(AiBridgeExportSheet), findsOneWidget);
        expect(app.transport.requests, isEmpty, reason: 'the chat opens no connection of its own');
        await tester.pump(const Duration(seconds: 6));
      });

      testWidgets('«شو صار اليوم؟» reads an empty day plainly', (tester) async {
        final app = await pumpDayChat(tester, lang: lang, seed: false);
        await tester.tap(find.byKey(const ValueKey('dayChat.tab.summary')));
        await dayChatUntil(tester, 'the summary', () => find.text(l.dayChatSummaryEmpty).evaluate().isNotEmpty);
        expect(find.text(l.dayChatSummaryEmpty), findsOneWidget);
        // An empty day is a fact, not an occasion: no illustration, no
        // cheer-up, and not even the offline note.
        expect(find.text(l.dayChatSummaryOffline), findsNothing);
        expect(app.transport.requests, isEmpty);
        await tester.pump(const Duration(seconds: 6));
      });

      testWidgets('«شو صار اليوم؟» reads back a day he filed himself', (tester) async {
        final app = await pumpDayChat(tester, lang: lang);
        final pieces = await sendLine(tester, app, fiveFacts, expectPieces: 5);
        // One tap per piece, which is the whole point of the screen.
        for (final piece in pieces) {
          await tapCardButton(tester, 'file', piece.id);
        }
        await dayChatUntil(
          tester,
          'his five facts in his data',
          () => storedDay(app)?.applied.length == 5,
        );

        await tester.tap(find.byKey(const ValueKey('dayChat.tab.summary')));
        await dayChatUntil(tester, 'the summary', () => find.byType(DaySummaryView).evaluate().isNotEmpty);
        await dayChatUntil(
          tester,
          'the summary lines',
          () => find.text(l.dayChatSummaryOffline).evaluate().isNotEmpty,
        );
        final summary = app.app.container.read(dayChatSummaryProvider(dayChatToday)).value!;
        expect(summary.isEmpty, isFalse);
        final lines = chatTexts(tester).summary(summary);
        expect(lines, isNotEmpty);
        for (final line in lines) {
          expect(find.text(line), findsOneWidget, reason: line);
        }
        // The day he typed is the day it reads back.
        expect(find.text(chatTexts(tester).summaryTitle(dayChatToday)), findsOneWidget);
        expect(summary.line(DaySummaryTopic.money), isNotNull);
        expect(summary.line(DaySummaryTopic.prayers), isNotNull);
        expect(summary.line(DaySummaryTopic.water), isNotNull);
        expect(app.transport.requests, isEmpty);
        await tester.pump(const Duration(seconds: 6));
      });
    });
  }

  testWidgets('the whole chat never asks the transport for anything', (tester) async {
    final app = await pumpDayChat(tester);
    final pieces = await sendLine(tester, app, fiveFacts, expectPieces: 5);
    await tapCardButton(tester, 'file', pieces.first.id);
    await tapCardButton(tester, 'reject', pieces[1].id);
    final unread = await sendLine(tester, app, 'غسلت السيارة');
    expect(unread.single.kind, DayChatKind.unread);
    await tester.tap(find.byKey(const ValueKey('dayChat.tab.summary')));
    await dayChatUntil(tester, 'the summary', () => find.byType(DaySummaryView).evaluate().isNotEmpty);
    // Reading, filing, refusing, an unread sentence and the day summary:
    // not one request, and nothing queued on the fake either.
    expect(app.transport.requests, isEmpty);
    expect(app.transport.queue, isEmpty);
    await tester.pump(const Duration(seconds: 6));
  });
}
