/// The chat's edit sheets: how he corrects **one** piece before it is
/// written, and nothing more.
///
/// Two rules live here, and they are why this file exists at all:
///
/// * **an edit changes a value, never the kind.** Every sheet hands back a
///   new [DayChatFact] of the same class the reader produced, so the health
///   guard's verdict (a dose or a diagnosis is only ever his own note)
///   cannot be edited away;
/// * **the sheet validates, because the engine no longer can.**
///   `DayChatService.applyEdited` clears the piece's gaps wholesale, so by
///   the time the fact reaches the service nothing is left to refuse it: a
///   pain score is bounded 0–10 here, a mood 1–5, a tracker value by the
///   **field's own** `min`/`max`, and an amount has to be a number at all.
///   Every bound is declared on the [FieldSpec], so the sheet refuses to
///   save and says why, in his language.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart' show repositoriesProvider;
import '../../../core/domain/enums.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../custom_modules/data/custom_modules_providers.dart';
import '../../custom_modules/domain/module_schema.dart';
import '../../family/family_texts.dart' show FamilyTexts;
import '../../family/presentation/widgets/family_widgets.dart' show channelIcon;
import '../../prayer_tracker/domain/tracker_prayers.dart';
import '../../prayer_tracker/presentation/tracker_labels.dart' show TrackerLabels;
import '../domain/day_chat_piece.dart';

/// What one edit produced: a new fact, and – when he settled a piece the
/// reader could not place at all – the kind it has become.
@immutable
class DayChatEditResult {
  const DayChatEditResult(this.fact, {this.kind});

  final DayChatFact fact;

  /// Set only where settling the gap also settles **where** the piece
  /// lands: a number that found its tracker stops being a bare `sign`.
  final DayChatKind? kind;
}

/// There is no tracker of his to file a number in at all (the card's own
/// «اعمللي متابعة جديدة من هاي» is the way out).
class DayChatNoTrackers implements Exception {
  const DayChatNoTrackers();

  @override
  String toString() => 'DayChatNoTrackers';
}

/// The pain score's bounds – the same 0–10 the wellbeing screens use.
const int kDayChatPainMin = 0;
const int kDayChatPainMax = 10;

/// The mood's bounds (1–5, as `MoodFact` documents).
const int kDayChatMoodMin = 1;
const int kDayChatMoodMax = 5;

/// Millilitres of water one sip can plausibly be.
const int kDayChatWaterMax = 5000;

/// Opens the sheet that fits [piece] and gives back what he settled, or
/// null when he cancelled (then nothing at all changes).
///
/// Nothing is written here: the caller puts the result back on the card and
/// only his tap on «سجّلها» writes it.
Future<DayChatEditResult?> showDayChatEditSheet(BuildContext context, WidgetRef ref, DayChatPiece piece) async {
  final fact = piece.fact;
  return switch (fact) {
    MoneyFact() => _money(context, fact),
    MealFact() => _meal(context, fact),
    WorkoutFact() => _workout(context, fact),
    WaterFact() => _water(context, fact),
    PainFact() => _pain(context, fact),
    MoodFact() => _mood(context, fact),
    PrayerFact() => _prayer(context, fact),
    TaskDoneFact() => _taskDone(context, ref, fact),
    TaskTodoFact() => _todo(context, fact),
    ContactFact() => _contact(context, fact),
    ModuleFact() => _module(context, ref, piece, fact),
    NoteFact() => _note(context, fact),
    // His own words, read again from scratch: that is the reword sheet, not
    // an edit of a fact that does not exist.
    UnreadFact() => Future.value(null),
  };
}

/// The sentence he wants to say another way (null when he cancelled or
/// left it as it was).
Future<String?> showDayChatRewordSheet(BuildContext context, DayChatPiece piece) async {
  final l = L10n.of(context);
  final values = await showEditSheet(
    context,
    title: l.dayChatCorrectTitle,
    icon: Icons.edit_note_rounded,
    fields: [
      FieldSpec.multiline('text', l.dayChatCorrectField, required: true, maxLength: 240),
    ],
    initial: {'text': piece.text},
  );
  final text = (values?['text'] as String?)?.trim();
  if (text == null || text.isEmpty || text == piece.text.trim()) return null;
  return text;
}

