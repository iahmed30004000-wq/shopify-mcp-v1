import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../data/sufra_providers.dart';
import '../sufra_actions.dart';
import '../sufra_texts.dart';
import 'sufra_dish.dart';
import 'sufra_widgets.dart';

/// «سفرة اليوم» on the kitchen world's page: what needs attention in the
/// house, and the one dish Madar can honestly suggest tonight.
///
/// When there is nothing to suggest it says so («ما في إشي بقدر أقترحه»)
/// and offers to add a dish – never an invented one.
class SufraTodayCard extends ConsumerWidget {
  const SufraTodayCard({super.key, required this.onOpen, this.onOpenPantry});

  /// Opens «شو نطبخ اليوم».
  final VoidCallback onOpen;

  /// Opens «شو في بالبيت» (defaults to [onOpen]).
  final VoidCallback? onOpenPantry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = SufraTexts.of(context);
    final p = SufraPalette.of(context);
    final text = Theme.of(context).textTheme;
    final board = ref.watch(sufraBoardProvider);
    final tonight = board.tonight;
    final attention = board.attention;

    return SufraCard(
      key: const ValueKey('sufra.today'),
      title: l.sufraHubCardTitle,
      icon: Icons.restaurant_rounded,
      iconColor: p.ready,
      seed: 9.0,
      onTap: onOpen,
      semanticLabel: [
        l.sufraHubCardTitle,
        if (tonight != null) '${tonight.recipe.name}, ${tx.verdict(tonight.verdict)}',
        if (tonight == null) l.sufraSuggestionsEmptyTitle,
      ].join(l.commonFactSeparator),
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: t.textTertiary),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SufraAttentionLines(attention: attention),
            const SizedBox(height: Space.m),
            if (tonight == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.sufraSuggestionsEmptyTitle, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    board.recipes.isEmpty ? l.sufraRecipesEmptyBody : l.sufraSuggestionsEmptyBody,
                    style: text.bodySmall?.copyWith(color: t.textTertiary),
                  ),
                  const SizedBox(height: Space.m),
                  MadarButton(
                    key: const ValueKey('sufra.today.addRecipe'),
                    label: l.sufraAddRecipe,
                    icon: Icons.add_rounded,
                    variant: MadarButtonVariant.secondary,
                    size: MadarButtonSize.small,
                    expand: true,
                    onPressed: () => SufraActions.addRecipe(context, ref),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(sufraVerdictIcon(tonight.verdict), size: 18, color: p.verdict(tonight.verdict)),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tonight.recipe.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          tx.verdict(tonight.verdict),
                          style: text.bodySmall?.copyWith(color: p.verdict(tonight.verdict)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
