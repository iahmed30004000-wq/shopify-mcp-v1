import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import 'health_summaries.dart';
import 'lab_series.dart';
import 'record_texts.dart';
import 'report_model.dart';

/// Turns the report's raw data into a localised [ReportDocument]. Pure: the
/// same inputs always give the same document (tests read it directly).
///
/// Only the user's own records are shown – values, dates, their own
/// reference ranges and neutral flags, counts and averages. Nothing is
/// interpreted.
class ReportComposer {
  ReportComposer(this.l, this.fmt) : texts = RecordTexts(l, fmt, isolate: false);

  final L10n l;
  final MadarFormatter fmt;
  final RecordTexts texts;

  /// Earlier readings listed per test.
  static const int historyLimit = 4;

  ReportDocument compose(DoctorReportRequest request, DoctorReportData data) {
    final from = request.from;
    final today = request.today;
    final blocks = <ReportBlock>[
      for (final s in ReportSection.values)
        if (request.includes(s))
          switch (s) {
            ReportSection.alerts => _alerts(data),
            ReportSection.conditions => _conditions(data),
            ReportSection.medications => _medications(data),
            ReportSection.labs => _labs(data, from, today, rtl: request.languageCode == 'ar'),
            ReportSection.pain => _pain(data),
            ReportSection.mood => _mood(data),
            ReportSection.questions => _questions(data),
          },
    ];
    final name = request.patientName?.trim();
    return ReportDocument(
      languageCode: request.languageCode,
      title: l.recordReportTitle,
      metaTitle: l.recordReportTitle,
      periodLine: from == null
          ? l.recordReportPeriodAll(_date(today))
          : l.recordReportPeriodLine(_date(from), _date(today)),
      generatedLine: l.recordReportGenerated(_date(today)),
      nameLabel: l.recordReportNameLabel,
      patientName: name == null || name.isEmpty ? null : name,
      footer: l.recordReportFooter,
      pageLabel: (page, total) => l.recordReportPage(fmt.formatInt(page), fmt.formatInt(total)),
      blocks: blocks,
    );
  }

  String _date(DateTime d) => fmt.formatDate(d, style: MadarDateStyle.medium);
  String get _nothing => l.recordReportNothing;

  ReportBlock _alerts(DoctorReportData data) => ReportAlertsBlock(
    title: l.recordSectionAlerts,
    emptyText: _nothing,
    alerts: [
      for (final a in data.alerts)
        if (a.body.trim().isNotEmpty)
          ReportAlert(text: a.body.trim(), severity: a.severity, severityLabel: texts.severity(a.severity)),
    ],
  );

  ReportBlock _conditions(DoctorReportData data) => ReportItemsBlock(
    section: ReportSection.conditions,
    title: l.recordSectionConditions,
    emptyText: _nothing,
    items: [
      for (final c in data.conditions)
        ReportItem(
          title: c.name.trim(),
          detail: c.notes?.trim().isEmpty ?? true ? null : c.notes!.trim(),
          meta: c.since == null ? null : l.recordConditionSince(_date(c.since!)),
        ),
    ],
  );

  ReportBlock _medications(DoctorReportData data) {
    final meds = [...data.medications]
      ..sort((a, b) {
        final k = a.kind.index.compareTo(b.kind.index);
        return k != 0 ? k : a.sortOrder.compareTo(b.sortOrder);
      });
    return ReportTableBlock(
      section: ReportSection.medications,
      title: l.recordSectionMedications,
      emptyText: _nothing,
      columns: [
        ReportColumn(l.recordReportColName, flex: 3),
        ReportColumn(l.recordReportColDose, flex: 2),
        ReportColumn(l.recordReportColTimes, flex: 3),
        ReportColumn(l.recordReportColWith, flex: 2),
      ],
      rows: [
        for (final m in meds)
          [
            m.kind == MedKind.supplement ? l.recordReportSupplementName(m.name.trim()) : m.name.trim(),
            texts.dose(m) ?? '—',
            m.times.isEmpty ? '—' : texts.times(m.times),
            m.takenWith == TakenWith.anytime
                ? (m.takenWithNote?.trim().isNotEmpty ?? false ? m.takenWithNote!.trim() : '—')
                : texts.takenWith(m.takenWith),
          ],
      ],
    );
  }

