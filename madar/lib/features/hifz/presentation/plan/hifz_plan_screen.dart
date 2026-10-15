/// «الحفظ» · the morning screen (Part 14, step 2).
///
/// The first thing he sees after Fajr: today's three portions – «الجديد»,
/// «المراجعة القريبة» and «المراجعة البعيدة» – each with its stretch, how
/// many ayat it holds, how strongly he holds it, the method the plan
/// suggests, and one tap to start it.
///
/// After days away the first card is the backlog: «غبت ٧ أيام، و٣٥٩ آية
/// رجعت لدورها» with the stretches it names. Nothing is swallowed and
/// nothing piles up: the day is still one ordinary day.
///
/// The screen asks [hifzMethodsProvider] before it offers anything, so a
/// method that needs the microphone is shown as "not ready yet" and the
/// typed ones take its place.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/quran/ayah.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../wird/data/wird_providers.dart' show quranCatalogReadyProvider;
import '../../data/hifz_plan_providers.dart';
import '../../domain/hifz_daily_plan.dart';
import '../../domain/hifz_modes.dart';
import '../hifz_actions.dart';
import 'hifz_drill_screen.dart' show showHifzMethodSheet;
import 'hifz_plan_nav.dart';
import 'hifz_plan_texts.dart';
import 'hifz_plan_widgets.dart';

/// «الحفظ»: today's plan, and the way in to everything else.
class HifzPlanScreen extends ConsumerWidget {
  const HifzPlanScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final plan = ref.watch(hifzDailyPlanProvider);
    final texts = HifzPlanTexts.of(context, catalog: ref.watch(quranCatalogReadyProvider).value);
    return MadarScaffold(
      title: l.hifzPlanTitle,
      backdropSeed: 4.1,
      animateBackdrop:
          animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      actions: [
        MadarButton.icon(
          key: const ValueKey('hifz.plan.find'),
          icon: Icons.travel_explore_rounded,
          semanticLabel: l.hifzPlanOpenFind,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.navigate,
          onPressed: () => hifzPlanGo(context, ref, HifzPlanDestination.find),
        ),
        MadarButton.icon(
          key: const ValueKey('hifz.plan.map'),
          icon: Icons.grid_view_rounded,
          semanticLabel: l.hifzPlanOpenMap,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.navigate,
          onPressed: () => hifzPlanGo(context, ref, HifzPlanDestination.map),
        ),
        MadarButton.icon(
          key: const ValueKey('hifz.plan.goals'),
          icon: Icons.flag_outlined,
          semanticLabel: l.hifzPlanOpenGoals,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.navigate,
          onPressed: () => hifzPlanGo(context, ref, HifzPlanDestination.goals),
        ),
        MadarButton.icon(
          key: const ValueKey('hifz.plan.settings'),
          icon: Icons.tune_rounded,
          semanticLabel: l.hifzPlanSettings,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => unawaited(showHifzPlanSettingsSheet(context, ref)),
        ),
      ],
      body: switch (plan) {
        AsyncData(value: final p) => _Body(plan: p, texts: texts),
        AsyncError() => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.hifzCatalogError, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.plan, required this.texts});

  final HifzDailyPlan plan;
  final HifzPlanTexts texts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final near = plan.near;
    final far = plan.far;
    return ListView(
      key: const PageStorageKey('hifz.plan'),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
      children: [
        // What today holds, in one line he can read while the kettle boils.
        HifzPanel(
          key: const ValueKey('hifz.plan.summary'),
          title: fmt.localizeDigits(
            l.hifzPlanTodaySummary(texts.ayat(plan.totalAyat), texts.portions(plan.portions.length)),
          ),
          subtitle: l.hifzPlanScreenSubtitle,
          icon: Icons.wb_twilight_rounded,
          iconColor: t.gold,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                fmt.localizeDigits(l.hifzPlanMemorisedLine(texts.ayat(plan.memorisedAyat))),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
              ),
              if (far.isNotEmpty)
                Text(
                  fmt.localizeDigits(l.hifzPlanCycleLine(texts.days(plan.cycleDays))),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
            ],
          ),
        ),
        // The backlog, first and in full: what a week away cost, and where
        // it went.
        if (!plan.backlog.isEmpty && plan.backlog.missedDays > 0) ...[
          const SizedBox(height: Space.m),
          _BacklogCard(backlog: plan.backlog, texts: texts),
        ],
        for (final note in plan.notes)
          if (texts.note(note) != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: HifzPanel(
                key: ValueKey('hifz.plan.note.${note.name}'),
                icon: Icons.info_outline_rounded,
                iconColor: t.textSecondary,
                child: Text(
                  texts.note(note)!,
                  key: ValueKey('hifz.plan.note.text.${note.name}'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                ),
              ),
            ),
        if (plan.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.l),
            child: AnimatedEmptyState(
              key: const ValueKey('hifz.plan.empty'),
              kind: EmptyStateKind.emptyList,
              title: l.hifzPlanNothingTitle,
              body: l.hifzPlanEmpty,
              actionLabel: l.hifzPlanAddFirst,
              actionIcon: Icons.add_rounded,
              onAction: () => unawaited(HifzActions.addAyat(context, ref)),
            ),
          ),
        if (plan.fresh != null) ...[
          _TrackHeader(track: HifzTrack.fresh, texts: texts),
          _PortionCard(portion: plan.fresh!, texts: texts),
        ],
        if (near.isNotEmpty) ...[
          _TrackHeader(track: HifzTrack.near, texts: texts),
          for (final p in near)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: _PortionCard(portion: p, texts: texts),
            ),
        ],
        if (far.isNotEmpty) ...[
          _TrackHeader(track: HifzTrack.far, texts: texts),
          for (final p in far)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: _PortionCard(portion: p, texts: texts),
            ),
        ],
        const HifzHonestyNote(),
      ],
    );
  }
}

