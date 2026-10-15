import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/interaction/sheets/edit_sheet.dart';
import 'package:madar/core/interaction/sheets/field_spec.dart';
import 'package:madar/core/interaction/sheets/sheet.dart';
import 'package:madar/core/settings/app_settings.dart' show DigitStyle;
import 'package:madar/core/sound/sound_api.dart';

import '../interaction_test_utils.dart';

class _Host extends StatefulWidget {
  const _Host({required this.fields, this.initial = const {}});

  final List<FieldSpec> fields;
  final Map<String, Object?> initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Map<String, Object?>? result;
  bool closed = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          final r = await showEditSheet(context, title: 'تعديل المهمة', fields: widget.fields, initial: widget.initial);
          setState(() {
            result = r;
            closed = true;
          });
        },
        child: const Text('open'),
      ),
    );
  }
}

Future<_HostState> _open(
  WidgetTester tester,
  List<FieldSpec> fields, {
  Map<String, Object?> initial = const {},
  Locale locale = const Locale('ar'),
  DigitStyle digits = DigitStyle.auto,
}) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(
    interactionApp(
      _Host(fields: fields, initial: initial),
      locale: locale,
      digits: digits,
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return tester.state<_HostState>(find.byType(_Host));
}

Finder _input(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

void main() {
  late List<Sfx> played;
  setUp(() {
    final fx = installInteractionFx();
    played = fx.sound.played;
  });

  testWidgets('opens with Sfx.sheetOpen and shows title and fields', (tester) async {
    await _open(tester, [FieldSpec.text('title', 'العنوان', required: true)]);
    expect(played, contains(Sfx.sheetOpen));
    expect(find.text('تعديل المهمة'), findsOneWidget);
    expect(find.text('العنوان'), findsOneWidget);
    expect(find.text('حفظ'), findsOneWidget);
  });

  testWidgets('Save is disabled until valid; tapping it reveals the error', (tester) async {
    final host = await _open(tester, [FieldSpec.text('title', 'العنوان', required: true)]);
    expect(find.text('هذا الحقل مطلوب'), findsNothing);
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(played, contains(Sfx.error));
    expect(find.text('هذا الحقل مطلوب'), findsOneWidget);
    expect(host.closed, isFalse);

    await tester.enterText(find.byType(TextField), '  شراء خبز ');
    await tester.pumpAndSettle();
    expect(find.text('هذا الحقل مطلوب'), findsNothing);
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(host.closed, isTrue);
    expect(host.result, {'title': 'شراء خبز'});
    expect(played, contains(Sfx.sheetClose));
  });

  testWidgets('number fields normalise Arabic-Indic digits and ٫', (tester) async {
    final host = await _open(tester, [
      FieldSpec.number('weight', 'الوزن', decimals: 2, unit: 'كغ'),
      FieldSpec.number('count', 'العدد'),
    ]);
    await tester.enterText(_input('الوزن'), '٧٢٫٥');
    await tester.enterText(_input('العدد'), '۱۲');
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(host.result, {'weight': 72.5, 'count': 12});
    expect(host.result!['count'], isA<int>());
  });

  testWidgets('the Arabic comma survives typing: ١٢،٥ is 12.5, not 125', (tester) async {
    final host = await _open(tester, [FieldSpec.number('weight', 'الوزن', decimals: 2)]);
    await tester.enterText(_input('الوزن'), '١٢،٥');
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(host.result, {'weight': 12.5});
  });

  testWidgets('number validation: decimals, min and max show inline errors', (tester) async {
    await _open(tester, [FieldSpec.number('pages', 'الصفحات', min: 1, max: 600)]);
    await tester.enterText(find.byType(TextField), '2.5');
    await tester.pumpAndSettle();
    expect(find.text('أدخل عددًا صحيحًا دون كسور'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0');
    await tester.pumpAndSettle();
    // Limits in the user's digit style (Arabic-Indic in Arabic by default).
    expect(find.text('لا يقلّ عن ١'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '٧٠٠');
    await tester.pumpAndSettle();
    expect(find.text('لا يزيد على ٦٠٠'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pumpAndSettle();
    // Letters are filtered by the input formatter.
    expect(find.text('abc'), findsNothing);
  });

  testWidgets('custom validators receive all values', (tester) async {
    await _open(tester, [
      FieldSpec.number('min', 'الأدنى'),
      FieldSpec.number(
        'max',
        'الأعلى',
        validator: (v, all) =>
            v != null && all['min'] != null && (v as num) < (all['min'] as num) ? 'أصغر من الأدنى' : null,
      ),
    ]);
    await tester.enterText(_input('الأدنى'), '10');
    await tester.enterText(_input('الأعلى'), '5');
    await tester.pumpAndSettle();
    expect(find.text('أصغر من الأدنى'), findsOneWidget);
  });

  testWidgets('initial values populate the form and an untouched form closes without asking', (tester) async {
    final host = await _open(
      tester,
      [FieldSpec.text('title', 'العنوان'), FieldSpec.currency('price', 'السعر')],
      initial: {
        'title': 'قهوة',
        'price': const MoneyValue(amountMilli: 2500, currency: 'JOD'),
      },
    );
    expect(find.text('قهوة'), findsOneWidget);
    expect(find.text('2.5'), findsOneWidget);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(host.closed, isTrue);
    expect(host.result, isNull);
  });

  testWidgets('dirty form asks before discarding; Keep editing stays, Discard closes', (tester) async {
    final host = await _open(tester, [FieldSpec.text('title', 'العنوان')], initial: {'title': 'قهوة'});
    await tester.enterText(find.byType(TextField), 'شاي');
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(host.closed, isFalse);
    expect(find.text('تجاهُل التعديلات؟  ', findRichText: true), findsNothing);
    expect(find.textContaining('تجاهُل التعديلات؟', findRichText: true), findsOneWidget);

    await tester.tap(find.text('متابعة التعديل'));
    await tester.pumpAndSettle();
    expect(find.textContaining('تجاهُل التعديلات؟', findRichText: true), findsNothing);
    expect(host.closed, isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.textContaining('تجاهُل التعديلات؟', findRichText: true), findsOneWidget);
    await tester.tap(find.text('تجاهُل'));
    await tester.pumpAndSettle();
    expect(host.closed, isTrue);
    expect(host.result, isNull);
  });

  testWidgets('drag down on the header dismisses a clean sheet', (tester) async {
    final host = await _open(tester, [FieldSpec.text('title', 'العنوان')]);
    await tester.fling(find.text('تعديل المهمة'), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();
    expect(host.closed, isTrue);
  });

  testWidgets('drag down on a dirty sheet springs back and asks', (tester) async {
    final host = await _open(tester, [FieldSpec.text('title', 'العنوان')]);
    await tester.enterText(find.byType(TextField), 'جديد');
    await tester.pumpAndSettle();
    // The sheet is bottom-anchored; it grows when the discard bar appears, so
    // compare its bottom edge (drag offset back at rest), not the title.
    final sheet = find.byType(InteractionSheetFrame);
    final before = tester.getBottomLeft(sheet);
    await tester.fling(find.text('تعديل المهمة'), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();
    expect(host.closed, isFalse);
    expect(tester.getBottomLeft(sheet).dy, closeTo(before.dy, 1));
    expect(find.textContaining('تجاهُل التعديلات؟', findRichText: true), findsOneWidget);
  });

  testWidgets('currency picker switches the currency', (tester) async {
    final host = await _open(tester, [FieldSpec.currency('amount', 'المبلغ', required: true)]);
    await tester.enterText(find.byType(TextField), '١٥٫٧٥');
    await tester.tap(find.text('JOD'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('دولار أمريكي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(host.result!['amount'], const MoneyValue(amountMilli: 15750, currency: 'USD'));
  });

  testWidgets('chips, toggle, rating, prayer window, colour and icon', (tester) async {
    final host = await _open(tester, [
      FieldSpec.singleSelect(
        'priority',
        'الأولوية',
        options: const [
          SelectOption(id: 'low', label: 'منخفضة'),
          SelectOption(id: 'high', label: 'عالية'),
        ],
      ),
      FieldSpec.toggle('top3', 'من أهم ثلاث'),
      FieldSpec.rating('stars', 'التقييم'),
      FieldSpec.prayerWindow('window', 'الوقت'),
      FieldSpec.color('color', 'اللون', palette: const [Color(0xFF7FE3C4), Color(0xFF9C8CFF)]),
      FieldSpec.icon('icon', 'الأيقونة', icons: const {'star': Icons.star_rounded, 'moon': Icons.dark_mode_rounded}),
    ]);
    await tester.tap(find.text('عالية'));
    await tester.tap(find.text('من أهم ثلاث'));
    await tester.tap(find.byKey(const ValueKey('star4')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('بعد العشاء'));
    await tester.tap(find.text('بعد العشاء'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.bySemanticsLabel('لون ٢'));
    await tester.tap(find.bySemanticsLabel('لون ٢'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.dark_mode_rounded));
    await tester.tap(find.byIcon(Icons.dark_mode_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(host.result, {
      'priority': 'high',
      'top3': true,
      'stars': 4,
      'window': PrayerWindow.isha,
      'color': 0xFF9C8CFF,
      'icon': 'moon',
    });
    expect(played, contains(Sfx.toggleOn));
  });

  testWidgets('Western digit style keeps limits in Western digits', (tester) async {
    await _open(tester, [FieldSpec.number('pages', 'الصفحات', min: 1, max: 600)], digits: DigitStyle.western);
    await tester.enterText(find.byType(TextField), '٧٠٠');
    await tester.pumpAndSettle();
    expect(find.text('لا يزيد على 600'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '2.5');
    await tester.pumpAndSettle();
    expect(find.text('أدخل عددًا صحيحًا دون كسور'), findsOneWidget);
  });

  testWidgets('decimal-place limits are localised too', (tester) async {
    await _open(tester, [FieldSpec.number('w', 'الوزن', decimals: 3)]);
    await tester.enterText(find.byType(TextField), '1.23456');
    await tester.pumpAndSettle();
    expect(find.text('٣ منازل عشرية كحدّ أقصى'), findsOneWidget);
  });

  testWidgets('a toggle is one labelled, toggled node for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester, [FieldSpec.toggle('fav', 'Pin to top')], locale: const Locale('en'));
    expect(
      find.bySemanticsLabel('Pin to top'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Pin to top')),
      isSemantics(label: 'Pin to top', hasToggledState: true, isToggled: false, hasTapAction: true),
    );
    await tester.tap(find.text('Pin to top'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Pin to top')),
      isSemantics(label: 'Pin to top', hasToggledState: true, isToggled: true),
    );
    handle.dispose();
  });

  testWidgets('icon picker speaks localised labels, never the stored keys', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester, [
      FieldSpec.icon('icon', 'الأيقونة', icons: const {'briefcase': Icons.work_rounded, 'book': Icons.book_rounded}),
    ]);
    expect(find.bySemanticsLabel('أيقونة ١'), findsOneWidget);
    expect(find.bySemanticsLabel('أيقونة ٢'), findsOneWidget);
    expect(find.bySemanticsLabel('briefcase'), findsNothing);
    expect(find.bySemanticsLabel('book'), findsNothing);
    handle.dispose();
  });

  testWidgets('multi-select can add an option inline', (tester) async {
    final host = await _open(tester, [
      FieldSpec.multiSelect(
        'triggers',
        'المحفّزات',
        allowAdd: true,
        options: const [
          SelectOption(id: 'stress', label: 'توتر'),
          SelectOption(id: 'sleep', label: 'قلة نوم'),
        ],
      ),
    ]);
    await tester.tap(find.text('توتر'));
    await tester.tap(find.text('خيار جديد'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'برد');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('برد'), findsOneWidget);
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(host.result!['triggers'], ['stress', 'برد']);
  });

  testWidgets('time list adds times in order and removes them', (tester) async {
    final host = await _open(
      tester,
      [FieldSpec.timeList('times', 'أوقات الجرعات')],
      initial: {
        'times': ['20:00'],
      },
    );
    await tester.tap(find.text('إضافة وقت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(host.result!['times'], ['00:00', '20:00']);
  });

  testWidgets('works left-to-right in English', (tester) async {
    final host = await _open(tester, [
      FieldSpec.text('title', 'Title', required: true),
      FieldSpec.slider('pain', 'Pain', labels: const {0: 'None', 10: 'Worst'}),
    ], locale: const Locale('en'));
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Walk');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(host.result, {'title': 'Walk', 'pain': 0});
  });
}
