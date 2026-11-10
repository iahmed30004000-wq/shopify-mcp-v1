/// Search / export / AI hooks for custom modules: a module and its entries
/// as (a) searchable text records, (b) CSV rows, (c) a Markdown summary.
///
/// Pure Dart. Localised output goes through [ModuleValueFormatter] and
/// [ModuleExportTexts] (the app passes `CustomTexts`); the defaults are
/// neutral (Western digits, ISO dates, English words) – right for CSV.
library;

import '../../../core/domain/enums.dart';
import '../../../core/domain/money.dart';
import 'field_migration.dart';
import 'field_values.dart';
import 'module_charts.dart';
import 'module_schema.dart';

/// How values are written for people (search snippets, Markdown).
abstract interface class ModuleValueFormatter {
  String number(num n);
  String date(DateTime d);

  /// [hhmm] is `"HH:mm"`.
  String time(String hhmm);
  String money(Money m);
  String rating(int stars, int max);
  String checkbox(bool value);
}

/// Western digits, ISO dates, `✓` / `✗`.
class PlainValueFormatter implements ModuleValueFormatter {
  const PlainValueFormatter();

  @override
  String number(num n) => FieldMigration.plainNumber(n);

  @override
  String date(DateTime d) => FieldValues.encodeDate(d);

  @override
  String time(String hhmm) => hhmm;

  @override
  String money(Money m) => '${m.formatAmount(locale: 'en', digits: MoneyDigits.western)} ${m.currency}';

  @override
  String rating(int stars, int max) => '$stars/$max';

  @override
  String checkbox(bool value) => value ? '✓' : '✗';
}

/// Words of the Markdown summary and CSV header.
abstract interface class ModuleExportTexts {
  String kind(CustomModuleKind kind);
  String fieldType(FieldType type);

  /// A planet's display name (null / unknown key → null).
  String? planet(String? key);
  String? window(PrayerWindow? window);

  String get kindLabel;
  String get planetLabel;
  String get windowLabel;
  String get fieldsLabel;
  String get entriesLabel;
  String get lastEntryLabel;
  String get requiredLabel;
  String get hiddenLabel;
  String get dateColumn;
  String get timeColumn;
  String get doneColumn;
  String get openLabel;
  String get doneLabel;
  String get noEntries;

  /// "Last 30 days".
  String lastDays(int days);
  String activeDays(int days);
  String total(String value);
  String average(String value);
  String streak(int current, int best);
}

class EnglishModuleExportTexts implements ModuleExportTexts {
  const EnglishModuleExportTexts();

  @override
  String kind(CustomModuleKind kind) => kind == CustomModuleKind.tracker ? 'Tracker' : 'List';

  @override
  String fieldType(FieldType type) => switch (type) {
    FieldType.text => 'text',
    FieldType.number => 'number',
    FieldType.date => 'date',
    FieldType.time => 'time',
    FieldType.checkbox => 'checkbox',
    FieldType.singleSelect => 'single choice',
    FieldType.multiSelect => 'multiple choice',
    FieldType.rating => 'rating',
    FieldType.currency => 'amount',
  };

  @override
  String? planet(String? key) => key;

  @override
  String? window(PrayerWindow? window) => window?.name;

  @override
  String get kindLabel => 'Kind';
  @override
  String get planetLabel => 'Planet';
  @override
  String get windowLabel => 'Window';
  @override
  String get fieldsLabel => 'Fields';
  @override
  String get entriesLabel => 'Entries';
  @override
  String get lastEntryLabel => 'Last entry';
  @override
  String get requiredLabel => 'required';
  @override
  String get hiddenLabel => 'hidden';
  @override
  String get dateColumn => 'date';
  @override
  String get timeColumn => 'time';
  @override
  String get doneColumn => 'done';
  @override
  String get openLabel => 'Open';
  @override
  String get doneLabel => 'Done';
  @override
  String get noEntries => 'No entries yet.';

  @override
  String lastDays(int days) => 'Last $days days';
  @override
  String activeDays(int days) => '$days active days';
  @override
  String total(String value) => 'total $value';
  @override
  String average(String value) => 'average $value';
  @override
  String streak(int current, int best) => 'streak $current (best $best)';
}

/// One searchable record: the module itself ([entryId] null) or an entry.
class ModuleSearchRecord {
  const ModuleSearchRecord({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.text,
    this.entryId,
    this.at,
    this.planetKey,
  });

  /// `cmod:<moduleId>` or `cmod:<moduleId>:<entryId>`.
  final String id;
  final String moduleId;
  final String? entryId;
  final String title;

  /// Everything searchable, one line.
  final String text;
  final DateTime? at;
  final String? planetKey;

  @override
  String toString() => 'ModuleSearchRecord($id, $title)';
}

