import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/kids/colouring/colouring.dart';
import 'package:madar/features/kids/colouring/data/colouring_store.dart';
import 'package:madar/features/kids/colouring/data/image_import.dart';
import 'package:madar/features/kids/colouring/domain/flood_fill.dart';
import 'package:madar/features/kids/colouring/domain/vector_pages.dart';
import 'package:madar/features/kids/colouring/ui/palette.dart';
import 'package:madar/features/kids/learn/ui/kids_widgets.dart' show KidsButton;

import '../learn/kids_harness.dart';
import 'colouring_test_utils.dart';

void main() {
  late Directory dir;
  late ColouringStore store;
  late FakePicker picker;
  late int gateCalls;
  late bool gateAnswer;
  late List<Override> overrides;

  setUp(() {
    dir = tempDir();
    store = ColouringStore(dir);
    picker = FakePicker(null);
    gateCalls = 0;
    gateAnswer = true;
    overrides = [
      colouringStoreProvider.overrideWith((ref) async => store),
      colouringPickerProvider.overrideWithValue(picker),
    ];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Widget screen({double scale = 1, String lang = 'ar', bool withGate = true}) => kidsApp(
    ColouringScreen(
      askParent: withGate
          ? () async {
              gateCalls++;
              return gateAnswer;
            }
          : null,
    ),
    textScale: scale,
    locale: Locale(lang),
    overrides: overrides,
  );

  L10n l10n(WidgetTester tester) => L10n.of(tester.element(find.byType(ColouringScreen)));

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text);
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
  }

  /// The save button is disabled (greyed) while the preview is being made.
  bool saveDisabled(WidgetTester tester, L10n l) {
    final f = find.ancestor(of: find.text(l.kidsColSavePicture), matching: find.byType(KidsButton));
    return f.evaluate().isEmpty || tester.widget<KidsButton>(f).onTap == null;
  }

  void phone(WidgetTester tester, {double w = 360, double h = 900}) => setPhone(tester, width: w, height: h);

  group('gallery', () {
    testWidgets('shows the import card for parents, the six built-in pages and no "mine" shelf when empty', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(screen());
      await settle(tester, rounds: 4);
      final l = l10n(tester);
      expect(find.text(l.kidsColAddTitle), findsOneWidget);
      expect(find.text(l.kidsColParentOnly), findsOneWidget);
      expect(find.text(l.kidsColMadar), findsOneWidget);
      expect(find.text(l.kidsColMine), findsNothing);
      for (var i = 1; i <= 6; i++) {
        expect(find.bySemanticsLabel(l.kidsColPatternName(['١', '٢', '٣', '٤', '٥', '٦'][i - 1])), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the child cannot add a picture: the gate says no, the picker is never opened', (tester) async {
      phone(tester);
      gateAnswer = false;
      picker.result = picked('x.png', (await tester.runAsync(() => makePng(40, 40)))!);
      await tester.pumpWidget(screen());
      await settle(tester, rounds: 3);
      await tapText(tester, l10n(tester).kidsColPickFile);
      await settle(tester, rounds: 3);
      expect(gateCalls, 1);
      expect(picker.calls, 0);
      expect(find.text(l10n(tester).kidsColBadFile), findsNothing);
      expect((await tester.runAsync(store.pictures))!, isEmpty);
    });

    testWidgets('with no gate wired in, importing is refused by default (safe until the shell connects it)', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(screen(withGate: false));
      await settle(tester, rounds: 3);
      await tapText(tester, l10n(tester).kidsColPickFile);
      await settle(tester, rounds: 3);
      expect(picker.calls, 0);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      phone(tester);
      await tester.pumpWidget(screen());
      await settle(tester, rounds: 3);
      await tapText(tester, l10n(tester).kidsColPickFile);
      await settle(tester, rounds: 4);
      expect(picker.calls, 1);
      expect(find.text(l10n(tester).kidsColBadFile), findsNothing);
      expect(find.text(l10n(tester).kidsColPrepTitle), findsNothing);
    });

    for (final c in [('a text file named .png', 'notImage'), ('a 2 GB file', 'tooBig')]) {
      testWidgets('${c.$1} gets a soft amber message and no wrong wording', (tester) async {
        phone(tester);
        picker.result = c.$2 == 'notImage'
            ? picked('cat.png', Uint8List.fromList('not a picture'.codeUnits))
            : PickedImage(
                name: 'huge.png',
                read: () async => throw StateError('must not be read'),
                sizeBytes: 2 * 1024 * 1024 * 1024,
              );
        await tester.pumpWidget(screen());
        await settle(tester, rounds: 3);
        await tapText(tester, l10n(tester).kidsColPickFile);
        await settle(tester, rounds: 6);
        final l = l10n(tester);
        expect(find.text(l.kidsColBadFile), findsOneWidget);
        expect(find.text(c.$2 == 'notImage' ? l.kidsColNotImage : l.kidsColTooBig), findsOneWidget);
        for (final w in ['خطأ', 'غلط', 'wrong', 'Wrong']) {
          expect(find.textContaining(w), findsNothing);
        }
        expect((await tester.runAsync(store.pictures))!, isEmpty);
      });
    }

    testWidgets(
      'a real picture: gate, pick, prepare, save; it appears under «صوري» and is copied into the private folder',
      (tester) async {
        phone(tester);
        picker.result = picked('cat.png', (await tester.runAsync(() => makePng(160, 120)))!);
        await tester.pumpWidget(screen());
        await settle(tester, rounds: 3);
        await tapText(tester, l10n(tester).kidsColPickFile);
        final l = l10n(tester);
        await eventuallyFound(tester, find.text(l.kidsColPrepTitle));
        expect(find.text(l.kidsColPrepLinesHint), findsOneWidget, reason: 'a line drawing is offered as it is');
        await eventually(tester, () async => !saveDisabled(tester, l), reason: 'the preview to be ready');
        await tapText(tester, l.kidsColSavePicture);
        await eventuallyFound(tester, find.text(l.kidsColMine));
        final saved = (await tester.runAsync(store.pictures))!;
        expect(saved.length, 1);
        expect(saved.single.mode, PictureMode.asIs);
        expect(
          Directory('${dir.path}/pictures/${saved.single.id}').listSync().any((e) => e.path.contains('original.')),
          isTrue,
        );
      },
    );

    testWidgets('a photo is offered as an outline by default', (tester) async {
      phone(tester);
      picker.result = picked('photo.png', (await tester.runAsync(() => makePng(160, 120, photo: true)))!);
      await tester.pumpWidget(screen());
      await settle(tester, rounds: 3);
      await tapText(tester, l10n(tester).kidsColPickFile);
      final l = l10n(tester);
      await eventuallyFound(tester, find.text(l.kidsColPrepPhotoHint));
      expect(find.text(l.kidsColLevelMid), findsOneWidget, reason: 'the detail chooser is shown for an outline');
      await eventually(tester, () async => !saveDisabled(tester, l), reason: 'the outline to be ready');
      await tapText(tester, l.kidsColSavePicture);
      await eventually(tester, () async => (await store.pictures()).isNotEmpty, reason: 'the picture to be saved');
      expect((await tester.runAsync(store.pictures))!.single.mode, PictureMode.outline);
    });

    testWidgets('delete is parent-only: gate no does nothing, gate yes asks, yes removes the picture and its folder', (
      tester,
    ) async {
      phone(tester);
      final png = (await tester.runAsync(() => makePng(80, 80)))!;
      final candidate = (await tester.runAsync(() => const ImageImporter().inspect(picked('a.png', png))))!;
      final rec = (await tester.runAsync(() => store.addPicture(candidate, candidate.asIs(), PictureMode.asIs)))!;
      await tester.pumpWidget(screen());
      await settle(tester, rounds: 6);
      final l = l10n(tester);
      expect(find.text(l.kidsColMine), findsOneWidget);

      gateAnswer = false;
      await tester.tap(find.bySemanticsLabel(l.kidsColDelete));
      await settle(tester, rounds: 3);
      expect(find.text(l.kidsColDeleteAsk), findsNothing);

      gateAnswer = true;
      await tester.tap(find.bySemanticsLabel(l.kidsColDelete));
      await settle(tester, rounds: 3);
      expect(find.text(l.kidsColDeleteAsk), findsOneWidget);
      await tapText(tester, l.kidsColDeleteYes);
      await settle(tester, rounds: 6);
      expect(find.text(l.kidsColMine), findsNothing);
      expect(Directory('${dir.path}/pictures/${rec.id}').existsSync(), isFalse);
    });
  });

  group('colouring a built-in page', () {
    testWidgets('tap fills a region and is saved; undo, eraser and clear work; it survives leaving and returning', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(screen());
      await settle(tester, rounds: 3);
      final l = l10n(tester);
      await tester.tap(find.bySemanticsLabel(l.kidsColPatternName('١')));
      await settle(tester, rounds: 4);
      expect(find.text(l.kidsColSaved), findsOneWidget);

      // tap the centre of the picture (the smallest region)
      final board = find
          .byType(CustomPaint)
          .evaluate()
          .map((e) => e.renderObject as RenderBox)
          .where((b) => b.size.width > 250 && b.size.height > 250)
          .first;
      final centre = board.localToGlobal(board.size.center(Offset.zero));
      await tester.tapAt(centre);
      await eventually(
        tester,
        () async => (await store.loadPageOps('khatam')).length == 1,
        reason: 'the first fill to be saved',
      );
      var ops = (await tester.runAsync(() => store.loadPageOps('khatam')))!;
      expect(ops.single.argb, argbOf(kColouringColours.first));

      // pick the second colour and fill the same region again
      await tester.tap(find.bySemanticsLabel(l.kidsColSwatch(2)));
      await tester.pump();
      await tester.tapAt(centre);
      await eventually(
        tester,
        () async => (await store.loadPageOps('khatam')).length == 2,
        reason: 'the second fill to be saved',
      );
      ops = (await tester.runAsync(() => store.loadPageOps('khatam')))!;
      expect(ops.map((o) => o.argb), [argbOf(kColouringColours[0]), argbOf(kColouringColours[1])]);

      await tester.tap(find.bySemanticsLabel(l.kidsColUndo));
      await eventually(
        tester,
        () async => (await store.loadPageOps('khatam')).length == 1,
        reason: 'the undo to be saved',
      );

      await tester.tap(find.bySemanticsLabel(l.kidsColEraser));
      await tester.pump();
      await tester.tapAt(centre);
      await eventually(
        tester,
        () async => (await store.loadPageOps('khatam')).length == 2,
        reason: 'the erase to be saved',
      );
      ops = (await tester.runAsync(() => store.loadPageOps('khatam')))!;
      expect(ops.last.argb, 0, reason: 'erased');

      await tapText(tester, l.kidsColClear);
      await eventually(
        tester,
        () async => (await store.loadPageOps('khatam')).isEmpty,
        reason: 'the clear to be saved',
      );

      // colour once more, finish, come back: the gallery shows it as started and reopening keeps the colour
      await tester.tap(find.bySemanticsLabel(l.kidsColSwatch(3)));
      await tester.pump();
      await tester.tapAt(centre);
      await eventually(
        tester,
        () async => (await store.loadPageOps('khatam')).length == 1,
        reason: 'the colour to be saved',
      );
      await tapText(tester, l.kidsColDone);
      await eventuallyFound(tester, find.text(l.kidsColAddTitle));
      await settle(tester, rounds: 6);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget, reason: 'the started page has its tick');
      expect((await tester.runAsync(() => store.loadPageOps('khatam')))!.single.argb, argbOf(kColouringColours[2]));
    });

    testWidgets('the system back button returns to the gallery, not out of the section', (tester) async {
      phone(tester);
      await tester.pumpWidget(screen());
      await settle(tester, rounds: 3);
      final l = l10n(tester);
      await tester.tap(find.bySemanticsLabel(l.kidsColPatternName('٢')));
      await settle(tester, rounds: 3);
      expect(find.text(l.kidsColAddTitle), findsNothing);
      await tester.binding.handlePopRoute();
      await settle(tester, rounds: 3);
      expect(find.text(l.kidsColAddTitle), findsOneWidget);
    });

    test('there is no red in the palette (the design forbids it)', () {
      for (final c in kColouringColours) {
        final hsv = HSVColor.fromColor(c);
        final nearRed = (hsv.hue < 15 || hsv.hue > 350) && hsv.saturation > 0.6 && hsv.value > 0.4;
        expect(nearRed, isFalse, reason: '$c');
      }
      expect(kColouringColours.length, greaterThanOrEqualTo(8));
    });
  });

  group('colouring one of his own pictures', () {
    testWidgets('open, fill, restart (new screen), the colours are still there', (tester) async {
      phone(tester);
      final png = (await tester.runAsync(() => makePng(120, 120)))!;
      final candidate = (await tester.runAsync(() => const ImageImporter().inspect(picked('a.png', png))))!;
      final rec = (await tester.runAsync(() => store.addPicture(candidate, candidate.asIs(), PictureMode.asIs)))!;

      await tester.pumpWidget(screen());
      await settle(tester, rounds: 6);
      final l = l10n(tester);
      await tester.tap(find.bySemanticsLabel(l.kidsColPictureName('١')));
      await settle(tester, rounds: 10);
      final board = find
          .byType(CustomPaint)
          .evaluate()
          .map((e) => e.renderObject as RenderBox)
          .where((b) => b.size.width > 250)
          .first;
      // the left half of the picture (inside the frame, left of the cross)
      await tester.tapAt(board.localToGlobal(Offset(board.size.width * 0.3, board.size.height * 0.5)));
      await eventually(
        tester,
        () async => (await store.pictures()).single.ops.length == 1,
        reason: 'the first fill to be saved',
      );
      var back = (await tester.runAsync(store.pictures))!.single;

      // a tap on the other half is a different region: two fills
      await tester.tap(find.bySemanticsLabel(l.kidsColSwatch(2)));
      await tester.pump();
      await tester.tapAt(board.localToGlobal(Offset(board.size.width * 0.7, board.size.height * 0.5)));
      await eventually(
        tester,
        () async => (await store.pictures()).single.ops.length == 2,
        reason: 'the second fill to be saved',
      );
      back = (await tester.runAsync(store.pictures))!.single;
      final art = (await tester.runAsync(() => store.loadArt(rec.id)))!;
      final canvas = ColourCanvas(art)..replay(back.ops);
      expect(canvas.colours[60 * 120 + 40], isNot(canvas.colours[60 * 120 + 85]), reason: 'two rooms, two colours');

      await tester.tap(find.bySemanticsLabel(l.kidsColUndo));
      await eventually(
        tester,
        () async => (await store.pictures()).single.ops.length == 1,
        reason: 'the undo to be saved',
      );
    });

    testWidgets('a picture whose page file is missing shows a soft message instead of crashing', (tester) async {
      phone(tester);
      final png = (await tester.runAsync(() => makePng(60, 60)))!;
      final candidate = (await tester.runAsync(() => const ImageImporter().inspect(picked('a.png', png))))!;
      final rec = (await tester.runAsync(() => store.addPicture(candidate, candidate.asIs(), PictureMode.asIs)))!;
      await tester.pumpWidget(screen());
      await settle(tester, rounds: 6);
      File('${dir.path}/pictures/${rec.id}/art.gray').deleteSync();
      await tester.tap(find.bySemanticsLabel(l10n(tester).kidsColPictureName('١')));
      await settle(tester, rounds: 6);
      expect(tester.takeException(), isNull);
    });
  });

  group('layout: RTL and English, 320 dp wide, text scale 1.3', () {
    for (final scale in [1.0, 1.3]) {
      for (final lang in ['ar', 'en']) {
        testWidgets('gallery, a page and the prepare step at ${scale}x $lang', (tester) async {
          phone(tester, w: 320, h: 640);
          picker.result = picked('photo.png', (await tester.runAsync(() => makePng(160, 120, photo: true)))!);
          await tester.pumpWidget(screen(scale: scale, lang: lang));
          await settle(tester, rounds: 4);
          expect(tester.takeException(), isNull);
          final l = l10n(tester);
          await tapText(tester, l.kidsColPickFile);
          await settle(tester, rounds: 14);
          expect(tester.takeException(), isNull, reason: 'prepare step');
          await tester.binding.handlePopRoute();
          await settle(tester, rounds: 3);
          final tile = find.bySemanticsLabel(l.kidsColPatternName(lang == 'ar' ? '١' : '1'));
          await tester.ensureVisible(tile);
          await tester.pump();
          await tester.tap(tile);
          await settle(tester, rounds: 4);
          expect(tester.takeException(), isNull, reason: 'board');
          expect(VectorPages.builtIn, isNotEmpty);
        });
      }
    }
  });
}
