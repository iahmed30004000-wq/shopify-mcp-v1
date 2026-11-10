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
import '../domain/dose_scheduler.dart';
import '../domain/med_models.dart';
import '../domain/meds_settings.dart';
import '../meds_texts.dart';
import 'widgets/editor_frame.dart';
import 'widgets/meds_widgets.dart';

/// Opens the medication editor; returns the draft to save (null when
/// cancelled). [med] edits an existing medication.
Future<MedDraft?> showMedicationEditor(BuildContext context, {MedSpec? med}) =>
    showInteractionSheet<MedDraft>(context, builder: (_) => MedicationEditor(med: med));

class _SlotDraft {
  _SlotDraft(this.key, [this.anchor]);

  ClockHm key;
  TimeAnchor? anchor;
}

/// The medication editor: name, type, dose (text + amount / unit), any
/// number of daily times – fixed, or following a prayer or a meal – "taken
/// with", and under "More details" stock and refill alert, colour,
/// titration steps, course link, active flag and notes.
class MedicationEditor extends ConsumerStatefulWidget {
  const MedicationEditor({super.key, this.med, this.today});

  final MedSpec? med;

  /// The day anchored times are previewed on (defaults to today).
  final DateTime? today;

  @override
  ConsumerState<MedicationEditor> createState() => _MedicationEditorState();
}

class _MedicationEditorState extends ConsumerState<MedicationEditor> {
  late final MedSpec? _m = widget.med;
  late final _name = TextEditingController(text: _m?.name ?? '');
  late final _dose = TextEditingController(text: _m?.dose ?? '');
  late final _amount = TextEditingController(text: _num(_m?.doseAmount));
  late final _unit = TextEditingController(text: _m?.doseUnit ?? '');
  late final _withNote = TextEditingController(text: _m?.takenWithNote ?? '');
  late final _notes = TextEditingController(text: _m?.notes ?? '');
  late final _stock = TextEditingController(text: _m?.stock?.toString() ?? '');
  late final _refillAt = TextEditingController(text: _m?.refillAt?.toString() ?? '');
  late MedKind _kind = _m?.kind ?? MedKind.medication;
  late TakenWith _with = _m?.takenWith ?? TakenWith.anytime;
  late final List<_SlotDraft> _slots = [for (final s in _m?.slots ?? const <MedSlot>[]) _SlotDraft(s.key, s.anchor)];
  late List<TitrationStep> _titration = [...?_m?.titration];
  late bool _active = _m?.active ?? true;
  late int? _color = _m?.color;
  late String? _courseId = _m?.courseId;
  late bool _more = _m != null &&
      (_m.stock != null || _m.titration.isNotEmpty || _m.courseId != null || (_m.notes?.isNotEmpty ?? false));
  int? _editing;
  bool _dirty = false;
  bool _showErrors = false;

  // Titration step being added.
  bool _addingStep = false;
  DateTime? _stepFrom;
  final _stepDose = TextEditingController();
  bool _stepStop = false;

  static String _num(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.round().toString() : v.toString();
  }

  @override
  void dispose() {
    for (final c in [_name, _dose, _amount, _unit, _withNote, _notes, _stock, _refillAt, _stepDose]) {
      c.dispose();
    }
    super.dispose();
  }

  void _change(VoidCallback f) => setState(() {
    f();
    _dirty = true;
  });

  DateTime get _today {
    final DateTime n = widget.today ?? ref.read<DateTime>(medsTodayDateProvider);
    return DateTime(n.year, n.month, n.day);
  }

  DoseScheduler _resolver() => DoseScheduler(
    meds: const [],
    settings: ref.read(medsSettingsProvider).value ?? const MedsSettings(),
    prayerTime: ref.read(medsPrayerTimeProvider),
  );

  DateTime _resolve(_SlotDraft s) => _resolver().resolve(MedSlot(s.key, s.anchor), _today);

  bool get _valid => _name.text.trim().isNotEmpty;

