/// His own words the reader must recognise: the modules he built, the people
/// he saved, the foods and exercises he already has, and his open tasks.
///
/// Pure Dart: the data layer reads these out of his database
/// (`DayChatService.vocabulary`), the reader only matches against them. A
/// fresh install has an empty vocabulary and the reader still works – it
/// just says more often that it could not resolve a name.
library;

import 'package:meta/meta.dart';

import '../../../core/domain/enums.dart';
import '../../custom_modules/domain/module_schema.dart';
import 'day_chat_text.dart';

/// One option of a select field.
@immutable
class DayChatOption {
  const DayChatOption(this.id, this.label);

  final String id;
  final String label;
}

/// One field of a module he built.
@immutable
class DayChatField {
  const DayChatField({
    required this.id,
    required this.label,
    required this.type,
    this.unit,
    this.min,
    this.max,
    this.options = const [],
  });

  factory DayChatField.of(ModuleField f) => DayChatField(
    id: f.id,
    label: f.label,
    type: f.type,
    unit: f.unit,
    min: f.min,
    max: f.max,
    options: [for (final o in f.options) DayChatOption(o.id, o.label)],
  );

  final String id;
  final String label;
  final FieldType type;
  final String? unit;
  final double? min;
  final double? max;
  final List<DayChatOption> options;

  /// A field a number can be written into.
  bool get takesNumber => type == FieldType.number || type == FieldType.rating || type == FieldType.currency;
}

/// One module he built himself.
@immutable
class DayChatModule {
  const DayChatModule({
    required this.id,
    required this.name,
    required this.fields,
    this.planetKey,
    this.isTracker = true,
  });

  factory DayChatModule.of(ModuleDefinition m) => DayChatModule(
    id: m.id,
    name: m.name,
    planetKey: m.planetKey,
    isTracker: m.isTracker,
    fields: [for (final f in m.visibleFields) DayChatField.of(f)],
  );

  final String id;
  final String name;
  final String? planetKey;
  final bool isTracker;
  final List<DayChatField> fields;

  List<DayChatField> get numberFields => [
    for (final f in fields)
      if (f.takesNumber) f,
  ];
}

/// A person of his family list.
@immutable
class DayChatPerson {
  const DayChatPerson({required this.id, required this.name, this.relation});

  final String id;
  final String name;

  /// The stored relation key («mother», «brother» …), when he set one.
  final String? relation;
}

/// A food of his library or an exercise of his plan.
@immutable
class DayChatNamed {
  const DayChatNamed({required this.id, required this.name, this.unit, this.portion});

  final String id;
  final String name;
  final String? unit;
  final double? portion;
}

/// A task of his that is still open.
@immutable
class DayChatOpenTask {
  const DayChatOpenTask({required this.id, required this.title});

  final String id;
  final String title;
}

@immutable
class DayChatVocabulary {
  const DayChatVocabulary({
    this.modules = const [],
    this.people = const [],
    this.foods = const [],
    this.exercises = const [],
    this.openTasks = const [],
  });

  static const DayChatVocabulary empty = DayChatVocabulary();

  final List<DayChatModule> modules;
  final List<DayChatPerson> people;
  final List<DayChatNamed> foods;
  final List<DayChatNamed> exercises;
  final List<DayChatOpenTask> openTasks;

  /// The food of his library he named, or null.
  DayChatNamed? food(String name) => _named(foods, name);

  /// The exercise of his plan he named, or null.
  DayChatNamed? exercise(String name) => _named(exercises, name);

  static DayChatNamed? _named(List<DayChatNamed> all, String name) {
    final key = DayChatText.nameKey(name);
    if (key.isEmpty) return null;
    for (final n in all) {
      if (DayChatText.nameKey(n.name) == key) return n;
    }
    // «منسف لحمة» finds his «منسف» when nothing matches the whole name.
    for (final n in all) {
      if (DayChatText.containsWords(name, n.name)) return n;
    }
    return null;
  }

  /// The person he named: by the name he saved, else the only person with
  /// that relation («أمي») – never a guess between two uncles.
  DayChatPerson? person(String typed, {String? relation}) {
    final key = DayChatText.nameKey(typed);
    if (key.isNotEmpty) {
      for (final p in people) {
        if (DayChatText.nameKey(p.name) == key) return p;
      }
    }
    if (relation == null) return null;
    final byRelation = [
      for (final p in people)
        if (p.relation == relation) p,
    ];
    return byRelation.length == 1 ? byRelation.single : null;
  }

  /// His open task whose title this text names, or null.
  DayChatOpenTask? openTask(String text) {
    final key = DayChatText.nameKey(text);
    if (key.isEmpty) return null;
    for (final t in openTasks) {
      if (DayChatText.nameKey(t.title) == key) return t;
    }
    for (final t in openTasks) {
      if (DayChatText.containsWords(t.title, text) || DayChatText.containsWords(text, t.title)) return t;
    }
    return null;
  }

  /// The tracker modules, longest name first (so «سكر الدم» wins over
  /// «سكر»).
  List<DayChatModule> get trackers {
    final out = [
      for (final m in modules)
        if (m.isTracker) m,
    ];
    out.sort((a, b) => DayChatText.terms(b.name).length.compareTo(DayChatText.terms(a.name).length));
    return out;
  }
}
