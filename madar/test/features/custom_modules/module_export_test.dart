import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/custom_modules/domain/module_export.dart';
import 'package:madar/features/custom_modules/domain/module_schema.dart';

void main() {
  const tracker = ModuleDefinition(
    id: 'm1',
    name: 'Reading | log',
    colorArgb: 0,
    planetKey: 'growth',
    window: PrayerWindow.fajr,
    fields: [
      ModuleField(id: 'f1', label: 'Book', type: FieldType.text, required: true),
      ModuleField(id: 'f2', label: 'Pages', type: FieldType.number, unit: 'p'),
      ModuleField(id: 'f3', label: 'Rating', type: FieldType.rating, max: 5),
      ModuleField(
        id: 'f4',
        label: 'Tags',
        type: FieldType.multiSelect,
        options: [FieldOption(id: 'o1', label: 'Novel'), FieldOption(id: 'o2', label: 'History')],
      ),
      ModuleField(id: 'f5', label: 'Cost', type: FieldType.currency, currency: 'JOD'),
      ModuleField(id: 'f6', label: 'Old note', type: FieldType.text, hidden: true),
    ],
    chart: ModuleChartConfig(type: ModuleChartType.bar, fieldId: 'f2', range: 7),
  );
  final entries = [
    ModuleEntry(
      id: 'e2',
      moduleId: 'm1',
      at: DateTime(2026, 9, 29, 5, 10),
      values: const {
        'f1': 'Emma, "the" novel',
        'f2': 12,
        'f4': ['o1'],
      },
    ),
    ModuleEntry(
      id: 'e1',
      moduleId: 'm1',
      at: DateTime(2026, 9, 28, 5, 0),
      values: const {
        'f1': '=HYPERLINK("x")',
        'f2': 30,
        'f3': 4,
        'f5': {'milli': 2500, 'currency': 'JOD'},
        'f6': 'kept',
      },
    ),
  ];
  final today = DateTime(2026, 9, 30, 12);

  group('search records', () {
    test('one for the module, one per entry with every value', () {
      final records = ModuleExport.searchRecords(tracker, entries);
      expect(records, hasLength(3));
      expect(records.first.entryId, isNull);
      expect(records.first.text, contains('Pages'));
      expect(records.first.text, contains('Novel'));
      expect(records.first.planetKey, 'growth');
      final e1 = records.firstWhere((r) => r.entryId == 'e1');
      expect(e1.id, 'cmod:m1:e1');
      expect(e1.title, '=HYPERLINK("x")');
      expect(e1.text, contains('Pages: 30 p'));
      expect(e1.text, contains('Rating: 4/5'));
      expect(e1.text, contains('Cost: 2.500 JOD'));
      expect(e1.text, contains('Old note: kept'), reason: 'hidden values stay searchable');
      expect(e1.at, DateTime(2026, 9, 28, 5));
    });
  });

  group('CSV', () {
    test('header, oldest first, neutral values, hidden fields included', () {
      final rows = ModuleExport.csvRows(tracker, entries);
      expect(rows.first, ['date', 'time', 'Book', 'Pages', 'Rating', 'Tags', 'Cost', 'Old note (hidden)']);
      expect(rows[1], ['2026-09-28', '05:00', '=HYPERLINK("x")', '30', '4', '', '2.500 JOD', 'kept']);
      expect(rows[2], ['2026-09-29', '05:10', 'Emma, "the" novel', '12', '', 'Novel', '', '']);
    });

    test('quotes, escapes and guards against formulas', () {
      final text = ModuleExport.csv(ModuleExport.csvRows(tracker, entries));
      final lines = text.split('\r\n');
      expect(lines, hasLength(4)); // header + 2 + trailing empty
      expect(lines[1], contains('"\'=HYPERLINK(""x"")"'));
      expect(lines[2], contains('"Emma, ""the"" novel"'));
      expect(ModuleExport.csvCell('-5'), '-5');
      expect(ModuleExport.csvCell('-x'), "'-x");
      expect(ModuleExport.csvCell('@sum'), "'@sum");
      expect(ModuleExport.csvCell('a\nb'), '"a\nb"');
    });

    test('lists add a done column in list order', () {
      const list = ModuleDefinition(
        id: 'l',
        name: 'Gifts',
        kind: CustomModuleKind.list,
        colorArgb: 0,
        fields: [ModuleField(id: 'f1', label: 'Idea', type: FieldType.text)],
      );
      final rows = ModuleExport.csvRows(list, [
        ModuleEntry(id: 'b', moduleId: 'l', at: DateTime(2026, 9, 2), values: const {'f1': 'B'}, sortOrder: 2, done: true),
        ModuleEntry(id: 'a', moduleId: 'l', at: DateTime(2026, 9, 3), values: const {'f1': 'A'}, sortOrder: 1),
      ]);
      expect(rows.first, ['date', 'time', 'done', 'Idea']);
      expect(rows[1].last, 'A');
      expect(rows[2][2], 'true');
    });
  });

  group('Markdown', () {
    test('summary with meta, fields, stats and a recent-entries table', () {
      final md = ModuleExport.markdown(tracker, entries, today: today);
      expect(md, startsWith('## Reading \\| log'));
      expect(md, contains('Kind: Tracker · Planet: growth · Window: fajr'));
      expect(md, contains('Pages (number, p)'));
      expect(md, contains('Book (text, required)'));
      expect(md, contains('Rating (rating, 1–5)'));
      expect(md, contains('Tags (multiple choice, Novel / History)'));
      expect(md, isNot(contains('Old note (')), reason: 'hidden fields are not described');
      expect(md, contains('Entries: 2 · Last entry: 2026-09-29'));
      expect(md, contains('Last 7 days: 2 active days · total 42 p · average 21 p · streak 2 (best 2)'));
      expect(md, contains('| date | Book | Pages | Rating | Tags | Cost |'));
      final table = md.split('\n').where((l) => l.startsWith('| 2026')).toList();
      expect(table.first, startsWith('| 2026-09-29 | Emma, "the" novel | 12 p |'));
      expect(table[1], contains('| 4/5 |'));
    });

    test('lists show open / done and check boxes; empty modules say so', () {
      const list = ModuleDefinition(
        id: 'l',
        name: 'Gifts',
        kind: CustomModuleKind.list,
        colorArgb: 0,
        fields: [ModuleField(id: 'f1', label: 'Idea', type: FieldType.text)],
      );
      final md = ModuleExport.markdown(list, [
        ModuleEntry(id: 'a', moduleId: 'l', at: DateTime(2026, 9, 3), values: const {'f1': 'A'}, done: true),
        ModuleEntry(id: 'b', moduleId: 'l', at: DateTime(2026, 9, 3), values: const {'f1': 'B'}, sortOrder: 1),
      ], today: today);
      expect(md, contains('Entries: 2 · Open: 1 · Done: 1'));
      expect(md, contains('| ☑ | A |'));
      expect(md, contains('| ☐ | B |'));
      expect(ModuleExport.markdown(list, const [], today: today), contains('No entries yet.'));
    });

    test('long histories are truncated to the recent entries', () {
      final many = [
        for (var i = 0; i < 15; i++)
          ModuleEntry(id: 'e$i', moduleId: 'm1', at: DateTime(2026, 9, 1 + i), values: {'f1': 'B$i', 'f2': i}),
      ];
      final md = ModuleExport.markdown(tracker, many, today: today, recent: 5);
      expect(md.split('\n').where((l) => l.startsWith('| 2026')), hasLength(5));
      expect(md, contains('| … |'));
      expect(md, contains('B14'));
      expect(md, isNot(contains('B0 ')));
    });
  });

  test('entry title falls back to the first value', () {
    const m = ModuleDefinition(
      id: 'x',
      name: 'X',
      colorArgb: 0,
      fields: [ModuleField(id: 'f1', label: 'N', type: FieldType.number, unit: 'kg')],
    );
    expect(ModuleExport.entryTitle(m, ModuleEntry(id: 'e', moduleId: 'x', at: today, values: const {'f1': 3})), '3 kg');
    expect(ModuleExport.entryTitle(m, ModuleEntry(id: 'e', moduleId: 'x', at: today)), isNull);
  });
}
