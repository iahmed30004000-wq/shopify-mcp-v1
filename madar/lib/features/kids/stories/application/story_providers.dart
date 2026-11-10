import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/voice_recorder.dart';

/// The microphone as a listener only: no file, nothing kept. Disposed with the
/// story screen, so the microphone is never left on.
final soundMeterProvider = Provider.autoDispose<SoundMeter>((ref) {
  final m = RecordSoundMeter();
  ref.onDispose(() => unawaited(m.dispose()));
  return m;
});

/// A steady clock for the sound detector (tests drive it).
final storyClockProvider = Provider<Duration Function()>((ref) {
  final sw = Stopwatch()..start();
  return () => sw.elapsed;
});
