import 'dart:ui' as ui;

/// Images of rendered pages, for the curl. Each entry is valid only for the
/// "signature" it was taken under (size, pixel ratio, text scale, paper,
/// content version ...): a different signature is a miss, never a stale image.
class PageSnapshotCache {
  final Map<int, _Entry> _entries = <int, _Entry>{};

  int get length => _entries.length;

  List<int> get pages => (_entries.keys.toList()..sort());

  /// The image of [page] if one exists for [signature], else null.
  ui.Image? lookup(int page, Object signature) {
    final e = _entries[page];
    if (e == null || e.signature != signature) return null;
    return e.image;
  }

  bool has(int page, Object signature) => lookup(page, signature) != null;

  /// Keeps [image] (the cache owns it from now on and disposes it).
  void store(int page, ui.Image image, Object signature) {
    _entries.remove(page)?.image.dispose();
    _entries[page] = _Entry(image, signature);
  }

  /// Drops one page (its content changed) or all of them.
  void invalidate([int? page]) {
    if (page == null) {
      clear();
    } else {
      _entries.remove(page)?.image.dispose();
    }
  }

  /// Drops every entry that was taken under another signature.
  void dropStale(Object signature) {
    _entries.removeWhere((_, e) {
      final stale = e.signature != signature;
      if (stale) e.image.dispose();
      return stale;
    });
  }

  /// Keeps only pages within [radius] of [center]; the rest are freed. A
  /// page image can be several megabytes, so only the neighbours stay.
  void evictFar(int center, int radius) {
    _entries.removeWhere((p, e) {
      final far = (p - center).abs() > radius;
      if (far) e.image.dispose();
      return far;
    });
  }

  /// Keeps exactly [keep]; everything else is freed.
  void retainOnly(Set<int> keep) {
    _entries.removeWhere((p, e) {
      final drop = !keep.contains(p);
      if (drop) e.image.dispose();
      return drop;
    });
  }

  void clear() {
    for (final e in _entries.values) {
      e.image.dispose();
    }
    _entries.clear();
  }

  void dispose() => clear();
}

class _Entry {
  _Entry(this.image, this.signature);
  final ui.Image image;
  final Object signature;
}
