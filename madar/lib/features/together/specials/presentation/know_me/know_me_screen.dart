import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/interaction/sheets/field_inputs.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../../data/together_providers.dart';
import '../../../domain/head_to_head.dart';
import '../../../domain/player_profile.dart';
import '../../../presentation/widgets/together_visuals.dart';
import '../../data/specials_providers.dart';
import '../../domain/know_me_bank.dart';
import '../../domain/know_me_round.dart';
import '../../domain/specials_bounds.dart';
import '../specials_texts.dart';
import '../specials_visuals.dart';
import 'know_me_round_screen.dart';
import 'question_bank_screen.dart';

/// "How well do you know me?" (قديش بتعرفني؟): the round set-up – how many
/// questions, which categories, who answers first – the couple's record
/// and the way to the question bank.
class KnowMeScreen extends ConsumerStatefulWidget {
  const KnowMeScreen({super.key, this.animateBackdrop = true, this.random});

  final bool animateBackdrop;

  /// Question draw and "random" first player (tests pass a seeded one).
  final math.Random? random;

  @override
  ConsumerState<KnowMeScreen> createState() => _KnowMeScreenState();
}

class _KnowMeScreenState extends ConsumerState<KnowMeScreen> {
  /// Who answers first (null: a draw).
  PlayerSlot? _first;
  late final math.Random _random = widget.random ?? math.Random();

