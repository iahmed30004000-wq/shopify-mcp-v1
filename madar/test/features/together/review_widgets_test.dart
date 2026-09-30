// Adversarial review of Together Mode on screen (hand-off gate, split-screen
// arena): each test reproduced a defect before its fix, or guards a property
// the review checked.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/widgets/widgets.dart' show GlassCard;
import 'package:madar/features/together/together.dart';

import 'split_touch_harness.dart';
import '../../helpers/screenshot_harness.dart' show loadMadarFonts;
import 'together_test_utils.dart';

const _secret = ValueKey('secret-hand');
const _reveal = ValueKey('together-reveal');

/// A pass-and-play table where tapping anywhere plays a move (and passes the
/// phone): a real table has its cards at the bottom, where the big reveal
/// button of the next hand-off screen appears.
class _TapToPlayTable extends StatelessWidget {
  const _TapToPlayTable(this.controller);

  final HandOffController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: HandOffGate(
      controller: controller,
      profileOf: (p) => TogetherProfile.defaults(p == 0 ? PlayerSlot.one : PlayerSlot.two),
      privateBuilder: (context, p) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.passTo(1 - p),
        child: Center(child: Text('hand of $p', key: _secret)),
      ),
    ),
  );
}

/// Counts taps; its state must survive layout changes of the arena.
class _Counter extends StatefulWidget {
  const _Counter(this.participant);

  final int participant;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => taps++),
    child: Center(child: Text('p${widget.participant}:$taps')),
  );
}

/// Opens [open] once the first frame is up (nothing has read the Together
/// providers before).
class _OpenOnStart extends StatefulWidget {
  const _OpenOnStart(this.open);

  final Future<void> Function(BuildContext context) open;

  @override
  State<_OpenOnStart> createState() => _OpenOnStartState();
}

class _OpenOnStartState extends State<_OpenOnStart> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

