import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/body_service.dart';
import '../../domain/body_week.dart';
import '../body_texts.dart';
import '../widgets/body_widgets.dart';

/// Opens the exercise sheet (new, or editing [exercise]). Completes with
/// the draft to save, or null when dismissed.
Future<ExerciseDraft?> showExerciseSheet(BuildContext context, {ExerciseRow? exercise}) =>
    showInteractionSheet<ExerciseDraft>(context, builder: (_) => ExerciseSheet(exercise: exercise));

/// Name, training days (a Saturday-first week in Arabic), sets / reps /
/// weight / minutes aimed for each time, and notes.
class ExerciseSheet extends ConsumerStatefulWidget {
  const ExerciseSheet({super.key, this.exercise});

  final ExerciseRow? exercise;

  @override
  ConsumerState<ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends ConsumerState<ExerciseSheet> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late Set<int> _days;
  int? _sets;
  int? _reps;
  double? _weight;
  int? _minutes;
  bool _showNameError = false;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    _name = TextEditingController(text: e?.name ?? '')..addListener(_onName);
    _notes = TextEditingController(text: e?.notes ?? '');
    _days = {...?e?.weekdays};
    _sets = e?.sets;
    _reps = e?.reps;
    _weight = e?.weight;
    _minutes = e?.durationMin;
  }

  void _onName() {
    if (_showNameError && _name.text.trim().isNotEmpty) setState(() => _showNameError = false);
    setState(() {});
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
    Fx.fire(Sfx.complete);
    Navigator.of(context).pop(
      ExerciseDraft(
        name: _name.text.trim(),
        weekdays: BodyWeek.normalize(_days),
        sets: _sets,
        reps: _reps,
        weight: _weight,
        durationMin: _minutes,
        notes: _notes.text,
        active: widget.exercise?.active ?? true,
      ),
    );
  }

  void _toggleDay(int d) {
    setState(() => _days.contains(d) ? _days.remove(d) : _days.add(d));
    Fx.fire(_days.contains(d) ? Sfx.toggleOn : Sfx.toggleOff);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final start = BodyWeek.startFor(tx.fmt.languageCode);
    final ordered = BodyWeek.inDisplayOrder(_days, start);
    return InteractionSheetFrame(
      title: widget.exercise == null ? l.bodyAddExercise : l.bodyEditExercise,
      subtitle: l.bodyExerciseSubtitle,
      icon: Icons.fitness_center_rounded,
      footer: Row(
        children: [
          Expanded(child: SheetButton(label: l.bodyCancel, onPressed: () => Navigator.of(context).maybePop())),
          const SizedBox(width: Space.m),
          Expanded(
            flex: 2,
            child: SheetButton(
              label: l.bodySave,
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
          TextField(
            key: const ValueKey('body.exercise.name'),
            controller: _name,
            autofocus: widget.exercise == null,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l.bodyExerciseName,
              hintText: l.bodyExerciseNameHint,
              counterText: '',
              errorText: _showNameError ? l.bodyNameRequired : null,
              prefixIcon: Icon(Icons.fitness_center_rounded, color: p.training, size: 20),
            ),
          ),
          const SizedBox(height: Space.l),
          Row(
            children: [
              Icon(Icons.event_repeat_rounded, size: 18, color: t.gold),
              const SizedBox(width: Space.s),
              Expanded(child: Text(l.bodyWeekdays, style: text.titleSmall)),
              MadarButton(
                label: _days.length == 7 ? l.bodyClearDays : l.bodyEveryDay,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: _days.length == 7 ? Sfx.toggleOff : Sfx.toggleOn,
                onPressed: () => setState(() => _days = _days.length == 7 ? {} : BodyWeek.all.toSet()),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in BodyWeek.ordered(start))
                _DayToggle(
                  letter: tx.weekdayShort(d),
                  name: tx.weekdayName(d),
                  selected: _days.contains(d),
                  color: p.training,
                  onTap: () => _toggleDay(d),
                ),
            ],
          ),
          const SizedBox(height: Space.s),
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.short),
            child: Text(
              ordered.isEmpty
                  ? l.bodyNoDays
                  : '${tx.weekdayList(ordered)}${tx.sep}${tx.fmt.localizeDigits(l.bodyPerWeek(ordered.length, tx.fmt.formatInt(ordered.length)))}',
              key: ValueKey(ordered.join(',')),
              style: text.bodySmall?.copyWith(color: ordered.isEmpty ? t.textTertiary : t.textSecondary),
            ),
          ),
          const MadarDivider(ornament: false, height: Space.xl),
          Row(
            children: [
              Icon(Icons.track_changes_rounded, size: 18, color: t.gold),
              const SizedBox(width: Space.s),
              Text(l.bodyTarget, style: text.titleSmall),
            ],
          ),
          const SizedBox(height: Space.s),
          Row(
            children: [
              Expanded(
                child: BodyStepper(
                  key: const ValueKey('body.exercise.sets'),
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
                  key: const ValueKey('body.exercise.reps'),
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
                  key: const ValueKey('body.exercise.weight'),
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
                  key: const ValueKey('body.exercise.minutes'),
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
          const SizedBox(height: Space.l),
          TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 4,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.bodyNotes, hintText: l.bodyNotesHint, counterText: ''),
          ),
        ],
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({required this.letter, required this.name, required this.selected, required this.color, required this.onTap});

  final String letter;
  final String name;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: onTap,
      sfx: null,
      semanticLabel: name,
      toggled: selected,
      excludeChildSemantics: true,
      pressScale: 0.9,
      child: SpringBuilder(
        value: selected ? 1 : 0,
        spring: MadarMotion.bouncy,
        builder: (context, v, _) {
          final f = v.clamp(0.0, 1.0);
          return Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(t.glassFill, color, f * 0.92),
              border: Border.all(color: Color.lerp(t.glassBorder, color, f)!, width: 1.4),
              boxShadow: f > 0.5 ? [BoxShadow(color: color.withValues(alpha: 0.35 * f), blurRadius: 12)] : null,
            ),
            child: Transform.scale(
              scale: 0.92 + 0.08 * v,
              child: Text(
                letter,
                maxLines: 1,
                style: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Color.lerp(t.textSecondary, t.isDark ? t.space0 : t.textOnAccent, f),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