/// What a new tracker built out of a bare number should be.
@immutable
class DayChatTrackerDraft {
  const DayChatTrackerDraft({required this.name, required this.fieldLabel, this.unit, this.min, this.max});

  final String name;
  final String fieldLabel;
  final String? unit;
  final num? min;
  final num? max;

  /// The tracker as the builder's own service stores it: one number field,
  /// on the Health world (where a tracked sign belongs), its colour the
  /// builder's default.
  ModuleDefinition definition() => ModuleDefinition(
    id: '',
    name: name,
    colorArgb: 0xFF4F8DF5,
    planetKey: 'health',
    fields: [
      ModuleField(
        id: 'f1',
        label: fieldLabel,
        type: FieldType.number,
        unit: unit,
        min: min,
        max: max,
        decimals: 2,
      ),
    ],
  );
}

/// «اعمللي متابعة جديدة من هاي»: the tracker he wants built for a number
/// that has none. Null when he cancelled.
Future<DayChatTrackerDraft?> showDayChatTrackerSheet(BuildContext context, ModuleFact fact) async {
  final l = L10n.of(context);
  final value = fact.value;
  final number = value is num ? value : null;
  final values = await showEditSheet(
    context,
    title: l.dayChatTrackerTitle,
    icon: Icons.insights_rounded,
    fields: [
      FieldSpec.text('name', l.dayChatTrackerName, required: true, maxLength: 40, icon: Icons.label_outline_rounded),
      FieldSpec.text('field', l.dayChatTrackerField, required: true, maxLength: 40, icon: Icons.numbers_rounded),
      FieldSpec.text('unit', l.dayChatTrackerUnit, maxLength: 12, icon: Icons.straighten_rounded),
      FieldSpec.number('min', l.dayChatTrackerMin, decimals: 2, icon: Icons.south_rounded),
      FieldSpec.number('max', l.dayChatTrackerMax, decimals: 2, icon: Icons.north_rounded),
    ],
    initial: {
      'name': fact.moduleName,
      'field': l.dayChatTrackerReading,
      // His own number has to fit inside the bounds the tracker is born
      // with, or the very piece that created the tracker could not be
      // filed into it.
      if (number != null) 'min': 0,
      if (number != null) 'max': _roomAbove(number),
    },
  );
  if (values == null) return null;
  final name = (values['name'] as String?)?.trim();
  final field = (values['field'] as String?)?.trim();
  if (name == null || name.isEmpty || field == null || field.isEmpty) return null;
  final min = (values['min'] as num?)?.toDouble();
  final max = (values['max'] as num?)?.toDouble();
  return DayChatTrackerDraft(
    name: name,
    fieldLabel: field,
    unit: (values['unit'] as String?)?.trim().isEmpty ?? true ? null : (values['unit'] as String).trim(),
    min: min,
    max: max == null || (min != null && max <= min) ? null : max,
  );
}

/// A round upper bound comfortably above [value] (so «١٢٠» is born with a
/// ceiling of ٢٠٠, not of ١٢٠).
num _roomAbove(num value) {
  if (value <= 0) return 100;
  final magnitude = value * 2;
  for (final step in [10, 20, 50, 100, 200, 500, 1000, 5000, 10000]) {
    if (magnitude <= step) return step;
  }
  return magnitude.ceil();
}

// --------------------------------------------------------------- the facts --

