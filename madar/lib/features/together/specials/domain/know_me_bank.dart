/// The editable question bank of "How well do you know me?".
library;

import 'know_me_catalogue.dart';
import 'specials_bounds.dart';

/// A category of questions. A default category shows its localised name
/// until it is renamed ([name] non-empty); a new one always has a name.
final class KnowMeCategory {
  const KnowMeCategory({required this.id, this.name = '', this.icon = ''});

  final String id;

  /// The typed name ('' = the default category's localised name).
  final String name;

  /// Icon key ('' = the default category's icon, else a star).
  final String icon;

  bool get isDefault => KnowMeCatalogue.isDefaultCategory(id);

  /// The name to show in [languageCode].
  String nameIn(String languageCode) =>
      name.isNotEmpty ? name : (KnowMeCatalogue.category(id)?.name.of(languageCode) ?? '');

  String get iconKey => icon.isNotEmpty ? icon : (KnowMeCatalogue.category(id)?.icon ?? 'star');

  Map<String, Object?> toJson() => {
    'i': id,
    if (name.isNotEmpty) 'n': name,
    if (icon.isNotEmpty) 'k': icon,
  };

  static KnowMeCategory? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['i'];
    if (id is! String || !SpecialsBounds.isValidId(id)) return null;
    final name = SpecialsBounds.clean(json['n'], SpecialsBounds.maxCategoryNameLength);
    final icon = json['k'];
    final c = KnowMeCategory(
      id: id,
      name: name,
      icon: icon is String && KnowMeCatalogue.iconKeys.contains(icon) ? icon : '',
    );
    // A category of the user's own must have a name.
    if (!c.isDefault && name.isEmpty) return null;
    return c;
  }

  @override
  bool operator ==(Object other) => other is KnowMeCategory && other.id == id && other.name == name && other.icon == icon;

  @override
  int get hashCode => Object.hash(id, name, icon);
}

/// A question. A default question shows its localised text until it is
/// edited ([text] non-empty); a new one always has a text.
final class KnowMeQuestion {
  const KnowMeQuestion({required this.id, required this.category, this.text = ''});

  final String id;
  final String category;

  /// The typed text ('' = the default question's localised text).
  final String text;

  bool get isDefault => KnowMeCatalogue.isDefaultQuestion(id);

  /// Whether a default question carries the user's own wording.
  bool get isEdited => isDefault && text.isNotEmpty;

  String textIn(String languageCode) =>
      text.isNotEmpty ? text : (KnowMeCatalogue.question(id)?.text.of(languageCode) ?? '');

  KnowMeQuestion copyWith({String? category, String? text}) =>
      KnowMeQuestion(id: id, category: category ?? this.category, text: text ?? this.text);

  Map<String, Object?> toJson() => {'i': id, 'c': category, if (text.isNotEmpty) 't': text};

  static KnowMeQuestion? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['i'];
    final category = json['c'];
    if (id is! String || !SpecialsBounds.isValidId(id)) return null;
    final text = SpecialsBounds.clean(json['t'], SpecialsBounds.maxQuestionLength);
    final q = KnowMeQuestion(
      id: id,
      category: category is String && SpecialsBounds.isValidId(category) ? category : '',
      text: text,
    );
    if (!q.isDefault && text.isEmpty) return null;
    return q;
  }

  @override
  bool operator ==(Object other) =>
      other is KnowMeQuestion && other.id == id && other.category == category && other.text == text;

  @override
  int get hashCode => Object.hash(id, category, text);
}

/// Why an edit of the bank was refused.
enum BankEditError { emptyText, full, unknownCategory, unknownQuestion, lastCategory }

/// Thrown by the bank's edits (the UI prevents all of them).
final class BankEditException implements Exception {
  const BankEditException(this.error);

  final BankEditError error;

  @override
  String toString() => 'BankEditException(${error.name})';
}

/// Every question and category, in the user's order. Immutable: each edit
/// returns a new bank.
///
/// Defaults the user removed are remembered, so an app update that adds
/// new default questions adds only those – never the ones deleted.
final class KnowMeBank {
  const KnowMeBank({
    required this.categories,
    required this.questions,
    this.removedQuestions = const {},
    this.removedCategories = const {},
  });

