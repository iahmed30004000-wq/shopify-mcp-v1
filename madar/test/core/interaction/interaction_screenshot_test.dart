// Visual critic pass for the interaction kit: renders the kit over the real
// cosmos with the real fonts and writes PNGs to madar/screenshots/.
//
//   flutter test --tags screenshot test/core/interaction/interaction_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/interaction/interaction.dart';

import '../../helpers/screenshot_harness.dart';

final _now = DateTime(2026, 9, 27, 10);

class _Task {
  const _Task(this.id, this.title, this.subtitle, this.planet, this.icon);
  final String id, title, subtitle, planet;
  final IconData icon;
}

class _Demo extends StatefulWidget {
  const _Demo({required this.english, required this.bodyKey, required this.itemKeys, required this.quickText});

  final bool english;
  final GlobalKey bodyKey;
  final List<GlobalKey<ActionableItemState>> itemKeys;
  final String quickText;

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  late final TextEditingController _quick = TextEditingController(text: widget.quickText);
  late List<_Task> _tasks = widget.english
      ? const [
          _Task('1', 'Morning adhkar', 'After Fajr', 'faith', Icons.auto_awesome_rounded),
          _Task('2', 'Call the supplier', 'Work · 11:00', 'work', Icons.call_rounded),
          _Task('3', 'Pay the electricity bill', 'Money · 35 JD', 'money', Icons.receipt_long_rounded),
          _Task('4', 'Evening walk', 'Body · 30 min', 'body', Icons.directions_walk_rounded),
          _Task('5', 'Read 10 pages', 'Growth', 'growth', Icons.menu_book_rounded),
        ]
      : const [
          _Task('1', 'أذكار الصباح', 'بعد الفجر', 'faith', Icons.auto_awesome_rounded),
          _Task('2', 'الاتصال بالمورّد', 'العمل · 11:00', 'work', Icons.call_rounded),
          _Task('3', 'دفع فاتورة الكهرباء', 'المال · 35 د.أ', 'money', Icons.receipt_long_rounded),
          _Task('4', 'مشي المساء', 'الجسد · 30 دقيقة', 'body', Icons.directions_walk_rounded),
          _Task('5', 'قراءة 10 صفحات', 'النمو', 'growth', Icons.menu_book_rounded),
        ];

  @override
  void dispose() {
    _quick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarScaffold(
      title: widget.english ? 'Today' : 'اليوم',
      body: Column(
        key: widget.bodyKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 0),
            child: QuickAddBar(controller: _quick, clock: () => _now),
          ),
          Expanded(
            child: ReorderableGlassList<_Task>(
              items: _tasks,
              itemKey: (task) => task.id,
              onReorder: (order) => setState(() => _tasks = order),
              itemBuilder: (context, task, index, handle) {
                final planet = PlanetPalettes.byKey[task.planet]!;
                return ActionableItem(
                  key: widget.itemKeys[index],
                  onTap: () {},
                  onCompleteSwipe: () => null,
                  quickActions: [
                    QuickAction(
                      icon: Icons.snooze_rounded,
                      label: widget.english ? 'Snooze' : 'تأجيل',
                      onPressed: () => null,
                    ),
                    QuickAction(
                      icon: Icons.today_rounded,
                      label: widget.english ? 'Tomorrow' : 'غدًا',
                      tone: ActionTone.info,
                      onPressed: () => null,
                    ),
                  ],
                  actions: ItemActions(
                    onEdit: () {},
                    onDuplicate: () => null,
                    onMove: () => null,
                    onSetReminder: () {},
                    onDelete: () => null,
                    extra: [
                      ItemAction(
                        icon: Icons.star_rounded,
                        label: widget.english ? 'Add to top 3' : 'ضمن أهم ثلاث',
                        tone: ActionTone.accent,
                        onSelected: () => null,
                      ),
                    ],
                  ),
                  child: GlassCard(
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.xs, Space.m),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [planet.glow, planet.surface, planet.deep],
                              stops: const [0, 0.6, 1],
                            ),
                            boxShadow: [BoxShadow(color: planet.surface.withValues(alpha: 0.5), blurRadius: 12)],
                          ),
                          child: Icon(task.icon, size: 18, color: planet.deep),
                        ),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task.title, style: text.titleMedium),
                              Text(task.subtitle, style: text.bodySmall?.copyWith(color: t.textTertiary)),
                            ],
                          ),
                        ),
                        handle,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _app(Widget home, {bool english = false, MadarThemeId theme = MadarThemeId.lapis}) => ProviderScope(
  child: madarScreenshotApp(home: home, theme: theme, locale: Locale(english ? 'en' : 'ar')),
);

({Widget app, GlobalKey body, List<GlobalKey<ActionableItemState>> items}) _scene({
  bool english = false,
  MadarThemeId theme = MadarThemeId.lapis,
  String? quick,
}) {
  final body = GlobalKey();
  final items = List.generate(5, (_) => GlobalKey<ActionableItemState>());
  final app = _app(
    _Demo(
      english: english,
      bodyKey: body,
      itemKeys: items,
      quickText: quick ?? (english ? 'tomorrow after isha call supplier' : 'صرفت 12.5 دينار بنزين'),
    ),
    english: english,
    theme: theme,
  );
  return (app: app, body: body, items: items);
}

