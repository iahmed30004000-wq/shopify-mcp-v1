/// Where the daily chat is kept: JSON in `key_values` inside the encrypted
/// database – one entry per day plus a small index – exactly like the AI
/// chat's conversations, so Part 7 needs no schema change.
///
/// Bounded: at most [maxDays] days, the oldest dropped first.
library;

import '../../../core/db/database.dart';
import '../../../core/db/repositories/key_value_repository.dart';
import '../domain/day_chat_journal.dart';

class DayChatStore {
  DayChatStore(this.db) : kv = KeyValueRepository(db);

  final MadarDatabase db;
  final KeyValueRepository kv;

  /// `key_values` key of the index (the days that have a chat).
  static const String indexKey = 'dayChat.index';

  /// Prefix of a day's entry.
  static const String dayPrefix = 'dayChat.d.';

  /// How many days of chat are kept.
  static const int maxDays = 180;

  static String keyOf(DateTime day) => '$dayPrefix${DayChatDay.keyOf(day)}';

  /// Every `key_values` key the daily chat writes (for tests and audits).
  static bool ownsKey(String key) => key == indexKey || key.startsWith(dayPrefix);

  /// The days with a chat, newest first.
  Future<List<DateTime>> days() async => _decodeIndex(await kv.getJson(indexKey));

  Stream<List<DateTime>> watchDays() => kv.watchJson(indexKey).map(_decodeIndex);

  static List<DateTime> _decodeIndex(Object? json) {
    final out = <DateTime>[
      if (json is List)
        for (final e in json)
          if (e is String) ?DayChatDay.dayOfKey(e),
    ];
    out.sort((a, b) => b.compareTo(a));
    return out;
  }

  Future<DayChatDay> day(DateTime day) async => DayChatDay.fromJson(day, await kv.getJson(keyOf(day)));

  Stream<DayChatDay> watchDay(DateTime day) =>
      kv.watchJson(keyOf(day)).map((json) => DayChatDay.fromJson(day, json));

  /// Writes [change] of that day's chat, in one transaction with the index.
  Future<DayChatDay> update(DateTime day, DayChatDay Function(DayChatDay current) change) =>
      db.transaction(() async {
        final current = await this.day(day);
        final next = change(current);
        if (next.isEmpty) {
          await kv.remove(keyOf(day));
          await _writeIndex([
            for (final d in await days())
              if (DayChatDay.keyOf(d) != DayChatDay.keyOf(day)) d,
          ]);
          return next;
        }
        await kv.setJson(keyOf(day), next.toJson());
        final listed = await days();
        if (!listed.any((d) => DayChatDay.keyOf(d) == DayChatDay.keyOf(day))) {
          final all = [...listed, next.day]..sort((a, b) => b.compareTo(a));
          while (all.length > maxDays) {
            final dropped = all.removeLast();
            await kv.remove(keyOf(dropped));
          }
          await _writeIndex(all);
        }
        return next;
      });

  Future<void> _writeIndex(List<DateTime> days) =>
      kv.setJson(indexKey, [for (final d in days) DayChatDay.keyOf(d)]);

  /// Forgets one day (the chat screen's "clear this day"); his data stays.
  Future<void> forget(DateTime day) => update(day, (_) => DayChatDay(day: day));
}