  /// The starting set: every default category and question.
  factory KnowMeBank.defaults() => KnowMeBank(
    categories: [for (final c in KnowMeCatalogue.categories) KnowMeCategory(id: c.id)],
    questions: [for (final q in KnowMeCatalogue.questions) KnowMeQuestion(id: q.id, category: q.category)],
  );

  final List<KnowMeCategory> categories;
  final List<KnowMeQuestion> questions;

  /// Default questions / categories the user deleted.
  final Set<String> removedQuestions;
  final Set<String> removedCategories;

  bool get isFull => questions.length >= SpecialsBounds.maxQuestions;

  bool get categoriesFull => categories.length >= SpecialsBounds.maxCategories;

  KnowMeCategory? category(String id) => categories.where((c) => c.id == id).firstOrNull;

  KnowMeQuestion? question(String id) => questions.where((q) => q.id == id).firstOrNull;

  /// Questions of [categoryId] in order.
  List<KnowMeQuestion> questionsIn(String categoryId) => [
    for (final q in questions)
      if (q.category == categoryId) q,
  ];

  /// Questions in [categoryIds] (every question when empty or when none of
  /// the ids exists any more).
  List<KnowMeQuestion> questionsInAny(Set<String> categoryIds) {
    final valid = categoryIds.where((id) => category(id) != null).toSet();
    if (valid.isEmpty) return questions;
    return [
      for (final q in questions)
        if (valid.contains(q.category)) q,
    ];
  }

  /// Whether the defaults can be restored (something was removed or edited).
  bool get differsFromDefaults =>
      removedQuestions.isNotEmpty ||
      removedCategories.isNotEmpty ||
      questions.any((q) => q.isEdited) ||
      categories.any((c) => c.isDefault && (c.name.isNotEmpty || c.icon.isNotEmpty));

  // ----------------------------------------------------------------- edits

  KnowMeBank _with({
    List<KnowMeCategory>? categories,
    List<KnowMeQuestion>? questions,
    Set<String>? removedQuestions,
    Set<String>? removedCategories,
  }) => KnowMeBank(
    categories: categories ?? this.categories,
    questions: questions ?? this.questions,
    removedQuestions: removedQuestions ?? this.removedQuestions,
    removedCategories: removedCategories ?? this.removedCategories,
  );

  String _cleanQuestion(String text) {
    final t = SpecialsBounds.clean(text, SpecialsBounds.maxQuestionLength);
    if (t.isEmpty) throw const BankEditException(BankEditError.emptyText);
    return t;
  }

  /// Adds a question of the user's own at the end of [categoryId].
  KnowMeBank addQuestion({required String id, required String categoryId, required String text}) {
    if (isFull) throw const BankEditException(BankEditError.full);
    if (category(categoryId) == null) throw const BankEditException(BankEditError.unknownCategory);
    if (!SpecialsBounds.isValidId(id) || question(id) != null || KnowMeCatalogue.isDefaultQuestion(id)) {
      throw ArgumentError.value(id, 'id', 'not a fresh id');
    }
    final q = KnowMeQuestion(id: id, category: categoryId, text: _cleanQuestion(text));
    // Right after the last question of its category (the category stays
    // together in the list).
    final lastIndex = questions.lastIndexWhere((x) => x.category == categoryId);
    final list = [...questions]..insert(lastIndex + 1, q);
    return _with(questions: list);
  }

  /// Rewords and/or moves question [id]. A default question reworded back
  /// to its default text in either language becomes the default again.
  KnowMeBank editQuestion(String id, {String? text, String? categoryId}) {
    final q = question(id);
    if (q == null) throw const BankEditException(BankEditError.unknownQuestion);
    if (categoryId != null && category(categoryId) == null) throw const BankEditException(BankEditError.unknownCategory);
    var newText = q.text;
    if (text != null) {
      newText = _cleanQuestion(text);
      final d = KnowMeCatalogue.question(id);
      if (d != null && (newText == d.text.ar || newText == d.text.en)) newText = '';
    }
    final moved = categoryId != null && categoryId != q.category;
    final updated = KnowMeQuestion(id: id, category: categoryId ?? q.category, text: newText);
    final list = [...questions];
    final i = list.indexWhere((x) => x.id == id);
    if (!moved) {
      list[i] = updated;
    } else {
      list.removeAt(i);
      final last = list.lastIndexWhere((x) => x.category == categoryId);
      list.insert(last + 1, updated);
    }
    return _with(questions: list);
  }

