import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/interaction/sheets/field_inputs.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/meds_providers.dart';
import '../data/meds_service.dart';
import '../domain/med_models.dart';
import '../meds_texts.dart';
import 'widgets/editor_frame.dart';
import 'widgets/meds_widgets.dart';

/// Opens the course editor; returns the draft to save.
Future<CourseDraft?> showCourseEditor(BuildContext context, {CourseSpec? course}) =>
    showInteractionSheet<CourseDraft>(context, builder: (_) => CourseEditor(course: course));

class _PhaseDraft {
  _PhaseDraft({this.frequency = CourseFrequency.daily, this.interval = 1, this.count = 10, String dose = ''})
    : dose = TextEditingController(text: dose);

  factory _PhaseDraft.of(CoursePhase p) =>
      _PhaseDraft(frequency: p.frequency, interval: p.interval, count: p.count, dose: p.dose ?? '');

  CourseFrequency frequency;
  int interval;

  /// null = ongoing (only the last phase).
  int? count;
  final TextEditingController dose;

  CoursePhase toPhase() => CoursePhase(
    frequency: frequency,
    interval: interval,
    count: count,
    dose: dose.text.trim().isEmpty ? null : dose.text.trim(),
  );
}

/// Name, medication, start date and phases (frequency × interval, number of
/// doses or ongoing, the phase's dose), notes and active flag.
class CourseEditor extends ConsumerStatefulWidget {
  const CourseEditor({super.key, this.course, this.today});

  final CourseSpec? course;
  final DateTime? today;