  void _save() {
    if (!_valid) {
      setState(() => _showErrors = true);
      return;
    }
    // Anchored times keep today's resolution as their stored time.
    final used = <int>{};
    final slots = <MedSlot>[];
    final ordered = [..._slots];
    for (final s in ordered) {
      var minutes = s.anchor == null ? s.key.minutes : ClockHm(_resolve(s).hour, _resolve(s).minute).minutes;
      while (used.contains(minutes % 1440)) {
        minutes++;
      }
      used.add(minutes % 1440);
      slots.add(MedSlot(ClockHm.fromMinutes(minutes), s.anchor));
    }
    // A time-less medication "with breakfast" gets that meal as its time,
    // so every reader of the stored times (the Health score) sees it.
    if (slots.isEmpty) {
      final meal = switch (_with) {
        TakenWith.emptyStomach || TakenWith.breakfast => MealSlot.breakfast,
        TakenWith.lunch => MealSlot.lunch,
        TakenWith.dinner => MealSlot.dinner,
        TakenWith.bedtime => MealSlot.bedtime,
        _ => null,
      };
      if (meal != null && _courseId == null) {
        final settings = ref.read(medsSettingsProvider).value ?? const MedsSettings();
        final offset = _with == TakenWith.emptyStomach ? -settings.emptyStomachLead : 0;
        final anchor = TimeAnchor(AnchorBaseX.ofMeal(meal), offset);
        final at = _resolver().resolve(MedSlot(settings.mealTime(meal), anchor), _today);
        slots.add(MedSlot(ClockHm(at.hour, at.minute), anchor));
      }
    }
    Navigator.of(context).pop(
      MedDraft(
        id: _m?.id,
        name: _name.text.trim(),
        kind: _kind,
        dose: _dose.text,
        doseAmount: LocalizedNumbers.parse(_amount.text)?.toDouble(),
        doseUnit: _unit.text,
        slots: slots,
        takenWith: _with,
        takenWithNote: _with == TakenWith.other ? _withNote.text : null,
        notes: _notes.text,
        active: _active,
        stock: LocalizedNumbers.parse(_stock.text)?.round(),
        refillAt: LocalizedNumbers.parse(_refillAt.text)?.round(),
        color: _color,
        titration: _titration,
        courseId: _courseId,
      ),
    );
  }

  bool _digitsShown = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tx = MedsTexts(l, fmt);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    ref.watch(medsSettingsProvider);
    if (!_digitsShown) {
      // Stored numbers shown in the user's digits (the parser reads both).
      _digitsShown = true;
      for (final c in [_amount, _stock, _refillAt]) {
        c.text = fmt.localizeDigits(c.text);
      }
    }
    final courses = ref.watch(medCoursesProvider).value ?? const [];
    final nameError = _showErrors && !_valid ? l.medsFieldNameRequired : null;

