import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/motion/particles/particle_pool.dart';

void main() {
  test('obtain never exceeds capacity', () {
    final pool = ParticlePool(16);
    var granted = 0;
    for (var i = 0; i < 100; i++) {
      if (pool.obtain() >= 0) granted++;
    }
    expect(granted, 16);
    expect(pool.count, 16);
    expect(pool.isFull, isTrue);
    expect(pool.obtain(), -1);
  });

  test('dead particles are recycled and live ones stay packed', () {
    final pool = ParticlePool(8);
    for (var i = 0; i < 8; i++) {
      final p = pool.obtain();
      pool
        ..life[p] = (i + 1) * 0.1
        ..x[p] = i.toDouble();
    }
    pool.update(0.35); // the first three die
    expect(pool.count, 5);
    final xs = [for (var i = 0; i < pool.count; i++) pool.x[i]]..sort();
    expect(xs, [3, 4, 5, 6, 7]);
    // Slots are reusable.
    expect(pool.obtain(), 5);
  });

  test('everything dies out', () {
    final pool = ParticlePool(64);
    for (var i = 0; i < 64; i++) {
      final p = pool.obtain();
      pool
        ..life[p] = 0.2 + i * 0.03
        ..vy[p] = -100
        ..ay[p] = 400;
    }
    var t = 0.0;
    while (!pool.isEmpty && t < 10) {
      pool.update(1 / 60);
      t += 1 / 60;
      expect(pool.count, lessThanOrEqualTo(64));
    }
    expect(pool.isEmpty, isTrue);
    expect(t, lessThan(2.3));
  });

  test('ballistic integration applies gravity and drag', () {
    final pool = ParticlePool(2);
    final a = pool.obtain();
    pool
      ..life[a] = 10
      ..vx[a] = 100
      ..ay[a] = 100;
    final b = pool.obtain();
    pool
      ..life[b] = 10
      ..vx[b] = 100
      ..drag[b] = 3;
    for (var i = 0; i < 60; i++) {
      pool.update(1 / 60);
    }
    expect(pool.x[a], closeTo(100, 1));
    expect(pool.y[a], greaterThan(40));
    expect(pool.vx[b], lessThan(20));
    expect(pool.x[b], lessThan(pool.x[a]));
  });

  test('orbital motion turns around the centre', () {
    final pool = ParticlePool(1);
    final p = pool.obtain();
    pool
      ..motion[p] = ParticleMotion.orbital
      ..life[p] = 10
      ..x[p] = 50
      ..y[p] = 50
      ..radius[p] = 20
      ..spin[p] = 3.14159265 / 2;
    final (x0, y0) = pool.positionOf(p);
    expect(x0, closeTo(70, 1e-3));
    expect(y0, closeTo(50, 1e-3));
    pool.update(1);
    final (x1, y1) = pool.positionOf(p);
    expect(x1, closeTo(50, 1e-3));
    expect(y1, closeTo(70, 1e-3));
  });

  test('envelope fades in and out; size shrinks', () {
    final pool = ParticlePool(1);
    final p = pool.obtain();
    pool
      ..life[p] = 1
      ..fadeIn[p] = 0.1
      ..fadeOut[p] = 0.5
      ..size0[p] = 10
      ..size1[p] = 0;
    expect(pool.envelope(p), 0);
    pool.update(0.05);
    expect(pool.envelope(p), closeTo(0.5, 0.01));
    pool.update(0.25);
    expect(pool.envelope(p), 1);
    pool.update(0.65);
    expect(pool.envelope(p), lessThan(0.05));
    expect(pool.sizeOf(p), lessThan(1));
  });
}
