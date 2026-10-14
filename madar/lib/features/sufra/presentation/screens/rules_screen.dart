import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/sufra_providers.dart';
import '../../domain/no_repeat.dart';
import '../../domain/sufra_settings.dart';
import '../sufra_actions.dart';
import '../sufra_texts.dart';
import '../widgets/sufra_widgets.dart';

/// «محدداتي» – her standing constraints, and the few choices the kitchen
/// remembers.
///
/// A hard rule (an allergy, a request for tonight) stops a dish outright;
/// «أفضّل أبعد عنه» only pushes it down and says why; «أفضّله» only moves it
/// up. The card at the top says exactly that, in her words.
///
/// The one tie to his meal plan ([SufraSettings.dietMode]) is **not** on
/// this screen: it is his switch on his own copy, and until he turns it on
/// «السفرة» knows nothing about it.
class KitchenRulesScreen extends ConsumerWidget {
  const KitchenRulesScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = SufraPalette.of(context);
    final rows = ref.watch(kitchenRuleRowsProvider).value ?? const <KitchenRuleRow>[];
    final settings = ref.watch(sufraSettingsProvider).value ?? const SufraSettings();

    return MadarScaffold(
      title: l.sufraConstraintsTitle,
      backdropSeed: 9.5,
      animateBackdrop: animateBackdrop,
      floatingAction: MadarButton.icon(
        key: const ValueKey('sufra.rules.add'),
        icon: Icons.add_rounded,
        semanticLabel: l.sufraAddRule,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
        onPressed: () => SufraActions.addRule(context, ref),
      ),
      body: ReorderableGlassList<KitchenRuleRow>(
        items: rows,
        itemKey: (r) => r.id,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, sufraBottomPadding),
        spacing: Space.s,
        itemBorderRadius: BorderRadius.circular(t.radiusL),
        header: Padding(
          padding: const EdgeInsets.only(bottom: Space.m),
          child: SufraCard(
            key: const ValueKey('sufra.rules.explainer'),
            title: l.sufraConstraintsTitle,
            icon: Icons.rule_rounded,
            iconColor: p.rule,
            seed: 9.5,
            child: Text(
              l.sufraRuleHardNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
            ),
          ),
        ),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.l),
                child: AnimatedEmptyState(
                  key: const ValueKey('sufra.rules.empty'),
                  kind: EmptyStateKind.emptyList,
                  title: l.sufraRulesEmptyTitle,
                  body: l.sufraRulesEmptyBody,
                  actionLabel: l.sufraAddRule,
                  actionIcon: Icons.add_rounded,
                  onAction: () => SufraActions.addRule(context, ref),
                ),
              ),
            KitchenSettingsCard(settings: settings),
          ],
        ),
        onReorder: (order) => unawaited(ref.read(sufraServiceProvider).reorderRules([for (final r in order) r.id])),
        itemBuilder: (context, row, index, grip) => KitchenRuleTile(row: row, grip: grip),
      ),
    );
  }
}

/// One constraint of hers: what kind it is, the word, and who it is for.
class KitchenRuleTile extends ConsumerWidget {
  const KitchenRuleTile({super.key, required this.row, this.grip});

  final KitchenRuleRow row;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = SufraTexts.of(context);
    final p = SufraPalette.of(context);
    final text = Theme.of(context).textTheme;
    final line = [
      tx.ruleKind(row.kind),
      ?(row.who == null || row.who!.trim().isEmpty ? null : tx.name(row.who)),
      if (!row.active) l.sufraRuleOff,
    ].join(l.commonFactSeparator);