  void _openBank() {
    Fx.fire(Sfx.navigate);
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const QuestionBankScreen())));
  }

  void _start(KnowMeBank bank, KnowMePrefs prefs) {
    final st = SpecialsTexts.of(context);
    final first = _first ?? (_random.nextBool() ? PlayerSlot.one : PlayerSlot.two);
    final round = KnowMeRound.draw(
      bank: bank,
      prefs: prefs,
      languageCode: st.lang,
      first: first,
      now: ref.read(togetherClockProvider)(),
      random: _random,
    );
    Fx.fire(Sfx.navigate);
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => KnowMeRoundScreen(round: round, random: _random),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final bank = ref.watch(knowMeBankProvider);
    final prefs = ref.watch(knowMePrefsProvider);
    final profiles = ref.watch(togetherProfilesProvider);
    final ledger = ref.watch(togetherLedgerProvider);
    final ready = bank.hasValue && prefs.hasValue && profiles.hasValue && ledger.hasValue;
    return MadarScaffold(
      title: l.togetherGameKnowMe,
      backdropSeed: 2.7,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        MadarButton.icon(
          key: const ValueKey('knowme-edit-questions'),
          icon: Icons.edit_note_rounded,
          onPressed: _openBank,
          semanticLabel: l.togetherKnowMeEditQuestions,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.navigate,
        ),
      ],
      body: !ready
          ? const Center(child: OrbitLoader(size: 40))
          : _body(context, bank.requireValue, prefs.requireValue, profiles.requireValue, ledger.requireValue.tallyOf('knowMe')),
    );
  }

  Widget _body(BuildContext context, KnowMeBank bank, KnowMePrefs prefs, TogetherProfiles profiles, GameTally tally) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final tx = st.tx;
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final repo = ref.read(specialsRepositoryProvider);
    final available = bank.questionsInAny(prefs.categories).length;
    final validCats = {
      for (final id in prefs.categories)
        if (bank.category(id) != null) id,
    };
    var i = 0;
    return EntranceChoreo(
      id: 'knowme-setup',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        children: [
          StaggerItem(index: i++, child: _Hero(profiles: profiles, tally: tally)),
          const SizedBox(height: Space.xl),
          StaggerItem(
            index: i++,
            child: FieldShell(
              label: l.togetherKnowMeQuestionsPerRound,
              icon: Icons.format_list_numbered_rounded,
              child: ChoicePills<int>.single(
                dense: true,
                options: [
                  for (final n in SpecialsBounds.roundSizes) ChoiceOption(value: n, label: tx.n(n)),
                ],
                selected: SpecialsBounds.roundSizes.contains(prefs.roundSize) ? prefs.roundSize : null,
                onChanged: (n) {
                  if (n != null) unawaited(repo.updatePrefs((p) => p.copyWith(roundSize: n)));
                },
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
          StaggerItem(
            index: i++,
            child: FieldShell(
              label: l.togetherKnowMeCategories,
              icon: Icons.category_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: Space.s,
                    children: [
                      MadarChip(
                        key: const ValueKey('knowme-cat-all'),
                        label: l.togetherKnowMeAllCategories,
                        selected: validCats.isEmpty,
                        dense: true,
                        showCheck: true,
                        onSelected: (_) => unawaited(repo.updatePrefs((p) => p.copyWith(categories: {}))),
                      ),
                      for (final c in bank.categories)
                        MadarChip(
                          key: ValueKey('knowme-cat-${c.id}'),
                          label: st.category(c),
                          icon: SpecialsLook.categoryIcon(c.iconKey),
                          selected: validCats.contains(c.id),
                          dense: true,
                          onSelected: (on) {
                            final next = {...validCats};
                            if (on) {
                              next.add(c.id);
                            } else {
                              next.remove(c.id);
                            }
                            // Every category picked is the same as "all".
                            final all = next.length == bank.categories.length;
                            unawaited(repo.updatePrefs((p) => p.copyWith(categories: all ? {} : next)));
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.s),
                  Text(
                    available == 0 ? l.togetherKnowMeNoQuestions : st.questions(available),
                    style: text.bodySmall?.copyWith(color: available == 0 ? t.warning : t.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
          StaggerItem(
            index: i++,
            child: FieldShell(
              label: l.togetherWhoStarts,
              icon: Icons.swap_horiz_rounded,
              child: ChoicePills<PlayerSlot?>.single(
                dense: true,
                options: [
                  for (final p in profiles.both)
                    ChoiceOption(value: p.slot, label: tx.rawName(p), color: TogetherLook.colorOf(p)),
                  ChoiceOption(value: null, label: l.togetherRandomStart, icon: Icons.casino_rounded),
                ],
                selected: _first,
                onChanged: (s) => setState(() => _first = s),
              ),
            ),
          ),
          const SizedBox(height: Space.xxl),
          StaggerItem(
            index: i++,
            child: MadarButton(
              key: const ValueKey('knowme-start'),
              label: l.togetherKnowMeStart,
              icon: Icons.favorite_rounded,
              size: MadarButtonSize.large,
              expand: true,
              onPressed: available == 0 ? null : () => _start(bank, prefs),
            ),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: Center(
              child: MadarButton(
                label: tx.facts([l.togetherKnowMeEditQuestions, st.questions(bank.questions.length)]),
                icon: Icons.edit_note_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.navigate,
                onPressed: _openBank,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Both players around a heart, the invitation and who knows whom best.
class _Hero extends StatelessWidget {
  const _Hero({required this.profiles, required this.tally});

  final TogetherProfiles profiles;
  final GameTally tally;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final tx = st.tx;
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final leader = tally.leader;

    Widget player(TogetherProfile p) => Expanded(
      child: Column(
        children: [
          TogetherAvatarView(profile: p, displayName: tx.rawName(p), size: 64, glow: leader == p.slot),
          const SizedBox(height: Space.xs),
          Text(
            tx.rawName(p),
            style: text.titleSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (tally.matches > 0)
            Text(
              tx.n(tally.winsOf(p.slot)),
              style: SpecialsLook.numerals(text.headlineSmall)?.copyWith(color: TogetherLook.colorOf(p)),
            ),
        ],
      ),
    );

    return GlassPanel(
      key: const ValueKey('knowme-hero'),
      seed: 2,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.l, Space.m, Space.l),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              player(profiles.one),
              Padding(
                padding: const EdgeInsets.only(top: Space.m),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SpecialsRosette(
                      color: Color.lerp(TogetherLook.colorOf(profiles.one), TogetherLook.colorOf(profiles.two), 0.5)!,
                      size: 72,
                      folds: 8,
                    ),
                    Icon(
                      Icons.favorite_rounded,
                      size: 34,
                      color: t.gold,
                      shadows: [Shadow(color: t.gold.withValues(alpha: 0.6), blurRadius: 14)],
                    ),
                  ],
                ),
              ),
              player(profiles.two),
            ],
          ),
          const SizedBox(height: Space.m),
          Text(
            tally.matches == 0 ? l.togetherKnowMeIntro : l.togetherKnowMeWhoKnowsBest,
            style: (tally.matches == 0 ? text.bodyMedium : text.titleSmall)?.copyWith(
              color: tally.matches == 0 ? t.textSecondary : t.textPrimary,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (tally.matches > 0) ...[
            const SizedBox(height: Space.xxs),
            Text(
              tally.draws > 0 ? tx.facts([st.rounds(tally.matches), tx.draws(tally.draws)]) : st.rounds(tally.matches),
              style: text.bodySmall?.copyWith(color: t.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.s),
            Text(
              l.togetherKnowMeIntro,
              style: text.bodySmall?.copyWith(color: t.textTertiary, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
