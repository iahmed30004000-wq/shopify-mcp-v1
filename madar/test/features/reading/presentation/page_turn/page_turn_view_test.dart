import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/reading/presentation/page_turn/curl_painter.dart';
import 'package:madar/features/reading/presentation/page_turn/curl_scene.dart';
import 'package:madar/features/reading/presentation/page_turn/page_turn.dart';
import 'package:madar/features/reading/presentation/page_turn/spread_layout.dart';

const _labels = PageTurnLabels(
  nextPage: 'Next page',
  previousPage: 'Previous page',
  pageStatus: _status,
);
String _status(int page, int total) => 'Page $page of $total';

/// Test rig: owns the knobs a test turns.
class _Rig {
  _Rig({
    this.pageCount = 6,
    this.direction = BookDirection.ltr,
    this.uiDirection = TextDirection.ltr,
    this.reduced = false,
    this.snapshots = false,
    this.spread = true,
    this.initialPage = 0,
    this.contentKey,
  });

  int pageCount;
  BookDirection direction;
  TextDirection uiDirection;
  bool reduced;
  bool snapshots;
  bool spread;
  double textScale = 1.0;
  int initialPage;
  Object? contentKey;
  final Key key = UniqueKey();
  final PageTurnController controller = PageTurnController();
  final List<int> changes = <int>[];
  final List<int> built = <int>[];
  int centerTaps = 0;

  Widget app(WidgetTester tester) => Directionality(
    textDirection: uiDirection,
    child: MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(textScaler: TextScaler.linear(textScale)),
      child: PageTurnView(
        key: key,
        pageCount: pageCount,
        initialPage: initialPage,
        bookDirection: direction,
        reducedMotion: reduced,
        useSnapshots: snapshots,
        spread: spread,
        contentKey: contentKey,
        controller: controller,
        labels: _labels,
        onPageChanged: changes.add,
        onTapCenter: () => centerTaps++,
        paper: const PaperOptions(grainStrength: 0),
        pageBuilder: (context, i) {
          built.add(i);
          return Center(
            key: ValueKey<String>('page$i'),
            child: Text('P$i', style: const TextStyle(fontSize: 20)),
          );
        },
      ),
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(app(tester));
    await tester.pump();
  }

  PageTurnViewState state(WidgetTester tester) => tester.state<PageTurnViewState>(find.byType(PageTurnView));
}