  /// Back to the default wording of a default question.
  KnowMeBank resetQuestionText(String id) {
    final q = question(id);
    if (q == null || !q.isDefault) return this;
    return _with(questions: [for (final x in questions) x.id == id ? x.copyWith(text: '') : x]);
  }

  KnowMeBank deleteQuestion(String id) {
    final q = question(id);
    if (q == null) return this;
    return _with(
      questions: [
        for (final x in questions)
          if (x.id != id) x,
      ],
      removedQuestions: q.isDefault ? {...removedQuestions, id} : removedQuestions,
    );
  }

  /// Puts the questions of [categoryId] in the order of [ids] (ids not in
  /// the category are ignored; questions missing from [ids] keep their
  /// relative order after the listed ones).
  KnowMeBank reorderQuestions(String categoryId, List<String> ids) {
    final inCategory = questionsIn(categoryId);
    final byId = {for (final q in inCategory) q.id: q};
    final ordered = <KnowMeQuestion>[
      for (final id in ids.toSet())
        if (byId.containsKey(id)) byId[id]!,
    ];
    for (final q in inCategory) {
      if (!ordered.contains(q)) ordered.add(q);
    }
    // Fill the category's slots in the global list with the new order.
    var k = 0;
    return _with(questions: [for (final q in questions) q.category == categoryId ? ordered[k++] : q]);
  }

  KnowMeBank addCategory({required String id, required String name, String icon = ''}) {
    if (categoriesFull) throw const BankEditException(BankEditError.full);
    if (!SpecialsBounds.isValidId(id) || category(id) != null || KnowMeCatalogue.isDefaultCategory(id)) {
      throw ArgumentError.value(id, 'id', 'not a fresh id');
    }
    final n = SpecialsBounds.clean(name, SpecialsBounds.maxCategoryNameLength);
    if (n.isEmpty) throw const BankEditException(BankEditError.emptyText);
    return _with(
      categories: [...categories, KnowMeCategory(id: id, name: n, icon: KnowMeCatalogue.iconKeys.contains(icon) ? icon : '')],
    );
  }

  /// Renames a category ('' gives a default category its default name back;
  /// one of the user's own must keep a name).
  KnowMeBank renameCategory(String id, String name, {String? icon}) {
    final c = category(id);
    if (c == null) throw const BankEditException(BankEditError.unknownCategory);
    var n = SpecialsBounds.clean(name, SpecialsBounds.maxCategoryNameLength);
    final d = KnowMeCatalogue.category(id);
    if (d != null && (n == d.name.ar || n == d.name.en)) n = '';
    if (n.isEmpty && !c.isDefault) throw const BankEditException(BankEditError.emptyText);
    var k = icon ?? c.icon;
    if (!KnowMeCatalogue.iconKeys.contains(k) || (d != null && k == d.icon)) k = '';
    return _with(categories: [for (final x in categories) x.id == id ? KnowMeCategory(id: id, name: n, icon: k) : x]);
  }

  /// Deletes a category; its questions move to [moveTo] (default: the first
  /// other category). The last category cannot be deleted.
  KnowMeBank deleteCategory(String id, {String? moveTo}) {
    final c = category(id);
    if (c == null) return this;
    if (categories.length <= 1) throw const BankEditException(BankEditError.lastCategory);
    final target = moveTo != null && moveTo != id && category(moveTo) != null
        ? moveTo
        : categories.firstWhere((x) => x.id != id).id;
    final moving = questionsIn(id).map((q) => q.copyWith(category: target)).toList();
    final rest = [
      for (final q in questions)
        if (q.category != id) q,
    ];
    final last = rest.lastIndexWhere((q) => q.category == target);
    rest.insertAll(last + 1, moving);
    return _with(
      categories: [
        for (final x in categories)
          if (x.id != id) x,
      ],
      questions: rest,
      removedCategories: c.isDefault ? {...removedCategories, id} : removedCategories,
    );
  }