Future<DayChatEditResult?> _money(BuildContext context, MoneyFact fact) async {
  final l = L10n.of(context);
  final values = await showEditSheet(
    context,
    title: l.dayChatEditTitle,
    icon: Icons.payments_rounded,
    fields: [
      FieldSpec.currency(
        'amount',
        l.dayChatFieldAmount,
        required: true,
        defaultCurrency: fact.currency,
        min: 0.001,
        decimals: 3,
        icon: Icons.payments_rounded,
      ),
      FieldSpec.text('note', l.dayChatFieldOnWhat, maxLength: 80, icon: Icons.notes_rounded),
    ],
    initial: {
      if (fact.amountMilli > 0) 'amount': MoneyValue(amountMilli: fact.amountMilli, currency: fact.currency ?? 'JOD'),
      'note': fact.note,
    },
  );
  if (values == null) return null;
  final amount = values['amount'] as MoneyValue?;
  if (amount == null || amount.amountMilli <= 0) return null;
  return DayChatEditResult(
    fact.copyWith(
      amountMilli: amount.amountMilli,
      currency: amount.currency,
      note: (values['note'] as String?)?.trim() ?? fact.note,
    ),
  );
}

Future<DayChatEditResult?> _meal(BuildContext context, MealFact fact) async {
  final l = L10n.of(context);
  final values = await showEditSheet(
    context,
    title: l.dayChatEditTitle,
    icon: Icons.restaurant_rounded,
    fields: [
      FieldSpec.text('name', l.dayChatFieldMeal, required: true, maxLength: 60, icon: Icons.restaurant_rounded),
      FieldSpec.number('portion', l.dayChatFieldPortion, min: 0, max: 100, decimals: 2, icon: Icons.scale_rounded),
    ],
    initial: {'name': fact.name, 'portion': fact.portion},
  );
  if (values == null) return null;
  final name = (values['name'] as String?)?.trim();
  if (name == null || name.isEmpty) return null;
  return DayChatEditResult(fact.copyWith(name: name, portion: (values['portion'] as num?)?.toDouble()));
}

Future<DayChatEditResult?> _workout(BuildContext context, WorkoutFact fact) async {
  final l = L10n.of(context);
  final values = await showEditSheet(
    context,
    title: l.dayChatEditTitle,
    icon: Icons.fitness_center_rounded,
    fields: [
      FieldSpec.text('name', l.dayChatFieldWorkout, required: true, maxLength: 60, icon: Icons.fitness_center_rounded),
      FieldSpec.number('sets', l.dayChatFieldSets, min: 1, max: 50, icon: Icons.repeat_rounded),
      FieldSpec.number('reps', l.dayChatFieldReps, min: 1, max: 500, icon: Icons.numbers_rounded),
      FieldSpec.number('weight', l.dayChatFieldWeight, min: 0, max: 500, decimals: 2, icon: Icons.scale_rounded),
      FieldSpec.number('minutes', l.dayChatFieldMinutes, min: 1, max: 600, icon: Icons.timer_rounded),
    ],
    initial: {
      'name': fact.name,
      'sets': fact.sets,
      'reps': fact.reps,
      'weight': fact.weight,
      'minutes': fact.durationMin,
    },
  );
  if (values == null) return null;
  final name = (values['name'] as String?)?.trim();
  if (name == null || name.isEmpty) return null;
  return DayChatEditResult(
    fact.copyWith(
      name: name,
      sets: (values['sets'] as num?)?.toInt(),
      reps: (values['reps'] as num?)?.toInt(),
      weight: (values['weight'] as num?)?.toDouble(),
      durationMin: (values['minutes'] as num?)?.toInt(),
    ),
  );
}

Future<DayChatEditResult?> _water(BuildContext context, WaterFact fact) async {
  final l = L10n.of(context);
  final values = await showEditSheet(
    context,
    title: l.dayChatEditTitle,
    icon: Icons.water_drop_rounded,
    fields: [
      FieldSpec.number(
        'ml',
        l.dayChatFieldWater,
        required: true,
        min: 1,
        max: kDayChatWaterMax,
        icon: Icons.water_drop_rounded,
      ),
    ],
    initial: {'ml': fact.ml},
  );
  final ml = (values?['ml'] as num?)?.toInt();
  if (ml == null || ml <= 0) return null;
  return DayChatEditResult(fact.copyWith(ml: ml));
}

