import 'package:flutter/foundation.dart';

import '../../prayer/domain/cities.dart' show CityText;

/// Packing categories. The standard ones are stored by key and shown in the
/// UI language; anything else is a category the user typed, stored as is.
abstract final class PackingCategories {
  static const documents = 'documents';
  static const clothes = 'clothes';
  static const toiletries = 'toiletries';
  static const health = 'health';
  static const electronics = 'electronics';
  static const prayer = 'prayer';
  static const misc = 'misc';

  /// Display order of the standard categories.
  static const standard = [documents, clothes, toiletries, health, electronics, prayer, misc];

  static bool isStandard(String? category) => category != null && standard.contains(category);

  /// The category an item is listed under (blank → [misc]).
  static String of(String? category) {
    final c = category?.trim();
    return c == null || c.isEmpty ? misc : c;
  }
}

/// Packed / total of a list.
@immutable
class PackingProgress {
  const PackingProgress(this.packed, this.total);

  factory PackingProgress.of(Iterable<bool> packedFlags) {
    var total = 0, packed = 0;
    for (final p in packedFlags) {
      total++;
      if (p) packed++;
    }
    return PackingProgress(packed, total);
  }

  static const empty = PackingProgress(0, 0);

  final int packed;
  final int total;

  int get remaining => total - packed;

  /// 0…1 (0 for an empty list).
  double get fraction => total == 0 ? 0 : packed / total;

  /// Everything packed (an empty list is never complete).
  bool get complete => total > 0 && packed == total;

  bool get isEmpty => total == 0;

  /// Whether going from [before] to this completes the list (the moment to
  /// celebrate).
  bool completes(PackingProgress before) => complete && !before.complete;

  @override
  bool operator ==(Object other) => other is PackingProgress && other.packed == packed && other.total == total;

  @override
  int get hashCode => Object.hash(packed, total);

  @override
  String toString() => 'PackingProgress($packed/$total)';
}

/// One category of a packing list.
@immutable
class PackingGroup<T> {
  const PackingGroup(this.category, this.items, this.progress);

  final String category;
  final List<T> items;
  final PackingProgress progress;
}

/// A row of the grouped packing list: a category header or an item.
sealed class PackingEntry<T> {
  const PackingEntry();
}

final class PackingHeader<T> extends PackingEntry<T> {
  const PackingHeader(this.group);

  final PackingGroup<T> group;

  String get category => group.category;

  @override
  bool operator ==(Object other) => other is PackingHeader<T> && other.category == category;

  @override
  int get hashCode => category.hashCode;
}

final class PackingItemEntry<T> extends PackingEntry<T> {
  const PackingItemEntry(this.item, this.category);

  final T item;
  final String category;

  @override
  bool operator ==(Object other) => other is PackingItemEntry<T> && other.item == item;

  @override
  int get hashCode => item.hashCode;
}

/// The result of dropping a packing row somewhere else.
@immutable
class PackingReorder<T> {
  const PackingReorder(this.order, this.recategorized);

  /// Every item in its new order.
  final List<T> order;

  /// Items dropped under another category's header → that category.
  final Map<T, String> recategorized;
}

/// Grouping of a packing list (pure, generic over the item type).
abstract final class PackingLayout {
  /// Items grouped by category: the standard categories in their order,
  /// then the user's own in order of first appearance. Items keep their
  /// relative order inside a group.
  static List<PackingGroup<T>> group<T>(
    List<T> items, {
    required String? Function(T item) categoryOf,
    required bool Function(T item) packedOf,
  }) {
    final byCategory = <String, List<T>>{};
    for (final item in items) {
      byCategory.putIfAbsent(PackingCategories.of(categoryOf(item)), () => []).add(item);
    }
    final ordered = [
      for (final c in PackingCategories.standard)
        if (c != PackingCategories.misc && byCategory.containsKey(c)) c,
      for (final c in byCategory.keys)
        if (!PackingCategories.isStandard(c)) c,
      if (byCategory.containsKey(PackingCategories.misc)) PackingCategories.misc,
    ];
    return [
      for (final c in ordered)
        PackingGroup<T>(c, List.unmodifiable(byCategory[c]!), PackingProgress.of(byCategory[c]!.map(packedOf))),
    ];
  }

