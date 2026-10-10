/// Generic starter modules for the template gallery. Optional and fully
/// editable: a template only pre-fills the builder. No personal data – the
/// labels come from the localisations through [TemplateLabel].
///
/// Pure Dart.
library;

import '../../../core/domain/enums.dart';
import 'module_schema.dart';

enum ModuleTemplateKey { readingLog, dhikrCounter, dailyHabit, habitList, sleepLog, giftIdeas }

/// Label keys a template needs (the UI maps them to localised strings).
enum TemplateText {
  readingLogName,
  readingBook,
  readingPages,
  readingRating,
  unitPages,
  dhikrName,
  dhikrAfter,
  dhikrCount,
  unitTimes,
  prayerFajr,
  prayerDhuhr,
  prayerAsr,
  prayerMaghrib,
  prayerIsha,
  habitName,
  habitDone,
  habitNote,
  habitListName,
  habitListHabit,
  habitListFrequency,
  frequencyDaily,
  frequencyWeekly,
  frequencyMonthly,
  sleepName,
  sleepBedtime,
  sleepWake,
  sleepHours,
  unitHours,
  sleepQuality,
  giftName,
  giftIdea,
  giftFor,
  giftBudget,
  giftOccasion,
  notes,
}

typedef TemplateLabel = String Function(TemplateText key);

abstract final class ModuleTemplates {
  static const List<ModuleTemplateKey> all = ModuleTemplateKey.values;

  /// Planet surface colours (the orbit's palette) for the templates.
  static const Map<String, int> planetColors = {
    'faith': 0xFFF2C14E,
    'health': 0xFF1FB5C9,
    'family': 0xFFD9774A,
    'work': 0xFF8A95A8,
    'money': 0xFF7FE3C4,
    'growth': 0xFF4CC96B,
    'body': 0xFFFF5A36,
    'travel': 0xFF9C8CFF,
  };

  /// A new (unsaved, id `''`) module pre-filled from [key].
  static ModuleDefinition build(ModuleTemplateKey key, TemplateLabel t) {
    ModuleField f(
      String id,
      TemplateText label,
      FieldType type, {
      String? unit,
      bool required = false,
      List<FieldOption> options = const [],
      num? min,
      num? max,
      int decimals = 0,
      String? currency,
      bool multiline = false,
    }) => ModuleField(
      id: id,
      label: t(label),
      type: type,
      unit: unit,
      required: required,
      options: options,
      min: min,
      max: max,
      decimals: decimals,
      currency: currency,
      multiline: multiline,
    );
    FieldOption o(String id, TemplateText label) => FieldOption(id: id, label: t(label));

    ModuleDefinition m({
      required TemplateText name,
      required CustomModuleKind kind,
      required String icon,
      required String planet,
      PrayerWindow? window,
      required List<ModuleField> fields,
      ModuleChartConfig? chart,
    }) => ModuleDefinition(
      id: '',
      name: t(name),
      kind: kind,
      iconKey: icon,
      colorArgb: planetColors[planet]!,
      planetKey: planet,
      window: window,
      fields: fields,
      chart: chart,
    );

    switch (key) {
      case ModuleTemplateKey.readingLog:
        return m(
          name: TemplateText.readingLogName,
          kind: CustomModuleKind.tracker,
          icon: 'book',
          planet: 'growth',
          window: PrayerWindow.fajr,
          fields: [
            f('f1', TemplateText.readingBook, FieldType.text, required: true),
            f('f2', TemplateText.readingPages, FieldType.number, unit: t(TemplateText.unitPages), required: true, min: 0),
            f('f3', TemplateText.readingRating, FieldType.rating, max: 5),
          ],
          chart: const ModuleChartConfig(type: ModuleChartType.bar, fieldId: 'f2', range: 30),
        );
      case ModuleTemplateKey.dhikrCounter:
        return m(
          name: TemplateText.dhikrName,
          kind: CustomModuleKind.tracker,
          icon: 'sparkle',
          planet: 'faith',
          fields: [
            f(
              'f1',
              TemplateText.dhikrAfter,
              FieldType.singleSelect,
              options: [
                o('o1', TemplateText.prayerFajr),
                o('o2', TemplateText.prayerDhuhr),
                o('o3', TemplateText.prayerAsr),
                o('o4', TemplateText.prayerMaghrib),
                o('o5', TemplateText.prayerIsha),
              ],
            ),
            f('f2', TemplateText.dhikrCount, FieldType.number, unit: t(TemplateText.unitTimes), required: true, min: 0),
          ],
          chart: const ModuleChartConfig(type: ModuleChartType.bar, fieldId: 'f2', range: 30),
        );
      case ModuleTemplateKey.dailyHabit:
        return m(
          name: TemplateText.habitName,
          kind: CustomModuleKind.tracker,
          icon: 'sprout',
          planet: 'growth',
          fields: [
            f('f1', TemplateText.habitDone, FieldType.checkbox),
            f('f2', TemplateText.habitNote, FieldType.text),
          ],
          chart: const ModuleChartConfig(type: ModuleChartType.streak, fieldId: 'f1', range: 30),
        );
      case ModuleTemplateKey.habitList:
        return m(
          name: TemplateText.habitListName,
          kind: CustomModuleKind.list,
          icon: 'leaf',
          planet: 'growth',
          fields: [
            f('f1', TemplateText.habitListHabit, FieldType.text, required: true),
            f(
              'f2',
              TemplateText.habitListFrequency,
              FieldType.singleSelect,
              options: [
                o('o1', TemplateText.frequencyDaily),
                o('o2', TemplateText.frequencyWeekly),
                o('o3', TemplateText.frequencyMonthly),
              ],
            ),
            f('f3', TemplateText.notes, FieldType.text, multiline: true),
          ],
        );
      case ModuleTemplateKey.sleepLog:
        return m(
          name: TemplateText.sleepName,
          kind: CustomModuleKind.tracker,
          icon: 'sleep',
          planet: 'body',
          window: PrayerWindow.isha,
          fields: [
            f('f1', TemplateText.sleepBedtime, FieldType.time),
            f('f2', TemplateText.sleepWake, FieldType.time),
            f(
              'f3',
              TemplateText.sleepHours,
              FieldType.number,
              unit: t(TemplateText.unitHours),
              min: 0,
              max: 24,
              decimals: 1,
              required: true,
            ),
            f('f4', TemplateText.sleepQuality, FieldType.rating, max: 5),
          ],
          chart: const ModuleChartConfig(type: ModuleChartType.line, fieldId: 'f3', range: 30),
        );
      case ModuleTemplateKey.giftIdeas:
        return m(
          name: TemplateText.giftName,
          kind: CustomModuleKind.list,
          icon: 'gift',
          planet: 'family',
          fields: [
            f('f1', TemplateText.giftIdea, FieldType.text, required: true),
            f('f2', TemplateText.giftFor, FieldType.text),
            f('f3', TemplateText.giftBudget, FieldType.currency, currency: 'JOD'),
            f('f4', TemplateText.giftOccasion, FieldType.date),
          ],
        );
    }
  }
}
