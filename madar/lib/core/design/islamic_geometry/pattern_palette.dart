import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

import '../themes.dart' show PlanetPalettes;
import 'pattern_spec.dart';

/// A planet's signature ornament: which tiling, at which contact angle, in
/// which two colours. Every planet key in the app gets a distinct
/// (family, angle) pair, so two planets never share a texture.
@immutable
class PatternPalette {
  const PatternPalette({required this.spec, required this.color, required this.accent});

  /// The tiling and angle that belong to the planet.
  final PatternSpec spec;

  /// Line colour (the planet's surface tone).
  final Color color;

  /// Highlight / glow colour (the planet's glow tone).
  final Color accent;

  static const _specs = <String, PatternSpec>{
    'faith': PatternSpec(family: PatternFamily.girih10, contactAngle: 0.46),
    'health': PatternSpec(family: PatternFamily.hex6, contactAngle: 1.05),
    'family': PatternSpec(family: PatternFamily.square4, contactAngle: 0.785),
    'work': PatternSpec(family: PatternFamily.rosette12, contactAngle: 0.95),
    'money': PatternSpec(family: PatternFamily.hex6, contactAngle: 0.7),
    'growth': PatternSpec(family: PatternFamily.rosette12, contactAngle: 1.2),
    'body': PatternSpec(family: PatternFamily.square4, contactAngle: 1.1),
    'travel': PatternSpec(family: PatternFamily.girih10, contactAngle: 0.3),
    'sufra': PatternSpec(family: PatternFamily.square4, contactAngle: 0.55),
    'games': PatternSpec(family: PatternFamily.hex6, contactAngle: 1.35),
  };

  /// The keys that have a hand-picked palette (the planets in the app).
  static Iterable<String> get planetKeys => _specs.keys;

  /// Palette for [planetKey] ('faith', 'health', ...). An unknown key (a
  /// user-added planet) gets a stable choice derived from the key text, so
  /// it looks the same on every launch; [fallbackColor] overrides its tone.
  static PatternPalette forPlanet(String planetKey, {Color? fallbackColor}) {
    final known = _specs[planetKey];
    final colors = PlanetPalettes.byKey[planetKey];
    if (known != null && colors != null) {
      return PatternPalette(spec: known, color: fallbackColor ?? colors.surface, accent: colors.glow);
    }
    final h = _fnv1a(planetKey);
    final family = PatternFamily.values[h % PatternFamily.values.length];
    final angle = family.defaultContactAngle * (0.7 + (h ~/ 7 % 7) * 0.08);
    final tones = PlanetPalettes.byKey.values.toList(growable: false);
    final tone = tones[(h ~/ 3) % tones.length];
    return PatternPalette(
      spec: PatternSpec(family: family, contactAngle: angle),
      color: fallbackColor ?? tone.surface,
      accent: tone.glow,
    );
  }

  static int _fnv1a(String s) {
    var h = 0x811c9dc5;
    for (final u in s.codeUnits) {
      h = ((h ^ u) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }
}
