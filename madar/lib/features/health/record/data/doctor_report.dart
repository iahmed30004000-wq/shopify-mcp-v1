import 'dart:io';

import 'package:drift/drift.dart' hide Table;
import 'package:file_picker/file_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../domain/lab_flags.dart';
import '../domain/report_composer.dart';
import '../domain/report_model.dart';
import '../pdf/doctor_report_pdf.dart';
import '../pdf/report_fonts.dart';

/// Reads what the doctor report needs straight from the tables: pinned
/// alerts, active conditions, active medications (the medications package's
/// table, read-only), lab tests + readings, pain / mood entries of the
/// period, open questions and appointments.
class DoctorReportDataSource {
  DoctorReportDataSource(this.repos);

  final Repositories repos;

  Future<DoctorReportData> load(DoctorReportRequest request, {double margin = LabFlags.defaultMargin}) async {
    final from = request.from;
    final db = repos.db;
    Future<List<T>> maybe<T>(ReportSection s, Future<List<T>> Function() read) async =>
        request.includes(s) ? read() : <T>[];

    final alerts = await maybe(
      ReportSection.alerts,
      () => repos.healthAlerts.getAll(where: (t) => t.pinned.equals(true)),
    );
    final conditions = await maybe(
      ReportSection.conditions,
      () => repos.conditions.getAll(where: (t) => t.active.equals(true)),
    );
    final meds = await maybe(
      ReportSection.medications,
      () => repos.medications.getAll(where: (t) => t.active.equals(true)),
    );
    final tests = await maybe(ReportSection.labs, () => repos.labTests.getAll());
    final readings = await maybe(ReportSection.labs, () => repos.labReadings.getAll());
    final pains = await maybe(
      ReportSection.pain,
      () =>
          (db.select(db.painEntries)..where(
                (t) => from == null
                    ? const Constant(true)
                    : t.at.julianday.isBiggerOrEqual(Variable<DateTime>(from).julianday),
              ))
              .get(),
    );
    final moods = await maybe(
      ReportSection.mood,
      () =>
          (db.select(db.moodEntries)..where(
                (t) => from == null
                    ? const Constant(true)
                    : t.at.julianday.isBiggerOrEqual(Variable<DateTime>(from).julianday),
              ))
              .get(),
    );
    final questions = await maybe(
      ReportSection.questions,
      () => repos.doctorQuestions.getAll(where: (t) => t.answered.equals(false)),
    );
    final appointments = await maybe(ReportSection.questions, () => repos.appointments.getAll());
    final needsTags = request.includes(ReportSection.pain) || request.includes(ReportSection.mood);
    final tags = needsTags ? await repos.tagOptions.getAll() : const <TagOptionRow>[];
    return DoctorReportData(
      alerts: alerts,
      conditions: conditions,
      medications: meds,
      tests: tests,
      readings: readings,
      pains: pains,
      moods: moods,
      questions: questions,
      appointments: appointments,
      tagLabels: {for (final t in tags) t.id: t.label},
      margin: margin,
    );
  }
}

/// A built report.
class DoctorReportFile {
  const DoctorReportFile({required this.bytes, required this.fileName, required this.document});

  final Uint8List bytes;

  /// ASCII only, no personal data: `madar-health-report-2026-09-29.pdf`.
  final String fileName;
  final ReportDocument document;

  static String fileNameFor(DateTime day) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'madar-health-report-${day.year}-${two(day.month)}-${two(day.day)}.pdf';
  }
}

/// Data → document → PDF bytes, all on the device.
class DoctorReportBuilder {
  DoctorReportBuilder({required this.dataSource, required this.fonts});

  final DoctorReportDataSource dataSource;
  final ReportFontLoader fonts;

  Future<DoctorReportFile> build(
    DoctorReportRequest request, {
    required L10n l,
    required MadarFormatter fmt,
    double margin = LabFlags.defaultMargin,
  }) async {
    await initializeDateFormatting();
    final data = await dataSource.load(request, margin: margin);
    final doc = ReportComposer(l, fmt).compose(request, data);
    final bytes = await DoctorReportPdf.build(doc, await fonts.load());
    return DoctorReportFile(bytes: bytes, fileName: DoctorReportFile.fileNameFor(request.today), document: doc);
  }
}

/// Hands the PDF to the user: the share sheet, or a save-as dialog.
abstract interface class ReportExporter {
  Future<void> share(DoctorReportFile file, {String? subject});

  /// True when the user picked a place and the file was written.
  Future<bool> save(DoctorReportFile file);
}

class PlatformReportExporter implements ReportExporter {
  const PlatformReportExporter();

  @override
  Future<void> share(DoctorReportFile file, {String? subject}) async {
    // Written to the app's own cache (overwritten by the next report).
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/${file.fileName}');
    await out.writeAsBytes(file.bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(out.path, mimeType: 'application/pdf')],
        subject: subject,
        title: subject,
      ),
    );
  }

  @override
  Future<bool> save(DoctorReportFile file) async {
    final uri = await FilePicker.saveFile(
      fileName: file.fileName,
      bytes: file.bytes,
      mimeType: 'application/pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    return uri != null;
  }
}

/// Records exports (tests, previews).
class RecordingReportExporter implements ReportExporter {
  final List<DoctorReportFile> shared = [];
  final List<DoctorReportFile> saved = [];
  bool saveResult = true;

  @override
  Future<void> share(DoctorReportFile file, {String? subject}) async => shared.add(file);

  @override
  Future<bool> save(DoctorReportFile file) async {
    saved.add(file);
    return saveResult;
  }
}
