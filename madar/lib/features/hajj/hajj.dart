/// Part 18 «الحج والعمرة»: so far only the offline round counter.
///
/// * Pure domain: [RoundCounter], [RoundSession], [RoundKind], [TapResult].
/// * Persistence: [RoundCounterStore] ([KeyValueRoundCounterStore],
///   [MemoryRoundCounterStore]) and [RoundCounterPersister].
/// * Screen-sized widget: [RoundCounterView].
library;

export 'data/round_counter_store.dart';
export 'domain/round_counter.dart';
export 'presentation/round_counter_view.dart';
