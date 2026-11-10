import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'scene_controller.dart';

/// Places the astrolabe billboard on the projected core star: lays its
/// child out at [SceneController.coreRect]'s size (the dial picks its level
/// of detail from that) at the rect's position, fading and blurring it with
/// the fly-in. Driven by [SceneController.compositing] – no widget rebuilds.
class CoreAnchor extends SingleChildRenderObjectWidget {
  const CoreAnchor({super.key, required this.controller, super.child});

  final SceneController controller;

  @override
  RenderCoreAnchor createRenderObject(BuildContext context) => RenderCoreAnchor(controller);

  @override
  void updateRenderObject(BuildContext context, RenderCoreAnchor renderObject) => renderObject.controller = controller;
}

class RenderCoreAnchor extends RenderShiftedBox {
  RenderCoreAnchor(this._controller) : super(null);

  SceneController _controller;
  SceneController get controller => _controller;
  set controller(SceneController value) {
    if (identical(value, _controller)) return;
    if (attached) _controller.compositing.removeListener(_changed);
    _controller = value;
    if (attached) _controller.compositing.addListener(_changed);
    markNeedsLayout();
  }

  Rect _laidOut = Rect.zero;
  double _layoutSide = 0;
  double _opacity = 1, _blur = 0;
  final LayerHandle<TransformLayer> _transformLayer = LayerHandle<TransformLayer>();
  final LayerHandle<OpacityLayer> _opacityLayer = LayerHandle<OpacityLayer>();
  final LayerHandle<ImageFilterLayer> _blurLayer = LayerHandle<ImageFilterLayer>();

  @override
  void dispose() {
    _opacityLayer.layer = null;
    _blurLayer.layer = null;
    _transformLayer.layer = null;
    super.dispose();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.compositing.addListener(_changed);
  }

  @override
  void detach() {
    _controller.compositing.removeListener(_changed);
    super.detach();
  }

  void _changed() {
    final r = _controller.coreRect;
    if (_controller.coreLayoutSide != _layoutSide) {
      markNeedsLayout();
    } else if (r != _laidOut) {
      // Same paint box, new place / scale: repaint only.
      _laidOut = r;
      markNeedsPaint();
    } else if (_quantBlur(_controller.coreBlur) != _blur || (_controller.coreOpacity - _opacity).abs() > 0.002) {
      markNeedsPaint();
    }
  }

  static double _quantBlur(double s) => s < 0.3 ? 0 : (s * 4).roundToDouble() / 4;

  @override
  bool get isRepaintBoundary => true;

  @override
  void performLayout() {
    size = constraints.biggest;
    final r = _controller.coreRect;
    _laidOut = r;
    final side = _controller.coreLayoutSide;
    _layoutSide = side;
    final c = child;
    if (c == null) return;
    final w = side.isFinite && side > 0 ? side : 0.0;
    c.layout(BoxConstraints.tight(Size(w, w)));
    (c.parentData! as BoxParentData).offset = Offset.zero;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    _laidOut = _controller.coreRect;
    _opacity = _controller.coreOpacity;
    _blur = _quantBlur(_controller.coreBlur);
    if (c == null || _opacity <= 0.004 || _laidOut.width <= 0 || !c.hasSize || c.size.width <= 0) {
      _opacityLayer.layer = null;
      _blurLayer.layer = null;
      _transformLayer.layer = null;
      return;
    }
    // The child is laid out at [SceneController.coreLayoutSide]; place it
    // on the current paint box (a pure translate outside a flight).
    final scale = _laidOut.width / c.size.width;
    void paintChild(PaintingContext ctx, Offset o) {
      if ((scale - 1).abs() < 1e-4) {
        _transformLayer.layer = null;
        ctx.paintChild(c, o + _laidOut.topLeft);
        return;
      }
      final m = Matrix4.identity()
        ..translateByDouble(o.dx + _laidOut.left, o.dy + _laidOut.top, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
      _transformLayer.layer = ctx.pushTransform(
        needsCompositing,
        Offset.zero,
        m,
        (cc, oo) => cc.paintChild(c, oo),
        oldLayer: _transformLayer.layer,
      );
    }

    void blurred(PaintingContext ctx, Offset o) {
      if (_blur <= 0) {
        _blurLayer.layer = null;
        paintChild(ctx, o);
        return;
      }
      final l = _blurLayer.layer ?? ImageFilterLayer();
      l.imageFilter = ui.ImageFilter.blur(sigmaX: _blur, sigmaY: _blur, tileMode: TileMode.decal);
      _blurLayer.layer = l;
      ctx.pushLayer(l, paintChild, o);
    }

    if (_opacity >= 0.996) {
      _opacityLayer.layer = null;
      blurred(context, offset);
    } else {
      _opacityLayer.layer = context.pushOpacity(
        offset,
        (_opacity * 255).round(),
        blurred,
        oldLayer: _opacityLayer.layer,
      );
    }
  }

  @override
  bool hitTestSelf(Offset position) => false;

  /// The scene hit-tests the dial itself (with the right depth order).
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => false;
}

/// Blurs its child by [sigma] of the scene (depth of field during a fly-in),
/// repainting only when the quantised sigma changes; no filter layer at all
/// while it is under 0.3.
class SceneBlur extends SingleChildRenderObjectWidget {
  const SceneBlur({
    super.key,
    required this.controller,
    required this.sigma,
    this.tileMode = TileMode.decal,
    super.child,
  });

  final SceneController controller;
  final double Function(SceneController controller) sigma;

  /// `clamp` for an opaque full-screen child (the sky: no dark fringe at the
  /// screen edges), `decal` for transparent ones.
  final TileMode tileMode;

