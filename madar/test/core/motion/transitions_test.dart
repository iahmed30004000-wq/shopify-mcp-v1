import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/core/motion/transitions.dart';
import 'package:madar/core/sound/sound_api.dart';

import 'motion_test_utils.dart';

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: GestureDetector(
        onTap: () => setState(() => taps++),
        child: SizedBox(width: 200, height: 60, child: Center(child: Text('home $taps'))),
      ),
    ),
  );
}

Widget _page(String label) => Scaffold(
  body: Center(child: SizedBox(width: 200, child: Text(label))),
);

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          MadarTransitions.fadeThrough(context: context, key: state.pageKey, child: const _Home()),
      routes: [
        GoRoute(
          path: 'fade',
          pageBuilder: (context, state) =>
              MadarTransitions.fadeThrough(context: context, key: state.pageKey, child: _page('fade page')),
        ),
        GoRoute(
          path: 'axis',
          pageBuilder: (context, state) =>
              MadarTransitions.sharedAxis(context: context, key: state.pageKey, child: _page('axis page')),
        ),
        GoRoute(
          path: 'vertical',
          pageBuilder: (context, state) => MadarTransitions.sharedAxis(
            context: context,
            key: state.pageKey,
            axis: MadarSharedAxis.vertical,
            child: _page('vertical page'),
          ),
        ),
        GoRoute(
          path: 'scaled',
          pageBuilder: (context, state) => MadarTransitions.sharedAxis(
            context: context,
            key: state.pageKey,
            axis: MadarSharedAxis.scaled,
            child: _page('scaled page'),
          ),
        ),
        GoRoute(
          path: 'cosmic',
          pageBuilder: (context, state) => MadarTransitions.cosmicZoom(
            context: context,
            key: state.pageKey,
            originRect: const Rect.fromLTWH(40, 80, 60, 60),
            child: _page('cosmic page'),
          ),
        ),
        GoRoute(
          path: 'sheet',
          pageBuilder: (context, state) => MadarTransitions.sheetRise(
            context: context,
            key: state.pageKey,
            child: Align(
              alignment: AlignmentDirectional.bottomCenter,
              child: SizedBox(height: 240, child: _page('sheet page')),
            ),
          ),
        ),
      ],
    ),
  ],
);

Widget _app(GoRouter router, {TextDirection direction = TextDirection.ltr, bool reduced = false}) => MaterialApp.router(
  theme: buildMadarTheme(MadarThemeId.lapis, arabic: direction == TextDirection.rtl),
  routerConfig: router,
  builder: (context, child) => MotionScope(
    reduced: reduced,
    child: Directionality(textDirection: direction, child: child!),
  ),
);