void main() {
  testWidgets('the profile editor opened before the profiles loaded edits the stored profile, never the defaults', (
    tester,
  ) async {
    final env = await pumpTogetherApp(
      tester,
      locale: const Locale('en'),
      home: _OpenOnStart((c) => showTogetherProfileSheet(c, PlayerSlot.two)),
      seed: (repo) => repo.saveProfile(
        TogetherProfile.defaults(PlayerSlot.two).copyWith(
          name: 'Nova',
          avatar: const TogetherAvatar.emoji('🌙'),
          colorIndex: 5,
          customTitle: 'Card Queen',
        ),
      ),
    );
    final field = tester.widget<TextField>(find.byKey(const ValueKey('together-name-field')));
    expect(field.controller!.text, 'Nova');
    // Opening the editor does not jump to the custom title with the keyboard up.
    final title = tester.widget<EditableText>(
      find.descendant(of: find.byKey(const ValueKey('together-title-field')), matching: find.byType(EditableText)),
    );
    expect(title.controller.text, 'Card Queen');
    expect(title.focusNode.hasFocus, isFalse);
    await tester.tap(find.text('Save'));
    await settleTogether(tester);
    final stored = (await tester.runAsync(() => env.repo.profiles()))!.two;
    expect(stored.name, 'Nova');
    expect(stored.avatar, const TogetherAvatar.emoji('🌙'));
    expect(stored.colorIndex, 5);
    expect(stored.customTitle, 'Card Queen');
  });

  testWidgets('Arabic never puts a middle dot beside Arabic-Indic digits (it reads as a zero)', (tester) async {
    await pumpTogetherApp(tester, home: const TogetherHomeScreen(animateBackdrop: false), seed: seedTogetherHistory);
    final seen = <String>{};
    for (var i = 0; i < 6; i++) {
      for (final e in find.byType(RichText).evaluate()) {
        seen.add((e.widget as RichText).text.toPlainText());
      }
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(seen.where((t) => t.contains('·')), isEmpty);
    expect(seen.where((t) => t.contains('، ')), isNotEmpty);
  });

  group('hand-off', () {
    testWidgets('a quick second tap after playing never reveals the next player\'s hand', (tester) async {
      final controller = HandOffController()..passTo(0);
      addTearDown(controller.dispose);
      await pumpTogetherApp(tester, home: _TapToPlayTable(controller));
      final at = tester.getCenter(find.byKey(_reveal));
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(find.text('hand of 0'), findsOneWidget);

      // Player 1 plays with a tap right where the reveal button will be,
      // and taps once more out of habit (a double tap, 150 ms apart).
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(_reveal), findsOneWidget);
      await tester.tapAt(at);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.phase, HandOffPhase.handOff);
      expect(find.byKey(_secret, skipOffstage: false), findsNothing);

      // The next player, holding the phone, reveals with a deliberate tap.
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_reveal));
      await tester.pumpAndSettle();
      expect(find.text('hand of 1'), findsOneWidget);
    });

    testWidgets('a finger already down when the hand-off appears cannot reveal on lift', (tester) async {
      final controller = HandOffController()..passTo(0);
      addTearDown(controller.dispose);
      await pumpTogetherApp(tester, home: _TapToPlayTable(controller));
      final at = tester.getCenter(find.byKey(_reveal));
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      // The move is made by a remote event while player 1's finger rests on
      // the screen; it lifts long after the hand-off screen is up.
      final finger = await tester.startGesture(at);
      controller.passTo(1);
      await tester.pump(const Duration(seconds: 2));
      await finger.up();
      await tester.pumpAndSettle();
      expect(controller.phase, HandOffPhase.handOff);
      expect(find.byKey(_secret, skipOffstage: false), findsNothing);
    });

    testWidgets('a sheet or dialog opened from a hand closes – without an exit animation – when the phone is passed', (
      tester,
    ) async {
      final controller = HandOffController()..passTo(0);
      addTearDown(controller.dispose);
      await pumpTogetherApp(
        tester,
        home: Scaffold(
          body: HandOffGate(
            controller: controller,
            profileOf: (p) => TogetherProfile.defaults(p == 0 ? PlayerSlot.one : PlayerSlot.two),
            privateBuilder: (context, p) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    key: const ValueKey('open-sheet'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => SizedBox(height: 200, child: Text('card detail of $p')),
                    ),
                    child: const Text('sheet'),
                  ),
                  TextButton(
                    key: const ValueKey('open-dialog'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(content: Text('answer of $p')),
                    ),
                    child: const Text('dialog'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(_reveal));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-sheet')));
      await tester.pumpAndSettle();
      expect(find.text('card detail of 0'), findsOneWidget);
      // A timer (or the other device) passes the turn while the sheet is open.
      controller.passTo(1);
      await tester.pump();
      expect(find.text('card detail of 0', skipOffstage: false), findsNothing);
      expect(find.byType(HandOffScreen), findsOneWidget);
      await tester.pumpAndSettle();

      // Leaving the app with a dialog open: it is gone when the app returns.
      await tester.tap(find.byKey(_reveal));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-dialog')));
      await tester.pumpAndSettle();
      expect(find.text('answer of 1'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('answer of 1', skipOffstage: false), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.textContaining('هل ما زلت'), findsOneWidget);
    });

    testWidgets('before the reveal, nothing private reaches the semantics tree (TalkBack)', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = HandOffController()..passTo(1);
      addTearDown(controller.dispose);
      await pumpTogetherApp(tester, home: _TapToPlayTable(controller));
      expect(find.bySemanticsLabel(RegExp('hand of')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('اللاعب ٢')), findsWidgets);
      semantics.dispose();
    });
  });

  group('split screen', () {
    Future<List<SplitTouch>> pumpArena(
      WidgetTester tester, {
      required Widget Function(BuildContext context, SplitHalf half) halfBuilder,
      ValueNotifier<SplitLayout>? layout,
      Size size = const Size(412, 915),
      Locale locale = const Locale('en'),
      List<Color>? colors,
    }) async {
      final touches = <SplitTouch>[];
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final l = layout ?? ValueNotifier(SplitLayout.faceToFace);
      final (app, _) = await buildTogetherApp(
        tester,
        locale: locale,
        home: Scaffold(
          body: ValueListenableBuilder<SplitLayout>(
            valueListenable: l,
            builder: (context, v, _) =>
                SplitScreenArena(layout: v, onTouch: touches.add, colors: colors, halfBuilder: halfBuilder),
          ),
        ),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      return touches;
    }

    testWidgets('six fingers at once, three per half: every one tracked by its own half', (tester) async {
      final pans = <int, List<String>>{0: [], 1: []};
      final live = <int, SplitTouches>{};
      final touches = await pumpArena(
        tester,
        halfBuilder: (context, half) {
          live[half.participant] = SplitScreenArena.touchesOf(context);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => pans[half.participant]!.add('start'),
            onScaleEnd: (_) => pans[half.participant]!.add('end'),
          );
        },
      );
      final harness = SplitTouchHarness(tester);
      await harness.simultaneousDrags([
        for (final p in [0, 1])
          for (final x in [0.2, 0.5, 0.8]) SplitPath(p, Offset(x, 0.8), Offset(x, 0.3)),
      ]);
      for (final p in [0, 1]) {
        final mine = touches.where((t) => t.participant == p);
        expect(mine.where((t) => t.phase == SplitTouchPhase.down).length, 3, reason: 'half $p');
        expect(mine.where((t) => t.phase == SplitTouchPhase.up).length, 3, reason: 'half $p');
        expect(pans[p], containsAllInOrder(['start', 'end']), reason: 'half $p');
        expect(live[p]!.isTouched, isFalse);
      }
      // Each half saw its own fingers move "up" in its own frame.
      final far = touches.where((t) => t.participant == 1 && t.phase == SplitTouchPhase.move).last;
      expect(far.normalized.dy, closeTo(0.3, 0.03));
    });

    testWidgets('one player holding a long-press does not starve the other player\'s taps', (tester) async {
      final log = <String>[];
      await pumpArena(
        tester,
        halfBuilder: (context, half) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => log.add('long${half.participant}'),
          onTap: () => log.add('tap${half.participant}'),
        ),
      );
      final harness = SplitTouchHarness(tester);
      final hold = await tester.startGesture(harness.globalIn(0, const Offset(0.5, 0.5)), pointer: 41);
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 3; i++) {
        await tester.tapAt(harness.globalIn(1, const Offset(0.5, 0.5)), pointer: 50 + i);
        await tester.pump(const Duration(milliseconds: 120));
      }
      await tester.pump(const Duration(milliseconds: 600));
      await hold.up();
      await tester.pump();
      expect(log.where((e) => e == 'tap1'), hasLength(3));
      expect(log, contains('long0'));
      expect(log, isNot(contains('tap0')));
    });

    testWidgets('Arabic stays right-to-left inside the upside-down half, and taps land after rotation', (tester) async {
      final log = <String>[];
      await pumpArena(
        tester,
        locale: const Locale('ar'),
        halfBuilder: (context, half) => Column(
          children: [
            Row(
              children: [
                Text('أول', key: ValueKey('first-${half.participant}')),
                const Spacer(),
                Text('أخير', key: ValueKey('last-${half.participant}')),
              ],
            ),
            Expanded(
              child: GestureDetector(
                key: ValueKey('pad-${half.participant}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => log.add('pad${half.participant}'),
              ),
            ),
          ],
        ),
      );
      // Near half: RTL – the first child at the physical right.
      expect(tester.getCenter(find.byKey(const ValueKey('first-0'))).dx, greaterThan(300));
      // Far half (turned 180°): still RTL in its own frame – its right is the
      // device's left, and its top row is at the device's middle.
      final first1 = tester.getCenter(find.byKey(const ValueKey('first-1')));
      expect(first1.dx, lessThan(100));
      expect(first1.dy, greaterThan(400));
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('pad-1'))));
      expect(log, ['pad1']);
    });

    testWidgets('changing the layout (the phone turned) keeps each half\'s own state', (tester) async {
      final layout = ValueNotifier(SplitLayout.faceToFace);
      addTearDown(layout.dispose);
      await pumpArena(tester, layout: layout, halfBuilder: (context, half) => _Counter(half.participant));
      final harness = SplitTouchHarness(tester);
      await tester.tapAt(harness.globalIn(0, const Offset(0.5, 0.5)));
      await tester.tapAt(harness.globalIn(0, const Offset(0.5, 0.5)));
      await tester.tapAt(harness.globalIn(1, const Offset(0.5, 0.5)));
      await tester.pump();
      expect(find.text('p0:2'), findsOneWidget);
      expect(find.text('p1:1'), findsOneWidget);
      layout.value = SplitLayout.sideBySide;
      await tester.pumpAndSettle();
      expect(find.text('p0:2'), findsOneWidget);
      expect(find.text('p1:1'), findsOneWidget);
    });

    testWidgets('system gesture areas are turned into each half\'s frame too', (tester) async {
      tester.view.systemGestureInsets = const FakeViewPadding(left: 60, right: 60);
      final seen = <int, EdgeInsets>{};
      await pumpArena(
        tester,
        size: const Size(915, 412),
        layout: ValueNotifier(SplitLayout.endToEnd),
        halfBuilder: (context, half) {
          seen[half.participant] = MediaQuery.systemGestureInsetsOf(context);
          return const SizedBox.expand();
        },
      );
      // Physical left edge = the left player's bottom; the midline has none.
      expect(seen[0], const EdgeInsets.only(bottom: 30));
      expect(seen[1], const EdgeInsets.only(bottom: 30));
    });

    testWidgets('the midline shows each player\'s colour on their own side', (tester) async {
      const red = Color(0xFFFF0000);
      const blue = Color(0xFF0000FF);
      await pumpArena(
        tester,
        size: const Size(915, 412),
        layout: ValueNotifier(SplitLayout.sideBySide),
        colors: const [red, blue],
        halfBuilder: (context, half) => const SizedBox.expand(),
      );
      // LTR: player 0 on the left.
      final paint = tester.widget<CustomPaint>(
        find.descendant(of: find.byType(SplitScreenArena), matching: find.byType(CustomPaint)).last,
      );
      final rec = ui.PictureRecorder();
      paint.painter!.paint(Canvas(rec), const Size(400, 10));
      final image = (await tester.runAsync(() => rec.endRecording().toImage(400, 10)))!;
      final bytes = (await tester.runAsync(() => image.toByteData()))!;
      Color at(int x) {
        final i = (5 * 400 + x) * 4;
        return Color.fromARGB(255, bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
      }

      image.dispose();
      final left = at(2);
      final right = at(397);
      expect((left.r * 255).round(), greaterThan(200), reason: 'left edge is player 0 (red): $left');
      expect((right.b * 255).round(), greaterThan(200), reason: 'right edge is player 1 (blue): $right');
    });
  });

  // Last: these load the real fonts (the test font's square glyphs say
  // nothing about what fits), which then stay loaded in this isolate.
  group('text scale 1.3 (English, the longest texts)', () {
    setUpAll(loadMadarFonts);

    /// Texts under [scope] that are cut: vertically clipped, or truncated
    /// to their maxLines.
    List<String> cutTexts(WidgetTester tester, Finder scope) => [
      for (final e in find.descendant(of: scope, matching: find.byType(RichText)).evaluate())
        if (e.renderObject case final RenderParagraph p
            when p.didExceedMaxLines || p.size.height + 0.5 < p.getMinIntrinsicHeight(p.size.width))
          p.text.toPlainText(),
    ];

    testWidgets('Hall of Fame: every trophy name and description is shown whole', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTogetherApp(
        tester,
        locale: const Locale('en'),
        home: const HallOfFameScreen(animateBackdrop: false),
        seed: seedTogetherHistory,
      );
      final cut = <String>{};
      for (var i = 0; i < 8; i++) {
        cut.addAll(cutTexts(tester, find.byType(GlassCard)));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(cut, isEmpty);
    });

    testWidgets('launch sheet: the play modes are named in full', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTogetherApp(
        tester,
        locale: const Locale('en'),
        home: _OpenOnStart((c) => showGameLaunchSheet(c, game: TogetherGames.airHockey)),
      );
      expect(cutTexts(tester, find.byType(PlayModeCard)).where((t) => t.startsWith('Two phones')), isEmpty);
    });

    testWidgets('home shelf: the dates under the trophies never run into each other', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTogetherApp(
        tester,
        locale: const Locale('en'),
        home: const TogetherHomeScreen(animateBackdrop: false),
        seed: seedTogetherHistory,
      );
      final shelf = find.byKey(const ValueKey('together-shelf'));
      final dates = [
        for (final e in find.descendant(of: shelf, matching: find.textContaining('September')).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ]..sort((a, b) => a.left.compareTo(b.left));
      expect(dates.length, greaterThan(2));
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].left - dates[i - 1].right, greaterThanOrEqualTo(6), reason: 'gap before date $i');
      }
    });
  });
}