abstract final class ModuleExport {
  /// [v] of [f] for people, or null when empty.
  static String? displayValue(ModuleField f, Object? v, {ModuleValueFormatter fmt = const PlainValueFormatter()}) {
    if (FieldValues.isEmpty(v)) return null;
    switch (f.type) {
      case FieldType.text:
        return FieldValues.text(v);
      case FieldType.number:
        final n = FieldValues.number(v);
        if (n == null) return null;
        final unit = f.unit?.trim();
        return unit == null || unit.isEmpty ? fmt.number(n) : '${fmt.number(n)} $unit';
      case FieldType.rating:
        final r = FieldValues.rating(v);
        return r == null ? null : fmt.rating(r, f.ratingMax);
      case FieldType.date:
        final d = FieldValues.date(v);
        return d == null ? null : fmt.date(d);
      case FieldType.time:
        final t = FieldValues.time(v);
        return t == null ? null : fmt.time(t);
      case FieldType.checkbox:
        final b = FieldValues.checkbox(v);
        return b == null ? null : fmt.checkbox(b);
      case FieldType.singleSelect:
      case FieldType.multiSelect:
        return FieldMigration.plainText(f, v);
      case FieldType.currency:
        final m = FieldValues.money(v, fallbackCurrency: f.currencyCode);
        return m == null ? null : fmt.money(m);
    }
  }

  /// The title of an entry: its first text value, else its first value,
  /// else null.
  static String? entryTitle(
    ModuleDefinition m,
    ModuleEntry e, {
    ModuleValueFormatter fmt = const PlainValueFormatter(),
  }) {
    final tf = m.titleField;
    if (tf != null) {
      final t = FieldValues.text(e.values[tf.id]);
      if (t != null) return t;
    }
    for (final f in m.visibleFields) {
      final d = displayValue(f, e.values[f.id], fmt: fmt);
      if (d != null) return d;
    }
    return null;
  }

  // ------------------------------------------------------------- search --

  /// The module (name, kind, field labels) and every entry (all its values).
  static List<ModuleSearchRecord> searchRecords(
    ModuleDefinition m,
    List<ModuleEntry> entries, {
    ModuleValueFormatter fmt = const PlainValueFormatter(),
    ModuleExportTexts texts = const EnglishModuleExportTexts(),
  }) {
    final out = <ModuleSearchRecord>[
      ModuleSearchRecord(
        id: 'cmod:${m.id}',
        moduleId: m.id,
        title: m.name,
        text: [
          m.name,
          texts.kind(m.kind),
          ?texts.planet(m.planetKey),
          for (final f in m.visibleFields) f.label,
          for (final f in m.visibleFields)
            for (final o in f.visibleOptions) o.label,
        ].join(' · '),
        planetKey: m.planetKey,
        at: m.createdAt,
      ),
    ];
    for (final e in entries) {
      final parts = <String>[
        for (final f in m.fields)
          if (displayValue(f, e.values[f.id], fmt: fmt) case final String d) '${f.label}: $d',
      ];
      out.add(
        ModuleSearchRecord(
          id: 'cmod:${m.id}:${e.id}',
          moduleId: m.id,
          entryId: e.id,
          title: entryTitle(m, e, fmt: fmt) ?? m.name,
          text: [m.name, ...parts].join(' · '),
          at: e.at,
          planetKey: m.planetKey,
        ),
      );
    }
    return out;
  }

  // ---------------------------------------------------------------- CSV --

