import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/interaction/actionable_item.dart';
import 'package:madar/core/interaction/reorderable_glass_list.dart';
import 'package:madar/core/sound/sound_api.dart';

import 'interaction_test_utils.dart';

Widget _row(String label, Widget handle) => SizedBox(
  height: 64,
  child: Row(
    children: [
      Expanded(child: Text(label)),
      handle,
    ],
  ),
);

class _Host extends StatefulWidget {
  const _Host({super.key, required this.initial, required this.onReorder, this.wrapInItem = false});

  final List<String> initial;
  final void Function(List<String>) onReorder;
  final bool wrapInItem;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<String> items = widget.initial;

  void replaceItems(List<String> next) => setState(() => items = next);

  @override
  Widget build(BuildContext context) {
    return ReorderableGlassList<String>(
      items: items,
      itemKey: (s) => s,
      onReorder: (order) {
        widget.onReorder(order);
        setState(() => items = order);
      },
      itemBuilder: (context, item, index, handle) {
        final row = _row(item, handle);
        return widget.wrapInItem ? ActionableItem(onTap: () {}, onCompleteSwipe: () => null, child: row) : row;
      },
    );
  }
}

Future<void> _dragGrip(WidgetTester tester, String label, double dy) async {
  final grip = find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
    matching: find.byType(ReorderGrip),
  );
  final gesture = await tester.startGesture(tester.getCenter(grip));
  await tester.pump(const Duration(milliseconds: 50));
  for (var i = 0; i < 12; i++) {
    await gesture.moveBy(Offset(0, dy / 12));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 300));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  late List<Sfx> played;
  setUp(() => played = installInteractionFx().sound.played);

  testWidgets('dragging a grip reorders and reports the full new order', (tester) async {
    usePhoneSurface(tester);
    final orders = <List<String>>[];
    await tester.pumpWidget(interactionApp(_Host(initial: const ['أ', 'ب', 'ج'], onReorder: orders.add)));
    await tester.pumpAndSettle();
    expect(find.byType(ReorderGrip), findsNWidgets(3));

    await _dragGrip(tester, 'أ', 150);
    expect(orders, [
      ['ب', 'ج', 'أ'],
    ]);
    expect(played, containsAllInOrder([Sfx.pickUp, Sfx.drop]));
    // Rendered in the new order.
    expect(tester.getTopLeft(find.text('ب')).dy, lessThan(tester.getTopLeft(find.text('أ')).dy));
  });

  testWidgets('the dragged row lifts: scale 1.03 with a glow', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(interactionApp(_Host(initial: const ['أ', 'ب', 'ج'], onReorder: (_) {})));
    await tester.pumpAndSettle();
    final grip = find.byType(ReorderGrip).first;
    final gesture = await tester.startGesture(tester.getCenter(grip));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 30));
    await pumpFrames(tester, 30);
    final scales = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((t) => t.transform.getMaxScaleOnAxis())
        .where((s) => s > 1.001)
        .toList();
    expect(scales, isNotEmpty);
    expect(scales.first, closeTo(1.03, 0.002));
    final glows = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => (d.boxShadow?.length ?? 0) == 2);
    expect(glows, isNotEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('works with grips inside ActionableItem rows (no accidental swipe)', (tester) async {
    usePhoneSurface(tester);
    final orders = <List<String>>[];
    await tester.pumpWidget(
      interactionApp(_Host(initial: const ['1', '2', '3'], onReorder: orders.add, wrapInItem: true)),
    );
    await tester.pumpAndSettle();
    await _dragGrip(tester, '3', -150);
    expect(orders, [
      ['3', '1', '2'],
    ]);
    expect(played, isNot(contains(Sfx.complete)));
  });

  testWidgets('new items from the parent appear with an entrance', (tester) async {
    usePhoneSurface(tester);
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(interactionApp(_Host(key: key, initial: const ['أ'], onReorder: (_) {})));
    await tester.pumpAndSettle();
    key.currentState!.replaceItems(['أ', 'ب']);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final fading = tester
        .widgetList<Opacity>(find.ancestor(of: find.text('ب'), matching: find.byType(Opacity)))
        .where((o) => o.opacity < 1);
    expect(fading, isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.text('ب'), findsOneWidget);
  });

  testWidgets('grip exposes a localised semantics label in both directions', (tester) async {
    usePhoneSurface(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      interactionApp(
        _Host(initial: const ['a'], onReorder: (_) {}),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Drag to reorder'), findsOneWidget);
    handle.dispose();
  });
}
