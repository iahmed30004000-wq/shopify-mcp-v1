import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../body/presentation/widgets/body_widgets.dart';
import '../../data/nutrition_providers.dart';
import '../nutrition_texts.dart';
import 'nutrition_widgets.dart';

/// Food at a glance for the Body hub and for the top of the food tab: what
/// he logged today, how much of his plan he kept, and today's rating – the
/// rating only when he has written a rule, never otherwise.
class NutritionTodayCard extends ConsumerWidget {
  const NutritionTodayCard({super.key, this.onOpen, this.onQuickLog});

  /// Opens the food tab (the hub passes this; the tab itself does not).
  final VoidCallback? onOpen;

  /// Opens the quick-log sheet.
  final VoidCallback? onQuickLog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    final text = Theme.of(context).textTheme;
    final summary = ref.watch(nutritionSummaryProvider);
    final hasRating = ref.watch(nutritionHasRatingProvider);
    final risk = summary.risk;
    final count = summary.entryCountToday;
    return BodyCard(
      key: const ValueKey('nutrition.todayCard'),
      title: l.nutritionCardTitle,
      icon: Icons.restaurant_rounded,
      iconColor: p.food,
      seed: 2.7,
      onTap: onOpen,
      semanticLabel: onOpen == null ? null : '${l.nutritionCardTitle}. ${l.nutritionCardOpen}',
      trailing: onOpen == null
          ? null
          : Icon(Icons.chevron_right_rounded, color: t.textTertiary, textDirection: Directionality.of(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tx.fmt.localizeDigits(l.nutritionEntriesToday(count, tx.fmt.formatInt(count))),
            style: text.titleSmall,
          ),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              BodyPill(
                label: tx.fmt.localizeDigits(l.nutritionLoggedDays(summary.loggedDays7, tx.fmt.formatInt(summary.loggedDays7))),
                icon: Icons.event_available_rounded,
                color: p.food,
                dense: true,
              ),
              if (summary.hasPlan)
                BodyPill(
                  label: tx.adherence(summary.adherenceToday),
                  icon: Icons.event_note_rounded,
                  color: p.plan,
                  dense: true,
                ),
              // No rules, no rating: nothing stands in for it here.
              if (hasRating && risk != null) NutritionLevelPill(level: risk.level, dense: true),
            ],
          ),
          if (onQuickLog != null) ...[
            const SizedBox(height: Space.m),
            MadarButton(
              key: const ValueKey('nutrition.quickLog'),
              label: l.nutritionQuickLog,
              icon: Icons.add_rounded,
              variant: MadarButtonVariant.primary,
              expand: true,
              sfx: Sfx.sheetOpen,
              onPressed: onQuickLog,
            ),
          ],
        ],
      ),
    );
  }
}
