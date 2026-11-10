import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sound/prayer_mute.dart';
import 'adhkar_providers.dart';

/// Which attached recording is playing (null = none). Stops when the last
/// listener goes (the reader closes), when the recording's known length has
/// passed, and when the adhan starts (the prayer mute engages): a recording
/// never talks over the call to prayer.
final dhikrPlaybackProvider = NotifierProvider.autoDispose<DhikrPlayback, String?>(DhikrPlayback.new);

class DhikrPlayback extends Notifier<String?> {
  Timer? _end;

  @override
  String? build() {
    // Keeps the player alive while playback is possible.
    final player = ref.watch(dhikrAudioPlayerProvider);
    final mute = ref.watch(prayerMuteProvider);
    var wasMuted = mute.muted;
    void onMute() {
      // Only the moment it engages: a recording the user starts during the
      // prayer minutes afterwards still plays.
      if (mute.muted && !wasMuted) stop();
      wasMuted = mute.muted;
    }

    mute.addListener(onMute);
    ref.onDispose(() {
      mute.removeListener(onMute);
      _end?.cancel();
      player.stop();
    });
    return null;
  }

  /// Plays [dhikrId]'s recording; false when there is none or audio is
  /// unavailable.
  Future<bool> play(String dhikrId) async {
    stop();
    final store = ref.read(dhikrAudioStoreProvider);
    final info = (await store.all())[dhikrId];
    final bytes = await store.read(dhikrId);
    if (bytes == null || !ref.mounted) return false;
    final ok = await ref.read(dhikrAudioPlayerProvider).play(dhikrId, bytes);
    if (!ok || !ref.mounted) return false;
    state = dhikrId;
    final length = info?.duration;
    if (length != null) {
      _end = Timer(length + const Duration(milliseconds: 150), () {
        if (ref.mounted && state == dhikrId) state = null;
      });
    }
    return true;
  }

  void stop() {
    _end?.cancel();
    _end = null;
    if (state != null) {
      ref.read(dhikrAudioPlayerProvider).stop();
      state = null;
    }
  }

  /// Plays or stops [dhikrId].
  Future<bool> toggle(String dhikrId) async {
    if (state == dhikrId) {
      stop();
      return true;
    }
    return play(dhikrId);
  }
}
