/// One exercise of **his** library (Part 8, «#24 – Body / gym»).
///
/// The machine's picture, the movement's video, the muscles he named, the
/// numbers he set, his own history with it – the chart, the heaviest set he
/// ever did – and what his own arithmetic comes to for next time.
///
/// Madar ships no exercise, no picture and no video: a fresh install opens
/// this screen on an empty frame he fills himself.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/body_providers.dart';
import '../../data/gym_media.dart';
import '../../domain/body_week.dart';
import '../../domain/training.dart';
import '../body_actions.dart';
import '../body_texts.dart';
import '../gym_actions.dart';
import '../gym_texts.dart';
import '../sheets/exercise_history_sheet.dart';
import '../widgets/body_charts.dart';
import '../widgets/body_widgets.dart';
import '../widgets/gym_widgets.dart';

/// His own page for one exercise.
class GymExerciseScreen extends ConsumerStatefulWidget {
  const GymExerciseScreen({super.key, required this.exerciseId, this.animateBackdrop = true});

  final String exerciseId;
  final bool animateBackdrop;

  @override
  ConsumerState<GymExerciseScreen> createState() => _GymExerciseScreenState();
}

class _GymExerciseScreenState extends ConsumerState<GymExerciseScreen> {
  ProgressMetric? _metric;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final exercise = ref.watch(bodyExerciseProvider(widget.exerciseId));
    return MadarScaffold(
      title: exercise?.name ?? l.gymTitle,
      backdropSeed: 6.4,
      animateBackdrop:
          widget.animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      actions: exercise == null
          ? const []
          : [
              MadarButton.icon(
                key: const ValueKey('gym.exercise.edit'),
                icon: Icons.edit_outlined,
                semanticLabel: l.gymEditExerciseAction,
                variant: MadarButtonVariant.ghost,
                sfx: Sfx.sheetOpen,
                onPressed: () => unawaited(BodyActions.editExercise(context, ref, widget.exerciseId)),
              ),
            ],
      floatingAction: exercise == null
          ? null
          : MadarButton.icon(
              key: const ValueKey('gym.exercise.log'),
              icon: Icons.add_task_rounded,
              semanticLabel: l.gymLogSession,
              variant: MadarButtonVariant.primary,
              size: MadarButtonSize.large,
              sfx: Sfx.sheetOpen,
              onPressed: () => unawaited(BodyActions.logWithDetails(context, ref, exercise: exercise)),
            ),
      body: exercise == null
          ? Center(
              child: AnimatedEmptyState(
                key: const ValueKey('gym.exercise.gone'),
                kind: EmptyStateKind.noData,
                title: l.gymNoLibraryTitle,
                body: l.gymNoLibraryBody,
              ),
            )
          : _Body(
              exercise: exercise,
              metric: _metric,
              onMetric: (m) => setState(() => _metric = m),
            ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.exercise, required this.metric, required this.onMetric});

