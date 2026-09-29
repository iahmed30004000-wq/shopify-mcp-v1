import 'package:flutter/material.dart';

import '../../../../core/db/database.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../domain/lab_flags.dart';
import '../domain/lab_series.dart';
import '../domain/record_settings.dart';
import 'record_ui.dart';

/// The record's edit sheets (the interaction kit's glass [showEditSheet]).
/// Each returns the edited values, or null when dismissed.
abstract final class RecordSheets {
  static String _clock(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String? _str(Object? v) {
    final s = (v as String?)?.trim();
    return s == null || s.isEmpty ? null : s;
  }

  // ---------------------------------------------------------------- alerts

  static Future<({String body, Severity severity, bool pinned})?> alert(
    BuildContext context, {
    HealthAlertRow? initial,
  }) async {
    final l = L10n.of(context);
    final texts = context.recordTexts;
    final values = await showEditSheet(
      context,
      title: initial == null ? l.recordAlertAdd : l.recordAlertEdit,
      subtitle: l.recordAlertSubtitle,
      icon: RecordIcons.alert,
      saveLabel: initial == null ? l.recordAdd : l.recordSave,
      initial: {
        'body': initial?.body,
        'severity': (initial?.severity ?? Severity.critical).name,
        'pinned': initial?.pinned ?? true,
      },
      fields: [
        FieldSpec.multiline('body', l.recordAlertBody, required: true, hint: l.recordAlertBodyHint, maxLength: 160),
        FieldSpec.singleSelect(
          'severity',
          l.recordAlertSeverity,
          options: [
            for (final s in Severity.values.reversed)
              SelectOption(id: s.name, label: texts.severity(s), icon: RecordIcons.severity(s)),
          ],
          required: true,
        ),
        FieldSpec.toggle('pinned', l.recordAlertPinned, hint: l.recordAlertPinnedHint),
      ],
    );
    if (values == null) return null;
    final body = _str(values['body']);
    if (body == null) return null;
    return (
      body: body,
      severity: Severity.values.byName((values['severity'] as String?) ?? Severity.critical.name),
      pinned: values['pinned'] as bool? ?? true,
    );
  }

  // ------------------------------------------------------------ conditions

  static Future<({String name, String? notes, DateTime? since, bool active})?> condition(
    BuildContext context, {
    ConditionRow? initial,
    required DateTime today,
  }) async {
    final l = L10n.of(context);
    final values = await showEditSheet(
      context,
      title: initial == null ? l.recordConditionAdd : l.recordConditionEdit,
      icon: RecordIcons.conditions,
      saveLabel: initial == null ? l.recordAdd : l.recordSave,
      initial: {
        'name': initial?.name,
        'since': initial?.since,
        'notes': initial?.notes,
        'active': initial?.active ?? true,
      },
      fields: [
        FieldSpec.text('name', l.recordConditionName, required: true, maxLength: 80),
        FieldSpec.date('since', l.recordConditionSinceLabel, lastDate: today, icon: Icons.event_outlined),
        FieldSpec.multiline('notes', l.recordNotes, maxLength: 600),
        FieldSpec.toggle('active', l.recordConditionActive),
      ],
    );
    if (values == null) return null;
    final name = _str(values['name']);
    if (name == null) return null;
    return (
      name: name,
      notes: _str(values['notes']),
      since: values['since'] as DateTime?,
      active: values['active'] as bool? ?? true,
    );
  }

  // ------------------------------------------------------------------ labs

  static Future<({String name, String? unit, double? low, double? high, String? category, String? notes})?> labTest(
    BuildContext context, {
    LabTestRow? initial,
    required List<String> categories,
  }) async {
    final l = L10n.of(context);
    final values = await showEditSheet(
      context,
      title: initial == null ? l.recordLabAddTest : l.recordLabEditTest,
      subtitle: l.recordLabTestSubtitle,
      icon: RecordIcons.labs,
      saveLabel: initial == null ? l.recordAdd : l.recordSave,
      initial: {
        'name': initial?.name,
        'unit': initial?.unit,
        'low': initial?.low,
        'high': initial?.high,
        'category': [?initial?.category],
        'notes': initial?.notes,
      },
      fields: [
        FieldSpec.text('name', l.recordLabTestName, required: true, maxLength: 60),
        FieldSpec.text('unit', l.recordLabUnit, hint: l.recordLabUnitHint, maxLength: 20),
        FieldSpec.number('low', l.recordLabLow, decimals: 3, icon: Icons.arrow_downward_rounded),
        FieldSpec.number(
          'high',
          l.recordLabHigh,
          decimals: 3,
          icon: Icons.arrow_upward_rounded,
          validator: (v, all) {
            final lo = all['low'] as num?;
            return v is num && lo != null && lo > v ? l.recordLabRangeInvalid : null;
          },
        ),
        FieldSpec.multiSelect(
          'category',
          l.recordLabCategory,
          options: [for (final c in categories) SelectOption(id: c, label: c)],
          allowAdd: true,
          maxCount: 1,
        ),
        FieldSpec.multiline('notes', l.recordNotes, maxLength: 400),
      ],
    );
    if (values == null) return null;
    final name = _str(values['name']);
    if (name == null) return null;
    final cats = (values['category'] as List?)?.cast<String>() ?? const [];
    return (
      name: name,
      unit: _str(values['unit']),
      low: (values['low'] as num?)?.toDouble(),
      high: (values['high'] as num?)?.toDouble(),
      category: cats.isEmpty ? null : cats.first.trim(),
      notes: _str(values['notes']),
    );
  }

  static Future<({DateTime date, LabValueInput input, String? note})?> reading(
    BuildContext context, {
    required LabTestRow test,
    LabReadingRow? initial,
    required DateTime today,
    int decimals = 0,
  }) async {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final texts = context.recordTexts;
    final range = texts.range(LabSeries.rangeOf(test), unit: test.unit, decimals: decimals);
    final initialValue = initial == null
        ? null
        : initial.value != null
        ? fmt.formatNumber(initial.value!, maxDecimals: 3, grouping: false)
        : initial.valueText;
    final values = await showEditSheet(
      context,
      title: initial == null ? l.recordLabAddReading : l.recordLabEditReading,
      subtitle: [BidiIsolate.isolate(test.name), ?range].join(l.recordListSeparator),
      icon: RecordIcons.labs,
      saveLabel: initial == null ? l.recordAdd : l.recordSave,
      initial: {'date': initial?.date ?? today, 'value': initialValue, 'note': initial?.note},
      fields: [
        FieldSpec.text(
          'value',
          test.unit == null ? l.recordLabValue : l.recordLabValueWithUnit(BidiIsolate.isolate(test.unit!)),
          required: true,
          hint: l.recordLabValueHint,
          autofocus: initial == null,
          maxLength: 40,
        ),
        FieldSpec.date('date', l.recordDate, required: true, lastDate: today, icon: Icons.event_outlined),
        FieldSpec.multiline('note', l.recordLabNote, maxLength: 300),
      ],
    );
    if (values == null) return null;
    final input = LabValueInput.parse(values['value'] as String?);
    if (input.isEmpty) return null;
    return (date: (values['date'] as DateTime?) ?? today, input: input, note: _str(values['note']));
  }

  // ---------------------------------------------------------- appointments

  static Future<({String title, String? doctor, String? place, DateTime at, String? notes})?> appointment(
    BuildContext context, {
    AppointmentRow? initial,
    required DateTime now,
  }) async {
    final l = L10n.of(context);
    final start = initial?.at ?? DateTime(now.year, now.month, now.day + 7, 9);
    final values = await showEditSheet(
      context,
      title: initial == null ? l.recordAppointmentAdd : l.recordAppointmentEdit,
      icon: RecordIcons.appointments,
      saveLabel: initial == null ? l.recordAdd : l.recordSave,
      initial: {
        'title': initial?.title,
        'doctor': initial?.doctor,
        'place': initial?.place,
        'date': DateTime(start.year, start.month, start.day),
        'time': _clock(start),
        'notes': initial?.notes,
      },
      fields: [
        FieldSpec.text(
          'title',
          l.recordAppointmentTitleField,
          required: true,
          hint: l.recordAppointmentTitleHint,
          maxLength: 80,
        ),
        FieldSpec.text('doctor', l.recordAppointmentDoctor, icon: RecordIcons.doctor, maxLength: 60),
        FieldSpec.text('place', l.recordAppointmentPlace, icon: RecordIcons.place, maxLength: 80),
        FieldSpec.date('date', l.recordDate, required: true, icon: Icons.event_outlined),
        FieldSpec.time('time', l.recordTime, required: true, icon: RecordIcons.time),
        FieldSpec.multiline('notes', l.recordNotes, maxLength: 600),
      ],
    );
    if (values == null) return null;
    final title = _str(values['title']);
    final date = values['date'] as DateTime?;
    if (title == null || date == null) return null;
    final parts = ((values['time'] as String?) ?? '09:00').split(':');
    final at = DateTime(date.year, date.month, date.day, int.tryParse(parts[0]) ?? 9, int.tryParse(parts[1]) ?? 0);
    return (
      title: title,
      doctor: _str(values['doctor']),
      place: _str(values['place']),
      at: at,
      notes: _str(values['notes']),
    );
  }

  // ------------------------------------------------------------- questions

  static Future<({String question, String? appointmentId, bool answered, String? answer})?> question(
    BuildContext context, {
    DoctorQuestionRow? initial,
    required List<AppointmentRow> appointments,
    String? appointmentId,
  }) async {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    const general = '_general';
    final current = initial?.appointmentId ?? appointmentId;
    final values = await showEditSheet(
      context,
      title: initial == null ? l.recordQuestionAdd : l.recordQuestionEdit,
      icon: RecordIcons.questions,
      saveLabel: initial == null ? l.recordAdd : l.recordSave,
      initial: {
        'question': initial?.question,
        'appointment': current ?? general,
        'answered': initial?.answered ?? false,
        'answer': initial?.answer,
      },
      fields: [
        FieldSpec.multiline('question', l.recordQuestionField, required: true, maxLength: 300),
        FieldSpec.singleSelect(
          'appointment',
          l.recordQuestionAppointment,
          options: [
            SelectOption(id: general, label: l.recordQuestionGeneral, icon: Icons.all_inclusive_rounded),
            for (final a in appointments)
              SelectOption(
                id: a.id,
                label:
                    '${BidiIsolate.isolate(a.title)}${l.recordListSeparator}${fmt.formatDate(a.at, style: MadarDateStyle.dayMonth)}',
                icon: RecordIcons.appointments,
              ),
          ],
        ),
        if (initial != null) ...[
          FieldSpec.toggle('answered', l.recordQuestionAnswered),
          FieldSpec.multiline('answer', l.recordQuestionAnswer, maxLength: 600),
        ],
      ],
    );
    if (values == null) return null;
    final q = _str(values['question']);
    if (q == null) return null;
    final appt = values['appointment'] as String?;
    final answer = _str(values['answer']);
    return (
      question: q,
      appointmentId: appt == null || appt == general ? null : appt,
      answered: values['answered'] as bool? ?? false,
      answer: answer,
    );
  }

  /// Just the answer (marking a question answered from a swipe).
  static Future<String?> answer(BuildContext context, DoctorQuestionRow q) async {
    final l = L10n.of(context);
    final values = await showEditSheet(
      context,
      title: l.recordQuestionMarkAnswered,
      subtitle: q.question,
      icon: Icons.question_answer_outlined,
      saveLabel: l.recordSave,
      initial: {'answer': q.answer},
      fields: [FieldSpec.multiline('answer', l.recordQuestionAnswerOptional, maxLength: 600)],
    );
    if (values == null) return null;
    return (values['answer'] as String?)?.trim() ?? '';
  }

  // -------------------------------------------------------------- settings

  static Future<RecordSettings?> settings(BuildContext context, RecordSettings current) async {
    final l = L10n.of(context);
    final texts = context.recordTexts;
    final fmt = MadarFormatter.of(context);
    final values = await showEditSheet(
      context,
      title: l.recordSettingsTitle,
      icon: RecordIcons.settings,
      saveLabel: l.recordSave,
      initial: {
        'margin': (current.borderlineMargin * 100).round(),
        'reminders': current.remindersEnabled,
        'offsets': [for (final o in current.reminderOffsets) '$o'],
      },
      fields: [
        FieldSpec.slider(
          'margin',
          l.recordSettingsMargin,
          min: 0,
          max: (LabFlags.maxMargin * 100).round(),
          labels: {
            for (final p in [0, 5, 10, 15, 20, 25]) p: fmt.formatPercent(p / 100),
          },
          icon: Icons.straighten_rounded,
        ),
        FieldSpec.toggle('reminders', l.recordSettingsReminders, hint: l.recordSettingsRemindersHint),
        FieldSpec.multiSelect(
          'offsets',
          l.recordSettingsReminderTimes,
          options: [
            for (final o in RecordSettings.offsetChoices) SelectOption(id: '$o', label: texts.reminderOffset(o)),
          ],
          maxCount: 4,
        ),
      ],
    );
    if (values == null) return null;
    return current.copyWith(
      borderlineMargin: ((values['margin'] as int?) ?? 5) / 100,
      remindersEnabled: values['reminders'] as bool? ?? true,
      reminderOffsets: [
        for (final o in (values['offsets'] as List?)?.cast<String>() ?? const <String>[]) ?int.tryParse(o),
      ],
    );
  }
}
