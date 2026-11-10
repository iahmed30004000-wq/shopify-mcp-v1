/// «جلسة اليوم» · the session runner (Part 8, «#24 – Body / gym»).
///
/// It walks him through today's session one **set** at a time: the
/// exercise, which set of it he is on, whether that set is a warm-up, the
/// reps and the weight he is about to do — and after each set the rest
/// between sets. When the last set of an exercise is in, the exercise is
/// written as one log with its sets, in the order he did them, and the
/// screen moves to the next one.
///
/// What it offers for a set are **his own numbers**: the ones he wrote into
/// the exercise (or into the named day), with a chip that fills in what he
/// lifted last time. Nothing here tells him what to lift.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/body_providers.dart';
import '../../data/body_service.dart';
import '../../domain/gym.dart';
import '../../domain/training.dart';
import '../body_texts.dart';
import '../gym_actions.dart';
import '../gym_texts.dart';
import '../widgets/body_widgets.dart';
import '../widgets/gym_widgets.dart';

/// Today's session, set by set.
class GymSessionScreen extends ConsumerStatefulWidget {
  const GymSessionScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  ConsumerState<GymSessionScreen> createState() => _GymSessionScreenState();
}

class _GymSessionScreenState extends ConsumerState<GymSessionScreen> {
  /// Which exercise of the day he is on.
  int _index = 0;

  /// Which set of that exercise (0-based).
  int _set = 0;

  /// The sets he has already done of the current exercise.
  final List<SetDraft> _done = [];

  /// What he turned the steppers to for the set in front of him. Until he
  /// touches one, the set shows what the exercise (or the day's template)
  /// says – read live, so numbers that arrive from the database a moment
  /// after the screen opens are not missed.
  int? _reps;
  bool _repsEdited = false;
  double? _weight;
  bool _weightEdited = false;

  int? get _shownReps => _repsEdited ? _reps : _current?.reps;

  double? get _shownWeight => _weightEdited ? _weight : _current?.weight;

  /// When the rest started (null: he is not resting).
  DateTime? _restFrom;
  int? _restTarget;

  /// The exercises he has finished in this run (so the screen does not jump
  /// back to one that is already logged).
  final Set<String> _logged = {};
  bool _finished = false;

  /// Today's exercises, in the order the day asks for them.
  List<PlannedExercise> get _plan {
    final day = ref.read(bodyTrainingTodayProvider);
    return [for (final item in day.items) item.exercise];
  }

  PlannedExercise? get _current {
    final plan = _plan;
    if (_index < 0 || _index >= plan.length) return null;
    return plan[_index];
  }

