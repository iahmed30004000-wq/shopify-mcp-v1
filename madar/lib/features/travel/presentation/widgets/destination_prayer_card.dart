import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../prayer/application/prayer_settings_controller.dart' show prayerSettingsControllerProvider;
import '../../../prayer/domain/prayer_day.dart';
import '../../../prayer/domain/time_zones.dart';
import '../../../prayer/presentation/prayer_labels.dart';
import '../../../qibla/presentation/qibla_labels.dart';
import '../../data/travel_providers.dart';
import '../../domain/destination_prayer.dart';
import '../../domain/travel_overview.dart';
import '../../domain/trip_timeline.dart';
import '../../travel_texts.dart';

/// The destination's prayer times for any day of the trip (in the
/// destination's own clock, with the user's calculation settings), its
/// local time and offset from the phone, the qibla from there, and "use as
/// my prayer location while travelling" when the app provides it.
class DestinationPrayerCard extends ConsumerStatefulWidget {
  const DestinationPrayerCard({super.key, required this.trip, this.onPickCity});

  final TripView trip;

  /// Shown for a destination typed freely (opens the trip editor).
  final VoidCallback? onPickCity;

  @override
  ConsumerState<DestinationPrayerCard> createState() => _DestinationPrayerCardState();
}

class _DestinationPrayerCardState extends ConsumerState<DestinationPrayerCard> {
  DateTime? _day;
  Timer? _tick;
  bool _using = false;
  final _selectedChip = GlobalKey();

