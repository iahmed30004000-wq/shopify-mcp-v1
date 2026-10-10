import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';

void main() {
  const viewport = Size(400, 800);

  test('target projects onto the principal point', () {
    const cam = OrbitCamera(principal: Offset(0.5, 0.4));
    final p = cam.project(V3.zero, viewport);
    expect(p.offset.dx, closeTo(200, 1e-6));
    expect(p.offset.dy, closeTo(320, 1e-6));
    expect(p.depth, closeTo(cam.distance, 1e-9));
  });

  test('nearer points project larger', () {
    const cam = OrbitCamera(elevation: 0.3, azimuth: 0);
    final front = cam.project(const V3(0, 0, 2), viewport);
    final back = cam.project(const V3(0, 0, -2), viewport);
    expect(front.scale, greaterThan(back.scale));
    expect(front.depth, lessThan(back.depth));
  });

  test('ray through a projected point hits the sphere there', () {
    const cam = OrbitCamera(elevation: 0.4, azimuth: 0.7, roll: -0.2);
    const center = V3(1.2, 0.1, -0.4);
    final p = cam.project(center, viewport);
    final dir = cam.rayDirection(p.offset, viewport);
    final t = raySphere(cam.position, dir, center, 0.2);
    expect(t, isNotNull);
  });

  test('orbit positions stay on the orbit radius', () {
    const e = OrbitElements(radius: 2.5, phase: 0.3, periodSeconds: 600, inclination: 0.2, node: 1.1);
    for (var s = 0.0; s < 1200; s += 97) {
      expect(e.positionAt(s).length, closeTo(2.5, 1e-9));
    }
    expect(e.angleAt(600) - e.angleAt(0), closeTo(2 * math.pi, 1e-9));
  });

  test('camera lerp takes the shortest azimuth arc', () {
    const a = OrbitCamera(azimuth: 0.1);
    const b = OrbitCamera(azimuth: 2 * math.pi - 0.1);
    final mid = OrbitCamera.lerp(a, b, 0.5);
    expect(mid.azimuth, closeTo(0.0, 1e-9));
  });
}
