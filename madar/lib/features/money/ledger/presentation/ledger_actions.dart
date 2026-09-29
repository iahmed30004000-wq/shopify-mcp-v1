import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/domain/money.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/ledger_providers.dart';
import '../domain/ledger_book.dart';
import '../domain/ledger_format.dart';
import '../domain/ledger_models.dart';
import '../domain/tx_filter.dart';
import 'currencies_screen.dart';
import 'ledger_ui.dart';
import 'money_ledger_screen.dart';
import 'transactions_screen.dart';
import 'wallet_screen.dart';
import 'sheets/transaction_sheet.dart';
import 'widgets/tx_tile.dart';

/// Where the ledger's screens lead. The defaults push plain routes; the app
/// can override [ledgerRoutesProvider] to route through go_router instead.
class LedgerRoutes {
  const LedgerRoutes({this.ledger, this.wallet, this.transactions, this.currencies});

  final void Function(BuildContext context)? ledger;
  final void Function(BuildContext context, String walletId)? wallet;
  final void Function(BuildContext context, TxFilter filter)? transactions;
  final void Function(BuildContext context)? currencies;
}

final ledgerRoutesProvider = Provider<LedgerRoutes>((ref) => const LedgerRoutes());

/// The ledger's user actions (sheets, undo toasts, navigation).
abstract final class LedgerActions {
  // ------------------------------------------------------- navigation ----

