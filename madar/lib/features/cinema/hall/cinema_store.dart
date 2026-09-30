import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/core/score.dart';
import 'cinema_records.dart';

/// The persistent score sink the hall hands to every game it launches: the
/// records store (best score, plays, wins and play time per game in the
/// encrypted key/value table, see [KvCinemaRecordsStore]).
final hallScoreSinkProvider = Provider<ScoreSink>((ref) => ref.watch(cinemaRecordsStoreProvider));

/// Former name of the key/value score sink (best scores only, key
/// `cinema.best`). It now keeps full records under `cinema.records` and
/// folds the old map in on first use.
typedef KvScoreSink = KvCinemaRecordsStore;
