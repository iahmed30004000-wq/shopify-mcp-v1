import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../lists/lists.dart';
import '../../ledger/data/ledger_providers.dart';
import '../data/shopping_post_service.dart';

/// The bar under a budget envelope's shopping list: what posting would
/// charge («٣ أغراض — ٨٫٠٠٠ د.أ على بقالة»), the one button that posts it,
/// and – once it was posted – what was posted and that the rest stayed on
/// the list.
///
/// Nothing here computes money: the amount is the engine's exact sum and
/// the entry is written by the ledger's own service.
class ShoppingPostBar extends ConsumerStatefulWidget {
  const ShoppingPostBar({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<ShoppingPostBar> createState() => _ShoppingPostBarState();
}

class _ShoppingPostBarState extends ConsumerState<ShoppingPostBar> {
  bool _busy = false;

  Future<void> _post(ListPostPlan plan, String? envelopeName) async {
    if (_busy) return;
    final l = L10n.of(context);
    final service = ref.read(shoppingPostServiceProvider);
    final bundle = ref.read(listBundleProvider(widget.listId)).value;
    if (bundle == null) return;
    final currencies = ref.read(listCurrenciesProvider).value ?? ListCurrencies.fallback;
    final code = currencies.of(bundle.currency);
    final wallets = await service.walletsIn(code);
    if (!mounted || wallets.isEmpty) return;

    String walletId = wallets.first.id;
    if (wallets.length > 1) {
      final target = await showMoveSheet(
        context,
        title: l.listsPostWalletTitle,
        icon: Icons.account_balance_wallet_rounded,
        targets: [
          for (final w in wallets) MoveTarget(id: w.id, label: w.name, icon: Icons.account_balance_wallet_rounded),
        ],
      );
      if (target == null || !mounted) return;
      walletId = target.id;
    }

    setState(() => _busy = true);
    final ListTexts texts = ListTexts.of(context, currencies);
    try {
      final result = await service.post(widget.listId, walletId: walletId);
      if (!mounted) return;
      final undo = result.undo;
      if (!result.posted || undo == null) {
        // The only refusal reachable from a tap is a race another tap (or
        // another screen) won: the bar rebuilds and says so itself.
        Fx.fire(Sfx.error);
        return;
      }
      Fx.fire(Sfx.complete);
      final name = result.envelopeName ?? envelopeName ?? '';
      unawaited(
        showUndoToast(
          context,
          UndoableAction(
            label: l.listsPostToast(texts.money(result.plan.amountMilli, bundle.currency), texts.name(name)),
            undo: () async {
              await undo();
              Fx.fire(Sfx.undo);
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _refusal(L10n l, ListPostRefusal? refusal) => switch (refusal) {
    ListPostRefusal.alreadyPosted => l.listsPostRefusedAlready,
    ListPostRefusal.nothingTicked => l.listsPostRefusedNothing,
    ListPostRefusal.noAmount => l.listsPostRefusedNoAmount,
    ListPostRefusal.noWallet => l.listsPostRefusedNoWallet,
    ListPostRefusal.listGone => l.listsPostRefusedGone,
    ListPostRefusal.notAnEnvelope => l.listsPostRefusedHost,
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final bundle = ref.watch(listBundleProvider(widget.listId)).value;
    if (bundle == null || bundle.host.table != ListHost.budgetItems) return const SizedBox.shrink();

    final currencies = ref.watch(listCurrenciesProvider).value ?? ListCurrencies.fallback;
    final texts = ListTexts.of(context, currencies);
    final code = currencies.of(bundle.currency);
    final wallets = ref.watch(ledgerWalletsProvider).value ?? const [];
    final payable = [
      for (final w in wallets)
        if (!w.archived && w.currency.toUpperCase() == code) w,
    ];
    final envelope = ref.watch(hostNameProvider(bundle.host)).value;
    final plan = bundle.plan(currency: code, hasWallet: payable.isNotEmpty);

    final refusal = _refusal(l, plan.refusal);
    final where = envelope == null ? '' : l.listsPostOnEnvelope(texts.name(envelope));
    // Nothing ticked yet: say what to do, never «٠ غرض — ٠٫٠٠٠ د.أ».
    final (String headline, String second) = switch (plan) {
      _ when bundle.posted => (
        l.listsPostedNote(
          texts.money(bundle.row.postedAmountMilli ?? plan.amountMilli, bundle.currency),
          texts.name(envelope ?? ''),
        ),
        l.listsPostedKeepsOpen,
      ),
      ListPostPlan(itemCount: 0) => (refusal ?? l.listsPostRefusedNothing, where),
      _ => (texts.postSummary(plan.itemCount, texts.money(plan.amountMilli, bundle.currency)), refusal ?? where),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.glassFill,
        border: BorderDirectional(top: BorderSide(color: t.brass.withValues(alpha: 0.45))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.m, Space.gutter, Space.m),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      headline,
                      key: const ValueKey('lists.post.summary'),
                      style: text.titleSmall!.copyWith(color: bundle.posted ? t.success : t.textPrimary),
                    ),
                    if (second.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 2),
                        child: Text(
                          second,
                          key: const ValueKey('lists.post.second'),
                          style: text.bodySmall!.copyWith(color: t.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Space.m),
              if (!bundle.posted)
                MadarButton(
                  key: const ValueKey('lists.post.button'),
                  label: l.listsPostButton,
                  icon: Icons.receipt_long_rounded,
                  size: MadarButtonSize.medium,
                  loading: _busy,
                  sfx: Sfx.tap,
                  onPressed: plan.canPost ? () => unawaited(_post(plan, envelope)) : null,
                )
              else
                Icon(Icons.verified_rounded, color: t.success, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
