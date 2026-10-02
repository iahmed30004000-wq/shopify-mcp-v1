import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/health/record/record.dart';

import 'record_harness.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

class _LabTestByName extends ConsumerWidget {
  const _LabTestByName(this.name);

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = (ref.watch(labTestsProvider).value ?? const <LabTestRow>[]).where((t) => t.name == name).firstOrNull;
    return t == null ? const SizedBox.shrink() : LabTestScreen(testId: t.id, animateBackdrop: false);
  }
}

/// The text field of the edit-sheet field labelled [label].
Finder _fieldOf(String label) => find.descendant(
  of: find.ancestor(of: find.text(label).first, matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

Future<T> _db<T>(WidgetTester tester, Future<T> Function() read) async => (await tester.runAsync(read)) as T;

/// Lets database work finish without running out finite animations (the
/// undo toast would count down and leave).
Future<void> _settleShort(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('record screen: alerts on top, four tabs with seeded content', (tester) async {
    await pumpRecordApp(tester, home: const RecordScreen(animateBackdrop: false), seed: true);
    expect(find.text('ممنوع الكورتيزون بكل أشكاله'), findsOneWidget);
    expect(find.text('TSH'), findsOneWidget);
    expect(find.byType(LabFlagChip), findsWidgets);

    await tester.tap(find.text(_ar.recordTabAppointments));
    await settleRecord(tester);
    expect(find.text('مراجعة الغدد الصماء'), findsOneWidget);
    expect(find.text(_ar.recordAppointmentUpcoming), findsOneWidget);

    await tester.tap(find.text(_ar.recordTabQuestions));
    await settleRecord(tester);
    expect(find.text('هل أحتاج إلى فحص كثافة العظام؟'), findsOneWidget);
    expect(find.text(_ar.recordQuestionsGeneralHeader), findsOneWidget);

    await tester.tap(find.text(_ar.recordTabConditions));
    await settleRecord(tester);
    expect(find.text('قصور الغدة الدرقية'), findsOneWidget);
    expect(find.text(_ar.recordConditionsInactiveHeader), findsOneWidget);
  });

  testWidgets('empty record: add a standing alert from the hint (sound + undo toast)', (tester) async {
    final env = await pumpRecordApp(
      tester,
      home: const RecordScreen(animateBackdrop: false),
      locale: const Locale('en'),
    );
    expect(find.text(_en.recordLabsEmpty), findsOneWidget);
    await tester.tap(find.text(_en.recordAlertAdd));
    await settleRecord(tester);
    await tester.enterText(_fieldOf(_en.recordAlertBody).first, 'Allergic to penicillin');
    await tester.pump();
    await tester.tap(find.text(_en.recordAdd).last);
    await _settleShort(tester);
    expect(find.text(_en.recordAlertAdded), findsOneWidget);
    await settleRecord(tester);
    final alerts = await _db(tester, () => env.repos.healthAlerts.getAll());
    expect(alerts.single.body, 'Allergic to penicillin');
    expect(alerts.single.pinned, isTrue);
    expect(find.byType(HealthAlertCard), findsOneWidget);
    expect(env.sound.played, contains(Sfx.complete));
    await tester.pump(const Duration(seconds: 6));
    await settleRecord(tester);
  });

  testWidgets('add a condition with the FAB on the conditions tab', (tester) async {
    final env = await pumpRecordApp(
      tester,
      home: const RecordScreen(initialTab: RecordTab.conditions, animateBackdrop: false),
      locale: const Locale('en'),
    );
    await tester.tap(find.bySemanticsLabel(_en.recordConditionAdd).last);
    await settleRecord(tester);
    await tester.enterText(_fieldOf(_en.recordConditionName).first, 'Asthma');
    await tester.pump();
    await tester.tap(find.text(_en.recordAdd).last);
    await settleRecord(tester);
    expect((await _db(tester, () => env.repos.conditions.getAll())).single.name, 'Asthma');
    expect(find.text('Asthma'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await settleRecord(tester);
  });

  testWidgets('answering a question from its ring records the answer and a Health activity', (tester) async {
    final env = await pumpRecordApp(
      tester,
      home: const RecordScreen(initialTab: RecordTab.questions, animateBackdrop: false),
      locale: const Locale('en'),
      seed: true,
    );
    await tester.tap(find.bySemanticsLabel(_en.recordQuestionMarkAnswered).first);
    await settleRecord(tester);
    await tester.enterText(find.byType(TextField).last, 'After breakfast');
    await tester.pump();
    await tester.tap(find.text(_en.recordSave).last);
    await settleRecord(tester);
    final answered = (await _db(tester, () => env.repos.doctorQuestions.getAll())).where((q) => q.answered).toList();
    expect(answered.map((q) => q.answer), contains('After breakfast'));
    final logs = await _db(tester, () => env.repos.activity.since(DateTime(2000), planetKey: 'health'));
    expect(logs.where((a) => a.kind == RecordActivityKinds.questionAnswered), hasLength(2));
    await tester.pump(const Duration(seconds: 6));
    await settleRecord(tester);
  });

  testWidgets('lab visit: several results for one date in one save', (tester) async {
    final env = await pumpRecordApp(
      tester,
      home: const RecordScreen(animateBackdrop: false),
      locale: const Locale('en'),
      seed: true,
    );
    final before = await _db(tester, () => env.repos.labReadings.count());
    await tester.tap(find.text(_en.recordLabVisit).first);
    await settleRecord(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '2.2');
    await tester.enterText(fields.at(1), '1.1');
    await tester.pump();
    expect(find.text(_en.recordLabVisitSave(2, '2')), findsOneWidget);
    await tester.tap(find.text(_en.recordLabVisitSave(2, '2')));
    await settleRecord(tester);
    expect(await _db(tester, () => env.repos.labReadings.count()), before + 2);
    await tester.pump(const Duration(seconds: 6));
    await settleRecord(tester);
  });

  testWidgets('lab test screen: latest, neutral flag, chart with band and periods', (tester) async {
    await pumpRecordApp(tester, home: const _LabTestByName('TSH'), locale: const Locale('en'), seed: true);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text(_en.recordFlagBorderlineHigh), findsOneWidget);
    final range = RecordTexts(
      _en,
      const MadarFormatter(languageCode: 'en'),
    ).range(const LabRange(low: 0.4, high: 4), unit: 'mIU/L', decimals: 2);
    expect(BidiIsolate.strip(range!), '0.40 – 4.00 mIU/L');
    expect(find.text(range), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.rangeAnnotations.horizontalRangeAnnotations.single.y2, 4);
    expect(chart.data.lineBarsData.single.spots, hasLength(5), reason: '12 months');
    await tester.tap(find.text(_en.recordPeriodMonths(3, '3')));
    await settleRecord(tester);
    expect(tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.single.spots, hasLength(2));
    expect(find.bySemanticsLabel(RegExp('TSH trend')), findsOneWidget);
  });

  testWidgets('lab chart runs right-to-left in Arabic: the newest point is on the left', (tester) async {
    await pumpRecordApp(tester, home: const _LabTestByName('TSH'), seed: true);
    final spots = tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.single.spots;
    // Sorted by x: the leftmost is the latest reading (3.85), the rightmost the oldest (5.2).
    expect(spots.first.y, 3.85);
    expect(spots.last.y, 5.2);
  });

  testWidgets('doctor report: share builds the PDF; the name is stored only when asked', (tester) async {
    final env = await pumpRecordApp(
      tester,
      home: const RecordScreen(animateBackdrop: false),
      locale: const Locale('en'),
      seed: true,
    );
    await tester.tap(find.bySemanticsLabel(_en.recordDoctorReport).first);
    await settleRecord(tester);
    await tester.enterText(find.byType(TextField).first, 'Sara Ahmad');
    await tester.pump();
    await tester.tap(find.text(_en.recordReportShare));
    for (var i = 0; i < 30 && env.exporter.shared.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await settleRecord(tester);
    expect(env.exporter.shared, hasLength(1));
    final file = env.exporter.shared.single;
    expect(file.document.patientName, 'Sara Ahmad');
    expect(file.document.languageCode, 'en');
    expect(String.fromCharCodes(file.bytes.sublist(0, 4)), '%PDF');
    final service = env.container.read(recordServiceProvider);
    expect((await _db(tester, service.settings)).reportName, isNull);

    // Again, remembering the name and saving a file.
    await tester.tap(find.bySemanticsLabel(_en.recordDoctorReport).first);
    await settleRecord(tester);
    await tester.enterText(find.byType(TextField).first, 'Sara Ahmad');
    await tester.tap(find.byType(MadarSwitch));
    await tester.pump();
    await tester.tap(find.text(_en.recordReportSave));
    for (var i = 0; i < 30 && env.exporter.saved.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await settleRecord(tester);
    expect(env.exporter.saved, hasLength(1));
    expect(find.text(_en.recordReportSaved), findsOneWidget);
    expect((await _db(tester, service.settings)).reportName, 'Sara Ahmad');
  });

  testWidgets('hub cards: next appointment and flagged labs', (tester) async {
    await pumpRecordApp(
      tester,
      home: const Scaffold(body: Column(children: [NextAppointmentCard(), LabFlagsCard()])),
      locale: const Locale('en'),
      seed: true,
    );
    expect(find.text('Endocrinology follow-up'), findsOneWidget);
    expect(find.text(_en.recordAppointmentQuestions(2, '2')), findsOneWidget);
    expect(find.text(_en.recordLabFlaggedCount(3, '3')), findsOneWidget);
    expect(find.text('Ferritin'), findsOneWidget);
  });

  testWidgets('reduced motion renders the record without entrance motion', (tester) async {
    await pumpRecordApp(tester, home: const RecordScreen(animateBackdrop: false), seed: true, reducedMotion: true);
    expect(find.text('TSH'), findsOneWidget);
  });
}
