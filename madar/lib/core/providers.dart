import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'sound/sound_api.dart';

/// The unlocked, encrypted database. Overridden in bootstrap once the key has
/// been read from secure storage (and in tests with an in-memory database).
final databaseProvider = Provider<MadarDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden after unlock'),
);

/// Audio engine (flutter_soloud in production, silent in tests).
final soundServiceProvider = Provider<SoundService>((ref) => SilentSoundService());

/// Haptics engine.
final hapticsServiceProvider = Provider<HapticsService>(
  (ref) => throw UnimplementedError('hapticsServiceProvider must be overridden in bootstrap'),
);

/// Combined sound + haptic feedback.
final feedbackProvider = Provider<FeedbackService>(
  (ref) => FeedbackService(ref.watch(soundServiceProvider), ref.watch(hapticsServiceProvider)),
);
