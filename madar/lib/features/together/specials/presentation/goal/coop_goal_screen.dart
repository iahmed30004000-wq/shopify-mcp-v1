import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/interaction/sheets/field_inputs.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../../data/together_providers.dart';
import '../../../presentation/hall_of_fame_screen.dart';
import '../../data/specials_providers.dart';
import '../../domain/coop_goal.dart';
import '../../domain/specials_bounds.dart';
import '../specials_texts.dart';
import '../specials_visuals.dart';

/// The cooperative goal: a big progress ring, the reward the couple wrote,
/// how the points came in (or the counter to move), and "our rewards" –
/// every goal reached so far. Reaching the target unlocks the reward with a
/// celebration.
class CoopGoalScreen extends ConsumerWidget {
  const CoopGoalScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final standing = ref.watch(goalStandingProvider);
    final board = ref.watch(goalBoardProvider).value;
    final goal = standing.value?.goal;
    return MadarScaffold(
      title: l.togetherGoalTitle,
      backdropSeed: 6.6,
      animateBackdrop: animateBackdrop,
      actions: [
        if (goal != null)
          MadarButton.icon(
            key: const ValueKey('goal-edit'),
            icon: Icons.edit_rounded,
            onPressed: () => unawaited(showGoalEditorSheet(context, goal: goal)),
            semanticLabel: l.togetherGoalEdit,
            variant: MadarButtonVariant.ghost,
            sfx: Sfx.sheetOpen,
          ),
      ],
      body: GoalUnlockWatcher(
        child: switch (standing) {
          AsyncData(:final value) => _GoalBody(standing: value, achieved: board?.achieved ?? const []),
          AsyncError() => const Center(child: AnimatedEmptyState(kind: EmptyStateKind.noData)),
          _ => const Center(child: OrbitLoader(size: 40)),
        },
      ),
    );
  }
}

class _GoalBody extends ConsumerWidget {
  const _GoalBody({required this.standing, required this.achieved});

