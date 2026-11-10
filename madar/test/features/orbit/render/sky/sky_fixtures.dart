import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';
import 'package:madar/features/orbit/render/sky/sky.dart';

/// Named instants for sky tests (Amman is UTC+3 all year).
class SkyShot {
  const SkyShot(this.name, this.time);

  final String name;
  final DateTime time;

  static DateTime amman(int y, int m, int d, int h, int min) => DateTime.utc(y, m, d, h - 3, min);

  static final fajr = SkyShot('fajr_0535', amman(2026, 9, 27, 5, 35));
  static final noon = SkyShot('noon_1230', amman(2026, 9, 27, 12, 30));
  static final golden = SkyShot('golden_1755', amman(2026, 9, 27, 17, 55));
  static final maghrib = SkyShot('maghrib_1840', amman(2026, 9, 27, 18, 40));
  static final night = SkyShot('night_2230', amman(2026, 9, 27, 22, 30));
  static final newMoon = SkyShot('newmoon_2200', amman(2026, 10, 10, 22, 0));

  /// A moonless summer night with the galactic centre near the qibla view.
  static final milkyWay = SkyShot('milkyway_0714_2300', amman(2026, 7, 14, 23, 0));

  /// A young waxing crescent low in the west after Maghrib (bright limb
  /// toward the set sun, earthshine on the dark side).
  static final crescent = SkyShot('crescent_1013_1850', amman(2026, 10, 13, 18, 50));

  /// The six reference instants of the work package, plus two showcases.
  static final all = [fajr, noon, golden, maghrib, night, newMoon, milkyWay, crescent];
}

/// A light Madar theme tone for pure tests.
SkyTone testTone({bool dark = true}) => dark
    ? const SkyTone(
        dark: true,
        space0: Color(0xFF03050F),
        space1: Color(0xFF070B1E),
        nebulaA: Color(0xFF2B3FA8),
        nebulaB: Color(0xFF7A2E8C),
        starTint: Color(0xFFFFF1D6),
        gold: Color(0xFFE8C77A),
        engrave: Color(0xFFC9CDD8),
        engraveShadow: Color(0xFF03050F),
      )
    : const SkyTone(
        dark: false,
        space0: Color(0xFFF7F3EA),
        space1: Color(0xFFEFE8DA),
        nebulaA: Color(0xFFE9D8B8),
        nebulaB: Color(0xFFD7DDF2),
        starTint: Color(0xFFB0802A),
        gold: Color(0xFFC39334),
        engrave: Color(0xFF5B5446),
        engraveShadow: Color(0xFFEFE8DA),
      );

/// The sky as it sits behind the home screen: optionally with a stand-in
/// for the astrolabe (so framing can be judged), the lens flares and the
/// glass panel below.
class SkyPreviewScene extends StatefulWidget {
  const SkyPreviewScene({super.key, required this.time, this.withScene = false, this.camera = const OrbitCamera()});

  final DateTime time;
  final bool withScene;
  final OrbitCamera camera;

  @override
  State<SkyPreviewScene> createState() => _SkyPreviewSceneState();
}

class _SkyPreviewSceneState extends State<SkyPreviewScene> {
  late final SkyController _controller = SkyController(time: widget.time, camera: widget.camera)..still = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final centre = Offset(size.width * 0.5, size.height * 0.4);
        final r = size.width * 0.42;
        if (widget.withScene) {
          _controller
            ..coreStar = centre
            ..labelKeepOut = Rect.fromCircle(center: centre, radius: r * 1.08);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            SkyLayer(controller: _controller),
            if (widget.withScene) ...[
              CustomPaint(painter: _AstrolabeStandIn(centre, r, context.tokens)),
              // Flares belong above the scene, below the UI panels.
              SkyFlareLayer(controller: _controller),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: size.height * 0.46,
                child: const GlassPanel(child: SizedBox.expand()),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AstrolabeStandIn extends CustomPainter {
  _AstrolabeStandIn(this.c, this.r, this.t);

  final Offset c;
  final double r;
  final MadarTokens t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = ui.Gradient.radial(c, r, [t.space2.withValues(alpha: 0.9), t.space1.withValues(alpha: 0.95)]),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = t.brass,
    );
    canvas.drawCircle(
      c,
      r * 0.3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = t.gold,
    );
    canvas.drawCircle(
      c,
      r * 0.14,
      Paint()..shader = ui.Gradient.radial(c, r * 0.14, [const Color(0xFFFFFFFF), t.gold.withValues(alpha: 0)]),
    );
  }

  @override
  bool shouldRepaint(_AstrolabeStandIn old) => false;
}