  @override
  void initState() {
    super.initState();
    // The local time and the next-prayer countdown move with the minute.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    // Bring the selected day into view (a long trip's chips overflow).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _selectedChip.currentContext;
      if (mounted && c != null) Scrollable.ensureVisible(c, alignment: 0.5);
    });
  }

  /// "الخميس ٨" / "Thu 8": short enough for a row of chips.
  String _chipLabel(DateTime d, MadarFormatter fmt, String lang) {
    try {
      return fmt.localizeDigits(DateFormat('EEE d', lang).format(d));
    } catch (_) {
      return fmt.formatDate(d, style: MadarDateStyle.dayMonth);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Today there while the trip is under way (or undated / past), else the
  /// departure day.
  DateTime _defaultDay(DestinationPrayer p, DateTime now) {
    final today = p.todayThere(now);
    final start = widget.trip.row.startDate;
    if (widget.trip.phase == TripPhase.upcoming && start != null) return TravelDates.day(start);
    return today;
  }

  Future<void> _use(TravelUsePrayerLocation use, TripPlace place) async {
    if (_using) return;
    setState(() => _using = true);
    try {
      await use(context, place);
    } finally {
      if (mounted) setState(() => _using = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = TravelTexts.of(context);
    final fmt = tx.fmt;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final prayer = ref.watch(travelDestinationPrayerProvider(widget.trip.id));
    final place = widget.trip.place;
    final name = widget.trip.displayName(lang);

    if (prayer == null || place == null) {
      return GlassCard(
        glow: false,
        padding: const EdgeInsetsDirectional.all(Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Title(icon: Icons.mosque_rounded, title: l.travelPrayerTitle(tx.name(name))),
            const SizedBox(height: Space.s),
            Text(l.travelPrayerNoPlace, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
            if (widget.onPickCity != null) ...[
              const SizedBox(height: Space.m),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MadarButton(
                  label: l.travelPrayerPickCity,
                  icon: Icons.travel_explore_rounded,
                  variant: MadarButtonVariant.secondary,
                  size: MadarButtonSize.small,
                  sfx: Sfx.sheetOpen,
                  onPressed: widget.onPickCity,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final now = ref.watch(travelClockProvider)();
    final settings = ref.watch(prayerSettingsControllerProvider);
    final clock = prayerClockOf(context, settings);
    final todayThere = prayer.todayThere(now);
    final days = widget.trip.timeline.days(fallback: todayThere, max: 31);
    final day = _day ?? _defaultDay(prayer, now);
    final chips = <DateTime>[
      if (!days.any((d) => TravelDates.sameDay(d, todayThere))) todayThere,
      ...days,
    ];
    final pd = prayer.day(day);
    final isToday = TravelDates.sameDay(day, todayThere);
    final next = isToday ? prayer.nextPrayer(now) : null;
    final friday = day.weekday == DateTime.friday;
    final local = prayer.localTime(now);
    final zone = place.zone;
    final zoneName = zone == null ? l.ptTimeZoneDevice : BidiIsolate.ltr(zone.name.replaceAll('_', ' '));
    final zoneLine = [
      zoneName,
      l.zoneOffset(MadarTimeZones.offsetAt(now, zone), fmt),
      tx.offsetFromPhone(prayer.offsetFromDevice(now)),
    ].join(l.commonFactSeparator);
    final use = ref.watch(travelUsePrayerLocationProvider);
    final isLocation = place.isPrayerLocationOf(settings);
    const moments = [
      PrayerMoment.fajr,
      PrayerMoment.sunrise,
      PrayerMoment.dhuhr,
      PrayerMoment.asr,
      PrayerMoment.maghrib,
      PrayerMoment.isha,
    ];
    final nextMoment = next == null ? null : PrayerMoment.ofPrayer(next.prayer);
    final qibla = prayer.qibla;

    return GlassCard(
      glow: false,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Title(icon: Icons.mosque_rounded, title: l.travelPrayerTitle(tx.name(name)))),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    clock.format(local).joined,
                    style: text.titleLarge!.copyWith(color: t.gold, fontWeight: FontWeight.w700, height: 1.1),
                  ),
                  Text(l.travelLocalTime, style: text.labelSmall!.copyWith(color: t.textTertiary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(zoneLine, style: text.bodySmall!.copyWith(color: t.textSecondary)),
          const SizedBox(height: Space.m),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
              itemBuilder: (context, i) {
                final d = chips[i];
                final selected = TravelDates.sameDay(d, day);
                final label = TravelDates.sameDay(d, todayThere) ? l.travelPrayerToday : _chipLabel(d, fmt, lang);
                return MadarChip(
                  key: selected ? _selectedChip : null,
                  label: label,
                  selected: selected,
                  dense: true,
                  onSelected: (_) => setState(() => _day = d),
                );
              },
            ),
          ),
          const SizedBox(height: Space.m),
          for (final m in moments)
            _TimeRow(
              icon: momentIcon(m),
              label: l.momentName(m, friday: friday),
              time: clock.format(prayer.localTime(pd.timeOf(m))).joined,
              highlight: m == nextMoment,
              muted: m == PrayerMoment.sunrise,
              past: isToday && pd.timeOf(m).isBefore(now) && m != nextMoment,
            ),
          if (next != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              l.travelPrayerNext(l.prayerName(next.prayer, friday: friday), fmt.formatDurationWords(l, next.at.difference(now))),
              style: text.labelLarge!.copyWith(color: t.accent),
            ),
          ],
          const SizedBox(height: Space.m),
          const MadarDivider(height: 20),
          Row(
            children: [
              QiblaMiniDial(bearing: qibla.bearing, size: 64),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.travelQiblaTitle, style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      qibla.atKaaba ? l.travelQiblaAtKaaba : l.travelQiblaBearing(l.qiblaBearingText(qibla.bearing, fmt)),
                      style: text.bodyMedium!.copyWith(color: t.gold),
                    ),
                    Text(
                      l.travelQiblaDistance(l.qiblaDistanceText(qibla.distanceKm, fmt)),
                      style: text.bodySmall!.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          if (isLocation)
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: t.success, size: 18),
                const SizedBox(width: Space.s),
                Expanded(child: Text(l.travelPrayerIsLocation, style: text.bodyMedium!.copyWith(color: t.success))),
              ],
            )
          else if (use != null)
            MadarButton(
              label: l.travelPrayerUseHere,
              icon: Icons.near_me_rounded,
              variant: MadarButtonVariant.secondary,
              size: MadarButtonSize.small,
              expand: true,
              loading: _using,
              sfx: Sfx.toggleOn,
              onPressed: () => _use(use, place),
            ),
          const SizedBox(height: Space.xs),
          Text(l.travelPrayerMethodNote, style: text.labelSmall!.copyWith(color: t.textTertiary)),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Icon(icon, size: 20, color: t.gold),
        const SizedBox(width: Space.s),
        Flexible(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.label,
    required this.time,
    this.highlight = false,
    this.muted = false,
    this.past = false,
  });

  final IconData icon;
  final String label;
  final String time;
  final bool highlight;
  final bool muted;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final color = highlight ? t.accent : (muted || past ? t.textTertiary : t.textPrimary);
    return AnimatedContainer(
      duration: context.motion(MadarMotion.short),
      margin: const EdgeInsetsDirectional.only(bottom: 2),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusS),
        color: highlight ? t.accent.withValues(alpha: t.isDark ? 0.14 : 0.1) : Colors.transparent,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: highlight ? t.accent : t.textTertiary),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium!.copyWith(color: color, fontWeight: highlight ? FontWeight.w700 : null),
            ),
          ),
          Text(
            time,
            style: text.bodyMedium!.copyWith(
              color: color,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small, still compass rose with the qibla needle at [bearing] (degrees
/// clockwise from true north) – a picture of the direction from the
/// destination, not a live compass.
class QiblaMiniDial extends StatelessWidget {
  const QiblaMiniDial({super.key, required this.bearing, this.size = 64});

  final double bearing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    return Semantics(
      label: l.travelQiblaSemantics(l.qiblaBearingText(bearing, fmt)),
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: QiblaMiniDialPainter(
            bearing: bearing,
            ring: t.metalBrass,
            needle: t.metalGold,
            face: t.glassFill,
            tick: t.textTertiary,
            north: t.danger,
            northLabel: l.qiblaPointN,
            labelStyle: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.textSecondary, fontSize: 9),
          ),
        ),
      ),
    );
  }
}

class QiblaMiniDialPainter extends CustomPainter {
  QiblaMiniDialPainter({
    required this.bearing,
    required this.ring,
    required this.needle,
    required this.face,
    required this.tick,
    required this.north,
    required this.northLabel,
    required this.labelStyle,
  });

  final double bearing;
  final Color ring, needle, face, tick, north;
  final String northLabel;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1;
    canvas.drawCircle(c, r, Paint()..color = face);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = ring,
    );
    final tickPaint = Paint()
      ..strokeWidth = 1
      ..color = tick;
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      final major = i % 4 == 0;
      final inner = r - (major ? 6 : 3);
      canvas.drawLine(
        c + Offset(math.sin(a) * inner, -math.cos(a) * inner),
        c + Offset(math.sin(a) * (r - 1), -math.cos(a) * (r - 1)),
        tickPaint..color = i == 0 ? north : tick,
      );
    }
    // North letter just inside the top tick.
    final tp = TextPainter(
      text: TextSpan(text: northLabel, style: labelStyle.copyWith(color: north)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c + Offset(-tp.width / 2, -r + 7));
    tp.dispose();

    // The needle, from the centre toward the qibla.
    final a = bearing * math.pi / 180;
    final dir = Offset(math.sin(a), -math.cos(a));
    final perp = Offset(-dir.dy, dir.dx);
    final tip = c + dir * (r - 9);
    final tail = c - dir * (r * 0.3);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((c + perp * 3.2).dx, (c + perp * 3.2).dy)
      ..lineTo(tail.dx, tail.dy)
      ..lineTo((c - perp * 3.2).dx, (c - perp * 3.2).dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = needle.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(path, Paint()..color = needle);
    // The Kaaba: a small square at the tip.
    final kaaba = Rect.fromCenter(center: c + dir * (r - 9), width: 6, height: 6);
    canvas.save();
    canvas.translate(kaaba.center.dx, kaaba.center.dy);
    canvas.rotate(a);
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 6, height: 6), Paint()..color = const Color(0xFF1A1A1A));
    canvas.drawLine(const Offset(-3, -1), const Offset(3, -1), Paint()..color = needle..strokeWidth = 1);
    canvas.restore();
    canvas.drawCircle(c, 2.4, Paint()..color = ring);
  }

  @override
  bool shouldRepaint(QiblaMiniDialPainter old) =>
      old.bearing != bearing || old.ring != ring || old.needle != needle || old.face != face || old.north != north;
}
