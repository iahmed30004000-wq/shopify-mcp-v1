// Importing a parent's picture, and keeping it on the device: the copy lands
// in the private folder and nowhere else, only images are accepted, and
// nothing ever touches the network.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/colouring/data/colouring_store.dart';
import 'package:madar/features/kids/colouring/data/image_import.dart';
import 'package:madar/features/kids/colouring/domain/flood_fill.dart';
import 'package:madar/features/kids/colouring/domain/outline.dart';
import 'package:madar/features/kids/colouring/domain/vector_colouring.dart';

/// A PNG made by the engine: black ring on white (line art) or a smooth
/// gradient (a "photo").
Future<Uint8List> _png(int w, int h, {bool photo = false}) async {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  if (photo) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()
        ..shader = ui.Gradient.linear(ui.Offset.zero, ui.Offset(w.toDouble(), h.toDouble()), [
          Colors.black,
          Colors.white,
        ]),
    );
  } else {
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = Colors.white);
    canvas.drawRect(
      ui.Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.6, h * 0.6),
      ui.Paint()
        ..color = Colors.black
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }
  final image = await rec.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

PickedImage _pick(String name, Uint8List bytes, {int? declared}) =>
    PickedImage(name: name, read: () async => bytes, sizeBytes: declared ?? bytes.length);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const importer = ImageImporter();
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('madar_colouring_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<ImportFailure> failure(Future<Object?> f) async {
    try {
      await f;
    } on ImportFailure catch (e) {
      return e;
    }
    fail('expected an ImportFailure');
  }

  group('what is a picture (by content, not by name)', () {
    test('sniffs PNG, JPEG, GIF, BMP and WebP and reads their declared size', () async {
      final png = sniffImage(await _png(30, 20))!;
      expect((png.kind, png.width, png.height), (ImageKind.png, 30, 20));

      final jpeg = Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0x00,
        0x10,
        0x4A,
        0x46,
        0x49,
        0x46,
        0x00,
        0x01,
        0x01,
        0x00,
        0x00,
        0x01,
        0x00,
        0x01,
        0x00,
        0x00, // JFIF
        0xFF,
        0xC0,
        0x00,
        0x11,
        0x08,
        0x01,
        0x00,
        0x02,
        0x00,
        0x03,
        0x01,
        0x22,
        0x00,
        0x02,
        0x11,
        0x01,
        0x03,
        0x11,
        0x01, // SOF0 256 x 512
      ]);
      final j = sniffImage(jpeg)!;
      expect((j.kind, j.width, j.height), (ImageKind.jpeg, 512, 256));

      final gif = Uint8List.fromList([...'GIF89a'.codeUnits, 7, 0, 5, 0, 0, 0, 0]);
      expect(sniffImage(gif)!.width, 7);
      expect(sniffImage(gif)!.height, 5);

      final bmp = Uint8List(40)
        ..[0] = 0x42
        ..[1] = 0x4D
        ..[18] = 9
        ..[22] = 4;
      expect((sniffImage(bmp)!.kind, sniffImage(bmp)!.width, sniffImage(bmp)!.height), (ImageKind.bmp, 9, 4));

      final webp = Uint8List(32)
        ..setAll(0, 'RIFF'.codeUnits)
        ..setAll(8, 'WEBPVP8X'.codeUnits)
        ..[24] =
            99 // width - 1
        ..[27] = 49; // height - 1
      final w = sniffImage(webp)!;
      expect((w.kind, w.width, w.height), (ImageKind.webp, 100, 50));
    });

    test('text, PDFs, executables, empty and random bytes are not pictures', () {
      for (final bytes in [
        Uint8List.fromList('hello, this is not a picture'.codeUnits),
        Uint8List.fromList('%PDF-1.7 ...'.codeUnits),
        Uint8List.fromList([0x4D, 0x5A, 0x90, 0x00]),
        Uint8List(0),
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList('<svg xmlns="http://www.w3.org/2000/svg"></svg>'.codeUnits),
      ]) {
        expect(sniffImage(bytes), isNull);
      }
    });
  });

  group('accepting and rejecting', () {
    test('a file with a .png name that is really text is refused softly as notImage', () async {
      final e = await failure(importer.inspect(_pick('cute.png', Uint8List.fromList('just words'.codeUnits))));
      expect(e.error, ImportError.notImage);
    });

    test('a PDF named .jpg is notImage too', () async {
      final e = await failure(importer.inspect(_pick('photo.jpg', Uint8List.fromList('%PDF-1.4 ...'.codeUnits))));
      expect(e.error, ImportError.notImage);
    });

    test('a file that declares more than the byte limit is refused BEFORE it is read', () async {
      var read = false;
      final e = await failure(
        importer.inspect(
          PickedImage(
            name: 'huge.png',
            read: () async {
              read = true;
              return Uint8List(1);
            },
            sizeBytes: kMaxImageBytes + 1,
          ),
        ),
      );
      expect(e.error, ImportError.tooBig);
      expect(read, isFalse, reason: 'a 2 GB file is never loaded into memory');
    });

    test('bytes over the limit are refused even if the picker did not say', () async {
      final big = Uint8List(kMaxImageBytes + 1)..setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final e = await failure(importer.inspect(PickedImage(name: 'a.png', read: () async => big)));
      expect(e.error, ImportError.tooBig);
    });

    test('an image that declares absurd dimensions (20000 x 20000) is tooBig, without decoding it', () async {
      final bytes = Uint8List.fromList(await _png(8, 8));
      final bd = ByteData.sublistView(bytes);
      bd.setUint32(16, 20000);
      bd.setUint32(20, 20000);
      final e = await failure(importer.inspect(_pick('bomb.png', bytes)));
      expect(e.error, ImportError.tooBig);
    });

    test('a picture whose header is fine but whose data is broken is unreadable, not a crash', () async {
      final bytes = Uint8List.fromList(await _png(40, 40));
      final truncated = Uint8List.sublistView(bytes, 0, 40);
      final e = await failure(importer.inspect(_pick('cut.png', truncated)));
      expect(e.error, ImportError.unreadable);
    });

    test('a picker that fails while reading is unreadable', () async {
      final e = await failure(
        importer.inspect(PickedImage(name: 'x.png', read: () async => throw const FileSystemException('gone'))),
      );
      expect(e.error, ImportError.unreadable);
    });
  });

  group('downscaling', () {
    test('a large picture is brought down to at most 1024 on its longest side, keeping its shape', () async {
      final c = await importer.inspect(_pick('wide.png', await _png(2048, 1024)));
      expect(c.art.width, 1024);
      expect(c.art.height, 512);
      expect((c.sourceWidth, c.sourceHeight), (2048, 1024));
      final tall = await importer.inspect(_pick('tall.png', await _png(600, 3000)));
      expect(tall.art.height, 1024);
      expect(tall.art.width, lessThan(300));
    });

    test('a small picture is NOT blown up', () async {
      final c = await importer.inspect(_pick('small.png', await _png(100, 50)));
      expect((c.art.width, c.art.height), (100, 50));
    });

    test('line art is recognised as line art, a gradient as a photo', () async {
      expect((await importer.inspect(_pick('lines.png', await _png(200, 200)))).isPhoto, isFalse);
      expect((await importer.inspect(_pick('photo.png', await _png(200, 200, photo: true)))).isPhoto, isTrue);
    });

    test('as-is keeps the ink as a region barrier; the outline of a photo is a picture too', () async {
      final c = await importer.inspect(_pick('lines.png', await _png(200, 200)));
      final canvas = ColourCanvas(c.asIs());
      expect(canvas.fill(100, 100, 0xFFE26A89), greaterThan(0));
      expect(canvas.colours[5 * 200 + 5], ColourCanvas.paper, reason: 'the frame keeps the colour in');
      final p = await importer.inspect(_pick('photo.png', await _png(200, 200, photo: true)));
      final outline = await p.outline(OutlineLevel.many);
      expect((outline.width, outline.height), (200, 200));
    });
  });

  group('the private folder', () {
    ColouringStore store() => ColouringStore(Directory('${tmp.path}/app/kids_colouring'));

    test('importing copies the file into the private folder and leaves the original alone', () async {
      final original = File('${tmp.path}/DCIM/cat.png')..createSync(recursive: true);
      final bytes = await _png(120, 80);
      original.writeAsBytesSync(bytes);
      final c = await importer.inspect(
        PickedImage(name: 'cat.png', read: original.readAsBytes, sizeBytes: bytes.length),
      );
      final s = store();
      final rec = await s.addPicture(c, c.asIs(), PictureMode.asIs);

      final dir = Directory('${s.root.path}/pictures/${rec.id}');
      expect(dir.existsSync(), isTrue);
      final copy = dir.listSync().whereType<File>().firstWhere((f) => f.path.contains('original.'));
      expect(copy.path.startsWith(s.root.path), isTrue, reason: 'inside the private folder');
      expect(copy.readAsBytesSync(), bytes, reason: 'a true copy');
      expect(copy.path, isNot(original.path));
      expect(original.readAsBytesSync(), bytes, reason: 'the original is untouched');
      // deleting the original later changes nothing
      original.deleteSync();
      expect((await s.pictures()).single.id, rec.id);
      expect(await s.loadArt(rec.id), isNotNull);
    });

    test('nothing is written outside the private folder', () async {
      final before = tmp.listSync(recursive: true).map((e) => e.path).toSet();
      final c = await importer.inspect(_pick('a.png', await _png(64, 64)));
      final s = store();
      await s.addPicture(c, c.asIs(), PictureMode.asIs);
      final after = tmp.listSync(recursive: true).map((e) => e.path).toSet().difference(before);
      expect(after, isNotEmpty);
      expect(
        after.every((p) => p == '${tmp.path}/app' || p.startsWith('${tmp.path}/app/kids_colouring')),
        isTrue,
        reason: '$after',
      );
    });

    test('the page and its colours survive a restart (a round trip through a fresh store)', () async {
      final c = await importer.inspect(_pick('a.png', await _png(100, 100)));
      var s = store();
      final rec = await s.addPicture(c, c.asIs(), PictureMode.asIs);
      final art = (await s.loadArt(rec.id))!;
      final canvas = ColourCanvas(art);
      canvas
        ..fill(50, 50, 0xFFE26A89)
        ..fill(2, 2, 0xFF2FA59C);
      await s.savePictureOps(rec.id, canvas.ops);

      s = store(); // "the app was killed and relaunched"
      final back = (await s.pictures()).single;
      expect(back.id, rec.id);
      expect(back.started, isTrue);
      expect(back.ops, canvas.ops);
      final art2 = (await s.loadArt(back.id))!;
      expect(art2.grey, art.grey);
      final restored = ColourCanvas(art2)..replay(back.ops);
      expect(restored.colours, canvas.colours, reason: 'same picture, same colours');
    });

    test('art.gray round trip and refusal of damaged data', () {
      final art = LineArt(3, 2, Uint8List.fromList([0, 50, 100, 150, 200, 255]));
      final back = decodeArt(encodeArt(art))!;
      expect((back.width, back.height), (3, 2));
      expect(back.grey, orderedEquals(art.grey));
      expect(decodeArt(Uint8List(5)), isNull);
      expect(decodeArt(Uint8List.sublistView(encodeArt(art), 0, 14)), isNull);
      expect(decodeArt(Uint8List.fromList([...encodeArt(art), 0])), isNull);
    });

    test('delete removes the copy, the page and the colours', () async {
      final c = await importer.inspect(_pick('a.png', await _png(64, 64)));
      final s = store();
      final rec = await s.addPicture(c, c.asIs(), PictureMode.asIs);
      await s.deletePicture(rec.id);
      expect(Directory('${s.root.path}/pictures/${rec.id}').existsSync(), isFalse);
      expect(await s.pictures(), isEmpty);
      expect(await s.loadArt(rec.id), isNull);
    });

    test('ids that try to climb out of the folder do nothing', () async {
      final s = store();
      await s.deletePicture('../../etc');
      expect(await s.loadArt('../x'), isNull);
      await s.savePictureOps('../x', const []);
    });

    test('a damaged picture folder is skipped, the others still list', () async {
      final c = await importer.inspect(_pick('a.png', await _png(64, 64)));
      final s = store();
      final good = await s.addPicture(c, c.asIs(), PictureMode.asIs);
      final bad = await s.addPicture(c, c.asIs(), PictureMode.outline);
      File('${s.root.path}/pictures/${bad.id}/meta.json').writeAsStringSync('{ not json');
      Directory('${s.root.path}/pictures/emptyfolder1').createSync();
      expect((await s.pictures()).map((r) => r.id), [good.id]);
    });

    test('saves are atomic: no temporary files are left behind', () async {
      final c = await importer.inspect(_pick('a.png', await _png(64, 64)));
      final s = store();
      final rec = await s.addPicture(c, c.asIs(), PictureMode.asIs);
      await s.savePictureOps(rec.id, const [FillOp(1, 1, 0xFFE26A89)]);
      await s.savePageOps('khatam', const [RegionFill(0, 0xFF2FA59C)]);
      final leftovers = s.root.listSync(recursive: true).where((e) => e.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);
    });

    test('built-in page colours round trip and a missing or corrupt file means "nothing coloured yet"', () async {
      final s = store();
      expect(await s.loadPageOps('khatam'), isEmpty);
      await s.savePageOps('khatam', const [RegionFill(3, 0xFFE26A89), RegionFill(4, 0)]);
      expect(await store().loadPageOps('khatam'), const [RegionFill(3, 0xFFE26A89), RegionFill(4, 0)]);
      File('${s.root.path}/progress/khatam.json').writeAsStringSync('garbage');
      expect(await s.loadPageOps('khatam'), isEmpty);
      // a hostile page id can not name another file
      await s.savePageOps('../../evil', const []);
      expect(File('${tmp.path}/evil.json').existsSync(), isFalse);
    });
  });

  group('no network', () {
    test('the whole import, outline, save and delete path never creates an HTTP client', () async {
      final created = <String>[];
      await HttpOverrides.runZoned(
        () async {
          final c = await importer.inspect(_pick('p.png', await _png(120, 120, photo: true)));
          final out = await c.outline(OutlineLevel.some);
          final s = ColouringStore(Directory('${tmp.path}/nn'));
          final rec = await s.addPicture(c, out, PictureMode.outline);
          await s.savePictureOps(rec.id, [const FillOp(5, 5, 0xFFE26A89)]);
          await s.pictures();
          await s.deletePicture(rec.id);
        },
        createHttpClient: (context) {
          created.add('HttpClient');
          throw StateError('network is forbidden inside kids colouring');
        },
      );
      expect(created, isEmpty);
    });

    test('the colouring and learn sources import no network, sharing or launching library', () {
      const banned = [
        'HttpClient',
        'package:http/',
        'package:dio/',
        'Socket',
        'WebSocket',
        'url_launcher',
        'share_plus',
        'firebase',
        'nearby_connections',
        'webview',
        'Uri.http',
        'Uri.https',
        "'http://",
        "'https://",
      ];
      for (final root in ['lib/features/kids/colouring', 'lib/features/kids/learn']) {
        for (final f in Directory(
          root,
        ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
          final text = f.readAsStringSync();
          for (final b in banned) {
            expect(text.contains(b), isFalse, reason: '${f.path} mentions $b');
          }
        }
      }
    });
  });
}
