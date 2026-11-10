import 'dart:ui';

import 'package:flame/components.dart';

import 'cinema_game.dart';
import 'rig.dart';

/// Puts a [RigCharacter] into a Flame world.
///
/// [position] is the point between the character's feet (anchor
/// bottom-centre); the component's size is the rig's standing box. The
/// component owns the rig and disposes it on removal. Gameplay steers the
/// rig through [rig] (act, facing, speed, squash, lookAt…).
class RigComponent extends PositionComponent with HasGameReference<CinemaGame> {
  RigComponent({required this.rig, super.position, super.priority})
    : super(anchor: Anchor.bottomCenter, size: Vector2(rig.spec.height * 0.9, rig.spec.height));

  final RigCharacter rig;

  @override
  void update(double dt) => rig.update(dt);

  @override
  void render(Canvas canvas) {
    canvas
      ..save()
      ..translate(size.x / 2, size.y);
    rig.paint(canvas, game.rigPaint);
    canvas.restore();
  }

  @override
  void onRemove() {
    rig.dispose();
    super.onRemove();
  }
}
