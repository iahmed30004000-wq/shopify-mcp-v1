import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/interaction/sheets/field_inputs.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../../data/together_providers.dart';
import '../../../domain/player_profile.dart';
import '../../../presentation/hall_of_fame_screen.dart';
import '../../../presentation/widgets/together_visuals.dart';
import '../../data/specials_providers.dart';
import '../../domain/specials_bounds.dart';
import '../specials_texts.dart';
import '../specials_visuals.dart';
import 'challenge_list_screen.dart';

/// The weekly shared challenge: this week's challenge, both players'
/// "I did it", the streak of weeks done together, the recent weeks, and
/// the way to another challenge or to the list.
class WeeklyChallengeScreen extends ConsumerStatefulWidget {
  const WeeklyChallengeScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  ConsumerState<WeeklyChallengeScreen> createState() => _WeeklyChallengeScreenState();
}

class _WeeklyChallengeScreenState extends ConsumerState<WeeklyChallengeScreen> {
  final GlobalKey _heroKey = GlobalKey();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The week keeps the challenge it is shown with, whatever happens to
    // the list later.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(specialsRepositoryProvider).ensureWeek(ref.read(togetherClockProvider)()));
    });
  }

  Future<void> _toggle(PlayerSlot slot, bool done) async {
    if (_busy) return;
    _busy = true;
    try {
      final repo = ref.read(specialsRepositoryProvider);
      final res = await repo.markChallenge(slot, done: !done, now: ref.read(togetherClockProvider)());
      if (!mounted) return;
      if (res.mark.completed) {
        final hero = _heroKey.currentContext;
        if (hero != null && hero.mounted) {
          Celebrate.burstFrom(hero, kind: CelebrationKind.lanternSparks, sfx: Sfx.levelUp);
        }
      }
      await celebrateTrophies(context, res.newTrophies);
    } finally {
      _busy = false;
    }
  }

  Future<void> _another(WeeklyView view) async {
    final next = view.log.nextAfter(view.week, view.weekStart, view.list.pool);
    if (next.isEmpty) return;
    Fx.fire(Sfx.swipe);
    await ref.read(specialsRepositoryProvider).swapChallenge(next, ref.read(togetherClockProvider)());
  }

  Future<void> _pick(WeeklyView view) async {
    final picked = await showInteractionSheet<String>(context, builder: (_) => _PickSheet(view: view));
    if (picked == null || !mounted) return;
    await ref.read(specialsRepositoryProvider).swapChallenge(picked, ref.read(togetherClockProvider)());
  }

  void _openList() {
    Fx.fire(Sfx.navigate);
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ChallengeListScreen())));
  }

  @override
  Widget build(BuildContext context) {
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final view = ref.watch(weeklyViewProvider);
    final profiles = ref.watch(togetherProfilesProvider).value;
    return MadarScaffold(
      title: l.togetherWeeklyTitle,
      backdropSeed: 8.2,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        MadarButton.icon(
          key: const ValueKey('weekly-list'),
          icon: Icons.format_list_bulleted_rounded,
          onPressed: _openList,
          semanticLabel: l.togetherWeeklyList,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.navigate,
        ),
        MadarButton.icon(
          key: const ValueKey('weekly-settings'),
          icon: Icons.tune_rounded,
          onPressed: () => unawaited(showSpecialsSettingsSheet(context)),
          semanticLabel: l.togetherSpecialsSettings,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
        ),
      ],
      body: switch ((view, profiles)) {
        (AsyncData(value: final v), final TogetherProfiles p) => _body(context, v, p),
        (AsyncError(), _) => const Center(child: AnimatedEmptyState(kind: EmptyStateKind.noData)),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }

  Widget _body(BuildContext context, WeeklyView view, TogetherProfiles profiles) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final text = Theme.of(context).textTheme;
    var i = 0;
    return EntranceChoreo(
      id: 'weekly',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        children: [
          StaggerItem(
            index: i++,
            child: WeeklyChallengeHero(
              key: _heroKey,
              view: view,
              profiles: profiles,
              onToggle: (slot, done) => unawaited(_toggle(slot, done)),
            ),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: Row(
              children: [
                Expanded(
                  child: MadarButton(
                    key: const ValueKey('weekly-another'),
                    label: l.togetherWeeklyAnother,
                    icon: Icons.shuffle_rounded,
                    variant: MadarButtonVariant.secondary,
                    size: MadarButtonSize.small,
                    expand: true,
                    sfx: Sfx.swipe,
                    onPressed: view.canSwap ? () => unawaited(_another(view)) : null,
                  ),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: MadarButton(
                    key: const ValueKey('weekly-pick'),
                    label: l.togetherWeeklyPick,
                    icon: Icons.checklist_rounded,
                    variant: MadarButtonVariant.secondary,
                    size: MadarButtonSize.small,
                    expand: true,
                    sfx: Sfx.sheetOpen,
                    onPressed: view.canSwap ? () => unawaited(_pick(view)) : null,
                  ),
                ),
              ],
            ),
          ),
          if (!view.canSwap && (view.record?.anyDone ?? false)) ...[
            const SizedBox(height: Space.xs),
            StaggerItem(
              index: i++,
              child: Text(
                l.togetherWeeklySwapLocked,
                style: text.labelSmall?.copyWith(color: t.textTertiary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: Space.l),
          StaggerItem(
            index: i++,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: StatTile(
                      key: const ValueKey('weekly-streak'),
                      label: l.togetherWeeklyStreak,
                      value: view.streak > 0 ? '×${st.n(view.streak)}' : '—',
                      icon: Icons.local_fire_department_rounded,
                      color: t.warning,
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: StatTile(
                      label: l.togetherWeeklyBest,
                      value: view.log.best > 0 ? '×${st.n(view.log.best)}' : '—',
                      icon: Icons.workspace_premium_rounded,
                      color: t.gold,
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: StatTile(
                      key: const ValueKey('weekly-total'),
                      label: l.togetherWeeklyTotal,
                      value: st.n(view.log.total),
                      icon: Icons.task_alt_rounded,
                      color: t.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
          StaggerItem(
            index: i++,
            child: SectionHeader(
              title: l.togetherWeeklyRecent,
              padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.m),
            ),
          ),
          StaggerItem(index: i++, child: _WeekStrip(view: view)),
        ],
      ),
    );
  }
}

/// This week's challenge: when it renews, the challenge itself and both
/// players' "I did it".
class WeeklyChallengeHero extends StatelessWidget {
  const WeeklyChallengeHero({super.key, required this.view, required this.profiles, required this.onToggle});

  final WeeklyView view;
  final TogetherProfiles profiles;

  /// (player, currently done).
  final void Function(PlayerSlot slot, bool done) onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final tx = st.tx;
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final c = view.challenge;
    final record = view.record;
    final one = record?.doneOne != null, two = record?.doneTwo != null;
    final both = one && two;
    final status = both
        ? l.togetherWeeklyBothDone
        : one
        ? l.togetherWeeklyWaiting(tx.name(profiles.two))
        : two
        ? l.togetherWeeklyWaiting(tx.name(profiles.one))
        : l.togetherWeeklyNotYet;
    final accent = both ? t.gold : t.accent;
    return GlassPanel(
      seed: 8,
      glowColor: both ? t.gold.withValues(alpha: 0.5) : null,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.l),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.event_repeat_rounded, size: 18, color: t.gold),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  l.togetherWeeklyThisWeek,
                  style: text.labelLarge?.copyWith(color: t.gold, fontWeight: FontWeight.w700),
                ),
              ),
              Flexible(
                child: Text(
                  tx.facts([st.daysLeft(view.daysLeft), l.togetherWeeklyRenewsOn(st.weekday(view.weekStart))]),
                  key: const ValueKey('weekly-renews'),
                  style: text.labelSmall?.copyWith(color: t.textSecondary),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SpecialsRosette(color: accent, size: 120, folds: 12),
                SpecialsBadge(
                  icon: c == null ? Icons.flag_rounded : SpecialsLook.challengeIcon(c.iconKey),
                  size: 76,
                  color: accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.m),
          Semantics(
            header: true,
            child: AnimatedSwitcher(
              duration: context.motion(MadarMotion.medium),
              child: Text(
                c == null ? '—' : st.challenge(c),
                key: ValueKey('weekly-challenge-${c?.id}-${c?.text}'),
                style: text.headlineSmall?.copyWith(color: t.textPrimary, height: 1.35),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: Space.l),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in profiles.both)
                Expanded(
                  child: DuoDoneButton(
                    key: ValueKey('weekly-done-${p.slot.name}'),
                    profile: p,
                    done: p.slot == PlayerSlot.one ? one : two,
                    onToggle: c == null ? null : () => onToggle(p.slot, p.slot == PlayerSlot.one ? one : two),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.m),
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.medium),
            child: Row(
              key: ValueKey(status),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  both ? Icons.celebration_rounded : Icons.hourglass_bottom_rounded,
                  size: 18,
                  color: both ? t.gold : t.textTertiary,
                ),
                const SizedBox(width: Space.xs),
                Flexible(
                  child: Text(
                    status,
                    style: text.titleSmall?.copyWith(color: both ? t.gold : t.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The last eight weeks: a gold star for a week done together, a half moon
/// for one of the two, an empty ring otherwise.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.view});

  final WeeklyView view;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final text = Theme.of(context).textTheme;
    final weeks = view.log.recent(view.week, view.weekStart);
    final firstStart = view.week - 7 * (weeks.length - 1);
    String dayMonth(int day) => st.tx.fmt.formatDate(SpecialWeeks.dateOf(day), style: MadarDateStyle.dayMonth);
    return GlassCard(
      key: const ValueKey('weekly-strip'),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.m, Space.s, Space.s),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < weeks.length; i++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final w = weeks[i];
                      final start = firstStart + 7 * i;
                      final current = i == weeks.length - 1;
                      final both = w?.bothDone ?? false;
                      final half = !both && (w?.anyDone ?? false);
                      final date = SpecialWeeks.dateOf(start);
                      return Semantics(
                        label: '${dayMonth(start)}: ${both ? st.l.togetherWeeklyBothDone : (half ? st.l.togetherWeeklyDone : '—')}',
                        excludeSemantics: true,
                        child: Column(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: both ? t.gold : (half ? t.gold.withValues(alpha: 0.25) : null),
                                border: Border.all(
                                  color: current ? t.accent : (both || half ? t.gold : t.glassBorder),
                                  width: current ? 2 : 1,
                                ),
                                boxShadow: both ? [BoxShadow(color: t.gold.withValues(alpha: 0.45), blurRadius: 8)] : null,
                              ),
                              child: both ? Icon(Icons.star_rounded, size: 16, color: TogetherLook.inkOn(t.gold)) : null,
                            ),
                            const SizedBox(height: Space.xs),
                            // The day the week started; the months are in
                            // the range below.
                            Text(
                              st.n(date.day),
                              style: text.labelSmall?.copyWith(
                                color: current ? t.textPrimary : t.textTertiary,
                                fontWeight: current ? FontWeight.w700 : null,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            st.l.togetherWeeklyRange(dayMonth(firstStart), dayMonth(view.week)),
            style: text.labelSmall?.copyWith(color: t.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Every challenge in rotation; tapping one gives it to this week.
class _PickSheet extends StatelessWidget {
  const _PickSheet({required this.view});

  final WeeklyView view;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final text = Theme.of(context).textTheme;
    return InteractionSheetFrame(
      title: st.l.togetherWeeklyPick,
      icon: Icons.checklist_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in view.list.pool)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
              child: GlassCard(
                key: ValueKey('weekly-pick-${c.id}'),
                onTap: () => Navigator.of(context).pop(c.id),
                borderColor: c.id == view.challenge?.id ? t.accent : null,
                padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
                child: Row(
                  children: [
                    Icon(SpecialsLook.challengeIcon(c.iconKey), size: 22, color: t.accent),
                    const SizedBox(width: Space.m),
                    Expanded(child: Text(st.challenge(c), style: text.bodyLarge?.copyWith(color: t.textPrimary))),
                    if (c.id == view.challenge?.id) Icon(Icons.check_rounded, color: t.accent),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The specials' settings: the day the weekly challenge renews.
Future<void> showSpecialsSettingsSheet(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const SpecialsSettingsSheet());

class SpecialsSettingsSheet extends ConsumerWidget {
  const SpecialsSettingsSheet({super.key});

  /// Saturday first, as the week reads in Jordan.
  static const List<int> _order = [
    DateTime.saturday,
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(specialsSettingsProvider).value;
    final repo = ref.read(specialsRepositoryProvider);
    return InteractionSheetFrame(
      title: l.togetherSpecialsSettings,
      icon: Icons.event_repeat_rounded,
      body: settings == null
          ? const Padding(padding: EdgeInsets.all(Space.xxl), child: Center(child: OrbitLoader(size: 40)))
          : FieldShell(
              label: l.togetherWeekStart,
              icon: Icons.calendar_view_week_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.togetherWeekStartHint, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                  const SizedBox(height: Space.m),
                  ChoicePills<int>.single(
                    dense: true,
                    options: [for (final d in _order) ChoiceOption(value: d, label: st.weekday(d))],
                    selected: settings.weekStart,
                    onChanged: (d) {
                      if (d != null) unawaited(repo.saveSettings(settings.copyWith(weekStart: d)));
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