  @override
  RenderSceneBlur createRenderObject(BuildContext context) => RenderSceneBlur(controller, sigma, tileMode);

  @override
  void updateRenderObject(BuildContext context, RenderSceneBlur renderObject) => renderObject
    ..controller = controller
    ..sigma = sigma
    ..tileMode = tileMode;
}

class RenderSceneBlur extends RenderProxyBox {
  RenderSceneBlur(this._controller, this.sigma, this._tileMode);

  SceneController _controller;
  double Function(SceneController controller) sigma;
  TileMode _tileMode;

  set tileMode(TileMode value) {
    if (value == _tileMode) return;
    _tileMode = value;
    markNeedsPaint();
  }

  double _painted = 0;

  set controller(SceneController value) {
    if (identical(value, _controller)) return;
    if (attached) _controller.compositing.removeListener(_changed);
    _controller = value;
    if (attached) _controller.compositing.addListener(_changed);
    _changed();
  }

  double get _current {
    final s = sigma(_controller);
    return s < 0.3 ? 0 : (s * 4).roundToDouble() / 4;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.compositing.addListener(_changed);
  }

  @override
  void detach() {
    _controller.compositing.removeListener(_changed);
    super.detach();
  }

  void _changed() {
    final s = _current;
    if (s == _painted) return;
    if ((s == 0) != (_painted == 0)) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _current > 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    final s = _current;
    _painted = s;
    if (s <= 0) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    final l = (layer as ImageFilterLayer?) ?? ImageFilterLayer();
    l.imageFilter = ui.ImageFilter.blur(sigmaX: s, sigmaY: s, tileMode: _tileMode);
    layer = l;
    context.pushLayer(l, super.paint, offset);
  }
}

/// The fly-in's radial motion blur (`zoom_blur.frag` as an
/// `ImageFilter.shader`). Impeller only: where
/// `ui.ImageFilter.isShaderFilterSupported` is false (Skia, `flutter test`)
/// it is a plain pass-through.
class ZoomBlur extends SingleChildRenderObjectWidget {
  const ZoomBlur({super.key, required this.controller, super.child});

  final SceneController controller;

  static const asset = 'shaders/orbit/zoom_blur.frag';

  static ui.FragmentProgram? _program;
  static Future<void>? _loading;

  /// Whether the platform can run shader image filters.
  static bool get supported {
    try {
      return ui.ImageFilter.isShaderFilterSupported;
    } catch (_) {
      return false;
    }
  }

  /// Loads the program once (only where it can run).
  static Future<void> preload() {
    if (!supported) return Future.value();
    return _loading ??= ui.FragmentProgram.fromAsset(asset).then(
      (p) => _program = p,
      onError: (Object _) {
        _loading = null;
      },
    );
  }

  /// Loads the program and runs it once as an image filter offscreen, so
  /// the first fly-in does not compile its pipeline mid-flight.
  static Future<void> warmUp() async {
    await preload();
    final program = _program;
    if (program == null) return;
    final shader = program.fragmentShader();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    try {
      shader
        ..setFloat(2, 4)
        ..setFloat(3, 4)
        ..setFloat(4, 0.5)
        ..setFloat(5, 0);
      const rect = Rect.fromLTWH(0, 0, 8, 8);
      canvas
        ..saveLayer(rect, Paint()..imageFilter = ui.ImageFilter.shader(shader))
        ..drawRect(rect, Paint()..color = const Color(0xFF808080))
        ..restore();
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(8, 8);
        image.dispose();
      } finally {
        picture.dispose();
      }
    } finally {
      shader.dispose();
    }
  }

  @override
  RenderZoomBlur createRenderObject(BuildContext context) {
    unawaited(preload());
    return RenderZoomBlur(controller, MediaQuery.devicePixelRatioOf(context));
  }

  @override
  void updateRenderObject(BuildContext context, RenderZoomBlur renderObject) => renderObject
    ..controller = controller
    ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
}

class RenderZoomBlur extends RenderProxyBox {
  RenderZoomBlur(this._controller, this.devicePixelRatio);

  SceneController _controller;
  double devicePixelRatio;
  ui.FragmentShader? _shader;
  int _frame = 0;
  bool _active = false;

  set controller(SceneController value) {
    if (identical(value, _controller)) return;
    if (attached) _controller.compositing.removeListener(_changed);
    _controller = value;
    if (attached) _controller.compositing.addListener(_changed);
  }

  bool get _wanted => ZoomBlur._program != null && _controller.motionBlur > 0.01 && _controller.motionCenter != null;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.compositing.addListener(_changed);
  }

  @override
  void detach() {
    _controller.compositing.removeListener(_changed);
    super.detach();
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  void _changed() {
    final wanted = _wanted;
    if (wanted != _active) markNeedsCompositingBitsUpdate();
    if (wanted || _active) markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _wanted;

  @override
  void paint(PaintingContext context, Offset offset) {
    _active = _wanted;
    if (!_active) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    final shader = _shader ??= ZoomBlur._program!.fragmentShader();
    final c = _controller.motionCenter!;
    // uSize (floats 0–1) is set by the engine; the focus is in the filtered
    // layer's physical pixels.
    shader
      ..setFloat(2, (c.dx + offset.dx) * devicePixelRatio)
      ..setFloat(3, (c.dy + offset.dy) * devicePixelRatio)
      ..setFloat(4, _controller.motionBlur.clamp(0.0, 1.0))
      ..setFloat(5, (_frame++ % 64).toDouble());
    final l = (layer as ImageFilterLayer?) ?? ImageFilterLayer();
    l.imageFilter = ui.ImageFilter.shader(shader);
    layer = l;
    context.pushLayer(l, super.paint, offset);
  }
}
