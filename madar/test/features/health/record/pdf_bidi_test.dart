import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/health/record/domain/lab_flags.dart';
import 'package:madar/features/health/record/domain/report_model.dart';
import 'package:madar/features/health/record/pdf/doctor_report_pdf.dart';
import 'package:madar/features/health/record/pdf/pdf_bidi.dart';
import 'package:madar/features/health/record/pdf/report_fonts.dart';

BidiWord r(String s) => BidiWord(s, rtl: true);
BidiWord l(String s) => BidiWord(s, rtl: false);

void main() {
  group('PdfBidi.layout', () {
    test('a pure line stays one word for the pdf package', () {
      expect(PdfBidi.layout('ممنوع الكورتيزون، بكل أشكاله', rtl: true), [r('ممنوع الكورتيزون، بكل أشكاله')]);
      expect(PdfBidi.layout('No cortisone 5 mg', rtl: false), [l('No cortisone 5 mg')]);
    });

    test('right-to-left: Latin groups stay together, a Western number joins them (W7), others stand alone', () {
      expect(PdfBidi.layout('Omega 3 مع الفطور', rtl: true), [l('Omega 3'), r('مع'), r('الفطور')]);
      expect(PdfBidi.layout('فيتامين د: ١٢٫٥ ng/mL منخفض', rtl: true), [
        r('فيتامين'),
        r('د:'),
        l('١٢٫٥'),
        l('ng/mL'),
        r('منخفض'),
      ]);
      expect(PdfBidi.layout('٨:٠٠ ص، ٨:٠٠ م', rtl: true), [l('٨:٠٠'), r('ص،'), l('٨:٠٠'), r('م')]);
      expect(PdfBidi.layout('Vitamin D3 IU مرة', rtl: true), [l('Vitamin D3 IU'), r('مرة')]);
    });

    test('left-to-right: an Arabic group becomes one right-to-left span', () {
      expect(PdfBidi.layout('Take مع ٣ أقراص daily', rtl: false), [
        l('Take'),
        const BidiSpan([BidiWord('مع', rtl: true), BidiWord('٣', rtl: false), BidiWord('أقراص', rtl: true)], rtl: true),
        l('daily'),
      ]);
      expect(PdfBidi.layout('Note: سلبي', rtl: false), [l('Note:'), r('سلبي')]);
    });

    test('brackets are mirrored in right-to-left words', () {
      expect(PdfBidi.layout('(ضمن المدى)', rtl: true), [r(')ضمن المدى(')]);
      expect(PdfBidi.mirror('[a](b)'), ']a[)b(');
    });

    test('clean: controls, spaces and what the bidi step cannot take', () {
      expect(PdfBidi.clean('\u2068أ\u2069\u200Fب\tج'), 'أب ج');
      expect(PdfBidi.clean('أُعدّ'), 'أعدّ', reason: 'a haraka after a hamza letter is dropped');
      expect(PdfBidi.clean('مُعدّ'), 'مُعدّ', reason: 'other harakat stay');
      expect(PdfBidi.clean('انتظر…'), 'انتظر...');
      expect(PdfBidi.clean('ﻻ بأس'), 'لا بأس');
      expect(PdfBidi.clean('ﷲ'), 'الله');
      expect(PdfBidi.strict('إِنْ ☺ ok'), 'إن   ok');
      expect(PdfBidi.hasArabic('abc ١٢'), isFalse);
      expect(PdfBidi.hasArabic('abc ب'), isTrue);
    });
  });

  test('tricky user text still builds a PDF in both directions', () async {
    final fonts = await ReportFontLoader(read: (path) async => ByteData.sublistView(File(path).readAsBytesSync()))
        .load();
    for (final lang in ['ar', 'en']) {
      final doc = ReportDocument(
        languageCode: lang,
        title: 'أُعدّ التقرير… ﷲ ﻷ',
        periodLine: 'Omega 3 (مع) الفطور؟ ٨:٠٠ ص',
        generatedLine: '\u2068x\u2069 إِنْ أَ ئُ',
        nameLabel: 'الاسم',
        patientName: 'Sara سارة',
        footer: 'f',
        pageLabel: (p, t) => '$p/$t',
        blocks: const [
          ReportAlertsBlock(
            title: 'تنبيهات',
            alerts: [
              ReportAlert(text: 'لا كورتيزون — AVN (رأس الفخذ)', severity: Severity.critical, severityLabel: 'x'),
            ],
          ),
          ReportLabsBlock(
            title: 'labs',
            columns: ['a', 'b', 'c', 'd', 'e'],
            legend: 'legend',
            groups: [
              ReportLabGroup(
                rows: [
                  ReportLabRow(
                    name: 'HbA1c',
                    latest: '٥٫٤ %',
                    latestDate: '١٢ سبتمبر',
                    flag: LabFlag.high,
                    flagLabel: 'مرتفع',
                    spark: ReportSpark(
                      points: [(x: 0, y: 1, flag: LabFlag.inRange), (x: 1, y: 3, flag: LabFlag.high)],
                      minY: 0,
                      maxY: 4,
                      low: 1,
                      high: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final bytes = await DoctorReportPdf.build(doc, fonts);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    }
  });
}
