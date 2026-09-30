import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/interaction/sheets/field_inputs.dart' show TimeWheel;
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/body_providers.dart';
import '../../data/body_service.dart';
import '../../domain/body_clock.dart';
import '../../domain/training.dart';
import '../body_texts.dart';
import '../widgets/body_widgets.dart';

/// Opens the workout log: prefilled from [exercise]'s plan (a planned
/// exercise marked done), from [log] (editing), or blank (an extra
/// workout). Completes with the draft to save, or null when dismissed.
Future<WorkoutDraft?> showWorkoutLogSheet(BuildContext context, {PlannedExercise? exercise, WorkoutLogRow? log}) =>
    showInteractionSheet<WorkoutDraft>(context, builder: (_) => WorkoutLogSheet(exercise: exercise, log: log));

/// What was actually done: sets, reps, weight, minutes, time and notes.
class WorkoutLogSheet extends ConsumerStatefulWidget {
  const WorkoutLogSheet({super.key, this.exercise, this.log});

  final PlannedExercise? exercise;
  final WorkoutLogRow? log;

  @override
  ConsumerState<WorkoutLogSheet> createState() => _WorkoutLogSheetState();
}

class _WorkoutLogSheetState extends ConsumerState<WorkoutLogSheet> {
  /// Days offered when logging a workout done earlier: today and the six
  /// before it.
  static const int _dayChoices = 7;

  late final TextEditingController _name;
  late final TextEditingController _notes;
  String? _exerciseId;
  int? _sets;
  int? _reps;
  double? _weight;
  int? _minutes;
  late DateTime _at;
  bool _timeOpen = false;
  bool _showNameError = false;

  bool get _free => widget.exercise == null && widget.log == null;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    final g = widget.log;
    final now = ref.read(bodyClockProvider)();
    _name = TextEditingController(text: g?.name ?? e?.name ?? '')..addListener(() => setState(() {}));
    _notes = TextEditingController(text: g?.notes ?? '');
    _exerciseId = g?.exerciseId ?? e?.id;
    _sets = g?.sets ?? e?.sets;
    _reps = g?.reps ?? e?.reps;
    _weight = g?.weight ?? e?.weight;
    _minutes = g?.durationMin ?? e?.durationMin;
    _at = g?.at ?? now;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  void _save() {
    if (!_valid) return;
    Navigator.of(context).pop(
      WorkoutDraft(
        exerciseId: _exerciseId,
        name: _name.text.trim(),
        at: _at,
        sets: _sets,
        reps: _reps,
        weight: _weight,
        durationMin: _minutes,
        notes: _notes.text,
      ),
    );
  }

