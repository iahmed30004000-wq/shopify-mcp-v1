import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/domain/enums.dart';
import '../domain/lab_flags.dart';
import '../domain/report_model.dart';
import 'pdf_bidi.dart';
import 'report_fonts.dart';

/// A calm print palette (the report is paper, not a themed screen: dark ink
/// on white, one lapis accent and a touch of astrolabe gold).
abstract final class ReportInk {
  static const ink = PdfColor.fromInt(0xFF1D2330);
  static const muted = PdfColor.fromInt(0xFF5A6173);
  static const faint = PdfColor.fromInt(0xFF8C92A1);
  static const hairline = PdfColor.fromInt(0xFFDCE0E7);
  static const zebra = PdfColor.fromInt(0xFFF6F7F9);
  static const accent = PdfColor.fromInt(0xFF1F3F7A);
  static const band = PdfColor.fromInt(0xFFE3EAF6);
  static const gold = PdfColor.fromInt(0xFFB08A3E);
  static const danger = PdfColor.fromInt(0xFFA3261F);
  static const dangerSoft = PdfColor.fromInt(0xFFFBECEA);
  static const warning = PdfColor.fromInt(0xFF8A5A00);
  static const warningSoft = PdfColor.fromInt(0xFFFFF3D9);
  static const info = PdfColor.fromInt(0xFF1E5A8C);
  static const infoSoft = PdfColor.fromInt(0xFFE8F1F9);
  static const neutralSoft = PdfColor.fromInt(0xFFEEF0F3);

  static PdfColor flag(LabFlag f) => switch (f) {
    LabFlag.low || LabFlag.high => danger,
    LabFlag.borderlineLow || LabFlag.borderlineHigh => warning,
    LabFlag.inRange => muted,
    _ => faint,
  };

  static PdfColor flagSoft(LabFlag f) => switch (f) {
    LabFlag.low || LabFlag.high => dangerSoft,
    LabFlag.borderlineLow || LabFlag.borderlineHigh => warningSoft,
    _ => neutralSoft,
  };

  static PdfColor severity(Severity s) => switch (s) {
    Severity.critical => danger,
    Severity.warning => warning,
    Severity.info => info,
  };

  static PdfColor severitySoft(Severity s) => switch (s) {
    Severity.critical => dangerSoft,
    Severity.warning => warningSoft,
    Severity.info => infoSoft,
  };
}

/// Lays a [ReportDocument] out as an A4 PDF: Arabic right-to-left with the
/// bundled Arabic font embedded, English left-to-right.
class DoctorReportPdf {
  DoctorReportPdf._(this.doc, this.fonts, {this.strict = false});

  final ReportDocument doc;
  final ReportFonts fonts;

  /// Last-resort text cleaning (see [PdfBidi.strict]).
  final bool strict;

  bool get rtl => doc.rtl;
  pw.TextDirection get _dir => rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  static const double margin = 40;

  /// Renders [doc] and returns the PDF bytes. Should laying out some user
  /// text fail, the report is rebuilt once with strictly cleaned text, so a
  /// report is always produced.
  static Future<Uint8List> build(
    ReportDocument doc,
    ReportFonts fonts, {
    PdfPageFormat format = PdfPageFormat.a4,
    bool compress = true,
  }) async {
    try {
      return await DoctorReportPdf._(doc, fonts)._render(format, compress);
    } catch (e) {
      debugPrint('doctor report: strict text fallback after $e');
      return DoctorReportPdf._(doc, fonts, strict: true)._render(format, compress);
    }
  }

