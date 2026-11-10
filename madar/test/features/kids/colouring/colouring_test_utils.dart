import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/colouring/data/image_import.dart';

/// A PNG made by the engine: a black frame with a cross on white (line art),
/// or a smooth gradient (a "photo").
Future<Uint8List> makePng(int w, int h, {bool photo = false}) async {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  final full = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  if (photo) {
    canvas.drawRect(
      full,
      ui.Paint()
        ..shader = ui.Gradient.linear(ui.Offset.zero, ui.Offset(w.toDouble(), h.toDouble()), [
          Colors.black,
          Colors.white,
        ]),
    );
  } else {
    canvas.drawRect(full, ui.Paint()..color = Colors.white);
    final ink = ui.Paint()
      ..color = Colors.black
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRect(ui.Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.8, h * 0.8), ink);
    canvas.drawLine(ui.Offset(w * 0.5, h * 0.1), ui.Offset(w * 0.5, h * 0.9), ink);
  }
  final image = await rec.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

class FakePicker implements ColouringImagePicker {
  FakePicker(this.result);
  PickedImage? result;
  int calls = 0;

  @override
  Future<PickedImage?> pick() async {
    calls++;
    return result;
  }
}

PickedImage picked(String name, Uint8List bytes, {int? declared}) =>
    PickedImage(name: name, read: () async => bytes, sizeBytes: declared ?? bytes.length);

Directory tempDir() => Directory.systemTemp.createTempSync('madar_colouring_ui_');

/// Lets real async work (codecs, isolates, file I/O) finish while the widget
/// tree is pumped. [tester.runAsync] steps out of the fake clock for a moment.
Future<void> settle(WidgetTester tester, {int rounds = 25}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 40));
  }
}

/// Pumps (and lets real async work run) until [cond] holds, or fails after
/// [maxMs]. Better than a fixed number of rounds on a loaded machine.
Future<void> eventually(
  WidgetTester tester,
  Future<bool> Function() cond, {
  int maxMs = 15000,
  String reason = 'condition',
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < maxMs) {
    if (await tester.runAsync(cond) == true) return;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('timed out after ${maxMs}ms waiting for $reason');
}

/// Until something is on screen.
Future<void> eventuallyFound(WidgetTester tester, Finder f, {int maxMs = 15000}) =>
    eventually(tester, () async => f.evaluate().isNotEmpty, maxMs: maxMs, reason: f.describeMatch(Plurality.zero));