/// «غبت ٧ أيام، و٣٥٩ آية رجعت لدورها» – and exactly which stretches.
class _BacklogCard extends StatelessWidget {
  const _BacklogCard({required this.backlog, required this.texts});

  final HifzBacklog backlog;
  final HifzPlanTexts texts;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final style = Theme.of(context).textTheme;
    return HifzPanel(
      key: const ValueKey('hifz.plan.backlog'),
      title: l.hifzBacklogTitle,
      icon: Icons.event_busy_rounded,
      iconColor: t.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            texts.backlog(backlog),
            key: const ValueKey('hifz.plan.backlog.line'),
            style: style.bodyMedium,
          ),
          if (backlog.dropped.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            Text(
              texts.backlogRanges(backlog),
              key: const ValueKey('hifz.plan.backlog.ranges'),
              style: style.bodySmall?.copyWith(color: t.textSecondary),
            ),
          ],
          if (backlog.reasons.contains(HifzDropReason.dailyCap)) ...[
            const SizedBox(height: Space.s),
            Text(l.hifzBacklogCapped, style: style.bodySmall?.copyWith(color: t.textTertiary)),
          ],
        ],
      ),
    );
  }
}

class _TrackHeader extends StatelessWidget {
  const _TrackHeader({required this.track, required this.texts});

  final HifzTrack track;
  final HifzPlanTexts texts;

  @override
  Widget build(BuildContext context) => SectionHeader(
    key: ValueKey('hifz.plan.track.${track.name}'),
    title: texts.track(track),
    subtitle: texts.trackNote(track),
    padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.s),
  );
}

/// One portion: the stretch, its size, its band, the suggested method and
/// one tap to start it.
class _PortionCard extends ConsumerWidget {
  const _PortionCard({required this.portion, required this.texts});

