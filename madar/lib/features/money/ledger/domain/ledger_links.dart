/// Entries other Money packages write into a wallet on the user's behalf
/// (pure Dart).
///
/// The goals package books a jar deposit / withdrawal and a debt payment as
/// a signed [TxKind.adjustment], and an obligation marked "Paid" as an
/// [TxKind.expense]. Each such row is the wallet half of a pair – its id
/// links it to the jar movement, debt payment or obligation payment – so the
/// ledger shows it but leaves editing, moving, duplicating and deleting to
/// the owning screen (changing one half alone would split the pair).
///
/// The id prefixes and tags mirror the goals package's
/// `GoalsService.jarTxId / debtTxId / obligationTxId` and
/// `GoalsService.tagJar / tagDebt / tagObligation`.
library;

import 'ledger_models.dart';

/// Where a linked entry comes from.
enum LedgerLink { jar, debt, obligation }

abstract final class LedgerLinks {
  static const String jarPrefix = 'jar-tx-';
  static const String debtPrefix = 'debt-tx-';
  static const String obligationPrefix = 'ob-tx-';

  /// Tags the goals package writes on its entries.
  static const Map<String, LedgerLink> systemTags = {
    'jar': LedgerLink.jar,
    'debt': LedgerLink.debt,
    'obligation': LedgerLink.obligation,
  };

  static const Map<LedgerLink, String> _prefixes = {
    LedgerLink.jar: jarPrefix,
    LedgerLink.debt: debtPrefix,
    LedgerLink.obligation: obligationPrefix,
  };

  /// The link of the entry with id [id] (null for the user's own entries).
  static LedgerLink? ofId(String id) {
    for (final e in _prefixes.entries) {
      if (id.startsWith(e.value) && id.length > e.value.length) return e.key;
    }
    return null;
  }

  /// The link of [tx] (null for the user's own entries).
  static LedgerLink? of(LedgerTx tx) => ofId(tx.id);

  /// Whether [tx] belongs to another screen (see the library doc).
  static bool isLinked(LedgerTx tx) => of(tx) != null;

  /// The id of the other half (jar movement, debt payment or obligation
  /// payment), or null for the user's own entries.
  static String? sourceId(LedgerTx tx) {
    final link = of(tx);
    return link == null ? null : tx.id.substring(_prefixes[link]!.length);
  }

  /// The link a tag stands for (null for the user's own tags).
  static LedgerLink? ofTag(String tag) => systemTags[tag.trim().toLowerCase()];

  /// The tags worth showing on [tx]'s row: a linked entry's own system tag
  /// repeats what its row already says and is left out.
  static List<String> visibleTags(LedgerTx tx) {
    final link = of(tx);
    if (link == null) return tx.tags;
    return [
      for (final t in tx.tags)
        if (ofTag(t) != link) t,
    ];
  }
}
