import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/custom_modules/domain/module_charts.dart';
import 'package:madar/features/custom_modules/domain/module_schema.dart';

void main() {
  final today = DateTime(2026, 9, 30, 15, 20);
  var n = 0;
  ModuleEntry e(DateTime at, Map<String, Object?> values) =>
      ModuleEntry(id: 'e${n++}', moduleId: 'm', at: at, values: values);
  DateTime day(int back, [int hour = 9]) => DateTime(2026, 9, 30 - back, hour);

  const pages = ModuleField(id: 'f1', label: 'Pages', type: FieldType.number);
  const mood = ModuleField(id: 'f2', label: 'Mood', type: FieldType.rating, max: 5);
  const done = ModuleField(id: 'f3', label: 'Done', type: FieldType.checkbox);
  const cost = ModuleField(id: 'f4', label: 'Cost', type: FieldType.currency);
  const note = ModuleField(id: 'f5', label: 'Note', type: FieldType.text);
  const module = ModuleDefinition(
    id: 'm',
    name: 'M',
    colorArgb: 0,
    fields: [pages, mood, done, cost, note],
  );

  ModuleChartData build(String? fieldId, List<ModuleEntry> entries, {int range = 7}) => ModuleCharts.build(
    module: module,
    entries: entries,
    today: today,
    config: ModuleChartConfig(type: ModuleChartType.bar, fieldId: fieldId, range: range),
  );

  test('numbers sum per day over the range, oldest first', () {
    final data = build('f1', [
      e(day(0, 6), {'f1': 10}),
      e(day(0, 20), {'f1': 5}),
      e(day(2), {'f1': 7}),
      e(day(9), {'f1': 100}), // outside 7 days
    ]);
    expect(data.days, hasLength(7));
    expect(data.days.first.day, DateTime(2026, 9, 24));
    expect(data.days.last.day, DateTime(2026, 9, 30));
    expect(data.days.last.value, 15);
    expect(data.days.last.entries, 2);
    expect(data.days[4].value, 7);
    expect(data.days[5].value, isNull);
    expect(data.aggregate, ChartAggregate.sum);
    expect(data.total, 22);
    expect(data.average, 11);
    expect(data.maxValue, 15);
    expect(data.daysWithData, 2);
  });

  test('ratings average, checkboxes are check-ins, amounts in units', () {
    final r = build('f2', [
      e(day(1, 8), {'f2': 4}),
      e(day(1, 20), {'f2': 2}),
    ]);
    expect(r.aggregate, ChartAggregate.average);
    expect(r.days[5].value, 3);
    expect(r.intensity(r.days[5]), closeTo(0.6, 1e-9), reason: 'rating shade uses the scale');

    final c = build('f3', [
      e(day(0), {'f3': false}),
      e(day(0, 10), {'f3': true}),
      e(day(1), {'f3': false}),
    ]);
    expect(c.aggregate, ChartAggregate.any);
    expect(c.days.last.value, 1);
    expect(c.days[5].value, 0);
    expect(c.activeDays, 1);

    final m = build('f4', [
      e(day(0), {
        'f4': {'milli': 1500, 'currency': 'JOD'},
      }),
    ]);
    expect(m.days.last.value, 1.5);
  });

  test('no field (or a non-chartable one) counts entries', () {
    final data = build('f5', [e(day(0), {}), e(day(0), {}), e(day(3), {})]);
    expect(data.aggregate, ChartAggregate.count);
    expect(data.config.fieldId, isNull);
    expect(data.days.last.value, 2);
    expect(data.days[3].value, 1);
  });

  test('ranges of 30 and 90 days', () {
    expect(build('f1', const [], range: 30).days, hasLength(30));
    final d90 = build('f1', const [], range: 90);
    expect(d90.days, hasLength(90));
    expect(d90.days.first.day, DateTime(2026, 7, 3));
    expect(d90.isEmpty, isTrue);
  });

  test('streaks: current run survives an open today, best over history', () {
    final entries = [
      for (final b in [1, 2, 3]) e(day(b), {'f3': true}),
      for (final b in [10, 11, 12, 13, 14]) e(day(b), {'f3': true}),
      e(day(6), {'f3': false}),
    ];
    final data = build('f3', entries);
    expect(data.currentStreak, 3);
    expect(data.bestStreak, 5);

    final withToday = build('f3', [...entries, e(day(0), {'f3': true})]);
    expect(withToday.currentStreak, 4);

    final broken = build('f3', [e(day(2), {'f3': true})]);
    expect(broken.currentStreak, 0);
    expect(broken.bestStreak, 1);
  });

  test('streaks across a month boundary and DST-free day math', () {
    final (cur, best) = ModuleCharts.streaks(
      {DateTime(2026, 2, 27), DateTime(2026, 2, 28), DateTime(2026, 3, 1)},
      DateTime(2026, 3, 1, 23),
    );
    expect((cur, best), (3, 3));
  });

  test('heat calendar weeks start on the chosen weekday and pad with nulls', () {
    final data = build('f1', const [], range: 30);
    final weeks = ModuleCharts.heatWeeks(data.days, firstWeekday: DateTime.saturday);
    // 1 Sep 2026 is a Tuesday: three leading blanks (Sat, Sun, Mon).
    expect(weeks.first.take(3), everyElement(isNull));
    expect(weeks.first[3]!.day, DateTime(2026, 9, 1));
    expect(weeks.every((w) => w.length == 7), isTrue);
    expect(weeks.expand((w) => w).whereType<ChartDay>(), hasLength(30));
    expect(ModuleCharts.weekdayOrder(firstWeekday: DateTime.saturday).first, DateTime.saturday);
    expect(ModuleCharts.weekdayOrder(firstWeekday: DateTime.sunday), [7, 1, 2, 3, 4, 5, 6]);
  });

  test('sparkline takes the last days with zeros', () {
    final data = build('f1', [e(day(0), {'f1': 3})], range: 30);
    final s = ModuleCharts.sparkline(data);
    expect(s, hasLength(7));
    expect(s.last, 3);
    expect(s.first, 0);
  });
}
