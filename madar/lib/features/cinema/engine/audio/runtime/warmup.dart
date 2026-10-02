import 'dart:async';

import '../../../../../core/sound/sound_api.dart';
import '../../core/audio.dart';
import '../../core/era.dart';
import '../../core/era_skins.dart';
import 'cue_source.dart';
import 'mixer.dart';

/// Pre-renders an era's audio into the shared cache so a game's music is
/// ready the moment it starts (call it when a poster is focused or tapped).
/// Does nothing when sound cannot be heard.
abstract final class CinemaAudioWarmup {
  /// Renders the era's effects kit, stingers and opening [moods] for a
  /// scene seed of [seed] (a game's first run uses seed 0).
  static Future<void> warm(
    Era era,
    SoundService sound, {
    int seed = 0,
    List<MusicMood> moods = const [MusicMood.title, MusicMood.adventure],
    CachingCueSource? cache,
  }) async {
    if (!mixerFor(sound).isLive) return;
    final c = cache ?? CachingCueSource.shared;
    final score = EraSkins.of(era).score;
    try {
      await Future.wait([
        c.renderSfx(era, 1),
        c.renderStingers(score, 1),
        for (final m in moods) c.renderCue(score, m, seed),
      ]);
    } catch (_) {
      // Best effort: the game renders whatever is missing itself.
    }
  }
}
