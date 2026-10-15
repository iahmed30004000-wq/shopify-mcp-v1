import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/saved_games/data/game_meta_fetcher.dart';
import 'package:madar/features/saved_games/domain/saved_web_game.dart';

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('never fetches over http (no request, no icon guess)', () async {
    final fetcher = HttpGameMetaFetcher();
    expect(await fetcher.fetchTitle(Uri.parse('http://example.com/')), isNull);
    expect(await fetcher.fetchIcon(Uri.parse('http://example.com/')), isNull);
  });

  test('a site icon is redrawn as a small square PNG within the stored bound', () async {
    final png = await squareIconPng(await _png(300, 150));
    expect(png, isNotNull);
    expect(png!.length, lessThanOrEqualTo(SavedGamesLimits.maxIconBytes));
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, SavedGamesLimits.iconPixels);
    expect(frame.image.height, SavedGamesLimits.iconPixels);
    frame.image.dispose();
    codec.dispose();
  });

  test('non-images and tiny images are refused', () async {
    expect(await squareIconPng(Uint8List(0)), isNull);
    expect(await squareIconPng(Uint8List.fromList(List.filled(64, 7))), isNull);
    expect(await squareIconPng(await _png(4, 4)), isNull);
  });
}