void main() {
  testWidgets('list: swipe, tray, preview, undo – Lapis RTL', (tester) async {
    final s = _scene();
    final file = await captureScreen(
      tester,
      s.app,
      'interaction_list_lapis_rtl',
      beforeCapture: (tester) async {
        showUndoToast(s.body.currentContext!, UndoableAction(label: 'حُذفت «مشي المساء»', undo: () async {}));
        final start = tester.getCenter(find.byKey(s.items[1]));
        final g = await tester.startGesture(start);
        for (var i = 0; i < 10; i++) {
          await g.moveBy(const Offset(18, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        // Opened after the swipe's pointer-down (which closes open trays).
        s.items[2].currentState!.openTray();
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
    expect(file.existsSync(), isTrue);
  });

  testWidgets('long-press menu – Lapis RTL', (tester) async {
    final s = _scene(quick: '');
    final file = await captureScreen(
      tester,
      s.app,
      'interaction_menu_lapis_rtl',
      beforeCapture: (tester) async {
        await tester.longPress(find.byKey(s.items[1]));
      },
    );
    expect(file.existsSync(), isTrue);
  });

  testWidgets('edit sheet – Emerald RTL', (tester) async {
    final s = _scene(theme: MadarThemeId.emerald, quick: '');
    final file = await captureScreen(
      tester,
      s.app,
      'interaction_edit_sheet_emerald_rtl',
      beforeCapture: (tester) async {
        showEditSheet(
          s.body.currentContext!,
          title: 'تعديل المصروف',
          icon: Icons.payments_rounded,
          fields: [
            FieldSpec.text('title', 'الوصف', required: true),
            FieldSpec.currency('amount', 'المبلغ', required: true),
            FieldSpec.singleSelect(
              'cat',
              'الفئة',
              options: const [
                SelectOption(id: 'fuel', label: 'وقود', icon: Icons.local_gas_station_rounded),
                SelectOption(id: 'food', label: 'طعام', icon: Icons.restaurant_rounded),
                SelectOption(id: 'bills', label: 'فواتير', icon: Icons.receipt_long_rounded),
              ],
            ),
            FieldSpec.prayerWindow('window', 'الوقت'),
            FieldSpec.rating('worth', 'هل كان يستحق؟'),
          ],
          initial: {
            'title': 'بنزين',
            'amount': const MoneyValue(amountMilli: 12500, currency: 'JOD'),
            'cat': 'fuel',
            'window': PrayerWindow.asr,
            'worth': 4,
          },
        );
      },
    );
    expect(file.existsSync(), isTrue);
  });

  testWidgets('edit sheet with validation errors – Pearl RTL', (tester) async {
    final s = _scene(theme: MadarThemeId.pearl, quick: '');
    final file = await captureScreen(
      tester,
      s.app,
      'interaction_edit_sheet_pearl_rtl',
      beforeCapture: (tester) async {
        showEditSheet(
          s.body.currentContext!,
          title: 'دواء جديد',
          icon: Icons.medication_rounded,
          fields: [
            FieldSpec.text('name', 'الاسم', required: true),
            FieldSpec.number('dose', 'الجرعة', unit: 'ملغ', min: 1, max: 2000, required: true),
            FieldSpec.timeList('times', 'الأوقات', required: true),
            FieldSpec.slider('pain', 'شدة الألم', labels: const {0: 'لا ألم', 5: 'متوسط', 10: 'لا يُحتمل'}),
            FieldSpec.toggle('food', 'مع الطعام', hint: 'ذكّرني أن آخذه مع وجبة'),
          ],
          initial: {
            'times': ['08:00', '20:00'],
            'pain': 3,
          },
        );
        await tester.pump(const Duration(milliseconds: 700));
        // Field 0 is the quick-add bar behind the sheet.
        await tester.enterText(find.byType(TextField).at(1), 'فيتامين د');
        await tester.enterText(find.byType(TextField).at(2), '٣٠٠٠');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('حفظ'));
      },
    );
    expect(file.existsSync(), isTrue);
  });

  testWidgets('reminder sheet – Desert RTL', (tester) async {
    final s = _scene(theme: MadarThemeId.desert, quick: '');
    final file = await captureScreen(
      tester,
      s.app,
      'interaction_reminder_desert_rtl',
      beforeCapture: (tester) async {
        showReminderSheet(
          s.body.currentContext!,
          initial: const {'kind': 'prayer', 'window': 'maghrib', 'offsetMin': -15},
          now: _now,
        );
      },
    );
    expect(file.existsSync(), isTrue);
  });

  testWidgets('move sheet – Aurora LTR', (tester) async {
    final s = _scene(english: true, theme: MadarThemeId.aurora, quick: '');
    final file = await captureScreen(
      tester,
      s.app,
      'interaction_move_aurora_ltr',
      beforeCapture: (tester) async {
        showMoveSheet(
          s.body.currentContext!,
          title: 'Move task',
          targets: [
            for (final (key, label, icon) in [
              ('faith', 'Faith', Icons.mosque_rounded),
              ('health', 'Health', Icons.favorite_rounded),
              ('family', 'Family', Icons.family_restroom_rounded),
              ('work', 'Work', Icons.work_rounded),
            ])
              MoveTarget(
                id: key,
                label: label,
                icon: icon,
                color: PlanetPalettes.byKey[key]!.surface,
                group: 'Planets',
                isCurrent: key == 'work',
              ),
            const MoveTarget(
              id: 'p1',
              label: 'Website relaunch',
              subtitle: '12 tasks',
              icon: Icons.folder_rounded,
              group: 'Projects',
            ),
            const MoveTarget(
              id: 'p2',
              label: 'Umrah trip',
              subtitle: '5 tasks',
              icon: Icons.flight_rounded,
              group: 'Projects',
            ),
          ],
        );
      },
    );
    expect(file.existsSync(), isTrue);
  });

  testWidgets('list – Aurora LTR', (tester) async {
    final s = _scene(english: true, theme: MadarThemeId.aurora);
    final file = await captureScreen(
      tester,
      s.app,
      'interaction_list_aurora_ltr',
      beforeCapture: (tester) async {
        s.items[3].currentState!.openTray();
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
    expect(file.existsSync(), isTrue);
  });
}
