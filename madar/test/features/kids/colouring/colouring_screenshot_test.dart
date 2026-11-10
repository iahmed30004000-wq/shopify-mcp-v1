// Renders the colouring screens with the real fonts to
// madar/screenshots/kids_col_*.png, to compare with docs/kids/png/08a, 08b.
//
//   flutter test --tags screenshot test/features/kids/colouring/colouring_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/colouring/colouring.dart';
import 'package:madar/features/kids/colouring/data/colouring_store.dart';
import 'package:madar/features/kids/colouring/data/image_import.dart';
import 'package:madar/features/kids/colouring/domain/vector_colouring.dart';
import 'package:madar/features/kids/colouring/domain/vector_pages.dart';
import 'package:madar/features/kids/colouring/ui/palette.dart';

import '../../../helpers/screenshot_harness.dart';
import 'colouring_test_utils.dart';

void main() {
  late Directory dir;
  late ColouringStore store;
  late FakePicker picker;

  Widget shot(Widget child, {double scale = 1}) => ProviderScope(
    overrides: [
      colouringStoreProvider.overrideWith((ref) async => store),
      colouringPickerProvider.overrideWithValue(picker),
    ],
    child: madarScreenshotApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale), size: const Size(360, 780)),
        child: Scaffold(body: SafeArea(child: child)),
      ),
    ),
  );

  setUp(() {
    dir = tempDir();
    store = ColouringStore(dir);
    picker = FakePicker(null);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  const size = Size(360, 780);

  Future<void> seed(WidgetTester t) async {
    await t.runAsync(() async {
      final png = await makePng(240, 180);
      final c = await const ImageImporter().inspect(picked('a.png', png));
      final rec = await store.addPicture(c, c.asIs(), PictureMode.asIs);
      await store.savePictureOps(rec.id, const []);
      // colour two regions of the first page and the second
      final page = VectorPages.builtIn.first;
      final model = VectorColouring(page);
      for (var i = 0; i < page.regions.length; i += 2) {
        model.fill(i, argbOf(kColouringColours[(i ~/ 2) % 6]));
      }
      await store.savePageOps(page.id, model.ops);
    });
  }

  testWidgets('gallery', (t) async {
    await seed(t);
    await captureScreen(
      t,
      shot(const ColouringScreen(askParent: _yes)),
      'kids_col_gallery',
      logicalSize: size,
      dpr: 2,
      beforeCapture: (t) async {
        await settle(t, rounds: 30);
      },
    );
  });

  testWidgets('gallery at 1.3x on 320 wide', (t) async {
    await seed(t);
    await captureScreen(
      t,
      shot(const ColouringScreen(askParent: _yes), scale: 1.3),
      'kids_col_gallery_320',
      logicalSize: const Size(320, 640),
      dpr: 2,
      beforeCapture: (t) async {
        await settle(t, rounds: 30);
      },
    );
  });

  testWidgets('a page being coloured', (t) async {
    await seed(t);
    await captureScreen(
      t,
      shot(const ColouringScreen(askParent: _yes)),
      'kids_col_board',
      logicalSize: size,
      dpr: 2,
      beforeCapture: (t) async {
        await settle(t, rounds: 30);
        await t.tap(find.bySemanticsLabel('نقش ١'));
        await settle(t, rounds: 30);
      },
    );
  });

  testWidgets('his own picture being coloured', (t) async {
    await seed(t);
    await captureScreen(
      t,
      shot(const ColouringScreen(askParent: _yes)),
      'kids_col_picture',
      logicalSize: size,
      dpr: 2,
      beforeCapture: (t) async {
        await settle(t, rounds: 30);
        await eventuallyFound(t, find.bySemanticsLabel('صورة ١'));
        await t.tap(find.bySemanticsLabel('صورة ١'));
        await settle(t, rounds: 30);
        final board = find
            .byType(CustomPaint)
            .evaluate()
            .map((e) => e.renderObject as RenderBox)
            .where((b) => b.size.width > 250)
            .first;
        await t.tapAt(board.localToGlobal(Offset(board.size.width * 0.3, board.size.height * 0.5)));
        await settle(t, rounds: 30);
      },
    );
  });

  testWidgets('prepare a photo', (t) async {
    picker.result = picked('p.png', (await t.runAsync(() => makePng(300, 220, photo: true)))!);
    await captureScreen(
      t,
      shot(const ColouringScreen(askParent: _yes)),
      'kids_col_prep',
      logicalSize: size,
      dpr: 2,
      beforeCapture: (t) async {
        await settle(t, rounds: 4);
        await t.tap(find.text('اختر ملف'));
        await settle(t, rounds: 30);
      },
    );
  });

  testWidgets('a soft problem message', (t) async {
    picker.result = picked('x.png', Uint8List.fromList('hello'.codeUnits));
    await captureScreen(
      t,
      shot(const ColouringScreen(askParent: _yes)),
      'kids_col_problem',
      logicalSize: size,
      dpr: 2,
      beforeCapture: (t) async {
        await settle(t, rounds: 4);
        await t.tap(find.text('اختر ملف'));
        await settle(t, rounds: 30);
      },
    );
  });
}

Future<bool> _yes() async => true;
