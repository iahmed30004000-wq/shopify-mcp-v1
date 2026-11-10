// Reads the religious content a sheikh has supplied: assets/kids_religious/.
//
// Layout: `index.json` = {"version":1,"files":["x.json", ...]} and each file =
// {"items":[ {...KidsReligiousItem json...}, ... ]}. Only an empty index.json
// ships today. The loader takes an [AssetBundle] (the pubspec cannot be edited
// from this folder) and tolerates every file being missing: no content simply
// means the calm «قريبًا».
import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/kids_religious_item.dart';

const String kidsReligiousDir = 'assets/kids_religious';

class KidsReligiousLoadResult {
  const KidsReligiousLoadResult(this.items, this.problems);

  static const empty = KidsReligiousLoadResult([], []);

  /// Every item that parsed (approved or not), in file order.
  final List<KidsReligiousItem> items;

  /// Parse and contract problems. The build-failing test demands none; at run
  /// time an item with a problem is dropped, never shown.
  final List<KidsContentProblem> problems;

  /// Items a child may see: valid AND signed off.
  List<KidsReligiousItem> get approved {
    final bad = {for (final p in problems) p.itemId};
    return [
      for (final i in items)
        if (i.approved && !bad.contains(i.id)) i,
    ];
  }
}

Future<String?> _tryLoad(AssetBundle bundle, String key) async {
  try {
    return await bundle.loadString(key, cache: false);
  } on Object {
    return null; // missing file: tolerated by design
  }
}

/// Loads every file listed in [dir]/index.json. Never throws.
Future<KidsReligiousLoadResult> loadKidsReligious(AssetBundle bundle, {String dir = kidsReligiousDir}) async {
  final indexText = await _tryLoad(bundle, '$dir/index.json');
  if (indexText == null) return KidsReligiousLoadResult.empty;

  final problems = <KidsContentProblem>[];
  final items = <KidsReligiousItem>[];
  final List<Object?> files;
  try {
    files = ((jsonDecode(indexText) as Map)['files'] as List?)?.cast<Object?>() ?? const [];
  } on Object catch (e) {
    return KidsReligiousLoadResult(const [], [KidsContentProblem('index.json', 'unreadable: $e')]);
  }

  for (final f in files) {
    final name = '$f';
    final text = await _tryLoad(bundle, '$dir/$name');
    if (text == null) {
      problems.add(KidsContentProblem(name, 'listed in index.json but missing'));
      continue;
    }
    try {
      final list = (jsonDecode(text) as Map)['items'] as List? ?? const [];
      for (final raw in list) {
        try {
          items.add(KidsReligiousItem.fromJson((raw as Map).cast<String, Object?>()));
        } on Object catch (e) {
          problems.add(KidsContentProblem('$name#${(raw is Map ? raw['id'] : null) ?? '?'}', 'unreadable item: $e'));
        }
      }
    } on Object catch (e) {
      problems.add(KidsContentProblem(name, 'unreadable file: $e'));
    }
  }
  problems.addAll(validateKidsReligiousItems(items));
  return KidsReligiousLoadResult(List.unmodifiable(items), List.unmodifiable(problems));
}
