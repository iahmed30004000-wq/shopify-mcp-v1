import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart';
import '../../../core/motion/motion_kit.dart';
import '../data/family_providers.dart';
import '../domain/family_models.dart';
import '../domain/rhythm.dart';
import '../family_texts.dart';
import 'widgets/family_sheet_frame.dart';
import 'widgets/family_widgets.dart';

/// Opens the "contacted" sheet for [name]: how (call / visit / message /
/// other), when (now by default; earlier today, yesterday or any past date
/// and time) and an optional note. Returns the draft to log (null when
/// cancelled). [initial] edits an existing contact.
Future<ContactDraft?> showContactedSheet(
  BuildContext context, {
  required String name,
  ContactDraft? initial,
  ContactChannel? channel,
}) => showInteractionSheet<ContactDraft>(
  context,
  builder: (_) => ContactedSheet(name: name, initial: initial, channel: channel),
);

enum _When { now, earlierToday, yesterday, pick }

/// The "contacted" sheet (see [showContactedSheet]).
class ContactedSheet extends ConsumerStatefulWidget {
  const ContactedSheet({super.key, required this.name, this.initial, this.channel});

  final String name;

  /// An existing contact to edit.
  final ContactDraft? initial;

  /// Preselected channel for a new contact (default: call).
  final ContactChannel? channel;

  @override
  ConsumerState<ContactedSheet> createState() => _ContactedSheetState();
}

class _ContactedSheetState extends ConsumerState<ContactedSheet> {
  late ContactChannel _channel;
  late _When _when;
  late DateTime _date;
  late String _time;
  bool _timeTouched = false;
  final _note = TextEditingController();
  bool _dirty = false;

  DateTime get _now => ref.read(familyClockProvider)();

  @override
  void initState() {
    super.initState();
    final now = _now;
    final initial = widget.initial;
    _channel = initial?.channel ?? widget.channel ?? ContactChannel.call;
    _note.text = initial?.note ?? '';
    if (initial == null) {
      _when = _When.now;
      _date = CalendarDays.dayOf(now);
      final earlier = now.subtract(const Duration(hours: 1));
      _time = CalendarDays.sameDay(earlier, now)
          ? ClockTime.format(earlier.hour, earlier.minute - earlier.minute % 5)
          : ClockTime.format(0, 0);
    } else {
      final at = initial.at;
      _date = CalendarDays.dayOf(at);
      _time = ClockTime.format(at.hour, at.minute);
      final days = CalendarDays.between(at, now);
      _when = days == 0 ? _When.earlierToday : (days == 1 ? _When.yesterday : _When.pick);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime get _at {
    final now = _now;
    final day = switch (_when) {
      _When.now => null,
      _When.earlierToday => CalendarDays.dayOf(now),
      _When.yesterday => CalendarDays.add(now, -1),
      _When.pick => _date,
    };
    if (day == null) return now;
    final parts = _time.split(':');
    return DateTime(day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Switching "when" keeps a time the user set; otherwise a natural one:
  /// an hour ago today, the evening on another day.
  void _pickWhen(_When w) {
    _when = w;
    if (_timeTouched || widget.initial != null) return;
    final now = _now;
    if (w == _When.earlierToday) {
      final earlier = now.subtract(const Duration(hours: 1));
      _time = CalendarDays.sameDay(earlier, now)
          ? ClockTime.format(earlier.hour, earlier.minute - earlier.minute % 5)
          : ClockTime.format(0, 0);
    } else if (w == _When.yesterday || w == _When.pick) {
      _time = ClockTime.format(20, 0);
    }
  }

  bool get _future => _when != _When.now && _at.isAfter(_now);

  void _change(VoidCallback f) => setState(() {
    f();
    _dirty = true;
  });

  void _save() {
    if (_future) return;
    final note = _note.text.trim();
    Navigator.of(context).pop(ContactDraft(channel: _channel, at: _at, note: note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final tx = FamilyTexts.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final now = _now;
    final future = _future;
    Widget gap([double h = Space.l]) => SizedBox(height: h);

    final whenLabel = switch (_when) {
      _When.now => l.familyWhenNow,
      _ => tx.when(_at, now),
    };

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldShell(
          label: l.familyFieldChannel,
          icon: Icons.forum_rounded,
          child: Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final c in ContactChannel.values)
                KitChip(
                  label: tx.channel(c),
                  icon: channelIcon(c),
                  selected: _channel == c,
                  onTap: () => _change(() => _channel = c),
                ),
            ],
          ),
        ),
        gap(),
        FieldShell(
          label: l.familyFieldWhen,
          icon: Icons.schedule_rounded,
          error: future ? l.familyFutureError : null,
          trailing: Text(whenLabel, style: text.labelMedium!.copyWith(color: future ? t.danger : t.textSecondary)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final (w, label) in [
                    if (widget.initial == null) (_When.now, l.familyWhenNow),
                    (_When.earlierToday, widget.initial == null ? l.familyWhenEarlierToday : l.familyWhenToday),
                    (_When.yesterday, l.familyWhenYesterday),
                    (_When.pick, l.familyWhenPick),
                  ])
                    KitChip(label: label, selected: _when == w, dense: true, onTap: () => _change(() => _pickWhen(w))),
                ],
              ),
              AnimatedSize(
                duration: context.motion(MadarMotion.medium),
                curve: MadarMotion.standard,
                alignment: AlignmentDirectional.topStart,
                child: _when == _When.now
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_when == _When.pick) ...[
                            gap(Space.m),
                            InlineDatePicker(
                              value: _date,
                              allowClear: false,
                              lastDate: CalendarDays.dayOf(now),
                              firstDate: DateTime(now.year - 5),
                              now: now,
                              onChanged: (d) {
                                if (d != null) _change(() => _date = CalendarDays.dayOf(d));
                              },
                            ),
                          ],
                          gap(Space.m),
                          TimeWheel(
                            value: _time,
                            minuteStep: 5,
                            onChanged: (v) => _change(() {
                              _time = v;
                              _timeTouched = true;
                            }),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        gap(),
        FieldShell(
          label: l.familyFieldNote,
          icon: Icons.edit_note_rounded,
          optional: true,
          child: TextField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: kitInputDecoration(context, hint: l.familyFieldNoteHint),
            onChanged: (_) => _dirty = true,
          ),
        ),
      ],
    );

    return FamilySheetFrame(
      title: widget.initial == null ? l.familyContactedTitle(tx.name(widget.name)) : l.familyEditContactTitle,
      subtitle: widget.initial == null ? l.familyContactedSubtitle : tx.name(widget.name),
      icon: Icons.favorite_rounded,
      body: body,
      dirty: _dirty && widget.initial != null,
      canSave: !future,
      saveLabel: widget.initial == null ? l.familyLog : l.familySave,
      saveIcon: widget.initial == null ? Icons.favorite_rounded : Icons.check_rounded,
      onSave: _save,
    );
  }
}
