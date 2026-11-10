import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/features/guide/guide.dart';

import '../../core/design/design_test_utils.dart';

/// A 360 x 640 phone, text scale [scale], in Arabic (RTL) or English (LTR).
Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  bool rtl = true,
  double scale = 1.3,
  bool reduced = true,
}) async {
  installRecordingFx();
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(360 * 3, 640 * 3);
  addTearDown(tester.view.reset);
  final locale = Locale(rtl ? 'ar' : 'en');
  await tester.pumpWidget(
    MaterialApp(
      theme: buildMadarTheme(MadarThemeId.lapis, arabic: rtl),
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      builder: (context, app) => MotionScope(
        reduced: reduced,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: app!,
        ),
      ),
      home: home,
    ),
  );
}

void main() {
  group('HelpButton and GuideSheet', () {
    Widget screen({String id = 'today', VoidCallback? replay}) => GuideScope.samples(
      child: Scaffold(
        appBar: AppBar(actions: [HelpButton(entryId: id, onReplayTour: replay)]),
        body: const SizedBox.expand(),
      ),
    );

    for (final rtl in [true, false]) {
      final dir = rtl ? 'RTL' : 'LTR';

      testWidgets('$dir at text scale 1.3: the button is 48 dp and opens the full sheet without overflow', (tester) async {
        await _pump(tester, screen(), rtl: rtl);
        expect(tester.getSize(find.byType(HelpButton)), const Size(48, 48));
        await tester.tap(find.byType(HelpButton));
        await tester.pumpAndSettle();
        final l = lookupL10n(Locale(rtl ? 'ar' : 'en'));
        for (final text in [
          l.guideTodayTitle,
          l.guideTodayPurpose,
          l.guideTodayExample,
          l.guideTodayDo1,
          l.guideTodayDo2,
          l.guideTodayDo3,
          l.guideSheetPurposeHeading,
          l.guideSheetExampleHeading,
          l.guideSheetDoHeading,
          l.guideSheetRelatedHeading,
          l.guideExpenseTitle,
          l.guideFaithTitle,
        ]) {
          expect(find.text(text), findsOneWidget, reason: text);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the glyph is «؟» in Arabic and ? in English', (tester) async {
      await _pump(tester, screen());
      expect(find.text('؟'), findsOneWidget);
      await _pump(tester, screen(), rtl: false);
      await tester.pumpAndSettle();
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('the help button has a screen-reader label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, screen());
      expect(find.bySemanticsLabel('شو هاي الشاشة؟'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a related link opens that entry in the same sheet, with a way back', (tester) async {
      await _pump(tester, screen());
      await tester.tap(find.byType(HelpButton));
      await tester.pumpAndSettle();
      final l = lookupL10n(const Locale('ar'));
      await tester.ensureVisible(find.text(l.guideExpenseTitle));
      await tester.tap(find.text(l.guideExpenseTitle));
      await tester.pumpAndSettle();
      expect(find.text(l.guideExpensePurpose), findsOneWidget);
      expect(find.text(l.guideTodayPurpose), findsNothing);
      expect(find.text(l.guideSheetBack), findsOneWidget);
      await tester.tap(find.text(l.guideSheetBack));
      await tester.pumpAndSettle();
      expect(find.text(l.guideTodayPurpose), findsOneWidget);
    });

    testWidgets('replay button: only with a tour and a callback; runs the callback after the sheet closes', (tester) async {
      final l = lookupL10n(const Locale('ar'));
      var replays = 0;
      await _pump(tester, screen(replay: () => replays++));
      await tester.tap(find.byType(HelpButton));
      await tester.pumpAndSettle();
      expect(find.text(l.guideReplayTour), findsOneWidget);
      await tester.tap(find.text(l.guideReplayTour));
      await tester.pumpAndSettle();
      expect(replays, 1);
      expect(find.text(l.guideTodayPurpose), findsNothing, reason: 'sheet closed');

      // No callback: no button. An entry without a tour: no button.
      await _pump(tester, screen());
      await tester.tap(find.byType(HelpButton));
      await tester.pumpAndSettle();
      expect(find.text(l.guideReplayTour), findsNothing);
      await tester.tapAt(const Offset(180, 20)); // the scrim
      await tester.pumpAndSettle();
      await _pump(tester, screen(id: 'planet.faith', replay: () => replays++));
      await tester.tap(find.byType(HelpButton));
      await tester.pumpAndSettle();
      expect(find.text(l.guideReplayTour), findsNothing);
    });

    testWidgets('an unknown entry id opens nothing', (tester) async {
      await _pump(tester, screen(id: 'nope'));
      await tester.tap(find.byType(HelpButton));
      await tester.pumpAndSettle();
      expect(find.byType(GuideSheet), findsNothing);
    });
  });

  group('coach tour overlay', () {
    const size = Size(48, 48);
    final keys = [GlobalKey(), GlobalKey(), GlobalKey()];
    final anchors = <Alignment>[Alignment.topLeft, Alignment.topRight, Alignment.bottomRight];

    Widget host({Alignment? corner, double? bottomInset}) => Material(
      child: Stack(
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              // Physical left/top on purpose: the corners are screen corners.
              left: (corner ?? anchors[i]).x < 0 ? 8 : null,
              right: (corner ?? anchors[i]).x > 0 ? 8 : null,
              top: (corner ?? anchors[i]).y < 0 ? 30 : null,
              bottom: (corner ?? anchors[i]).y > 0 ? 8 : null,
              child: SizedBox(key: keys[i], width: size.width, height: size.height),
            ),
        ],
      ),
    );

    List<CoachStep> steps() => [
      for (var i = 0; i < 3; i++)
        CoachStep(
          id: 's$i',
          title: 'عنوان الخطوة $i',
          body: 'شرح طويل نوعًا ما للخطوة رقم $i يوضح للمستخدم ما الذي يراه هنا وكيف يستعمله بسهولة.',
          target: keys[i],
        ),
    ];

    Finder bubbleLayout() => find.byWidgetPredicate((w) => w is CustomSingleChildLayout && '${w.delegate.runtimeType}' == '_BubbleLayout');

    Rect bubbleRect(WidgetTester tester) => tester.getRect(find.descendant(of: bubbleLayout(), matching: find.byType(Container)).first);

    for (final rtl in [true, false]) {
      final dir = rtl ? 'RTL' : 'LTR';
      testWidgets('$dir at text scale 1.3: every step stays on screen, off its target, no overflow', (tester) async {
        await _pump(tester, host(), rtl: rtl);
        final l = lookupL10n(Locale(rtl ? 'ar' : 'en'));
        late BuildContext context;
        context = tester.element(find.byType(Material).first);
        CoachTour.run(context, tourId: 'overlay-$dir', steps: steps(), store: MemoryGuideSeenStore());
        for (var i = 0; i < 3; i++) {
          await tester.pumpAndSettle();
          final bubble = bubbleRect(tester);
          final target = tester.getRect(find.byKey(keys[i])).inflate(6);
          expect(bubble.left, greaterThanOrEqualTo(0), reason: 'step $i');
          expect(bubble.right, lessThanOrEqualTo(360), reason: 'step $i');
          expect(bubble.top, greaterThanOrEqualTo(0), reason: 'step $i');
          expect(bubble.bottom, lessThanOrEqualTo(640), reason: 'step $i');
          expect(bubble.overlaps(target), isFalse, reason: 'step $i bubble $bubble target $target');
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(i == 2 ? l.guideTourDone : l.guideTourNext));
        }
        await tester.pumpAndSettle();
        expect(bubbleLayout(), findsNothing);
      });
    }

    testWidgets('under the keyboard: the bubble stays above it and off the target', (tester) async {
      await _pump(tester, host(corner: Alignment.bottomLeft), reduced: true);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
      addTearDown(tester.view.resetViewInsets);
      final context = tester.element(find.byType(Material).first);
      CoachTour.run(context, tourId: 'kb', steps: steps().take(1).toList(), store: MemoryGuideSeenStore());
      await tester.pumpAndSettle();
      // The target (bottom 8 dp) is behind the keyboard: centred bubble above it.
      final bubble = bubbleRect(tester);
      expect(bubble.bottom, lessThanOrEqualTo(640 - 300));
      expect(bubble.top, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the keyboard opening mid-step moves the bubble clear of it', (tester) async {
      await _pump(tester, host(corner: Alignment.bottomRight), reduced: true);
      final context = tester.element(find.byType(Material).first);
      CoachTour.run(context, tourId: 'kb2', steps: steps().take(1).toList(), store: MemoryGuideSeenStore());
      await tester.pumpAndSettle();
      expect(bubbleRect(tester).bottom, lessThan(640 - 8 - 48));
      tester.view.viewInsets = const FakeViewPadding(bottom: 200 * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(bubbleRect(tester).bottom, lessThanOrEqualTo(640 - 200));
    });

    testWidgets('TalkBack: the bubble is one focusable live region and the buttons are reachable', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, host());
      final context = tester.element(find.byType(Material).first);
      CoachTour.run(context, tourId: 'a11y', steps: steps(), store: MemoryGuideSeenStore());
      await tester.pumpAndSettle();
      final bubble = find.bySemanticsLabel(RegExp('^جولة سريعة'));
      expect(bubble, findsOneWidget);
      expect(tester.getSemantics(bubble), isSemantics(isLiveRegion: true, isFocusable: true));
      expect(find.bySemanticsLabel('التالي'), findsOneWidget);
      expect(find.bySemanticsLabel('تخطّي'), findsOneWidget);
      // The next step announces itself (new label), not the old one.
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('عنوان الخطوة 1')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('عنوان الخطوة 0')), findsNothing);
      handle.dispose();
    });

    testWidgets('reduced motion: no animation is left running after a step change', (tester) async {
      await _pump(tester, host(), reduced: true);
      final context = tester.element(find.byType(Material).first);
      CoachTour.run(context, tourId: 'rm', steps: steps(), store: MemoryGuideSeenStore());
      await tester.pumpAndSettle();
      await tester.tap(find.text('التالي'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('motion on: the spotlight glides to the next target', (tester) async {
      await _pump(tester, host(), reduced: false);
      final context = tester.element(find.byType(Material).first);
      CoachTour.run(context, tourId: 'mo', steps: steps(), store: MemoryGuideSeenStore());
      await tester.pumpAndSettle();
      await tester.tap(find.text('التالي'));
      await tester.pump();
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));
      await tester.pumpAndSettle();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });
  });

  group('EmptyStateCard', () {
    for (final rtl in [true, false]) {
      testWidgets('${rtl ? 'RTL' : 'LTR'} at 1.3: art, one sentence and the first action', (tester) async {
        var tapped = 0;
        await _pump(
          tester,
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyStateCard(
                art: const Icon(Icons.savings_outlined, size: 96),
                message: rtl ? 'ما في مصاريف لسّه. سجّل أول مبلغ دفعته وبتشوفه هون.' : 'No spending yet. Record the first amount you paid and it shows here.',
                actionLabel: rtl ? 'أضف مصروف' : 'Add an expense',
                actionIcon: Icons.add_rounded,
                onAction: () => tapped++,
              ),
            ),
          ),
          rtl: rtl,
        );
        expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
        await tester.tap(find.text(rtl ? 'أضف مصروف' : 'Add an expense'));
        expect(tapped, 1);
        expect(tester.takeException(), isNull);
        final button = tester.getSize(find.text(rtl ? 'أضف مصروف' : 'Add an expense'));
        expect(button.height, greaterThan(0));
      });
    }
  });
}