  /// Headers and items, flattened for one reorderable list.
  static List<PackingEntry<T>> entries<T>(List<PackingGroup<T>> groups) => [
    for (final g in groups) ...[PackingHeader<T>(g), for (final i in g.items) PackingItemEntry<T>(i, g.category)],
  ];

  /// Reads a dropped order back: each item belongs to the header above it
  /// (an item dropped above the first header joins the first group).
  static PackingReorder<T> applyReorder<T>(List<PackingEntry<T>> newOrder) {
    final order = <T>[];
    final moved = <T, String>{};
    String? current;
    final firstHeader = newOrder.whereType<PackingHeader<T>>().firstOrNull?.category;
    final leading = <PackingItemEntry<T>>[];
    for (final e in newOrder) {
      switch (e) {
        case PackingHeader<T>():
          current = e.category;
          if (leading.isNotEmpty) {
            // Items above the first header open its group.
            for (final l in leading) {
              order.add(l.item);
              if (l.category != current) moved[l.item] = current;
            }
            leading.clear();
          }
        case PackingItemEntry<T>():
          if (current == null) {
            leading.add(e);
          } else {
            order.add(e.item);
            if (e.category != current) moved[e.item] = current;
          }
      }
    }
    for (final l in leading) {
      order.add(l.item);
      if (firstHeader != null && l.category != firstHeader) moved[l.item] = firstHeader;
    }
    // Groups are displayed in category order, so the stored order is the
    // order of the regrouped list.
    return PackingReorder(order, moved);
  }
}

/// An item of a packing template: stored in `PackingTemplates.items` as its
/// body, or `category␟body` (U+001F, the unit separator) when it has one.
@immutable
class PackingTemplateItem {
  const PackingTemplateItem(this.body, [this.category]);

  static const separator = '\u001F';

  factory PackingTemplateItem.decode(String raw) {
    final i = raw.indexOf(separator);
    if (i < 0) return PackingTemplateItem(raw.trim());
    final category = raw.substring(0, i).trim();
    return PackingTemplateItem(raw.substring(i + 1).trim(), category.isEmpty ? null : category);
  }

  final String body;
  final String? category;

  String encode() {
    final c = category?.trim();
    return c == null || c.isEmpty || c == PackingCategories.misc ? body.trim() : '$c$separator${body.trim()}';
  }

  PackingTemplateItem copyWith({String? body, Object? category = _keep}) =>
      PackingTemplateItem(body ?? this.body, identical(category, _keep) ? this.category : category as String?);

  @override
  bool operator ==(Object other) => other is PackingTemplateItem && other.body == body && other.category == category;

  @override
  int get hashCode => Object.hash(body, category);

  @override
  String toString() => 'PackingTemplateItem($category: $body)';
}

const Object _keep = Object();

/// Template ↔ trip list transforms (pure).
abstract final class PackingTemplateMath {
  static List<PackingTemplateItem> decodeAll(Iterable<String> raw) => [
    for (final r in raw)
      if (r.trim().isNotEmpty) PackingTemplateItem.decode(r),
  ];

  static List<String> encodeAll(Iterable<PackingTemplateItem> items) => [
    for (final i in items)
      if (i.body.trim().isNotEmpty) i.encode(),
  ];

  /// Matching key of an item body: case-, space-, diacritic- and
  /// hamza-insensitive ("Phone charger" = "phone  charger", «شاحن» = «شاحن»).
  static String key(String body) => CityText.fold(body);

  /// The items of [templates] (in order) that are not in [existingBodies]
  /// and not repeated: applying two templates that both list a charger adds
  /// one charger, and none if the trip already has one.
  static List<PackingTemplateItem> merge(
    Iterable<List<PackingTemplateItem>> templates, {
    Iterable<String> existingBodies = const [],
  }) {
    final seen = {for (final b in existingBodies) key(b)};
    final out = <PackingTemplateItem>[];
    for (final t in templates) {
      for (final item in t) {
        final k = key(item.body);
        if (k.isEmpty || !seen.add(k)) continue;
        out.add(item);
      }
    }
    return out;
  }
}
