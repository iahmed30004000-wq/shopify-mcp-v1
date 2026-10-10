import 'dart:ui' as ui;

import '../domain/scene_math.dart';

/// Sequential float-uniform writer: call in exactly the order the uniforms are
/// declared in the GLSL source (after the common.glsl include).
class UniformWriter {
  UniformWriter(this.shader);

  final ui.FragmentShader shader;
  int _i = 0;

  int get index => _i;

  void f(double v) => shader.setFloat(_i++, v);

  void v2(double x, double y) {
    f(x);
    f(y);
  }

  void offset(ui.Offset o) => v2(o.dx, o.dy);

  void size(ui.Size s) => v2(s.width, s.height);

  void v3(V3 v) {
    f(v.x);
    f(v.y);
    f(v.z);
  }

  void v4(double x, double y, double z, double w) {
    f(x);
    f(y);
    f(z);
    f(w);
  }

  /// Colour as straight (non-premultiplied) sRGB rgba in 0..1.
  void color(ui.Color c) => v4(c.r, c.g, c.b, c.a);
}
