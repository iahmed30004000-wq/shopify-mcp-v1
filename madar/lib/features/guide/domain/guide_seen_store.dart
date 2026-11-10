/// Remembers which guide things the person has already seen (tour ids, the
/// first-run marker …). Pure Dart: the app adapts its own small-flag storage
/// to this tiny contract (see the integration notes in the guide README
/// comment of `guide.dart`).
library;

abstract class GuideSeenStore {
  /// The ids seen so far.
  Future<Set<String>> read();

  /// Replaces the whole set.
  Future<void> write(Set<String> ids);
}

/// Convenience over the two-method contract.
extension GuideSeenStoreOps on GuideSeenStore {
  Future<bool> isSeen(String id) async => (await read()).contains(id);

  Future<void> markSeen(String id) async {
    final ids = await read();
    if (ids.contains(id)) return;
    await write({...ids, id});
  }

  /// Forgets [id] so it runs again (a replay from «؟» does not need this;
  /// "reset the guide" in settings does).
  Future<void> forget(String id) async {
    final ids = await read();
    if (!ids.contains(id)) return;
    await write({...ids}..remove(id));
  }
}

/// Keeps the set in memory: tests, previews, and the default until the app
/// plugs in its persistent store.
class MemoryGuideSeenStore extends GuideSeenStore {
  MemoryGuideSeenStore([Iterable<String> initial = const []]) : _ids = {...initial};

  Set<String> _ids;

  @override
  Future<Set<String>> read() async => {..._ids};

  @override
  Future<void> write(Set<String> ids) async => _ids = {...ids};
}