  @override
  ConsumerState<CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends ConsumerState<CourseEditor> {
  late final CourseSpec? _c = widget.course;
  late final _name = TextEditingController(text: _c?.name ?? '');
  late final _notes = TextEditingController(text: _c?.notes ?? '');
  late String? _medId = _c?.medicationId;
  late DateTime _start = _c?.startDate ?? _today;
  late bool _active = _c?.active ?? true;
  late final List<_PhaseDraft> _phases = _c == null || _c.phases.isEmpty
      ? [_PhaseDraft()]
      : [for (final p in _c.phases) _PhaseDraft.of(p)];
  bool _pickingDate = false;
  bool _dirty = false;
  bool _showErrors = false;

  DateTime get _today {
    final DateTime n = widget.today ?? ref.read<DateTime>(medsTodayDateProvider);
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    for (final p in _phases) {
      p.dose.dispose();
    }
    super.dispose();
  }

  void _change(VoidCallback f) => setState(() {
    f();
    _dirty = true;
  });

  bool get _valid => _name.text.trim().isNotEmpty && _phases.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tx = MedsTexts(l, fmt);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final meds = ref.watch(medsListProvider).value ?? const [];
    final nameError = _showErrors && _name.text.trim().isEmpty ? l.medsCourseNameRequired : null;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldShell(
          label: l.medsCourseName,
          icon: Icons.vaccines_rounded,
          error: nameError,
          child: TextField(
            controller: _name,
            autofocus: _c == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: kitInputDecoration(context, error: nameError != null),
            onChanged: (_) => _change(() {}),
          ),
        ),
        const SizedBox(height: Space.l),
        FieldShell(
          label: l.medsCourseMed,
          icon: Icons.medication_rounded,
          optional: true,
          child: meds.isEmpty
              ? Text(l.medsCourseNoMed, style: text.bodySmall!.copyWith(color: t.textTertiary))
              : MedsChoiceRow<String?>(
                  values: [null, for (final m in meds) m.id],
                  selected: _medId,
                  label: (id) => id == null ? l.medsNoCourse : meds.firstWhere((m) => m.id == id).name,
                  icon: (id) => id == null ? null : medKindIcon(meds.firstWhere((m) => m.id == id).kind),
                  onSelected: (id) => _change(() => _medId = id),
                ),
        ),
        const SizedBox(height: Space.l),
        FieldShell(
          label: l.medsCourseStart,
          icon: Icons.event_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PickerButton(
                icon: Icons.event_rounded,
                text: fmt.formatDate(_start, style: MadarDateStyle.full),
                active: _pickingDate,
                onTap: () => setState(() => _pickingDate = !_pickingDate),
              ),
              AnimatedSize(
                duration: context.motion(MadarMotion.medium),
                child: _pickingDate
                    ? InlineDatePicker(
                        value: _start,
                        allowClear: false,
                        now: _today,
                        onChanged: (d) => _change(() {
                          if (d != null) _start = d;
                          _pickingDate = false;
                        }),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.l),
        FieldShell(
          label: l.medsCoursePhases,
          icon: Icons.stacked_line_chart_rounded,
          error: _showErrors && _phases.isEmpty ? l.medsCourseNeedsPhase : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _phases.length; i++) ...[
                _phaseCard(context, tx, i),
                const SizedBox(height: Space.s),
              ],
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MadarButton(
                  label: l.medsCourseAddPhase,
                  icon: Icons.add_rounded,
                  size: MadarButtonSize.small,
                  variant: MadarButtonVariant.secondary,
                  onPressed: () => _change(() {
                    // Only the last phase may be ongoing.
                    for (final p in _phases) {
                      p.count ??= 4;
                    }
                    final prev = _phases.isEmpty ? null : _phases.last.frequency;
                    _phases.add(
                      _PhaseDraft(
                        frequency: switch (prev) {
                          CourseFrequency.daily => CourseFrequency.weekly,
                          CourseFrequency.weekly || CourseFrequency.monthly => CourseFrequency.monthly,
                          null => CourseFrequency.daily,
                        },
                        count: 4,
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.l),
        FieldShell(
          label: l.medsFieldNotes,
          icon: Icons.notes_rounded,
          optional: true,
          child: TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 5,
            decoration: kitInputDecoration(context),
            onChanged: (_) => _change(() {}),
          ),
        ),
        const SizedBox(height: Space.l),
        Row(
          children: [
            Icon(Icons.power_settings_new_rounded, size: 18, color: t.accent),
            const SizedBox(width: Space.s),
            Expanded(child: Text(l.medsCourseActive, style: text.titleSmall!.copyWith(color: t.textPrimary))),
            GlassSwitch(value: _active, semanticLabel: l.medsCourseActive, onChanged: (v) => _change(() => _active = v)),
          ],
        ),
      ],
    );

    return MedsEditorFrame(
      title: _c == null ? l.medsCourseEditorNew : l.medsCourseEditorEdit,
      icon: Icons.vaccines_rounded,
      dirty: _dirty,
      canSave: _valid,
      onRejectedSave: () => setState(() => _showErrors = true),
      onSave: () => Navigator.of(context).pop(
        CourseDraft(
          id: _c?.id,
          name: _name.text.trim(),
          startDate: _start,
          medicationId: _medId,
          phases: [for (final p in _phases) p.toPhase()],
          notes: _notes.text,
          active: _active,
        ),
      ),
      body: body,
    );
  }

  Widget _phaseCard(BuildContext context, MedsTexts tx, int i) {
    final l = tx.l;
    final fmt = tx.fmt;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final p = _phases[i];
    final last = i == _phases.length - 1;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.s, Space.m),
      decoration: BoxDecoration(
        color: t.glassFill,
        borderRadius: BorderRadius.circular(t.radiusM),
        border: Border.all(color: t.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(l.medsCoursePhaseN(fmt.formatInt(i + 1)), style: text.titleSmall!.copyWith(color: t.gold)),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(
                  tx.phase(p.toPhase()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(color: t.textSecondary),
                ),
              ),
              if (_phases.length > 1)
                MadarButton.icon(
                  icon: Icons.close_rounded,
                  semanticLabel: l.medsDelete,
                  size: MadarButtonSize.small,
                  variant: MadarButtonVariant.ghost,
                  sfx: Sfx.delete,
                  onPressed: () => _change(() => _phases.removeAt(i).dose.dispose()),
                ),
            ],
          ),
          const SizedBox(height: Space.s),
          MedsChoiceRow<CourseFrequency>(
            values: CourseFrequency.values,
            selected: p.frequency,
            label: (f) => switch (f) {
              CourseFrequency.daily => l.medsFreqDaily,
              CourseFrequency.weekly => l.medsFreqWeekly,
              CourseFrequency.monthly => l.medsFreqMonthly,
            },
            onSelected: (f) => _change(() => p.frequency = f),
          ),
          const SizedBox(height: Space.m),
          Wrap(
            spacing: Space.m,
            runSpacing: Space.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.medsPhaseInterval, style: text.labelLarge!.copyWith(color: t.textSecondary)),
                  const SizedBox(width: Space.s),
                  MedsStepper(
                    value: p.interval,
                    min: 1,
                    max: 52,
                    label: l.medsPhaseInterval,
                    onChanged: (v) => _change(() => p.interval = v),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.medsPhaseCount, style: text.labelLarge!.copyWith(color: t.textSecondary)),
                  const SizedBox(width: Space.s),
                  if (p.count != null)
                    MedsStepper(
                      value: p.count!,
                      min: 1,
                      max: 999,
                      label: l.medsPhaseCount,
                      onChanged: (v) => _change(() => p.count = v),
                    ),
                  if (last) ...[
                    const SizedBox(width: Space.s),
                    KitChip(
                      label: l.medsPhaseOngoing,
                      dense: true,
                      icon: Icons.all_inclusive_rounded,
                      selected: p.count == null,
                      onTap: () => _change(() => p.count = p.count == null ? 4 : null),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: p.dose,
            decoration: kitInputDecoration(context, hint: l.medsPhaseDose),
            onChanged: (_) => _change(() {}),
          ),
        ],
      ),
    );
  }
}
