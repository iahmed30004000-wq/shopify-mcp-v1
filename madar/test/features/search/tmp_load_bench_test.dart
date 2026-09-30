// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/search/search.dart';

void main() {
  test('load bench', () async {
    final dir = Directory.systemTemp.createTempSync('madar_bench');
    addTearDown(() => dir.deleteSync(recursive: true));
    final db = MadarDatabase(DatabaseConnection(NativeDatabase.createInBackground(File('${dir.path}/db.sqlite'))));
    final r = Repositories(db);
    final w = await r.wallets.insert(WalletsCompanion.insert(name: 'cash', currency: 'JOD'));
    final rnd = Random(1);
    await db.batch((b) => b.insertAll(db.transactions, [
      for (var i = 0; i < 20000; i++)
        TransactionsCompanion.insert(walletId: w.id, kind: TxKind.expense, amountMilli: 500 + rnd.nextInt(90000), date: DateTime(2026, 1, 1).add(Duration(days: i % 900)), note: Value('note $i')),
    ]));
    final c = SearchLoadContext(repos: r, l10n: lookupL10n(const Locale('ar')), formatter: MadarFormatter(languageCode: 'ar'));
    final src = BuiltInSearchSources.all().firstWhere((s) => s.id == 'transactions');
    for (var round = 0; round < 3; round++) {
      var sw = Stopwatch()..start();
      await r.transactions.getAll();
      print('getAll: ${sw.elapsedMilliseconds}');
      sw = Stopwatch()..start();
      await c.mapRows(r.transactions, (t) => null);
      print('mapRows(null): ${sw.elapsedMilliseconds}');
      sw = Stopwatch()..start();
      for (var i = 0; i < 20000; i++) { c.money(500 + i, 'JOD'); }
      print('money x20k: ${sw.elapsedMilliseconds}');
      sw = Stopwatch()..start();
      final docs = await src.load(c);
      print('source.load: ${sw.elapsedMilliseconds} (${docs.length})');
      sw = Stopwatch()..start();
      var h = 0; for (final d in docs) { h ^= d.withSource('transactions').contentHash; }
      print('hash: ${sw.elapsedMilliseconds} $h');
    }
    await db.close();
  });
}
