// The colours on a built-in page: a map from region to colour that is the
// result of a list of fills (so undo and save/restore are the same as for
// pictures: replay the list).
import 'package:flutter/foundation.dart' show immutable;

import 'vector_pages.dart';

@immutable
class RegionFill {
  const RegionFill(this.region, this.argb);

  /// Index into [VectorPage.regions].
  final int region;

  /// 0 erases (back to paper).
  final int argb;

  List<int> toJson() => [region, argb];

  static RegionFill? fromJson(Object? j) {
    if (j is List && j.length == 2 && j[0] is int && j[1] is int) return RegionFill(j[0] as int, j[1] as int);
    return null;
  }

  @override
  bool operator ==(Object other) => other is RegionFill && other.region == region && other.argb == argb;

  @override
  int get hashCode => Object.hash(region, argb);
}

class VectorColouring {
  VectorColouring(this.page, [List<RegionFill> ops = const []]) {
    replay(ops);
  }

  final VectorPage page;
  final Map<int, int> _colours = {};
  final List<RegionFill> _ops = [];

  /// Region -> ARGB for the regions that are coloured.
  Map<int, int> get colours => Map.unmodifiable(_colours);

  List<RegionFill> get ops => List.unmodifiable(_ops);

  bool get canUndo => _ops.isNotEmpty;

  /// Colours [region] ([argb] 0 erases). False when the index is not a region
  /// of the page, or when nothing would change.
  bool fill(int region, int argb) {
    if (region < 0 || region >= page.regions.length) return false;
    if ((_colours[region] ?? 0) == argb) return false;
    _apply(region, argb);
    _ops.add(RegionFill(region, argb));
    return true;
  }

  bool undo() {
    if (_ops.isEmpty) return false;
    replay(_ops.sublist(0, _ops.length - 1));
    return true;
  }

  void clear() {
    _colours.clear();
    _ops.clear();
  }

  void replay(List<RegionFill> ops) {
    clear();
    for (final op in ops) {
      if (op.region < 0 || op.region >= page.regions.length) continue;
      _apply(op.region, op.argb);
      _ops.add(op);
    }
  }

  void _apply(int region, int argb) {
    if (argb == 0) {
      _colours.remove(region);
    } else {
      _colours[region] = argb;
    }
  }
}
