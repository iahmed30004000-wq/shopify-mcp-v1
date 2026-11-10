import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../data/sufra_providers.dart';
import '../../domain/constraints.dart';
import '../../domain/pantry_match.dart';
import '../sufra_actions.dart';
import '../sufra_nav.dart';
import '../sufra_texts.dart';
import '../widgets/sufra_dish.dart';
import '../widgets/sufra_widgets.dart';

/// «شو نطبخ اليوم» – the heart of «السفرة».
///
/// What she can cook **now** first, then the near ones with exactly what is
/// missing and how much, then the ones Madar could not work out – each
/// saying what it could not compare and offering the fix – then the ones
/// «بدون تكرار» is holding (with the override) and, last, the ones a hard
/// rule says no to today.
///
/// A dish Madar is unsure about never appears among the ones she can cook,
/// and never carries a «طبختها» tap: the engine's `cookable` is false for
/// every one of them, and the card asks it.
class TonightScreen extends ConsumerWidget {
  const TonightScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final p = SufraPalette.of(context);
    final board = ref.watch(sufraBoardProvider);
    final extra = ref.watch(kitchenConstraintsProvider);
    final cookNow = board.cookNow;
    final nearly = board.nearly;
    final matches = board.matches;
    final unsure = [
      for (final m in matches)
        if (m.verdict == MatchVerdict.unsure && !m.hold.held) m,
    ];
    final held = [
      for (final m in matches)
        if (m.hold.held) m,
    ];
    final blocked = ref.watch(blockedMatchesProvider);

    return MadarScaffold(
      title: l.sufraSuggestionsTitle,
      backdropSeed: 9.2,
      animateBackdrop: animateBackdrop,
      body: ListView(
        key: const PageStorageKey('sufra.tonight'),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, sufraBottomPadding),
        children: [
          TonightChoices(extra: extra),
          const SizedBox(height: Space.m),
          SufraCard(
            key: const ValueKey('sufra.tonight.attention'),
            title: l.sufraAttentionTitle,
            icon: Icons.kitchen_outlined,
            iconColor: p.pantry,
            seed: 9.2,
            onTap: () => sufraGo(context, ref, SufraDestination.pantry),
            child: SufraAttentionLines(attention: board.attention),
          ),
          if (board.recipes.isEmpty || matches.isEmpty && blocked.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.l),
              child: AnimatedEmptyState(
                key: const ValueKey('sufra.tonight.empty'),
                kind: EmptyStateKind.noData,
                title: l.sufraSuggestionsEmptyTitle,
                body: l.sufraSuggestionsEmptyBody,
                actionLabel: l.sufraAddRecipe,
                actionIcon: Icons.add_rounded,
                onAction: () => SufraActions.addRecipe(context, ref),
              ),
            ),
          if (cookNow.isNotEmpty) ...[
            SufraSectionTitle(l.sufraCookNowTitle, icon: Icons.check_circle_outline_rounded, color: p.ready),
            for (final m in cookNow)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: SufraDishCard(match: m),
              ),
          ],
          if (nearly.isNotEmpty) ...[
            SufraSectionTitle(l.sufraNearlyTitle, icon: Icons.shopping_basket_outlined, color: p.nearly),
            for (final m in nearly)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: SufraDishCard(match: m),
              ),
          ],
          // Not a failure: the three things Madar will not guess, each with
          // what to write so it can answer next time.
          if (unsure.isNotEmpty) ...[
            SufraSectionTitle(l.sufraUnsureTitle, icon: Icons.help_outline_rounded, color: p.unsure),
            for (final m in unsure)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: SufraDishCard(match: m),
              ),
          ],
          // «بدون تكرار»: when she cooked it, when it comes back, and the
          // override right above them.
          if (held.isNotEmpty) ...[
            SufraSectionTitle(l.sufraHeldTitle, icon: Icons.history_rounded),
            // Her override, right where the dishes it holds are.
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: MadarChip(
                  key: const ValueKey('sufra.tonight.showRepeats.inline'),
                  label: l.sufraShowRepeats,
                  icon: Icons.visibility_outlined,
                  selected: extra.ignoreNoRepeat,
                  dense: true,
                  onSelected: (v) => ref.read(kitchenConstraintsProvider.notifier).showRepeats(v),
                ),
              ),
            ),
            for (final m in held)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: SufraDishCard(match: m),
              ),
          ],
          if (blocked.isNotEmpty) ...[
            SufraSectionTitle(l.sufraBlockedTitle, icon: Icons.block_rounded, color: p.out),
            for (final m in blocked)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: SufraDishCard(match: m, showChecks: false),
              ),
          ],
        ],
      ),
    );
  }
}

