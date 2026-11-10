/// Conversations in the encrypted database, as JSON in `key_values` (no
/// schema change): one entry per conversation plus a small index for the
/// list. Bounded: at most [ConversationStore.maxConversations] (oldest
/// dropped), each with at most [Conversation.maxMessages] messages.
///
/// A deleted conversation stays deleted: a late save from a screen that
/// still has it open is dropped (only undo – [ConversationStore.restore] –
/// brings it back), and [ConversationStore.deletions] tells open screens to
/// let go of it.
library;

import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/key_value_repository.dart';
import '../domain/ai_settings.dart';
import '../domain/conversation.dart';

class ConversationStore {
  ConversationStore(this.db) : kv = KeyValueRepository(db);

  final MadarDatabase db;
  final KeyValueRepository kv;

  /// `key_values` key of the index.
  static const String indexKey = 'aiChat.index';

  /// Prefix of each conversation's key.
  static const String conversationPrefix = 'aiChat.c.';

  /// Most conversations kept (the least recently used go first).
  static const int maxConversations = 60;

  static String keyOf(String id) => '$conversationPrefix$id';

  /// Ids deleted through this store (until undone).
  final Set<String> _deleted = {};

  final StreamController<Set<String>?> _deletions = StreamController<Set<String>?>.broadcast(sync: true);

  /// Ids just deleted (null = every conversation). Delivered synchronously,
  /// before the delete call completes.
  Stream<Set<String>?> get deletions => _deletions.stream;

  /// Every `key_values` key the AI chat writes (for tests and audits).
  static bool ownsKey(String key) =>
      key == indexKey || key == AiSettings.storageKey || key.startsWith(conversationPrefix);

  static List<ConversationMeta> _decodeIndex(Object? json) {
    final list = <ConversationMeta>[
      if (json is List)
        for (final e in json) ?ConversationMeta.fromJson(e),
    ];
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// The list, newest first.
  Stream<List<ConversationMeta>> watchIndex() => kv.watchJson(indexKey).map(_decodeIndex);

  Future<List<ConversationMeta>> index() async => _decodeIndex(await kv.getJson(indexKey));

  Future<Conversation?> load(String id) async => Conversation.fromJson(await kv.getJson(keyOf(id)));

  /// Saves [c] (an empty conversation is not stored) and updates the index,
  /// dropping the oldest conversations beyond the limit.
  Future<void> save(Conversation c) async {
    if (c.isEmpty || _deleted.contains(c.id)) return;
    await db.transaction(() async {
      // Deleted while this save waited for the database.
      if (_deleted.contains(c.id)) return;
      await kv.setJson(keyOf(c.id), c.toJson());
      final list = [
        for (final m in await index())
          if (m.id != c.id) m,
      ]..insert(0, ConversationMeta.of(c));
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      while (list.length > maxConversations) {
        final dropped = list.removeLast();
        await kv.remove(keyOf(dropped.id));
      }
      await kv.setJson(indexKey, [for (final m in list) m.toJson()]);
    });
  }

  /// Renames [id]; returns the updated conversation.
  Future<Conversation?> rename(String id, String title) async {
    final c = await load(id);
    if (c == null || _deleted.contains(id)) return null;
    final clean = Conversation.cleanTitle(title);
    final next = c.copyWith(title: clean.isEmpty ? c.title : clean, titleEdited: clean.isNotEmpty);
    await db.transaction(() async {
      await kv.setJson(keyOf(id), next.toJson());
      final list = [
        for (final m in await index())
          m.id == id
              ? ConversationMeta(
                  id: m.id,
                  title: next.title,
                  updatedAt: m.updatedAt,
                  messageCount: m.messageCount,
                  preview: m.preview,
                )
              : m,
      ];
      await kv.setJson(indexKey, [for (final m in list) m.toJson()]);
    });
    return next;
  }

  /// Deletes [id]; returns it for undo.
  Future<Conversation?> delete(String id) async {
    _deleted.add(id);
    final c = await load(id);
    await db.transaction(() async {
      await kv.remove(keyOf(id));
      final list = [
        for (final m in await index())
          if (m.id != id) m,
      ];
      await kv.setJson(indexKey, [for (final m in list) m.toJson()]);
    });
    if (!_deletions.isClosed) _deletions.add({id});
    return c;
  }

  /// Deletes every conversation; returns them for undo.
  Future<List<Conversation>> deleteAll() async {
    final all = <Conversation>[];
    await db.transaction(() async {
      for (final m in await index()) {
        _deleted.add(m.id);
        final c = await load(m.id);
        if (c != null) all.add(c);
      }
      await (db.delete(db.keyValues)..where((t) => t.key.like('$conversationPrefix%'))).go();
      await kv.remove(indexKey);
    });
    if (!_deletions.isClosed) _deletions.add(null);
    return all;
  }

  /// Puts [conversations] back (undo).
  Future<void> restore(Iterable<Conversation> conversations) async {
    for (final c in conversations) {
      _deleted.remove(c.id);
      await save(c);
    }
  }
}