  final HifzPortion portion;
  final HifzPlanTexts texts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final style = Theme.of(context).textTheme;
    final states = ref.watch(hifzMethodsProvider);
    final pages = texts.pages(portion.range);
    final label = texts.range(portion.range);
    return HifzPanel(
      key: ValueKey('hifz.plan.portion.${portion.track.name}.${portion.range.first}-${portion.range.last}'),
      title: label,
      subtitle: [
        texts.ayat(portion.ayahCount),
        ?pages,
      ].join(l.commonFactSeparator),
      icon: texts.trackIcon(portion.track),
      // Bounded on purpose: «ما انختبرت» / "Never tested" at text scale
      // 1.3 would otherwise push the title's row off the card.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 116),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HifzBandDot(band: portion.band, texts: texts),
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(
                texts.band(portion.band),
                style: style.labelSmall?.copyWith(color: texts.bandColor(portion.band)),
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            fmt.localizeDigits(l.hifzPlanSuggestedMethod(texts.method(portion.method))),
            key: ValueKey('hifz.plan.portion.method.${portion.range.first}'),
            style: style.bodySmall?.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              MadarButton(
                key: ValueKey('hifz.plan.start.${portion.range.first}'),
                label: l.hifzPlanStart,
                icon: Icons.play_arrow_rounded,
                size: MadarButtonSize.small,
                semanticLabel: '${l.hifzPlanStart}. $label. ${texts.method(portion.method)}',
                onPressed: () => hifzStartDrill(context, ref, HifzDrillRequest.ofPortion(portion)),
              ),
              MadarButton(
                key: ValueKey('hifz.plan.pick.${portion.range.first}'),
                label: l.hifzPlanPickMethod,
                icon: Icons.swap_horiz_rounded,
                size: MadarButtonSize.small,
                variant: MadarButtonVariant.ghost,
                onPressed: () => unawaited(_pick(context, ref, states)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref, List<HifzMethodState> states) async {
    final picked = await showHifzMethodSheet(
      context,
      states: states,
      texts: texts,
      current: portion.method,
    );
    if (picked == null || !context.mounted) return;
    hifzStartDrill(context, ref, HifzDrillRequest.ofPortion(portion, method: picked));
  }
}

/// How much new a day, and where the new portion starts – without these
/// two there is never a «جديد», and the plan says so instead of guessing.
Future<void> showHifzPlanSettingsSheet(BuildContext context, WidgetRef ref) async {
  final l = L10n.of(context);
  final settings = ref.read(hifzPlanSettingsProvider).value ?? const HifzPlanSettings();
  final catalog = ref.read(quranCatalogReadyProvider).value;
  final from = settings.newFrom;
  final values = await showEditSheet(
    context,
    title: l.hifzPlanSettings,
    icon: Icons.tune_rounded,
    subtitle: l.hifzSettingsCapNote,
    fields: [
      FieldSpec.number(
        'perDay',
        l.hifzSettingsNewPerDay,
        min: 0,
        max: 100,
        step: 1,
        icon: Icons.auto_awesome_rounded,
      ),
      FieldSpec.number('surah', l.hifzGoalFieldSurah, min: 1, max: 114, step: 1, icon: Icons.menu_book_rounded),
      FieldSpec.number('ayah', l.hifzSettingsStartFrom, min: 1, max: 286, step: 1, icon: Icons.format_list_numbered),
      FieldSpec.number('cap', l.hifzSettingsCap, min: 1, max: 600, step: 5, icon: Icons.speed_rounded),
      FieldSpec.number('repetitions', l.hifzSettingsRepetitions, min: 1, max: 20, step: 1, icon: Icons.repeat_rounded),
    ],
    initial: {
      'perDay': settings.newAyatPerDay,
      'surah': from?.surah ?? 1,
      'ayah': from?.ayah ?? 1,
      'cap': settings.dailyCapAyat,
      'repetitions': settings.repetitions,
    },
  );
  if (values == null || !context.mounted) return;
  int pick(String key, int fallback) => (values[key] as num?)?.toInt() ?? fallback;
  final surah = pick('surah', 1).clamp(1, 114).toInt();
  final maxAyah = catalog?.ayahCount(surah) ?? 286;
  final ayah = pick('ayah', 1).clamp(1, maxAyah).toInt();
  final service = await ref.read(hifzPlanServiceProvider.future);
  final undo = await service.setSettings(
    settings.copyWith(
      newAyatPerDay: pick('perDay', settings.newAyatPerDay),
      newFrom: AyahRef(surah, ayah),
      dailyCapAyat: pick('cap', settings.dailyCapAyat),
      repetitions: pick('repetitions', settings.repetitions),
    ),
  );
  if (!context.mounted) return;
  Fx.fire(Sfx.complete);
  unawaited(showUndoToast(context, UndoableAction(label: l.hifzSettingsSaved, undo: undo)));
}

/// The compact «حفظ اليوم» card for the Faith world: today's first
/// portion and how big the day is, or the invitation to start.
class HifzPlanTodayCard extends ConsumerWidget {
  const HifzPlanTodayCard({super.key, this.onOpen});

  /// Opens «الحفظ» (default: the route).
  final void Function(BuildContext context)? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final texts = HifzPlanTexts.of(context, catalog: ref.watch(quranCatalogReadyProvider).value);
    final plan = ref.watch(hifzDailyPlanProvider).value;
    final first = plan?.portions.firstOrNull;
    void open() {
      Fx.fire(Sfx.navigate);
      if (onOpen != null) {
        onOpen!(context);
      } else {
        hifzPlanGo(context, ref, HifzPlanDestination.plan);
      }
    }

    return HifzPanel(
      key: const ValueKey('hifz.faithCard'),
      title: l.hifzFaithCardTitle,
      icon: Icons.psychology_alt_rounded,
      iconColor: t.gold,
      onTap: open,
      semanticLabel: [
        l.hifzFaithCardTitle,
        if (plan != null)
          fmt.localizeDigits(
            l.hifzPlanTodaySummary(texts.ayat(plan.totalAyat), texts.portions(plan.portions.length)),
          ),
      ].join('. '),
      trailing: Icon(Icons.chevron_right_rounded, size: 22, color: t.textTertiary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (plan == null)
            Text(l.hifzFaithCardEmpty, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textSecondary))
          else ...[
            Text(
              fmt.localizeDigits(
                l.hifzPlanTodaySummary(texts.ayat(plan.totalAyat), texts.portions(plan.portions.length)),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (first != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.xxs),
                child: Text(
                  '${texts.track(first.track)}${l.commonFactSeparator}${texts.range(first.range)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ),
            if (plan.backlog.missedDays > 0)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  texts.backlog(plan.backlog),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.warning),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
