import 'package:flutter/material.dart';

import 'geometry_pattern_painter.dart';
import 'mashrabiya_lattice.dart';
import 'pattern_bloom_reveal.dart';
import 'pattern_divider.dart';
import 'pattern_frame.dart';
import 'pattern_palette.dart';
import 'pattern_spec.dart';
import 'star_progress_ring.dart';

/// Developer gallery of everything in this folder, for the integrator's
/// screenshots. Labels are plain identifiers, not app copy.
class PatternGalleryPage extends StatelessWidget {
  const PatternGalleryPage({
    super.key,
    this.background = const Color(0xFF0B1020),
    this.foreground = const Color(0xFFE6C36A),
    this.accent = const Color(0xFF6FD3C8),
  });

  final Color background, foreground, accent;

  static const double _tile = 148;

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(color: foreground.withValues(alpha: 0.8), fontSize: 11);
    Widget cell(String name, Widget child) => SizedBox(
      width: _tile,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _tile,
            height: _tile,
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
          ),
          const SizedBox(height: 4),
          Text(name, style: label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );

    return Material(
      color: background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final f in PatternFamily.values)
                    cell(
                      f.name,
                      CustomPaint(
                        painter: GeometryPatternPainter(
                          spec: PatternSpec(family: f, repeat: 3, lineWidth: 1.4),
                          color: foreground,
                          glowColor: accent.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final key in PatternPalette.planetKeys)
                    cell(key, _planet(PatternPalette.forPlanet(key))),
                ],
              ),
              const SizedBox(height: 16),
              PatternDivider(spec: const PatternSpec(family: PatternFamily.square4), color: foreground, height: 28),
              const SizedBox(height: 12),
              PatternDivider(spec: const PatternSpec(family: PatternFamily.girih10), color: accent, height: 22),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: PatternFrame(
                  spec: const PatternSpec(family: PatternFamily.rosette12, lineWidth: 1),
                  color: foreground,
                  child: Center(child: Text('frame', style: label)),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (final (points, v) in const [(8, 0.0), (8, 0.5), (8, 1.0), (12, 0.25), (12, 0.75)])
                    StarProgressRing(
                      value: v,
                      points: points,
                      progressColor: foreground,
                      trackColor: foreground.withValues(alpha: 0.2),
                      animationDuration: Duration.zero,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  cell(
                    'bloom 0.6',
                    PatternBloomReveal(
                      progress: 0.6,
                      spec: const PatternSpec(family: PatternFamily.hex6, repeat: 4),
                      color: accent,
                    ),
                  ),
                  cell(
                    'mashrabiya',
                    MashrabiyaLattice(
                      barColor: foreground.withValues(alpha: 0.75),
                      lightColor: accent,
                      cellSize: 36,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planet(PatternPalette p) => ColoredBox(
    color: p.color.withValues(alpha: 0.12),
    child: CustomPaint(
      painter: GeometryPatternPainter(
        spec: p.spec.copyWith(repeat: 3, lineWidth: 1.3),
        color: p.color,
        glowColor: p.accent.withValues(alpha: 0.3),
        glowSigma: 2.5,
      ),
    ),
  );
}
