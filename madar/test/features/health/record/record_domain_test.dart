import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/features/health/record/domain/appointment_plan.dart';
import 'package:madar/features/health/record/domain/health_summaries.dart';
import 'package:madar/features/health/record/domain/lab_flags.dart';
import 'package:madar/features/health/record/domain/lab_series.dart';
import 'package:madar/features/health/record/domain/record_settings.dart';
import 'package:madar/features/health/record/domain/report_model.dart';

LabTestRow _test({String id = 't', double? low, double? high}) => LabTestRow(
  id: id,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  sortOrder: 0,
  name: 'T',
  low: low,
  high: high,
);

LabReadingRow _reading(
  String id,
  DateTime date, {
  double? value,
  String? text,
  String testId = 't',
  DateTime? created,
}) => LabReadingRow(
  id: id,
  createdAt: created ?? DateTime(2026),
  updatedAt: DateTime(2026),
  testId: testId,
  date: date,
  value: value,
  valueText: text,
);

AppointmentRow _appt(String id, DateTime at, {bool done = false}) =>
    AppointmentRow(id: id, createdAt: DateTime(2026), updatedAt: DateTime(2026), title: id, at: at, done: done);

void main() {
  group('LabFlags', () {
    const range = LabRange(low: 10, high: 20); // width 10 → 5 % margin = 0.5

    test('low / high outside the range', () {
      expect(LabFlags.classify(9.99, range), LabFlag.low);
      expect(LabFlags.classify(20.01, range), LabFlag.high);
    });

    test('borderline within 5 % of the width from a bound, bounds included', () {
      expect(LabFlags.classify(10, range), LabFlag.borderlineLow);
      expect(LabFlags.classify(10.49, range), LabFlag.borderlineLow);
      expect(LabFlags.classify(10.5, range), LabFlag.inRange);
      expect(LabFlags.classify(19.5, range), LabFlag.inRange);
      expect(LabFlags.classify(19.51, range), LabFlag.borderlineHigh);
      expect(LabFlags.classify(20, range), LabFlag.borderlineHigh);
      expect(LabFlags.classify(15, range), LabFlag.inRange);
    });

    test('the margin is adjustable; 0 turns borderline off', () {
      expect(LabFlags.classify(11, range, margin: 0.15), LabFlag.borderlineLow);
      expect(LabFlags.classify(10, range, margin: 0), LabFlag.inRange);
      expect(LabFlags.marginWidth(range, margin: 0.5), 2.5, reason: 'clamped to 25 %');
    });

    test('one bound: margin is a share of the bound', () {
      const upTo = LabRange(high: 200);
      expect(LabFlags.marginWidth(upTo), 10);
      expect(LabFlags.classify(189, upTo), LabFlag.inRange);
      expect(LabFlags.classify(191, upTo), LabFlag.borderlineHigh);
      expect(LabFlags.classify(201, upTo), LabFlag.high);
      const atLeast = LabRange(low: 40);
      expect(LabFlags.classify(41, atLeast), LabFlag.borderlineLow);
      expect(LabFlags.classify(39, atLeast), LabFlag.low);
      expect(LabFlags.classify(500, atLeast), LabFlag.inRange);
    });

    test('swapped bounds, narrow ranges, no range, qualitative', () {
      expect(LabFlags.classify(25, const LabRange(low: 20, high: 10)), LabFlag.high);
      // Width 1 → margin 0.05: 5.02 is nearer the low bound.
      expect(LabFlags.classify(5.02, const LabRange(low: 5, high: 6)), LabFlag.borderlineLow);
      expect(LabFlags.classify(5.99, const LabRange(low: 5, high: 6)), LabFlag.borderlineHigh);
      expect(LabFlags.classify(3, const LabRange()), LabFlag.noRange);
      expect(LabFlags.classify(null, range), LabFlag.qualitative);
      expect(LabFlags.marginWidth(const LabRange()), isNull);
    });

    test('facts', () {
      expect(LabFlag.low.isOutOfRange, isTrue);
      expect(LabFlag.borderlineHigh.isFlagged, isTrue);
      expect(LabFlag.inRange.isFlagged, isFalse);
      expect(LabFlag.borderlineLow.side, -1);
      expect(LabFlag.high.attention, greaterThan(LabFlag.borderlineHigh.attention));
    });
  });

  group('LabSeries', () {
    final t = _test(low: 1, high: 3);

    test('points are oldest first, same day by entry order, classified', () {
      final pts = LabSeries.points([
        _reading('b', DateTime(2026, 5, 1), value: 4, created: DateTime(2026, 5, 2)),
        _reading('a', DateTime(2026, 1, 1), value: 2),
        _reading('c', DateTime(2026, 5, 1), text: 'trace', created: DateTime(2026, 5, 1)),
        _reading('x', DateTime(2026, 2, 1), value: 2, testId: 'other'),
      ], t);
      expect(pts.map((p) => p.id), ['a', 'c', 'b']);
      expect(pts.map((p) => p.flag), [LabFlag.inRange, LabFlag.qualitative, LabFlag.high]);
      final summary = LabSeries.summary(pts)!;
      expect(summary.latest.id, 'b');
      expect(summary.change, isNull, reason: 'previous is qualitative');
    });

    test('period windows end today', () {
      final today = DateTime(2026, 9, 29);
      expect(LabPeriod.months3.start(today), DateTime(2026, 6, 29));
      expect(LabPeriod.months12.start(today), DateTime(2025, 9, 29));
      expect(LabPeriod.all.start(today), isNull);
      final pts = LabSeries.points([
        _reading('old', DateTime(2025, 1, 1), value: 2),
        _reading('new', DateTime(2026, 8, 1), value: 2),
      ], t);
      expect(LabSeries.within(pts, LabPeriod.months3, today).map((p) => p.id), ['new']);
      expect(LabSeries.within(pts, LabPeriod.all, today), hasLength(2));
    });

    test('decimals follow what was typed', () {
      expect(LabDecimals.of(120), 0);
      expect(LabDecimals.of(5.4), 1);
      expect(LabDecimals.of(0.035), 3);
      expect(LabDecimals.of(1.23456), 3);
      expect(LabDecimals.forValues([0.4, 4, 3.85]), 2);
    });

    test('typed values: any digits, comma decimals, or text', () {
      expect(LabValueInput.parse('١٢٫٥').value, 12.5);
      expect(LabValueInput.parse('12,5').value, 12.5);
      expect(LabValueInput.parse(' 7 ').value, 7);
      expect(LabValueInput.parse('negative').text, 'negative');
      expect(LabValueInput.parse('سلبي').value, isNull);
      expect(LabValueInput.parse('  ').isEmpty, isTrue);
      expect(LabValueInput.parse(null).isEmpty, isTrue);
    });

    test('chart scale is nice and always shows the band', () {
      final s = LabChartScale.of([2, 2.2, 2.1], range: const LabRange(low: 0.4, high: 4));
      expect(s.minY, lessThanOrEqualTo(0.4));
      expect(s.maxY, greaterThanOrEqualTo(4));
      expect(s.minY, greaterThanOrEqualTo(0), reason: 'no negative axis for positive values');
      expect(LabChartScale.niceStep(s.interval), closeTo(s.interval, 1e-9));
      expect(s.ticks.first, s.minY);
      expect(LabChartScale.niceStep(0.3), 0.5);
      expect(LabChartScale.niceStep(7), 10);
      expect(LabChartScale.niceStep(2.2), 2.5);
      final flat = LabChartScale.of([5, 5]);
      expect(flat.maxY, greaterThan(flat.minY));
    });

    test('time axis runs in the reading direction', () {
      final ltr = ChartTimeAxis(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 11), rtl: false);
      final rtl = ChartTimeAxis(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 11), rtl: true);
      expect(ltr.span, 10);
      expect(ltr.x(DateTime(2026, 1, 1)), 0);
      expect(rtl.x(DateTime(2026, 1, 1)), 10, reason: 'oldest on the right in Arabic');
      expect(rtl.x(DateTime(2026, 1, 11)), 0);
      expect(rtl.dateAt(rtl.x(DateTime(2026, 1, 4))), DateTime(2026, 1, 4));
      expect(ltr.fraction(DateTime(2026, 1, 6)), 0.5);
      // Across a DST change the days stay whole.
      final dst = ChartTimeAxis(start: DateTime(2026, 3, 20), end: DateTime(2026, 4, 5), rtl: false);
      expect(dst.x(DateTime(2026, 4, 1)), 12);
      final covering = ChartTimeAxis.covering(
        [DateTime(2026, 2, 1)],
        rtl: false,
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 3, 1),
      );
      expect(covering.start.isBefore(DateTime(2026, 1, 1)), isTrue);
      expect(covering.end.isAfter(DateTime(2026, 3, 1)), isTrue);
    });
  });

  group('appointments', () {
    final now = DateTime(2026, 9, 29, 10);

    test('split: upcoming soonest first (with a grace period), past latest first', () {
      final b = AppointmentTimeline.split([
        _appt('later', DateTime(2026, 10, 20, 9)),
        _appt('soon', DateTime(2026, 10, 1, 9)),
        _appt('now-ish', DateTime(2026, 9, 29, 8)),
        _appt('old', DateTime(2026, 8, 1, 9)),
        _appt('done', DateTime(2026, 10, 2, 9), done: true),
        _appt('older', DateTime(2026, 7, 1, 9)),
      ], now);
      expect(b.upcoming.map((a) => a.id), ['now-ish', 'soon', 'later']);
      expect(b.past.map((a) => a.id), ['done', 'old', 'older']);
      expect(AppointmentTimeline.next(b.upcoming, now)!.id, 'now-ish');
      expect(AppointmentTimeline.daysUntil(DateTime(2026, 9, 30, 1), now), 1);
      expect(AppointmentTimeline.daysUntil(DateTime(2026, 9, 28, 23), now), -1);
    });

    test('reminders: offsets largest first, past ones skipped, done / far excluded, ids in the block', () {
      final list = AppointmentReminderPlanner.plan(
        appointments: [
          _appt('a', DateTime(2026, 10, 1, 9)),
          _appt('b', DateTime(2026, 9, 29, 13)), // day-before already past
          _appt('done', DateTime(2026, 10, 3, 9), done: true),
          _appt('far', DateTime(2027, 1, 1, 9)),
          _appt('past', DateTime(2026, 9, 1, 9)),
        ],
        now: now,
        offsets: [120, 1440, 120, -5],
      );
      expect(list.map((r) => (r.appointmentId, r.offsetMinutes)), [('b', 120), ('a', 1440), ('a', 120)]);
      for (final r in list) {
        expect(AppointmentReminderIds.owns(r.id), isTrue);
        expect(r.at.isAfter(now), isTrue);
      }
      // b is slot 0 (soonest), a slot 1; offsets [1440, 120] → indexes 0, 1.
      expect(list.firstWhere((r) => r.appointmentId == 'b').id, AppointmentReminderIds.of(0, 1));
      expect(
        list.firstWhere((r) => r.appointmentId == 'a' && r.offsetMinutes == 1440).id,
        AppointmentReminderIds.of(1, 0),
      );
      expect(list.map((r) => r.id).toSet(), hasLength(list.length));
    });

    test('id block and offsets', () {
      expect(AppointmentReminderIds.first, 150000);
      expect(AppointmentReminderIds.last, 150399);
      expect(AppointmentReminderIds.owns(150400), isFalse);
      expect(() => AppointmentReminderIds.of(100, 0), throwsRangeError);
      expect(AppointmentReminderPlanner.normalizeOffsets([30, 60, 60, 1440, 10080, 2880]), [10080, 2880, 1440, 60]);
      expect(
        AppointmentReminderPlanner.plan(appointments: [_appt('a', DateTime(2026, 10, 1))], now: now, offsets: const []),
        isEmpty,
      );
    });
  });

  group('RecordSettings', () {
    test('defaults, JSON round trip and validation', () {
      const d = RecordSettings();
      expect(d.borderlineMargin, 0.05);
      expect(d.effectiveOffsets, [1440, 120]);
      expect(d.sectionsOrDefault, ReportSection.values.toSet());
      final s = d.copyWith(
        borderlineMargin: 0.1,
        reminderOffsets: [60, 1440],
        reportName: 'Sara',
        reportSections: {ReportSection.labs},
        reportPeriod: ReportPeriod.months3,
      );
      expect(RecordSettings.fromJson(s.toJson()), s);
      expect(s.reminderOffsets, [1440, 60]);
      expect(s.copyWith(clearReportName: true).reportName, isNull);
      expect(s.copyWith(remindersEnabled: false).effectiveOffsets, isEmpty);
      final bad = RecordSettings.fromJson({
        'borderlineMargin': 9,
        'reminderOffsets': 'x',
        'reportSections': ['nope', 'labs'],
        'reportName': ' ',
      });
      expect(bad.borderlineMargin, 0.25);
      expect(bad.reminderOffsets, RecordSettings.defaultOffsets);
      expect(bad.reportSections, {ReportSection.labs});
      expect(bad.reportName, isNull);
      expect(RecordSettings.fromJson(null), const RecordSettings());
      expect(d.toJson().containsKey('reportName'), isFalse, reason: 'nothing personal by default');
    });

    test('report periods', () {
      expect(ReportPeriod.months1.start(DateTime(2026, 3, 31)), DateTime(2026, 2, 31));
      expect(ReportPeriod.all.start(DateTime(2026, 3, 31)), isNull);
    });
  });

  group('summaries', () {
    test('pain: counts, days, average, highest and top tags with labels', () {
      PainEntryRow p(int d, int score, List<String> where) => PainEntryRow(
        id: '$d$score',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        at: DateTime(2026, 9, d, 8),
        score: score,
        locations: where,
        triggers: const [],
        bodyPoints: const [],
      );
      final s = PainSummary.of(
        [
          p(1, 4, ['tag1']),
          p(1, 6, ['Knee']),
          p(3, 12, ['tag1']),
        ],
        labels: {'tag1': 'Back'},
      )!;
      expect(s.entries, 3);
      expect(s.days, 2);
      expect(s.average, closeTo(20 / 3, 1e-9), reason: 'scores clamp to 10');
      expect(s.highest, 10);
      expect(s.topLocations.first, (label: 'Back', count: 2));
      expect(PainSummary.of(const []), isNull);
    });

    test('mood: averages only over entries that recorded the value', () {
      MoodEntryRow m({int? mood, double? sleep}) => MoodEntryRow(
        id: '$mood$sleep',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        at: DateTime(2026, 9, 1),
        mood: mood,
        sleepHours: sleep,
        factors: const ['Work'],
      );
      final s = MoodSummary.of([m(mood: 4), m(mood: 2, sleep: 6), m(sleep: 8)])!;
      expect(s.mood, 3);
      expect(s.sleepHours, 7);
      expect(s.stress, isNull);
      expect(s.topFactors.single, (label: 'Work', count: 3));
    });
  });
}
