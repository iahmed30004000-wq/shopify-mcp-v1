import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../engine/core/score.dart';

/// Best scores per game in the encrypted key/value store (one JSON map under
/// [key]). Owner: hall.
class KvScoreSink implements ScoreSink {
  KvScoreSink(this.kv);

  final KeyValueRepository kv;
  static const key = 'cinema.best';

  Future<Map<String, Object?>> _read() async {
    final raw = await kv.getJson(key);
    return raw is Map ? Map<String, Object?>.from(raw) : <String, Object?>{};
  }

  @override
  Future<void> submit(GameResult result) async {
    final map = await _read();
    final prev = (map[result.gameId] as num?)?.toInt();
    if (prev != null && prev >= result.score) return;
    map[result.gameId] = result.score;
    await kv.setJson(key, map);
  }

  @override
  Future<int?> best(String gameId) async => ((await _read())[gameId] as num?)?.toInt();
}

/// The persistent score sink the hall hands to every game it launches.
final hallScoreSinkProvider = Provider<ScoreSink>((ref) => KvScoreSink(ref.watch(repositoriesProvider).keyValues));
