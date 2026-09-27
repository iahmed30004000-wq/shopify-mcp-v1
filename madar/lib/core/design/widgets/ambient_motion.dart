import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Global switch for purely decorative, never-ending ambient motion: the
/// cosmos drift, the glass sheen and the empty-state illustration loops.
///
/// Under `flutter test` it defaults to **off**, so any screen built on
/// `MadarScaffold` / `GlassPanel` still lets `pumpAndSettle` settle (each
/// surface then renders one static, fully-composed frame). Tests that want
/// the live motion opt back in with [debugOverride]. Loaders (`OrbitLoader`)
/// are not ambient: like any progress indicator they always animate.
abstract final class AmbientMotion {
  static bool? _override;

  static final bool _underTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Whether ambient loops may run (reduced motion and TickerMode still
  /// apply on top of this).
  static bool get enabled => _override ?? !_underTest;

  /// Forces ambient motion on/off; `null` restores the default.
  @visibleForTesting
  static set debugOverride(bool? value) => _override = value;
}
