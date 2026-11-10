import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../data/family_providers.dart';
import '../domain/family_models.dart';
import '../domain/rhythm.dart';
import '../family_texts.dart';
import 'family_actions.dart';
import 'family_navigation.dart';
import 'widgets/family_widgets.dart';
import 'widgets/person_tile.dart';

/// Family & friends: everyone you want to stay close to, most urgent first
/// (overdue, due today, this week, in touch, no rhythm) – or in your own
/// drag-and-drop order – with a one-tap "contacted" on every row, the
/// reach-out reminder settings and adding people.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key, this.onOpenPerson, this.animateBackdrop = true});

  /// Opens a person's page; default: [FamilyNavigation.openPerson].
  final FamilyOpenPerson? onOpenPerson;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = FamilyTexts.of(context);
    final l = tx.l;
    final overview = ref.watch(familyOverviewProvider);
    final settings = ref.watch(familySettingsProvider).value ?? const FamilySettings();
    return MadarScaffold(
      title: l.familyTitle,
      backdropSeed: 2.2,
      animateBackdrop:
          animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      actions: [
        MadarButton.icon(
          icon: Icons.notifications_active_outlined,
          onPressed: () => FamilyActions.openSettings(context, ref),
          semanticLabel: l.familyRemindersTitle,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
        ),
        MadarButton.icon(
          icon: Icons.person_add_alt_1_rounded,
          onPressed: () => FamilyActions.addPerson(context, ref),
          semanticLabel: l.familyAddPerson,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
        ),
      ],
      body: switch (overview) {
        AsyncData(value: final o) when o.isEmpty => Center(
          child: SingleChildScrollView(
            child: AnimatedEmptyState(
              kind: EmptyStateKind.emptyList,
              title: l.familyEmptyTitle,
              body: l.familyEmptyBody,
              actionLabel: l.familyAddPerson,
              actionIcon: Icons.person_add_alt_1_rounded,
              onAction: () => FamilyActions.addPerson(context, ref),
            ),
          ),
        ),
        AsyncData(value: final o) =>
          settings.sortMode == FamilySortMode.manual
              ? _ManualList(overview: o, settings: settings, onOpenPerson: onOpenPerson)
              : _UrgencyList(overview: o, settings: settings, onOpenPerson: onOpenPerson),
        AsyncError() => const Center(child: AnimatedEmptyState(kind: EmptyStateKind.noData)),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }
}

const _listPadding = EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl + Space.xl);

class _UrgencyList extends ConsumerWidget {
  const _UrgencyList({required this.overview, required this.settings, this.onOpenPerson});

  final FamilyOverview overview;
  final FamilySettings settings;
  final FamilyOpenPerson? onOpenPerson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = FamilyTexts.of(context);
    final groups = overview.groups;
    var i = 0;
    return EntranceChoreo(
      id: 'family',
      child: ListView(
        padding: _listPadding,
        children: [
          StaggerItem(
            index: i++,
            child: FamilyHero(overview: overview),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: _SortPills(settings: settings),
          ),
          for (final MapEntry(key: group, value: people) in groups.entries) ...[
            StaggerItem(
              index: i++,
              child: FamilySectionTitle(
                title: tx.group(group),
                count: tx.count(people.length),
                color: switch (group) {
                  FamilyGroup.overdue => t.danger,
                  FamilyGroup.dueToday => t.warning,
                  FamilyGroup.thisWeek => t.gold,
                  FamilyGroup.inTouch => t.success,
                  FamilyGroup.noRhythm => t.textTertiary,
                },
              ),
            ),
            for (final p in people)
              StaggerItem(
                index: i++,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                  child: PersonTile(key: ValueKey(p.id), person: p, onOpenPerson: onOpenPerson),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ManualList extends ConsumerWidget {
  const _ManualList({required this.overview, required this.settings, this.onOpenPerson});

  final FamilyOverview overview;
  final FamilySettings settings;
  final FamilyOpenPerson? onOpenPerson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return ReorderableGlassList<PersonView>(
      items: overview.people,
      itemKey: (p) => p.id,
      padding: _listPadding,
      itemBorderRadius: BorderRadius.circular(t.radiusL),
      header: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FamilyHero(overview: overview),
            const SizedBox(height: Space.m),
            _SortPills(settings: settings),
          ],
        ),
      ),
      onReorder: (order) => unawaited(FamilyActions.reorder(ref, [for (final p in order) p.id])),
      itemBuilder: (context, p, index, handle) => PersonTile(person: p, dragHandle: handle, onOpenPerson: onOpenPerson),
    );
  }
}

class _SortPills extends ConsumerWidget {
  const _SortPills({required this.settings});

  final FamilySettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = FamilyTexts.of(context).l;
    return Semantics(
      label: l.familySortLabel,
      container: true,
      child: ChoicePills<FamilySortMode>.single(
        dense: true,
        options: [
          ChoiceOption(value: FamilySortMode.urgency, label: l.familySortUrgency, icon: Icons.bolt_rounded),
          ChoiceOption(value: FamilySortMode.manual, label: l.familySortManual, icon: Icons.drag_indicator_rounded),
        ],
        selected: settings.sortMode,
        onChanged: (m) {
          if (m != null) unawaited(FamilyActions.setSortMode(ref, settings, m));
        },
      ),
    );
  }
}

/// The summary at the top of the Family screen: how many are in touch (a
/// ring), who is waiting, and the next birthday.
class FamilyHero extends StatelessWidget {
  const FamilyHero({super.key, required this.overview});

  final FamilyOverview overview;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = FamilyTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final due = overview.due.length;
    final share = overview.inTouchShare;
    final withRhythm = overview.withRhythm;
    final allGood = withRhythm > 0 && due == 0;
    final ringColor = share == null
        ? t.textTertiary
        : (overview.people.any((p) => p.rhythm.status == RhythmStatus.overdue) ? t.warning : t.success);
    final birthdays = overview.upcomingBirthdays(withinDays: 30);
    final next = birthdays.firstOrNull;
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusXL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.l),
      child: Row(
        children: [
          ProgressRing(
            value: share ?? 0,
            size: 88,
            strokeWidth: 7,
            color: ringColor,
            glow: allGood,
            semanticLabel: l.familyGroupInTouch,
            semanticValue: share == null ? null : tx.percent(share),
            child: share == null
                ? Icon(Icons.family_restroom_rounded, color: t.accent, size: 32)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tx.count(overview.inTouch),
                        style: text.headlineSmall!.copyWith(color: t.textPrimary, height: 1.1),
                      ),
                      Text('/ ${tx.count(withRhythm)}', style: text.labelSmall!.copyWith(color: t.textTertiary)),
                    ],
                  ),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  withRhythm == 0
                      ? l.familyTitle
                      : (allGood ? l.familyHeroAllGood : tx.fmt.localizeDigits(l.familyHeroWaiting(due))),
                  style: text.titleLarge!.copyWith(color: allGood ? t.success : t.textPrimary),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  withRhythm == 0
                      ? l.familyHeroNoRhythm
                      : (allGood
                            ? l.familyHeroBlessing
                            : l.familyHeroInTouch(tx.count(overview.inTouch), tx.count(withRhythm))),
                  style: text.bodySmall!.copyWith(color: t.textSecondary),
                ),
                if (next != null) ...[
                  const SizedBox(height: Space.s),
                  Row(
                    children: [
                      Icon(Icons.cake_rounded, size: 15, color: t.gold),
                      const SizedBox(width: Space.xs),
                      Flexible(
                        child: Text(
                          tx.birthdayUpcoming(next.name, next.birthday!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium!.copyWith(color: t.gold),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
