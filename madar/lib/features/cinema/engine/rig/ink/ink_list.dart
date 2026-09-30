import 'dart:ui' as ui;
import 'dart:ui';

import '../../core/cinema_shaders.dart';
import '../../core/era_skin.dart';
import '../../core/shader_uniforms.dart';

/// Kinds of retained draw operations.
abstract final class InkOp {
  /// Solid fill in the op's colour.
  static const fill = 0;

  /// Ink stroke (outline behind a layer's fills, or an ink detail line):
  /// may carry the dry-brush ink shader.
  static const inkStroke = 1;

  /// Ink fill (brush strokes, pupils, solid ink shapes): may carry the ink
  /// shader.
  static const inkFill = 2;

  /// Shading mask filled with the era's halftone / crosshatch material (or a
  /// flat cel tone).
  static const shade = 3;

  /// Neon glow halo (blurred stroke).
  static const glow = 4;

  /// Plain stroke in the op's colour.
  static const stroke = 5;
}

final class _Op {
  Path path = _none;
  int kind = InkOp.fill;
  Color color = const Color(0xFF000000);
  double width = 0;
  double dx = 0, dy = 0;
  static final Path _none = Path();

  void copy(_Op o) {
    path = o.path;
    kind = o.kind;
    color = o.color;
    width = o.width;
    dx = o.dx;
    dy = o.dy;
  }
}

/// A retained display list for one drawing (a character, a prop).
///
/// A drawing is rebuilt only when it changes – a new pose drawing (on ones
/// or twos), a new boil frame, a new skin – and replayed every frame in
/// between. Paths, ops and paints are pooled: after the first few drawings
/// nothing is allocated.
///
/// Layers give the hand-inked look cheaply: every shape of a layer is first
/// stroked in ink (twice the line width, nudged toward the shadow side so
/// the line is heavy underneath and thin on top), then all fills go on top.
/// Overlapping shapes of one layer merge into a single inked silhouette.
final class InkList {
  final List<Path> _paths = [];
  int _pathCount = 0;
  final List<_Op> _ops = [];
  int _opCount = 0;

  final List<_Op> _shapes = [], _shades = [], _details = [];
  int _nShapes = 0, _nShades = 0, _nDetails = 0;
  bool _inLayer = false;

  // Per-drawing state.
  Color _ink = const Color(0xFF000000);
  Color _glow = const Color(0x00000000);
  Color _cel = const Color(0x40000000);
  bool _neon = false;
  double _offX = 0, _offY = 0;
  double _glowWidth = 0;
  ShadingMode _shading = ShadingMode.flat;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _inkFill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  final Paint _inkStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _shade = Paint()..isAntiAlias = true;
  double _blurSigma = -1;

  // Owned shader instances (uniforms change only when the drawing is rebuilt).
  ui.FragmentShader? _shadeShader;
  CinemaShader? _shadeSlot;
  ui.FragmentShader? _inkShader;
  bool _useInkShader = false;
  bool _shadeReady = false;

  /// Number of ops of the current drawing (tests, budgets).
  int get opCount => _opCount;

  /// Paths allocated so far (steady state: constant).
  int get pathPool => _paths.length;

  /// Starts a new drawing.
  void begin({
    required Color ink,
    required Color glow,
    required Color cel,
    required bool neon,
    required double offsetX,
    required double offsetY,
    required double glowWidth,
    required ShadingMode shading,
  }) {
    _pathCount = 0;
    _opCount = 0;
    _ink = ink;
    _glow = glow;
    _cel = cel;
    _neon = neon;
    _offX = offsetX;
    _offY = offsetY;
    _glowWidth = glowWidth;
    _shading = shading;
    _shadeReady = false;
  }

  Path _newPath() {
    if (_pathCount == _paths.length) _paths.add(Path());
    return _paths[_pathCount++]..reset();
  }

  _Op _op() {
    if (_opCount == _ops.length) _ops.add(_Op());
    return _ops[_opCount++];
  }

  static _Op _stage(List<_Op> list, int n) {
    if (n == list.length) list.add(_Op());
    return list[n];
  }

  // ---------------------------------------------------------------- layers

  void beginLayer() {
    if (_inLayer) endLayer();
    _inLayer = true;
    _nShapes = 0;
    _nShades = 0;
    _nDetails = 0;
  }

  /// A filled shape of the current layer, inked with an outline of
  /// [inkWidth] (0 = no outline). Returns the (reset) path to write into.
  Path shape(Color fill, double inkWidth) {
    final p = _newPath();
    if (!_inLayer) beginLayer();
    final o = _stage(_shapes, _nShapes++)
      ..path = p
      ..kind = InkOp.fill
      ..color = fill
      ..width = inkWidth;
    o.dx = 0;
    return p;
  }

  /// A shading mask of the current layer (drawn after the fills).
  Path shade() {
    final p = _newPath();
    if (!_inLayer) beginLayer();
    _stage(_shades, _nShades++)
      ..path = p
      ..kind = InkOp.shade;
    return p;
  }

  /// A detail of the current layer drawn after fills and shading.
  Path detail(int kind, Color color, [double width = 0]) {
    final p = _newPath();
    if (!_inLayer) {
      // Outside a layer a detail is a direct op.
      _op()
        ..path = p
        ..kind = kind
        ..color = color
        ..width = width
        ..dx = 0
        ..dy = 0;
      return p;
    }
    _stage(_details, _nDetails++)
      ..path = p
      ..kind = kind
      ..color = color
      ..width = width
      ..dx = 0
      ..dy = 0;
    return p;
  }

