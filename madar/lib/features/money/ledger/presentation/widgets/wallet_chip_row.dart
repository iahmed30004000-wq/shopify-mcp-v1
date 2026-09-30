import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/interaction/sheets/field_inputs.dart' show KitChip;
import '../../../../../core/sound/sound_api.dart';
import '../../domain/ledger_book.dart';
import '../../domain/ledger_models.dart';
import '../ledger_ui.dart';

/// A horizontal row of wallet chips (the transaction sheet's wallet
/// pickers). The selected chip is scrolled into view when the row appears,
/// and the chips' glow is not clipped by the row.
class WalletChipRow extends StatefulWidget {
  const WalletChipRow({
    super.key,
    required this.book,
    required this.wallets,
    required this.selected,
    required this.onPick,
    this.disabled,
  });

  final LedgerBook book;
  final List<LedgerWallet> wallets;
  final String? selected;
  final ValueChanged<String> onPick;

  /// A wallet shown dimmed that cannot be picked (the transfer's source).
  final String? disabled;

  @override
  State<WalletChipRow> createState() => _WalletChipRowState();
}

class _WalletChipRowState extends State<WalletChipRow> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _selectedKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(target, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (i, w) in widget.wallets.indexed) ...[
            if (i > 0) const SizedBox(width: Space.s),
            Opacity(
              key: w.id == widget.selected ? _selectedKey : null,
              opacity: w.id == widget.disabled ? 0.4 : 1,
              child: KitChip(
                label: w.name,
                icon: LedgerStyle.walletIcon(w),
                swatch: LedgerStyle.wallet(t, w, widget.book.wallets.indexOf(w)),
                selected: w.id == widget.selected,
                sfx: Sfx.tap,
                onTap: () {
                  if (w.id == widget.disabled) {
                    Fx.fire(Sfx.error);
                    return;
                  }
                  widget.onPick(w.id);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
