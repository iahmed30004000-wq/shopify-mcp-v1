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
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../../wird/data/wird_providers.dart';
import '../data/hifz_providers.dart';
import '../data/hifz_service.dart';
import '../domain/hifz_models.dart';
import 'hifz_actions.dart';
import 'hifz_labels.dart';
import 'hifz_navigation.dart';
import 'hifz_sheets.dart';
import 'widgets/hifz_segmented.dart';
import 'widgets/hifz_widgets.dart';

enum HifzTab { due, fresh, learned }

/// Hifz: today's review (due, then new up to the daily limit) with retention,
/// learned count, streak and the week's forecast; the items in Due / New /
/// Learned tabs (preview, edit, suspend, start over, delete – with undo);
/// adding ayat, a hadith of An-Nawawi's Forty or your own text.
class HifzScreen extends ConsumerStatefulWidget {
  const HifzScreen({super.key, this.onStartReview, this.initialTab = HifzTab.due, this.animateBackdrop = true});

  /// Opens the review ([only] = one item); default: [HifzNavigation.openReview].
  final HifzStartReview? onStartReview;
  final HifzTab initialTab;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  ConsumerState<HifzScreen> createState() => _HifzScreenState();
}

class _HifzScreenState extends ConsumerState<HifzScreen> {
  late HifzTab _tab = widget.initialTab;

  void _review({HifzCard? only}) {
    if (widget.onStartReview != null) {
      Fx.fire(Sfx.navigate);
      widget.onStartReview!(context, only: only);
    } else {
      unawaited(HifzNavigation.openReview(context, only: only));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final cards = ref.watch(hifzCardsProvider);
    final stats = ref.watch(hifzStatsProvider);
    return MadarScaffold(
      title: l.hifzTitle,
      backdropSeed: 3.9,
      animateBackdrop:
          widget.animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      actions: [
        MadarButton.icon(
          icon: Icons.tune_rounded,
          onPressed: () => showHifzSettingsSheet(context),
          semanticLabel: l.hifzSettingsTitle,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
        ),
        MadarButton.icon(
          icon: Icons.add_rounded,
          onPressed: () => HifzActions.add(context, ref),
          semanticLabel: l.hifzAdd,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
        ),
      ],
      body: switch ((cards, stats)) {
        (AsyncData(value: final list), AsyncData(value: final s)) =>
          list.isEmpty
              ? Center(
                  child: AnimatedEmptyState(
                    kind: EmptyStateKind.emptyList,
                    title: l.hifzEmptyTitle,
                    body: l.hifzEmptyBody,
                    actionLabel: l.hifzAdd,
                    actionIcon: Icons.add_rounded,
                    onAction: () => HifzActions.add(context, ref),
                  ),
                )
              : _content(context, list, s),
        (AsyncError(), _) => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.hifzCatalogError, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }

  Widget _content(BuildContext context, List<HifzCard> cards, HifzStats stats) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final today = ref.watch(wirdTodayProvider);
    final texts = HifzTexts(
      l,
      fmt,
      catalog: ref.watch(quranCatalogReadyProvider).value,
      hadith: ref.watch(hadithCollectionProvider).value,
    );
    final due = cards.where((c) => c.isDue(today)).toList()..sort((a, b) => a.due!.compareTo(b.due!));
    final fresh = cards.where((c) => c.isNew).toList();
    // Everything memorised at least once (due items too), soonest first;
    // suspended ones last.
    final learned = cards.where((c) => !c.isNew).toList()
      ..sort((a, b) {
        if (a.suspended != b.suspended) return a.suspended ? 1 : -1;
        return a.due!.compareTo(b.due!);
      });
    final shown = switch (_tab) {
      HifzTab.due => due,
      HifzTab.fresh => fresh,
      HifzTab.learned => learned,
    };
    var i = 0;
    return EntranceChoreo(
      id: 'hifz',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        children: [
          StaggerItem(
            index: i++,
            child: _Hero(stats: stats, onStart: () => _review()),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: _StatsStrip(stats: stats),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: HifzForecast(forecast: stats.forecast, today: today),
          ),
          const SizedBox(height: Space.xl),
          StaggerItem(
            index: i++,
            child: HifzSegmented<HifzTab>(
              values: HifzTab.values,
              value: _tab,
              labels: {HifzTab.due: l.hifzTabDue, HifzTab.fresh: l.hifzTabNew, HifzTab.learned: l.hifzTabLearned},
              counts: {
                HifzTab.due: fmt.formatInt(due.length),
                HifzTab.fresh: fmt.formatInt(fresh.length),
                HifzTab.learned: fmt.formatInt(learned.length),
              },
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
          const SizedBox(height: Space.m),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xl),
              child: Text(
                switch (_tab) {
                  HifzTab.due => l.hifzEmptyDue,
                  HifzTab.fresh => l.hifzEmptyNew,
                  HifzTab.learned => l.hifzEmptyLearned,
                },
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: context.tokens.textTertiary),
              ),
            ),
          for (final c in shown)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
              child: AnimatedReveal(
                key: ValueKey(c.id),
                child: HifzItemTile(
                  card: c,
                  texts: texts,
                  today: today,
                  onTap: () => showHifzPreview(
                    context,
                    card: c,
                    texts: texts,
                    today: today,
                    onReviewNow: () => _review(only: c),
                    onEdit: c.kind == HifzKind.hadith ? null : () => HifzActions.edit(context, ref, c),
                  ),
                  onEdit: c.kind == HifzKind.hadith ? null : () => HifzActions.edit(context, ref, c),
                  onDelete: () => HifzActions.delete(context, ref, c),
                  onToggleSuspend: () => HifzActions.toggleSuspend(context, ref, c),
                  onReset: () => HifzActions.reset(context, ref, c),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.stats, required this.onStart});

  final HifzStats stats;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final left = stats.sessionSize;
    final done = stats.reviewedToday;
    final all = left == 0;
    final progress = all ? 1.0 : done / (done + left);
    return GlassPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.l),
      glowColor: all ? t.success.withValues(alpha: 0.5) : t.accentGlow,
      child: Row(
        children: [
          ProgressRing(
            value: progress,
            size: 108,
            strokeWidth: 8,
            color: all ? t.success : t.accent,
            semanticLabel: l.hifzTodayTitle,
            semanticValue: fmt.localizeDigits(l.hifzDueCount(left)),
            child: all
                ? Icon(Icons.check_rounded, size: 42, color: t.success)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fmt.formatInt(left), style: text.headlineMedium!.copyWith(height: 1.1)),
                      Text(l.hifzStatDue, style: text.labelSmall),
                    ],
                  ),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.hifzTodayTitle, style: text.labelMedium!.copyWith(color: t.accent)),
                const SizedBox(height: Space.xxs),
                Text(
                  all ? l.hifzAllCaughtUp : fmt.localizeDigits(l.hifzDueCount(stats.dueToday)),
                  style: all ? text.titleMedium!.copyWith(color: t.success) : text.headlineSmall,
                ),
                if (!all && stats.newLeftToday > 0)
                  Text(
                    fmt.localizeDigits(l.hifzNewCount(stats.newLeftToday)),
                    style: text.bodySmall!.copyWith(color: t.info),
                  ),
                const SizedBox(height: Space.m),
                MadarButton(
                  label: done > 0 && !all ? l.hifzContinueReview : l.hifzStartReview,
                  icon: Icons.play_arrow_rounded,
                  onPressed: all ? null : onStart,
                  expand: true,
                  sfx: Sfx.navigate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats});

  final HifzStats stats;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    Widget stat(IconData icon, Color color, String value, String label, String? caption) => Expanded(
      child: Semantics(
        container: true,
        label: [label, value, ?caption].join(', '),
        excludeSemantics: true,
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: Space.xs),
            Text(value, style: text.titleLarge!.copyWith(color: t.textPrimary)),
            Text(label, style: text.labelMedium),
            if (caption != null) Text(caption, style: text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.m, Space.s, Space.m),
      child: IntrinsicHeight(
        child: Row(
          children: [
            stat(
              Icons.psychology_rounded,
              t.success,
              stats.retention == null ? '—' : fmt.formatPercent(stats.retention!),
              l.hifzStatRetention,
              l.hifzRetentionCaption(fmt.formatInt(30)),
            ),
            VerticalDivider(color: t.glassBorder, width: 1),
            stat(Icons.auto_stories_rounded, t.accent, fmt.formatInt(stats.learned), l.hifzStatLearned, null),
            VerticalDivider(color: t.glassBorder, width: 1),
            stat(Icons.local_fire_department_rounded, t.warning, fmt.formatInt(stats.streak), l.hifzStatStreak, null),
          ],
        ),
      ),
    );
  }
}

