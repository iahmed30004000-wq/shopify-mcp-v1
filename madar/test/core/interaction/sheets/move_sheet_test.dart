import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/interaction/sheets/move_sheet.dart';
import 'package:madar/core/sound/sound_api.dart';

import '../interaction_test_utils.dart';

const _planets = [
  MoveTarget(id: 'faith', label: 'الإيمان', icon: Icons.mosque_rounded, color: Color(0xFFF2C14E), group: 'الكواكب'),
  MoveTarget(
    id: 'work',
    label: 'العمل',
    icon: Icons.work_rounded,
    color: Color(0xFF8A95A8),
    group: 'الكواكب',
    isCurrent: true,
  ),
  MoveTarget(id: 'p1', label: 'مشروع المدرسة', subtitle: 'مشروع', group: 'المشاريع'),
  MoveTarget(id: 'inbox', label: 'الوارد', icon: Icons.inbox_rounded),
];

class _Host extends StatefulWidget {
  const _Host({required this.targets, this.searchable});

  final List<MoveTarget> targets;
  final bool? searchable;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  MoveTarget? result;
  bool closed = false;

  @override
  Widget build(BuildContext context) => Center(
    child: ElevatedButton(
      onPressed: () async {
        final r = await showMoveSheet(
          context,
          title: 'نقل المهمة',
          targets: widget.targets,
          searchable: widget.searchable,
        );
        setState(() {
          result = r;
          closed = true;
        });
      },
      child: const Text('open'),
    ),
  );
}

Future<_HostState> _open(
  WidgetTester tester,
  List<MoveTarget> targets, {
  bool? searchable,
  Locale locale = const Locale('ar'),
}) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(
    interactionApp(
      _Host(targets: targets, searchable: searchable),
      locale: locale,
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return tester.state<_HostState>(find.byType(_Host));
}

void main() {
  late List<Sfx> played;
  setUp(() => played = installInteractionFx().sound.played);

  group('groupMoveTargets', () {
    test('ungrouped first, then groups in first-appearance order', () {
      final groups = groupMoveTargets(_planets);
      expect(groups.map((g) => g.$1), [null, 'الكواكب', 'المشاريع']);
      expect(groups[1].$2.map((t) => t.id), ['faith', 'work']);
    });
    test('search folds Arabic letter variants and matches subtitles and groups', () {
      expect(groupMoveTargets(_planets, query: 'مدرسه').single.$2.single.id, 'p1');
      expect(groupMoveTargets(_planets, query: 'الايمان').single.$2.single.id, 'faith');
      expect(groupMoveTargets(_planets, query: 'مشروع').single.$2.single.id, 'p1');
      expect(groupMoveTargets(_planets, query: 'الكواكب').single.$2, hasLength(2));
      expect(groupMoveTargets(_planets, query: 'zzz'), isEmpty);
    });
    test('multi-word queries need every word', () {
      expect(groupMoveTargets(_planets, query: 'مشروع مدرسة'), hasLength(1));
      expect(groupMoveTargets(_planets, query: 'مشروع عمل'), isEmpty);
    });
  });

  testWidgets('lists targets under group headers and returns the tapped one', (tester) async {
    final host = await _open(tester, _planets);
    expect(played, contains(Sfx.sheetOpen));
    expect(find.text('نقل المهمة'), findsOneWidget);
    expect(find.text('الكواكب'), findsOneWidget);
    expect(find.text('المشاريع'), findsOneWidget);
    expect(find.text('الحالي'), findsOneWidget);
    // Short list: no search field.
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('الإيمان'));
    await tester.pumpAndSettle();
    expect(host.closed, isTrue);
    expect(host.result, _planets.first);
    expect(played, containsAllInOrder([Sfx.drop, Sfx.sheetClose]));
  });

  testWidgets('the current destination is not selectable', (tester) async {
    final host = await _open(tester, _planets);
    await tester.tap(find.text('العمل'));
    await tester.pumpAndSettle();
    expect(host.closed, isFalse);
  });

  testWidgets('long lists get a search field that filters and shows an empty state', (tester) async {
    final many = [
      for (var i = 0; i < 10; i++) MoveTarget(id: 'l$i', label: 'قائمة $i', color: PlanetPalettes.travel.surface),
      const MoveTarget(id: 'ahmad', label: 'أحمد'),
    ];
    final host = await _open(tester, many);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'احمد');
    await tester.pumpAndSettle();
    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('قائمة 1'), findsNothing);

    await tester.enterText(find.byType(TextField), 'غير موجود');
    await tester.pumpAndSettle();
    expect(find.text('لا وجهة تطابق بحثك'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '٣');
    await tester.pumpAndSettle();
    await tester.tap(find.text('قائمة 3'));
    await tester.pumpAndSettle();
    expect(host.result?.id, 'l3');
  });

  testWidgets('dismissing returns null', (tester) async {
    final host = await _open(tester, _planets);
    await tester.tapAt(const Offset(200, 30));
    await tester.pumpAndSettle();
    expect(host.closed, isTrue);
    expect(host.result, isNull);
  });

  testWidgets('works left-to-right in English', (tester) async {
    final host = await _open(tester, const [
      MoveTarget(id: 'a', label: 'Health', group: 'Planets'),
      MoveTarget(id: 'b', label: 'Work', group: 'Planets', isCurrent: true),
    ], locale: const Locale('en'));
    expect(find.text('Current'), findsOneWidget);
    // The orb/label start on the left in LTR.
    expect(tester.getTopLeft(find.text('Health')).dx, lessThan(200));
    await tester.tap(find.text('Health'));
    await tester.pumpAndSettle();
    expect(host.result?.id, 'a');
  });
}
