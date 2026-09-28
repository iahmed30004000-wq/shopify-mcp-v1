import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/sound/sound_api.dart';

import '../design_test_utils.dart';

double _scaleOf(WidgetTester tester, Finder within) {
  final st = tester.widget<ScaleTransition>(find.descendant(of: within, matching: find.byType(ScaleTransition)).first);
  return st.scale.value;
}

void main() {
  late ({SilentSoundService sound, RecordingHaptics haptics}) fx;
  setUp(() => fx = installRecordingFx());

  group('MadarButton', () {
    testWidgets('tap fires onPressed and Sfx.tap with its synced haptic', (tester) async {
      var taps = 0;
      await pumpMadar(tester, MadarButton(label: 'OK', onPressed: () => taps++));
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);
      expect(fx.sound.played, [Sfx.tap]);
      expect(fx.haptics.fired, [Haptic.selection]);
    });

    testWidgets('unmounting mid-press is safe', (tester) async {
      await pumpMadar(tester, MadarButton(label: 'OK', onPressed: () {}));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(MadarButton)));
      await tester.pump(const Duration(milliseconds: 50));
      await pumpMadar(tester, const SizedBox());
      await gesture.up();
      expect(tester.takeException(), isNull);
    });

    testWidgets('press springs to pressScale and back', (tester) async {
      await pumpMadar(tester, MadarButton(label: 'OK', onPressed: () {}));
      final button = find.byType(MadarButton);
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(_scaleOf(tester, button), closeTo(0.965, 0.01));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(_scaleOf(tester, button), closeTo(1, 0.005));
    });

    testWidgets('a quick tap inside a scrollable still shows its press', (tester) async {
      await pumpMadar(
        tester,
        ListView(
          children: [
            MadarButton(label: 'OK', onPressed: () {}),
            GlassCard(onTap: () {}, onLongPress: () {}, child: const SizedBox(height: 60, child: Text('card'))),
          ],
        ),
      );
      for (final target in [find.byType(MadarButton), find.byType(GlassCard)]) {
        final gesture = await tester.startGesture(tester.getCenter(target));
        var lowest = 1.0;
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          lowest = lowest < _scaleOf(tester, target) ? lowest : _scaleOf(tester, target);
        }
        await gesture.up(); // a 64 ms tap – shorter than kPressTimeout
        expect(lowest, lessThan(0.995), reason: '$target');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        expect(_scaleOf(tester, target), closeTo(1, 0.005));
      }
      expect(fx.sound.played, [Sfx.tap, Sfx.tap]);
    });

    testWidgets('dragging a list from a button is not a press', (tester) async {
      await pumpMadar(
        tester,
        ListView(
          children: [
            MadarButton(label: 'OK', onPressed: () {}),
            const SizedBox(height: 2000),
          ],
        ),
      );
      final button = find.byType(MadarButton);
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 600));
      expect(_scaleOf(tester, button), closeTo(1, 0.01));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fx.sound.played, isEmpty);
    });

    testWidgets('reduced motion: no press scale', (tester) async {
      await pumpMadar(tester, MadarButton(label: 'OK', onPressed: () {}), reducedMotion: true);
      final button = find.byType(MadarButton);
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(_scaleOf(tester, button), 1);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('disabled button is silent and inert', (tester) async {
      await pumpMadar(tester, const MadarButton(label: 'OK', onPressed: null));
      await tester.tap(find.text('OK'), warnIfMissed: false);
      await tester.pump();
      expect(fx.sound.played, isEmpty);
      expect(
        tester.getSemantics(find.byType(MadarButton)),
        isSemantics(isButton: true, label: 'OK', isEnabled: false, hasTapAction: false),
      );
    });

    testWidgets('loading shows the orbit loader, keeps size and ignores taps', (tester) async {
      var taps = 0;
      await pumpMadar(tester, MadarButton(label: 'Save', onPressed: () => taps++));
      final idleSize = tester.getSize(find.byType(MadarButton));
      await pumpMadar(tester, MadarButton(label: 'Save', loading: true, onPressed: () => taps++));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(OrbitLoader), findsOneWidget);
      expect(tester.getSize(find.byType(MadarButton)), idleSize);
      await tester.tap(find.byType(MadarButton));
      await tester.pump(const Duration(milliseconds: 100));
      expect(taps, 0);
      expect(fx.sound.played, isEmpty);
    });

    testWidgets('text button hugs its label; expand fills the width', (tester) async {
      await pumpMadar(tester, MadarButton(label: 'OK', onPressed: () {}));
      expect(tester.getSize(find.byType(MadarButton)).width, lessThan(200));
      await pumpMadar(
        tester,
        SizedBox(
          width: 300,
          child: MadarButton(label: 'OK', expand: true, onPressed: () {}),
        ),
      );
      expect(tester.getSize(find.byType(MadarButton)).width, 300);
    });

    testWidgets('icon button is round and labelled for screen readers', (tester) async {
      await pumpMadar(tester, MadarButton.icon(icon: Icons.add_rounded, semanticLabel: 'Add', onPressed: () {}));
      final size = tester.getSize(find.byType(MadarButton));
      expect(size.width, size.height);
      expect(find.bySemanticsLabel('Add'), findsOneWidget);
    });

    testWidgets('custom sfx', (tester) async {
      await pumpMadar(
        tester,
        MadarButton(label: 'Del', sfx: Sfx.delete, variant: MadarButtonVariant.danger, onPressed: () {}),
      );
      await tester.tap(find.text('Del'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(fx.sound.played, [Sfx.delete]);
    });
  });

  group('Chips & pills', () {
    testWidgets('MadarChip reports the requested state', (tester) async {
      bool? requested;
      await pumpMadar(tester, MadarChip(label: 'Fajr', selected: false, onSelected: (v) => requested = v));
      await tester.tap(find.text('Fajr'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(requested, isTrue);
      expect(fx.sound.played, [Sfx.tap]);
    });

    testWidgets('single-select pills', (tester) async {
      String? value = 'a';
      await pumpMadar(
        tester,
        StatefulBuilder(
          builder: (context, set) => ChoicePills<String>.single(
            options: const [
              ChoiceOption(value: 'a', label: 'A'),
              ChoiceOption(value: 'b', label: 'B'),
            ],
            selected: value,
            onChanged: (v) => set(() => value = v),
          ),
        ),
      );
      await tester.tap(find.text('B'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(value, 'b');
      // Tapping the selected option again is a no-op (no deselect).
      await tester.tap(find.text('B'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(value, 'b');
      expect(fx.sound.played, [Sfx.tap]);
      expect(
        tester.getSemantics(find.byType(MadarChip).last),
        isSemantics(
          isButton: true,
          label: 'B',
          isSelected: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
    });

    testWidgets('multi-select pills toggle with toggleOn/Off and reject past max', (tester) async {
      var values = <int>{1};
      await pumpMadar(
        tester,
        StatefulBuilder(
          builder: (context, set) => ChoicePills<int>.multi(
            maxSelected: 2,
            options: const [
              ChoiceOption(value: 1, label: 'one'),
              ChoiceOption(value: 2, label: 'two'),
              ChoiceOption(value: 3, label: 'three'),
            ],
            selected: values,
            onChanged: (v) => set(() => values = v),
          ),
        ),
      );
      await tester.tap(find.text('two'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(values, {1, 2});
      await tester.tap(find.text('three'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(values, {1, 2}, reason: 'max 2');
      await tester.tap(find.text('one'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(values, {2});
      expect(fx.sound.played, [Sfx.toggleOn, Sfx.error, Sfx.toggleOff]);
    });
  });

  group('MadarSwitch', () {
    Widget host(ValueChanged<bool> onChanged, {bool initial = false}) {
      var value = initial;
      return StatefulBuilder(
        builder: (context, set) => MadarSwitch(
          value: value,
          semanticLabel: 'Sound',
          onChanged: (v) {
            onChanged(v);
            set(() => value = v);
          },
        ),
      );
    }

    testWidgets('tap toggles with synced sounds', (tester) async {
      final changes = <bool>[];
      await pumpMadar(tester, host(changes.add));
      await tester.tap(find.byType(MadarSwitch));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byType(MadarSwitch));
      await tester.pump(const Duration(milliseconds: 500));
      expect(changes, [true, false]);
      expect(fx.sound.played, [Sfx.toggleOn, Sfx.toggleOff]);
    });

    for (final dir in TextDirection.values) {
      testWidgets('drag toward the reading end turns it on (${dir.name})', (tester) async {
        final changes = <bool>[];
        await pumpMadar(tester, host(changes.add), direction: dir);
        final toEnd = dir == TextDirection.ltr ? 30.0 : -30.0;
        await tester.drag(find.byType(MadarSwitch), Offset(toEnd, 0));
        await tester.pump(const Duration(milliseconds: 500));
        expect(changes, [true]);
        await tester.drag(find.byType(MadarSwitch), Offset(toEnd, 0));
        await tester.pump(const Duration(milliseconds: 500));
        expect(changes, [true], reason: 'already on');
      });
    }

    testWidgets('exposes toggled semantics; disabled is inert', (tester) async {
      await pumpMadar(tester, MadarSwitch(value: true, semanticLabel: 'Sound', onChanged: (_) {}));
      expect(
        tester.getSemantics(find.byType(MadarSwitch)),
        isSemantics(
          label: 'Sound',
          hasToggledState: true,
          isToggled: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
      await pumpMadar(tester, const MadarSwitch(value: false, onChanged: null));
      await tester.tap(find.byType(MadarSwitch));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fx.sound.played, isEmpty);
    });
  });

  group('Surfaces', () {
    testWidgets('GlassPanel uses exactly one BackdropFilter, GlassCard none', (tester) async {
      await pumpMadar(tester, const GlassPanel(child: Text('panel')));
      expect(find.descendant(of: find.byType(GlassPanel), matching: find.byType(BackdropFilter)), findsOneWidget);
      await pumpMadar(tester, const GlassCard(child: Text('card')));
      expect(find.descendant(of: find.byType(GlassCard), matching: find.byType(BackdropFilter)), findsNothing);
    });

    testWidgets('tappable GlassCard presses and plays Sfx.tap', (tester) async {
      var taps = 0;
      await pumpMadar(tester, GlassCard(onTap: () => taps++, semanticLabel: 'Row', child: const Text('row')));
      await tester.tap(find.text('row'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);
      expect(fx.sound.played, [Sfx.tap]);
      expect(find.bySemanticsLabel('Row'), findsOneWidget);
    });

    testWidgets('stretched card lays content across its full width', (tester) async {
      await pumpMadar(
        tester,
        const SizedBox(
          width: 300,
          child: GlassCard(padding: EdgeInsets.zero, child: SizedBox(height: 10)),
        ),
      );
      expect(tester.getSize(find.byType(GlassCard)).width, 300);
    });
  });

  group('Indicators', () {
    testWidgets('ProgressRing reports a clamped percentage', (tester) async {
      await pumpMadar(tester, const ProgressRing(value: 0.724, semanticLabel: 'Goal'));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getSemantics(find.byType(ProgressRing)), matchesSemantics(label: 'Goal', value: '72%'));
      await pumpMadar(tester, const ProgressRing(value: 3, semanticLabel: 'Goal'));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getSemantics(find.byType(ProgressRing)), matchesSemantics(label: 'Goal', value: '100%'));
    });

    testWidgets('OrbitLoader is announced as loading (localised)', (tester) async {
      await pumpMadar(tester, const OrbitLoader());
      expect(find.bySemanticsLabel('جارٍ التحميل'), findsOneWidget);
      await pumpMadar(tester, const OrbitLoader(), locale: const Locale('en'));
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });

    testWidgets('StatTile shows its value and reads as one node', (tester) async {
      var taps = 0;
      await pumpMadar(
        tester,
        SizedBox(
          width: 180,
          child: StatTile(label: 'Steps', value: '8,420', trend: StatTrend.up, trendLabel: '+12%', onTap: () => taps++),
        ),
      );
      expect(find.text('8,420'), findsOneWidget);
      expect(find.bySemanticsLabel('Steps, 8,420, +12%'), findsOneWidget);
      await tester.tap(find.byType(StatTile));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);
    });
  });

  group('Layout pieces', () {
    testWidgets('SectionHeader title is a header; action fires', (tester) async {
      var taps = 0;
      await pumpMadar(tester, SectionHeader(title: 'Stats', actionLabel: 'See all', onAction: () => taps++));
      expect(tester.getSemantics(find.text('Stats')), matchesSemantics(label: 'Stats', isHeader: true));
      await tester.tap(find.text('See all'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);
    });

    testWidgets('dividers and ornaments are decorative', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpMadar(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [MadarDivider(), IslamicStar(), GirihRosette(size: 60), AstrolabeRing(size: 60), ArabesqueBorder()],
        ),
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('MadarScaffold: back button pops, plays Sfx.back, mirrors in RTL', (tester) async {
      await pumpMadar(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MadarScaffold(title: 'Details', body: SizedBox()),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Details'), findsOneWidget);
      final back = find.bySemanticsLabel('رجوع');
      expect(back, findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_back_rounded));
      expect(icon.icon!.matchTextDirection, isTrue);
      expect(Directionality.of(tester.element(find.byIcon(Icons.arrow_back_rounded))), TextDirection.rtl);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Details'), findsNothing);
      expect(fx.sound.played, [Sfx.back]);
    });

    testWidgets('MadarScaffold without a route below shows no back button', (tester) async {
      await pumpMadar(tester, const MadarScaffold(title: 'Home', body: SizedBox()), scaffold: false);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('CosmosBackdrop', () {
    setUp(() => AmbientMotion.debugOverride = true);
    tearDown(() => AmbientMotion.debugOverride = null);

    testWidgets('animates while visible (on the shared ambient clock)', (tester) async {
      await pumpMadar(tester, const CosmosBackdrop(), scaffold: false);
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((c) => c.painter)
          .whereType<CosmosBackdropPainter>()
          .single;
      final t0 = painter.time.value;
      await tester.pump(const Duration(milliseconds: 100));
      expect(AmbientClock.instance.debugRunning, isTrue);
      expect(painter.time.value, greaterThan(t0));
    });

    testWidgets('reduced motion renders one static frame (no ticker)', (tester) async {
      await pumpMadar(tester, const CosmosBackdrop(), scaffold: false, reducedMotion: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('pauses when TickerMode is off', (tester) async {
      await pumpMadar(tester, const TickerMode(enabled: false, child: CosmosBackdrop()), scaffold: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('battery saver (animate: false) is static', (tester) async {
      await pumpMadar(tester, const CosmosBackdrop(animate: false), scaffold: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('paints its fallback in every theme without a shader', (tester) async {
      MadarShaders.debugDisable(MadarShaders.cosmosAsset);
      addTearDown(MadarShaders.debugReset);
      for (final id in MadarThemeId.values) {
        await pumpMadar(tester, const CosmosBackdrop(animate: false), scaffold: false, theme: id);
        expect(find.byType(CosmosBackdrop), paints..rect());
      }
    });
  });

  testWidgets('under flutter test, ambient motion is off so screens settle', (tester) async {
    expect(AmbientMotion.enabled, isFalse);
    await pumpMadar(
      tester,
      const MadarScaffold(
        title: 'T',
        body: Center(child: GlassPanel(child: Text('x'))),
      ),
      scaffold: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('x'), findsOneWidget);
  });

  group('AnimatedEmptyState', () {
    for (final (kind, ar, en) in [
      (EmptyStateKind.emptyList, 'لا شيء هنا بعد', 'Nothing here yet'),
      (EmptyStateKind.noData, 'لا بيانات بعد', 'No data yet'),
      (EmptyStateKind.noResults, 'لا نتائج', 'No results'),
    ]) {
      testWidgets('${kind.name}: localised defaults in ar and en', (tester) async {
        await pumpMadar(tester, AnimatedEmptyState(kind: kind));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(ar), findsOneWidget);
        await pumpMadar(tester, AnimatedEmptyState(kind: kind), locale: const Locale('en'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(en), findsOneWidget);
      });
    }

    testWidgets('action button fires', (tester) async {
      var taps = 0;
      await pumpMadar(
        tester,
        AnimatedEmptyState(kind: EmptyStateKind.emptyList, actionLabel: 'Add', onAction: () => taps++),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Add'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);
    });

    testWidgets('loops while ambient motion is on', (tester) async {
      AmbientMotion.debugOverride = true;
      addTearDown(() => AmbientMotion.debugOverride = null);
      await pumpMadar(tester, const AnimatedEmptyState(kind: EmptyStateKind.noData));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('reduced motion holds the illustration still', (tester) async {
      AmbientMotion.debugOverride = true;
      addTearDown(() => AmbientMotion.debugOverride = null);
      await pumpMadar(tester, const AnimatedEmptyState(kind: EmptyStateKind.noData), reducedMotion: true);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