void main() {
  group('page factories', () {
    testWidgets('produce CustomTransitionPages with the motion durations', (tester) async {
      late List<CustomTransitionPage<void>> pages;
      late List<CustomTransitionPage<void>> reducedPages;
      List<CustomTransitionPage<void>> build(BuildContext c) => [
        MadarTransitions.fadeThrough(context: c, child: const SizedBox()),
        MadarTransitions.sharedAxis(context: c, child: const SizedBox()),
        MadarTransitions.sharedAxis(context: c, axis: MadarSharedAxis.vertical, child: const SizedBox()),
        MadarTransitions.cosmicZoom(context: c, origin: const Offset(10, 10), child: const SizedBox()),
        MadarTransitions.sheetRise(context: c, child: const SizedBox()),
      ];
      await tester.pumpWidget(
        motionApp(
          Builder(
            builder: (c) {
              pages = build(c);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        motionApp(
          reduced: true,
          Builder(
            builder: (c) {
              reducedPages = build(c);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(pages, everyElement(isA<MadarTransitionPage<void>>()));
      expect(pages[0].transitionDuration, MadarMotion.medium);
      expect(pages[3].transitionDuration, MadarMotion.cinematic);
      expect(pages[3].transitionDuration, lessThan(const Duration(milliseconds: 800)));
      expect(pages[4].opaque, isFalse);
      expect(pages[4].barrierDismissible, isTrue);
      expect(pages[4].barrierColor, isNotNull);
      for (final p in reducedPages) {
        expect(p.transitionDuration, MadarMotion.reduced);
        expect(p.reverseTransitionDuration, MadarMotion.reduced);
      }
    });
  });

  group('go_router navigation', () {
    for (final route in ['fade', 'axis', 'vertical', 'scaled', 'cosmic', 'sheet']) {
      for (final reduced in [false, true]) {
        testWidgets('push & pop /$route${reduced ? ' (reduced)' : ''} keeps the home page state', (tester) async {
          final router = _router();
          await tester.pumpWidget(_app(router, reduced: reduced));
          await tester.tap(find.text('home 0'));
          await tester.pump();
          expect(find.text('home 1'), findsOneWidget);

          router.go('/$route');
          await tester.pump();
          await pumpFrames(tester, 8);
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();
          expect(find.text('$route page'), findsOneWidget);

          router.pop();
          await tester.pump();
          await pumpFrames(tester, 8);
          await tester.pumpAndSettle();
          expect(find.text('$route page'), findsNothing);
          expect(find.text('home 1'), findsOneWidget, reason: 'state survived the round trip');
        });
      }
    }

    for (final dir in TextDirection.values) {
      testWidgets('shared axis follows the reading direction ($dir)', (tester) async {
        final router = _router();
        await tester.pumpWidget(_app(router, direction: dir));
        router.go('/axis');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        final mid = tester.getCenter(find.text('axis page'));
        await tester.pumpAndSettle();
        final end = tester.getCenter(find.text('axis page'));
        if (dir == TextDirection.ltr) {
          expect(mid.dx, greaterThan(end.dx), reason: 'LTR: arrives from the right');
        } else {
          expect(mid.dx, lessThan(end.dx), reason: 'RTL: arrives from the left');
        }
      });
    }

    testWidgets('sheet: the page below recedes, barrier dismisses', (tester) async {
      final router = _router();
      await tester.pumpWidget(_app(router));
      final before = tester.getRect(find.text('home 0'));
      router.go('/sheet');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final during = tester.getRect(find.text('home 0'));
      expect(during.width, lessThan(before.width));
      await tester.pumpAndSettle();
      expect(find.text('sheet page'), findsOneWidget);
      expect(find.text('home 0'), findsOneWidget, reason: 'non-opaque: the page below stays painted');

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('sheet page'), findsNothing);
      expect(tester.getRect(find.text('home 0')), before);
    });

    testWidgets('cosmic zoom: circular reveal with blur, the cosmos flies forward', (tester) async {
      final router = _router();
      await tester.pumpWidget(_app(router));
      final before = tester.getRect(find.text('home 0'));
      router.go('/cosmic');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final clips = tester.widgetList<ClipOval>(find.byType(ClipOval));
      expect(clips.any((c) => c.clipBehavior != Clip.none), isTrue);
      expect(tester.widgetList<ImageFiltered>(find.byType(ImageFiltered)).any((f) => f.enabled), isTrue);
      final during = tester.getRect(find.text('home 0'));
      expect(during.width, greaterThan(before.width));
      await tester.pumpAndSettle();
      expect(tester.widgetList<ClipOval>(find.byType(ClipOval)).every((c) => c.clipBehavior == Clip.none), isTrue);
      expect(tester.widgetList<ImageFiltered>(find.byType(ImageFiltered)).every((f) => !f.enabled), isTrue);
    });

    testWidgets('reduced motion: pages below stay still', (tester) async {
      final router = _router();
      await tester.pumpWidget(_app(router, reduced: true));
      final before = tester.getRect(find.text('home 0'));
      router.go('/sheet');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getRect(find.text('home 0')), before);
      await tester.pumpAndSettle();
    });
  });

  group('MadarPageTransitionsBuilder', () {
    testWidgets('drives MaterialPageRoutes', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          theme: buildMadarTheme(MadarThemeId.lapis, arabic: false).copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {TargetPlatform.android: MadarPageTransitionsBuilder(axis: MadarSharedAxis.horizontal)},
            ),
          ),
          home: const Scaffold(body: Text('root')),
        ),
      );
      navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('next'))));
      await tester.pump();
      await pumpFrames(tester, 5);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
    });
  });

  group('MadarOpenContainer', () {
    testWidgets('opens with feedback and closes with a result', (tester) async {
      final fx = installMotionFx();
      String? result;
      await tester.pumpWidget(
        motionApp(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: MadarOpenContainer<String>(
                  onClosed: (v) => result = v,
                  closedBuilder: (context, open) => const Center(child: Text('card')),
                  openBuilder: (context, close) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => close(returnValue: 'done'),
                        child: const Text('close'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('card'));
      await tester.pump();
      await pumpFrames(tester, 10);
      await tester.pumpAndSettle();
      expect(find.text('close'), findsOneWidget);
      expect(fx.sound.played, contains(Sfx.navigate));

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      expect(find.text('card'), findsOneWidget);
      expect(result, 'done');
    });
  });
}
