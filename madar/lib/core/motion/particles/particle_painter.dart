import 'package:flutter/rendering.dart';

import 'particle_atlas.dart';
import 'particle_system.dart';

/// Renders a whole [ParticleSystem] with a single `drawRawAtlas` call.
///
/// [additive] blends light additively (`BlendMode.plus`) – right for dark,
/// cosmic themes; light themes composite normally so the sprites stay
/// visible on pale backgrounds.
class ParticlePainter extends CustomPainter {
  ParticlePainter({required this.system, required this.atlas, this.additive = true})
    : _paint = Paint()
        ..blendMode = additive ? BlendMode.plus : BlendMode.srcOver
        ..filterQuality = FilterQuality.low,
      super(repaint: system);

  final ParticleSystem system;
  final ParticleAtlas atlas;
  final bool additive;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    if (atlas.isDisposed) return;
    final n = system.prepareRender(atlas);
    if (n == 0) return;
    canvas.drawRawAtlas(atlas.image, system.transforms, system.rects, system.colors, BlendMode.modulate, null, _paint);
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) =>
      oldDelegate.system != system || oldDelegate.atlas != atlas || oldDelegate.additive != additive;
}
