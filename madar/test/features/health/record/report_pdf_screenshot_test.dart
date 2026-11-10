@Tags(['screenshot'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_app.dart';
import 'doctor_report_test.dart' show buildReport;
import 'record_seed.dart';

/// Writes the doctor report PDFs to screenshots/phase4/record/ for a visual
/// check (rendered to PNG outside Flutter, e.g. with MuPDF).
void main() {
  for (final lang in ['ar', 'en']) {
    test('writes screenshots/phase4/record/report_$lang.pdf', () async {
      final db = testDatabase(languageCode: lang, seed: false);
      addTearDown(db.close);
      await seedRecord(db, arabic: lang == 'ar');
      final file = await buildReport(db, lang);
      File('screenshots/phase4/record/report_$lang.pdf')
        ..createSync(recursive: true)
        ..writeAsBytesSync(file.bytes);
    });
  }
}