/// Tonight's choices: how many are eating, how long she has, and her
/// override of the no-repeat window. Not stored – it is about tonight.
///
/// Closed to one line by default: she opened «شو نطبخ اليوم» to see what
/// she can cook, not to fill in a form, and the line already says what is
/// being asked for («زي العادة · بلا حد»).
class TonightChoices extends ConsumerStatefulWidget {
  const TonightChoices({super.key, required this.extra});

  final KitchenConstraints extra;

  /// The sizes a table at home actually comes in.
  static const List<int> peopleChoices = [2, 3, 4, 5, 6, 8, 10];

  /// How long she has, in minutes.
  static const List<int> minuteChoices = [15, 30, 45, 60, 90];

  @override
  ConsumerState<TonightChoices> createState() => _TonightChoicesState();
}

class _TonightChoicesState extends ConsumerState<TonightChoices> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = SufraTexts.of(context);
    final extra = widget.extra;
    final notifier = ref.read(kitchenConstraintsProvider.notifier);
    // What is being asked for tonight, in one line.
    final summary = [
      extra.people == null ? l.sufraAnyPeople : tx.people(extra.people!),
      extra.maxMinutes == null ? l.sufraAnyTime : (tx.minutes(extra.maxMinutes!) ?? l.sufraAnyTime),
      if (extra.ignoreNoRepeat) l.sufraShowRepeats,
    ].join(l.commonFactSeparator);

    return SufraCard(
      key: const ValueKey('sufra.tonight.choices'),
      title: l.sufraTonightChoicesTitle,
      icon: Icons.tune_rounded,
      trailing: MadarButton.icon(
        key: const ValueKey('sufra.tonight.choices.toggle'),
        icon: _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
        semanticLabel: l.sufraTonightChoicesTitle,
        variant: MadarButtonVariant.ghost,
        size: MadarButtonSize.small,
        onPressed: () => setState(() => _open = !_open),
      ),
      onTap: _open ? null : () => setState(() => _open = true),
      child: AnimatedSize(
        duration: context.motion(MadarMotion.medium),
        curve: MadarMotion.decelerate,
        alignment: AlignmentDirectional.topStart,
        child: _open
            ? _choices(context, l, t, tx, extra, notifier)
            : Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  summary,
                  key: const ValueKey('sufra.tonight.choices.summary'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ),
      ),
    );
  }

  Widget _choices(
    BuildContext context,
    L10n l,
    MadarTokens t,
    SufraTexts tx,
    KitchenConstraints extra,
    KitchenConstraintsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.sufraPeopleLabel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Space.s),
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            MadarChip(
              key: const ValueKey('sufra.people.any'),
              label: l.sufraAnyPeople,
              selected: extra.people == null,
              dense: true,
              onSelected: (_) => notifier.people(null),
            ),
            for (final n in TonightChoices.peopleChoices)
              MadarChip(
                key: ValueKey('sufra.people.$n'),
                label: tx.people(n),
                selected: extra.people == n,
                dense: true,
                onSelected: (v) => notifier.people(v ? n : null),
              ),
          ],
        ),
        const SizedBox(height: Space.m),
        Text(l.sufraTimeLabel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Space.s),
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            MadarChip(
              key: const ValueKey('sufra.minutes.any'),
              label: l.sufraAnyTime,
              selected: extra.maxMinutes == null,
              dense: true,
              onSelected: (_) => notifier.minutes(null),
            ),
            for (final n in TonightChoices.minuteChoices)
              MadarChip(
                key: ValueKey('sufra.minutes.$n'),
                label: tx.minutes(n) ?? '',
                selected: extra.maxMinutes == n,
                dense: true,
                onSelected: (v) => notifier.minutes(v ? n : null),
              ),
          ],
        ),
        const SizedBox(height: Space.m),
        Row(
          children: [
            Expanded(child: Text(l.sufraShowRepeats, style: Theme.of(context).textTheme.labelLarge)),
            MadarSwitch(
              key: const ValueKey('sufra.tonight.showRepeats'),
              value: extra.ignoreNoRepeat,
              semanticLabel: l.sufraShowRepeats,
              onChanged: notifier.showRepeats,
            ),
          ],
        ),
        if (!extra.isEmpty) ...[
          const SizedBox(height: Space.s),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MadarButton(
              key: const ValueKey('sufra.tonight.clear'),
              label: l.sufraClearChoices,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              onPressed: notifier.clear,
            ),
          ),
        ],
      ],
    );
  }
}