Future<DayChatEditResult?> _pain(BuildContext context, PainFact fact) async {
  final l = L10n.of(context);
  final values = await showEditSheet(
    context,
    title: l.dayChatEditTitle,
    icon: Icons.healing_rounded,
    fields: [
      // Typed, not dragged: a slider could never be out of range, and the
      // whole point is that an impossible score is refused with a reason.
      FieldSpec.number(
        'score',
        l.dayChatFieldPain,
        required: true,
        min: kDayChatPainMin,
        max: kDayChatPainMax,
        icon: Icons.healing_rounded,
      ),
      FieldSpec.text('where', l.dayChatFieldPainWhere, maxLength: 40, icon: Icons.place_outlined),
    ],
    initial: {'score': fact.score, 'where': fact.location},
  );
  if (values == null) return null;
  final score = (values['score'] as num?)?.toInt();
  if (score == null || score < kDayChatPainMin || score > kDayChatPainMax) return null;
  return DayChatEditResult(fact.copyWith(score: score, location: (values['where'] as String?)?.trim()));
}

Future<DayChatEditResult?> _mood(BuildContext context, MoodFact fact) async {
  final l = L10n.of(context);
  final values = await showEditSheet(
    context,
    title: l.dayChatEditTitle,
    icon: Icons.mood_rounded,
    fields: [
      FieldSpec.number(
        'score',
        l.dayChatFieldMood,
        required: true,
        min: kDayChatMoodMin,
        max: kDayChatMoodMax,
        icon: Icons.mood_rounded,
      ),
    ],
    initial: {'score': fact.score},
  );
  final score = (values?['score'] as num?)?.toInt();
  if (score == null || score < kDayChatMoodMin || score > kDayChatMoodMax) return null;
  return DayChatEditResult(fact.copyWith(score: score));
}

Future<DayChatEditResult?> _prayer(BuildContext context, PrayerFact fact) async {
  final l = L10n.of(context);
  final prayers = TrackerPrayers.obligatory;
  final values = await showEditSheet(
    context,
    title: l.dayChatEditTitle,
    icon: Icons.mosque_rounded,
    fields: [
      FieldSpec.singleSelect(
        'prayer',
        l.dayChatFieldPrayer,
        required: true,
        options: [for (final p in prayers) SelectOption(id: p.name, label: l.trackerPrayerName(p))],
        icon: Icons.mosque_rounded,
      ),
      FieldSpec.toggle('mosque', l.dayChatFieldMosque, icon: Icons.mosque_rounded),
      FieldSpec.toggle('jamaah', l.dayChatFieldJamaah, icon: Icons.groups_rounded),
    ],
    initial: {'prayer': fact.prayer.name, 'mosque': fact.atMosque, 'jamaah': fact.inJamaah},
  );
  if (values == null) return null;
  final name = values['prayer'] as String?;
  final prayer = prayers.where((p) => p.name == name).firstOrNull;
  if (prayer == null) return null;
  final mosque = values['mosque'] == true;
  return DayChatEditResult(
    fact.copyWith(prayer: prayer, atMosque: mosque, inJamaah: mosque || values['jamaah'] == true),
  );
}

Future<DayChatEditResult?> _taskDone(BuildContext context, WidgetRef ref, TaskDoneFact fact) async {
  final l = L10n.of(context);
  final open = [
    for (final t in await ref.read(repositoriesProvider).tasks.getAll())
      if (!t.done) t,
  ];
  if (!context.mounted) return null;
  final values = await showEditSheet(
    context,
    title: l.dayChatEditTitle,
    icon: Icons.task_alt_rounded,
    fields: [
      FieldSpec.text('title', l.dayChatFieldTask, required: true, maxLength: 80, icon: Icons.task_alt_rounded),
      if (open.isNotEmpty)
        FieldSpec.singleSelect(
          'task',
          l.dayChatFieldTaskMatch,
          options: [
            SelectOption(id: '', label: l.dayChatKeepNoTask, icon: Icons.add_task_rounded),
            for (final t in open) SelectOption(id: t.id, label: t.title),
          ],
          icon: Icons.checklist_rounded,
        ),
    ],
    initial: {'title': fact.title, 'task': fact.taskId ?? ''},
  );
  if (values == null) return null;
  final title = (values['title'] as String?)?.trim();
  if (title == null || title.isEmpty) return null;
  final picked = (values['task'] as String?) ?? '';
  // Dart's `copyWith` cannot put a null back, and clearing the match is a
  // real choice here, so the fact is rebuilt.
  return DayChatEditResult(TaskDoneFact(title: title, taskId: picked.isEmpty ? null : picked));
}

