// Visual critic pass for the ledger: renders the real screens with the real
// fonts and shaders and writes PNGs to madar/screenshots/phase5/ledger/*.png.
//
//   flutter test --tags screenshot test/features/money/ledger/ledger_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/widgets.dart' show MadarScaffold;
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/money/ledger/ledger.dart';

import '../../../helpers/screenshot_harness.dart';
import 'ledger_test_app.dart';

const _dir = 'phase5/ledger';
const _ar = Locale('ar');
const _en = Locale('en');

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _scrollBy(WidgetTester tester, double dy) async {
  final list = find.byType(Scrollable).hitTestable().first;
  final state = tester.state<ScrollableState>(list);
  state.position.jumpTo((state.position.pixels + dy).clamp(0, state.position.maxScrollExtent));
  await _frames(tester, 16);
}

Future<void> _openSheet(WidgetTester tester, Future<void> Function(BuildContext context) open) async {
  final context = tester.element(find.byType(Scaffold).first);
  open(context);
  await _frames(tester, 24);
}

/// Taps keypad keys ("12.5"), in either digit script.
Future<void> _keys(WidgetTester tester, String keys) async {
  for (final k in keys.split('')) {
    final western = k == '.' ? '.' : k;
    final indic = k == '.' ? '\u066B' : String.fromCharCode(0x0660 + int.parse(k));
    var f = find.text(western);
    if (f.evaluate().isEmpty) f = find.text(indic);
    await tester.tap(f.last);
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUp(installLedgerFx);

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = _ar,
    bool data = true,
    Future<void> Function(WidgetTester tester)? before,
  }) async {
    final db = await ledgerDb(tester, data: data, arabic: locale == _ar);
    await captureScreen(
      tester,
      ledgerTestApp(home: home, overrides: ledgerOverrides(db), theme: theme, locale: locale),
      '$_dir/$name',
      beforeCapture: before,
    );
  }

  testWidgets('hub – Arabic, Lapis', (tester) async {
    await shot(tester, 'hub_ar_lapis', const MoneyLedgerScreen());
  });

  testWidgets('hub – Arabic, Lapis, charts', (tester) async {
    await shot(tester, 'hub_ar_lapis_charts', const MoneyLedgerScreen(), before: (t) => _scrollBy(t, 1050));
  });

  testWidgets('hub – Arabic, Lapis, recent', (tester) async {
    await shot(tester, 'hub_ar_lapis_recent', const MoneyLedgerScreen(), before: (t) => _scrollBy(t, 2600));
  });

  testWidgets('hub – English, Pearl', (tester) async {
    await shot(tester, 'hub_en_pearl', const MoneyLedgerScreen(), theme: MadarThemeId.pearl, locale: _en);
  });

  testWidgets('hub – English, Pearl, charts', (tester) async {
    await shot(
      tester,
      'hub_en_pearl_charts',
      const MoneyLedgerScreen(),
      theme: MadarThemeId.pearl,
      locale: _en,
      before: (t) => _scrollBy(t, 1050),
    );
  });

  testWidgets('hub – Arabic, Pearl, charts', (tester) async {
    await shot(
      tester,
      'hub_ar_pearl_charts',
      const MoneyLedgerScreen(),
      theme: MadarThemeId.pearl,
      before: (t) => _scrollBy(t, 1050),
    );
  });

  testWidgets('hub – English, Lapis', (tester) async {
    await shot(tester, 'hub_en_lapis', const MoneyLedgerScreen(), locale: _en);
  });

  testWidgets('wallet – Arabic, Pearl', (tester) async {
    await shot(tester, 'wallet_ar_pearl', const WalletScreen(walletId: Ex.cash), theme: MadarThemeId.pearl);
  });

  testWidgets('transactions – English, Lapis', (tester) async {
    await shot(tester, 'transactions_en_lapis', const TransactionsScreen(), locale: _en);
  });

  testWidgets('hub – Arabic, Emerald, empty', (tester) async {
    await shot(tester, 'hub_ar_emerald_empty', const MoneyLedgerScreen(), theme: MadarThemeId.emerald, data: false);
  });

  testWidgets('wallet – Arabic, Lapis', (tester) async {
    await shot(tester, 'wallet_ar_lapis', const WalletScreen(walletId: Ex.cash));
  });

  testWidgets('wallet – English, Pearl, USD', (tester) async {
    await shot(
      tester,
      'wallet_en_pearl_usd',
      const WalletScreen(walletId: Ex.usd),
      theme: MadarThemeId.pearl,
      locale: _en,
    );
  });

  testWidgets('transactions – Arabic, Aurora', (tester) async {
    await shot(tester, 'transactions_ar_aurora', const TransactionsScreen(), theme: MadarThemeId.aurora);
  });

  testWidgets('transactions – English, Pearl, filtered', (tester) async {
    await shot(
      tester,
      'transactions_en_pearl_filtered',
      const TransactionsScreen(
        filter: TxFilter(budgetItemIds: {Ex.food}, tags: {'family'}),
      ),
      theme: MadarThemeId.pearl,
      locale: _en,
    );
  });

  testWidgets('sheet – Arabic, Lapis, expense', (tester) async {
    await shot(
      tester,
      'sheet_ar_lapis_expense',
      const MoneyLedgerScreen(),
      before: (t) async {
        await _openSheet(t, (c) => showTransactionSheet(c, walletId: Ex.cash, budgetItemId: Ex.proteins));
        await _keys(t, '12.5');
      },
    );
  });

  testWidgets('sheet – English, Pearl, transfer between currencies', (tester) async {
    await shot(
      tester,
      'sheet_en_pearl_transfer',
      const MoneyLedgerScreen(),
      theme: MadarThemeId.pearl,
      locale: _en,
      before: (t) async {
        await _openSheet(
          t,
          (c) => showTransactionSheet(c, kind: TxKind.transfer, walletId: Ex.usd, toWalletId: Ex.bank),
        );
        await _keys(t, '250');
      },
    );
  });

  testWidgets('sheet – Arabic, Desert, adjustment', (tester) async {
    await shot(
      tester,
      'sheet_ar_desert_adjust',
      const MoneyLedgerScreen(),
      theme: MadarThemeId.desert,
      before: (t) async {
        await _openSheet(t, (c) => showTransactionSheet(c, kind: TxKind.adjustment, walletId: Ex.cash));
        await _keys(t, '175');
      },
    );
  });

  testWidgets('budget picker – Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'picker_ar_lapis',
      const MoneyLedgerScreen(),
      before: (t) async {
        await _openSheet(t, (c) => showTransactionSheet(c, walletId: Ex.cash));
        await t.tap(find.text('اختر بند\u064Bا'));
        await _frames(t, 24);
      },
    );
  });

  testWidgets('currencies – Arabic, Lapis', (tester) async {
    await shot(tester, 'currencies_ar_lapis', const CurrenciesScreen());
  });

  testWidgets('currencies – English, Pearl', (tester) async {
    await shot(tester, 'currencies_en_pearl', const CurrenciesScreen(), theme: MadarThemeId.pearl, locale: _en);
  });

  testWidgets('rebase – Arabic, Emerald', (tester) async {
    await shot(
      tester,
      'rebase_ar_emerald',
      const CurrenciesScreen(),
      theme: MadarThemeId.emerald,
      before: (t) async {
        await t.tap(find.text('تغيير العملة الأساسية'));
        await _frames(t, 24);
      },
    );
  });

  testWidgets('summary card – Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'summary_ar_lapis',
      const MadarScaffold(
        body: Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 20), child: WalletsSummaryCard()),
      ),
    );
  });

  testWidgets('summary card – English, Pearl', (tester) async {
    await shot(
      tester,
      'summary_en_pearl',
      const MadarScaffold(
        body: Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 20), child: WalletsSummaryCard()),
      ),
      theme: MadarThemeId.pearl,
      locale: _en,
    );
  });
}
