import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/db/tables/converters.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/import/import.dart';

/// The `dart` executable of the running SDK (null when none is found).
String? _dart() {
  final root = Platform.environment['FLUTTER_ROOT'];
  final candidates = [
    if (root != null) '$root/bin/dart',
    for (final dir in (Platform.environment['PATH'] ?? '').split(':'))
      if (dir.isNotEmpty) '$dir/dart',
  ];
  return candidates.where((c) => File(c).existsSync()).firstOrNull;
}

/// Runs `calendar_day_tz_probe.dart` in a separate Dart process with [tz] as
/// its time zone and returns the last line it printed.
Future<String> _probe(String dart, String tz, List<String> args) async {
  final r = await Process.run(dart, [
    'test/core/db/calendar_day_tz_probe.dart',
    ...args,
  ], environment: {'TZ': tz});
  expect(r.exitCode, 0, reason: '${r.stderr}');
  return '${r.stdout}'.trim().split('\n').last.trim();
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('CalendarDayConverter', () {
    const c = CalendarDayConverter();

    test('stores a zone-free noon UTC and reads local midnight of the same day', () {
      expect(c.toSql(DateTime(2026, 9, 1)), DateTime.utc(2026, 9, 1, 12));
      expect(c.toSql(DateTime(2026, 9, 1, 23, 59)), DateTime.utc(2026, 9, 1, 12));
      expect(c.fromSql(DateTime.utc(2026, 9, 1, 12)), DateTime(2026, 9, 1));
      expect(c.fromSql(c.toSql(DateTime(2026, 2, 28, 6))), DateTime(2026, 2, 28));
      expect(CalendarDayConverter.startOf(DateTime(2026, 9, 1, 18)), DateTime.utc(2026, 9, 1));
    });

    test('date-only columns are stored as UTC noon text and read back as the day', () async {
      final db = MadarDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repos = Repositories(db);
      final task = await repos.tasks.insert(TasksCompanion.insert(title: 't', date: Value(DateTime(2026, 9, 1, 21, 30))));
      expect(task.date, DateTime(2026, 9, 1));
      await repos.tasks.setColumn(task.id, 'date', DateTime(2026, 10, 1));
      final wallet = await repos.wallets.insert(WalletsCompanion.insert(name: 'w', currency: 'JOD'));
      await repos.transactions.insert(
        TransactionsCompanion.insert(walletId: wallet.id, kind: TxKind.expense, amountMilli: 1, date: DateTime(2026, 9, 1)),
      );
      final raw = await db.customSelect('SELECT t.date AS a, x.date AS b FROM tasks t, transactions x').getSingle();
      expect(raw.data['a'], '2026-10-01T12:00:00.000Z');
      expect(raw.data['b'], '2026-09-01T12:00:00.000Z');
      expect((await db.select(db.tasks).getSingle()).date, DateTime(2026, 10, 1));

      // Range queries with local-midnight bounds still find the day.
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 10, 1);
      final inSeptember = await (db.select(db.transactions)..where(
            (t) =>
                t.date.julianday.isBiggerOrEqual(Variable<DateTime>(start).julianday) &
                t.date.julianday.isSmallerThan(Variable<DateTime>(end).julianday),
          ))
          .get();
      expect(inSeptember, hasLength(1));
    });

    test('imported dates go through the same converter', () async {
      final db = MadarDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final importer = PrototypeImporter(labels: ImportLabels.forLanguage('en'));
      final plan = importer.analyze(
        '{"tasks": [{"title": "Renew", "date": "2026-09-01"}], '
        '"transactions": [{"amount": 5, "date": "2026-09-01T23:30:00"}]}',
        now: DateTime(2026, 9, 6),
      );
      await importer.commit(db, plan);
      final raw = await db.customSelect('SELECT t.date AS a, x.date AS b FROM tasks t, transactions x').getSingle();
      expect(raw.data['a'], '2026-09-01T12:00:00.000Z');
      expect(raw.data['b'], '2026-09-01T12:00:00.000Z');
    });

    test(
      'a day written in Amman is the same day in London and New York',
      () async {
        final dart = _dart();
        if (dart == null || !Directory('/usr/share/zoneinfo/Asia').existsSync()) {
          markTestSkipped('needs the dart executable and tzdata');
          return;
        }
        // The old mapping (local midnight + offset) moved the day west.
        expect(await _probe(dart, 'Europe/London', ['read', '2026-09-01T00:00:00.000 +03:00', '--legacy']), '2026-8-31');

        final stored = await _probe(dart, 'Asia/Amman', ['write', '2026', '9', '1']);
        expect(stored, '2026-09-01T12:00:00.000Z');
        final reads = await Future.wait([
          _probe(dart, 'Europe/London', ['read', stored]),
          _probe(dart, 'America/New_York', ['read', stored]),
          _probe(dart, 'Pacific/Honolulu', ['read', stored]),
        ]);
        expect(reads, everyElement('2026-9-1'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
