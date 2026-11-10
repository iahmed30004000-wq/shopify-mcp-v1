import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/family_providers.dart';
import '../domain/birthdays.dart';
import '../domain/family_models.dart';
import '../domain/rhythm.dart';
import '../family_texts.dart';
import 'widgets/family_sheet_frame.dart';

/// Opens the person editor; returns the draft to save (null when
/// cancelled). [person] edits an existing person.
Future<PersonDraft?> showPersonSheet(BuildContext context, {PersonRow? person}) =>
    showInteractionSheet<PersonDraft>(context, builder: (_) => PersonSheet(person: person));

enum _Last { unknown, today, yesterday, weekAgo, pick }

/// The person editor: name, relation (suggestions or free text), contact
/// rhythm, when you last reached out (new people), phone, birthday and –
/// under "More details" – notes, colour and whether they orbit the Family
/// planet as a moon.
class PersonSheet extends ConsumerStatefulWidget {
  const PersonSheet({super.key, this.person});

  final PersonRow? person;

  @override
  ConsumerState<PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends ConsumerState<PersonSheet> {
  static const _rhythmPresets = [1, 2, 3, 7, 14, 30];
  static const _primaryRelations = [
    'father',
    'mother',
    'wife',
    'son',
    'daughter',
    'brother',
    'sister',
    'friend',
    'colleague',
    'partner',
  ];

  final _name = TextEditingController();
  final _relation = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final _customDays = TextEditingController();

  String? _relationKey;
  int? _rhythm;
  bool _customRhythm = false;
  bool _rhythmTouched = false;
  _Last _last = _Last.unknown;
  DateTime? _lastDate;
  DateTime? _birthday;
  bool _birthdayYearKnown = true;
  bool _birthdayOpen = false;
  int? _color;
  bool _moon = true;
  bool _more = false;
  bool _allRelations = false;
  bool _showErrors = false;
  late final PersonDraft _initial;

  bool get _editing => widget.person != null;

  DateTime get _now => ref.read(familyClockProvider)();

  @override
  void initState() {
    super.initState();
    final p = widget.person;
    if (p != null) {
      _name.text = p.name;
      _relationKey = FamilyRelations.isKey(p.relation) ? p.relation : null;
      // Free text shows as written; a suggestion key gets its label below.
      if (_relationKey == null) _relation.text = p.relation ?? '';
      _rhythm = RhythmEngine.normalizeRhythm(p.rhythmDays);
      _customRhythm = _rhythm != null && !_rhythmPresets.contains(_rhythm);
      if (_customRhythm) _customDays.text = '$_rhythm';
      _rhythmTouched = true;
      _phone.text = p.phone ?? '';
      _notes.text = p.notes ?? '';
      _birthday = p.birthday;
      _birthdayYearKnown = p.birthday == null || Birthdays.yearKnown(p.birthday!);
      _color = p.color;
      _moon = p.showAsMoon;
      _more = (p.notes ?? '').isNotEmpty;
    }
    _initial = _draft();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = widget.person;
    if (p != null && _relationKey != null && _relation.text.isEmpty) {
      _relation.text = FamilyTexts.of(context).relation(p.relation) ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _relation, _phone, _notes, _customDays]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime? get _lastContact {
    final now = _now;
    return switch (_last) {
      _Last.unknown => null,
      _Last.today => now,
      _Last.yesterday => CalendarDays.add(now, -1).add(const Duration(hours: 12)),
      _Last.weekAgo => CalendarDays.add(now, -7).add(const Duration(hours: 12)),
      _Last.pick => _lastDate?.add(const Duration(hours: 12)),
    };
  }

  PersonDraft _draft() {
    final relationText = _relation.text.trim();
    final relation = _relationKey ?? (relationText.isEmpty ? null : relationText);
    return PersonDraft(
      name: _name.text,
      relation: relation,
      rhythmDays: _rhythm,
      phone: _phone.text,
      birthday: _birthday == null ? null : Birthdays.normalize(_birthday!, yearKnown: _birthdayYearKnown),
      notes: _notes.text,
      color: _color,
      showAsMoon: _moon,
      lastContact: _editing ? null : _lastContact,
    ).normalized();
  }

  bool get _dirty => _draft() != _initial;

  void _change(VoidCallback f) => setState(f);

  void _pickRelation(String key, FamilyTexts tx) => _change(() {
    _relationKey = key;
    _relation.text = tx.relation(key)!;
    if (!_rhythmTouched) {
      _rhythm = RhythmEngine.suggestedRhythm(key);
      _customRhythm = false;
    }
  });

  void _typedRelation(String v) => _change(() {
    _relationKey = FamilyTexts.relationKeyFor(v);
    if (!_rhythmTouched && _relationKey != null) _rhythm = RhythmEngine.suggestedRhythm(_relationKey!);
  });

  void _save() {
    final d = _draft();
    if (!d.isValid) {
      setState(() => _showErrors = true);
      Fx.fire(Sfx.error);
      return;
    }
    Navigator.of(context).pop(d);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final tx = FamilyTexts.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final now = _now;
    final nameError = _showErrors && _name.text.trim().isEmpty ? l.familyFieldNameRequired : null;
    Widget gap([double h = Space.l]) => SizedBox(height: h);

    final relations = _allRelations ? FamilyRelations.keys : _primaryRelations;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldShell(
          label: l.familyFieldName,
          icon: Icons.person_rounded,
          error: nameError,
          child: TextField(
            controller: _name,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: kitInputDecoration(context, hint: l.familyFieldNameHint, error: nameError != null),
            onChanged: (_) => setState(() {}),
          ),
        ),
        gap(),
        FieldShell(
          label: l.familyFieldRelation,
          icon: Icons.diversity_1_rounded,
          optional: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _relation,
                textInputAction: TextInputAction.next,
                decoration: kitInputDecoration(context, hint: l.familyFieldRelationHint),
                onChanged: _typedRelation,
              ),
              gap(Space.s),
              AnimatedSize(
                duration: context.motion(MadarMotion.medium),
                curve: MadarMotion.standard,
                alignment: AlignmentDirectional.topStart,
                child: Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    for (final k in relations)
                      KitChip(
                        label: tx.relation(k)!,
                        selected: _relationKey == k,
                        dense: true,
                        onTap: () => _pickRelation(k, tx),
                      ),
                    KitChip(
                      label: _allRelations ? '−' : '…',
                      selected: false,
                      dense: true,
                      sfx: _allRelations ? Sfx.sheetClose : Sfx.sheetOpen,
                      onTap: () => _change(() => _allRelations = !_allRelations),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        gap(),
        FieldShell(
          label: l.familyFieldRhythm,
          icon: Icons.autorenew_rounded,
          trailing: Text(tx.rhythm(_rhythm), style: text.labelMedium!.copyWith(color: t.accent)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  KitChip(
                    label: l.familyRhythmNone,
                    selected: _rhythm == null && !_customRhythm,
                    dense: true,
                    onTap: () => _change(() {
                      _rhythm = null;
                      _customRhythm = false;
                      _rhythmTouched = true;
                    }),
                  ),
                  for (final d in _rhythmPresets)
                    KitChip(
                      label: tx.rhythm(d),
                      selected: !_customRhythm && _rhythm == d,
                      dense: true,
                      onTap: () => _change(() {
                        _rhythm = d;
                        _customRhythm = false;
                        _rhythmTouched = true;
                      }),
                    ),
                  KitChip(
                    label: l.familyRhythmCustom,
                    icon: Icons.tune_rounded,
                    selected: _customRhythm,
                    dense: true,
                    onTap: () => _change(() {
                      _customRhythm = true;
                      _rhythmTouched = true;
                      _customDays.text = '${_rhythm ?? 10}';
                      _rhythm = _rhythm ?? 10;
                    }),
                  ),
                ],
              ),
              AnimatedSize(
                duration: context.motion(MadarMotion.medium),
                curve: MadarMotion.standard,
                alignment: AlignmentDirectional.topStart,
                child: !_customRhythm
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsetsDirectional.only(top: Space.m),
                        child: Row(
                          children: [
                            Expanded(child: Text(l.familyRhythmCustomLabel, style: text.bodyMedium)),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _customDays,
                                keyboardType: TextInputType.number,
                                inputFormatters: [kitNumberFormatter, LengthLimitingTextInputFormatter(3)],
                                textAlign: TextAlign.center,
                                decoration: kitInputDecoration(context, suffix: l.familyUnitDays),
                                onChanged: (v) => _change(() {
                                  final n = LocalizedNumbers.parse(v)?.round();
                                  _rhythm = RhythmEngine.normalizeRhythm(n);
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (!_editing) ...[
          gap(),
          FieldShell(
            label: l.familyFieldLastContact,
            icon: Icons.history_rounded,
            optional: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    for (final (w, label) in [
                      (_Last.today, l.familyWhenToday),
                      (_Last.yesterday, l.familyWhenYesterday),
                      (_Last.weekAgo, l.familyWhenWeekAgo),
                      (_Last.unknown, l.familyWhenUnknown),
                      (_Last.pick, l.familyWhenPick),
                    ])
                      KitChip(
                        label: label,
                        selected: _last == w,
                        dense: true,
                        onTap: () => _change(() {
                          _last = w;
                          if (w == _Last.pick) _lastDate ??= CalendarDays.add(now, -14);
                        }),
                      ),
                  ],
                ),
                AnimatedSize(
                  duration: context.motion(MadarMotion.medium),
                  curve: MadarMotion.standard,
                  alignment: AlignmentDirectional.topStart,
                  child: _last != _Last.pick
                      ? const SizedBox(width: double.infinity)
                      : InlineDatePicker(
                          value: _lastDate,
                          allowClear: false,
                          firstDate: DateTime(now.year - 5),
                          lastDate: CalendarDays.dayOf(now),
                          now: now,
                          onChanged: (d) => _change(() => _lastDate = d),
                        ),
                ),
              ],
            ),
          ),
        ],
        gap(),
        FieldShell(
          label: l.familyFieldPhone,
          icon: Icons.call_rounded,
          optional: true,
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left,
            decoration: kitInputDecoration(context, hint: l.familyFieldPhoneHint),
            onChanged: (_) => setState(() {}),
          ),
        ),
        gap(),
        FieldShell(
          label: l.familyFieldBirthday,
          icon: Icons.cake_rounded,
          optional: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PickerButton(
                icon: Icons.cake_rounded,
                text: _birthday == null
                    ? l.familyBirthdayNone
                    : tx.birthdayDate(Birthdays.normalize(_birthday!, yearKnown: _birthdayYearKnown)),
                placeholder: _birthday == null,
                active: _birthdayOpen,
                onTap: () => _change(() => _birthdayOpen = !_birthdayOpen),
              ),
              AnimatedSize(
                duration: context.motion(MadarMotion.medium),
                curve: MadarMotion.standard,
                alignment: AlignmentDirectional.topStart,
                child: !_birthdayOpen
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InlineDatePicker(
                            value: _birthday == null
                                ? null
                                : DateTime(
                                    _birthdayYearKnown ? _birthday!.year : now.year - 30,
                                    _birthday!.month,
                                    _birthday!.day,
                                  ),
                            firstDate: DateTime(1905),
                            lastDate: CalendarDays.dayOf(now),
                            now: now,
                            onChanged: (d) => _change(() => _birthday = d),
                          ),
                          _SwitchRow(
                            label: l.familyBirthdayYearUnknown,
                            value: !_birthdayYearKnown,
                            onChanged: (v) => _change(() => _birthdayYearKnown = !v),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        gap(Space.m),
        _MoreToggle(open: _more, onTap: () => _change(() => _more = !_more)),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.standard,
          alignment: AlignmentDirectional.topStart,
          child: !_more
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    gap(Space.m),
                    FieldShell(
                      label: l.familyFieldNotes,
                      icon: Icons.sticky_note_2_rounded,
                      optional: true,
                      child: TextField(
                        controller: _notes,
                        minLines: 3,
                        maxLines: 8,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: kitInputDecoration(context, hint: l.familyFieldNotesHint),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    gap(),
                    FieldShell(
                      label: l.familyFieldColor,
                      icon: Icons.palette_rounded,
                      optional: true,
                      child: SwatchPicker(
                        colors: CuratedPalette.colors,
                        value: _color,
                        onChanged: (c) => _change(() => _color = c),
                      ),
                    ),
                    gap(),
                    _SwitchRow(
                      label: l.familyFieldMoon,
                      hint: l.familyFieldMoonHint,
                      icon: Icons.brightness_3_rounded,
                      value: _moon,
                      onChanged: (v) => _change(() => _moon = v),
                    ),
                  ],
                ),
        ),
      ],
    );

    final name = _name.text.trim();
    return FamilySheetFrame(
      title: _editing ? l.familyEditTitle(tx.name(widget.person!.name)) : l.familyNewPerson,
      subtitle: _editing ? null : l.familyNewPersonSubtitle,
      icon: _editing ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
      body: body,
      dirty: _dirty,
      canSave: name.isNotEmpty,
      onRejectedSave: () => setState(() => _showErrors = true),
      saveLabel: l.familySave,
      onSave: _save,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged, this.hint, this.icon});

  final String label;
  final String? hint;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.s),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: t.accent), const SizedBox(width: Space.s)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodyLarge!.copyWith(color: t.textPrimary)),
                if (hint != null) Text(hint!, style: text.bodySmall!.copyWith(color: t.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: Space.s),
          GlassSwitch(value: value, onChanged: onChanged, semanticLabel: label),
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
    final label = open ? l.familyFewerDetails : l.familyMoreDetails;
    return MadarPressable(
      onTap: onTap,
      sfx: open ? Sfx.sheetClose : Sfx.sheetOpen,
      semanticLabel: label,
      toggled: open,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s),
        child: Row(
          children: [
            Text(label, style: text.titleSmall!.copyWith(color: t.accent)),
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
