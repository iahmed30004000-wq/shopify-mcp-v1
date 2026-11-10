/// The guide's content model.
///
/// An entry is stored as a [GuideEntrySpec] – ids and ARB *keys* only – so the
/// registry never holds display text and follows a language switch for free:
/// a [GuideTextResolver] turns keys into the current language when an entry
/// is needed.
library;

import 'package:flutter/foundation.dart';

/// Turns an ARB key into text in the current language. Must throw for an
/// unknown key (a typo in a spec should fail loudly in tests, not show a key).
typedef GuideTextResolver = String Function(String key);

/// A guide entry before translation.
@immutable
class GuideEntrySpec {
  const GuideEntrySpec({
    required this.id,
    required this.titleKey,
    required this.purposeKey,
    required this.exampleKey,
    required this.doKeys,
    this.relatedIds = const [],
    this.keywordsKey,
    this.tourId,
  });

  /// Stable, dotted id: «today», «planet.faith», «add.expense».
  final String id;
  final String titleKey;

  /// One sentence: what this screen is for.
  final String purposeKey;

  /// One concrete example, written as «مثال: …».
  final String exampleKey;

  /// "What you can do here": two or three items.
  final List<String> doKeys;

  /// Ids of other entries worth reading next.
  final List<String> relatedIds;

  /// Extra words people may search with (synonyms, colloquial spellings).
  final String? keywordsKey;

  /// The coach tour of this screen, when it has one (shows «replay»).
  final String? tourId;

  static const int minDoItems = 2;
  static const int maxDoItems = 3;
}

/// A guide entry in the current language.
@immutable
class GuideEntry {
  GuideEntry({
    required this.id,
    required this.title,
    required this.purpose,
    required this.example,
    required List<String> doItems,
    List<String> related = const [],
    this.keywords = '',
    this.tourId,
  }) : doItems = List.unmodifiable(doItems),
       related = List.unmodifiable(related);

  final String id;
  final String title;
  final String purpose;
  final String example;
  final List<String> doItems;
  final List<String> related;
  final String keywords;
  final String? tourId;

  bool get hasTour => tourId != null;
}

/// What is wrong with a registry (empty = fine).
enum GuideProblem { badDoCount, unknownRelated, selfRelated, emptyId }

@immutable
class GuideRegistryIssue {
  const GuideRegistryIssue(this.entryId, this.problem, [this.detail]);

  final String entryId;
  final GuideProblem problem;
  final String? detail;

  @override
  String toString() => '$entryId: ${problem.name}${detail == null ? '' : ' ($detail)'}';
}

/// id → entry spec, in the order the guide lists them. Language-agnostic.
class GuideRegistry {
  GuideRegistry(Iterable<GuideEntrySpec> specs) : _specs = _index(specs);

  final Map<String, GuideEntrySpec> _specs;

  static Map<String, GuideEntrySpec> _index(Iterable<GuideEntrySpec> specs) {
    final out = <String, GuideEntrySpec>{};
    for (final s in specs) {
      if (out.containsKey(s.id)) throw ArgumentError('Duplicate guide entry id: ${s.id}');
      out[s.id] = s;
    }
    return Map.unmodifiable(out);
  }

  /// A registry of [specs] plus the ones in [other] (ids must not clash):
  /// every feature contributes its own specs and the app merges them.
  GuideRegistry merged(GuideRegistry other) => GuideRegistry([..._specs.values, ...other._specs.values]);

  Iterable<String> get ids => _specs.keys;
  int get length => _specs.length;
  bool contains(String id) => _specs.containsKey(id);
  GuideEntrySpec? spec(String id) => _specs[id];
  Iterable<GuideEntrySpec> get specs => _specs.values;

  /// The entry [id] in the language of [resolve], or null when unknown.
  GuideEntry? entry(String id, GuideTextResolver resolve) {
    final s = _specs[id];
    return s == null ? null : _build(s, resolve);
  }

  /// Every entry, in registry order.
  List<GuideEntry> all(GuideTextResolver resolve) => [for (final s in _specs.values) _build(s, resolve)];

  /// The entries [entry] points to (unknown ids are skipped).
  List<GuideEntry> relatedOf(GuideEntry entry, GuideTextResolver resolve) => [
    for (final id in entry.related)
      if (_specs[id] case final s?) _build(s, resolve),
  ];

  GuideEntry _build(GuideEntrySpec s, GuideTextResolver resolve) => GuideEntry(
    id: s.id,
    title: resolve(s.titleKey),
    purpose: resolve(s.purposeKey),
    example: resolve(s.exampleKey),
    doItems: [for (final k in s.doKeys) resolve(k)],
    related: s.relatedIds,
    keywords: s.keywordsKey == null ? '' : resolve(s.keywordsKey!),
    tourId: s.tourId,
  );

  /// Structural problems: wrong number of do-items, related ids that do not
  /// exist. Run in a test over the real registry so a typo cannot ship.
  List<GuideRegistryIssue> validate() {
    final issues = <GuideRegistryIssue>[];
    for (final s in _specs.values) {
      if (s.id.trim().isEmpty) issues.add(GuideRegistryIssue(s.id, GuideProblem.emptyId));
      if (s.doKeys.length < GuideEntrySpec.minDoItems || s.doKeys.length > GuideEntrySpec.maxDoItems) {
        issues.add(GuideRegistryIssue(s.id, GuideProblem.badDoCount, '${s.doKeys.length}'));
      }
      for (final r in s.relatedIds) {
        if (r == s.id) {
          issues.add(GuideRegistryIssue(s.id, GuideProblem.selfRelated));
        } else if (!_specs.containsKey(r)) {
          issues.add(GuideRegistryIssue(s.id, GuideProblem.unknownRelated, r));
        }
      }
    }
    return issues;
  }
}
