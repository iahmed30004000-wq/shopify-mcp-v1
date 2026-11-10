import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../body/presentation/widgets/body_widgets.dart';
import '../../domain/food_rules.dart';
import '../../domain/plan_compare.dart';
import '../../domain/risk.dart';
import '../nutrition_texts.dart';

/// The food screens' semantic colours, all derived from the theme tokens so
/// every theme (Pearl included) keeps its contrast.
class NutritionPalette {
  NutritionPalette(this.t);

  factory NutritionPalette.of(BuildContext context) => NutritionPalette(context.tokens);

  final MadarTokens t;

  /// Food itself: the warm end of the planet.
  Color get food => Color.lerp(t.gold, t.warning, 0.35)!;
  Color get foodEnd => t.gold;

  /// The meal plan.
  Color get plan => t.info;

  /// His conditions and his rules.
  Color get condition => t.secondary;

  /// Observations.
  Color get insight => t.highlight;

  /// A level's colour. `none` is deliberately the calm success colour: it
  /// means "none of your rules fired", not "good food".
  Color level(RiskLevel l) => switch (l) {
    RiskLevel.none => t.success,
    RiskLevel.low => t.info,
    RiskLevel.medium => t.warning,
    RiskLevel.high => t.danger,
  };

  Color status(SlotStatus s) => switch (s) {
    SlotStatus.eatenOnTime => t.success,
    SlotStatus.eatenLate => t.warning,
    SlotStatus.swapped => t.info,
    SlotStatus.skipped => t.danger,
    SlotStatus.pending => t.textTertiary,
  };
}

IconData nutritionStatusIcon(SlotStatus s) => switch (s) {
  SlotStatus.eatenOnTime => Icons.check_circle_rounded,
  SlotStatus.eatenLate => Icons.schedule_rounded,
  SlotStatus.swapped => Icons.swap_horiz_rounded,
  SlotStatus.skipped => Icons.remove_circle_outline_rounded,
  SlotStatus.pending => Icons.hourglass_empty_rounded,
};

IconData nutritionLevelIcon(RiskLevel l) => switch (l) {
  RiskLevel.none => Icons.check_circle_outline_rounded,
  RiskLevel.low => Icons.info_outline_rounded,
  RiskLevel.medium => Icons.warning_amber_rounded,
  RiskLevel.high => Icons.priority_high_rounded,
};

/// A rating pill. It is only ever built where a rating exists – the screens
/// show nothing at all when `nutritionHasRatingProvider` is false.
class NutritionLevelPill extends StatelessWidget {
  const NutritionLevelPill({super.key, required this.level, this.dense = false, this.label});

  final RiskLevel level;
  final bool dense;

  /// Overrides the level's own word.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    return BodyPill(
      label: label ?? tx.level(level),
      icon: nutritionLevelIcon(level),
      color: p.level(level),
      dense: dense,
    );
  }
}

/// One reason behind a rating: his sentence, with the rule's parts under it.
class NutritionReasonLine extends StatelessWidget {
  const NutritionReasonLine({super.key, required this.reason});

  final RiskReason reason;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final text = Theme.of(context).textTheme;
    final p = NutritionPalette.of(context);
    final color = p.level(switch (reason.weight) {
      RiskWeight.low => RiskLevel.low,
      RiskWeight.medium => RiskLevel.medium,
      RiskWeight.high => RiskLevel.high,
    });
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.85)),
            ),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(tx.reason(reason), style: text.bodySmall?.copyWith(color: t.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// A slot's outcome as a small chip («بوقتها» / «ما أكلتها» …).
class NutritionStatusChip extends StatelessWidget {
  const NutritionStatusChip({super.key, required this.status, this.dense = true});

  final SlotStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    return BodyPill(label: tx.status(status), icon: nutritionStatusIcon(status), color: p.status(status), dense: dense);
  }
}

/// A row of "open that screen" tiles, like the life hubs' tools.
class NutritionToolTiles extends StatelessWidget {
  const NutritionToolTiles({super.key, required this.tools});

  /// icon, title, hint, tap.
  final List<(IconData, String, String, VoidCallback)> tools;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (icon, title, hint, onTap) in tools)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: GlassCard(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
              borderRadius: BorderRadius.circular(t.radiusL),
              onTap: onTap,
              semanticLabel: '$title. $hint',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48 - 2 * Space.m),
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: t.gold),
                      const SizedBox(width: Space.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title, style: text.titleSmall),
                            const SizedBox(height: 2),
                            Text(hint, style: text.bodySmall?.copyWith(color: t.textTertiary)),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: t.textTertiary,
                        textDirection: Directionality.of(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The invitation shown instead of a rating while he has written no rule.
/// Nothing numeric appears: no rules, no rating.
class NutritionNoRulesCard extends StatelessWidget {
  const NutritionNoRulesCard({super.key, required this.onWriteRule});

  final VoidCallback onWriteRule;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = NutritionPalette.of(context);
    return BodyCard(
      key: const ValueKey('nutrition.noRules'),
      title: l.nutritionNoRulesTitle,
      icon: Icons.rule_rounded,
      iconColor: p.condition,
      seed: 4.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.nutritionNoRulesBody,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: Space.m),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MadarButton(
              label: l.nutritionWriteFirstRule,
              icon: Icons.add_rounded,
              variant: MadarButtonVariant.secondary,
              size: MadarButtonSize.small,
              sfx: Sfx.sheetOpen,
              onPressed: onWriteRule,
            ),
          ),
        ],
      ),
    );
  }
}
