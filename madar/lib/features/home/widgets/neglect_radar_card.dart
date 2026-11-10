import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/themes.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/sound/sound_api.dart';
import '../../orbit/data/orbit_providers.dart';
import '../../orbit/domain/scene_snapshot.dart';
import '../../orbit/presentation/planet/planet_modules.dart';

/// Opens a planet page (optionally highlighting a record `refTable:refId`).
typedef OpenPlanet = void Function(String planetKey, {String? item});

/// The Neglect Radar in the home panel: the three weakest worlds, each with
/// its most urgent concrete reason («أبي — فات الموعد بـ٣ أيام», "2 doses past
/// due"); tapping one flies to that world (with the record highlighted).
/// When nothing is slipping it says so in one calm line.
///
/// [compact] (the peeking panel): a single line – the weakest world and its
/// reason, the other two as small orbs.
class NeglectRadarStrip extends ConsumerWidget {
  const NeglectRadarStrip({super.key, required this.onOpen, this.compact = false});

  final OpenPlanet onOpen;
  final bool compact;

  static String? _itemOf(RadarEntry e) =>
      e.opensPlanet || e.refTable == null ? null : PlanetModules.itemOf(e.refTable!, e.refId!);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final snapshot = ref.watch(sceneSnapshotProvider).value;
    final radar = snapshot?.radar ?? const <RadarEntry>[];
    if (compact) return _CompactRadar(snapshot: snapshot, radar: radar, onOpen: onOpen);
    final title = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.xs + 2),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: CustomPaint(
              painter: RadarScopePainter(ring: t.brass, sweep: t.accent, blips: const []),
            ),
          ),
          const SizedBox(width: Space.s),
          Semantics(
            header: true,
            child: Text(l.homeRadarTitle, style: text.labelMedium!.copyWith(color: t.textSecondary, height: 1.2)),
          ),
        ],
      ),
    );
    if (snapshot == null) return title;
    if (radar.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, 0),
            child: Text(
              snapshot.balanceDormant ? l.orbitUiRadarWaiting : l.orbitUiRadarClear,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall!.copyWith(color: t.textTertiary),
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < radar.length; i++) ...[
                  if (i > 0) const SizedBox(width: Space.s),
                  Expanded(
                    child: _RadarEntryCard(
                      entry: radar[i],
                      onTap: () => onOpen(radar[i].planetKey, item: _itemOf(radar[i])),
                    ),
                  ),
                ],
                for (var i = radar.length; i < 3; i++) ...[const SizedBox(width: Space.s), const Spacer()],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The radar in one line (the peeking panel): the scope, the weakest world
/// with its reason, and the next two worlds as orbs – or the calm line.
class _CompactRadar extends StatelessWidget {
  const _CompactRadar({required this.snapshot, required this.radar, required this.onOpen});