  @override
  void initState() {
    super.initState();
    // Start on the first exercise the day has not logged yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final day = ref.read(bodyTrainingTodayProvider);
      final at = day.items.indexWhere((i) => !i.done);
      setState(() {
        _index = at < 0 ? 0 : at;
        _prime();
      });
    });
  }

  /// Back to what the exercise itself says.
  void _prime() {
    _reps = null;
    _repsEdited = false;
    _weight = null;
    _weightEdited = false;
  }

  bool get _isWarmup {
    final e = _current;
    return e != null && SessionSets.isWarmup(e, _set);
  }

  int get _total {
    final e = _current;
    return e == null ? 1 : SessionSets.countOf(e);
  }

  void _recordSet() {
    final e = _current;
    if (e == null) return;
    Fx.fire(Sfx.complete);
    setState(() {
      _done.add(SetDraft(reps: _shownReps, weight: _shownWeight, warmup: _isWarmup));
      if (_set + 1 >= _total) {
        unawaited(_finishExercise());
      } else {
        _set += 1;
        _restFrom = ref.read(bodyClockProvider)();
        _restTarget = e.restSec;
      }
    });
  }

  void _skipSet() {
    final e = _current;
    if (e == null) return;
    Fx.fire(Sfx.toggleOff);
    setState(() {
      if (_set + 1 >= _total) {
        unawaited(_finishExercise());
      } else {
        _set += 1;
      }
    });
  }

  /// Writes the exercise as one log with its sets and moves on.
  Future<void> _finishExercise() async {
    final e = _current;
    if (e == null) return;
    final sets = List<SetDraft>.of(_done);
    _done.clear();
    final plan = _plan;
    final next = _index + 1;
    if (sets.isNotEmpty) {
      final undo = await GymActions.logSets(context, ref, e, sets);
      _logged.add(e.id);
      if (mounted && undo != null) unawaited(showUndoToast(context, undo));
    }
    if (!mounted) return;
    setState(() {
      _restFrom = null;
      _restTarget = null;
      _set = 0;
      if (next >= plan.length) {
        _finished = true;
      } else {
        _index = next;
        _prime();
      }
    });
  }

  void _endRest() {
    Fx.fire(Sfx.tap);
    setState(() {
      _restFrom = null;
      _restTarget = null;
    });
  }

  void _addRest() {
    Fx.fire(Sfx.countTick);
    setState(() => _restTarget = (_restTarget ?? 0) + GymRestCard.bump);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final day = ref.watch(bodyTrainingTodayProvider);
    final plan = [for (final item in day.items) item.exercise];
    return MadarScaffold(
      title: l.gymSessionTitle,
      backdropSeed: 6.6,
      animateBackdrop:
          widget.animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      body: plan.isEmpty
          ? Center(
              child: AnimatedEmptyState(
                key: const ValueKey('gym.session.empty'),
                kind: EmptyStateKind.emptyList,
                title: l.gymSessionEmptyTitle,
                body: l.gymSessionEmptyBody,
                actionLabel: l.bodyOpenPlan,
                actionIcon: Icons.event_note_rounded,
                onAction: () => Navigator.of(context).maybePop(),
              ),
            )
          : _finished || _index >= plan.length
          ? _Finished(day: day)
          : _Runner(
              exercise: plan[_index],
              index: _index,
              count: plan.length,
              set: _set,
              total: _total,
              warmup: _isWarmup,
              done: _done,
              reps: _shownReps,
              weight: _shownWeight,
              restFrom: _restFrom,
              restTarget: _restTarget,
              onReps: (v) => setState(() {
                _reps = v;
                _repsEdited = true;
              }),
              onWeight: (v) => setState(() {
                _weight = v;
                _weightEdited = true;
              }),
              onSetDone: _recordSet,
              onSkipSet: _skipSet,
              onFinishExercise: () => unawaited(_finishExercise()),
              onEndRest: _endRest,
              onAddRest: _addRest,
            ),
    );
  }
}

/// The set in front of him.
class _Runner extends ConsumerWidget {
  const _Runner({
    required this.exercise,
    required this.index,
    required this.count,
    required this.set,
    required this.total,
    required this.warmup,
    required this.done,
    required this.reps,
    required this.weight,
    required this.restFrom,
    required this.restTarget,
    required this.onReps,
    required this.onWeight,
    required this.onSetDone,
    required this.onSkipSet,
    required this.onFinishExercise,
    required this.onEndRest,
    required this.onAddRest,
  });