  final PlannedExercise exercise;
  final ProgressMetric? metric;
  final ValueChanged<ProgressMetric?> onMetric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final gx = GymTexts.of(context);
    final text = Theme.of(context).textTheme;
    final e = exercise;
    final progress = ref.watch(bodyExerciseProgressProvider(e.id));
    final load = ref.watch(bodyNextLoadProvider(e.id));
    final available = progress.available;
    final shown = metric != null && available.contains(metric) ? metric! : progress.preferred;
    final points = shown == null ? const <ProgressPoint>[] : progress.of(shown);
    final best = progress.bestSet;
    final bestReps = progress.bestRepsSet;
    final summary = tx.planSummary(e);
    final start = BodyWeek.startFor(tx.fmt.languageCode);
    var i = 0;
    Widget stagger(Widget child) => StaggerItem(index: i++, child: child);
    return ListView(
      key: const PageStorageKey('gym.exercise'),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bodyTabBottomPadding),
      children: [
        stagger(_MediaCard(exercise: e)),
        const SizedBox(height: Space.s),
        stagger(
          BodyCard(
            key: const ValueKey('gym.exercise.numbers'),
            title: l.bodyTarget,
            icon: Icons.track_changes_rounded,
            iconColor: p.training,
            seed: 5.1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WeekdayDots(weekdays: e.weekdays, color: p.training, dimmed: !e.active),
                const SizedBox(height: Space.s),
                Text(
                  summary.isEmpty ? l.bodyNotSet : summary,
                  style: text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                const SizedBox(height: Space.xs),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    if (e.restSec != null)
                      BodyPill(
                        label: '${l.gymRestShort}: ${gx.seconds(e.restSec!)}',
                        icon: Icons.timer_outlined,
                        color: p.water,
                        dense: true,
                      ),
                    if (e.warmupSets != null)
                      BodyPill(
                        label: '${l.gymWarmup}: ${tx.fmt.formatInt(e.warmupSets!)}',
                        icon: Icons.whatshot_outlined,
                        color: t.gold,
                        dense: true,
                      ),
                    if (!e.active) BodyPill(label: l.bodyPaused, icon: Icons.pause_rounded, color: t.warning, dense: true),
                  ],
                ),
                const SizedBox(height: Space.m),
                Text(l.gymMuscles, style: text.labelMedium?.copyWith(color: t.textSecondary)),
                const SizedBox(height: Space.xs),
                GymMuscleChips(muscles: e.muscles),
                if (e.notes != null) ...[
                  const SizedBox(height: Space.m),
                  Text(e.notes!, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                ],
                const SizedBox(height: Space.s),
                Text(
                  tx.weekdayList(BodyWeek.inDisplayOrder(e.weekdays, start)),
                  style: text.bodySmall?.copyWith(color: t.textTertiary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.s),
        // His own numbers for next time – arithmetic, never advice.
        stagger(
          GymNextLoadCard(
            load: load,
            onUse: load.any
                ? () => unawaited(
                    BodyActions.logWithDetails(
                      context,
                      ref,
                      exercise: e.copyWith(reps: load.reps, weight: load.weight),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: Space.s),
        stagger(
          BodyCard(
            key: const ValueKey('gym.exercise.best'),
            title: l.gymBestSet,
            icon: Icons.emoji_events_outlined,
            iconColor: t.gold,
            seed: 4.2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (best == null && bestReps == null)
                  Text(l.bodyHistoryEmpty, style: text.bodySmall?.copyWith(color: t.textTertiary))
                else ...[
                  if (best != null)
                    _BestLine(
                      label: l.gymBestSet,
                      value: gx.set(best.set),
                      when: l.gymBestOn(tx.fmt.formatDate(best.day, style: MadarDateStyle.dayMonth)),
                    ),
                  if (bestReps != null && (best == null || bestReps.set.reps != best.set.reps)) ...[
                    const SizedBox(height: Space.s),
                    _BestLine(
                      label: l.gymBestReps,
                      value: tx.reps(bestReps.set.reps ?? 0),
                      when: l.gymBestOn(tx.fmt.formatDate(bestReps.day, style: MadarDateStyle.dayMonth)),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.s),
        stagger(
          BodyCard(
            key: const ValueKey('gym.exercise.progress'),
            title: l.gymProgress,
            icon: Icons.insights_rounded,
            iconColor: p.training,
            seed: 7.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (progress.logs.isEmpty)
                  Text(l.bodyHistoryEmpty, style: text.bodySmall?.copyWith(color: t.textTertiary))
                else ...[
                  if (available.length > 1) ...[
                    ChoicePills<ProgressMetric>.single(
                      key: const ValueKey('gym.exercise.metric'),
                      options: [for (final m in available) ChoiceOption(value: m, label: tx.metric(m))],
                      selected: shown,
                      dense: true,
                      onChanged: onMetric,
                    ),
                    const SizedBox(height: Space.m),
                  ],
                  if (points.length >= 2 && shown != null)
                    ProgressLineChart(
                      key: ValueKey(shown),
                      points: points,
                      color: shown == ProgressMetric.minutes ? p.eating : p.training,
                      valueLabel: (v) => tx.metricValue(shown, v),
                      semanticLabel: tx.metric(shown),
                    )
                  else
                    BodyHint(l.bodyHistoryOneDay, icon: Icons.show_chart_rounded),
                ],
                const SizedBox(height: Space.m),
                MadarButton(
                  key: const ValueKey('gym.exercise.history'),
                  label: l.gymOpenHistory,
                  icon: Icons.history_rounded,
                  variant: MadarButtonVariant.secondary,
                  sfx: Sfx.sheetOpen,
                  onPressed: () => unawaited(showExerciseHistorySheet(context, e.id)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BestLine extends StatelessWidget {
  const _BestLine({required this.label, required this.value, required this.when});

  final String label;
  final String value;
  final String when;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value. $when',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelSmall?.copyWith(color: t.textTertiary)),
                Text(
                  value,
                  style: text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
          Text(when, style: text.bodySmall?.copyWith(color: t.textSecondary)),
        ],
      ),
    );
  }
}

/// The machine's picture and the movement's video, with the one sentence
/// that says what Madar does with each.
class _MediaCard extends ConsumerWidget {
  const _MediaCard({required this.exercise});

  final PlannedExercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final e = exercise;
    final video = GymVideo.parse(e.video);
    return BodyCard(
      key: const ValueKey('gym.exercise.media'),
      title: l.gymMedia,
      icon: Icons.photo_camera_back_outlined,
      seed: 1.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GymPhotoView(
                key: const ValueKey('gym.exercise.photo'),
                photo: e.photo,
                name: e.name,
                size: 96,
                onTap: () => unawaited(GymActions.pickPhoto(context, ref, e.id)),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.gymMachinePhoto, style: text.titleSmall),
                    const SizedBox(height: Space.xs),
                    Text(l.gymPhotoKept, style: text.bodySmall?.copyWith(color: t.textTertiary)),
                    const SizedBox(height: Space.s),
                    Wrap(
                      spacing: Space.s,
                      runSpacing: Space.xs,
                      children: [
                        MadarButton(
                          key: const ValueKey('gym.photo.pick'),
                          label: e.photo == null ? l.gymAddPhoto : l.gymChangePhoto,
                          icon: Icons.image_outlined,
                          variant: MadarButtonVariant.secondary,
                          size: MadarButtonSize.small,
                          onPressed: () => unawaited(GymActions.pickPhoto(context, ref, e.id)),
                        ),
                        if (e.photo != null)
                          MadarButton(
                            key: const ValueKey('gym.photo.remove'),
                            label: l.gymRemovePhoto,
                            icon: Icons.delete_outline_rounded,
                            variant: MadarButtonVariant.danger,
                            size: MadarButtonSize.small,
                            onPressed: () => unawaited(GymActions.removePhoto(context, ref, e.id)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const MadarDivider(ornament: false, height: Space.xl),
          Row(
            children: [
              Icon(Icons.play_circle_outline_rounded, size: 18, color: t.gold),
              const SizedBox(width: Space.s),
              Expanded(child: Text(l.gymVideo, style: text.titleSmall)),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            video == null
                ? l.gymVideoKept
                : (video.exists ? video.label : '${video.label}${BodyTexts.of(context).sep}${l.gymVideoMissing}'),
            key: const ValueKey('gym.exercise.video.label'),
            style: text.bodySmall?.copyWith(color: video != null && !video.exists ? t.warning : t.textTertiary),
          ),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.xs,
            children: [
              if (video != null)
                MadarButton(
                  key: const ValueKey('gym.video.open'),
                  label: l.gymVideoOpen,
                  icon: Icons.play_arrow_rounded,
                  variant: MadarButtonVariant.secondary,
                  size: MadarButtonSize.small,
                  onPressed: () => unawaited(GymActions.openVideo(context, ref, video)),
                ),
              MadarButton(
                key: const ValueKey('gym.video.pick'),
                label: l.gymVideoFromFiles,
                icon: Icons.video_library_outlined,
                variant: MadarButtonVariant.secondary,
                size: MadarButtonSize.small,
                onPressed: () => unawaited(GymActions.pickVideo(context, ref, e.id)),
              ),
              MadarButton(
                key: const ValueKey('gym.video.link'),
                label: l.gymVideoFromLink,
                icon: Icons.link_rounded,
                variant: MadarButtonVariant.secondary,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetOpen,
                onPressed: () => unawaited(GymActions.addVideoLink(context, ref, e.id)),
              ),
              if (video != null)
                MadarButton(
                  key: const ValueKey('gym.video.remove'),
                  label: l.gymRemoveVideo,
                  icon: Icons.delete_outline_rounded,
                  variant: MadarButtonVariant.danger,
                  size: MadarButtonSize.small,
                  onPressed: () => unawaited(GymActions.removeVideo(context, ref, e.id)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
