import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/quran/quran_catalog.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../data/wird_providers.dart';
import '../data/wird_service.dart';
import '../domain/wird_engine.dart';
import 'widgets/wird_history_calendar.dart';
import 'widgets/wird_plan_tile.dart';
import 'widgets/wird_target_panel.dart';
import 'wird_actions.dart';
import 'wird_labels.dart';

/// The daily wird: today's portion of the focused plan (the primary one
/// unless another is tapped) with "read now", mark done and "I stopped at…";
/// streak, projected finish and progress; the plans (add, edit, pause,
/// make primary, delete – all with undo); and the month-by-month history.
///
/// "Read now" goes to [onReadNow], else to [wirdReadNowProvider] (the app
/// routes it to the Quran reader); without either the button is disabled.
class WirdScreen extends ConsumerStatefulWidget {
  const WirdScreen({super.key, this.onReadNow, this.initialPlanId, this.animateBackdrop = true});

  final WirdReadNow? onReadNow;

  /// Plan to focus first (e.g. from a reminder tap).
  final String? initialPlanId;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  ConsumerState<WirdScreen> createState() => _WirdScreenState();
}

class _WirdScreenState extends ConsumerState<WirdScreen> {
  late String? _focusedId = widget.initialPlanId;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    ref.watch(wirdCompletionSyncProvider);
    final states = ref.watch(wirdStatesProvider);
    final primaryId = ref.watch(wirdPrimaryIdProvider).value;
    final catalog = ref.watch(quranCatalogReadyProvider).value;
    final readNow = widget.onReadNow ?? ref.watch(wirdReadNowProvider);
    return MadarScaffold(
      title: l.wirdTitle,
      backdropSeed: 7.7,
      animateBackdrop:
          widget.animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      actions: [
        MadarButton.icon(
          icon: Icons.add_rounded,
          onPressed: catalog == null ? null : () => WirdActions.create(context, ref),
          semanticLabel: l.wirdAddPlan,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
        ),
      ],
      body: switch (states) {
        AsyncData(:final value) when catalog != null =>
          value.isEmpty
              ? Center(
                  child: AnimatedEmptyState(
                    kind: EmptyStateKind.emptyList,
                    title: l.wirdEmptyTitle,
                    body: l.wirdEmptyBody,
                    actionLabel: l.wirdEmptyAction,
                    actionIcon: Icons.auto_stories_rounded,
                    onAction: () => WirdActions.create(context, ref),
                  ),
                )
              : _content(context, value, primaryId, catalog, readNow),
        AsyncError() => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.wirdCatalogError, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }

  Widget _content(
    BuildContext context,
    List<WirdPlanState> states,
    String? primaryId,
    QuranCatalog catalog,
    WirdReadNow? readNow,
  ) {
    final l = L10n.of(context);
    final primary = WirdService.primaryOf([for (final s in states) s.plan], primaryId);
    final focused = states.firstWhere(
      (s) => s.plan.id == _focusedId,
      orElse: () => states.firstWhere((s) => s.plan.id == primary?.id),
    );
    var i = 0;
    return EntranceChoreo(
      id: 'wird',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        children: [
          StaggerItem(
            index: i++,
            child: AnimatedSwitcher(
              duration: context.motion(MadarMotion.medium),
              child: WirdTargetPanel(
                key: ValueKey(focused.plan.id),
                state: focused,
                catalog: catalog,
                primary: focused.plan.id == primary?.id,
                onReadNow: readNow == null || focused.target.resumeAt == null
                    ? null
                    : () => WirdActions.readNow(context, readNow, focused),
                onMarkDone: () => WirdActions.markDone(context, ref, focused),
                onStoppedAt: () => WirdActions.stoppedAt(context, ref, focused),
                onResume: () async {
                  final undo = await WirdActions.togglePause(context, ref, focused.plan);
                  if (context.mounted) unawaited(showUndoToast(context, undo));
                },
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: _StatsStrip(state: focused, catalog: catalog),
          ),
          StaggerItem(
            index: i++,
            child: SectionHeader(
              title: l.wirdPlansTitle,
              actionLabel: l.wirdAddPlan,
              onAction: () => WirdActions.create(context, ref),
              padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.m),
            ),
          ),
          for (final s in states)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
              child: StaggerItem(
                index: i++,
                child: WirdPlanTile(
                  key: ValueKey(s.plan.id),
                  state: s,
                  catalog: catalog,
                  primary: s.plan.id == primary?.id,
                  focused: s.plan.id == focused.plan.id && states.length > 1,
                  onTap: () {
                    Fx.fire(Sfx.tap);
                    setState(() => _focusedId = s.plan.id);
                  },
                  onEdit: () => WirdActions.edit(context, ref, s.plan),
                  onDelete: () => WirdActions.delete(context, ref, s.plan),
                  onTogglePause: () => WirdActions.togglePause(context, ref, s.plan),
                  onMakePrimary: () => WirdActions.makePrimary(context, ref, s.plan),
                  onMarkDone: s.target.remaining == null || s.paused || !s.started
                      ? null
                      : () async {
                          final undo = await ref
                              .read(wirdServiceProvider)
                              .markDone(s, pagesAxis: ref.read(wirdAxesProvider).value?.pages);
                          if (undo == null || !context.mounted) return null;
                          return UndoableAction(label: L10n.of(context).wirdDoneToast, undo: undo);
                        },
                ),
              ),
            ),
          StaggerItem(
            index: i++,
            child: SectionHeader(
              title: l.wirdHistoryTitle,
              subtitle: focused.plan.name,
              padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.m),
            ),
          ),
          StaggerItem(
            index: i++,
            child: WirdHistoryCalendar(key: ValueKey('cal-${focused.plan.id}'), state: focused),
          ),
        ],
      ),
    );
  }
}

/// Streak, projected finish and overall progress of a plan.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.state, required this.catalog});

  final WirdPlanState state;
  final QuranCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final texts = WirdTexts(l, fmt, catalog);
    final finish = state.projectedFinish;
    final plan = state.plan;
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.m, Space.s, Space.m),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                icon: Icons.local_fire_department_rounded,
                color: t.warning,
                value: fmt.formatInt(state.streak),
                label: l.wirdStreak,
                caption: l.wirdBestStreak(texts.days(state.bestStreak)),
              ),
            ),
            VerticalDivider(color: t.glassBorder, width: 1),
            Expanded(
              child: _Stat(
                icon: Icons.flag_circle_rounded,
                color: t.success,
                value: finish == null ? l.wirdNoProjection : fmt.formatDate(finish, style: MadarDateStyle.dayMonth),
                label: l.wirdFinish,
                caption: plan.targetDate == null
                    ? fmt.localizeDigits(l.wirdKhatmas(state.khatmas))
                    : l.wirdTargetDate(fmt.formatDate(plan.targetDate!, style: MadarDateStyle.dayMonth)),
              ),
            ),
            VerticalDivider(color: t.glassBorder, width: 1),
            Expanded(
              child: _Stat(
                icon: Icons.donut_large_rounded,
                color: t.accent,
                value: fmt.formatPercent(state.fraction),
                label: l.wirdProgress,
                caption: plan.isKhatma
                    ? texts.amount(WirdUnit.pages, state.progress)
                    : texts.pages(AyahRange.single(state.cursor ?? plan.start)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.value, required this.label, this.caption});

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: [label, value, ?caption].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: Space.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, maxLines: 1, style: text.titleLarge!.copyWith(color: t.textPrimary)),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelMedium),
            if (caption != null)
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: text.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}