    Widget gap([double h = Space.l]) => SizedBox(height: h);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldShell(
          label: l.medsFieldName,
          icon: Icons.medication_rounded,
          error: nameError,
          child: TextField(
            controller: _name,
            autofocus: _m == null,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: kitInputDecoration(context, hint: l.medsFieldNameHint, error: nameError != null),
            onChanged: (_) => _change(() {}),
          ),
        ),
        gap(),
        FieldShell(
          label: l.medsFieldKind,
          icon: Icons.category_rounded,
          child: MedsChoiceRow<MedKind>(
            values: MedKind.values,
            selected: _kind,
            label: tx.kind,
            icon: medKindIcon,
            onSelected: (k) => _change(() => _kind = k),
          ),
        ),
        gap(),
        FieldShell(
          label: l.medsFieldDose,
          icon: Icons.straighten_rounded,
          optional: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _dose,
                textInputAction: TextInputAction.next,
                decoration: kitInputDecoration(context, hint: l.medsFieldDoseHint),
                onChanged: (_) => _change(() {}),
              ),
              const SizedBox(height: Space.s),
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [kitNumberFormatter],
                      decoration: kitInputDecoration(context, hint: l.medsFieldAmount),
                      onChanged: (_) => _change(() {}),
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: TextField(
                      controller: _unit,
                      decoration: kitInputDecoration(context, hint: l.medsFieldUnit),
                      onChanged: (_) => _change(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final u in [
                      l.medsUnitTab,
                      l.medsUnitCap,
                      l.medsUnitMg,
                      l.medsUnitMl,
                      l.medsUnitIu,
                      l.medsUnitDrop,
                      l.medsUnitPuff,
                      l.medsUnitAmp,
                    ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: Space.xs),
                        child: KitChip(
                          label: u,
                          dense: true,
                          selected: _unit.text.trim() == u,
                          onTap: () => _change(() => _unit.text = u),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        gap(),
        FieldShell(
          label: l.medsTimes,
          icon: Icons.schedule_rounded,
          optional: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Space.s, start: Space.xxs),
                child: Text(
                  _slots.isEmpty && _courseId == null ? l.medsNoTimesAsNeeded : l.medsTimesHint,
                  style: text.bodySmall!.copyWith(color: t.textTertiary),
                ),
              ),
              for (var i = 0; i < _slots.length; i++) ...[
                _slotRow(context, tx, i),
                const SizedBox(height: Space.s),
              ],
              Row(
                children: [
                  Expanded(
                    child: MadarButton(
                      label: l.medsAddFixedTime,
                      icon: Icons.add_rounded,
                      size: MadarButtonSize.small,
                      variant: MadarButtonVariant.secondary,
                      onPressed: () => _change(() {
                        final last = _slots.isEmpty ? const ClockHm(8, 0) : _slots.last.key;
                        _slots.add(_SlotDraft(_slots.isEmpty ? last : ClockHm.fromMinutes(last.minutes + 12 * 60)));
                        _editing = _slots.length - 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: MadarButton(
                      label: l.medsAddAnchoredTime,
                      icon: Icons.wb_twilight_rounded,
                      size: MadarButtonSize.small,
                      variant: MadarButtonVariant.secondary,
                      onPressed: () => _change(() {
                        final s = _SlotDraft(const ClockHm(5, 0), const TimeAnchor(AnchorBase.fajr, 15));
                        final at = _resolve(s);
                        s.key = ClockHm(at.hour, at.minute);
                        _slots.add(s);
                        _editing = _slots.length - 1;
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        gap(),
        FieldShell(
          label: l.medsFieldTakenWith,
          icon: Icons.restaurant_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MedsChoiceRow<TakenWith>(
                values: const [
                  TakenWith.anytime,
                  TakenWith.emptyStomach,
                  TakenWith.breakfast,
                  TakenWith.lunch,
                  TakenWith.dinner,
                  TakenWith.bedtime,
                  TakenWith.perCourse,
                  TakenWith.other,
                ],
                selected: _with,
                label: tx.takenWith,
                onSelected: (w) => _change(() => _with = w),
              ),
              AnimatedSize(
                duration: context.motion(MadarMotion.medium),
                child: _with == TakenWith.other
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(top: Space.s),
                        child: TextField(
                          controller: _withNote,
                          decoration: kitInputDecoration(context, hint: l.medsFieldTakenWithNote),
                          onChanged: (_) => _change(() {}),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
        gap(Space.m),
        _MoreToggle(open: _more, onTap: () => setState(() => _more = !_more)),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.standard,
          alignment: Alignment.topCenter,
          child: _more ? _details(context, tx, courses) : const SizedBox(width: double.infinity),
        ),
      ],
    );

    return MedsEditorFrame(
      title: _m == null ? l.medsEditorNew : l.medsEditorEdit,
      subtitle: _m == null ? null : tx.name(_m.name),
      icon: medKindIcon(_kind),
      dirty: _dirty,
      canSave: _valid,
      onSave: _save,
      onRejectedSave: () => setState(() => _showErrors = true),
      body: body,
    );
  }

  Widget _slotRow(BuildContext context, MedsTexts tx, int i) {
    final l = tx.l;
    final t = context.tokens;
    final s = _slots[i];
    final open = _editing == i;
    final label = s.anchor == null
        ? tx.clock(s.key)
        : '${tx.anchor(s.anchor!)} · ${l.medsTimeToday(tx.time(_resolve(s)))}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PickerButton(
                icon: s.anchor == null
                    ? Icons.schedule_rounded
                    : (s.anchor!.base.isPrayer ? Icons.wb_twilight_rounded : Icons.restaurant_rounded),
                text: label,
                active: open,
                onTap: () => setState(() => _editing = open ? null : i),
              ),
            ),
            const SizedBox(width: Space.xs),
            MadarButton.icon(
              icon: Icons.close_rounded,
              semanticLabel: l.medsRemoveTime,
              size: MadarButtonSize.small,
              variant: MadarButtonVariant.ghost,
              sfx: Sfx.delete,
              onPressed: () => _change(() {
                _slots.removeAt(i);
                _editing = null;
              }),
            ),
          ],
        ),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.standard,
          child: !open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.only(top: Space.s),
                  child: s.anchor == null
                      ? TimeWheel(
                          value: s.key.hhmm,
                          minuteStep: 5,
                          onChanged: (v) {
                            final hm = ClockHm.tryParse(v);
                            if (hm != null && hm != s.key) _change(() => s.key = hm);
                          },
                        )
                      : Container(
                          padding: const EdgeInsetsDirectional.all(Space.m),
                          decoration: BoxDecoration(
                            color: t.glassFill,
                            borderRadius: BorderRadius.circular(t.radiusM),
                            border: Border.all(color: t.glassBorder),
                          ),
                          child: AnchorPicker(
                            anchor: s.anchor!,
                            onChanged: (a) => _change(() {
                              s.anchor = a;
                              final at = _resolve(s);
                              s.key = ClockHm(at.hour, at.minute);
                            }),
                          ),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _details(BuildContext context, MedsTexts tx, List<CourseSpec> courses) {
    final l = tx.l;
    final fmt = tx.fmt;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldShell(
            label: l.medsFieldStock,
            icon: Icons.inventory_2_rounded,
            optional: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        inputFormatters: [kitNumberFormatter],
                        decoration: kitInputDecoration(context, hint: l.medsFieldStock),
                        onChanged: (_) => _change(() {}),
                      ),
                    ),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: TextField(
                        controller: _refillAt,
                        keyboardType: TextInputType.number,
                        inputFormatters: [kitNumberFormatter],
                        decoration: kitInputDecoration(context, hint: l.medsFieldRefillAt),
                        onChanged: (_) => _change(() {}),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: Space.xs, start: Space.xxs),
                  child: Text(l.medsStockHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.medsFieldColor,
            icon: Icons.palette_rounded,
            optional: true,
            child: SwatchPicker(
              colors: CuratedPalette.colors,
              value: _color,
              onChanged: (c) => _change(() => _color = c == _color ? null : c),
            ),
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.medsTitration,
            icon: Icons.stairs_rounded,
            optional: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: Space.s, start: Space.xxs),
                  child: Text(l.medsTitrationHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                ),
                for (final (i, s) in _titration.indexed)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: Space.xs),
                    child: Row(
                      children: [
                        Icon(s.stop ? Icons.block_rounded : Icons.trending_flat_rounded, size: 16, color: t.accent),
                        const SizedBox(width: Space.s),
                        Expanded(
                          child: Text(
                            '${l.medsTitrationFrom(fmt.formatDate(s.from, style: MadarDateStyle.medium))} · '
                            '${s.stop ? l.medsTitrationStopLine : tx.dose(s.dose ?? '')}',
                            style: text.bodyMedium!.copyWith(color: t.textPrimary),
                          ),
                        ),
                        MadarButton.icon(
                          icon: Icons.close_rounded,
                          semanticLabel: l.medsDelete,
                          size: MadarButtonSize.small,
                          variant: MadarButtonVariant.ghost,
                          sfx: Sfx.delete,
                          onPressed: () => _change(() => _titration = [..._titration]..removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                AnimatedSize(
                  duration: context.motion(MadarMotion.medium),
                  child: _addingStep ? _stepForm(context, tx) : const SizedBox(width: double.infinity),
                ),
                if (!_addingStep)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: MadarButton(
                      label: l.medsTitrationAdd,
                      icon: Icons.add_rounded,
                      size: MadarButtonSize.small,
                      variant: MadarButtonVariant.ghost,
                      onPressed: () => setState(() {
                        _addingStep = true;
                        _stepFrom = _today;
                        _stepDose.clear();
                        _stepStop = false;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          if (courses.isNotEmpty) ...[
            const SizedBox(height: Space.l),
            FieldShell(
              label: l.medsFieldCourse,
              icon: Icons.vaccines_rounded,
              optional: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MedsChoiceRow<String?>(
                    values: [null, for (final c in courses) c.id],
                    selected: _courseId,
                    label: (id) => id == null ? l.medsNoCourse : courses.firstWhere((c) => c.id == id).name,
                    onSelected: (id) => _change(() => _courseId = id),
                  ),
                  if (_courseId != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: Space.xs, start: Space.xxs),
                      child: Text(l.medsCourseLinkedHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.medsFieldNotes,
            icon: Icons.notes_rounded,
            optional: true,
            child: TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              decoration: kitInputDecoration(context),
              onChanged: (_) => _change(() {}),
            ),
          ),
          const SizedBox(height: Space.l),
          Row(
            children: [
              Icon(Icons.power_settings_new_rounded, size: 18, color: t.accent),
              const SizedBox(width: Space.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.medsFieldActive, style: text.titleSmall!.copyWith(color: t.textPrimary)),
                    Text(l.medsFieldActiveHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                  ],
                ),
              ),
              GlassSwitch(
                value: _active,
                semanticLabel: l.medsFieldActive,
                onChanged: (v) => _change(() => _active = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepForm(BuildContext context, MedsTexts tx) {
    final l = tx.l;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsetsDirectional.only(top: Space.s),
      padding: const EdgeInsetsDirectional.all(Space.m),
      decoration: BoxDecoration(
        color: t.glassFill,
        borderRadius: BorderRadius.circular(t.radiusM),
        border: Border.all(color: t.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.medsTitrationStepTitle, style: text.titleSmall!.copyWith(color: t.gold)),
          InlineDatePicker(
            value: _stepFrom,
            allowClear: false,
            now: _today,
            onChanged: (d) => setState(() => _stepFrom = d),
          ),
          const SizedBox(height: Space.s),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _stepDose,
                  enabled: !_stepStop,
                  decoration: kitInputDecoration(context, hint: l.medsTitrationStepDose),
                ),
              ),
              const SizedBox(width: Space.s),
              KitChip(
                label: l.medsTitrationStop,
                icon: Icons.block_rounded,
                dense: true,
                selected: _stepStop,
                onTap: () => setState(() => _stepStop = !_stepStop),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Row(
            children: [
              Expanded(
                child: SheetButton(label: l.actionCancel, onPressed: () => setState(() => _addingStep = false)),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: SheetButton(
                  label: l.medsTitrationAdd,
                  primary: true,
                  icon: Icons.add_rounded,
                  enabled: _stepFrom != null && (_stepStop || _stepDose.text.trim().isNotEmpty),
                  onPressed: () => _change(() {
                    final step = TitrationStep(
                      from: _stepFrom!,
                      dose: _stepStop ? null : _stepDose.text.trim(),
                      stop: _stepStop,
                    );
                    _titration = TitrationStep.parseList([
                      for (final s in _titration) s.toJson(),
                      step.toJson(),
                    ]);
                    _addingStep = false;
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreToggle extends StatelessWidget {
  const _MoreToggle({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: onTap,
      sfx: open ? Sfx.sheetClose : Sfx.sheetOpen,
      semanticLabel: l.medsMore,
      toggled: open,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s),
        child: Row(
          children: [
            Text(l.medsMore, style: text.titleSmall!.copyWith(color: t.accent)),
            const SizedBox(width: Space.xs),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: context.motion(MadarMotion.short),
              child: Icon(Icons.expand_more_rounded, color: t.accent, size: 20),
            ),
            const SizedBox(width: Space.s),
            Expanded(child: Container(height: 0.8, color: t.glassBorder)),
          ],
        ),
      ),
    );
  }
}

/// Picks what a dose time follows (a prayer or a meal) and how far before
/// or after it.
class AnchorPicker extends StatelessWidget {
  const AnchorPicker({super.key, required this.anchor, required this.onChanged});

  final TimeAnchor anchor;
  final ValueChanged<TimeAnchor> onChanged;

  static const offsets = [5, 10, 15, 20, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final tx = MedsTexts(l, MadarFormatter.of(context));
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final dir = anchor.offsetMinutes.sign;
    final magnitude = anchor.offsetMinutes.abs();
    Widget label(String s) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.xs, top: Space.s),
      child: Text(s, style: text.labelMedium!.copyWith(color: t.textTertiary)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tx.anchor(anchor), style: text.titleSmall!.copyWith(color: t.textPrimary)),
        label(l.medsAnchorPrayers),
        MedsChoiceRow<AnchorBase>(
          values: [for (final b in AnchorBase.values) if (b.isPrayer) b],
          selected: anchor.base,
          label: tx.anchorPlaceTitle,
          onSelected: (b) => onChanged(TimeAnchor(b, anchor.offsetMinutes)),
        ),
        label(l.medsAnchorMeals),
        MedsChoiceRow<AnchorBase>(
          values: [for (final b in AnchorBase.values) if (b.isMeal) b],
          selected: anchor.base,
          label: tx.anchorPlaceTitle,
          onSelected: (b) => onChanged(TimeAnchor(b, anchor.offsetMinutes)),
        ),
        label(l.medsAnchorOffset),
        MedsChoiceRow<int>(
          values: const [-1, 0, 1],
          selected: dir,
          label: (v) => switch (v) {
            -1 => l.medsOffsetBefore,
            0 => l.medsOffsetAt,
            _ => l.medsOffsetAfter,
          },
          onSelected: (v) => onChanged(TimeAnchor(anchor.base, v * (magnitude == 0 ? 15 : magnitude))),
        ),
        if (dir != 0) ...[
          const SizedBox(height: Space.s),
          MedsChoiceRow<int>(
            values: offsets,
            selected: magnitude,
            label: tx.duration,
            onSelected: (m) => onChanged(TimeAnchor(anchor.base, dir * m)),
          ),
        ],
      ],
    );
  }
}