  final SceneSnapshot? snapshot;
  final List<RadarEntry> radar;
  final OpenPlanet onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final scope = SizedBox.square(
      dimension: 16,
      child: CustomPaint(
        painter: RadarScopePainter(ring: t.brass, sweep: t.accent, blips: [for (final e in radar) e.palette.glow]),
      ),
    );
    final s = snapshot;
    final style = text.bodySmall!.copyWith(color: t.textSecondary, height: 1.3);
    Widget line(Widget child) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, 0),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            scope,
            const SizedBox(width: Space.s),
            Expanded(child: child),
          ],
        ),
      ),
    );
    if (s == null || radar.isEmpty) {
      final calm = s == null ? l.homeRadarTitle : (s.balanceDormant ? l.orbitUiRadarWaiting : l.orbitUiRadarClear);
      return Semantics(
        container: true,
        label: l.orbitUiListSeparator(l.homeRadarTitle, calm),
        excludeSemantics: true,
        child: line(Text(calm, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      );
    }
    final first = radar.first;
    return line(
      Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: l.orbitUiListSeparator(
                l.homeRadarTitle,
                l.orbitUiRadarEntrySemantics(fmt.isolate(first.planetName), first.text),
              ),
              hint: l.orbitUiRadarOpenHint,
              excludeSemantics: true,
              onTap: () {
                Fx.fire(Sfx.navigate);
                onOpen(first.planetKey, item: NeglectRadarStrip._itemOf(first));
              },
              child: MadarPressable(
                onTap: () => onOpen(first.planetKey, item: NeglectRadarStrip._itemOf(first)),
                sfx: Sfx.navigate,
                excludeChildSemantics: true,
                focusRadius: BorderRadius.circular(t.radiusS),
                child: Row(
                  children: [
                    _Orb(palette: first.palette, score: first.score),
                    const SizedBox(width: Space.xs + 2),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: fmt.isolate(first.planetName),
                              style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            TextSpan(text: l.orbitUiRadarLineJoin),
                            TextSpan(text: first.text),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final e in radar.skip(1)) ...[
            const SizedBox(width: Space.s),
            Semantics(
              button: true,
              label: l.orbitUiRadarEntrySemantics(fmt.isolate(e.planetName), e.text),
              hint: l.orbitUiRadarOpenHint,
              excludeSemantics: true,
              onTap: () {
                Fx.fire(Sfx.navigate);
                onOpen(e.planetKey, item: NeglectRadarStrip._itemOf(e));
              },
              child: MadarPressable(
                onTap: () => onOpen(e.planetKey, item: NeglectRadarStrip._itemOf(e)),
                sfx: Sfx.navigate,
                excludeChildSemantics: true,
                focusRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(2),
                  child: _Orb(palette: e.palette, score: e.score),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RadarEntryCard extends StatelessWidget {
  const _RadarEntryCard({required this.entry, required this.onTap});

  final RadarEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final palette = entry.palette;
    return Semantics(
      button: true,
      label: l.orbitUiRadarEntrySemantics(fmt.isolate(entry.planetName), entry.text),
      hint: l.orbitUiRadarOpenHint,
      excludeSemantics: true,
      onTap: () {
        Fx.fire(Sfx.navigate);
        onTap();
      },
      child: MadarPressable(
        onTap: onTap,
        sfx: Sfx.navigate,
        excludeChildSemantics: true,
        focusRadius: BorderRadius.circular(t.radiusM),
        child: GlassCard(
          glow: false,
          padding: const EdgeInsetsDirectional.fromSTEB(Space.s + 2, Space.s + 2, Space.s, Space.s + 2),
          borderColor: palette.glow.withValues(alpha: 0.28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _Orb(palette: palette, score: entry.score),
                  const SizedBox(width: Space.xs + 2),
                  Expanded(
                    child: Text(
                      entry.planetName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge!.copyWith(color: t.textPrimary, height: 1.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(
                entry.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.3, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small world orb with its balance as a thin arc around it.
class _Orb extends StatelessWidget {
  const _Orb({required this.palette, required this.score});

  final PlanetPalette palette;
  final double score;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 20,
      child: CustomPaint(
        painter: _OrbPainter(palette: palette, score: score, track: context.tokens.glassBorder),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.palette, required this.score, required this.track});

  final PlanetPalette palette;
  final double score;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r * 0.62,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [palette.glow, palette.surface, palette.deep],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.62)),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r - 1, ring..color = track);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - 1),
      -math.pi / 2,
      2 * math.pi * score.clamp(0.02, 1.0),
      false,
      ring..color = palette.glow,
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.palette != palette || old.score != score || old.track != track;
}

/// A still radar scope: three rings, cross-hairs, a fading sweep wedge and
/// optional blips.
class RadarScopePainter extends CustomPainter {
  const RadarScopePainter({required this.ring, required this.sweep, required this.blips});

  final Color ring;
  final Color sweep;
  final List<Color> blips;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 0.5;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = ring.withValues(alpha: 0.75);
    for (final f in const [1.0, 0.6]) {
      canvas.drawCircle(c, r * f, line);
    }
    const start = -math.pi / 2;
    const span = math.pi / 2.2;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      span,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + span,
          colors: [sweep.withValues(alpha: 0.0), sweep.withValues(alpha: 0.55)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawLine(
      c,
      c + Offset(math.cos(start + span), math.sin(start + span)) * r,
      Paint()
        ..strokeWidth = 1
        ..color = sweep,
    );
    for (var i = 0; i < blips.length; i++) {
      final a = i * 2 * math.pi / blips.length + 0.4;
      final d = r * (0.3 + 0.6 * ((i * 37) % 10) / 10);
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * d, 1.9, Paint()..color = blips[i]);
    }
  }

  @override
  bool shouldRepaint(RadarScopePainter old) =>
      old.ring != ring || old.sweep != sweep || old.blips.length != blips.length;
}
