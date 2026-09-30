import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// The bundled IBM Plex Sans Arabic faces embedded in the doctor report
/// (Arabic + Latin + Arabic-Indic digits in one family, so both languages
/// print with the app's own type).
class ReportFonts {
  const ReportFonts({required this.regular, required this.medium, required this.bold});

  final pw.Font regular;
  final pw.Font medium;
  final pw.Font bold;
}

/// Reads font files: the asset bundle in the app, the file system in tests.
typedef FontBytesReader = Future<ByteData> Function(String assetPath);

class ReportFontLoader {
  ReportFontLoader({FontBytesReader? read}) : _read = read ?? rootBundle.load;

  final FontBytesReader _read;
  Future<ReportFonts>? _fonts;

  static const String regularAsset = 'assets/fonts/IBMPlexSansArabic-Regular.ttf';
  static const String mediumAsset = 'assets/fonts/IBMPlexSansArabic-Medium.ttf';
  static const String boldAsset = 'assets/fonts/IBMPlexSansArabic-Bold.ttf';

  /// Loaded once, then shared.
  Future<ReportFonts> load() => _fonts ??= _load();

  Future<ReportFonts> _load() async {
    final (r, m, b) = await (_read(regularAsset), _read(mediumAsset), _read(boldAsset)).wait;
    return ReportFonts(regular: pw.Font.ttf(r), medium: pw.Font.ttf(m), bold: pw.Font.ttf(b));
  }
}
