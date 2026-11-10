import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/health/record/data/doctor_report.dart';
import 'package:madar/features/health/record/domain/lab_flags.dart';
import 'package:madar/features/health/record/domain/report_composer.dart';
import 'package:madar/features/health/record/domain/report_model.dart';
import 'package:madar/features/health/record/pdf/report_fonts.dart';

import '../../../helpers/test_app.dart';
import 'record_seed.dart';

ReportFontLoader fileFonts() =>
    ReportFontLoader(read: (path) async => ByteData.sublistView(File(path).readAsBytesSync()));

DoctorReportRequest requestFor(
  String lang, {
  Set<ReportSection>? sections,
  ReportPeriod period = ReportPeriod.months12,
  String? name,
}) => DoctorReportRequest(
  sections: sections ?? ReportSection.values.toSet(),
  period: period,
  now: recordTestNow,
  patientName: name,
  languageCode: lang,
);

Future<DoctorReportFile> buildReport(MadarDatabase db, String lang, {DoctorReportRequest? request}) {
  final builder = DoctorReportBuilder(dataSource: DoctorReportDataSource(Repositories(db)), fonts: fileFonts());
  return builder.build(
    request ?? requestFor(lang, name: lang == 'ar' ? 'سارة أحمد' : 'Sara Ahmad'),
    l: lookupL10n(Locale(lang)),
    fmt: MadarFormatter(languageCode: lang),
  );
}

void main() {
  late MadarDatabase db;

  tearDown(() => db.close());

  group('doctor report', () {
    for (final lang in ['ar', 'en']) {
      test('builds a PDF with the expected content ($lang)', () async {
        db = testDatabase(languageCode: lang, seed: false);
        await seedRecord(db, arabic: lang == 'ar');
        final file = await buildReport(db, lang);
        final l = lookupL10n(Locale(lang));

        expect(ascii.decode(file.bytes.sublist(0, 5)), '%PDF-');
        expect(file.bytes.length, greaterThan(20000), reason: 'fonts are embedded');
        expect(file.fileName, 'madar-health-report-2026-09-29.pdf');

        final doc = file.document;
        expect(doc.rtl, lang == 'ar');
        final texts = doc.texts.join('\n');
        expect(texts, contains(l.recordReportTitle));
        expect(doc.patientName, lang == 'ar' ? 'سارة أحمد' : 'Sara Ahmad');
        expect([for (final b in doc.blocks) b.section], ReportSection.values);

        final alerts = doc.blocks.whereType<ReportAlertsBlock>().single;
        expect(alerts.alerts.map((a) => a.text), hasLength(3));
        expect(alerts.alerts.first.text, lang == 'ar' ? 'ممنوع الكورتيزون بكل أشكاله' : 'No cortisone in any form');

        // Active conditions only.
        final conditions = doc.blocks.whereType<ReportItemsBlock>().first;
        expect(conditions.items, hasLength(2));

        final meds = doc.blocks.whereType<ReportTableBlock>().single;
        expect(meds.rows, hasLength(3));
        expect(meds.rows.map((r) => r.first).join(), contains('Omega 3'));

        final labs = doc.blocks.whereType<ReportLabsBlock>().single;
        final rows = {
          for (final g in labs.groups)
            for (final r in g.rows) r.name: r,
        };
        expect(rows['TSH']!.flag, LabFlag.borderlineHigh);
        expect(rows['TSH']!.spark, isNotNull);
        expect(rows['TSH']!.history, hasLength(ReportComposer.historyLimit));
        expect(rows['LDL']!.flag, LabFlag.borderlineHigh);
        expect(rows.values.where((r) => r.flag == LabFlag.low), hasLength(1), reason: 'ferritin 12 < 15');
        expect(rows.values.where((r) => r.flag == LabFlag.qualitative), hasLength(1));
        // Uncategorised tests come last, under "Other".
        expect(labs.groups.last.category, l.recordLabUncategorized);

        final stats = doc.blocks.whereType<ReportStatsBlock>().toList();
        expect(stats[0].stats.first.value, isNotEmpty);
        expect(stats[1].tagLines.single.tags.first.label, lang == 'ar' ? 'العمل' : 'Work');

        final questions = doc.blocks.whereType<ReportItemsBlock>().last;
        expect(questions.items, hasLength(3), reason: 'open questions only');
        expect(questions.items.first.meta, isNotNull, reason: 'tied to the endocrinology visit');

        // Nothing interpretive: every flag label is one of the neutral ones.
        final neutral = {
          l.recordFlagLow,
          l.recordFlagHigh,
          l.recordFlagBorderlineLow,
          l.recordFlagBorderlineHigh,
          l.recordFlagInRange,
          l.recordFlagNoRange,
          l.recordFlagQualitative,
        };
        expect(rows.values.map((r) => r.flagLabel).toSet().difference(neutral), isEmpty);
        if (lang == 'ar') expect(texts, contains('٣٫٨٥'), reason: 'Arabic-Indic digits');
      });
    }

    test('only the chosen sections, an empty period says so, no name → blank line', () async {
      db = testDatabase(seed: false);
      await seedRecord(db);
      final file = await buildReport(
        db,
        'ar',
        request: requestFor('ar', sections: {ReportSection.labs, ReportSection.pain}, period: ReportPeriod.months1),
      );
      final doc = file.document;
      expect(doc.patientName, isNull);
      expect([for (final b in doc.blocks) b.section], [ReportSection.labs, ReportSection.pain]);
      final labs = doc.blocks.first as ReportLabsBlock;
      // Only the 12 Sep visit is inside one month.
      expect(labs.groups.expand((g) => g.rows).every((r) => r.history.isEmpty), isTrue);
      expect(ascii.decode(file.bytes.sublist(0, 5)), '%PDF-');
    });

    test('empty record still builds', () async {
      db = testDatabase(seed: false);
      final file = await buildReport(db, 'en', request: requestFor('en'));
      expect(file.document.blocks.every((b) => b.isEmpty), isTrue);
      expect(file.document.texts, contains(lookupL10n(const Locale('en')).recordReportNothing));
      expect(ascii.decode(file.bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
