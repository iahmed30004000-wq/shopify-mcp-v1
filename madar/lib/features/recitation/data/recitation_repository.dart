import 'package:drift/drift.dart' show Value;

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../domain/listening_tracker.dart';
import '../domain/recitation_settings.dart';

/// Recitation settings in the encrypted key/value store.
class RecitationSettingsRepository {
  RecitationSettingsRepository(this.keyValues);

  final KeyValueRepository keyValues;

  Future<RecitationSettings> load() async =>
      RecitationSettings.fromJson(await keyValues.getJson(RecitationSettings.storageKey));

  Stream<RecitationSettings> watch() =>
      keyValues.watchJson(RecitationSettings.storageKey).map(RecitationSettings.fromJson).distinct();

  Future<void> save(RecitationSettings settings) => keyValues.setJson(RecitationSettings.storageKey, settings.toJson());
}

/// Where listening sessions go.
abstract class ListeningLogger {
  Future<void> log(ListeningSummary summary);
}

/// Logs a session to QuranSessions (mode listen) and the activity stream
/// (`quran.listen`, faith planet), linked so the entry can be removed with
/// the session.
class DbListeningLogger implements ListeningLogger {
  DbListeningLogger(this.repos);

  final Repositories repos;

  static const activityKind = 'quran.listen';
  static const planetKey = 'faith';

  @override
  Future<void> log(ListeningSummary s) async {
    final row = await repos.quranSessions.insert(
      QuranSessionsCompanion.insert(
        day: s.startedAt,
        mode: const Value(QuranSessionMode.listen),
        fromSurah: s.first.surah,
        fromAyah: s.first.ayah,
        toSurah: s.last.surah,
        toAyah: s.last.ayah,
        ayahCount: Value(s.ayat),
        seconds: Value(s.listened.inSeconds),
      ),
    );
    await repos.activity.log(
      planetKey: planetKey,
      kind: activityKind,
      refTable: 'quran_sessions',
      refId: row.id,
      at: s.endedAt,
      value: s.listened.inSeconds / 60,
      payload: {
        'seconds': s.listened.inSeconds,
        'ayat': s.ayat,
        'from': '${s.first}',
        'to': '${s.last}',
        'reciter': s.reciterId,
      },
    );
  }
}