Future<DayChatEditResult?> _todo(BuildContext context, TaskTodoFact fact) async {
  final l = L10n.of(context);
  final today = DateTime.now();
  final values = await showEditSheet(
    context,
    title: l.dayChatEditTitle,
    icon: Icons.event_note_rounded,
    fields: [
      FieldSpec.text('title', l.dayChatFieldTask, required: true, maxLength: 80, icon: Icons.event_note_rounded),
      FieldSpec.prayerWindow('window', l.dayChatFieldWindow, icon: Icons.schedule_rounded),
      FieldSpec.date(
        'date',
        l.dayChatFieldDate,
        firstDate: DateTime(today.year - 1),
        lastDate: DateTime(today.year + 2),
        icon: Icons.event_rounded,
      ),
    ],
    initial: {'title': fact.title, 'window': fact.window, 'date': fact.date},
  );
  if (values == null) return null;
  final title = (values['title'] as String?)?.trim();
  if (title == null || title.isEmpty) return null;
  return DayChatEditResult(
    TaskTodoFact(
      title: title,
      window: values['window'] as PrayerWindow?,
      date: values['date'] as DateTime?,
      time: fact.time,
      planetKey: fact.planetKey,
    ),
  );
}

Future<DayChatEditResult?> _contact(BuildContext context, ContactFact fact) async {
  final l = L10n.of(context);
  final tx = FamilyTexts.of(context);
  final values = await showEditSheet(
    context,
    title: l.dayChatEditTitle,
    icon: Icons.people_alt_rounded,
    fields: [
      FieldSpec.text('name', l.dayChatFieldPerson, required: true, maxLength: 60, icon: Icons.person_outline_rounded),
      FieldSpec.singleSelect(
        'channel',
        l.dayChatFieldChannel,
        required: true,
        options: [
          for (final c in ContactChannel.values) SelectOption(id: c.name, label: tx.channel(c), icon: channelIcon(c)),
        ],
        icon: Icons.forum_outlined,
      ),
    ],
    initial: {'name': fact.name, 'channel': fact.channel.name},
  );
  if (values == null) return null;
  final name = (values['name'] as String?)?.trim();
  if (name == null || name.isEmpty) return null;
  final channel = ContactChannel.values.where((c) => c.name == values['channel']).firstOrNull ?? fact.channel;
  // A different person is a different person: the match of the old name
  // must not travel with the new one.
  final sameName = name == fact.name.trim();
  return DayChatEditResult(
    ContactFact(
      name: name,
      at: fact.at,
      personId: sameName ? fact.personId : null,
      channel: channel,
    ),
  );
}

Future<DayChatEditResult?> _note(BuildContext context, NoteFact fact) async {
  final l = L10n.of(context);
  final values = await showEditSheet(
    context,
    title: l.dayChatEditTitle,
    icon: Icons.sticky_note_2_outlined,
    fields: [
      FieldSpec.multiline('text', l.dayChatFieldNote, required: true, maxLength: 240),
      FieldSpec.prayerWindow('window', l.dayChatFieldWindow, icon: Icons.schedule_rounded),
    ],
    initial: {'text': fact.text, 'window': fact.window},
  );
  if (values == null) return null;
  final text = (values['text'] as String?)?.trim();
  if (text == null || text.isEmpty) return null;
  return DayChatEditResult(fact.copyWith(text: text, window: values['window'] as PrayerWindow?));
}

