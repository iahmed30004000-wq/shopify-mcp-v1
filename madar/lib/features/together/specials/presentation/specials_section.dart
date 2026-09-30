import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/together_providers.dart';
import '../../domain/player_profile.dart';
import '../../presentation/widgets/together_visuals.dart';
import '../data/specials_providers.dart';
import 'goal/coop_goal_screen.dart';
import 'know_me/know_me_screen.dart';
import 'specials_texts.dart';
import 'specials_visuals.dart';
import 'weekly/weekly_challenge_screen.dart';

/// "Just the two of us" (لنا نحن الاثنين) on the Together home: "How well do
/// you know me?", this week's challenge (both players' marks and the
/// streak) and the cooperative goal (its ring and reward). Each row opens
/// its screen – by default with `Navigator.push`; pass the callbacks to use
/// the app's router instead.
class TogetherSpecialsSection extends ConsumerStatefulWidget {
  const TogetherSpecialsSection({super.key, this.onOpenKnowMe, this.onOpenWeekly, this.onOpenGoal});

  final VoidCallback? onOpenKnowMe;
  final VoidCallback? onOpenWeekly;
  final VoidCallback? onOpenGoal;

  @override
  ConsumerState<TogetherSpecialsSection> createState() => _TogetherSpecialsSectionState();
}

class _TogetherSpecialsSectionState extends ConsumerState<TogetherSpecialsSection> {
  @override
  void initState() {
    super.initState();
    // Pins this week's challenge the first time it is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(specialsRepositoryProvider).ensureWeek(ref.read(togetherClockProvider)()));
    });
  }

  void _open(VoidCallback? custom, WidgetBuilder page) {
    if (custom != null) {
      custom();
      return;
    }
    Fx.fire(Sfx.navigate);
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: page)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final tx = st.tx;
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final bank = ref.watch(knowMeBankProvider).value;
    final ledger = ref.watch(togetherLedgerProvider).value;
    final weekly = ref.watch(weeklyViewProvider).value;
    final goal = ref.watch(goalStandingProvider);
    final profiles = ref.watch(togetherProfilesProvider).value ?? TogetherProfiles.defaults();

    // How well do you know me?
    final tally = ledger?.tallyOf('knowMe');
    final leader = tally?.leader;
    final knowMeFacts = [
      if (tally == null || tally.matches == 0) ...[
        if (bank != null) st.questions(bank.questions.length),
        st.rounds(0),
      ] else ...[
        st.rounds(tally.matches),
        if (leader == null)
          l.togetherAllSquare
        else
          l.togetherLeads(tx.name(profiles.of(leader)), tx.n((tally.winsOne - tally.winsTwo).abs())),
      ],
    ];

    // This week's challenge.
    final record = weekly?.record;
    final challenge = weekly?.challenge;
    Widget mark(PlayerSlot s) {
      final done = record?.doneBy(s) != null;
      final color = TogetherLook.colorOf(profiles.of(s));
      return Container(
        width: 18,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color : null,
          border: Border.all(color: color, width: 1.6),
        ),
        child: done ? Icon(Icons.check_rounded, size: 12, color: TogetherLook.inkOn(color)) : null,
      );
    }

    final streak = weekly?.streak ?? 0;
    final weeklyTrailing = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [mark(PlayerSlot.one), mark(PlayerSlot.two)]),
        if (streak > 0) ...[
          const SizedBox(height: Space.xxs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department_rounded, size: 14, color: t.warning),
              Text('×${st.n(streak)}', style: text.labelSmall?.copyWith(color: t.warning, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ],
    );

    // Our goal.
    final s = goal.value;
    final goalTrailing = s == null
        ? Icon(Icons.add_circle_outline_rounded, color: t.gold)
        : ProgressRing(
            value: s.fraction,
            size: 46,
            strokeWidth: 5,
            color: s.goal.isUnlocked ? t.gold : t.accent,
            gradientEnd: t.gold,
            child: Text(
              st.percent(s.fraction),
              style: text.labelSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
              textScaler: TextScaler.noScaling,
            ),
          );

    return GoalUnlockWatcher(
      child: Column(
        key: const ValueKey('together-specials'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SpecialsTile(
            key: const ValueKey('specials-knowme'),
            icon: Icons.favorite_rounded,
            color: TogetherLook.colorOf(profiles.two),
            title: l.togetherGameKnowMe,
            subtitle: knowMeFacts.isEmpty ? l.togetherKnowMeStart : tx.facts(knowMeFacts),
            trailing: Icon(Icons.play_circle_fill_rounded, color: t.accent, size: 30),
            onTap: () => _open(widget.onOpenKnowMe, (_) => const KnowMeScreen()),
          ),
          const SizedBox(height: Space.s),
          SpecialsTile(
            key: const ValueKey('specials-weekly'),
            icon: challenge == null ? Icons.event_repeat_rounded : SpecialsLook.challengeIcon(challenge.iconKey),
            color: t.warning,
            title: l.togetherWeeklyTitle,
            subtitle: challenge == null ? '…' : st.challenge(challenge),
            trailing: weeklyTrailing,
            onTap: () => _open(widget.onOpenWeekly, (_) => const WeeklyChallengeScreen()),
          ),
          const SizedBox(height: Space.s),
          SpecialsTile(
            key: const ValueKey('specials-goal'),
            icon: Icons.redeem_rounded,
            color: t.gold,
            title: s == null ? l.togetherGoalTitle : st.goalTitle(s.goal),
            subtitle: s == null
                ? l.togetherSpecialsGoalEmpty
                : s.goal.isUnlocked
                ? tx.facts([l.togetherGoalUnlocked, s.goal.reward])
                : tx.facts([st.progress(s.progress, s.target), s.goal.reward]),
            trailing: goalTrailing,
            onTap: () => _open(widget.onOpenGoal, (_) => const CoopGoalScreen()),
          ),
        ],
      ),
    );
  }
}
