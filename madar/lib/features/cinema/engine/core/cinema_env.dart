import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'era.dart';
import 'era_skin.dart';

/// Read-only environment handed to every engine factory (FilmFx, stage,
/// HUD, transitions): the era skin plus the host's reading direction and
/// accessibility state.
@immutable
class CinemaEnv {
  const CinemaEnv({
    required this.skin,
    this.direction = TextDirection.rtl,
    this.reducedMotion = false,
    this.seed = 0,
    this.languageCode = 'ar',
  });

  final EraSkin skin;
  Era get era => skin.era;

  /// Arabic-first: RTL unless the app runs in a LTR locale. HUD slots named
  /// "start"/"end" follow it; intertitles are laid out with it.
  final TextDirection direction;

  /// Reduced motion / no flashing (from MediaQuery / MotionScope).
  final bool reducedMotion;

  /// Per-scene seed for procedural variation (stable within a scene).
  final int seed;
  final String languageCode;
}
