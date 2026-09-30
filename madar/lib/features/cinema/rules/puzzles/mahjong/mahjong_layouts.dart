/// Mahjong Solitaire layouts.
///
/// Positions use half-tile units: a tile at `(x2, y2, z)` covers
/// `[x2, x2 + 2) × [y2, y2 + 2)` on layer `z`.
library;

/// One slot of a layout.
final class MahjongSlot {
  const MahjongSlot(this.x2, this.y2, this.z);
  final int x2;
  final int y2;
  final int z;

  @override
  bool operator ==(Object other) => other is MahjongSlot && other.x2 == x2 && other.y2 == y2 && other.z == z;

  @override
  int get hashCode => Object.hash(x2, y2, z);

  @override
  String toString() => '($x2,$y2,$z)';
}

enum MahjongLayoutId { turtle, pyramid, twinMinarets }

/// A layout with its precomputed blocking relations.
final class MahjongLayout {
  MahjongLayout._(this.id, List<MahjongSlot> slots) : slots = List.unmodifiable(slots) {
    final n = slots.length;
    for (var i = 0; i < n; i++) {
      final a = slots[i];
      final left = <int>[], right = <int>[], above = <int>[];
      for (var j = 0; j < n; j++) {
        if (i == j) continue;
        final b = slots[j];
        final overlapY = (b.y2 - a.y2).abs() < 2;
        if (b.z == a.z && overlapY) {
          if (b.x2 == a.x2 - 2) left.add(j);
          if (b.x2 == a.x2 + 2) right.add(j);
        }
        if (b.z == a.z + 1 && overlapY && (b.x2 - a.x2).abs() < 2) above.add(j);
      }
      _left.add(List.unmodifiable(left));
      _right.add(List.unmodifiable(right));
      _above.add(List.unmodifiable(above));
    }
    final blocked = List.generate(n, (_) => <int>[]);
    for (var i = 0; i < n; i++) {
      for (final j in [..._above[i], ..._left[i], ..._right[i]]) {
        blocked[j].add(i);
      }
    }
    _blocks.addAll([for (final b in blocked) List<int>.unmodifiable(b)]);
  }

  final MahjongLayoutId id;
  final List<MahjongSlot> slots;
  final List<List<int>> _left = [];
  final List<List<int>> _right = [];
  final List<List<int>> _above = [];
  final List<List<int>> _blocks = [];

  int get length => slots.length;

  List<int> leftOf(int i) => _left[i];
  List<int> rightOf(int i) => _right[i];
  List<int> above(int i) => _above[i];

  /// Slots that slot [i] covers or flanks (the ones it can block).
  List<int> blocks(int i) => _blocks[i];

  /// A present slot is free when nothing lies on it and one side is open.
  bool isFree(int i, List<bool> present) {
    if (!present[i]) return false;
    for (final j in _above[i]) {
      if (present[j]) return false;
    }
    var leftOpen = true;
    for (final j in _left[i]) {
      if (present[j]) {
        leftOpen = false;
        break;
      }
    }
    if (leftOpen) return true;
    for (final j in _right[i]) {
      if (present[j]) return false;
    }
    return true;
  }

  static final Map<MahjongLayoutId, MahjongLayout> _cache = {};

  static MahjongLayout of(MahjongLayoutId id) => _cache[id] ??= MahjongLayout._(id, switch (id) {
    MahjongLayoutId.turtle => _turtle(),
    MahjongLayoutId.pyramid => _pyramid(),
    MahjongLayoutId.twinMinarets => _twinMinarets(),
  });

  /// Adds a rectangle of tiles; coordinates in half units.
  static void _rect(List<MahjongSlot> out, int x2, int y2, int cols, int rows, int z) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        out.add(MahjongSlot(x2 + 2 * c, y2 + 2 * r, z));
      }
    }
  }

  /// The traditional 144-tile turtle.
  static List<MahjongSlot> _turtle() {
    final s = <MahjongSlot>[];
    // Layer 0: rows of 12, 8, 10, 12, 12, 10, 8, 12 plus the three ends.
    const rows = [(1, 12), (3, 8), (2, 10), (1, 12), (1, 12), (2, 10), (3, 8), (1, 12)];
    for (var y = 0; y < rows.length; y++) {
      _rect(s, rows[y].$1 * 2, y * 2, rows[y].$2, 1, 0);
    }
    s
      ..add(const MahjongSlot(0, 7, 0))
      ..add(const MahjongSlot(26, 7, 0))
      ..add(const MahjongSlot(28, 7, 0));
    _rect(s, 8, 2, 6, 6, 1);
    _rect(s, 10, 4, 4, 4, 2);
    _rect(s, 12, 6, 2, 2, 3);
    s.add(const MahjongSlot(13, 7, 4));
    return s;
  }

  /// A stepped pyramid (132 tiles).
  static List<MahjongSlot> _pyramid() {
    final s = <MahjongSlot>[];
    _rect(s, 0, 0, 12, 6, 0);
    _rect(s, 2, 2, 10, 4, 1);
    _rect(s, 4, 4, 8, 2, 2);
    _rect(s, 8, 5, 4, 1, 3);
    return s;
  }

  /// Two stepped towers joined by a bridge (78 tiles).
  static List<MahjongSlot> _twinMinarets() {
    final s = <MahjongSlot>[];
    for (final ox in const [0, 18]) {
      _rect(s, ox, 0, 4, 4, 0);
      _rect(s, ox + 1, 1, 3, 3, 1);
      _rect(s, ox + 2, 2, 2, 2, 2);
      s.add(MahjongSlot(ox + 3, 3, 3));
    }
    _rect(s, 8, 0, 5, 1, 0);
    _rect(s, 8, 6, 5, 1, 0);
    _rect(s, 8, 3, 5, 1, 0);
    _rect(s, 10, 3, 3, 1, 1);
    return s;
  }
}
