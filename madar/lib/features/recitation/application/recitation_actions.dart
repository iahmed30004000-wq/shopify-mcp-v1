import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recitation_settings.dart';
import '../domain/reciters.dart';
import 'recitation_providers.dart';

/// User actions shared by the settings screen, the player sheet and the
/// mini player: they persist the choice and apply it to what is playing.
abstract final class RecitationActions {
  /// Saves [change]; tolerant of a missing database (tests, early start).
  static Future<void> changeSettings(WidgetRef ref, RecitationSettings Function(RecitationSettings) change) async {
    try {
      await ref.read(recitationSettingsProvider.notifier).change(change);
    } catch (_) {}
  }

  /// Chooses [reciter] for the app and for what is playing (not a preview).
  static Future<void> chooseReciter(WidgetRef ref, Reciter reciter) async {
    final player = ref.read(recitationPlayerProvider);
    final previewing = player.isSampleOf(player.state.reciter);
    unawaited(changeSettings(ref, (s) => s.copyWith(reciterId: reciter.id)));
    if (player.state.active && !previewing) await player.setReciter(reciter);
  }

  /// Plays or stops [reciter]'s sample.
  static Future<void> toggleSample(WidgetRef ref, Reciter reciter) async {
    final player = ref.read(recitationPlayerProvider);
    if (player.isSampleOf(reciter)) return player.stop();
    return player.playSample(reciter);
  }

  static Future<void> setSpeed(WidgetRef ref, double speed) async {
    unawaited(changeSettings(ref, (s) => s.copyWith(speed: speed)));
    await ref.read(recitationPlayerProvider).setSpeed(speed);
  }
}
