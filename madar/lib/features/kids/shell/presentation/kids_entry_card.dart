import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../lock/application/lock_controller.dart';
import '../../../lock/presentation/pin_sheets.dart' show showPinSetupSheet;
import '../application/kids_actions.dart';
import 'kids_palette.dart';

/// Makes sure a parent PIN exists, offering to set one first. True when one
/// exists (so the door has a key), false when the parent backed out or secure
/// storage could not be read.
Future<bool> ensureParentPin(BuildContext context, WidgetRef ref) async {
  final lock = ref.read(lockControllerProvider.notifier);
  final record = await lock.load();
  if (record == null) return false;
  if (record.hasPin) return true;
  if (!context.mounted) return false;
  final l = L10n.of(context);
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.kidsShellNeedPinTitle),
      content: Text(l.kidsShellNeedPinBody),
      actions: [
        TextButton(
          key: const ValueKey('kids-need-pin-action'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.kidsShellNeedPinAction),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return false;
  final result = await showPinSetupSheet(context);
  if (result == null) return false;
  await lock.setPin(result.pin, biometrics: result.biometrics);
  return true;
}

/// The card at the top of Settings (docs/kids screen 1a): one tap, «ادخل».
/// The first time (no PIN yet) the parent sets one first; then the phone is the
/// child's and only the PIN or the fingerprint gets back.
class KidsEntryCard extends ConsumerWidget {
  const KidsEntryCard({super.key});

  Future<void> _enter(BuildContext context, WidgetRef ref) async {
    if (!await ensureParentPin(context, ref)) return;
    ref.read(kidsActionsProvider).enter();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Semantics(
        container: true,
        child: DecoratedBox(
          key: const ValueKey('kids-entry-card'),
          decoration: BoxDecoration(
            color: KidsColors.paper,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: KidsColors.sun500, width: 3),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const KhatamStar(
                      size: 64,
                      color: KidsColors.sun500,
                      child: Icon(Icons.stars_rounded, color: KidsColors.teal700, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.kidsShellEntryTitle, style: KidsText.title(KidsColors.night900, size: 28)),
                          Text(l.kidsShellEntrySubtitle, style: KidsText.text(KidsColors.ink2, size: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                KidsBigButton(
                  key: const ValueKey('kids-enter'),
                  label: l.kidsShellEntryButton,
                  icon: Icons.chevron_left_rounded,
                  tone: KidsButtonTone.teal,
                  onPressed: () => unawaited(_enter(context, ref)),
                ),
                const SizedBox(height: 8),
                Text(
                  l.kidsShellEntryRule,
                  textAlign: TextAlign.center,
                  style: KidsText.text(KidsColors.ink2, size: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
