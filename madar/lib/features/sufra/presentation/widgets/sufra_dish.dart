import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/pantry.dart';
import '../../domain/pantry_match.dart';
import '../sufra_actions.dart';
import '../sufra_nav.dart';
import '../sufra_texts.dart';
import 'sufra_widgets.dart';

/// One ingredient against the house, in one line – and for the three
/// verdicts Madar is not sure about, the line is the refusal itself plus
/// the one tap that fixes it.
///
/// It never shows a number Madar did not compute: a missing amount of null
/// is shown without one ([SufraTexts.check]).
class SufraCheckLine extends ConsumerWidget {
  const SufraCheckLine({super.key, required this.check, this.onFix, this.dense = false});

  final IngredientCheck check;

  /// Shown under the line when Madar could not judge the ingredient: the
  /// editor that makes the comparison possible (it differs per verdict, so
  /// the check comes back with the call). Null hides the fixes – the
  /// dish's own screen owns them.
  final void Function(IngredientCheck check)? onFix;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = SufraTexts.of(context);
    final p = SufraPalette.of(context);
    final text = Theme.of(context).textTheme;
    final color = switch (check.verdict) {
      IngredientVerdict.have => p.ready,
      IngredientVerdict.short => p.nearly,
      IngredientVerdict.missing => p.out,
      _ => p.unsure,
    };
    final loose = tx.loose(check);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Semantics(
        label: [tx.check(check), ?loose].join(' '),
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(sufraCheckIcon(check.verdict), size: dense ? 13 : 15, color: color),
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.check(check),
                    style: (dense ? text.bodySmall : text.bodyMedium)?.copyWith(
                      color: check.verdict == IngredientVerdict.have ? t.textSecondary : t.textPrimary,
                    ),
                  ),
                  if (loose != null) Text(loose, style: text.labelSmall?.copyWith(color: t.textTertiary)),
                  if (check.ingredient.optional)
                    Text(
                      L10n.of(context).sufraOptionalIngredient,
                      style: text.labelSmall?.copyWith(color: t.textTertiary),
                    ),
                  if (onFix != null && check.unknown) ...[
                    const SizedBox(height: Space.xs),
                    _Fixes(check: check, onFix: onFix!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The honest way out of an ingredient Madar refused to judge: write it in
/// the same measure, say how much there is, or tell it that two of her
/// words mean one thing.
class _Fixes extends ConsumerWidget {
  const _Fixes({required this.check, required this.onFix});

  final IngredientCheck check;
  final void Function(IngredientCheck check) onFix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final id = check.ingredient.id;
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.xs,
      children: [
        if (check.verdict == IngredientVerdict.unknownUnit)
          MadarChip(
            key: ValueKey('sufra.fix.unit.$id'),
            label: l.sufraFixUnit,
            icon: Icons.straighten_rounded,
            dense: true,
            onSelected: (_) => onFix(check),
          ),
        if (check.verdict == IngredientVerdict.unknownAmount)
          MadarChip(
            key: ValueKey('sufra.fix.amount.$id'),
            label: l.sufraFixAmount,
            icon: Icons.numbers_rounded,
            dense: true,
            onSelected: (_) => onFix(check),
          ),
        if (check.verdict == IngredientVerdict.ambiguous)
          for (final candidate in check.candidates)
            MadarChip(
              key: ValueKey('sufra.fix.alias.$id.${candidate.item.id}'),
              label: l.sufraMakeAlias(tx.name(candidate.item.name)),
              icon: Icons.sell_outlined,
              dense: true,
              onSelected: (_) => SufraActions.makeAlias(context, ref, candidate, check.ingredient.name),
            ),
      ],
    );
  }
}

/// One dish, ranked against the house.
///
/// Three rules, straight from the engine's own handoff: an `unsure` dish is
/// **never** shown as cookable (no «طبختها» on it, and the reason is on the
/// card); a dish the window holds says when she cooked it and when it comes
/// back; and a missing amount Madar does not know is shown without a
/// number.
class SufraDishCard extends ConsumerWidget {
  const SufraDishCard({super.key, required this.match, this.showChecks = true, this.maxChecks = 4, this.onOpen});

  final RecipeMatch match;

  /// Show what is missing / what could not be judged under the name.
  final bool showChecks;

  /// At most this many lines before the card stops listing (the dish's own
  /// screen shows them all).
  final int maxChecks;

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = SufraTexts.of(context);
    final p = SufraPalette.of(context);
    final text = Theme.of(context).textTheme;
    final recipe = match.recipe;
    final held = tx.held(match.hold);
    // A dish the window holds, or one a hard rule stops, is never painted
    // in the colour of a dish she can cook – whatever the house says about
    // its ingredients.
    final color = match.blocked
        ? p.out
        : match.hold.held
        ? t.textTertiary
        : p.verdict(match.verdict);
    final icon = match.blocked
        ? Icons.block_rounded
        : match.hold.held
        ? Icons.history_rounded
        : sufraVerdictIcon(match.verdict);
    final freeFrom = tx.freeFrom(match.hold);
    final facts = [
      ?tx.servings(recipe.servings),
      ?tx.minutes(recipe.minutes),
      ?tx.scaledFor(match.scaledFor),
    ].join(l.commonFactSeparator);
    final shopping = match.shopping;
    final unsure = match.unsureChecks;
    final shown = showChecks
        ? [
            for (final c in [...unsure, ...shopping]) c,
          ].take(maxChecks).toList()
        : const <IngredientCheck>[];

