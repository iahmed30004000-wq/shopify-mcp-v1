/// «التسميع» · the providers the screens of step 2 will read.
///
/// Thin by design: the engine is pure Dart and the service is the only
/// thing that touches the database, so there is nothing to compute here.
///
/// **The recogniser is deliberately not provided as if it existed.**
/// [tasmeeRecogniserProvider] throws until step 2 overrides it with a real
/// on-device model, and [tasmeeAvailabilityProvider] answers
/// [RecogniserTrouble.notImplemented] without touching it – so a screen
/// that asks "can I listen?" gets an honest no and falls back to reading
/// and listening, exactly as a phone that cannot run the model would.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/quran/ayah.dart';
import '../../home/home_providers.dart';
import '../../quran/data/quran_providers.dart';
import '../domain/alignment.dart';
import '../domain/ayah_words.dart';
import '../domain/mistake_log.dart';
import '../domain/recite_to_find.dart';
import '../domain/recogniser.dart';
import '../domain/tasmee_settings.dart';
import 'tasmee_service.dart';

/// «التسميع»'s wall clock (follows the app's, so a test freezes them all at
/// once).
final tasmeeClockProvider = Provider<DateTime Function()>((ref) => ref.watch(homeClockProvider));

/// Every read and write of the recitation log.
final tasmeeServiceProvider = Provider<TasmeeService>(
  (ref) => TasmeeService(ref.watch(repositoriesProvider), clock: ref.watch(tasmeeClockProvider)),
);

/// His own choices (the experimental tashkeel check, the confidence floor,
/// the blanks, hiding the ayah markers).
final tasmeeSettingsProvider = StreamProvider<TasmeeSettings>(
  (ref) => ref.watch(tasmeeServiceProvider).watchSettings(),
);

/// The alignment options his settings imply.
final tasmeeAlignmentProvider = Provider<AlignmentOptions>(
  (ref) => (ref.watch(tasmeeSettingsProvider).value ?? const TasmeeSettings()).alignment,
);

/// The whole log, newest session first, each with its ayat and mistakes.
final tasmeeLogProvider = StreamProvider<List<TasmeeSession>>(
  (ref) => ref.watch(tasmeeServiceProvider).watchLog(),
);

/// The progress statistics, read off the log.
final tasmeeStatsProvider = StreamProvider<TasmeeStats>(
  (ref) => ref.watch(tasmeeServiceProvider).watchStats(),
);

/// The words of one range of the verified text, with the basmala allowed
/// before them.
final tasmeeTargetProvider = FutureProvider.family<RecitationTarget, AyahRange>(
  (ref, range) => TasmeeTargets.range(ref.watch(quranStoreProvider), range),
);

/// «شازام القرآن»'s n-gram index over the verified text. Built once, on
/// first use – it is the only thing in «التسميع» that costs memory.
final reciteIndexProvider = FutureProvider<ReciteIndex>(
  (ref) => TasmeeTargets.reciteIndex(ref.watch(quranStoreProvider)),
);

/// The on-device recogniser. **Not implemented in this build**: step 2
/// overrides this provider with the real model and nothing else changes.
final tasmeeRecogniserProvider = Provider<QuranRecogniser>((ref) {
  throw UnimplementedError(
    'No on-device recitation model in this build (Part 13 step 2). '
    'Override tasmeeRecogniserProvider, and read tasmeeAvailabilityProvider first.',
  );
});

/// Whether he can recite into the microphone at all – answered **without**
/// opening it and without building a recogniser, so a screen can degrade to
/// reading and listening instead of crashing.
final tasmeeAvailabilityProvider = FutureProvider<RecogniserAvailability>((ref) async {
  try {
    return await ref.watch(tasmeeRecogniserProvider).availability();
  } on UnimplementedError {
    return const RecogniserAvailability(
      trouble: RecogniserTrouble.notImplemented,
      detail: 'No on-device recitation model in this build',
    );
  }
});
