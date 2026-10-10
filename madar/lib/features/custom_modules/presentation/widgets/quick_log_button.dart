import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/interaction/sheets/field_inputs.dart' show StarRating;
import '../../../../core/motion/motion_kit.dart';
import '../../custom_texts.dart';
import '../../domain/module_schema.dart';
import '../../domain/module_summary.dart';
import '../custom_modules_actions.dart';
import 'module_visuals.dart';

/// The round one-tap control of a tracker row: tick today (check-in
/// modules), rate today (rating modules), +1 (counters) – or open the entry
/// form when the module needs one.
class QuickLogButton extends ConsumerWidget {
  const QuickLogButton({super.key, required this.summary, this.size = 44});

  final ModuleSummary summary;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final m = summary.module;
    final c = ModuleColors.of(m.colorArgb, t);
    final quick = m.quickEntry;
    final (IconData icon, bool filled, String label, String? hint, String? badge) = switch (quick) {
      QuickCheck() when summary.checkedToday => (
        Icons.check_rounded,
        true,
        l.cmodQuickChecked,
        l.cmodQuickCheckedHint,
        null,
      ),
      QuickCheck() => (Icons.check_rounded, false, l.cmodQuickDone, l.cmodQuickDoneHint, null),
      QuickRate() => (
        Icons.star_rounded,
        summary.todayRating != null,
        l.cmodQuickRate,
        summary.todayRating == null ? null : tx.stars(summary.todayRating!),
        summary.todayRating == null ? null : tx.count(summary.todayRating!),
      ),
      QuickCount() => (
        Icons.add_rounded,
        false,
        l.cmodQuickAddOne,
        tx.loggedToday(summary.todayCount),
        summary.todayCount > 0 ? tx.count(summary.todayCount) : null,
      ),
      null => (Icons.add_rounded, false, l.cmodActionAddEntry, null, null),
    };

    Future<void> onTap() async {
      if (quick is QuickRate) {
        final stars = await showQuickRateSheet(context, m);
        if (stars == null || !context.mounted) return;
        await CustomModulesActions.quickLog(context, ref, m, rating: stars);
      } else {
        await CustomModulesActions.quickLog(context, ref, m);
      }
    }

    return Semantics(
      button: true,
      toggled: quick is QuickCheck ? summary.checkedToday : null,
      label: '$label · ${tx.name(m.name)}',
      hint: hint,
      excludeSemantics: true,
      child: SpringPress(
        sfx: null,
        onTap: onTap,
        child: SizedBox.square(
          dimension: size + 4,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: context.motion(MadarMotion.short),
                curve: MadarMotion.standard,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? c.base : c.soft,
                  border: Border.all(color: filled ? c.base : c.base.withValues(alpha: 0.55), width: 1.4),
                  boxShadow: filled ? [BoxShadow(color: c.glow, blurRadius: 14, spreadRadius: 1)] : null,
                ),
                child: Icon(icon, size: size * 0.5, color: filled ? c.onBase : c.ink),
              ),
              if (badge != null)
                PositionedDirectional(
                  top: -2,
                  end: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: t.space1,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: c.base.withValues(alpha: 0.7)),
                    ),
                    child: Text(
                      badge,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(color: c.ink, fontWeight: FontWeight.w700, height: 1.2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact sheet with big stars: the tap on a star is the rating.
Future<int?> showQuickRateSheet(BuildContext context, ModuleDefinition m) {
  final quick = m.quickEntry;
  final max = quick is QuickRate ? quick.max : 5;
  return showInteractionSheet<int>(
    context,
    builder: (ctx) {
      final tx = CustomTexts.of(ctx);
      return InteractionSheetFrame(
        title: tx.l.cmodQuickRate,
        subtitle: tx.name(m.name),
        icon: ModuleIcons.module(m.iconKey),
        body: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: Space.l),
            child: FittedBox(
              child: StarRating(
                value: null,
                max: max,
                allowClear: false,
                semanticLabel: tx.l.cmodQuickRate,
                onChanged: (v) {
                  if (v != null) Navigator.of(ctx).pop(v);
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
