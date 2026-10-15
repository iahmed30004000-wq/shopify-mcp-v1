import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;

import 'media_session.dart';

/// Background playback through audio_service: a foreground media service
/// with a notification (surah · ayah, reciter; previous / play-pause / next
/// / stop), lock-screen and headset controls.
///
/// Started lazily on the first play ([start]); [AudioService.init] runs at
/// most once per process. When it fails – the activity is not an
/// `AudioServiceFragmentActivity` yet, the service is not declared, or it
/// takes longer than [timeout] – [start] answers null and playback stays
/// foreground-only.
class AudioServiceBackground implements RecitationBackground {
  AudioServiceBackground({
    required this.channelName,
    this.notificationColor,
    this.timeout = const Duration(seconds: 6),
  });

  /// Name of the Android notification channel ("Quran recitation").
  final String channelName;
  final Color? notificationColor;
  final Duration timeout;

  static Future<MadarAudioHandler?>? _handler;

  static const channelId = 'app.madar.orbit.recitation';

  @override
  Future<RecitationMediaSession?> start() => _handler ??= _init();

  Future<MadarAudioHandler?> _init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    // Widget tests report Android but have no platform side.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
    try {
      return await AudioService.init(
        builder: MadarAudioHandler.new,
        config: AudioServiceConfig(
          androidNotificationChannelId: channelId,
          androidNotificationChannelName: channelName,
          androidNotificationIcon: 'drawable/ic_stat_madar',
          notificationColor: notificationColor,
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      ).timeout(timeout);
    } catch (e) {
      debugPrint('Recitation: background playback unavailable ($e); playing in the foreground only.');
      return null;
    }
  }
}

/// The audio_service handler: mirrors [RecitationMediaInfo] into the media
/// session and forwards its commands to the player.
class MadarAudioHandler extends BaseAudioHandler implements RecitationMediaSession {
  RecitationMediaControls? _controls;

  @override
  void attach(RecitationMediaControls controls) => _controls = controls;

  @override
  void update(RecitationMediaInfo? info, RecitationMediaLabels labels) {
    if (info == null) {
      playbackState.add(PlaybackState(processingState: AudioProcessingState.idle));
      mediaItem.add(null);
      return;
    }
    final current = mediaItem.value;
    if (current == null || current.id != info.id || current.title != info.title || current.duration != info.duration) {
      mediaItem.add(
        MediaItem(
          id: info.id,
          title: info.title,
          artist: info.reciter,
          album: info.album,
          duration: info.duration,
          displayTitle: info.title,
          displaySubtitle: info.reciter,
        ),
      );
    }
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl(
            androidIcon: 'drawable/audio_service_skip_previous',
            label: labels.previous,
            action: MediaAction.skipToPrevious,
          ),
          if (info.playing)
            MediaControl(androidIcon: 'drawable/audio_service_pause', label: labels.pause, action: MediaAction.pause)
          else
            MediaControl(
              androidIcon: 'drawable/audio_service_play_arrow',
              label: labels.play,
              action: MediaAction.play,
            ),
          MediaControl(
            androidIcon: 'drawable/audio_service_skip_next',
            label: labels.next,
            action: MediaAction.skipToNext,
          ),
          MediaControl(androidIcon: 'drawable/audio_service_stop', label: labels.stop, action: MediaAction.stop),
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek, MediaAction.playPause},
        processingState: info.loading ? AudioProcessingState.buffering : AudioProcessingState.ready,
        playing: info.playing,
        updatePosition: info.position,
        speed: info.speed,
      ),
    );
  }

  @override
  Future<void> play() async => _controls?.resume();

  @override
  Future<void> pause() async => _controls?.pause();

  @override
  Future<void> skipToNext() async => _controls?.next();

  @override
  Future<void> skipToPrevious() async => _controls?.previous();

  @override
  Future<void> stop() async {
    await _controls?.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async => _controls?.seekWithin(position);

  /// Swiping the notification away / the task being removed while paused.
  @override
  Future<void> onTaskRemoved() async {
    if (!playbackState.value.playing) await stop();
  }
}