  Future<Uint8List> _render(PdfPageFormat format, bool compress) {
    final pdf = pw.Document(
      title: doc.metaTitle,
      creator: 'Madar',
      producer: 'Madar',
      compress: compress,
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold, fontFallback: [fonts.regular]),
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(margin, margin - 6, margin, margin - 10),
        textDirection: _dir,
        maxPages: 80,
        header: _runningHeader,
        footer: _footer,
        build: (_) => _body(format.width - 2 * margin),
      ),
    );
    return pdf.save();
  }

  // ------------------------------------------------------------------ text

  /// Arabic words need a wider gap than the font's narrow space: a final
  /// reh / teh marbuta tail otherwise reaches the next word.
  double get _wordGap => rtl ? 0.36 : 0.26;

  pw.TextStyle _style(double size, PdfColor color, {pw.Font? font}) => pw.TextStyle(
    font: font ?? fonts.regular,
    fontSize: size,
    color: color,
    lineSpacing: size * 0.35,
    wordSpacing: rtl ? 1.7 : 1.0,
  );

  /// Bidi-safe text: every line laid out by [PdfBidi].
  pw.Widget _text(String text, {double size = 10, PdfColor color = ReportInk.ink, pw.Font? font, bool center = false}) {
    final style = _style(size, color, font: font);
    final lines = (strict ? PdfBidi.strict(text) : PdfBidi.clean(text))
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return pw.SizedBox();
    final widgets = [for (final line in lines) _line(line, style, center: center)];
    if (widgets.length == 1) return widgets.single;
    return pw.Column(
      crossAxisAlignment: center ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  pw.Widget _line(String line, pw.TextStyle style, {bool center = false}) {
    final items = PdfBidi.layout(line, rtl: rtl);
    if (items.length == 1 && items.single is BidiWord) {
      final w = items.single as BidiWord;
      return pw.Text(
        w.text,
        style: style,
        textDirection: w.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.start,
      );
    }
    return pw.Wrap(
      spacing: style.fontSize! * _wordGap,
      runSpacing: style.fontSize! * 0.2,
      alignment: center ? pw.WrapAlignment.center : pw.WrapAlignment.start,
      crossAxisAlignment: pw.WrapCrossAlignment.center,
      children: [for (final i in items) _item(i, style)],
    );
  }

  pw.Widget _item(BidiItem item, pw.TextStyle style) => switch (item) {
    BidiWord(:final text, rtl: final r) => pw.Text(
      text,
      style: style,
      textDirection: r ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    ),
    BidiSpan(:final items, rtl: final r) => pw.Directionality(
      textDirection: r ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Wrap(
        spacing: style.fontSize! * _wordGap,
        crossAxisAlignment: pw.WrapCrossAlignment.center,
        children: [for (final i in items) _item(i, style)],
      ),
    ),
  };

  // ---------------------------------------------------------------- chrome

  pw.Widget _star(double size, PdfColor color) => pw.CustomPaint(
    size: PdfPoint(size, size),
    painter: (canvas, s) {
      final c = PdfPoint(s.x / 2, s.y / 2);
      final r = s.x / 2;
      final inner = r * 0.42;
      canvas.setFillColor(color);
      for (var i = 0; i < 16; i++) {
        final a = math.pi / 2 + i * math.pi / 8;
        final rr = i.isEven ? r : inner;
        final p = PdfPoint(c.x + rr * math.cos(a), c.y + rr * math.sin(a));
        if (i == 0) {
          canvas.moveTo(p.x, p.y);
        } else {
          canvas.lineTo(p.x, p.y);
        }
      }
      canvas.fillPath();
    },
  );

  pw.Widget _hairline({PdfColor color = ReportInk.hairline, double height = 0.7}) =>
      pw.Container(height: height, color: color);

  pw.Widget _runningHeader(pw.Context context) {
    if (context.pageNumber == 1) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              _star(7, ReportInk.gold),
              pw.SizedBox(width: 5),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [_text(doc.title, size: 8.5, color: ReportInk.muted, font: fonts.medium)],
                ),
              ),
              if (doc.patientName != null) _text(doc.patientName!, size: 8.5, color: ReportInk.muted),
            ],
          ),
          pw.SizedBox(height: 4),
          _hairline(),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context context) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8),
    child: pw.Column(
      children: [
        _hairline(),
        pw.SizedBox(height: 5),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [_text(doc.footer, size: 7.5, color: ReportInk.faint)],
              ),
            ),
            pw.SizedBox(width: 16),
            _text(doc.pageLabel(context.pageNumber, context.pagesCount), size: 8, color: ReportInk.muted),
          ],
        ),
      ],
    ),
  );

  // ------------------------------------------------------------------ body

  List<pw.Widget> _body(double width) => [_header(), for (final b in doc.blocks) ..._block(b, width)];

  pw.Widget _header() {
    final name = doc.patientName;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _text(doc.title, size: 20, color: ReportInk.accent, font: fonts.bold),
                  pw.SizedBox(height: 4),
                  _text(doc.periodLine, size: 9.5, color: ReportInk.muted),
                  pw.SizedBox(height: 1),
                  _text(doc.generatedLine, size: 9.5, color: ReportInk.muted),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            _star(26, ReportInk.gold),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _text(doc.nameLabel, size: 9.5, color: ReportInk.muted, font: fonts.medium),
            pw.SizedBox(width: 10),
            if (name != null)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [_text(name, size: 13, font: fonts.bold)],
                ),
              )
            else
              // A line to write the name on by hand.
              pw.Expanded(
                child: pw.Container(
                  height: 16,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: ReportInk.faint, width: 0.6, style: pw.BorderStyle.dotted),
                    ),
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 12),
        _hairline(color: ReportInk.accent, height: 1.6),
        pw.SizedBox(height: 2),
        _hairline(color: ReportInk.gold, height: 0.5),
      ],
    );
  }

  pw.Widget _sectionTitle(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            _star(8, ReportInk.gold),
            pw.SizedBox(width: 6),
            _text(title, size: 12.5, color: ReportInk.accent, font: fonts.bold),
          ],
        ),
        pw.SizedBox(height: 5),
        _hairline(),
      ],
    ),
  );

  pw.Widget _empty(String? text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [_text(text ?? '', size: 9.5, color: ReportInk.faint)],
    ),
  );

  /// The section title travels with its first row (never orphaned at the
  /// bottom of a page).
  List<pw.Widget> _block(ReportBlock b, double width) {
    final content = b.isEmpty
        ? [_empty(b.emptyText)]
        : switch (b) {
            ReportAlertsBlock() => _alerts(b),
            ReportItemsBlock() => b.section == ReportSection.questions ? _questions(b) : _items(b),
            ReportTableBlock() => _table(b),
            ReportLabsBlock() => _labs(b),
            ReportStatsBlock() => _stats(b, width),
          };
    return [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [_sectionTitle(b.title), if (content.isNotEmpty) content.first],
      ),
      ...content.skip(1),
    ];
  }

  List<pw.Widget> _alerts(ReportAlertsBlock b) => [
    for (final a in b.alerts)
      pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 6),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(
          color: ReportInk.severitySoft(a.severity),
          border: rtl
              ? pw.Border(right: pw.BorderSide(color: ReportInk.severity(a.severity), width: 3.2))
              : pw.Border(left: pw.BorderSide(color: ReportInk.severity(a.severity), width: 3.2)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _text(a.severityLabel, size: 8, color: ReportInk.severity(a.severity), font: fonts.medium),
            pw.SizedBox(height: 1),
            _text(a.text, size: 11.5, font: fonts.bold),
          ],
        ),
      ),
  ];

  List<pw.Widget> _items(ReportItemsBlock b) => [
    for (final i in b.items)
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: ReportInk.hairline, width: 0.5)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [_text(i.title, size: 10.5, font: fonts.medium)],
                  ),
                ),
                if (i.meta != null) ...[pw.SizedBox(width: 10), _text(i.meta!, size: 8.5, color: ReportInk.muted)],
              ],
            ),
            if (i.detail != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [_text(i.detail!, size: 9.5, color: ReportInk.muted)],
                ),
              ),
          ],
        ),
      ),
  ];

  List<pw.Widget> _questions(ReportItemsBlock b) => [
    for (final i in b.items)
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Container(
                width: 9,
                height: 9,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: ReportInk.muted, width: 0.7),
                  borderRadius: pw.BorderRadius.circular(1.5),
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _text(i.title, size: 10.5),
                  if (i.meta != null) _text(i.meta!, size: 8, color: ReportInk.faint),
                ],
              ),
            ),
          ],
        ),
      ),
  ];

  pw.Widget _cell(pw.Widget child, int flex) => pw.Expanded(
    flex: flex,
    child: pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [child]),
    ),
  );

  pw.Widget _headerRow(List<(String, int)> columns) => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 4, top: 2),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: ReportInk.muted, width: 0.8)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        for (final (h, flex) in columns) _cell(_text(h, size: 8, color: ReportInk.muted, font: fonts.medium), flex),
      ],
    ),
  );

  List<pw.Widget> _table(ReportTableBlock b) => _withHead(_headerRow([for (final c in b.columns) (c.header, c.flex)]), [
    for (var r = 0; r < b.rows.length; r++)
      pw.Container(
        color: r.isOdd ? ReportInk.zebra : null,
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < b.columns.length; c++)
              _cell(
                _text(
                  c < b.rows[r].length ? b.rows[r][c] : '',
                  size: c == 0 ? 10 : 9.5,
                  font: c == 0 ? fonts.medium : null,
                  color: c == 0 ? ReportInk.ink : ReportInk.muted,
                ),
                b.columns[c].flex,
              ),
          ],
        ),
      ),
  ]);

  /// [head] glued to the first of [rows].
  List<pw.Widget> _withHead(pw.Widget head, List<pw.Widget> rows) => [
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [head, ?rows.firstOrNull]),
    ...rows.skip(1),
  ];

  pw.Widget _chip(String label, PdfColor fg, PdfColor bg) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(6)),
    child: _text(label, size: 7.5, color: fg, font: fonts.medium),
  );

  List<pw.Widget> _labs(ReportLabsBlock b) {
    const flexes = [26, 26, 17, 15, 20];
    final out = <pw.Widget>[];
    for (final g in b.groups) {
      final head = <pw.Widget>[];
      final rows = <pw.Widget>[];
      if (g.category != null) {
        head.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 4,
                  height: 4,
                  decoration: const pw.BoxDecoration(color: ReportInk.gold, shape: pw.BoxShape.circle),
                ),
                pw.SizedBox(width: 5),
                _text(g.category!, size: 9.5, color: ReportInk.accent, font: fonts.medium),
              ],
            ),
          ),
        );
      }
      head.add(_headerRow([for (var i = 0; i < b.columns.length; i++) (b.columns[i], flexes[i])]));
      for (final r in g.rows) {
        rows.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: ReportInk.hairline, width: 0.5)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _cell(
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _text(r.name, size: 10, font: fonts.bold),
                      if (r.unit != null) _text(r.unit!, size: 8, color: ReportInk.faint),
                    ],
                  ),
                  flexes[0],
                ),
                _cell(
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _text(
                        r.latest,
                        size: 11,
                        font: fonts.bold,
                        color: r.flag.isOutOfRange ? ReportInk.danger : ReportInk.ink,
                      ),
                      pw.SizedBox(height: 2),
                      if (r.flag != LabFlag.qualitative)
                        _chip(r.flagLabel, ReportInk.flag(r.flag), ReportInk.flagSoft(r.flag)),
                      pw.SizedBox(height: 2),
                      _text(r.latestDate, size: 7.5, color: ReportInk.faint),
                    ],
                  ),
                  flexes[1],
                ),
                _cell(_text(r.range ?? '—', size: 9, color: ReportInk.muted), flexes[2]),
                _cell(r.spark == null ? _text('—', size: 9, color: ReportInk.faint) : _spark(r.spark!), flexes[3]),
                _cell(
                  r.history.isEmpty
                      ? _text('—', size: 9, color: ReportInk.faint)
                      : pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            for (final h in r.history)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 1.5),
                                child: pw.Row(
                                  mainAxisSize: pw.MainAxisSize.min,
                                  children: [
                                    _text(h.date, size: 7.5, color: ReportInk.faint),
                                    pw.SizedBox(width: 5),
                                    _text(
                                      h.value,
                                      size: 8.5,
                                      color: h.flag.isOutOfRange
                                          ? ReportInk.danger
                                          : h.flag.isBorderline
                                          ? ReportInk.warning
                                          : ReportInk.muted,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                  flexes[4],
                ),
              ],
            ),
          ),
        );
      }
      out.addAll(_withHead(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: head), rows));
    }
    out.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [_text(b.legend, size: 7.5, color: ReportInk.faint)],
        ),
      ),
    );
    return out;
  }

  pw.Widget _spark(ReportSpark s) => pw.CustomPaint(
    size: const PdfPoint(64, 24),
    painter: (canvas, size) {
      final w = size.x, h = size.y;
      final span = s.maxY - s.minY == 0 ? 1.0 : s.maxY - s.minY;
      double y(double v) => 3 + (v.clamp(s.minY, s.maxY) - s.minY) / span * (h - 6);
      double x(double f) => 3 + f.clamp(0.0, 1.0) * (w - 6);
      if (s.low != null || s.high != null) {
        final lo = y(s.low ?? s.minY), hi = y(s.high ?? s.maxY);
        canvas
          ..setFillColor(ReportInk.band)
          ..drawRect(0, math.min(lo, hi), w, (hi - lo).abs())
          ..fillPath();
      }
      final pts = [...s.points]..sort((a, b) => a.x.compareTo(b.x));
      canvas
        ..setStrokeColor(ReportInk.accent)
        ..setLineWidth(0.9)
        ..setLineJoin(PdfLineJoin.round)
        ..setLineCap(PdfLineCap.round);
      for (var i = 0; i < pts.length; i++) {
        if (i == 0) {
          canvas.moveTo(x(pts[i].x), y(pts[i].y));
        } else {
          canvas.lineTo(x(pts[i].x), y(pts[i].y));
        }
      }
      canvas.strokePath();
      for (final p in pts) {
        canvas
          ..setFillColor(p.flag.isFlagged ? ReportInk.flag(p.flag) : ReportInk.accent)
          ..drawEllipse(x(p.x), y(p.y), 1.7, 1.7)
          ..fillPath();
      }
    },
  );

  List<pw.Widget> _stats(ReportStatsBlock b, double width) {
    const perRow = 4;
    const gap = 8.0;
    final tileWidth = (width - gap * (perRow - 1)) / perRow;
    return [
      pw.Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final s in b.stats)
            pw.Container(
              width: tileWidth,
              padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: pw.BoxDecoration(color: ReportInk.zebra, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _text(s.label, size: 7.5, color: ReportInk.muted),
                  pw.SizedBox(height: 2),
                  _text(s.value, size: 14, font: fonts.bold),
                ],
              ),
            ),
        ],
      ),
      for (final t in b.tagLines)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 118,
                child: _text(t.label, size: 8.5, color: ReportInk.muted, font: fonts.medium),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in t.tags)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: ReportInk.hairline, width: 0.7),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            _text(tag.label, size: 8.5),
                            pw.SizedBox(width: 4),
                            _text(tag.count, size: 8.5, color: ReportInk.accent, font: fonts.bold),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }
}