  /// Header + one row per entry: date, time, (done for lists), then every
  /// field – hidden ones too (an export never loses data). Values are
  /// neutral (see [FieldMigration.plainText]); entries oldest first for
  /// trackers, in list order for lists.
  static List<List<String>> csvRows(
    ModuleDefinition m,
    List<ModuleEntry> entries, {
    ModuleExportTexts texts = const EnglishModuleExportTexts(),
    bool includeHidden = true,
  }) {
    final fields = [
      for (final f in m.fields)
        if (includeHidden || !f.hidden) f,
    ];
    final sorted = [...entries];
    if (m.isTracker) {
      sorted.sort((a, b) => a.at.compareTo(b.at));
    } else {
      sorted.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return [
      [
        texts.dateColumn,
        texts.timeColumn,
        if (m.isList) texts.doneColumn,
        for (final f in fields) f.hidden ? '${f.label} (${texts.hiddenLabel})' : f.label,
      ],
      for (final e in sorted)
        [
          FieldValues.encodeDate(e.at),
          FieldValues.encodeTime(e.at.hour, e.at.minute),
          if (m.isList) e.done ? 'true' : 'false',
          for (final f in fields) FieldMigration.plainText(f, e.values[f.id]) ?? '',
        ],
    ];
  }

  /// RFC 4180 text (CRLF line ends, quotes where needed). Cells that a
  /// spreadsheet would run as a formula get a leading apostrophe.
  static String csv(List<List<String>> rows) {
    final b = StringBuffer();
    for (final row in rows) {
      b.write(row.map(csvCell).join(','));
      b.write('\r\n');
    }
    return b.toString();
  }

  static final RegExp _formula = RegExp(r'^[=+@\t\r]|^-(?![\d.])');

  static String csvCell(String v) {
    var s = v;
    if (_formula.hasMatch(s)) s = "'$s";
    if (s.contains(RegExp('[",\r\n]'))) s = '"${s.replaceAll('"', '""')}"';
    return s;
  }

  // ----------------------------------------------------------- Markdown --

  /// A compact Markdown summary for the AI assistant and shared exports:
  /// what the module is, its fields, the last [ModuleChartConfig.range]
  /// days in numbers, and the [recent] latest entries as a table.
  static String markdown(
    ModuleDefinition m,
    List<ModuleEntry> entries, {
    required DateTime today,
    ModuleExportTexts texts = const EnglishModuleExportTexts(),
    ModuleValueFormatter fmt = const PlainValueFormatter(),
    int recent = 10,
  }) {
    final b = StringBuffer();
    b.writeln('## ${_md(m.name)}');
    b.writeln();
    final meta = <String>[
      '${texts.kindLabel}: ${texts.kind(m.kind)}',
      if (texts.planet(m.planetKey) case final String p) '${texts.planetLabel}: ${_md(p)}',
      if (texts.window(m.window) case final String w) '${texts.windowLabel}: $w',
    ];
    b.writeln('- ${meta.join(' · ')}');
    final fieldDescs = [
      for (final f in m.visibleFields)
        () {
          final bits = <String>[
            texts.fieldType(f.type),
            if (f.unit != null) f.unit!,
            if (f.type == FieldType.currency) f.currencyCode,
            if (f.type == FieldType.rating) '1–${fmt.number(f.ratingMax)}',
            if (f.isSelect && f.visibleOptions.isNotEmpty) f.visibleOptions.map((o) => _md(o.label)).join(' / '),
            if (f.isRequired) texts.requiredLabel,
          ];
          return '${_md(f.label)} (${bits.join(', ')})';
        }(),
    ];
    if (fieldDescs.isNotEmpty) b.writeln('- ${texts.fieldsLabel}: ${fieldDescs.join('; ')}');
    final latest = entries.isEmpty ? null : entries.map((e) => e.at).reduce((a, c) => c.isAfter(a) ? c : a);
    if (m.isList) {
      final done = entries.where((e) => e.done).length;
      b.writeln(
        '- ${texts.entriesLabel}: ${fmt.number(entries.length)} · ${texts.openLabel}: ${fmt.number(entries.length - done)} · ${texts.doneLabel}: ${fmt.number(done)}',
      );
    } else {
      b.writeln(
        '- ${texts.entriesLabel}: ${fmt.number(entries.length)}${latest == null ? '' : ' · ${texts.lastEntryLabel}: ${fmt.date(latest)}'}',
      );
      if (entries.isNotEmpty) {
        final data = ModuleCharts.build(module: m, entries: entries, today: today);
        final stats = <String>[
          texts.activeDays(data.activeDays),
          if (data.aggregate == ChartAggregate.sum || data.aggregate == ChartAggregate.count)
            texts.total(_withUnit(fmt.number(_round(data.total)), data.field)),
          if (data.average case final double avg when data.aggregate != ChartAggregate.any)
            texts.average(_withUnit(fmt.number(_round(avg)), data.field)),
          texts.streak(data.currentStreak, data.bestStreak),
        ];
        b.writeln('- ${texts.lastDays(data.config.range)}: ${stats.join(' · ')}');
      }
    }
    b.writeln();
    if (entries.isEmpty) {
      b.writeln(texts.noEntries);
      return b.toString();
    }
    final fields = m.visibleFields;
    final rows = [...entries];
    if (m.isTracker) {
      rows.sort((a, c) => c.at.compareTo(a.at));
    } else {
      rows.sort((a, c) => a.sortOrder.compareTo(c.sortOrder));
    }
    final shown = rows.take(recent).toList();
    final header = [if (m.isList) texts.doneColumn else texts.dateColumn, for (final f in fields) _md(f.label)];
    b.writeln('| ${header.join(' | ')} |');
    b.writeln('|${List.filled(header.length, '---').join('|')}|');
    for (final e in shown) {
      final cells = [
        if (m.isList) (e.done ? '☑' : '☐') else fmt.date(e.at),
        for (final f in fields) _md(displayValue(f, e.values[f.id], fmt: fmt) ?? ''),
      ];
      b.writeln('| ${cells.join(' | ')} |');
    }
    if (rows.length > shown.length) b.writeln('| … |${List.filled(header.length - 1, '').join('|')}|');
    return b.toString();
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  static String _withUnit(String v, ModuleField? f) {
    if (f == null) return v;
    if (f.type == FieldType.currency) return '$v ${f.currencyCode}';
    final u = f.unit?.trim();
    return u == null || u.isEmpty ? v : '$v $u';
  }

  /// Escapes Markdown table / emphasis characters and folds newlines.
  static String _md(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('|', '\\|').replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll('*', '\\*');
}