  static void _push(BuildContext context, Widget page) {
    Fx.fire(Sfx.navigate);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  static void openLedger(BuildContext context, WidgetRef ref) {
    final custom = ref.read(ledgerRoutesProvider).ledger;
    if (custom != null) return custom(context);
    _push(context, const MoneyLedgerScreen());
  }

  static void openWallet(BuildContext context, WidgetRef ref, String walletId) {
    final custom = ref.read(ledgerRoutesProvider).wallet;
    if (custom != null) return custom(context, walletId);
    _push(context, WalletScreen(walletId: walletId));
  }

  static void openTransactions(BuildContext context, WidgetRef ref, {TxFilter filter = TxFilter.none}) {
    final custom = ref.read(ledgerRoutesProvider).transactions;
    if (custom != null) return custom(context, filter);
    _push(context, TransactionsScreen(filter: filter));
  }

  static void openCurrencies(BuildContext context, WidgetRef ref) {
    final custom = ref.read(ledgerRoutesProvider).currencies;
    if (custom != null) return custom(context);
    _push(context, const CurrenciesScreen());
  }

  // ----------------------------------------------------- transactions ----

  /// The row actions of a transaction list.
  static TxTileActions txActions(BuildContext context, WidgetRef ref) => TxTileActions(
    onEdit: (tx) => showTransactionSheet(context, transactionId: tx.id),
    onDuplicate: (tx) async {
      final l = L10n.of(context);
      final (_, undo) = await ref.read(ledgerServiceProvider).duplicate(tx.id);
      return UndoableAction(label: l.ledgerDuplicated, undo: undo);
    },
    onMove: (tx) => moveTransaction(context, ref, tx),
    onDelete: (tx) async {
      final l = L10n.of(context);
      final undo = await ref.read(ledgerServiceProvider).delete(tx.id);
      return UndoableAction(label: l.ledgerDeleted, undo: undo);
    },
  );

  /// Moves [tx] to another wallet (converting between currencies).
  static Future<UndoableAction?> moveTransaction(BuildContext context, WidgetRef ref, LedgerTx tx) async {
    final book = ref.read(ledgerBookProvider).value;
    if (book == null) return null;
    final l = L10n.of(context);
    final fmt = ledgerFormatOf(context, book);
    final fromCurrency = book.currencyOfWallet(tx.walletId) ?? book.baseCode;
    final targets = [
      for (final (i, w) in book.wallets.indexed)
        if (!w.archived || w.id == tx.walletId)
          MoveTarget(
            id: w.id,
            label: w.name,
            icon: LedgerStyle.walletIcon(w),
            color: LedgerStyle.wallet(context.tokens, w, i),
            subtitle: [
              l.walletKind(w.kind),
              if (w.currency != fromCurrency)
                () {
                  final converted = book.rates.convert(
                    tx.amountMilli,
                    fromCurrency,
                    w.currency,
                    decimals: fmt.decimalsOf(w.currency),
                  );
                  return converted == null ? l.ledgerNoRate : fmt.embed(fmt.amount(converted, w.currency));
                }(),
            ].join(' · '),
            isCurrent: w.id == tx.walletId,
            enabled:
                w.id != tx.walletId &&
                !(tx.isTransfer && tx.toWalletId == w.id) &&
                (w.currency == fromCurrency || book.rates.convert(1000, fromCurrency, w.currency) != null),
          ),
    ];
    final target = await showMoveSheet(
      context,
      title: l.ledgerMoveTitle,
      subtitle: TxTile.titleOf(tx, book, l),
      targets: targets,
      icon: Icons.account_balance_wallet_rounded,
    );
    if (target == null || !context.mounted) return null;
    final undo = await ref.read(ledgerServiceProvider).move(tx.id, target.id, book);
    if (undo == null) {
      Fx.fire(Sfx.error);
      return null;
    }
    final w = book.wallet(target.id)!;
    final name = LedgerMoneyFormat.isolate(w.name);
    if (w.currency != fromCurrency) {
      final converted = book.rates.convert(
        tx.amountMilli,
        fromCurrency,
        w.currency,
        decimals: fmt.decimalsOf(w.currency),
      );
      return UndoableAction(
        label: l.ledgerMovedConverted(name, fmt.embed(fmt.amount(converted ?? 0, w.currency))),
        undo: undo,
      );
    }
    return UndoableAction(label: l.ledgerMoved(name), undo: undo);
  }

  // ---------------------------------------------------------- wallets ----

  static const walletIconKeys = [
    'wallet',
    'coins',
    'savings',
    'receipt',
    'bag',
    'cart',
    'briefcase',
    'laptop',
    'handshake',
    'home',
    'car',
    'plane',
    'globe',
    'gift',
    'family',
    'star',
  ];

  /// Opens the wallet editor ([wallet] null = new). Returns the saved id.
  static Future<String?> editWallet(BuildContext context, WidgetRef ref, {LedgerWallet? wallet}) async {
    final book = ref.read(ledgerBookProvider).value;
    if (book == null) return null;
    final l = L10n.of(context);
    final fmt = ledgerFormatOf(context, book);
    final service = ref.read(ledgerServiceProvider);
    final locked = wallet != null && await service.transactionCount(wallet.id) > 0;
    if (!context.mounted) return null;
    final values = await showEditSheet(
      context,
      title: wallet == null ? l.ledgerAddWallet : l.ledgerWalletEdit,
      icon: Icons.account_balance_wallet_rounded,
      saveLabel: l.actionSave,
      initial: {
        'name': wallet?.name,
        'currency': wallet?.currency ?? book.baseCode,
        if (wallet != null && wallet.openingMilli != 0) 'opening': Money(wallet.openingMilli, wallet.currency).units,
        'kind': (wallet?.kind ?? WalletKind.personal).name,
        'color': ?wallet?.color,
        'icon': wallet?.icon ?? 'wallet',
      },
      fields: [
        FieldSpec.text(
          'name',
          l.ledgerWalletName,
          required: true,
          hint: l.ledgerWalletNameHint,
          icon: Icons.edit_rounded,
        ),
        FieldSpec.singleSelect(
          'currency',
          l.ledgerCurrenciesTitle,
          required: true,
          icon: Icons.currency_exchange_rounded,
          options: [
            for (final c in book.currencies)
              SelectOption(
                id: c.code,
                label: '${c.code} · ${c.name(arabic: fmt.arabic)}',
              ),
          ],
          validator: (v, _) => locked && v != wallet.currency ? l.ledgerCurrencyLocked : null,
        ),
        FieldSpec.number('opening', l.ledgerOpening, decimals: 3, icon: Icons.flag_rounded),
        FieldSpec.singleSelect(
          'kind',
          l.ledgerWalletKind,
          required: true,
          icon: Icons.category_rounded,
          options: [
            SelectOption(id: WalletKind.personal.name, label: l.ledgerPersonal, icon: Icons.person_rounded),
            SelectOption(id: WalletKind.business.name, label: l.ledgerBusiness, icon: Icons.storefront_rounded),
          ],
        ),
        FieldSpec.color('color', l.ledgerColor),
        FieldSpec.icon(
          'icon',
          l.ledgerIcon,
          icons: {
            for (final k in walletIconKeys)
              if (InteractionIcons.curated[k] != null) k: InteractionIcons.curated[k]!,
          },
        ),
      ],
    );
    if (values == null || !context.mounted) return null;
    final name = (values['name'] as String?)?.trim() ?? '';
    final currency = values['currency'] as String? ?? book.baseCode;
    final openingRaw = values['opening'];
    final opening = openingRaw is num ? (Rational.fromNum(openingRaw) * Rational.thousand).roundHalfUp() : 0;
    final kind = values['kind'] == WalletKind.business.name ? WalletKind.business : WalletKind.personal;
    final color = values['color'] as int?;
    final icon = values['icon'] as String?;
    if (wallet == null) {
      final created = await service.addWallet(
        name: name,
        currency: currency,
        openingMilli: opening,
        kind: kind,
        color: color,
        icon: icon,
      );
      Fx.fire(Sfx.complete);
      if (context.mounted) {
        unawaited(
          showUndoToast(
            context,
            UndoableAction(label: l.ledgerWalletSaved, undo: () => service.deleteWallet(created.id).then((_) {})),
          ),
        );
      }
      return created.id;
    }
    final undo = await service.updateWallet(
      wallet.id,
      name: name,
      currency: currency,
      openingMilli: opening,
      kind: kind,
      color: color,
      icon: icon,
    );
    Fx.fire(Sfx.complete);
    if (context.mounted) unawaited(showUndoToast(context, UndoableAction(label: l.ledgerWalletSaved, undo: undo)));
    return wallet.id;
  }

  static Future<UndoableAction?> toggleArchive(BuildContext context, WidgetRef ref, LedgerWallet wallet) async {
    final l = L10n.of(context);
    final undo = await ref.read(ledgerServiceProvider).setArchived(wallet.id, !wallet.archived);
    Fx.fire(wallet.archived ? Sfx.toggleOn : Sfx.toggleOff);
    return UndoableAction(label: wallet.archived ? l.ledgerUnarchivedToast : l.ledgerArchivedToast, undo: undo);
  }

  static Future<UndoableAction?> deleteWallet(BuildContext context, WidgetRef ref, LedgerWallet wallet) async {
    final l = L10n.of(context);
    final service = ref.read(ledgerServiceProvider);
    final count = await service.transactionCount(wallet.id);
    final undo = await service.deleteWallet(wallet.id);
    return UndoableAction(label: l.ledgerWalletDeleted(count), undo: undo);
  }

  /// The long-press actions of a wallet row.
  static ItemActions walletItemActions(BuildContext context, WidgetRef ref, LedgerWallet w) => ItemActions(
    onEdit: () => editWallet(context, ref, wallet: w),
    onDelete: () => deleteWallet(context, ref, w),
    extra: [
      ItemAction(
        icon: Icons.add_card_rounded,
        label: L10n.of(context).ledgerAddTx,
        tone: ActionTone.accent,
        onSelected: () async {
          await showTransactionSheet(context, walletId: w.id);
          return null;
        },
      ),
      ItemAction(
        icon: w.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
        label: w.archived ? L10n.of(context).ledgerUnarchive : L10n.of(context).ledgerArchive,
        tone: ActionTone.warning,
        onSelected: () => toggleArchive(context, ref, w),
      ),
    ],
  );

  /// The book, when loaded.
  static LedgerBook? bookOf(WidgetRef ref) => ref.read(ledgerBookProvider).value;
}