/// A number and the tracker it belongs in: which tracker (when the reader
/// could not tell), which of its fields, and the value – bounded by that
/// field's **own** min and max, because the service will not check again.
Future<DayChatEditResult?> _module(
  BuildContext context,
  WidgetRef ref,
  DayChatPiece piece,
  ModuleFact fact,
) async {
  final l = L10n.of(context);
  final service = ref.read(customModulesServiceProvider);
  final all = [
    for (final m in await service.modules())
      if (!m.archived && m.isTracker && m.fields.any((f) => !f.hidden)) m,
  ];
  if (!context.mounted) return null;
  if (all.isEmpty) {
    // Nothing to pick from: say so instead of opening an empty sheet. The
    // way out of here is «اعمللي متابعة جديدة من هاي» on the card itself.
    throw const DayChatNoTrackers();
  }
  final current = all.where((m) => m.id == fact.moduleId).firstOrNull;
  final values = await showEditSheet(
    context,
    title: l.dayChatEditTitle,
    icon: Icons.insights_rounded,
    fields: [
      FieldSpec.singleSelect(
        'module',
        l.dayChatFieldModule,
        required: true,
        options: [for (final m in all) SelectOption(id: m.id, label: m.name)],
        icon: Icons.insights_rounded,
      ),
    ],
    initial: {'module': current?.id ?? all.first.id},
  );
  if (values == null || !context.mounted) return null;
  final module = all.where((m) => m.id == values['module']).firstOrNull;
  if (module == null) return null;
  return _moduleValue(context, piece, fact, module);
}

/// The second half of a tracker edit: the field and the value, with the
/// field's own bounds on the input.
Future<DayChatEditResult?> _moduleValue(
  BuildContext context,
  DayChatPiece piece,
  ModuleFact fact,
  ModuleDefinition module,
) async {
  final l = L10n.of(context);
  final fields = [
    for (final f in module.visibleFields)
      if (f.type == FieldType.number || f.type == FieldType.rating || f.type == FieldType.currency) f,
  ];
  final usable = fields.isEmpty ? module.visibleFields : fields;
  if (usable.isEmpty) return null;
  final chosen = usable.where((f) => f.id == fact.fieldId).firstOrNull ?? usable.first;
  final value = fact.value;
  final values = await showEditSheet(
    context,
    title: l.dayChatEditTitle,
    subtitle: module.name,
    icon: Icons.numbers_rounded,
    fields: [
      if (usable.length > 1)
        FieldSpec.singleSelect(
          'field',
          l.dayChatFieldModuleField,
          required: true,
          options: [for (final f in usable) SelectOption(id: f.id, label: f.label)],
          icon: Icons.list_alt_rounded,
        ),
      _valueField(l, chosen),
    ],
    initial: {'field': chosen.id, 'value': value is num ? value : null},
  );
  if (values == null) return null;
  final field = usable.where((f) => f.id == (values['field'] ?? chosen.id)).firstOrNull ?? chosen;
  final raw = values['value'];
  final number = raw is num ? raw : (raw is MoneyValue ? raw.amount : null);
  if (number == null) return null;
  // The field he landed on may not be the one the bounds were drawn for
  // (he changed the picker and the number stayed): check it here, where
  // the sheet can still refuse, instead of letting the service store it.
  if (field.min != null && number < field.min!) return null;
  if (field.max != null && number > field.max!) return null;
  return DayChatEditResult(
    ModuleFact(
      moduleId: module.id,
      moduleName: module.name,
      at: fact.at,
      fieldId: field.id,
      fieldLabel: field.label,
      value: number,
    ),
    // It has a tracker now, so it is no longer a bare reading.
    kind: piece.kind == DayChatKind.sign ? DayChatKind.moduleEntry : null,
  );
}

/// The input for one tracker field, carrying that field's own bounds.
FieldSpec _valueField(L10n l, ModuleField field) => switch (field.type) {
  FieldType.rating => FieldSpec.number(
    'value',
    field.label,
    required: true,
    min: 1,
    max: field.ratingMax,
    icon: Icons.star_outline_rounded,
  ),
  FieldType.currency => FieldSpec.number(
    'value',
    field.label,
    required: true,
    min: field.min ?? 0,
    max: field.max,
    decimals: 3,
    icon: Icons.payments_rounded,
  ),
  _ => FieldSpec.number(
    'value',
    field.label,
    required: true,
    min: field.min,
    max: field.max,
    decimals: field.decimals,
    unit: field.unit,
    icon: Icons.numbers_rounded,
  ),
};
