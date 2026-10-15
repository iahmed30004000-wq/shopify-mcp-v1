/// Madar's pure-Dart procedural synthesiser.
///
/// Everything here is deterministic (seeded), allocation-light and free of
/// Flutter dependencies, so it can run inside `Isolate.run` and in plain
/// unit tests.
library;

export 'buffer.dart';
export 'canvas.dart';
export 'dynamics.dart';
export 'envelope.dart';
export 'filters.dart';
export 'instruments.dart';
export 'maqam.dart';
export 'oscillators.dart';
export 'reverb.dart';
export 'rng.dart';
export 'wav.dart';
