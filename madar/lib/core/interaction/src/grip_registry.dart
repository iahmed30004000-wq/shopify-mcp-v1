/// Pointers that went down on a reorder grip. [ActionableItem] ignores them so
/// a grip inside an item starts a reorder drag instead of a swipe, tap or
/// long-press. The grip's listener sits deeper in the hit-test path than the
/// item's recognizers, so it always registers the pointer first.
abstract final class GripPointerRegistry {
  static final Set<int> _pointers = <int>{};

  static void add(int pointer) {
    if (_pointers.length > 16) _pointers.clear();
    _pointers.add(pointer);
  }

  static void remove(int pointer) => _pointers.remove(pointer);

  static bool contains(int pointer) => _pointers.contains(pointer);
}