  final PlannedExercise exercise;
  final int index;
  final int count;
  final int set;
  final int total;
  final bool warmup;
  final List<SetDraft> done;
  final int? reps;
  final double? weight;
  final DateTime? restFrom;
  final int? restTarget;
  final ValueChanged<int?> onReps;
  final ValueChanged<double?> onWeight;
  final VoidCallback onSetDone;
  final VoidCallback onSkipSet;
  final VoidCallback onFinishExercise;
  final VoidCallback onEndRest;
  final VoidCallback onAddRest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final gx = GymTexts.of(context);
    final text = Theme.of(context).textTheme;
    final load = ref.watch(bodyNextLoadProvider(exercise.id));
    final e = exercise;
    return ListView(
      key: const PageStorageKey('gym.session'),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
      children: [
        // Where he is: exercise i of n, set j of m.
        BodyCard(
          key: const ValueKey('gym.session.head'),
          seed: 1.2,
          child: Row(
            children: [
              GymPhotoView(photo: e.photo, name: e.name, size: 64),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.fmt.localizeDigits(
                        l.gymExerciseOf(tx.fmt.formatInt(index + 1), tx.fmt.formatInt(count)),
                      ),
                      style: text.labelMedium?.copyWith(color: t.textTertiary),
                    ),
                    const SizedBox(height: 2),
                    Semantics(
                      header: true,
                      child: Text(e.name, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: Space.xs),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        BodyPill(
                          label: tx.fmt.localizeDigits(
                            l.gymSetOf(tx.fmt.formatInt(set + 1), tx.fmt.formatInt(total)),
                          ),
                          icon: Icons.format_list_numbered_rounded,
                          color: p.training,
                          dense: true,
                        ),
                        if (warmup)
                          BodyPill(label: l.gymWarmup, icon: Icons.whatshot_outlined, color: t.gold, dense: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.s),
        if (restFrom != null)
          GymRestCard(start: restFrom!, targetSec: restTarget, onDone: onEndRest, onAdd: onAddRest)
        else
          BodyCard(
            key: const ValueKey('gym.session.set'),
            title: warmup ? l.gymWarmup : l.gymSessionTitle,
            icon: Icons.fitness_center_rounded,
            iconColor: p.training,
            seed: 2.2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: BodyStepper(
                        key: const ValueKey('gym.session.reps'),
                        label: l.bodyReps,
                        value: reps,
                        min: 1,
                        max: 300,
                        color: p.training,
                        onChanged: (v) => onReps(v?.toInt()),
                      ),
                    ),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: BodyStepper(
                        key: const ValueKey('gym.session.weight'),
                        label: l.bodyWeight,
                        value: weight,
                        step: 2.5,
                        min: 0,
                        max: 500,
                        decimals: 1,
                        unit: l.bodyUnitKg,
                        color: p.training,
                        onChanged: (v) => onWeight(v?.toDouble()),
                      ),
                    ),
                  ],
                ),
                if (load.any) ...[
                  const SizedBox(height: Space.s),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: MadarChip(
                      key: const ValueKey('gym.session.lastTime'),
                      label: l.gymLastTimeValue(gx.lastValue(load)),
                      icon: Icons.history_rounded,
                      dense: true,
                      onSelected: (_) {
                        Fx.fire(Sfx.tap);
                        onReps(load.lastReps);
                        onWeight(load.last);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: Space.m),
                MadarButton(
                  key: const ValueKey('gym.session.setDone'),
                  label: l.gymSetDone,
                  icon: Icons.check_rounded,
                  variant: MadarButtonVariant.primary,
                  onPressed: onSetDone,
                ),
                const SizedBox(height: Space.s),
                Row(
                  children: [
                    Expanded(
                      child: MadarButton(
                        key: const ValueKey('gym.session.skipSet'),
                        label: l.gymSkipSet,
                        icon: Icons.skip_next_rounded,
                        variant: MadarButtonVariant.secondary,
                        size: MadarButtonSize.small,
                        onPressed: onSkipSet,
                      ),
                    ),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: MadarButton(
                        key: const ValueKey('gym.session.finishExercise'),
                        label: index + 1 >= count ? l.gymFinishExercise : l.gymNextExercise,
                        icon: Icons.chevron_right_rounded,
                        variant: MadarButtonVariant.secondary,
                        size: MadarButtonSize.small,
                        onPressed: onFinishExercise,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: Space.s),
        // What he has already put in, this exercise.
        BodyCard(
          key: const ValueKey('gym.session.sofar'),
          title: l.gymSetsSoFar(done.length),
          icon: Icons.checklist_rounded,
          seed: 3.9,
          child: done.isEmpty
              ? BodyHint(l.gymNoSetsYetHint, icon: Icons.touch_app_outlined)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < done.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.xs),
                        child: GymSetLine(
                          index: i + 1,
                          dense: true,
                          set: LoggedSet(
                            id: '$i',
                            reps: done[i].reps,
                            weight: done[i].weight,
                            warmup: done[i].warmup,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// The end of the session.
class _Finished extends ConsumerWidget {
  const _Finished({required this.day});

  final TrainingDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, Space.xxxl),
      children: [
        BodyCard(
          key: const ValueKey('gym.session.done'),
          title: l.gymSessionDoneTitle,
          icon: Icons.local_fire_department_rounded,
          iconColor: BodyPalette(t).training,
          seed: 8.1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.gymSessionDoneBody, style: text.bodySmall?.copyWith(color: t.textSecondary)),
              const SizedBox(height: Space.m),
              for (final item in day.items)
                if (item.done)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.xs),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 16, color: t.success),
                        const SizedBox(width: Space.xs),
                        Expanded(child: Text(item.exercise.name, style: text.bodyMedium)),
                        Text(
                          tx.workoutSummary(item.latest!),
                          style: text.bodySmall?.copyWith(color: t.textSecondary),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: Space.m),
              MadarButton(
                key: const ValueKey('gym.session.leave'),
                label: l.gymLeaveSession,
                icon: Icons.chevron_right_rounded,
                variant: MadarButtonVariant.primary,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
