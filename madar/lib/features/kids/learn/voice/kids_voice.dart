// "Every text has a speaker button": this is what the button calls.
//
// The recordings do not exist yet; the owner adds them later as
// `assets/kids/voice/<id>.mp3`. So [play] looks the asset up and is silent
// when it is not there: no registration, no list of ids, no crash. When the
// owner drops a file in and registers the folder, the same call starts to
// sound with no code change.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

abstract interface class KidsVoice {
  /// Plays the recording called [id] (`letter_ain`, `word_ain`, `maths_mul_3_4`
  /// ...) if the app has it; otherwise does nothing. Never throws.
  Future<void> play(String id);

  Future<void> stop();
}

/// Starts playback of one bundled asset (just_audio in production).
typedef KidsAssetPlayer = Future<void> Function(String assetPath);

class AssetKidsVoice implements KidsVoice {
  AssetKidsVoice({AssetBundle? bundle, this._player}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final KidsAssetPlayer? _player;
  AudioPlayer? _audio;

  /// Ids are file names: lower-case letters, digits and underscores only, so
  /// a stray id can never walk out of the voice folder.
  static final RegExp _valid = RegExp(r'^[a-z0-9_]{1,80}$');

  static String pathFor(String id) => 'assets/kids/voice/$id.mp3';

  /// True when the asset exists (an unregistered asset throws on load).
  Future<bool> exists(String id) async {
    if (!_valid.hasMatch(id)) return false;
    try {
      await _bundle.load(pathFor(id));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> play(String id) async {
    try {
      if (!await exists(id)) return;
      final path = pathFor(id);
      final custom = _player;
      if (custom != null) {
        await custom(path);
        return;
      }
      final audio = _audio ??= AudioPlayer();
      await audio.setAsset(path);
      unawaited(audio.play());
    } catch (_) {
      // A recording that cannot play must never break the lesson.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _audio?.stop();
    } catch (_) {}
  }
}

/// Silent voice: the default in tests and previews.
class SilentKidsVoice implements KidsVoice {
  const SilentKidsVoice();
  @override
  Future<void> play(String id) async {}
  @override
  Future<void> stop() async {}
}

final kidsVoiceProvider = Provider<KidsVoice>((ref) => AssetKidsVoice());
