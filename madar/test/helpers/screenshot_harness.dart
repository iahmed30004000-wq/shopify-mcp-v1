// Screenshot harness: renders real Madar screens with the real bundled fonts
// and shaders at phone size and writes PNGs to `screenshots/<name>.png`
// (relative to the package root, i.e. madar/screenshots/).
//
// Used by @Tags(['screenshot']) tests for visual critic passes:
//   flutter test --tags screenshot
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/shader_cache.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

bool _fontsLoaded = false;

/// Loads IBM Plex Sans Arabic (all weights), Reem Kufi, Amiri Quran, Amiri
/// and the Material Icons font from the Flutter SDK, so screenshots show real
/// glyphs instead of the test font's boxes. Idempotent.
///
/// Must run outside the fake-async zone: call it in `setUpAll` or inside
/// `tester.runAsync` ([captureScreen] does the latter for you).
Future<void> loadMadarFonts() async {
  if (_fontsLoaded) return;
  Future<void> family(String name, List<String> paths) async {
    final loader = FontLoader(name);
    for (final path in paths) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  const fonts = 'assets/fonts';
  await family('PlexArabic', [
    for (final w in ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold']) '$fonts/IBMPlexSansArabic-$w.ttf',
  ]);
  await family('ReemKufi', ['$fonts/ReemKufi-Variable.ttf']);
  await family('AmiriQuran', ['$fonts/AmiriQuran-Regular.ttf']);
  await family('Amiri', ['$fonts/Amiri-Regular.ttf', '$fonts/Amiri-Bold.ttf']);
  final icons = _materialIconsFont();
  if (icons != null) await family('MaterialIcons', [icons.path]);
  _fontsLoaded = true;
}

File? _materialIconsFont() {
  const rel = 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?) root,
  ];
  // flutter_tester lives in <root>/bin/cache/artifacts/engine/<platform>/.
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    roots.add(dir.path);
    dir = dir.parent;
  }
  for (final root in roots) {
    final f = File('$root/$rel');
    if (f.existsSync()) return f;
  }
  return null;
}

/// Wraps [home] in a MaterialApp configured like the real app (Madar theme,
/// localisations, locale-driven direction).
Widget madarScreenshotApp({
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
}) {
  final arabic = locale.languageCode == 'ar';
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildMadarTheme(theme, arabic: arabic),
    locale: locale,
    supportedLocales: L10n.supportedLocales,
    localizationsDelegates: L10n.localizationsDelegates,
    home: home,
  );
}

/// Renders [app] at phone size ([logicalSize] × [dpr]), pumps enough frames
/// for entrance animations and shader loading, and writes the result to
/// `screenshots/<name>.png`. Returns the written file.
///
/// [beforeCapture] may drive the UI (scroll, tap) before the capture.
Future<File> captureScreen(
  WidgetTester tester,
  Widget app,
  String name, {
  Size logicalSize = const Size(412, 915),
  double dpr = 2.625,
  Future<void> Function(WidgetTester tester)? beforeCapture,
  Duration settle = const Duration(milliseconds: 1600),
}) async {
  await tester.runAsync(() async {
    await loadMadarFonts();
    await MadarShaders.preload();
  });

  tester.view.physicalSize = logicalSize * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);

  final boundaryKey = GlobalKey();
  final previousShadows = debugDisableShadows;
  // Real shadows/glows – the test binding disables them for golden stability.
  debugDisableShadows = false;
  try {
    await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: app));
    const step = Duration(milliseconds: 50);
    for (var elapsed = Duration.zero; elapsed < settle; elapsed += step) {
      await tester.pump(step);
    }
    if (beforeCapture != null) {
      await beforeCapture(tester);
      for (var i = 0; i < 12; i++) {
        await tester.pump(step);
      }
    }
    final file = File('screenshots/$name.png');
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: dpr);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
    return file;
  } finally {
    debugDisableShadows = previousShadows;
  }
}