  final GoalStanding? standing;
  final List<AchievedGoal> achieved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final s = standing;
    final repo = ref.read(specialsRepositoryProvider);
    var i = 0;
    return EntranceChoreo(
      id: 'goal',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        children: [
          if (s == null)
            StaggerItem(
              index: i++,
              child: GlassPanel(
                key: const ValueKey('goal-empty'),
                seed: 6,
                padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.xl, Space.l, Space.xl),
                child: Column(
                  children: [
                    SizedBox(
                      height: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SpecialsRosette(color: t.gold, size: 140, folds: 8),
                          SpecialsBadge(icon: Icons.redeem_rounded, size: 76, color: t.gold),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.m),
                    Text(l.togetherGoalNone, style: text.headlineSmall?.copyWith(color: t.textPrimary)),
                    const SizedBox(height: Space.xs),
                    Text(
                      l.togetherGoalNoneBody,
                      style: text.bodyMedium?.copyWith(color: t.textSecondary, height: 1.45),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Space.l),
                    MadarButton(
                      key: const ValueKey('goal-set'),
                      label: l.togetherGoalSet,
                      icon: Icons.flag_rounded,
                      size: MadarButtonSize.large,
                      expand: true,
                      sfx: Sfx.sheetOpen,
                      onPressed: () => unawaited(showGoalEditorSheet(context)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            StaggerItem(
              index: i++,
              child: _GoalHero(standing: s),
            ),
            const SizedBox(height: Space.m),
            StaggerItem(
              index: i++,
              child: _RewardCard(standing: s),
            ),
            const SizedBox(height: Space.m),
            if (s.goal.metric == GoalMetric.counter)
              StaggerItem(
                index: i++,
                child: _CounterControls(standing: s),
              )
            else
              StaggerItem(
                index: i++,
                child: _PointsBreakdown(standing: s),
              ),
            if (s.goal.isUnlocked) ...[
              const SizedBox(height: Space.l),
              StaggerItem(
                index: i++,
                child: MadarButton(
                  key: const ValueKey('goal-next'),
                  label: l.togetherGoalNext,
                  icon: Icons.flag_rounded,
                  size: MadarButtonSize.large,
                  expand: true,
                  sfx: Sfx.sheetOpen,
                  onPressed: () => unawaited(showGoalEditorSheet(context)),
                ),
              ),
            ],
            // An unlocked goal is filed under "our rewards" by the next one.
            if (!s.goal.isUnlocked) ...[
              const SizedBox(height: Space.m),
              StaggerItem(
                index: i++,
                child: Center(
                  child: MadarButton(
                    key: const ValueKey('goal-drop'),
                    label: l.togetherGoalDelete,
                    icon: Icons.delete_outline_rounded,
                    variant: MadarButtonVariant.ghost,
                    size: MadarButtonSize.small,
                    sfx: Sfx.delete,
                    onPressed: () async {
                      final undo = await repo.deleteGoal();
                      if (!context.mounted) return;
                      unawaited(showUndoToast(context, UndoableAction(label: l.togetherGoalDeleted, undo: undo)));
                    },
                  ),
                ),
              ),
            ],
          ],
          if (achieved.isNotEmpty) ...[
            StaggerItem(
              index: i++,
              child: SectionHeader(
                title: l.togetherGoalAchieved,
                padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.m),
              ),
            ),
            for (final a in achieved.reversed)
              StaggerItem(
                index: i++,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                  child: _AchievedTile(goal: a),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The ring: progress of the target, the goal's name and what is left.
class _GoalHero extends StatelessWidget {
  const _GoalHero({required this.standing});

  final GoalStanding standing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final g = standing.goal;
    final unit = g.metric == GoalMetric.points ? null : st.unit(g.unit);
    final unlocked = g.isUnlocked;
    return GlassPanel(
      key: const ValueKey('goal-hero'),
      seed: 6,
      glowColor: unlocked ? t.gold.withValues(alpha: 0.5) : null,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.xl, Space.l, Space.l),
      child: Column(
        children: [
          Semantics(
            header: true,
            child: Text(
              st.goalTitle(g),
              style: text.titleLarge?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Space.l),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SpecialsRosette(color: unlocked ? t.gold : t.accent, size: 220, folds: 12),
                ProgressRing(
                  value: standing.fraction,
                  size: 188,
                  strokeWidth: 14,
                  color: unlocked ? t.gold : t.accent,
                  gradientEnd: t.gold,
                  semanticLabel: st.goalTitle(g),
                  semanticValue: st.progress(standing.progress, standing.target),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RollingNumber(
                        value: standing.progress,
                        formatter: (v) => st.n(v.round()),
                        style: SpecialsLook.numerals(text.displaySmall)?.copyWith(color: t.textPrimary),
                      ),
                      Text(
                        '/ ${st.n(standing.target)}${unit == null ? '' : ' $unit'}',
                        style: text.titleSmall?.copyWith(color: t.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (g.metric == GoalMetric.points)
                        Text(l.togetherGoalMetricPoints, style: text.labelSmall?.copyWith(color: t.gold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.m),
          Text(
            unlocked
                ? l.togetherGoalUnlocked
                : st.tx.facts([
                    l.togetherGoalRemaining(st.n(standing.remaining)),
                    l.togetherGoalSince(st.tx.fmt.formatDate(g.startedAt, style: MadarDateStyle.dayMonth)),
                  ]),
            key: const ValueKey('goal-status'),
            style: text.titleSmall?.copyWith(color: unlocked ? t.gold : t.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The reward the couple wrote: waiting behind a lock, then glowing.
class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.standing});

  final GoalStanding standing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final text = Theme.of(context).textTheme;
    final unlocked = standing.goal.isUnlocked;
    return GlassCard(
      key: const ValueKey('goal-reward'),
      borderColor: unlocked ? t.gold : null,
      glowColor: unlocked ? t.gold.withValues(alpha: 0.45) : null,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Row(
        children: [
          SpecialsBadge(icon: unlocked ? Icons.redeem_rounded : Icons.lock_rounded, color: t.gold, size: 48),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unlocked ? st.l.togetherGoalUnlocked : st.l.togetherGoalRewardLocked,
                  style: text.labelLarge?.copyWith(color: t.gold, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(standing.goal.reward, style: text.titleMedium?.copyWith(color: t.textPrimary, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A counter goal: minus / plus around the count.
class _CounterControls extends ConsumerWidget {
  const _CounterControls({required this.standing});

  final GoalStanding standing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final repo = ref.read(specialsRepositoryProvider);
    final g = standing.goal;
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Row(
        children: [
          MadarButton.icon(
            key: const ValueKey('goal-minus'),
            icon: Icons.remove_rounded,
            semanticLabel: l.togetherGoalTakeOne,
            onPressed: g.counter <= 0 ? null : () => unawaited(repo.bumpCounter(-1)),
            sfx: Sfx.toggleOff,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  st.n(g.counter),
                  style: SpecialsLook.numerals(text.headlineMedium)?.copyWith(color: t.textPrimary),
                ),
                Text(st.unit(g.unit), style: text.labelMedium?.copyWith(color: t.textSecondary)),
              ],
            ),
          ),
          MadarButton.icon(
            key: const ValueKey('goal-plus'),
            icon: Icons.add_rounded,
            semanticLabel: l.togetherGoalAddOne,
            variant: MadarButtonVariant.primary,
            onPressed: g.counter >= SpecialsBounds.maxCounter ? null : () => unawaited(repo.bumpCounter(1)),
            sfx: Sfx.countTick,
          ),
        ],
      ),
    );
  }
}

/// Where a points goal's points came from.
class _PointsBreakdown extends ConsumerWidget {
  const _PointsBreakdown({required this.standing});

  final GoalStanding standing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final g = standing.goal;
    final ledger = ref.watch(togetherLedgerProvider).value;
    final log = ref.watch(challengeLogProvider).value;
    final fromMatches = ledger == null || !g.countGames ? 0 : g.matchesSince(ledger) * SpecialsBounds.matchPoints;
    final fromChallenges = log == null || !g.countChallenges
        ? 0
        : (log.total - g.baseChallenges).clamp(0, 1 << 30) * SpecialsBounds.challengePoints;
    Widget row(IconData icon, String label, bool on) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xxs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: on ? t.accent : t.textTertiary),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(label, style: text.bodyMedium?.copyWith(color: on ? t.textPrimary : t.textTertiary)),
          ),
        ],
      ),
    );
    return GlassCard(
      key: const ValueKey('goal-breakdown'),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (g.countGames) row(Icons.sports_esports_rounded, l.togetherGoalFromMatches(st.points(fromMatches)), true),
          if (g.countChallenges)
            row(Icons.event_available_rounded, l.togetherGoalFromChallenges(st.points(fromChallenges)), true),
          const SizedBox(height: Space.xs),
          Text(
            st.tx.digits(
              l.togetherGoalMetricPointsBody(
                st.points(SpecialsBounds.matchPoints),
                st.points(SpecialsBounds.challengePoints),
              ),
            ),
            style: text.labelSmall?.copyWith(color: t.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _AchievedTile extends StatelessWidget {
  const _AchievedTile({required this.goal});

  final AchievedGoal goal;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.m, Space.s + 2),
      child: Row(
        children: [
          SpecialsBadge(icon: Icons.redeem_rounded, size: 36, color: t.gold),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.reward, style: text.titleSmall?.copyWith(color: t.textPrimary)),
                Text(
                  st.tx.facts([
                    st.achievedTitle(goal),
                    st.tx.fmt.formatDate(goal.unlockedAt, style: MadarDateStyle.medium),
                  ]),
                  style: text.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ unlocking

/// Unlocks the active goal as soon as it is reached – when shown, and
/// whenever the progress changes while shown – and celebrates: a burst, the
/// reward revealed in gold, and "Dream came true" the first time. Wrap
/// every place that shows the goal (the Together home section does).
class GoalUnlockWatcher extends ConsumerStatefulWidget {
  const GoalUnlockWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GoalUnlockWatcher> createState() => _GoalUnlockWatcherState();
}

class _GoalUnlockWatcherState extends ConsumerState<GoalUnlockWatcher> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(ref.read(goalStandingProvider).value));
  }

  Future<void> _check(GoalStanding? s) async {
    if (!mounted || _checking || s == null || !s.reached || s.goal.isUnlocked) return;
    _checking = true;
    try {
      final trophies = await ref.read(specialsRepositoryProvider).unlockIfReached(ref.read(togetherClockProvider)());
      if (trophies == null || !mounted) return;
      Celebrate.burstFrom(context, kind: CelebrationKind.lanternSparks, sfx: Sfx.levelUp);
      await showInteractionSheet<void>(context, builder: (_) => _RewardUnlockedSheet(goal: s.goal));
      if (mounted) await celebrateTrophies(context, trophies);
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(goalStandingProvider, (_, next) => unawaited(_check(next.value)));
    return widget.child;
  }
}

class _RewardUnlockedSheet extends StatelessWidget {
  const _RewardUnlockedSheet({required this.goal});

  final CoopGoal goal;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final text = Theme.of(context).textTheme;
    return InteractionSheetFrame(
      title: l.togetherGoalUnlocked,
      subtitle: st.goalTitle(goal),
      icon: Icons.redeem_rounded,
      body: Column(
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SpecialsRosette(color: t.gold, size: 150, folds: 12),
                SpecialsBadge(icon: Icons.redeem_rounded, size: 84, color: t.gold),
              ],
            ),
          ),
          const SizedBox(height: Space.m),
          Text(
            l.togetherGoalUnlockedBody,
            style: text.bodyMedium?.copyWith(color: t.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.s),
          Text(
            goal.reward,
            key: const ValueKey('goal-unlocked-reward'),
            style: text.headlineSmall?.copyWith(color: t.gold, height: 1.35),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      footer: SheetButton(
        label: st.tx.l.actionDone,
        primary: true,
        sfx: Sfx.complete,
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}

// --------------------------------------------------------------- editor

/// Sets a new goal (none given) or edits [goal].
Future<void> showGoalEditorSheet(BuildContext context, {CoopGoal? goal}) =>
    showInteractionSheet<void>(context, builder: (_) => GoalEditorSheet(goal: goal));

class GoalEditorSheet extends ConsumerStatefulWidget {
  const GoalEditorSheet({super.key, this.goal});

  /// The goal to edit; null starts a new one.
  final CoopGoal? goal;

  @override
  ConsumerState<GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends ConsumerState<GoalEditorSheet> {
  late final TextEditingController _title = TextEditingController(text: widget.goal?.title ?? '');
  late final TextEditingController _reward = TextEditingController(text: widget.goal?.reward ?? '');
  late final TextEditingController _target = TextEditingController(
    text: widget.goal == null ? '' : '${widget.goal!.target}',
  );
  late final TextEditingController _unit = TextEditingController(text: widget.goal?.unit ?? '');
  late GoalMetric _metric = widget.goal?.metric ?? GoalMetric.points;
  late bool _games = widget.goal?.countGames ?? true;
  late bool _challenges = widget.goal?.countChallenges ?? true;
  bool _tried = false;
  bool _saving = false;

  static const List<int> _suggested = [10, 25, 50, 100];

  @override
  void dispose() {
    _title.dispose();
    _reward.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  int? get _targetValue {
    final v = LocalizedNumbers.parse(_target.text);
    if (v == null || v != v.roundToDouble()) return null;
    final i = v.toInt();
    return i >= 1 && i <= SpecialsBounds.maxGoalTarget ? i : null;
  }

  bool get _rewardOk => SpecialsBounds.clean(_reward.text, SpecialsBounds.maxRewardLength).isNotEmpty;

  bool get _valid => _rewardOk && _targetValue != null && (_metric == GoalMetric.counter || _games || _challenges);

  Future<void> _save() async {
    if (!_valid) {
      setState(() => _tried = true);
      Fx.fire(Sfx.error);
      return;
    }
    if (_saving) return;
    _saving = true;
    final repo = ref.read(specialsRepositoryProvider);
    final g = widget.goal;
    try {
      if (g == null || g.isUnlocked) {
        await repo.startGoal(
          title: _title.text,
          reward: _reward.text,
          metric: _metric,
          target: _targetValue!,
          countGames: _games,
          countChallenges: _challenges,
          unit: _unit.text,
          now: ref.read(togetherClockProvider)(),
        );
      } else {
        await repo.editGoal(
          (x) => x.copyWith(
            title: _title.text,
            reward: _reward.text,
            metric: _metric,
            target: _targetValue,
            countGames: _games,
            countChallenges: _challenges,
            unit: _unit.text,
          ),
        );
      }
      Fx.fire(Sfx.complete);
      if (mounted) Navigator.of(context).pop();
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final editing = widget.goal != null && !widget.goal!.isUnlocked;

    Widget switchRow(String title, bool value, ValueChanged<bool> onChanged, Key key) => Row(
      children: [
        Expanded(
          child: Text(title, style: text.bodyLarge?.copyWith(color: t.textPrimary)),
        ),
        MadarSwitch(key: key, value: value, onChanged: onChanged, semanticLabel: title),
      ],
    );

    return InteractionSheetFrame(
      title: editing ? l.togetherGoalEdit : l.togetherGoalNew,
      icon: Icons.flag_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldShell(
            label: l.togetherGoalNameField,
            icon: Icons.title_rounded,
            optional: true,
            child: TextField(
              key: const ValueKey('goal-title-field'),
              controller: _title,
              inputFormatters: [LengthLimitingTextInputFormatter(SpecialsBounds.maxGoalTitleLength)],
              decoration: kitInputDecoration(context, hint: l.togetherGoalTitle),
            ),
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.togetherGoalRewardField,
            icon: Icons.redeem_rounded,
            error: _tried && !_rewardOk ? l.togetherGoalRewardRequired : null,
            child: TextField(
              key: const ValueKey('goal-reward-field'),
              controller: _reward,
              minLines: 1,
              maxLines: 3,
              inputFormatters: [LengthLimitingTextInputFormatter(SpecialsBounds.maxRewardLength)],
              decoration: kitInputDecoration(context, hint: l.togetherGoalRewardHint, error: _tried && !_rewardOk),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.togetherGoalMetricField,
            icon: Icons.route_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChoicePills<GoalMetric>.single(
                  dense: true,
                  options: [
                    ChoiceOption(
                      value: GoalMetric.points,
                      label: l.togetherGoalMetricPoints,
                      icon: Icons.stars_rounded,
                    ),
                    ChoiceOption(
                      value: GoalMetric.counter,
                      label: l.togetherGoalMetricCounter,
                      icon: Icons.exposure_plus_1_rounded,
                    ),
                  ],
                  selected: _metric,
                  onChanged: (m) {
                    if (m != null) setState(() => _metric = m);
                  },
                ),
                const SizedBox(height: Space.s),
                Text(
                  _metric == GoalMetric.points
                      ? st.tx.digits(
                          l.togetherGoalMetricPointsBody(
                            st.points(SpecialsBounds.matchPoints),
                            st.points(SpecialsBounds.challengePoints),
                          ),
                        )
                      : l.togetherGoalMetricCounterBody,
                  style: text.bodySmall?.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: Space.s),
                if (_metric == GoalMetric.points) ...[
                  switchRow(
                    l.togetherGoalCountGames,
                    _games,
                    (v) => setState(() => _games = v),
                    const ValueKey('goal-games'),
                  ),
                  switchRow(
                    l.togetherGoalCountChallenges,
                    _challenges,
                    (v) => setState(() => _challenges = v),
                    const ValueKey('goal-challenges'),
                  ),
                ] else
                  TextField(
                    key: const ValueKey('goal-unit-field'),
                    controller: _unit,
                    inputFormatters: [LengthLimitingTextInputFormatter(SpecialsBounds.maxUnitLength)],
                    decoration: kitInputDecoration(context, hint: l.togetherGoalUnitHint),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.togetherGoalTargetField,
            icon: Icons.flag_circle_rounded,
            error: _tried && _targetValue == null ? l.fieldInvalidNumber : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('goal-target-field'),
                  controller: _target,
                  keyboardType: TextInputType.number,
                  inputFormatters: [kitNumberFormatter, LengthLimitingTextInputFormatter(5)],
                  decoration: kitInputDecoration(
                    context,
                    hint: st.n(50),
                    error: _tried && _targetValue == null,
                    suffix: _metric == GoalMetric.points ? l.togetherGoalMetricPoints : st.unit(_unit.text),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Space.s),
                Wrap(
                  spacing: Space.s,
                  children: [
                    for (final n in _suggested)
                      MadarChip(
                        label: st.n(n),
                        dense: true,
                        selected: _targetValue == n,
                        onSelected: (_) => setState(() => _target.text = '$n'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(
              label: l.togetherCancel,
              sfx: Sfx.sheetClose,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: SheetButton(
              key: const ValueKey('goal-save'),
              label: l.togetherSave,
              primary: true,
              enabled: _valid,
              onDisabledTap: () {
                setState(() => _tried = true);
                Fx.fire(Sfx.error);
              },
              sfx: null,
              onPressed: () => unawaited(_save()),
            ),
          ),
        ],
      ),
    );
  }
}
