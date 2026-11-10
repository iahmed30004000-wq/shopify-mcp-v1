import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/money/ledger/domain/amount_entry.dart';
import 'package:madar/features/money/ledger/domain/ledger_models.dart';
import 'package:madar/features/money/ledger/domain/tx_draft.dart';
import 'package:madar/features/money/ledger/domain/tx_filter.dart';

import 'ledger_fixtures.dart';

AmountEntry type(String keys, {int decimals = 3}) {
  var e = AmountEntry('', decimals);
  for (final k in keys.split('')) {
    e = e.press(switch (k) {
      '.' => KeypadKey.decimal,
      '<' => KeypadKey.backspace,
      'C' => KeypadKey.clear,
      _ => KeypadKey.ofDigit(int.parse(k)),
    });
  }
  return e;
}

void main() {
  group('keypad', () {
    test('digits and decimals to exact milli', () {
      expect(type('12.5').milli, 12500);
      expect(type('0.005').milli, 5);
      expect(type('.5').text, '0.5');
      expect(type('007').text, '7');
      expect(type('').milli, 0);
    });

    test('limits decimals per currency and a single point', () {
      expect(type('1.2345').text, '1.234');
      expect(type('1.234', decimals: 2).text, '1.23');
      expect(type('1.5', decimals: 0).text, '15');
      expect(type('1..2').text, '1.2');
    });

    test('backspace and clear', () {
      expect(type('12.5<').text, '12.');
      expect(type('12.5<<<').text, '1');
      expect(type('12C').text, '');
      expect(type('<').text, '');
    });

    test('at most twelve integer digits', () {
      expect(type('1234567890123').text, '123456789012');
    });

    test('fromMilli trims the fraction and respects decimals', () {
      expect(AmountEntry.fromMilli(12500).text, '12.5');
      expect(AmountEntry.fromMilli(-200000).text, '200');
      expect(AmountEntry.fromMilli(12345, decimals: 2).text, '12.34');
      expect(AmountEntry.fromMilli(0).text, '');
    });

    test('exact keeps a stored fraction finer than the currency', () {
      final e = AmountEntry.exact(12345, decimals: 2);
      expect((e.text, e.decimals, e.milli), ('12.345', 3, 12345));
      expect(AmountEntry.exact(12340, decimals: 2).decimals, 2);
      expect(AmountEntry.exact(-7000, decimals: 0).text, '7');
      expect(AmountEntry.exact(7500, decimals: 0).decimals, 1);
    });

    test('withDecimals truncates when the currency changes', () {
      expect(type('1.234').withDecimals(2).text, '1.23');
      expect(type('1.2').withDecimals(0).text, '1');
      expect(type('12').withDecimals(2).milli, 12000);
    });
  });

  group('draft', () {
    final book = sampleBook();
    String? currencyOf(String id) => book.currencyOfWallet(id);
    final day = DateTime(2026, 9, 20);

    test('expense needs a wallet and an amount', () {
      expect(TxDraft(date: day).validate(), [TxDraftError.noWallet, TxDraftError.noAmount]);
      expect(TxDraft(date: day, walletId: 'cash', amountMilli: 1).validate(), isEmpty);
    });

    test('transfer: destination, not the same wallet, convertible', () {
      final base = TxDraft(date: day, kind: TxKind.transfer, walletId: 'cash', amountMilli: 70900);
      expect(base.validate(), [TxDraftError.noDestination]);
      expect(base.copyWith(toWalletId: 'cash').validate(), [TxDraftError.sameWallet]);
      final toBank = base.copyWith(toWalletId: 'bank');
      expect(toBank.validate(currencyOf: currencyOf, rates: book.rates), isEmpty);
      expect(toBank.resolvedToAmount(fromCurrency: 'JOD', toCurrency: 'USD', rates: book.rates, toDecimals: 2), 100000);
      // An explicit received amount wins.
      expect(
        toBank
            .copyWith(toAmountMilli: 99500)
            .resolvedToAmount(fromCurrency: 'JOD', toCurrency: 'USD', rates: book.rates),
        99500,
      );
      final noRate = TxDraft(date: day, kind: TxKind.transfer, walletId: 'cash', toWalletId: 'x', amountMilli: 5);
      expect(noRate.validate(currencyOf: (id) => id == 'x' ? 'XYZ' : 'JOD', rates: book.rates), [TxDraftError.noRate]);
    });

    test('adjustment: set balance stores the difference', () {
      final d = TxDraft(date: day, kind: TxKind.adjustment, walletId: 'cash', amountMilli: 150000);
      expect(d.adjustmentDelta(148000), 2000);
      expect(d.copyWith(negative: true).adjustmentDelta(10000), -160000);
      expect(d.validate(currentBalanceMilli: 150000), [TxDraftError.noChange]);
      final delta = d.copyWith(adjustMode: AdjustMode.delta, amountMilli: 500, negative: true);
      expect(delta.adjustmentDelta(999), -500);
    });

    test('write: expense keeps its item, tags are trimmed and unique', () {
      final d = TxDraft(
        date: DateTime(2026, 9, 20, 18, 30),
        walletId: 'cash',
        amountMilli: 4250,
        budgetItemId: 'proteins',
        note: '  Chicken  ',
        tags: const ['family', ' family ', '', 'weekly'],
      );
      final w = TxWrite.of(d, currencyOf: currencyOf, rates: book.rates)!;
      expect(w.kind, TxKind.expense);
      expect(w.amountMilli, 4250);
      expect(w.date, DateTime(2026, 9, 20));
      expect(w.note, 'Chicken');
      expect(w.tags, ['family', 'weekly']);
      expect(w.budgetItemId, 'proteins');
    });

    test('write: a transfer never carries a budget item; the rate fills the received amount', () {
      final d = TxDraft(
        date: day,
        kind: TxKind.transfer,
        walletId: 'bank',
        toWalletId: 'cash',
        amountMilli: 100000,
        budgetItemId: 'car',
      );
      final w = TxWrite.of(d, currencyOf: currencyOf, rates: book.rates, decimalsOf: (_) => 3)!;
      expect(w.budgetItemId, isNull);
      expect(w.toAmountMilli, 70900);
    });

    test('write: adjustment stores the signed delta; invalid drafts give null', () {
      final d = TxDraft(date: day, kind: TxKind.adjustment, walletId: 'cash', amountMilli: 100000);
      expect(
        TxWrite.of(d, currencyOf: currencyOf, rates: book.rates, currentBalanceMilli: 148000)!.amountMilli,
        -48000,
      );
      expect(
        TxWrite.of(
          TxDraft(date: day),
          currencyOf: currencyOf,
          rates: book.rates,
        ),
        isNull,
      );
    });

    test('fromTx round-trips', () {
      final t = book.transaction('adj')!;
      final d = TxDraft.fromTx(t);
      expect(d.kind, TxKind.adjustment);
      expect(d.adjustMode, AdjustMode.delta);
      expect(d.signedAmountMilli, 3000);
      final neg = TxDraft.fromTx(tx('n', 'cash', TxKind.adjustment, -700));
      expect(neg.negative, isTrue);
      expect(neg.adjustmentDelta(0), -700);
    });
  });

  group('filters', () {
    final book = sampleBook();

    List<String> ids(TxFilter f) => [for (final t in f.apply(book.transactions, book)) t.id];

    test('empty filter keeps everything (newest first)', () {
      expect(ids(TxFilter.none), ['xfer', 'lunch', 'adj', 'fuel', 'spice', 'meat', 'salary', 'aug']);
      expect(TxFilter.none.isEmpty, isTrue);
    });

    test('wallet includes transfers into it', () {
      expect(ids(const TxFilter(walletIds: {'shop'})), ['xfer', 'aug']);
    });

    test('kinds, budget subtree, unassigned', () {
      expect(ids(const TxFilter(kinds: {TxKind.income})), ['salary']);
      expect(ids(const TxFilter(budgetItemIds: {'food'})), ['spice', 'meat']);
      expect(ids(const TxFilter(unassignedOnly: true)), ['lunch', 'salary', 'aug']);
    });

    test('tags, date range, wallet kind', () {
      expect(ids(const TxFilter(tags: {'car'})), ['fuel']);
      expect(ids(TxFilter(from: DateTime(2026, 9, 4), to: DateTime(2026, 9, 6))), ['adj', 'fuel', 'spice']);
      expect(ids(const TxFilter(walletKind: WalletKind.business)), ['xfer', 'aug']);
    });

    test('search: notes, tags, names, Arabic forms and amounts', () {
      expect(ids(const TxFilter(query: 'cairo')), ['lunch']);
      expect(ids(const TxFilter(query: 'FAMILY')), ['spice', 'meat']);
      expect(ids(const TxFilter(query: 'proteins')), ['meat']);
      expect(ids(const TxFilter(query: 'shop')), ['xfer', 'aug']);
      expect(ids(const TxFilter(query: '30')), ['fuel']);
      expect(ids(const TxFilter(query: '٣٠')), ['fuel']);
      expect(LedgerSearch.normalize('إ\u0650فطار  الأ\u064Fسرة'), 'افطار الاسره');
    });

    test('activeCount and equality', () {
      const f = TxFilter(walletIds: {'a'}, kinds: {TxKind.expense}, query: 'x');
      expect(f.activeCount, 2);
      expect(f.withoutQuery, const TxFilter(walletIds: {'a'}, kinds: {TxKind.expense}));
      expect(f.copyWith(clearDates: true, from: DateTime(2026)).from, isNull);
    });

    test('day groups: newest day first, newest entry first', () {
      final groups = TxGrouping.byDay([
        tx('a', 'cash', TxKind.expense, 1, date: DateTime(2026, 9, 2), createdAt: DateTime(2026, 9, 2, 8)),
        tx('b', 'cash', TxKind.expense, 1, date: DateTime(2026, 9, 2), createdAt: DateTime(2026, 9, 2, 9)),
        tx('c', 'cash', TxKind.expense, 1, date: DateTime(2026, 9, 3)),
      ]);
      expect(groups.map((g) => g.day), [DateTime(2026, 9, 3), DateTime(2026, 9, 2)]);
      expect(groups.last.txs.map((t) => t.id), ['b', 'a']);
    });
  });

  test('currency names fall back sensibly', () {
    expect(const LedgerCurrency(code: 'X', nameEn: 'Ex').name(arabic: true), 'Ex');
    expect(const LedgerCurrency(code: 'X').name(arabic: false), 'X');
  });
}
