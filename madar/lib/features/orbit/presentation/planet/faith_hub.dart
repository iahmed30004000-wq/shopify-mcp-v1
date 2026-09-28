import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/routing/route_pages.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../adhkar/adhkar.dart' show AdhkarTodayCard;
import '../../../home/home_providers.dart';
import '../../../prayer/prayer.dart';
import '../../../prayer_tracker/prayer_tracker.dart' show PrayerTodayCard;
import '../../data/orbit_providers.dart';

/// The Faith world's own page content – the hub of the day around the five
/// prayers:
///
/// * the next prayer with a live countdown, under today's Hijri and
///   Gregorian dates (opens prayer times);
/// * today's five prayers from the tracker ([PrayerTodayCard]: tap cycles,
///   long-press for every option; its header opens the tracker);
/// * today's adhkar ([AdhkarTodayCard]) – each set opens in the reader;
/// * quick links: prayer times, the tracker's history, adhkar, the tasbeeh
///   and the adhan settings.
///
/// Every part is a [StaggerItem] of the planet page's entrance, so the hub
/// rises in step with the rest of the sheet.
class FaithHub extends StatelessWidget {
  const FaithHub({super.key, this.firstIndex = 1});

  /// Stagger index of the first card.
  final int firstIndex;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    Widget pad(Widget child) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
      child: child,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StaggerItem(index: firstIndex, child: pad(const NextPrayerCard())),
        const SizedBox(height: Space.m),
        StaggerItem(
          index: firstIndex + 1,
          child: pad(PrayerTodayCard(onOpen: () => FaithNav.tracker(context))),
        ),
        const SizedBox(height: Space.m),
        StaggerItem(
          index: firstIndex + 2,
          child: pad(
            AdhkarTodayCard(
              onOpenSet: FaithNav.adhkarSet,
              onOpenHome: FaithNav.adhkar,
              onOpenTasbeeh: FaithNav.tasbeeh,
            ),
          ),
        ),
        StaggerItem(
          index: firstIndex + 3,
          child: SectionHeader(
            title: l.faithHubLinksTitle,
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, Space.s),
          ),
        ),
        StaggerItem(index: firstIndex + 3, child: pad(const _HubLinks())),
      ],
    );
  }
}

/// Today's Hijri date over the Gregorian one, then the next obligatory
/// prayer, its time on the location's clock and a countdown that ticks every
/// second (only while the page is showing). Tap: prayer times.
class NextPrayerCard extends ConsumerWidget {
  const NextPrayerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    // Minute ticks (and every window start) – the countdown below ticks on
    // its own.
    final now = ref.watch(homeNowProvider);
    final schedule = ref.watch(prayerScheduleProvider);
    final next = nextObligatoryPrayer(schedule, now);
    final friday = schedule.dateOf(next.at).weekday == DateTime.friday;
    final name = l.prayerName(next.prayer, friday: friday);
    final clock = prayerClockOf(context, schedule.settings);
    final at = clock.format(schedule.wallClock(next.at)).joined;
    final hijri = l.hijriDate(ref.watch(hijriDateProvider(now)), fmt);
    final gregorian = fmt.formatDate(schedule.wallClock(now), style: MadarDateStyle.weekdayDayMonth);

    return MadarPressable(
      onTap: () => FaithNav.prayerTimes(context),
      sfx: Sfx.navigate,
      semanticLabel: [
        hijri,
        gregorian,
        l.ptCountdownSemantics(name, fmt.formatDurationWords(l, next.at.difference(now))),
        l.faithHubAt(at),
      ].join('. '),
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusL),
      child: GlassCard(
        borderRadius: BorderRadius.circular(t.radiusL),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.l),
        glowColor: t.accentGlow.withValues(alpha: t.accentGlow.a * 0.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hijri,
                        style: text.titleLarge!.copyWith(
                          fontFamily: MadarTypography.naskhFamily,
                          fontSize: 21,
                          height: 1.35,
                          color: t.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(gregorian, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: Space.s),
                const IslamicStar(size: 22, glow: true),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: Space.m),
              child: Divider(height: 1, thickness: 0.6, color: t.glassBorder.withValues(alpha: 0.4)),
            ),
            Text(l.ptNextPrayer, style: text.labelMedium!.copyWith(color: t.textTertiary)),
            const SizedBox(height: Space.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.headlineMedium),
                      Text(l.faithHubAt(at), style: text.bodyMedium!.copyWith(color: t.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: Space.m),
                _Countdown(target: next.at, format: clock.countdown),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `h:mm:ss` to [target], ticking once a second while tickers are enabled on
/// this route (a covered or hidden page stops ticking).
class _Countdown extends ConsumerStatefulWidget {
  const _Countdown({required this.target, required this.format});

  final DateTime target;
  final String Function(Duration) format;

  @override
  ConsumerState<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends ConsumerState<_Countdown> {
  Timer? _tick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final live = TickerMode.valuesOf(context).enabled;
    if (live && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!live) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final now = ref.read(orbitClockProvider)();
    return Text(
      widget.format(widget.target.difference(now)),
      style: Theme.of(context).textTheme.headlineSmall!
          .copyWith(color: t.accent, fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

/// Two columns of glass links into the faith pages (an odd last one spans
/// the row).
class _HubLinks extends StatelessWidget {
  const _HubLinks();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final links = [
      (Icons.schedule_rounded, l.ptTitle, l.faithHubTimesHint, () => FaithNav.prayerTimes(context)),
      (
        Icons.insights_rounded,
        l.faithHubHistory,
        l.faithHubHistoryHint,
        () => FaithNav.tracker(context, history: true),
      ),
      (Icons.menu_book_rounded, l.adhkarTitle, l.faithHubAdhkarHint, () => FaithNav.adhkar(context)),
      (Icons.blur_circular_rounded, l.adhkarTasbeehTitle, l.faithHubTasbeehHint, () => FaithNav.tasbeeh(context)),
      (
        Icons.notifications_active_rounded,
        l.adhanSettingsTitle,
        l.faithHubAdhanHint,
        () => FaithNav.adhanSettings(context),
      ),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < links.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: Space.s));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = i; j < i + 2; j++) ...[
                if (j > i) const SizedBox(width: Space.s),
                if (j < links.length)
                  Expanded(
                    child: _HubLink(icon: links[j].$1, title: links[j].$2, hint: links[j].$3, onTap: links[j].$4),
                  ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

class _HubLink extends StatelessWidget {
  const _HubLink({required this.icon, required this.title, required this.hint, required this.onTap});

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: onTap,
      sfx: Sfx.navigate,
      semanticLabel: '$title. $hint',
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: GlassCard(
        glow: false,
        padding: const EdgeInsetsDirectional.all(Space.m),
        child: Row(
          children: [
            Icon(icon, size: 22, color: t.accent),
            const SizedBox(width: Space.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                  Text(
                    hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(color: t.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
