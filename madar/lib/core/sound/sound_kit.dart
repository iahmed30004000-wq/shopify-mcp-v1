import 'dart:isolate';
import 'dart:typed_data';

import 'profiles.dart';
import 'sound_api.dart';

/// Every UI sound of one profile, rendered to PCM16 WAV bytes.
final class SoundKit {
  const SoundKit({
    required this.profileId,
    required this.sampleRate,
    required this.wavs,
    required this.renderTime,
  });

  final String profileId;
  final int sampleRate;

  /// One WAV per [Sfx]; always complete.
  final Map<Sfx, Uint8List> wavs;

  /// Wall-clock synthesis time (diagnostics / performance budget).
  final Duration renderTime;

  int get totalBytes => wavs.values.fold(0, (a, b) => a + b.length);
}

/// Renders sound kits. Synthesis is pure Dart and deterministic; use
/// [renderInBackground] from the UI isolate so start-up and theme switches
/// never drop a frame.
abstract final class SoundKitRenderer {
  static const int defaultSampleRate = 44100;

  /// Synchronously renders every [Sfx] for [profileId] (unknown ids fall back
  /// to Lapis). Budget: < 300 ms per profile on a mid-range phone.
  static SoundKit render(String profileId, {int sampleRate = defaultSampleRate}) {
    final sw = Stopwatch()..start();
    final profile = SoundProfiles.byId(profileId);
    final wavs = renderSubset(profile.id, Sfx.values, sampleRate: sampleRate);
    sw.stop();
    return SoundKit(profileId: profile.id, sampleRate: sampleRate, wavs: wavs, renderTime: sw.elapsed);
  }

  /// Renders only [sounds] of [profileId].
  static Map<Sfx, Uint8List> renderSubset(String profileId, Iterable<Sfx> sounds, {int sampleRate = defaultSampleRate}) {
    final profile = SoundProfiles.byId(profileId);
    return {for (final sfx in sounds) sfx: profile.renderWav(sfx, sampleRate: sampleRate)};
  }

  /// [render] on background isolates, so the UI isolate never synthesises.
  ///
  /// The sounds are split across [isolates] workers balanced by length (the
  /// dominant cost), roughly dividing wall-clock time on multi-core phones.
  /// Results come back without copying (`Isolate.exit`); output is identical
  /// to [render].
  static Future<SoundKit> renderInBackground(String profileId, {int sampleRate = defaultSampleRate, int isolates = 2}) async {
    final sw = Stopwatch()..start();
    final id = SoundProfiles.normalize(profileId);
    final parts = partition(Sfx.values, isolates);
    final results = await Future.wait([
      for (final (i, part) in parts.indexed)
        Isolate.run(() => renderSubset(id, part, sampleRate: sampleRate), debugName: 'madar-sound-kit-$id-$i'),
    ]);
    final wavs = <Sfx, Uint8List>{for (final r in results) ...r};
    sw.stop();
    return SoundKit(
      profileId: id,
      sampleRate: sampleRate,
      wavs: {for (final sfx in Sfx.values) sfx: wavs[sfx]!},
      renderTime: sw.elapsed,
    );
  }

  /// Greedy longest-first split of [sounds] into [n] groups of similar total
  /// length.
  static List<List<Sfx>> partition(List<Sfx> sounds, int n) {
    final k = n.clamp(1, sounds.length);
    final groups = [for (var i = 0; i < k; i++) <Sfx>[]];
    final load = List<double>.filled(k, 0);
    final sorted = [...sounds]..sort((a, b) => SfxSpecs.maxSeconds(b).compareTo(SfxSpecs.maxSeconds(a)));
    for (final sfx in sorted) {
      var best = 0;
      for (var i = 1; i < k; i++) {
        if (load[i] < load[best]) best = i;
      }
      groups[best].add(sfx);
      load[best] += SfxSpecs.maxSeconds(sfx);
    }
    return groups;
  }
}