  ReportBlock _labs(DoctorReportData data, DateTime? from, DateTime today, {required bool rtl}) {
    final byTest = LabSeries.byTest(data.readings);
    final groups = <String?, List<ReportLabRow>>{};
    final order = <String?>[];
    final tests = [...data.tests]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final t in tests) {
      final all = LabSeries.points(byTest[t.id] ?? const [], t, margin: data.margin);
      final inPeriod = from == null
          ? all
          : [
              for (final p in all)
                if (!p.date.isBefore(from)) p,
            ];
      if (inPeriod.isEmpty) continue;
      final decimals = LabDecimals.forTest(t, inPeriod);
      final latest = inPeriod.last;
      final range = LabSeries.rangeOf(t);
      final numeric = [
        for (final p in inPeriod)
          if (p.value != null) p,
      ];
      ReportSpark? spark;
      if (numeric.length >= 2) {
        final axis = ChartTimeAxis.covering(
          numeric.map((p) => p.date),
          rtl: rtl,
          from: from,
          to: today,
          padFraction: 0,
        );
        final scale = LabChartScale.of(numeric.map((p) => p.value!), range: range);
        spark = ReportSpark(
          points: [for (final p in numeric) (x: axis.fraction(p.date), y: p.value!, flag: p.flag)],
          minY: scale.minY,
          maxY: scale.maxY,
          low: range.ordered.$1,
          high: range.ordered.$2,
        );
      }
      final key = (t.category?.trim().isEmpty ?? true) ? null : t.category!.trim();
      if (!groups.containsKey(key)) order.add(key);
      (groups[key] ??= []).add(
        ReportLabRow(
          name: t.name.trim(),
          unit: t.unit?.trim().isEmpty ?? true ? null : t.unit!.trim(),
          range: texts.range(range, decimals: decimals),
          latest: texts.reading(latest, decimals: decimals),
          latestDate: _date(latest.date),
          flag: latest.flag,
          flagLabel: texts.flag(latest.flag),
          history: [
            for (final p in inPeriod.reversed.skip(1).take(historyLimit))
              (
                date: texts.compactDate(p.date),
                value: texts.reading(p, decimals: decimals),
                flag: p.flag,
              ),
          ],
          spark: spark,
        ),
      );
    }
    // Uncategorised tests last (List.sort is not stable – rebuild instead).
    final ordered = [...order.whereType<String>(), if (order.contains(null)) null];
    return ReportLabsBlock(
      title: l.recordSectionLabs,
      emptyText: _nothing,
      columns: [
        l.recordReportColTest,
        l.recordReportColLatest,
        l.recordReportColRange,
        l.recordReportColTrend,
        l.recordReportColHistory,
      ],
      legend: l.recordReportLabLegend(texts.margin(data.margin)),
      groups: [
        for (final k in ordered)
          // Uncategorised tests get an "Other" heading when there are
          // categories around them.
          ReportLabGroup(category: k ?? (ordered.length > 1 ? l.recordLabUncategorized : null), rows: groups[k]!),
      ],
    );
  }

  String _avg(double v, {int decimals = 1}) => fmt.formatNumber(v, maxDecimals: decimals);

  List<({String label, String count})> _tags(List<({String label, int count})> tags) => [
    for (final t in tags) (label: t.label, count: fmt.formatInt(t.count)),
  ];

  ReportBlock _pain(DoctorReportData data) {
    final s = PainSummary.of(data.pains, labels: data.tagLabels);
    return ReportStatsBlock(
      section: ReportSection.pain,
      title: l.recordSectionPain,
      emptyText: _nothing,
      stats: s == null
          ? const []
          : [
              ReportStat(l.recordReportEntries, fmt.formatInt(s.entries)),
              ReportStat(l.recordReportDaysLogged, fmt.formatInt(s.days)),
              ReportStat(l.recordReportPainAverage(fmt.formatInt(10)), _avg(s.average)),
              ReportStat(l.recordReportPainHighest, fmt.formatInt(s.highest)),
            ],
      tagLines: s == null
          ? const []
          : [
              if (s.topLocations.isNotEmpty) ReportTagLine(l.recordReportTopLocations, _tags(s.topLocations)),
              if (s.topTriggers.isNotEmpty) ReportTagLine(l.recordReportTopTriggers, _tags(s.topTriggers)),
            ],
    );
  }

  ReportBlock _mood(DoctorReportData data) {
    final s = MoodSummary.of(data.moods, labels: data.tagLabels);
    return ReportStatsBlock(
      section: ReportSection.mood,
      title: l.recordSectionMood,
      emptyText: _nothing,
      stats: s == null
          ? const []
          : [
              ReportStat(l.recordReportEntries, fmt.formatInt(s.entries)),
              if (s.mood != null) ReportStat(l.recordReportMoodAverage(fmt.formatInt(5)), _avg(s.mood!)),
              if (s.stress != null) ReportStat(l.recordReportStressAverage(fmt.formatInt(10)), _avg(s.stress!)),
              if (s.anxiety != null) ReportStat(l.recordReportAnxietyAverage(fmt.formatInt(10)), _avg(s.anxiety!)),
              if (s.energy != null) ReportStat(l.recordReportEnergyAverage(fmt.formatInt(10)), _avg(s.energy!)),
              if (s.sleepHours != null) ReportStat(l.recordReportSleepAverage, _avg(s.sleepHours!)),
              if (s.caffeineCups != null) ReportStat(l.recordReportCaffeineAverage, _avg(s.caffeineCups!)),
            ],
      tagLines: s == null || s.topFactors.isEmpty
          ? const []
          : [ReportTagLine(l.recordReportTopFactors, _tags(s.topFactors))],
    );
  }

  ReportBlock _questions(DoctorReportData data) {
    final appts = {for (final a in data.appointments) a.id: a};
    final qs = [...data.questions]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return ReportItemsBlock(
      section: ReportSection.questions,
      title: l.recordSectionQuestions,
      emptyText: _nothing,
      items: [
        for (final q in qs)
          if (q.question.trim().isNotEmpty)
            ReportItem(
              title: q.question.trim(),
              meta: switch (appts[q.appointmentId]) {
                final a? => l.recordReportQuestionFor(a.title.trim(), _date(a.at)),
                null => null,
              },
            ),
      ],
    );
  }
}
