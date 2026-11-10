import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/reading/presentation/page_turn/page_snapshot_cache.dart';

void main() {
  testWidgets('a lookup under another signature is a miss, never a stale image', (tester) async {
    final cache = PageSnapshotCache();
    final img = (await tester.runAsync(() => createTestImage(width: 4, height: 4)))!;
    cache.store(3, img, 'a');
    expect(cache.lookup(3, 'a'), same(img));
    expect(cache.lookup(3, 'b'), isNull);
    expect(cache.has(4, 'a'), isFalse);
    cache.dispose();
  });

  testWidgets('far pages are evicted and their images freed', (tester) async {
    final cache = PageSnapshotCache();
    final images = <int, dynamic>{};
    for (var p = 0; p < 8; p++) {
      final img = (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!;
      images[p] = img;
      cache.store(p, img, 's');
    }
    cache.evictFar(4, 1);
    expect(cache.pages, [3, 4, 5]);
    expect(images[0].debugDisposed, isTrue);
    expect(images[7].debugDisposed, isTrue);
    expect(images[4].debugDisposed, isFalse);
    cache.dispose();
    expect(images[4].debugDisposed, isTrue);
    expect(cache.length, 0);
  });

  testWidgets('storing over a page frees the old image; invalidate drops one or all', (tester) async {
    final cache = PageSnapshotCache();
    final a = (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!;
    final b = (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!;
    final c = (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!;
    cache.store(1, a, 's');
    cache.store(1, b, 's');
    expect(a.debugDisposed, isTrue);
    cache.store(2, c, 's');
    cache.invalidate(1);
    expect(b.debugDisposed, isTrue);
    expect(cache.pages, [2]);
    cache.invalidate();
    expect(c.debugDisposed, isTrue);
    expect(cache.length, 0);
  });

  testWidgets('dropStale frees only the images of an old signature; retainOnly keeps a set', (tester) async {
    final cache = PageSnapshotCache();
    final old = (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!;
    final fresh = (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!;
    final other = (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!;
    cache.store(1, old, 'v1');
    cache.store(2, fresh, 'v2');
    cache.store(3, other, 'v2');
    cache.dropStale('v2');
    expect(old.debugDisposed, isTrue);
    expect(cache.pages, [2, 3]);
    cache.retainOnly({3});
    expect(fresh.debugDisposed, isTrue);
    expect(other.debugDisposed, isFalse);
    cache.dispose();
  });
}
