import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/quran/quran_audio.dart';
import '../../../recitation/application/recitation_providers.dart'
    show recitationDownloadsProvider, recitationSettingsProvider;
import '../../../recitation/domain/reciters.dart';
import '../../core/kids_section.dart' show kidsReligiousUnlockedProvider;
import '../data/kids_audio.dart';
import '../data/kids_religious_loader.dart';
import '../domain/kids_religious_item.dart';

/// Where the sheikh's content files are read from (the app bundle).
final kidsReligiousBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// Everything in assets/kids_religious/, parsed and checked.
final kidsReligiousContentProvider = FutureProvider<KidsReligiousLoadResult>(
  (ref) => loadKidsReligious(ref.watch(kidsReligiousBundleProvider)),
);

/// What a child may see: valid, signed off, and only while the religious gate
/// is open. Every kids faith screen reads items ONLY through this provider, so
/// "unapproved => not rendered" and "flag closed => nothing" hold in one place.
final kidsApprovedItemsProvider = Provider<AsyncValue<List<KidsReligiousItem>>>((ref) {
  if (!ref.watch(kidsReligiousUnlockedProvider)) return const AsyncData([]);
  return ref.watch(kidsReligiousContentProvider).whenData((r) => r.approved);
});

/// Approved items of one [kind], in their `order`.
List<KidsReligiousItem> kidsItemsOfKind(List<KidsReligiousItem> all, KidsReligiousKind kind) =>
    [for (final i in all) if (i.kind == kind) i]..sort((a, b) => a.order.compareTo(b.order));

/// Local-only recitation (see [LocalOnlyKidsAudio]). Tests override it.
final kidsAyahAudioProvider = Provider<KidsAyahAudio>(
  (ref) => LocalOnlyKidsAudio(
    files: ref.watch(recitationDownloadsProvider),
    audio: ref.watch(quranAudioProvider),
    reciter: () => ref.read(recitationSettingsProvider).value?.reciter ?? Reciters.fallback,
  ),
);

/// Whether a surah's recitation is fully on the phone.
final kidsSurahOnPhoneProvider = FutureProvider.autoDispose.family<bool, (int, int)>(
  (ref, key) => ref.watch(kidsAyahAudioProvider).isSurahOnPhone(key.$1, ayahCount: key.$2),
);

final kidsPlaybackProvider = StreamProvider.autoDispose<QuranPlayback>((ref) async* {
  final audio = ref.watch(kidsAyahAudioProvider);
  yield audio.value;
  yield* audio.playback;
});
