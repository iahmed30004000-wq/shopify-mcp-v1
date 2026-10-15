/// Medical record: standing alerts, conditions, labs with trend charts,
/// appointments with reminders, questions for the doctor and the doctor
/// report (PDF). Tracking only – values, the user's own ranges and neutral
/// flags; never interpretation or advice.
library;

export 'data/appointment_reminders.dart';
export 'data/doctor_report.dart';
export 'data/record_providers.dart';
export 'data/record_service.dart';
export 'domain/appointment_plan.dart';
export 'domain/health_summaries.dart';
export 'domain/lab_flags.dart';
export 'domain/lab_series.dart';
export 'domain/record_settings.dart';
export 'domain/record_texts.dart';
export 'domain/report_composer.dart';
export 'domain/report_model.dart';
export 'pdf/doctor_report_pdf.dart' show DoctorReportPdf, ReportInk;
export 'pdf/pdf_bidi.dart';
export 'pdf/report_fonts.dart';
export 'presentation/appointments_screen.dart';
export 'presentation/doctor_report_sheet.dart';
export 'presentation/lab_test_screen.dart';
export 'presentation/lab_visit_sheet.dart';
export 'presentation/record_actions.dart';
export 'presentation/record_navigation.dart';
export 'presentation/record_screen.dart';
export 'presentation/record_sheets.dart';
export 'presentation/record_ui.dart';
export 'presentation/widgets/health_alerts_banner.dart';
export 'presentation/widgets/hub_cards.dart';
export 'presentation/widgets/lab_bits.dart';
export 'presentation/widgets/lab_trend_chart.dart';
export 'presentation/widgets/record_tiles.dart';