  void _pickFromPlan(PlannedExercise e) {
    Fx.fire(Sfx.tap);
    setState(() {
      _exerciseId = e.id;
      _name.text = e.name;
      _sets = e.sets;
      _reps = e.reps;
      _weight = e.weight;
      _minutes = e.durationMin;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final e = widget.exercise;
    final plan = _free ? ref.watch(bodyExercisesProvider).where((x) => x.active).toList() : const <PlannedExercise>[];
    final volume = WorkoutMath.volume(_sets, _reps, _weight);
    final today = ref.watch(bodyTodayProvider);
    final hhmm = BodyTimes.format(_at.hour * 60 + _at.minute);
    final daysAgo = BodyDays.between(BodyDays.of(_at), today);
    return InteractionSheetFrame(
      title: widget.log != null ? l.bodyLogEditTitle : (e?.name ?? l.bodyLogTitle),
      subtitle: widget.log != null ? tx.timeOn(widget.log!.at, today) : (_free ? l.bodyLogExtraSubtitle : l.bodyLogSubtitle),
      icon: Icons.directions_run_rounded,
      footer: Row(
        children: [
          Expanded(child: SheetButton(label: l.bodyCancel, onPressed: () => Navigator.of(context).maybePop())),
          const SizedBox(width: Space.m),
          Expanded(
            flex: 2,
            child: SheetButton(
              label: widget.log != null ? l.bodySave : l.bodyLogSave,
              primary: true,
              icon: Icons.check_rounded,
              sfx: null,
              enabled: _valid,
              onPressed: _save,
              onDisabledTap: () {
                Fx.fire(Sfx.error);
                setState(() => _showNameError = true);
              },
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (e != null && tx.planSummary(e).isNotEmpty) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BodyPill(label: '${l.bodyTabPlan}: ${tx.planSummary(e)}', icon: Icons.event_note_rounded, color: p.training),
            ),
            const SizedBox(height: Space.m),
          ],
          if (_free || (widget.log != null && widget.log!.exerciseId == null)) ...[
            TextField(
              key: const ValueKey('body.log.name'),
              controller: _name,
              autofocus: _free && plan.isEmpty,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.bodyWorkoutName,
                hintText: l.bodyWorkoutNameHint,
                counterText: '',
                errorText: _showNameError ? l.bodyNameRequired : null,
                prefixIcon: Icon(Icons.directions_run_rounded, color: p.training, size: 20),
              ),
            ),
            if (plan.isNotEmpty) ...[
              const SizedBox(height: Space.s),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final x in plan.take(8))
                    MadarChip(
                      label: x.name,
                      dense: true,
                      selected: _exerciseId == x.id,
                      icon: Icons.fitness_center_rounded,
                      sfx: null,
                      onSelected: (_) => _pickFromPlan(x),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Space.l),
          ],
          Row(
            children: [
              Expanded(
                child: BodyStepper(
                  key: const ValueKey('body.log.sets'),
                  label: l.bodySets,
                  value: _sets,
                  min: 1,
                  max: 20,
                  color: p.training,
                  onChanged: (v) => setState(() => _sets = v?.toInt()),
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: BodyStepper(
                  key: const ValueKey('body.log.reps'),
                  label: l.bodyReps,
                  value: _reps,
                  min: 1,
                  max: 300,
                  color: p.training,
                  onChanged: (v) => setState(() => _reps = v?.toInt()),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Row(
            children: [
              Expanded(
                child: BodyStepper(
                  key: const ValueKey('body.log.weight'),
                  label: l.bodyWeight,
                  value: _weight,
                  step: 2.5,
                  min: 0,
                  max: 500,
                  decimals: 1,
                  unit: l.bodyUnitKg,
                  color: p.training,
                  onChanged: (v) => setState(() => _weight = v?.toDouble()),
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: BodyStepper(
                  key: const ValueKey('body.log.minutes'),
                  label: l.bodyDuration,
                  value: _minutes,
                  step: 5,
                  min: 0,
                  max: 600,
                  unit: l.bodyUnitMin,
                  color: p.training,
                  onChanged: (v) => setState(() => _minutes = v?.toInt()),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.short),
            curve: MadarMotion.standard,
            child: volume == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Space.s),
                    child: BodyHint(
                      '${l.bodyLogVolume(l.bodyKg(tx.fmt.formatNumber(volume, maxDecimals: 1)))}${tx.sep}${l.bodyVolumeHint}',
                      icon: Icons.stacked_bar_chart_rounded,
                    ),
                  ),
          ),
          const MadarDivider(ornament: false, height: Space.xl),
          MadarPressable(
            onTap: () => setState(() => _timeOpen = !_timeOpen),
            sfx: Sfx.tap,
            semanticLabel: '${l.bodyLogWhen}: ${tx.timeOn(_at, today)}',
            excludeChildSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: t.gold),
                  const SizedBox(width: Space.s),
                  Expanded(child: Text(l.bodyLogWhen, style: text.titleSmall)),
                  Text(tx.timeOn(_at, today), style: text.bodyMedium?.copyWith(color: t.textSecondary)),
                  const SizedBox(width: Space.xs),
                  AnimatedRotation(
                    turns: _timeOpen ? 0.5 : 0,
                    duration: context.motion(MadarMotion.short),
                    child: Icon(Icons.expand_more_rounded, color: t.textTertiary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.short),
            curve: MadarMotion.standard,
            child: !_timeOpen
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Space.s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ChoicePills<int>.single(
                          key: const ValueKey('body.log.day'),
                          dense: true,
                          scrollable: true,
                          options: [
                            for (var i = 0; i < _dayChoices; i++)
                              ChoiceOption(
                                value: i,
                                label: switch (i) {
                                  0 => l.bodyTabToday,
                                  1 => l.bodyYesterday,
                                  _ => tx.weekdayName(BodyDays.add(today, -i).weekday),
                                },
                              ),
                          ],
                          selected: daysAgo >= 0 && daysAgo < _dayChoices ? daysAgo : null,
                          onChanged: (i) {
                            if (i == null) return;
                            final d = BodyDays.add(today, -i);
                            setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
                          },
                        ),
                        const SizedBox(height: Space.s),
                        TimeWheel(
                          value: hhmm,
                          onChanged: (v) {
                            final m = BodyTimes.parse(v);
                            if (m == null) return;
                            setState(() => _at = DateTime(_at.year, _at.month, _at.day, 0, m));
                          },
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 4,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.bodyNotes, counterText: ''),
          ),
        ],
      ),
    );
  }
}