    return SufraCard(
      key: ValueKey('sufra.dish.${recipe.id}'),
      onTap: onOpen ?? () => sufraOpenRecipe(context, ref, recipe.id),
      semanticLabel: [
        recipe.name,
        match.blocked ? l.sufraBlockedTitle : tx.verdict(match.verdict),
        if (shopping.isNotEmpty) tx.missingCount(match.missingCount),
        ?held,
        for (final hit in match.hits) tx.breach(hit),
      ].join(l.commonFactSeparator),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: t.isDark ? 0.14 : 0.10),
                    border: Border.all(color: color.withValues(alpha: 0.45)),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              recipe.name,
                              style: text.titleSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (recipe.favorite) ...[
                            const SizedBox(width: Space.xs),
                            Icon(Icons.star_rounded, size: 14, color: t.gold),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      // A dish a hard rule stops never says «بتقدري
                      // تطبخيها هلأ»: whatever the house holds, today the
                      // answer is no, and the reason is right under it.
                      Text(
                        match.blocked ? l.sufraBlockedTitle : tx.verdict(match.verdict),
                        style: text.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
                      ),
                      if (facts.isNotEmpty) Text(facts, style: text.labelSmall?.copyWith(color: t.textTertiary)),
                      // Whose dish it is, under its own name – never a pill
                      // beside it, which would squeeze the name on a long
                      // word or at a big text size.
                      if (recipe.isImported)
                        Text(tx.source(recipe), style: text.labelSmall?.copyWith(color: t.textTertiary)),
                    ],
                  ),
                ),
              ],
            ),
            if (tx.usesExpiring(match) case final reason?) ...[
              const SizedBox(height: Space.s),
              SufraNote(reason, icon: Icons.schedule_rounded, color: p.nearly),
            ],
            // Held by «بدون تكرار»: when she cooked it, and the day it is
            // free again. Never a dish quietly missing.
            if (held != null) ...[
              const SizedBox(height: Space.s),
              SufraNote([held, ?freeFrom].join(l.commonFactSeparator), icon: Icons.history_rounded),
            ],
            for (final hit in match.hits) ...[
              const SizedBox(height: Space.s),
              SufraNote(
                tx.breach(hit),
                icon: hit.hard ? Icons.block_rounded : Icons.do_not_disturb_on_outlined,
                color: hit.hard ? p.out : p.nearly,
              ),
            ],
            // Madar cannot work this dish out, and says why instead of
            // putting it on her table.
            if (match.verdict == MatchVerdict.unsure && unsure.isNotEmpty) ...[
              const SizedBox(height: Space.s),
              SufraNote(l.sufraUnsureNote, icon: Icons.help_outline_rounded, color: p.unsure),
            ],
            if (shown.isNotEmpty) ...[
              const SizedBox(height: Space.s),
              for (final c in shown) SufraCheckLine(check: c, dense: true),
              if (unsure.length + shopping.length > shown.length)
                Text(tx.missingCount(match.missingCount), style: text.labelSmall?.copyWith(color: t.textTertiary)),
            ],
            if (match.cookable || shopping.isNotEmpty) ...[
              const SizedBox(height: Space.m),
              Row(
                children: [
                  // Only a dish Madar is sure about can be cooked from
                  // here: `cookable` is false for every unsure dish, for a
                  // blocked one and for one the window holds.
                  if (match.cookable)
                    Expanded(
                      child: MadarButton(
                        key: ValueKey('sufra.dish.${recipe.id}.cook'),
                        label: l.sufraCookedIt,
                        icon: Icons.local_fire_department_rounded,
                        size: MadarButtonSize.small,
                        sfx: Sfx.complete,
                        onPressed: () => SufraActions.cook(context, ref, match),
                      ),
                    ),
                  if (match.cookable && shopping.isNotEmpty) const SizedBox(width: Space.s),
                  if (shopping.isNotEmpty)
                    Expanded(
                      child: MadarButton(
                        key: ValueKey('sufra.dish.${recipe.id}.missing'),
                        label: l.sufraAddToList,
                        icon: Icons.add_shopping_cart_rounded,
                        variant: MadarButtonVariant.secondary,
                        size: MadarButtonSize.small,
                        onPressed: () async {
                          final listId = await SufraActions.missingToList(context, ref, match);
                          if (listId != null && context.mounted) sufraOpenList(context, ref, listId);
                        },
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// «خلص: زيت · فات تاريخه: لبن · قلّ: رز» – the top of the pantry, worst
/// first, grouped by what is wrong.
class SufraAttentionLines extends StatelessWidget {
  const SufraAttentionLines({super.key, required this.attention});

  final List<PantryStock> attention;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final p = SufraPalette.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    if (attention.isEmpty) {
      return SufraNote(l.sufraAttentionNone, icon: Icons.check_circle_outline_rounded, color: p.ready);
    }
    // The board is already worst first; keep that order for the groups too.
    final groups = <PantryState, List<PantryStock>>{};
    for (final s in attention) {
      (groups[s.state] ??= []).add(s);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final MapEntry(key: state, value: stocks) in groups.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(sufraStateIcon(state), size: 15, color: p.state(state)),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(
                    l.sufraAttentionGroup(
                      tx.state(state),
                      [for (final s in stocks) tx.name(s.item.name)].join(l.recordListSeparator),
                    ),
                    style: text.bodySmall?.copyWith(color: t.textPrimary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
