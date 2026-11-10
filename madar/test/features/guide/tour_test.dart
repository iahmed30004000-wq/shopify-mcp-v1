import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/guide/guide.dart';

import '../../core/design/design_test_utils.dart';

void main() {
  group('TourState sequencing', () {
    test('next walks to the end, the last next completes', () {
      var s = const TourState(3);
      expect(s.isFirst, isTrue);
      s = s.next();
      expect((s.index, s.isRunning), (1, true));
      s = s.next();
      expect(s.isLast, isTrue);
      expect(s.isRunning, isTrue);
      s = s.next();
      expect(s.outcome, TourOutcome.completed);
      expect(s.index, 2);
      expect(s.next(), s, reason: 'a finished tour stays finished');
    });

    test('back goes one step, never before the first', () {
      var s = const TourState(4).next().next();
      s = s.back();
      expect(s.index, 1);
      expect(const TourState(4).back().index, 0);
    });

    test('skip ends the tour at any step, and stays ended', () {
      final s = const TourState(4).next().skip();
      expect(s.outcome, TourOutcome.skipped);
      expect(s.next(), s);
      expect(s.back(), s);
    });

    test('a one-bubble tour completes on next', () {
      expect(const TourState(1).next().outcome, TourOutcome.completed);
    });
  });

  group('TourGate', () {
    test('runs until it is marked seen; reset lets it run again', () async {
      final gate = TourGate(MemoryGuideSeenStore());
      expect(await gate.shouldRun('today'), isTrue);
      await gate.markSeen('today');
      expect(await gate.shouldRun('today'), isFalse);
      expect(await gate.shouldRun('map'), isTrue);
      await gate.reset('today');
      expect(await gate.shouldRun('today'), isTrue);
    });

    test('does not collide with other seen ids', () async {
      final store = MemoryGuideSeenStore(['today']);
      expect(await TourGate(store).shouldRun('today'), isTrue);
    });
  });

  group('CoachTour.run', () {
    final keys = [GlobalKey(debugLabel: 'a'), GlobalKey(debugLabel: 'b'), GlobalKey(debugLabel: 'c')];
    late MemoryGuideSeenStore store;
    late BuildContext hostContext;

    List<CoachStep> steps([int n = 3]) => [
      for (var i = 0; i < n; i++) CoachStep(id: 's$i', title: 'العنوان $i', body: 'الشرح $i', target: keys[i]),
    ];

    Future<void> pumpHost(WidgetTester tester) async {
      installRecordingFx();
      store = MemoryGuideSeenStore();
      await pumpMadar(
        tester,
        Builder(
          builder: (context) {
            hostContext = context;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) SizedBox(key: keys[i], width: 80, height: 48, child: Text('target $i')),
              ],
            );
          },
        ),
        reducedMotion: true,
      );
    }

    testWidgets('shows the steps in order; next, back, then done marks it seen', (tester) async {
      await pumpHost(tester);
      TourOutcome? result;
      var finished = false;
      CoachTour.run(hostContext, tourId: 'today', steps: steps(), store: store).then((o) {
        result = o;
        finished = true;
      });
      await tester.pumpAndSettle();
      expect(find.text('العنوان 0'), findsOneWidget);
      expect(find.text('السابق'), findsNothing);

      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('العنوان 1'), findsOneWidget);
      await tester.tap(find.text('السابق'));
      await tester.pumpAndSettle();
      expect(find.text('العنوان 0'), findsOneWidget);
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('العنوان 2'), findsOneWidget);
      expect(find.text('تخطّي'), findsNothing, reason: 'the last step only has done');

      await tester.tap(find.text('تمام، خلصنا'));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(result, TourOutcome.completed);
      expect(find.text('العنوان 2'), findsNothing);
      expect(await TourGate(store).shouldRun('today'), isFalse);
    });

    testWidgets('skip ends it at once and counts as seen', (tester) async {
      await pumpHost(tester);
      TourOutcome? result;
      CoachTour.run(hostContext, tourId: 'today', steps: steps(), store: store).then((o) => result = o);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تخطّي'));
      await tester.pumpAndSettle();
      expect(result, TourOutcome.skipped);
      expect(find.text('العنوان 0'), findsNothing);
      expect(await TourGate(store).shouldRun('today'), isFalse);
    });

    testWidgets('the system back button skips', (tester) async {
      await pumpHost(tester);
      TourOutcome? result;
      CoachTour.run(hostContext, tourId: 'today', steps: steps(), store: store).then((o) => result = o);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(result, TourOutcome.skipped);
    });

    testWidgets('runs once per tourId; a replay ignores that', (tester) async {
      await pumpHost(tester);
      CoachTour.run(hostContext, tourId: 'today', steps: steps(), store: store);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تخطّي'));
      await tester.pumpAndSettle();

      TourOutcome? second = TourOutcome.completed;
      var done = false;
      CoachTour.run(hostContext, tourId: 'today', steps: steps(), store: store).then((o) {
        second = o;
        done = true;
      });
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(second, isNull, reason: 'already seen: it does not open');
      expect(find.text('العنوان 0'), findsNothing);

      CoachTour.run(hostContext, tourId: 'today', steps: steps(), store: store, replay: true);
      await tester.pumpAndSettle();
      expect(find.text('العنوان 0'), findsOneWidget);
      await tester.tap(find.text('تخطّي'));
      await tester.pumpAndSettle();
    });

    testWidgets('a different tour still runs; the same tour cannot open twice at once', (tester) async {
      await pumpHost(tester);
      CoachTour.run(hostContext, tourId: 'a', steps: steps(), store: store);
      await tester.pumpAndSettle();
      var again = false;
      CoachTour.run(hostContext, tourId: 'a', steps: steps(), store: store, replay: true).then((o) => again = o == null);
      await tester.pumpAndSettle();
      expect(again, isTrue);
      expect(find.text('العنوان 0'), findsOneWidget);
      await tester.tap(find.text('تخطّي'));
      await tester.pumpAndSettle();
    });

    testWidgets('no steps: nothing opens and nothing is marked', (tester) async {
      await pumpHost(tester);
      final r = await CoachTour.run(hostContext, tourId: 'x', steps: const [], store: store);
      expect(r, isNull);
      expect(await TourGate(store).shouldRun('x'), isTrue);
    });

    testWidgets('a target that is not on screen shows a centred bubble, no error', (tester) async {
      await pumpHost(tester);
      final ghost = GlobalKey();
      CoachTour.run(
        hostContext,
        tourId: 'ghost',
        steps: [CoachStep(id: 'g', title: 'بلا هدف', body: 'نص', target: ghost)],
        store: store,
      );
      await tester.pumpAndSettle();
      expect(find.text('بلا هدف'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('تمام، خلصنا'));
      await tester.pumpAndSettle();
    });
  });
}
