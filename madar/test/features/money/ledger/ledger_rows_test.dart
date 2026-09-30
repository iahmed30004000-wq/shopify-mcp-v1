// Row texts of the transaction list: titles, detail lines and their bidi
// isolation (no widgets pumped).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/money/ledger/domain/ledger_models.dart';
import 'package:madar/features/money/ledger/presentation/widgets/tx_tile.dart';

import 'ledger_fixtures.dart';

void main() {
  final ar = lookupL10n(const Locale('ar'));
  final en = lookupL10n(const Locale('en'));
  const fsi = '⁨', lri = '⁦', rli = '⁧', pdi = '⁩';
  final book = sampleBook();
  final xfer = book.transaction('xfer')!; // Bank → Shop

  test('a route follows the UI direction, whatever the wallet names\' script', () {
    // English names in the Arabic UI: the Arabic arrow must still read
    // right to left, so the route is an RTL isolate.
    expect(TxTile.titleOf(xfer, book, ar), '$rli${fsi}Bank$pdi ← ${fsi}Shop$pdi$pdi');
    expect(TxTile.titleOf(xfer, book, en), '$lri${fsi}Bank$pdi → ${fsi}Shop$pdi$pdi');
  });

  test('seen from a wallet, a transfer names the other side', () {
    expect(TxTile.titleOf(xfer, book, en, perspectiveWalletId: 'bank'), 'Transfer to ${fsi}Shop$pdi');
    expect(TxTile.titleOf(xfer, book, en, perspectiveWalletId: 'shop'), 'Transfer from ${fsi}Bank$pdi');
  });

  test('a transfer with a note shows the route in the detail line', () {
    final noted = LedgerTx(
      id: 'n',
      walletId: 'bank',
      kind: TxKind.transfer,
      amountMilli: 1000,
      date: DateTime(2026, 9, 9),
      toWalletId: 'shop',
      note: 'Float',
    );
    expect(TxTile.titleOf(noted, book, en), 'Float');
    expect(TxTile.detailOf(noted, book, en, showWallet: true), '$lri${fsi}Bank$pdi → ${fsi}Shop$pdi$pdi');
  });

  test('detail parts are isolated one by one', () {
    final lunch = LedgerTx(
      id: 'l',
      walletId: 'cash',
      kind: TxKind.expense,
      amountMilli: 5000,
      date: DateTime(2026, 9, 9),
      budgetItemId: 'proteins',
      note: 'Lunch',
    );
    expect(TxTile.detailOf(lunch, book, en, showWallet: true), '${fsi}Home food › Proteins$pdi · ${fsi}Cash$pdi');
    expect(TxTile.detailOf(lunch, book, en, showWallet: false), '${fsi}Home food › Proteins$pdi');
  });

  test('a jar entry reads as its jar', () {
    final jar = LedgerTx(
      id: 'jar-tx-7',
      walletId: 'cash',
      kind: TxKind.adjustment,
      amountMilli: -20000,
      date: DateTime(2026, 9, 9),
      note: 'سفر',
      tags: const ['jar'],
    );
    expect(TxTile.titleOf(jar, book, ar), 'سفر');
    expect(TxTile.detailOf(jar, book, ar, showWallet: true), '$fsiحصّالة$pdi · ${fsi}Cash$pdi');
    final unnamed = LedgerTx(
      id: 'jar-tx-8',
      walletId: 'cash',
      kind: TxKind.adjustment,
      amountMilli: -1000,
      date: DateTime(2026, 9, 9),
    );
    expect(TxTile.titleOf(unnamed, book, en), 'Savings jar');
  });
}
