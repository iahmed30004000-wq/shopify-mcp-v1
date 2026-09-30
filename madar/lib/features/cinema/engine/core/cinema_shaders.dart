import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'film_clock.dart';

/// Every reserved shader slot of the Film Reel Engine: asset path, the
/// exact number of float uniforms and samplers (the uniform contract – the
/// test suite checks the compiled programs against these numbers), and the
/// agent that owns the GLSL body. Uniform layouts: shader_uniforms.dart and
/// the header of each .frag.
enum CinemaShader {
  filmGrade('film_grade', floats: 36, samplers: 1),
  vhs('vhs', floats: 24, samplers: 1),
  halftone('halftone', floats: 16),
  crosshatch('crosshatch', floats: 16),
  inkLine('ink_line', floats: 8),
  paper('paper', floats: 16),
  iris('iris', floats: 16),
  burn('burn', floats: 16),
  curtain('curtain', floats: 24),
  spotlight('spotlight', floats: 16);

  const CinemaShader(this.file, {required this.floats, this.samplers = 0});

  final String file;

  /// Float uniforms (setFloat indices 0 … floats-1).
  final int floats;

  /// Image samplers (setImageSampler indices 0 … samplers-1).
  final int samplers;

  String get asset => 'shaders/cinema/$file.frag';
}

/// Loads and caches the cinema FragmentPrograms (once per process).
///
/// Call [preload] early (the hall does it; CinemaGame.onLoad awaits it).
/// A shader that fails to load stays `null` and every user must fall back to
/// plain Canvas drawing – a missing effect never blanks the screen.
abstract final class CinemaShaders {
  static final Map<CinemaShader, ui.FragmentProgram> _programs = {};
  static Future<void>? _loading;

  static Future<void> preload() => _loading ??= _loadAll();

  static Future<void> _loadAll() async {
    await Future.wait([
      for (final s in CinemaShader.values)
        ui.FragmentProgram.fromAsset(s.asset).then<void>(
          (p) => _programs[s] = p,
          onError: (Object e) {
            if (kDebugMode) debugPrint('CinemaShaders: ${s.asset} failed to load: $e');
          },
        ),
    ]);
  }

  static ui.FragmentProgram? program(CinemaShader shader) => _programs[shader];

  static bool isLoaded(CinemaShader shader) => _programs.containsKey(shader);

  @visibleForTesting
  static void debugReset() {
    _programs.clear();
    _loading = null;
  }
}

/// Hands out [ui.FragmentShader] instances of one program so that several
/// draws in the same frame can use different uniforms (a FragmentShader's
/// uniforms are shared by every draw that references it until the frame is
/// rasterised – see dart:ui FragmentShader docs).
///
/// Instances are created on demand and reused on later ticks: no allocations
/// in steady state. The pool resets itself when [FilmClock.tick] changes.
class ShaderPool {
  ShaderPool(this.shader, {this.maxInstances = 64});

  final CinemaShader shader;

  /// Safety cap; beyond it the last instance is reused (and a debug warning
  /// printed once) – raise it or batch draws if you hit it.
  final int maxInstances;

  final List<ui.FragmentShader> _items = [];
  int _used = 0;
  int _tick = -1;
  bool _warned = false;

  /// A shader for one draw this tick, or `null` while the program is not
  /// loaded (fall back to plain paint).
  ui.FragmentShader? next(FilmClock clock) {
    final program = CinemaShaders.program(shader);
    if (program == null) return null;
    if (clock.tick != _tick) {
      _tick = clock.tick;
      _used = 0;
    }
    if (_used < _items.length) return _items[_used++];
    if (_items.length < maxInstances) {
      final s = program.fragmentShader();
      _items.add(s);
      _used++;
      return s;
    }
    if (kDebugMode && !_warned) {
      _warned = true;
      debugPrint('ShaderPool(${shader.file}): more than $maxInstances draws in one frame');
    }
    return _items.last;
  }

  int get allocated => _items.length;

  void dispose() {
    for (final s in _items) {
      s.dispose();
    }
    _items.clear();
  }
}