  KnowMeBank reorderCategories(List<String> ids) {
    final byId = {for (final c in categories) c.id: c};
    final ordered = <KnowMeCategory>[
      for (final id in ids.toSet())
        if (byId.containsKey(id)) byId[id]!,
    ];
    for (final c in categories) {
      if (!ordered.contains(c)) ordered.add(c);
    }
    return _with(categories: ordered);
  }

  /// Brings back every default question and category (with their default
  /// wording) and keeps the user's own questions and categories.
  KnowMeBank restoreDefaults() {
    final own = KnowMeBank(
      categories: [
        for (final c in categories)
          if (!c.isDefault) c,
      ],
      questions: [
        for (final q in questions)
          if (!q.isDefault) q,
      ],
    );
    final defaults = KnowMeBank.defaults();
    final cats = [...defaults.categories, ...own.categories].take(SpecialsBounds.maxCategories).toList();
    final catIds = {for (final c in cats) c.id};
    final ownQuestions = [
      for (final q in own.questions)
        if (catIds.contains(q.category)) q else q.copyWith(category: KnowMeCatalogue.favourites),
    ];
    // Own questions first (they are what the couple wrote), then as many
    // defaults as the bound allows.
    final room = SpecialsBounds.maxQuestions - ownQuestions.length;
    final qs = [...defaults.questions.take(room.clamp(0, defaults.questions.length)), ...ownQuestions];
    return KnowMeBank(categories: cats, questions: _groupByCategory(qs, cats));
  }

  static List<KnowMeQuestion> _groupByCategory(List<KnowMeQuestion> qs, List<KnowMeCategory> cats) => [
    for (final c in cats) ...qs.where((q) => q.category == c.id),
  ];

  // ------------------------------------------------------------------ json

  Map<String, Object?> toJson() => {
    'v': 1,
    'c': [for (final c in categories) c.toJson()],
    'q': [for (final q in questions) q.toJson()],
    if (removedQuestions.isNotEmpty) 'rq': removedQuestions.toList()..sort(),
    if (removedCategories.isNotEmpty) 'rc': removedCategories.toList()..sort(),
  };

  /// A stored bank; the defaults when nothing usable is stored. Unusable
  /// entries and duplicates are dropped, everything is bounded, and default
  /// questions / categories added by a newer app version appear (unless the
  /// user removed them).
  static KnowMeBank fromJson(Object? json) {
    if (json is! Map || json['c'] is! List || json['q'] is! List) return KnowMeBank.defaults();
    Set<String> ids(Object? v, bool Function(String) known) => {
      if (v is List)
        for (final x in v)
          if (x is String && known(x)) x,
    };
    final removedQ = ids(json['rq'], KnowMeCatalogue.isDefaultQuestion);
    final removedC = ids(json['rc'], KnowMeCatalogue.isDefaultCategory);

    final cats = <KnowMeCategory>[];
    for (final item in json['c'] as List) {
      final c = KnowMeCategory.fromJson(item);
      if (c == null || cats.any((x) => x.id == c.id)) continue;
      if (c.isDefault && removedC.contains(c.id)) continue;
      if (cats.length < SpecialsBounds.maxCategories) cats.add(c);
    }
    for (final d in KnowMeCatalogue.categories) {
      if (cats.length >= SpecialsBounds.maxCategories) break;
      if (!removedC.contains(d.id) && !cats.any((c) => c.id == d.id)) cats.add(KnowMeCategory(id: d.id));
    }
    if (cats.isEmpty) return KnowMeBank.defaults();
    final catIds = {for (final c in cats) c.id};
    String home(String category, String questionId) {
      if (catIds.contains(category)) return category;
      final d = KnowMeCatalogue.question(questionId)?.category;
      return d != null && catIds.contains(d) ? d : cats.first.id;
    }

    final qs = <KnowMeQuestion>[];
    final seen = <String>{};
    for (final item in json['q'] as List) {
      final q = KnowMeQuestion.fromJson(item);
      if (q == null || !seen.add(q.id)) continue;
      if (q.isDefault && removedQ.contains(q.id)) continue;
      if (qs.length < SpecialsBounds.maxQuestions) qs.add(q.copyWith(category: home(q.category, q.id)));
    }
    for (final d in KnowMeCatalogue.questions) {
      if (qs.length >= SpecialsBounds.maxQuestions) break;
      if (!removedQ.contains(d.id) && !seen.contains(d.id)) {
        seen.add(d.id);
        final q = KnowMeQuestion(id: d.id, category: home(d.category, d.id));
        final last = qs.lastIndexWhere((x) => x.category == q.category);
        qs.insert(last + 1, q);
      }
    }
    return KnowMeBank(categories: cats, questions: qs, removedQuestions: removedQ, removedCategories: removedC);
  }

