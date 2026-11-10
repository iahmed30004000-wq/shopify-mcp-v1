import 'package:drift/drift.dart' show DataClass;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../orbit/data/orbit_providers.dart';
import '../domain/list_money.dart';
import '../domain/record_list.dart';
import 'list_service.dart';

/// The list engine's wall clock (follows the orbit's, so a test freezes
/// them all at once).
final listClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// Every read and write of the shared list engine.
final listServiceProvider = Provider<ListService>(
  (ref) => ListService(ref.watch(repositoriesProvider), clock: ref.watch(listClockProvider)),
);

/// The lists of one host record, in his own order.
final hostListsProvider = StreamProvider.family<List<RecordListRow>, ListHost>(
  (ref, host) => ref.watch(listServiceProvider).watchLists(host),
);

/// Ticked / total and the exact amounts of each list of one host, keyed by
/// list id.
final hostListTotalsProvider = StreamProvider.family<Map<String, ListTotals>, ListHost>(
  (ref, host) => ref.watch(listServiceProvider).watchHostTotals(host),
);

/// How many lists hang on each record of one table (`budget_items` →
/// `{itemId: 2}`): what a host's own row shows without loading the lists.
final listHostCountsProvider = StreamProvider.family<Map<String, int>, String>(
  (ref, table) => ref.watch(listServiceProvider).watchHostCounts(table),
);

/// Every list in the database, in his own order (the all-lists screen,
/// which groups them by host itself).
final allListsProvider = StreamProvider<List<RecordListRow>>(
  (ref) => ref.watch(listServiceProvider).watchAllLists(),
);

/// Ticked / total and the exact amounts of **every** list, keyed by list
/// id (a list with no items of its own is simply absent).
final allListTotalsProvider = StreamProvider<Map<String, ListTotals>>(
  (ref) => ref.watch(listServiceProvider).watchAllTotals(),
);

/// One list with its lines and totals (null once it is deleted).
final listBundleProvider = StreamProvider.family<ListBundle?, String>(
  (ref, listId) => ref.watch(listServiceProvider).watchBundle(listId),
);

/// The base currency, each currency's decimals and the user's own symbols
/// (read straight from `currencies`: the list engine needs no part of the
/// Money package to show a price).
final listCurrenciesProvider = StreamProvider<ListCurrencies>((ref) {
  return ref.watch(repositoriesProvider).currencies.watchAll().map((rows) {
    final list = rows.toList();
    if (list.isEmpty) return ListCurrencies.fallback;
    final base = list.where((c) => c.isBase).firstOrNull?.code ?? list.first.code;
    return ListCurrencies(
      base: base.toUpperCase(),
      decimals: {for (final c in list) c.code.toUpperCase(): c.decimals},
      symbols: {
        for (final c in list)
          if (c.symbol.trim().isNotEmpty) c.code.toUpperCase(): c.symbol.trim(),
      },
      codes: [for (final c in list) c.code.toUpperCase()],
    );
  });
});

/// The name of a host record («بقالة», «عمّان»), or null when that record
/// was deleted – read generically, so a new host needs no change here: the
/// first filled text of `name`, `destination`, `title` or `body`.
final hostNameProvider = StreamProvider.family<String?, ListHost>((ref, host) {
  final repos = ref.watch(repositoriesProvider);
  final repo = repos.forTable(host.table);
  if (repo == null) return Stream<String?>.value(null);
  return repo.watchById(host.id).map((row) => row == null ? null : hostDisplayName(row));
});

/// The display name inside a host row (see [hostNameProvider]).
String? hostDisplayName(DataClass row) {
  final json = row.toJson();
  for (final key in const ['name', 'destination', 'title', 'body']) {
    final v = json[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}