    return ActionableItem(
      key: ValueKey('sufra.rule.${row.id}'),
      semanticLabel: '${row.term}, $line',
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => SufraActions.editRule(context, ref, row),
      actions: ItemActions(
        onEdit: () => SufraActions.editRule(context, ref, row),
        onDelete: () => SufraActions.deleteRule(context, ref, row),
        extra: [
          ItemAction(
            icon: row.active ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
            label: row.active ? l.sufraRuleOff : l.sufraRuleActive,
            onSelected: () => SufraActions.toggleRule(context, ref, row),
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: row.active ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
          label: row.active ? l.sufraRuleOff : l.sufraRuleActive,
          onPressed: () => SufraActions.toggleRule(context, ref, row),
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.sufraDelete,
          tone: ActionTone.danger,
          onPressed: () => SufraActions.deleteRule(context, ref, row),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.xs, Space.m),
        borderRadius: BorderRadius.circular(t.radiusL),
        child: ExcludeSemantics(
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.rule.withValues(alpha: t.isDark ? 0.14 : 0.10),
                  border: Border.all(color: p.rule.withValues(alpha: 0.45)),
                ),
                child: Icon(
                  row.active ? Icons.rule_rounded : Icons.pause_rounded,
                  size: 18,
                  color: row.active ? p.rule : t.textTertiary,
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      row.term,
                      style: text.titleSmall?.copyWith(color: row.active ? t.textPrimary : t.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(line, style: text.bodySmall?.copyWith(color: t.textTertiary)),
                    if (row.note != null && row.note!.trim().isNotEmpty)
                      Text(row.note!.trim(), style: text.labelSmall?.copyWith(color: t.textTertiary)),
                  ],
                ),
              ),
              ?grip,
            ],
          ),
        ),
      ),
    );
  }
}

/// The few choices the kitchen remembers: her no-repeat window, how early
/// an expiry warns, how many usually eat, and how much missing still counts
/// as «قريبة».
class KitchenSettingsCard extends ConsumerWidget {
  const KitchenSettingsCard({super.key, required this.settings});

  final SufraSettings settings;

  /// How early an expiry warns, in days.
  static const List<int> warningChoices = [0, 1, 2, 3, 5, 7];

  /// How many missing things still count as a near match.
  static const List<int> nearlyChoices = [1, 2, 3, 4, 5];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final tx = SufraTexts.of(context);
    final p = SufraPalette.of(context);
    final text = Theme.of(context).textTheme;

    Widget row(String label, Widget chips) => Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: text.labelLarge),
          const SizedBox(height: Space.s),
          chips,
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: Space.l),
      child: SufraCard(
        key: const ValueKey('sufra.settings'),
        title: l.sufraSettingsSectionTitle,
        icon: Icons.settings_outlined,
        iconColor: p.pantry,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row(
              l.sufraWindowLabel,
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final (days, label) in tx.windowChoices)
                    MadarChip(
                      key: ValueKey('sufra.window.$days'),
                      label: label,
                      selected: settings.noRepeatDays == NoRepeat.window(days),
                      dense: true,
                      onSelected: (_) => SufraActions.setSettings(context, ref, settings.copyWith(noRepeatDays: days)),
                    ),
                ],
              ),
            ),
            row(
              l.sufraExpiryWarningLabel,
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final days in warningChoices)
                    MadarChip(
                      key: ValueKey('sufra.warning.$days'),
                      label: tx.daysBefore(days),
                      selected: settings.expiryWarningDays == days,
                      dense: true,
                      onSelected: (_) =>
                          SufraActions.setSettings(context, ref, settings.copyWith(expiryWarningDays: days)),
                    ),
                ],
              ),
            ),
            row(
              l.sufraDefaultPeopleLabel,
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  MadarChip(
                    key: const ValueKey('sufra.defaultPeople.none'),
                    label: l.sufraAnyPeople,
                    selected: settings.defaultPeople == null,
                    dense: true,
                    onSelected: (_) =>
                        SufraActions.setSettings(context, ref, settings.copyWith(clearDefaultPeople: true)),
                  ),
                  for (final n in const [2, 3, 4, 5, 6, 8, 10])
                    MadarChip(
                      key: ValueKey('sufra.defaultPeople.$n'),
                      label: tx.people(n),
                      selected: settings.defaultPeople == n,
                      dense: true,
                      onSelected: (_) => SufraActions.setSettings(context, ref, settings.copyWith(defaultPeople: n)),
                    ),
                ],
              ),
            ),
            row(
              l.sufraNearlyLimitLabel,
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final n in nearlyChoices)
                    MadarChip(
                      key: ValueKey('sufra.nearlyLimit.$n'),
                      label: tx.things(n),
                      selected: settings.nearlyLimit == n,
                      dense: true,
                      onSelected: (_) => SufraActions.setSettings(context, ref, settings.copyWith(nearlyLimit: n)),
                    ),
                ],
              ),
            ),
            SufraNote(tx.pantryCount(ref.watch(pantryBoardProvider).live.length), icon: Icons.inventory_2_outlined),
          ],
        ),
      ),
    );
  }
}
