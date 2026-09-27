import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/interaction/actions.dart';
import 'package:madar/core/interaction/undo_toast.dart';
import 'package:madar/core/sound/sound_api.dart';

import 'interaction_test_utils.dart';

/// Opens toasts from a button so each test controls the context.
class _Host extends StatelessWidget {
  const _Host({required this.onPressed});

  final void Function(BuildContext context) onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Builder(
      builder: (context) => ElevatedButton(onPressed: () => onPressed(context), child: const Text('go')),
    ),
  );
}

void main() {
  late List<Sfx> played;
  setUp(() => played = installInteractionFx().sound.played);

  testWidgets('shows label, Undo and a 5-second countdown, then expires with false', (tester) async {
    usePhoneSurface(tester);
    Future<bool>? result;
    var undos = 0;
    await tester.pumpWidget(
      interactionApp(
        _Host(
          onPressed: (context) =>
              result = showUndoToast(context, UndoableAction(label: 'حُذفت المهمة', undo: () async => undos++)),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await pumpFrames(tester, 20);
    expect(find.text('حُذفت المهمة'), findsOneWidget);
    expect(find.text('تراجع'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('4'), findsOneWidget);

    bool? outcome;
    result!.then((v) => outcome = v);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('حُذفت المهمة'), findsNothing);
    expect(outcome, isFalse);
    expect(undos, 0);
  });

  testWidgets('tapping Undo runs undo(), plays Sfx.undo, confirms and completes with true', (tester) async {
    usePhoneSurface(tester);
    Future<bool>? result;
    var undos = 0;
    await tester.pumpWidget(
      interactionApp(
        _Host(
          onPressed: (context) =>
              result = showUndoToast(context, UndoableAction(label: 'تم الحذف', undo: () async => undos++)),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await pumpFrames(tester, 20);

    await tester.tap(find.text('تراجع'));
    await tester.pump();
    expect(undos, 1);
    expect(played, contains(Sfx.undo));
    expect(await result, isTrue);
    await pumpFrames(tester, 10);
    expect(find.text('تمّ التراجع'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('تمّ التراجع'), findsNothing);

    // A second tap is impossible once gone; undo ran exactly once.
    expect(undos, 1);
  });

  testWidgets('holding the toast pauses the countdown', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      interactionApp(
        _Host(
          onPressed: (context) => showUndoToast(context, UndoableAction(label: 'تم', undo: () async {})),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await pumpFrames(tester, 20);
    final gesture = await tester.startGesture(tester.getCenter(find.text('تم')));
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('تم'), findsOneWidget);
    await gesture.up();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('تم'), findsNothing);
  });

  testWidgets('toasts stack: the newest is in front and only it is interactive', (tester) async {
    usePhoneSurface(tester);
    final undone = <String>[];
    var n = 0;
    await tester.pumpWidget(
      interactionApp(
        _Host(
          onPressed: (context) {
            final label = 'عنصر ${++n}';
            showUndoToast(context, UndoableAction(label: label, undo: () async => undone.add(label)));
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await pumpFrames(tester, 10);
    await tester.tap(find.text('go'));
    await pumpFrames(tester, 30);
    expect(find.text('عنصر 1'), findsOneWidget);
    expect(find.text('عنصر 2'), findsOneWidget);
    // The front toast is the lowest on screen; the older one recedes above.
    expect(tester.getCenter(find.text('عنصر 2')).dy, greaterThan(tester.getCenter(find.text('عنصر 1')).dy));

    await tester.tap(find.text('تراجع').last, warnIfMissed: false);
    await tester.pump();
    await pumpFrames(tester, 5);
    expect(undone, ['عنصر 2']);
    await tester.pumpAndSettle();
  });

  testWidgets('dismissAll clears every toast with false', (tester) async {
    usePhoneSurface(tester);
    final results = <Future<bool>>[];
    late BuildContext ctx;
    await tester.pumpWidget(
      interactionApp(
        _Host(
          onPressed: (context) {
            ctx = context;
            results.add(showUndoToast(context, UndoableAction(label: 'أ', undo: () async {})));
            results.add(showUndoToast(context, UndoableAction(label: 'ب', undo: () async {})));
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await pumpFrames(tester, 10);
    UndoToast.dismissAll(Overlay.of(ctx, rootOverlay: true));
    await tester.pump();
    expect(find.text('أ'), findsNothing);
    expect(await Future.wait(results), [false, false]);
  });

  testWidgets('is announced as a live region with the Undo button as its own node', (tester) async {
    usePhoneSurface(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      interactionApp(
        _Host(
          onPressed: (context) => showUndoToast(context, UndoableAction(label: 'تم الحذف', undo: () async {})),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await pumpFrames(tester, 20);
    expect(
      tester.getSemantics(find.bySemanticsLabel('تم الحذف')),
      isSemantics(label: 'تم الحذف', isLiveRegion: true, hint: 'يمكنك التراجع خلال 5 ثوانٍ'),
    );
    expect(tester.getSemantics(find.bySemanticsLabel('تراجع')), isSemantics(isButton: true, hasTapAction: true));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    handle.dispose();
  });

  testWidgets('reduced motion still counts down and undoes', (tester) async {
    usePhoneSurface(tester);
    var undos = 0;
    await tester.pumpWidget(
      interactionApp(
        _Host(
          onPressed: (context) => showUndoToast(context, UndoableAction(label: 'تم', undo: () async => undos++)),
        ),
        reduced: true,
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('تم'), findsOneWidget);
    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();
    expect(undos, 1);
    expect(find.text('تم'), findsNothing);
  });
}
