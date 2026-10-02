import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/interaction/actionable_item.dart';
import 'package:madar/core/interaction/actions.dart';
import 'package:madar/core/interaction/interaction_math.dart';
import 'package:madar/core/interaction/reorderable_glass_list.dart';
import 'package:madar/core/sound/sound_api.dart';

import 'interaction_test_utils.dart';

Widget _row(String label) => Container(
  height: 64,
  alignment: AlignmentDirectional.centerStart,
  padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
  child: Text(label),
);

void main() {
  late ({dynamic sound, RecordingHaptics haptics}) fx;
  setUp(() {
    final r = installInteractionFx();
    fx = (sound: r.sound, haptics: r.haptics);
  });

  List<Sfx> played() => (fx.sound.played as List<Sfx>);

  group('tap', () {
    testWidgets('tap runs the primary action with Sfx.tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        interactionApp(
          Center(
            child: ActionableItem(onTap: () => taps++, child: _row('مهمة')),
          ),
        ),
      );
      await tester.tap(find.text('مهمة'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(played(), contains(Sfx.tap));
    });
  });

  group('long-press menu', () {
    testWidgets('shows only the provided actions and runs Edit after closing', (tester) async {
      usePhoneSurface(tester);
      var edits = 0;
      await tester.pumpWidget(
        interactionApp(
          Center(
            child: ActionableItem(
              actions: ItemActions(onEdit: () => edits++, onSetReminder: () {}),
              child: _row('مهمة'),
            ),
          ),
        ),
      );
      await tester.longPress(find.text('مهمة'));
      await tester.pumpAndSettle();
      expect(played(), contains(Sfx.pickUp));
      expect(fx.haptics.fired, contains(Haptic.medium));
      expect(find.text('تعديل'), findsOneWidget);
      expect(find.text('تذكير'), findsOneWidget);
      expect(find.text('حذف'), findsNothing);
      expect(find.text('تكرار'), findsNothing);

      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();
      expect(edits, 1);
      expect(find.text('تعديل'), findsNothing);
    });

    testWidgets('outside tap dismisses the menu without running anything', (tester) async {
      usePhoneSurface(tester);
      var edits = 0;
      await tester.pumpWidget(
        interactionApp(
          Center(
            child: ActionableItem(
              actions: ItemActions(onEdit: () => edits++),
              child: _row('مهمة'),
            ),
          ),
        ),
      );
      await tester.longPress(find.text('مهمة'));
      await tester.pumpAndSettle();
      expect(find.text('تعديل'), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('تعديل'), findsNothing);
      expect(edits, 0);
    });

    testWidgets('back button dismisses the menu', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        interactionApp(
          Center(
            child: ActionableItem(
              actions: ItemActions(onEdit: () {}),
              child: _row('مهمة'),
            ),
          ),
        ),
      );
      await tester.longPress(find.text('مهمة'));
      await tester.pumpAndSettle();
      expect(find.text('تعديل'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('تعديل'), findsNothing);
    });

    testWidgets('delete dissolves the row, calls onDelete and offers undo', (tester) async {
      usePhoneSurface(tester);
      var deleted = false;
      var undone = false;
      await tester.pumpWidget(
        interactionApp(
          StatefulBuilder(
            builder: (context, setState) => Center(
              child: deleted
                  ? const SizedBox.shrink()
                  : ActionableItem(
                      actions: ItemActions(
                        onEdit: () {},
                        onDelete: () async {
                          setState(() => deleted = true);
                          return UndoableAction(
                            label: 'تم الحذف',
                            undo: () async {
                              undone = true;
                              setState(() => deleted = false);
                            },
                          );
                        },
                      ),
                      child: _row('مهمة'),
                    ),
            ),
          ),
        ),
      );
      await tester.longPress(find.text('مهمة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pump();
      // The menu lands back on the row first, then the row dissolves.
      await pumpFrames(tester, 10);
      expect(deleted, isFalse);
      await pumpFrames(tester, 40);
      expect(played(), contains(Sfx.delete));
      expect(deleted, isTrue);
      expect(find.text('تم الحذف'), findsOneWidget);

      await tester.tap(find.text('تراجع'));
      await tester.pump();
      await pumpFrames(tester, 80);
      expect(undone, isTrue);
      expect(played(), contains(Sfx.undo));
      await tester.pumpAndSettle();
      expect(find.text('مهمة'), findsOneWidget);
    });

    testWidgets('extra actions appear before Delete', (tester) async {
      usePhoneSurface(tester);
      var pinned = 0;
      await tester.pumpWidget(
        interactionApp(
          Center(
            child: ActionableItem(
              actions: ItemActions(
                onDelete: () => null,
                extra: [
                  ItemAction(
                    icon: Icons.push_pin_rounded,
                    label: 'تثبيت',
                    onSelected: () => pinned++ == -1 ? null : null,
                  ),
                ],
              ),
              child: _row('مهمة'),
            ),
          ),
        ),
      );
      await tester.longPress(find.text('مهمة'));
      await tester.pumpAndSettle();
      final pin = tester.getTopLeft(find.text('تثبيت'));
      final del = tester.getTopLeft(find.text('حذف'));
      expect(pin.dy, lessThan(del.dy));
      await tester.tap(find.text('تثبيت'));
      await tester.pumpAndSettle();
      expect(pinned, 1);
    });
  });

  group('undo & accessibility', () {
    testWidgets('Duplicate returning an UndoableAction shows the undo toast', (tester) async {
      usePhoneSurface(tester);
      var copies = 0;
      await tester.pumpWidget(
        interactionApp(
          Center(
            child: ActionableItem(
              actions: ItemActions(
                onDuplicate: () async {
                  copies++;
                  return UndoableAction(label: 'تم التكرار', undo: () async => copies--);
                },
              ),
              child: _row('مهمة'),
            ),
          ),
        ),
      );
      await tester.longPress(find.text('مهمة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تكرار'));
      await pumpFrames(tester, 40);
      expect(copies, 1);
      expect(find.text('تم التكرار'), findsOneWidget);
      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(copies, 0);
    });

    testWidgets('a completed swipe can be undone', (tester) async {
      usePhoneSurface(tester);
      var done = false;
      await tester.pumpWidget(
        interactionApp(
          Center(
            child: ActionableItem(
              onCompleteSwipe: () {
                done = true;
                return UndoableAction(label: 'أُنجزت', undo: () async => done = false);
              },
              child: _row('مهمة'),
            ),
          ),
        ),
      );
      await tester.drag(find.text('مهمة'), const Offset(260, 0));
      await pumpFrames(tester, 40);
      expect(done, isTrue);
      expect(find.text('أُنجزت'), findsOneWidget);
      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(done, isFalse);
    });

    testWidgets('every action is reachable as a screen-reader action', (tester) async {
      usePhoneSurface(tester);
      final handle = tester.ensureSemantics();
      final log = <String>[];
      await tester.pumpWidget(
        interactionApp(
          Center(
            child: ActionableItem(
              semanticLabel: 'مهمة القراءة',
              onTap: () => log.add('tap'),
              onCompleteSwipe: () {
                log.add('complete');
                return null;
              },
              quickActions: [
                QuickAction(
                  icon: Icons.snooze_rounded,
                  label: 'تأجيل',
                  onPressed: () {
                    log.add('snooze');
                    return null;
                  },
                ),
              ],
              actions: ItemActions(onEdit: () => log.add('edit'), onSetReminder: () => log.add('reminder')),
              child: _row('مهمة'),
            ),
          ),
        ),
      );
      final node = tester.getSemantics(find.bySemanticsLabel(RegExp('مهمة القراءة')));
      expect(node, isSemantics(hasTapAction: true, hasLongPressAction: true, hint: 'اسحب نحو اليمين للإنجاز'));
      final owner = node.owner!;
      for (final label in ['تعديل', 'تذكير', 'إنجاز', 'تأجيل']) {
        final action = CustomSemanticsAction(label: label);
        owner.performAction(node.id, SemanticsAction.customAction, CustomSemanticsAction.getIdentifier(action));
        await tester.pumpAndSettle();
      }
      expect(log, ['edit', 'reminder', 'complete', 'snooze']);
      expect(played(), contains(Sfx.complete));
      handle.dispose();
    });

    testWidgets('disabled items ignore every gesture', (tester) async {
      usePhoneSurface(tester);
      var hits = 0;
      await tester.pumpWidget(
        interactionApp(
          Center(
            child: ActionableItem(
              enabled: false,
              onTap: () => hits++,
              onCompleteSwipe: () => hits++ == -1 ? null : null,
              actions: ItemActions(onEdit: () => hits++),
              child: _row('مهمة'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('مهمة'));
      await tester.longPress(find.text('مهمة'));
      await tester.drag(find.text('مهمة'), const Offset(260, 0));
      await tester.pumpAndSettle();
      expect(hits, 0);
      expect(find.text('تعديل'), findsNothing);
    });

    testWidgets('reduced motion: menu and swipe still work', (tester) async {
      usePhoneSurface(tester);
      var edits = 0;
      var done = 0;
      await tester.pumpWidget(
        interactionApp(
          Center(
            child: ActionableItem(
              actions: ItemActions(onEdit: () => edits++),
              onCompleteSwipe: () => done++ == -1 ? null : null,
              child: _row('مهمة'),
            ),
          ),
          reduced: true,
        ),
      );
      await tester.longPress(find.text('مهمة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('مهمة'), const Offset(260, 0));
      await tester.pumpAndSettle();
      expect((edits, done), (1, 1));
    });
  });

  group('swipe', () {
    testWidgets('right swipe past the threshold completes with tick + complete', (tester) async {
      usePhoneSurface(tester);
      var completed = 0;
      await tester.pumpWidget(
        interactionApp(
          Center(
            child: ActionableItem(onCompleteSwipe: () => completed++ == -1 ? null : null, child: _row('مهمة')),
          ),
        ),
      );
      final threshold = SwipeMath.completeThreshold(412);
      final gesture = await tester.startGesture(tester.getCenter(find.text('مهمة')));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveBy(Offset(threshold * 0.5, 0));
      await tester.pump();
      expect(played(), isNot(contains(Sfx.countTick)));
      await gesture.moveBy(Offset(threshold * 0.6, 0));
      await tester.pump();
      expect(played().where((s) => s == Sfx.countTick), hasLength(1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(played(), contains(Sfx.complete));
    });

    testWidgets('right swipe short of the threshold springs back', (tester) async {
      usePhoneSurface(tester);
      var completed = 0;
      await tester.pumpWidget(
        interactionApp(
          Center(
            child: ActionableItem(onCompleteSwipe: () => completed++ == -1 ? null : null, child: _row('مهمة')),
          ),
        ),
      );
      final start = tester.getTopLeft(find.text('مهمة'));
      await tester.drag(find.text('مهمة'), const Offset(50, 0));
      await tester.pumpAndSettle();
      expect(completed, 0);
      expect(played(), isNot(contains(Sfx.complete)));
      expect(tester.getTopLeft(find.text('مهمة')), start);
    });

    testWidgets('swipe is physical: right completes in LTR too', (tester) async {
      usePhoneSurface(tester);
      var completed = 0;
      await tester.pumpWidget(
        interactionApp(
          Center(
            child: ActionableItem(onCompleteSwipe: () => completed++ == -1 ? null : null, child: _row('Task')),
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.drag(find.text('Task'), const Offset(260, 0));
      await tester.pumpAndSettle();
      expect(completed, 1);
      await tester.drag(find.text('Task'), const Offset(-260, 0));
      await tester.pumpAndSettle();
      expect(completed, 1);
    });

    testWidgets('left swipe opens the quick-action tray which stays open', (tester) async {
      usePhoneSurface(tester);
      var snoozed = 0;
      await tester.pumpWidget(
        interactionApp(
          Column(
            children: [
              const SizedBox(height: 200),
              ActionableItem(
                quickActions: [
                  QuickAction(
                    icon: Icons.snooze_rounded,
                    label: 'تأجيل',
                    onPressed: () => snoozed++ == -1 ? null : null,
                  ),
                ],
                child: _row('مهمة'),
              ),
              const SizedBox(height: 200, child: Text('خارج')),
            ],
          ),
        ),
      );
      await tester.drag(find.text('مهمة'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(played(), contains(Sfx.swipe));
      final state = tester.state<ActionableItemState>(find.byType(ActionableItem));
      expect(state.trayOpen, isTrue);
      expect(find.text('تأجيل'), findsOneWidget);

      await tester.tap(find.text('تأجيل'));
      await tester.pumpAndSettle();
      expect(snoozed, 1);
      expect(state.trayOpen, isFalse);

      // Re-open, then tap elsewhere to close.
      await tester.drag(find.text('مهمة'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(state.trayOpen, isTrue);
      await tester.tap(find.text('خارج'));
      await tester.pumpAndSettle();
      expect(state.trayOpen, isFalse);
    });

    testWidgets('vertical drags scroll the list instead of swiping', (tester) async {
      usePhoneSurface(tester);
      var completed = 0;
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        interactionApp(
          ListView(
            controller: controller,
            children: [
              for (var i = 0; i < 30; i++)
                ActionableItem(onCompleteSwipe: () => completed++ == -1 ? null : null, child: _row('عنصر $i')),
            ],
          ),
        ),
      );
      await tester.drag(find.text('عنصر 3'), const Offset(30, -300));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(100));
      expect(completed, 0);
    });

    testWidgets('a reorder grip inside the item does not trigger swipe or tap', (tester) async {
      usePhoneSurface(tester);
      var taps = 0;
      var completed = 0;
      await tester.pumpWidget(
        interactionApp(
          ReorderableListView(
            buildDefaultDragHandles: false,
            onReorderItem: (a, b) {},
            children: [
              for (var i = 0; i < 3; i++)
                ActionableItem(
                  key: ValueKey(i),
                  onTap: () => taps++,
                  onCompleteSwipe: () => completed++ == -1 ? null : null,
                  child: Row(
                    children: [
                      Expanded(child: _row('عنصر $i')),
                      ReorderGrip(index: i),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(ReorderGrip).first);
      await tester.pumpAndSettle();
      expect(taps, 0);
      await tester.drag(find.byType(ReorderGrip).first, const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(completed, 0);
    });
  });
}
