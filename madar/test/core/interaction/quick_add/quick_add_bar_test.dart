import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/interaction/quick_add/parser.dart';
import 'package:madar/core/interaction/quick_add/preview.dart';
import 'package:madar/core/interaction/quick_add/quick_add_bar.dart';
import 'package:madar/core/interaction/quick_add/quick_add_handler.dart';
import 'package:madar/core/settings/app_settings.dart' show DigitStyle;
import 'package:madar/core/sound/sound_api.dart';

import '../interaction_test_utils.dart';

final _now = DateTime(2026, 9, 27, 10); // Sunday
QuickAddIntent _p(String s) => QuickAddParser.parse(s, now: _now);

class _Recorder extends QuickAddHandler {
  _Recorder([this.answer = true]);
  final bool answer;
  final List<QuickAddIntent> seen = [];

  @override
  Future<bool> handle(QuickAddIntent intent) async {
    seen.add(intent);
    return answer;
  }
}

Widget _bar({QuickAddHandler? handler, ValueChanged<QuickAddIntent>? onAdded}) => Padding(
  padding: const EdgeInsets.all(16),
  child: Align(
    alignment: Alignment.topCenter,
    child: QuickAddBar(handler: handler, clock: () => _now, onAdded: onAdded),
  ),
);

void main() {
  late List<Sfx> played;
  setUp(() => played = installInteractionFx().sound.played);

  group('quickAddFacets', () {
    test('empty input shows nothing', () => expect(quickAddFacets(_p('  ')), isEmpty));
    test('expense: kind + amount', () {
      expect(quickAddFacets(_p('صرفت 12.5 دينار بنزين')), [QuickAddFacet.kind, QuickAddFacet.amount]);
    });
    test('task with date, window and planet', () {
      expect(quickAddFacets(_p('بكرا بعد المغرب اجتماع مع فريق مصر')), [
        QuickAddFacet.kind,
        QuickAddFacet.date,
        QuickAddFacet.window,
        QuickAddFacet.planet,
      ]);
    });
    test('water shows millilitres; pain and mood show a score', () {
      expect(quickAddFacets(_p('water 750ml')), [QuickAddFacet.kind, QuickAddFacet.water]);
      expect(quickAddFacets(_p('ألم ظهر 6')), [QuickAddFacet.kind, QuickAddFacet.score]);
      expect(quickAddFacets(_p('مزاجي 4')), [QuickAddFacet.kind, QuickAddFacet.score]);
    });
    test('clock time', () {
      expect(quickAddFacets(_p('call ahmad 17:30')), contains(QuickAddFacet.time));
    });
    test('money kinds do not repeat their implied planet', () {
      expect(quickAddFacets(_p('spent 20 usd on lunch')), isNot(contains(QuickAddFacet.planet)));
    });
  });

  group('handlers', () {
    test('composite tries each handler until one accepts', () async {
      final a = _Recorder(false);
      final b = _Recorder(true);
      final c = _Recorder(true);
      expect(await CompositeQuickAddHandler([a, b, c]).handle(_p('شاي')), isTrue);
      expect([a.seen.length, b.seen.length, c.seen.length], [1, 1, 0]);
      expect(await const CompositeQuickAddHandler([]).handle(_p('شاي')), isFalse);
    });
    test('kind routing with a fallback', () async {
      final money = _Recorder();
      final rest = _Recorder();
      final h = KindQuickAddHandler({QuickAddKind.expense: money}, fallback: rest);
      await h.handle(_p('صرفت 5 دنانير'));
      await h.handle(_p('اجتماع'));
      expect(money.seen.single.kind, QuickAddKind.expense);
      expect(rest.seen.single.kind, QuickAddKind.task);
      expect(await const KindQuickAddHandler({}).handle(_p('x')), isFalse);
    });
    test('callback handler', () async {
      QuickAddIntent? got;
      final h = CallbackQuickAddHandler((i) async {
        got = i;
        return true;
      });
      expect(await h.handle(_p('water 1l')), isTrue);
      expect(got!.ml, 1000);
    });
  });

  testWidgets('typing shows live preview chips', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(interactionApp(_bar()));
    expect(find.text('مصروف'), findsNothing);
    await tester.enterText(find.byType(TextField), 'صرفت 12.5 دينار بنزين');
    await tester.pumpAndSettle();
    expect(find.text('مصروف'), findsOneWidget);
    // Amounts follow the user's digit style (Arabic-Indic in Arabic).
    expect(find.text('١٢٫٥ د.أ'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'بكرا بعد المغرب اجتماع مع فريق مصر');
    await tester.pumpAndSettle();
    expect(find.text('مهمة'), findsOneWidget);
    expect(find.text('غدًا'), findsOneWidget);
    expect(find.text('المغرب ← العشاء'), findsOneWidget);
    expect(find.text('العمل'), findsOneWidget);
    expect(find.text('مصروف'), findsNothing);
  });

  testWidgets('every chip of one preview uses one digit style', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(interactionApp(_bar()));
    await tester.enterText(find.byType(TextField), 'صرفت 12.5 دينار بنزين 15/10 الساعة 5');
    await tester.pumpAndSettle();
    // Chip texts only (not the field's own hint / typed text).
    Iterable<String> chipTexts() {
      final field = tester.widgetList<Text>(find.descendant(of: find.byType(TextField), matching: find.byType(Text))).toSet();
      return tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => !field.contains(t))
          .map((t) => t.data ?? '')
          .where((s) => s.isNotEmpty);
    }

    final chips = chipTexts();
    expect(chips, contains('١٢٫٥ د.أ'));
    expect(chips.where((s) => RegExp('[0-9]').hasMatch(s)), isEmpty, reason: '$chips');

    await tester.pumpWidget(interactionApp(_bar(), digits: DigitStyle.western));
    await tester.enterText(find.byType(TextField), 'صرفت 12.5 دينار بنزين 15/10 الساعة 5');
    await tester.pumpAndSettle();
    final western = chipTexts();
    expect(western, contains('12.5 د.أ'));
    expect(western.where((s) => RegExp('[٠-٩]').hasMatch(s)), isEmpty, reason: '$western');
  });

  testWidgets('submits through quickAddHandlerProvider, clears and confirms', (tester) async {
    usePhoneSurface(tester);
    final recorder = _Recorder();
    final added = <QuickAddIntent>[];
    await tester.pumpWidget(
      interactionApp(_bar(onAdded: added.add), overrides: [quickAddHandlerProvider.overrideWithValue(recorder)]),
    );
    await tester.enterText(find.byType(TextField), 'شرب ماء 500 مل');
    await tester.pumpAndSettle();
    expect(find.text('٥٠٠ مل'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(recorder.seen.single.kind, QuickAddKind.water);
    expect(recorder.seen.single.ml, 500);
    expect(added.single.ml, 500);
    expect(played, containsAllInOrder([Sfx.tap, Sfx.complete]));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.text('أُضيف إلى مداره'), findsOneWidget);
    // The confirmation fades on its own.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('أُضيف إلى مداره'), findsNothing);
  });

  testWidgets('the explicit handler wins over the provider; send button submits', (tester) async {
    usePhoneSurface(tester);
    final provided = _Recorder();
    final explicit = _Recorder();
    await tester.pumpWidget(
      interactionApp(_bar(handler: explicit), overrides: [quickAddHandlerProvider.overrideWithValue(provided)]),
    );
    await tester.enterText(find.byType(TextField), 'tomorrow after isha call supplier');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('إضافة'));
    await tester.pumpAndSettle();
    expect(provided.seen, isEmpty);
    final intent = explicit.seen.single;
    // An imperative ("call supplier") is a to-do, not a logged call.
    expect(intent.kind, QuickAddKind.task);
    expect(intent.title, 'call supplier');
    expect(intent.window, PrayerWindow.isha);
    expect(intent.date, DateTime(2026, 9, 28));
  });

  testWidgets('without a handler it explains quick add is not ready', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(interactionApp(_bar()));
    await tester.enterText(find.byType(TextField), 'اجتماع');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(played, contains(Sfx.error));
    expect(find.text('الإضافة السريعة ليست جاهزة بعد'), findsOneWidget);
    // The text is kept.
    expect(find.text('اجتماع'), findsOneWidget);
  });

  testWidgets('empty submit is rejected with a hint', (tester) async {
    usePhoneSurface(tester);
    final recorder = _Recorder();
    await tester.pumpWidget(interactionApp(_bar(handler: recorder)));
    await tester.tap(find.bySemanticsLabel('إضافة'));
    await tester.pumpAndSettle();
    expect(recorder.seen, isEmpty);
    expect(played, contains(Sfx.error));
    expect(find.text('اكتب شيئًا أولًا'), findsOneWidget);
    // Typing clears the error.
    await tester.enterText(find.byType(TextField), 'ش');
    await tester.pumpAndSettle();
    expect(find.text('اكتب شيئًا أولًا'), findsNothing);
  });

  testWidgets('a handler that declines or throws keeps the text and reports failure', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(interactionApp(_bar(handler: _Recorder(false))));
    await tester.enterText(find.byType(TextField), 'مزاجي 4');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('تعذّرت الإضافة، حاول مرة أخرى'), findsOneWidget);
    expect(find.text('مزاجي 4'), findsOneWidget);

    await tester.pumpWidget(
      interactionApp(_bar(handler: CallbackQuickAddHandler((_) async => throw StateError('db locked')))),
    );
    await tester.enterText(find.byType(TextField), 'مزاجي 5');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isA<StateError>());
    expect(find.text('تعذّرت الإضافة، حاول مرة أخرى'), findsOneWidget);
  });

  testWidgets('shows a busy state while the handler works and ignores double submits', (tester) async {
    usePhoneSurface(tester);
    var calls = 0;
    await tester.pumpWidget(
      interactionApp(
        _bar(
          handler: CallbackQuickAddHandler((_) async {
            calls++;
            await Future<void>.delayed(const Duration(milliseconds: 500));
            return true;
          }),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'note: idea');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 100));
    final state = tester.state<QuickAddBarState>(find.byType(QuickAddBar));
    expect(state.busy, isTrue);
    expect(await state.submit(), isFalse);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(state.busy, isFalse);
  });

  testWidgets('Latin text in the Arabic UI is typed left-to-right, and vice versa', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(interactionApp(_bar()));
    await tester.enterText(find.byType(TextField), 'spent 20 usd on lunch');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).textDirection, TextDirection.ltr);
    await tester.enterText(find.byType(TextField), '١٢ صرفت');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).textDirection, TextDirection.rtl);
    await tester.pumpAndSettle();
  });

  testWidgets('English UI', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(interactionApp(_bar(), locale: const Locale('en')));
    await tester.enterText(find.byType(TextField), 'spent 20 usd on lunch');
    await tester.pumpAndSettle();
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text(r'20 $'), findsOneWidget);
  });
}