  @override
  bool operator ==(Object other) =>
      other is KnowMeBank &&
      _listEq(other.categories, categories) &&
      _listEq(other.questions, questions) &&
      other.removedQuestions.length == removedQuestions.length &&
      other.removedQuestions.containsAll(removedQuestions) &&
      other.removedCategories.length == removedCategories.length &&
      other.removedCategories.containsAll(removedCategories);

  @override
  int get hashCode => Object.hash(Object.hashAll(categories), Object.hashAll(questions), removedQuestions.length);

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Round preferences and the recently asked questions.
final class KnowMePrefs {
  const KnowMePrefs({
    this.roundSize = SpecialsBounds.defaultRoundSize,
    this.categories = const {},
    this.recent = const [],
  });

  /// Questions per round (each is asked about both players).
  final int roundSize;

  /// Categories to draw from (empty = all).
  final Set<String> categories;

  /// Recently asked question ids, oldest first.
  final List<String> recent;

  KnowMePrefs copyWith({int? roundSize, Set<String>? categories, List<String>? recent}) => KnowMePrefs(
    roundSize: roundSize == null ? this.roundSize : roundSize.clamp(1, SpecialsBounds.maxRoundSize),
    categories: categories ?? this.categories,
    recent: recent ?? this.recent,
  );

  /// [ids] were just asked: they move to the end of the recent list.
  KnowMePrefs asked(Iterable<String> ids) {
    final set = ids.toSet();
    final list = [
      ...recent.where((id) => !set.contains(id)),
      ...set,
    ];
    return copyWith(
      recent: list.length > SpecialsBounds.maxRecentAsked ? list.sublist(list.length - SpecialsBounds.maxRecentAsked) : list,
    );
  }

  Map<String, Object?> toJson() => {
    'v': 1,
    'n': roundSize,
    if (categories.isNotEmpty) 'c': categories.toList()..sort(),
    if (recent.isNotEmpty) 'r': recent,
  };

  static KnowMePrefs fromJson(Object? json) {
    if (json is! Map) return const KnowMePrefs();
    final n = json['n'];
    List<String> ids(Object? v, int max) {
      final out = <String>[];
      if (v is List) {
        for (final x in v) {
          if (x is String && SpecialsBounds.isValidId(x) && !out.contains(x)) out.add(x);
        }
      }
      return out.length > max ? out.sublist(out.length - max) : out;
    }

    return KnowMePrefs(
      roundSize: n is int && n >= 1 && n <= SpecialsBounds.maxRoundSize ? n : SpecialsBounds.defaultRoundSize,
      categories: ids(json['c'], SpecialsBounds.maxCategories).toSet(),
      recent: ids(json['r'], SpecialsBounds.maxRecentAsked),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KnowMePrefs &&
      other.roundSize == roundSize &&
      other.categories.length == categories.length &&
      other.categories.containsAll(categories) &&
      KnowMeBank._listEq(other.recent, recent);

  @override
  int get hashCode => Object.hash(roundSize, categories.length, recent.length);
}