  /// Flushes the current layer: glow → ink silhouettes → fills → shading →
  /// details.
  void endLayer() {
    if (!_inLayer) return;
    _inLayer = false;
    if (_neon && _glowWidth > 0) {
      for (var i = 0; i < _nShapes; i++) {
        final s = _shapes[i];
        if (s.width <= 0) continue;
        _op()
          ..path = s.path
          ..kind = InkOp.glow
          ..color = _glow
          ..width = s.width + _glowWidth
          ..dx = 0
          ..dy = 0;
      }
    }
    for (var i = 0; i < _nShapes; i++) {
      final s = _shapes[i];
      if (s.width <= 0) continue;
      _op()
        ..path = s.path
        ..kind = InkOp.inkStroke
        ..color = _ink
        ..width = s.width
        ..dx = _offX
        ..dy = _offY;
    }
    for (var i = 0; i < _nShapes; i++) {
      _op().copy(_shapes[i]);
    }
    if (_shading != ShadingMode.flat && _shading != ShadingMode.neon) {
      for (var i = 0; i < _nShades; i++) {
        _op()
          ..copy(_shades[i])
          ..color = _cel;
      }
    }
    for (var i = 0; i < _nDetails; i++) {
      _op().copy(_details[i]);
    }
  }

  // --------------------------------------------------------------- shaders

  /// Sets the shading material for this drawing: a ramp from [from] (light,
  /// tone [toneFrom]) to [to] (shadow, tone [toneTo]) in local units.
  void setShading(
    EraSkin skin,
    Offset from,
    Offset to, {
    required Color ink,
    required int boilFrame,
    required double pixelScale,
    double toneFrom = 0.35,
    double toneTo = 1,
  }) {
    final mode = skin.ink.shading;
    final slot = switch (mode) {
      ShadingMode.halftone => CinemaShader.halftone,
      ShadingMode.crosshatch => CinemaShader.crosshatch,
      _ => null,
    };
    if (slot == null) {
      _shadeReady = false;
      return;
    }
    if (_shadeSlot != slot || _shadeShader == null) {
      final program = CinemaShaders.program(slot);
      if (program == null) {
        _shadeReady = false;
        return;
      }
      _shadeShader?.dispose();
      _shadeShader = program.fragmentShader();
      _shadeSlot = slot;
    }
    final s = _shadeShader!;
    if (slot == CinemaShader.halftone) {
      HalftoneUniforms.write(
        s,
        from: from,
        to: to,
        ink: ink,
        style: skin.halftone,
        toneFrom: toneFrom,
        toneTo: toneTo,
        boilFrame: boilFrame,
        pixelScale: pixelScale,
      );
    } else {
      CrosshatchUniforms.write(
        s,
        from: from,
        to: to,
        ink: ink,
        style: skin.hatch,
        toneFrom: toneFrom,
        toneTo: toneTo,
        boilFrame: boilFrame,
        pixelScale: pixelScale,
      );
    }
    _shadeReady = true;
  }

  /// Dry-brush ink texture for this drawing's ink (when the era's ink is
  /// dry and the program is loaded).
  void setInkTexture(EraSkin skin, {required int boilFrame, required double seed, bool enabled = true}) {
    final dry = skin.ink.dryness;
    if (!enabled || dry <= 0.01 || skin.ink.shading == ShadingMode.neon) {
      _useInkShader = false;
      return;
    }
    if (_inkShader == null) {
      final program = CinemaShaders.program(CinemaShader.inkLine);
      if (program == null) {
        _useInkShader = false;
        return;
      }
      _inkShader = program.fragmentShader();
    }
    InkLineUniforms.write(_inkShader!, ink: _ink, dryness: dry, boilFrame: boilFrame, seed: seed);
    _useInkShader = true;
  }

  // ---------------------------------------------------------------- replay

  /// Draws the retained drawing. [flash] > 0 whites the fills out (hit
  /// flash) – no allocation, colours swap per op.
  void replay(Canvas canvas, {Color? flash}) {
    if (_inLayer) endLayer();
    final inkShader = _useInkShader ? _inkShader : null;
    _inkStroke.shader = inkShader;
    _inkFill.shader = inkShader;
    final useMaterial = _shadeReady && _shadeShader != null;
    _shade.shader = useMaterial ? _shadeShader : null;
    for (var i = 0; i < _opCount; i++) {
      final o = _ops[i];
      switch (o.kind) {
        case InkOp.fill:
          _fill.color = flash ?? o.color;
          canvas.drawPath(o.path, _fill);
        case InkOp.inkFill:
          _inkFill.color = o.color;
          canvas.drawPath(o.path, _inkFill);
        case InkOp.inkStroke:
          _inkStroke
            ..color = o.color
            ..strokeWidth = o.width;
          if (o.dx != 0 || o.dy != 0) {
            canvas
              ..translate(o.dx, o.dy)
              ..drawPath(o.path, _inkStroke)
              ..translate(-o.dx, -o.dy);
          } else {
            canvas.drawPath(o.path, _inkStroke);
          }
        case InkOp.shade:
          if (flash != null) continue;
          if (!useMaterial) _shade.color = o.color;
          canvas.drawPath(o.path, _shade);
        case InkOp.glow:
          if (_blurSigma != _glowWidth) {
            _blurSigma = _glowWidth;
            _glowPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, _glowWidth * 0.5);
          }
          _glowPaint
            ..color = o.color
            ..strokeWidth = o.width;
          canvas.drawPath(o.path, _glowPaint);
        case InkOp.stroke:
          _stroke
            ..color = flash != null && o.color.a > 0.9 && o.color != _ink ? flash : o.color
            ..strokeWidth = o.width;
          canvas.drawPath(o.path, _stroke);
      }
    }
  }

  void dispose() {
    _shadeShader?.dispose();
    _shadeShader = null;
    _inkShader?.dispose();
    _inkShader = null;
    _opCount = 0;
  }
}
