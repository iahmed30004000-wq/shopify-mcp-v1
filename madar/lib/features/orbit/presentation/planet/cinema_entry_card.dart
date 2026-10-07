import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../cinema/games/catalog.dart';

/// Madar Cinema's door on the Growth world's page: a small marquee – a sign
/// ringed with bulbs that chase once when the card appears and then stay
/// lit (lit at once under reduced motion) – with the cinema's name and
/// line, how many shows can be played now, and a ticket into the hall.
///
/// The whole card is one button ([onOpen]); it reads as "Madar Cinema, its
/// line, the shows ready". Theme tokens only: on Pearl the bulbs and ink
/// are the theme's deep gold.
class CinemaEntryCard extends StatefulWidget {
  const CinemaEntryCard({super.key, required this.onOpen, this.readyShows});

  /// Opens the hall.
  final void Function(BuildContext context) onOpen;

  /// Shows that can be played now (default: the programme's playable
  /// entries).
  final int? readyShows;

  /// The programme's entries that can be played now.
  static int get playableShows => CinemaCatalog.all.where((e) => e.isPlayable).length;

  @override
  State<CinemaEntryCard> createState() => _CinemaEntryCardState();
}

class _CinemaEntryCardState extends State<CinemaEntryCard> with SingleTickerProviderStateMixin {
  /// The bulbs' one chase (two laps), then they rest lit.
  late final AnimationController _chase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MotionScope.reducedOf(context)) {
      _chase.value = 1;
    } else {
      _chase.forward();
    }
  }

  @override
  void dispose() {
    _chase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final shows = MadarFormatter.of(context)
        .localizeDigits(l.cinemaWiringShowsReady(widget.readyShows ?? CinemaEntryCard.playableShows));
    final radius = BorderRadius.circular(t.radiusL);
    return MadarPressable(
      onTap: () => widget.onOpen(context),
      sfx: Sfx.navigate,
      semanticLabel: '${l.cinemaTitle}. ${l.cinemaHallSubtitle}. $shows',
      excludeChildSemantics: true,
      focusRadius: radius,
      child: GlassCard(
        glow: false,
        borderRadius: radius,
        padding: EdgeInsets.zero,
        child: CustomPaint(
          foregroundPainter: _MarqueeFramePainter(
            chase: _chase,
            bulb: t.metalGold,
            dim: t.brass.withValues(alpha: 0.32),
            rule: t.brass.withValues(alpha: 0.7),
            radius: t.radiusL,
            glow: t.isDark,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.xl, Space.xl - 2, Space.xl, Space.xl - 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.cinemaTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.headlineSmall!.copyWith(color: t.gold, height: 1.3),
                          ),
                          const SizedBox(height: Space.xxs),
                          Text(
                            l.cinemaHallSubtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    const _ReelSeal(),
                  ],
                ),
                const SizedBox(height: Space.m),
                Wrap(
                  spacing: Space.m,
                  runSpacing: Space.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Ticket(label: l.cinemaWiringEnterHall),
                    Text(shows, style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.3)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A brass eight-point seal holding a film-reel icon (the hub tools' seal,
/// a size up).
class _ReelSeal extends StatelessWidget {
  const _ReelSeal();

  static const double size = 52;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IslamicStar(size: size, color: t.accentSoft),
          IslamicStar(size: size, filled: false, color: t.brass.withValues(alpha: 0.85), strokeWidth: 1.3),
          Icon(Icons.theaters_rounded, size: 24, color: t.accent),
        ],
      ),
    );
  }
}

/// The ticket into the hall: an accent stub with notched ends.
class _Ticket extends StatelessWidget {
  const _Ticket({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: ShapeDecoration(color: t.accent, shape: const _TicketBorder()),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m + 2, Space.xs + 2, Space.m + 4, Space.xs + 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_activity_rounded, size: 18, color: t.textOnAccent),
            const SizedBox(width: Space.xs + 2),
            Text(
              label,
              style: text.labelLarge!.copyWith(color: t.textOnAccent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// A rounded stub with a half-round notch in the middle of each end.
class _TicketBorder extends ShapeBorder {
  const _TicketBorder();

  static const double _corner = 6;
  static const double _notch = 4.5;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final body = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(_corner)));
    final notches = Path()
      ..addOval(Rect.fromCircle(center: rect.centerLeft, radius: _notch))
      ..addOval(Rect.fromCircle(center: rect.centerRight, radius: _notch));
    return Path.combine(PathOperation.difference, body, notches);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

/// The marquee: a fine brass rule inside the card's edge and a ring of
/// bulbs between it and the edge. While [chase] runs, every third bulb is
/// lit and the pattern steps round (two laps); then all rest lit.
class _MarqueeFramePainter extends CustomPainter {
  _MarqueeFramePainter({
    required this.chase,
    required this.bulb,
    required this.dim,
    required this.rule,
    required this.radius,
    required this.glow,
  }) : super(repaint: chase);

  final Animation<double> chase;
  final Color bulb, dim, rule;
  final double radius;

  /// Halos round the lit bulbs (night themes; on Pearl a halo only muddies).
  final bool glow;

  static const double _ringInset = 8;
  static const double _ruleInset = 14;
  static const double _spacing = 15;
  static const double _bulbRadius = 2.3;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rulePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = rule;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(_ruleInset),
        Radius.circular(math.max(0, radius - _ruleInset)),
      ),
      rulePaint,
    );

    final ring = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(_ringInset),
          Radius.circular(math.max(0, radius - _ringInset)),
        ),
      );
    final metric = ring.computeMetrics().first;
    final count = math.max(4, (metric.length / _spacing).round());
    final step = metric.length / count;
    final p = chase.value;
    final resting = p >= 1;
    // 2 laps of a 3-bulb pattern: 2 × count / 3 steps would crawl on a long
    // card; the pattern steps 36 times over the run instead.
    final shift = (p * 36).floor();
    final on = Paint()..color = bulb;
    final off = Paint()..color = dim;
    final halo = Paint()
      ..color = bulb.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var i = 0; i < count; i++) {
      final tangent = metric.getTangentForOffset(i * step);
      if (tangent == null) continue;
      final c = tangent.position;
      final lit = resting || (i + shift) % 3 == 0;
      if (lit && glow) canvas.drawCircle(c, _bulbRadius * 2, halo);
      canvas.drawCircle(c, _bulbRadius, lit ? on : off);
    }
  }

  @override
  bool shouldRepaint(_MarqueeFramePainter old) =>
      old.chase != chase ||
      old.bulb != bulb ||
      old.dim != dim ||
      old.rule != rule ||
      old.radius != radius ||
      old.glow != glow;
}
