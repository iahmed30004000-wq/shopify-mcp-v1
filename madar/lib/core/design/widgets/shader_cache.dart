import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Loads Madar's fragment programs once and shares them app-wide.
///
/// Programs load lazily on first use; call [MadarShaders.preload] during
/// bootstrap so the very first frame already has them. Every consumer must
/// tolerate a `null` program (still loading, or the platform cannot compile
/// runtime effects) and paint its gradient fallback instead.
abstract final class MadarShaders {
  static const glassAsset = 'shaders/glass.frag';
  static const cosmosAsset = 'shaders/cosmos_backdrop.frag';

  static final Map<String, ValueNotifier<ui.FragmentProgram?>> _programs = {};
  static final Map<String, Future<ui.FragmentProgram?>> _pending = {};

  /// Listenable program for [asset]; starts loading on first access.
  static ValueListenable<ui.FragmentProgram?> program(String asset) {
    final notifier = _programs.putIfAbsent(asset, () => ValueNotifier<ui.FragmentProgram?>(null));
    if (notifier.value == null) unawaited(load(asset));
    return notifier;
  }

  /// The glass finish program (see `shaders/glass.frag`).
  static ValueListenable<ui.FragmentProgram?> get glass => program(glassAsset);

  /// The cosmos backdrop program (see `shaders/cosmos_backdrop.frag`).
  static ValueListenable<ui.FragmentProgram?> get cosmos => program(cosmosAsset);

  /// Loads [asset] once. Resolves to `null` (never throws) when the shader
  /// cannot be loaded, so callers keep their fallback.
  static Future<ui.FragmentProgram?> load(String asset) {
    final notifier = _programs.putIfAbsent(asset, () => ValueNotifier<ui.FragmentProgram?>(null));
    if (notifier.value != null) return SynchronousFuture(notifier.value);
    return _pending[asset] ??= ui.FragmentProgram.fromAsset(asset).then<ui.FragmentProgram?>(
      (program) {
        notifier.value = program;
        return program;
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('MadarShaders: "$asset" unavailable, using fallback ($error)');
        return null;
      },
    );
  }

  /// Loads every Madar shader. Safe to call repeatedly.
  ///
  /// Not `Future.wait`: [load] answers a loaded program with a
  /// [SynchronousFuture], whose callbacks run inside `Future.wait`'s
  /// registration loop and break it. Both loads still start before either
  /// is awaited, so they run in parallel.
  static Future<void> preload() async {
    final glass = load(glassAsset);
    final cosmos = load(cosmosAsset);
    await glass;
    await cosmos;
  }

  /// Test hook: forget loaded programs so a test can exercise the fallback.
  @visibleForTesting
  static void debugReset() {
    for (final n in _programs.values) {
      n.value = null;
    }
    _pending.clear();
  }

  /// Test hook: pretend [asset] failed/is unavailable (keeps it `null`).
  @visibleForTesting
  static void debugDisable(String asset) {
    _programs.putIfAbsent(asset, () => ValueNotifier<ui.FragmentProgram?>(null)).value = null;
    _pending[asset] = SynchronousFuture<ui.FragmentProgram?>(null);
  }
}
