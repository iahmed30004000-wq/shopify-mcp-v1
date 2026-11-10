// Shared helpers for the orbit presentation tests: shader preloading, a
// fixed Amman clock and prayer settings that match the host time zone.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/widgets/ambient_motion.dart';
import 'package:madar/core/design/widgets/shader_cache.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe_shaders.dart';
import 'package:madar/features/orbit/render/orbit_shaders.dart';
import 'package:madar/features/orbit/render/sky/sky_shaders.dart';

import '../../../helpers/screenshot_harness.dart';

/// Loads every orbit shader program outside the fake-async zone.
Future<void> preloadOrbitShaders(WidgetTester tester) async {
  await tester.runAsync(() async {
    await OrbitShaders.load();
    await SkyPrograms.load();
    await AstrolabePrograms.load();
  });
}

/// Whether the host clock runs on Amman time (UTC+3), so the default prayer
/// settings produce the real local prayer times.
bool get hostIsAmman => DateTime(2026, 9, 27, 12).timeZoneOffset == const Duration(hours: 3);

/// Prayer settings whose local times look like Amman's on any host: Amman's
/// latitude, and a longitude matching the host's UTC offset (so solar noon
/// falls near 12:00 local wherever the tests run).
PrayerSettings hostPrayerSettings() {
  if (hostIsAmman) return const PrayerSettings();
  final offset = DateTime(2026, 9, 27, 12).timeZoneOffset.inMinutes / 60;
  return PrayerSettings(longitude: offset * 15 - 9.09);
}

/// Screenshot sequences of the running app (captureScreen always pumps
/// after its callback; a fly-in needs frames at exact moments).
class SceneShots {
  SceneShots(this.tester, {this.dpr = 2.625, this.size = const Size(412, 915)});

  final WidgetTester tester;
  final double dpr;
  final Size size;
  final GlobalKey boundary = GlobalKey();
  bool? _shadows;

  /// Pumps [app] at phone size with fonts, shaders and live ambient motion,
  /// then lets it settle for [settle].
  Future<void> start(Widget app, {Duration settle = const Duration(milliseconds: 1600)}) async {
    await tester.runAsync(() async {
      await loadMadarFonts();
      await MadarShaders.preload();
    });
    await preloadOrbitShaders(tester);
    tester.view.physicalSize = size * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    AmbientMotion.debugOverride = true;
    _shadows = debugDisableShadows;
    debugDisableShadows = false;
    await tester.pumpWidget(RepaintBoundary(key: boundary, child: app));
    await frames(settle);
  }

  /// Pumps frames (16 ms apart) for [d].
  Future<void> frames(Duration d, {Duration step = const Duration(milliseconds: 16)}) async {
    for (var t = Duration.zero; t < d; t += step) {
      await tester.pump(step);
    }
  }

  /// Writes the current frame to `screenshots/<name>.png`.
  Future<File> snap(String name) async {
    final file = File('screenshots/$name.png');
    await tester.runAsync(() async {
      final b = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await b.toImage(pixelRatio: dpr);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
    return file;
  }

  /// Restores the global debug switches (call at the end of the test body).
  void finish() {
    AmbientMotion.debugOverride = null;
    final s = _shadows;
    if (s != null) debugDisableShadows = s;
  }
}