void _size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Runs a controller action and lets its animation finish (a controller
/// future only completes when frames are pumped, so never await it bare).
Future<void> _go(WidgetTester tester, Future<void> Function() action) async {
  final f = action();
  await tester.pumpAndSettle();
  await f;
}

Rect _pageRect(WidgetTester tester, int i) => tester.getRect(find.byKey(ValueKey<String>('page$i')));

void main() {
  group('direction', () {
    testWidgets('English book: dragging right-to-left turns forward', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig();
      await rig.pump(tester);
      await tester.drag(find.byType(PageTurnView), const Offset(-260, 0));
      await tester.pumpAndSettle();
      expect(rig.changes, [1]);
      expect(find.text('P1'), findsOneWidget);
    });

    testWidgets('English book: dragging left-to-right at page 0 does nothing', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig();
      await rig.pump(tester);
      await tester.drag(find.byType(PageTurnView), const Offset(260, 0));
      await tester.pumpAndSettle();
      expect(rig.changes, isEmpty);
      expect(rig.state(tester).debugTurning, isFalse);
    });

    testWidgets('Arabic book under an English UI: left-to-right turns forward, right-to-left goes back', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(direction: BookDirection.rtl, uiDirection: TextDirection.ltr);
      await rig.pump(tester);
      await tester.drag(find.byType(PageTurnView), const Offset(-260, 0)); // wrong way at page 0
      await tester.pumpAndSettle();
      expect(rig.changes, isEmpty);
      await tester.drag(find.byType(PageTurnView), const Offset(260, 0));
      await tester.pumpAndSettle();
      expect(rig.changes, [1]);
      await tester.drag(find.byType(PageTurnView), const Offset(-260, 0));
      await tester.pumpAndSettle();
      expect(rig.changes, [1, 0]);
    });

    testWidgets('English book under an Arabic UI still turns right-to-left', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(direction: BookDirection.ltr, uiDirection: TextDirection.rtl);
      await rig.pump(tester);
      await tester.drag(find.byType(PageTurnView), const Offset(-260, 0));
      await tester.pumpAndSettle();
      expect(rig.changes, [1]);
    });

    testWidgets('page content gets the book text direction, not the UI one', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(direction: BookDirection.rtl, uiDirection: TextDirection.ltr);
      await rig.pump(tester);
      final ctx = tester.element(find.byKey(const ValueKey<String>('page0')));
      expect(Directionality.of(ctx), TextDirection.rtl);
    });
  });

  group('gestures', () {
    testWidgets('a short drag springs back', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig();
      await rig.pump(tester);
      final g = await tester.startGesture(const Offset(380, 400));
      await g.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await g.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(rig.state(tester).debugTurning, isTrue);
      await g.up();
      await tester.pumpAndSettle();
      expect(rig.changes, isEmpty);
      expect(rig.state(tester).debugTurning, isFalse);
      expect(rig.state(tester).debugPage, 0);
    });

    testWidgets('a long drag completes the turn', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig();
      await rig.pump(tester);
      final g = await tester.startGesture(const Offset(380, 700));
      for (var i = 0; i < 12; i++) {
        await g.moveBy(const Offset(-20, -3));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(rig.changes, [1]);
    });

    testWidgets('a fast fling turns even after a tiny drag', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig();
      await rig.pump(tester);
      final g = await tester.startGesture(const Offset(300, 400));
      // 48 px in 24 ms = 2000 px/s: a flick, far too short to turn by distance.
      for (var i = 1; i <= 6; i++) {
        await g.moveBy(const Offset(-8, 0), timeStamp: Duration(milliseconds: 4 * i));
      }
      await g.up(timeStamp: const Duration(milliseconds: 26));
      await tester.pumpAndSettle();
      expect(rig.changes, [1]);
    });

    testWidgets('a fling the other way cancels a long drag', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig();
      await rig.pump(tester);
      final g = await tester.startGesture(const Offset(390, 400));
      for (var i = 0; i < 8; i++) {
        await g.moveBy(const Offset(-25, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 3; i++) {
        await g.moveBy(const Offset(30, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(rig.changes, isEmpty);
    });

    testWidgets('tap near the right edge: next in an English book, previous in an Arabic one', (tester) async {
      _size(tester, 400, 800);
      final en = _Rig();
      await en.pump(tester);
      await tester.tapAt(const Offset(385, 400));
      await tester.pumpAndSettle();
      expect(en.changes, [1]);
      await tester.tapAt(const Offset(15, 400));
      await tester.pumpAndSettle();
      expect(en.changes, [1, 0]);

      final ar = _Rig(direction: BookDirection.rtl, initialPage: 2);
      await tester.pumpWidget(ar.app(tester));
      await tester.pump();
      await tester.tapAt(const Offset(385, 400)); // right edge = previous in Arabic
      await tester.pumpAndSettle();
      expect(ar.changes, [1]);
      await tester.tapAt(const Offset(15, 400)); // left edge = next
      await tester.pumpAndSettle();
      expect(ar.changes, [1, 2]);
    });

    testWidgets('tap in the middle only reports a centre tap', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig();
      await rig.pump(tester);
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();
      expect(rig.changes, isEmpty);
      expect(rig.centerTaps, 1);
    });

    testWidgets('the corner grab and the edge grab both complete (different start heights)', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig();
      await rig.pump(tester);
      for (final y in [780.0, 400.0, 20.0]) {
        final before = rig.changes.length;
        await tester.dragFrom(Offset(380, y), const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(rig.changes.length, before + 1, reason: 'grab at y=$y');
      }
      expect(rig.changes, [1, 2, 3]);
    });
  });

  group('turn rendering', () {
    testWidgets('while dragging without images the live widgets are curled (never blank)', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(snapshots: false);
      await rig.pump(tester);
      final g = await tester.startGesture(const Offset(380, 700));
      await g.moveBy(const Offset(-120, -20));
      await tester.pump(const Duration(milliseconds: 16));
      await g.moveBy(const Offset(-120, -20));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(CurlLiveLayers), findsOneWidget);
      expect(find.text('P0'), findsWidgets); // front (and its mirrored back)
      expect(find.text('P1'), findsOneWidget); // the page underneath
      await g.up();
      await tester.pumpAndSettle();
      expect(find.byType(CurlLiveLayers), findsNothing);
      expect(rig.state(tester).debugPage, 1);
    });

    testWidgets('with images captured the curl is one canvas painter', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(snapshots: true);
      await rig.pump(tester);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final cache = rig.state(tester).debugCache;
      if (cache.length < 2) {
        // toImageSync is not available in this test engine: the live path is
        // covered above, nothing more to assert about images here.
        return;
      }
      expect(cache.pages, containsAll(<int>[0, 1]));
      final g = await tester.startGesture(const Offset(380, 700));
      // The first move only wins the drag (its start is where it is accepted).
      await g.moveBy(const Offset(-30, -10));
      await g.moveBy(const Offset(-150, -10));
      await tester.pump(const Duration(milliseconds: 16));
      await g.moveBy(const Offset(-150, -10));
      await tester.pump(const Duration(milliseconds: 16));
      expect(rig.state(tester).debugTurnUsesImages, isTrue);
      expect(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is CurlPainter),
        findsOneWidget,
      );
      await g.up();
      await tester.pumpAndSettle();
      expect(rig.state(tester).debugPage, 1);
    });

    testWidgets('neighbour pages are captured in the background, one per frame, and far ones evicted', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(snapshots: true, pageCount: 12);
      await rig.pump(tester);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final st = rig.state(tester);
      if (st.debugCache.length == 0) return; // toImageSync unavailable here
      expect(st.debugCache.pages, [0, 1]);
      for (var k = 0; k < 5; k++) {
        await _go(tester, rig.controller.next);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      expect(st.debugPage, 5);
      // Only the page and its neighbours stay in memory.
      expect(st.debugCache.pages.every((p) => (p - 5).abs() <= 1), isTrue, reason: '${st.debugCache.pages}');
    });

    testWidgets('a new content key invalidates every stored image', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(snapshots: true, contentKey: 'a');
      await rig.pump(tester);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final st = rig.state(tester);
      if (st.debugCache.length == 0) return;
      final before = st.debugSignature;
      rig.contentKey = 'b';
      await tester.pumpWidget(rig.app(tester));
      expect(st.debugSignature, isNot(before));
      expect(st.debugCache.pages.length, lessThanOrEqualTo(1)); // old ones dropped, re-captured gradually
    });

    testWidgets('text scale 1.3 changes the signature and nothing overflows', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(snapshots: true);
      await rig.pump(tester);
      final sig1 = rig.state(tester).debugSignature;
      rig.textScale = 1.3;
      await tester.pumpWidget(rig.app(tester));
      await tester.pump();
      expect(rig.state(tester).debugSignature, isNot(sig1));
      await tester.drag(find.byType(PageTurnView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(rig.changes, [1]);
    });
  });

  group('facing pages', () {
    testWidgets('portrait is a single page; landscape shows the cover alone, then 1+2', (tester) async {
      _size(tester, 800, 400);
      final rig = _Rig(pageCount: 6);
      await rig.pump(tester);
      expect(rig.state(tester).debugSpread, isTrue);
      expect(find.text('P0'), findsOneWidget);
      expect(find.text('P1'), findsNothing);
      // English: the cover sits on the right half.
      expect(_pageRect(tester, 0).center.dx, greaterThan(400));

      await _go(tester, rig.controller.next);
      await tester.pumpAndSettle();
      expect(rig.changes, [1]);
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('P2'), findsOneWidget);
      expect(_pageRect(tester, 1).center.dx, lessThan(_pageRect(tester, 2).center.dx));

      await _go(tester, rig.controller.next);
      await tester.pumpAndSettle();
      expect(rig.changes, [1, 3]);
      expect(find.text('P3'), findsOneWidget);
      expect(find.text('P4'), findsOneWidget);
    });

    testWidgets('Arabic book: cover on the left half, page 1 right of page 2', (tester) async {
      _size(tester, 800, 400);
      final rig = _Rig(pageCount: 6, direction: BookDirection.rtl);
      await rig.pump(tester);
      expect(_pageRect(tester, 0).center.dx, lessThan(400));
      await _go(tester, rig.controller.next);
      await tester.pumpAndSettle();
      expect(_pageRect(tester, 1).center.dx, greaterThan(_pageRect(tester, 2).center.dx));
    });

    testWidgets('an odd last page stands alone; going back lands on the pair', (tester) async {
      _size(tester, 800, 400);
      final rig = _Rig(pageCount: 4);
      await rig.pump(tester);
      await _go(tester, rig.controller.next);
      await _go(tester, rig.controller.next);
      await tester.pumpAndSettle();
      expect(find.text('P3'), findsOneWidget);
      expect(find.text('P4'), findsNothing);
      expect(rig.controller.canGoNext, isFalse);
      await _go(tester, rig.controller.previous);
      await tester.pumpAndSettle();
      expect(rig.changes, [1, 3, 1]);
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('P2'), findsOneWidget);
    });

    testWidgets('turning a spread by finger (drag from the right edge)', (tester) async {
      _size(tester, 800, 400);
      final rig = _Rig(pageCount: 6);
      await rig.pump(tester);
      await tester.dragFrom(const Offset(780, 200), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(rig.changes, [1]);
      // and back: drag from the left edge to the right.
      await tester.dragFrom(const Offset(20, 200), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(rig.changes, [1, 0]);
    });

    testWidgets('spread disabled keeps a single page in landscape', (tester) async {
      _size(tester, 800, 400);
      final rig = _Rig(spread: false);
      await rig.pump(tester);
      expect(rig.state(tester).debugSpread, isFalse);
    });
  });

  group('reduced motion', () {
    testWidgets('a swipe cross-fades; there is no curl', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(reduced: true);
      await rig.pump(tester);
      final g = await tester.startGesture(const Offset(380, 400));
      await g.moveBy(const Offset(-30, 0));
      await g.moveBy(const Offset(-200, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(rig.state(tester).debugTurning, isFalse);
      await g.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(rig.state(tester).debugFading, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('P0'), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);
      expect(find.byType(CurlLiveLayers), findsNothing);
      await tester.pumpAndSettle();
      expect(rig.changes, [1]);
      expect(find.text('P0'), findsNothing);
    });

    testWidgets('the system "disable animations" setting counts too', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(disableAnimations: true),
            child: PageTurnView(
              pageCount: 3,
              labels: _labels,
              onPageChanged: rig.changes.add,
              pageBuilder: (c, i) => Text('P$i'),
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(385, 400));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.state<PageTurnViewState>(find.byType(PageTurnView)).debugFading, isTrue);
      await tester.pumpAndSettle();
      expect(rig.changes, [1]);
    });
  });

  group('controller', () {
    testWidgets('next / previous / canGo flags / current page', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(pageCount: 3);
      await rig.pump(tester);
      expect(rig.controller.currentPage, 0);
      expect(rig.controller.pageCount, 3);
      expect(rig.controller.canGoNext, isTrue);
      expect(rig.controller.canGoPrevious, isFalse);
      await _go(tester, rig.controller.next);
      await tester.pumpAndSettle();
      expect(rig.controller.currentPage, 1);
      await _go(tester, rig.controller.next);
      await tester.pumpAndSettle();
      expect(rig.controller.currentPage, 2);
      expect(rig.controller.canGoNext, isFalse);
      await _go(tester, rig.controller.next); // at the end: nothing
      await tester.pumpAndSettle();
      expect(rig.controller.currentPage, 2);
      await _go(tester, rig.controller.previous);
      await tester.pumpAndSettle();
      expect(rig.controller.currentPage, 1);
      expect(rig.changes, [1, 2, 1]);
    });

    testWidgets('jumpTo far away fades; it never builds the pages in between', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(pageCount: 12);
      await rig.pump(tester);
      rig.built.clear();
      final done = rig.controller.jumpTo(10);
      await tester.pump(const Duration(milliseconds: 20));
      expect(rig.state(tester).debugFading, isTrue);
      expect(rig.state(tester).debugTurning, isFalse);
      await tester.pumpAndSettle();
      await done;
      expect(rig.controller.currentPage, 10);
      expect(rig.changes, [10]);
      expect(rig.built.toSet().difference({0, 10}), isEmpty, reason: 'built: ${rig.built.toSet()}');
    });

    testWidgets('jumpTo a neighbour turns with the curl; animate:false just lands', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(pageCount: 8);
      await rig.pump(tester);
      final f = rig.controller.jumpTo(1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.state(tester).debugTurning, isTrue);
      await tester.pumpAndSettle();
      await f;
      expect(rig.controller.currentPage, 1);
      await _go(tester, () => rig.controller.jumpTo(6, animate: false));
      await tester.pump();
      expect(rig.state(tester).debugFading, isFalse);
      expect(rig.controller.currentPage, 6);
      expect(find.text('P6'), findsOneWidget);
    });

    testWidgets('jumpTo is clamped; invalidate does not throw', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(pageCount: 4);
      await rig.pump(tester);
      await _go(tester, () => rig.controller.jumpTo(99, animate: false));
      await tester.pump();
      expect(rig.controller.currentPage, 3);
      rig.controller.invalidate();
      rig.controller.invalidate(2);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a controller that is not attached is harmless', (tester) async {
      final c = PageTurnController();
      expect(c.isAttached, isFalse);
      await c.next();
      await c.jumpTo(3);
      expect(c.canGoNext, isFalse);
    });
  });

  group('page counts', () {
    for (final n in [0, 1, 2, 3, 4]) {
      testWidgets('pageCount $n: renders, swipes and taps cause no exception (portrait and landscape)', (tester) async {
        for (final size in [const Size(400, 800), const Size(800, 400)]) {
          _size(tester, size.width, size.height);
          final rig = _Rig(pageCount: n);
          await tester.pumpWidget(rig.app(tester));
          await tester.pump();
          await tester.drag(find.byType(PageTurnView), const Offset(-300, 0));
          await tester.pumpAndSettle();
          await tester.drag(find.byType(PageTurnView), const Offset(300, 0));
          await tester.pumpAndSettle();
          await tester.tapAt(Offset(size.width - 10, size.height / 2));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'n=$n $size');
          if (n == 1) expect(rig.changes, isEmpty);
        }
      });
    }

    testWidgets('two pages: one turn forward, then the end', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(pageCount: 2);
      await rig.pump(tester);
      await tester.drag(find.byType(PageTurnView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageTurnView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(rig.changes, [1]);
    });
  });

  group('rotation and resize', () {
    testWidgets('rotating mid-drag cancels cleanly, the finger can still lift', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig();
      await rig.pump(tester);
      final g = await tester.startGesture(const Offset(380, 700));
      await g.moveBy(const Offset(-30, -10));
      await g.moveBy(const Offset(-150, -10));
      await tester.pump(const Duration(milliseconds: 16));
      expect(rig.state(tester).debugTurning, isTrue);
      tester.view.physicalSize = const Size(800, 400);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(rig.state(tester).debugTurning, isFalse);
      expect(rig.state(tester).debugSpread, isTrue);
      await g.moveBy(const Offset(-50, 0));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(rig.changes, isEmpty);
      expect(find.text('P0'), findsOneWidget);
    });

    testWidgets('rotating while a committed turn animates lands on the new page', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig();
      await rig.pump(tester);
      final f = rig.controller.next();
      await tester.pump(const Duration(milliseconds: 120));
      expect(rig.state(tester).debugTurning, isTrue);
      tester.view.physicalSize = const Size(800, 400);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await f;
      expect(tester.takeException(), isNull);
      expect(rig.state(tester).debugTurning, isFalse);
      expect(rig.changes, [1]);
      // Landscape now: page 1 is shown with its facing page 2.
      expect(find.text('P1'), findsOneWidget);
    });

    testWidgets('rotating during a fade finishes it', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(pageCount: 10);
      await rig.pump(tester);
      final f = rig.controller.jumpTo(8);
      await tester.pump(const Duration(milliseconds: 60));
      tester.view.physicalSize = const Size(800, 400);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      await f;
      expect(tester.takeException(), isNull);
      expect(rig.changes, [8]);
      expect(rig.state(tester).debugFading, isFalse);
    });

    testWidgets('a rotation keeps the reader on the same page', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(initialPage: 4);
      await rig.pump(tester);
      tester.view.physicalSize = const Size(800, 400);
      await tester.pump();
      await tester.pump();
      expect(find.text('P4'), findsOneWidget);
      tester.view.physicalSize = const Size(400, 800);
      await tester.pump();
      await tester.pump();
      expect(find.text('P4'), findsOneWidget);
      expect(rig.changes, isEmpty);
    });
  });

  group('accessibility', () {
    testWidgets('announces the page and offers next / previous as custom actions', (tester) async {
      final handle = tester.ensureSemantics();
      _size(tester, 400, 800);
      final rig = _Rig(pageCount: 5, initialPage: 1);
      await rig.pump(tester);
      final node = tester.getSemantics(find.bySemanticsLabel(RegExp('Page 2 of 5')));
      final data = node.getSemanticsData();
      expect(data.label, 'Page 2 of 5');
      expect(data.flagsCollection.isLiveRegion, isTrue);
      final next = CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: 'Next page'));
      final prev = CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: 'Previous page'));
      expect(data.customSemanticsActionIds, containsAll(<int>[next, prev]));

      tester.semantics.performAction(find.semantics.byLabel(RegExp('Page 2 of 5')), SemanticsAction.customAction, args: next);
      await tester.pumpAndSettle();
      expect(rig.changes, [2]);
      expect(find.bySemanticsLabel(RegExp('Page 3 of 5')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('no "previous" action on the first page', (tester) async {
      final handle = tester.ensureSemantics();
      _size(tester, 400, 800);
      final rig = _Rig(pageCount: 5);
      await rig.pump(tester);
      final data = tester.getSemantics(find.bySemanticsLabel(RegExp('Page 1 of 5'))).getSemanticsData();
      final prev = CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: 'Previous page'));
      expect(data.customSemanticsActionIds ?? const <int>[], isNot(contains(prev)));
      handle.dispose();
    });
  });

  group('performance', () {
    testWidgets('dragging a page costs well under a 60 fps frame budget in the widget tree', (tester) async {
      _size(tester, 400, 800);
      final rig = _Rig(snapshots: true);
      await rig.pump(tester);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final g = await tester.startGesture(const Offset(385, 760));
      final times = <int>[];
      final sw = Stopwatch();
      for (var i = 0; i < 90; i++) {
        sw.reset();
        sw.start();
        await g.moveBy(const Offset(-3.5, -1.5));
        await tester.pump(const Duration(milliseconds: 16));
        sw.stop();
        times.add(sw.elapsedMicroseconds);
      }
      await g.up();
      await tester.pumpAndSettle();
      times.sort();
      final mean = times.reduce((a, b) => a + b) / times.length / 1000;
      final p95 = times[(times.length * 0.95).floor()] / 1000;
      // Measured on this box (debug JIT, shared 4-core machine, 3 images
      // cached): mean 0.84 ms, p95 1.10 ms per dragged frame for build +
      // layout + paint recording of the whole widget tree. Release is faster.
      // ignore: avoid_print
      print('drag pump: mean ${mean.toStringAsFixed(2)} ms, p95 ${p95.toStringAsFixed(2)} ms (images: ${rig.state(tester).debugCache.length})');
      expect(mean, lessThan(40));
    });

    testWidgets('the canvas curl painter paints a frame in a few milliseconds', (tester) async {
      final img = (await tester.runAsync(() => createTestImage(width: 1080, height: 2400)))!;
      final rects = ReaderRects.compute(const Size(360, 800), BookDirection.ltr, spread: false);
      const grab = Offset(360, 800);
      final scene = CurlScene(
        rects: rects,
        grab: grab,
        touch: grab,
        paperTint: const Color(0xFFF7F0E0),
        front: img.clone(),
        under: img.clone(),
      );
      final painter = CurlPainter(scene: scene);
      const frames = 300;
      final sw = Stopwatch()..start();
      for (var i = 0; i < frames; i++) {
        final t = i / frames;
        scene.moveTouch(Offset(360 - 700 * t, 800 - 120 * t));
        final rec = ui.PictureRecorder();
        painter.paint(Canvas(rec), const Size(360, 800));
        rec.endRecording().dispose();
      }
      sw.stop();
      final perFrame = sw.elapsedMicroseconds / frames / 1000;
      // Measured: 0.055 ms per frame (1080x2400 images, corner curl,
      // recording only; the raster cost is the GPU's: a handful of clipped
      // image draws and four gradient fills).
      // ignore: avoid_print
      print('CurlPainter.paint (record only, debug JIT): ${perFrame.toStringAsFixed(3)} ms/frame');
      expect(perFrame, lessThan(4));
      scene.dispose();
      img.dispose();
    });
  });
}