/// Daily new items, listening repeats and chunk size.
Future<void> showHifzSettingsSheet(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const _SettingsSheet());

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final s = ref.watch(hifzSettingsProvider).value ?? const HifzSettings();
    final service = ref.read(hifzServiceProvider);
    Widget section(
      String title,
      List<int> choices,
      int value,
      String Function(int) label,
      HifzSettings Function(int) update,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: Space.l, bottom: Space.s),
          child: Text(title, style: text.titleSmall),
        ),
        ChoicePills<int>.single(
          options: [for (final c in choices) ChoiceOption(value: c, label: label(c))],
          selected: value,
          onChanged: (v) {
            if (v != null) unawaited(service.saveSettings(update(v)));
          },
        ),
      ],
    );
    return InteractionSheetFrame(
      title: l.hifzSettingsTitle,
      icon: Icons.tune_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section(
            l.hifzNewPerDay,
            HifzSettings.newPerDayChoices,
            s.newPerDay,
            fmt.formatInt,
            (v) => s.copyWith(newPerDay: v),
          ),
          section(
            l.hifzListenRepeat,
            HifzSettings.repeatChoices,
            s.listenRepeat,
            (v) => fmt.localizeDigits(l.hifzRepeatTimes(v)),
            (v) => s.copyWith(listenRepeat: v),
          ),
          section(
            l.hifzChunkSize,
            HifzSettings.chunkChoices,
            s.chunkSize,
            fmt.formatInt,
            (v) => s.copyWith(chunkSize: v),
          ),
        ],
      ),
    );
  }
}
