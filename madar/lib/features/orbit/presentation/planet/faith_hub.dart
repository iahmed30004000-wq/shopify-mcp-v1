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
import '../../../hifz/hifz.dart' show HifzTodayCard, hifzStatsProvider;
import '../../../home/home_providers.dart';
import '../../../prayer/prayer.dart';
import '../../../prayer_tracker/prayer_tracker.dart' show PrayerTodayCard;
import '../../../qibla/qibla.dart' show QiblaCard;
import '../../../quran/quran.dart' show QuranContinueCard;
import '../../../wird/wird.dart' show WirdTodayCard;
import '../../data/orbit_providers.dart';

/// The Faith world's own page content – the hub of the day around the five
/// prayers, in three movements under one hero:
///
/// * the hero: today's Hijri and Gregorian dates, the next prayer and a live
///   countdown ([NextPrayerCard] – opens prayer times);
/// * **your day** – today's five prayers ([PrayerTodayCard]: tap cycles,
///   long-press for every option; its header opens the tracker) and today's
///   adhkar ([AdhkarTodayCard] – each set opens in the reader);
/// * **with the Quran** – continue reading where the reader stopped
///   ([QuranContinueCard]), today's wird portion ([WirdTodayCard]: read now,
///   mark done) and the Hifz reviews due ([HifzTodayCard], once there is
///   something to memorise); the header's "Index" opens the Quran's front
///   page;
/// * **tools** – the qibla ([QiblaCard], a still mini astrolabe: no sensor
///   runs on this page) over a grid of six: the mushaf, Hifz, recitation,
///   the tasbeeh, the prayer history and the adhan.
///
/// Every part is a [StaggerItem] of the planet page's entrance (each
/// movement's header rises with its first card), so the hub unfolds in step
/// with the rest of the sheet. Every page opens as a route ([FaithNav]).
class FaithHub extends ConsumerWidget {
  const FaithHub({super.key, this.firstIndex = 1});

  /// Stagger index of the first card.
  final int firstIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    // Hifz joins the Quran once it holds something (the tools grid invites
    // before that) – no loader, no empty card on a fresh install.
    final hifz = (ref.watch(hifzStatsProvider).value?.total ?? 0) > 0;
    var index = firstIndex;
    final children = <Widget>[];
    void card(Widget child, {bool gap = true}) {
      if (gap && children.isNotEmpty && children.last is! _Header) {
        children.add(const SizedBox(height: Space.m));
      }
      children.add(
        StaggerItem(
          index: index++,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
            child: child,
          ),
        ),
      );
    }

    void header(String title, {String? action, VoidCallback? onAction}) =>
        children.add(_Header(index: index, title: title, action: action, onAction: onAction));

    card(const NextPrayerCard());

    header(l.faithHubTodayTitle);
    card(PrayerTodayCard(onOpen: () => FaithNav.tracker(context)));
    card(AdhkarTodayCard(onOpenSet: FaithNav.adhkarSet, onOpenHome: FaithNav.adhkar, onOpenTasbeeh: FaithNav.tasbeeh));

    header(
      l.faithHubQuranTitle,
      action: l.faithHubQuranIndex,
      onAction: () => FaithNav.quran(context),
    );
    card(QuranContinueCard(onOpen: (context, {ayah, page}) => FaithNav.quranReader(context, ayah: ayah, page: page)));
    card(WirdTodayCard(onOpen: (context) => FaithNav.wird(context)));
    if (hifz) {
      card(
        HifzTodayCard(
          onOpen: FaithNav.hifz,
          onStartReview: (context, {only}) => FaithNav.hifzReview(context, only: only),
        ),
      );
    }

    header(l.faithHubToolsTitle);
    card(QiblaCard(onOpen: () => FaithNav.qibla(context)));
    card(const FaithTools());

    // The planet sheet has no Material above it: the cards the features
    // bring (their bare numeral styles) would otherwise inherit the debug
    // fallback text style (a yellow double underline).
    return Material(
      type: MaterialType.transparency,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// A movement's title, rising with its first card.
class _Header extends StatelessWidget {
  const _Header({required this.index, required this.title, this.action, this.onAction});

  final int index;
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => StaggerItem(
    index: index,
    child: SectionHeader(
      title: title,
      actionLabel: action,
      onAction: onAction,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, Space.s),
    ),
  );
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
    // The same tabular Plex numerals as the prayer-times hero (Reem Kufi's
    // geometric ٢ reads as an "r" in a ticking clock).
    // Built on a theme style: the planet sheet has no Material above it, so
    // a bare TextStyle would inherit the debug fallback (yellow underline).
    return Text(
      widget.format(widget.target.difference(now)),
      style: Theme.of(context).textTheme.titleLarge!.merge(
        MadarTypography.numerals(t, size: 22, color: t.accent).copyWith(fontWeight: FontWeight.w600, height: 1.2),
      ),
    );
  }
}

/// The faith tools: a grid of three by two glass tiles, each a brass seal
/// around its icon over its name – the mushaf, Hifz and recitation, then
/// the tasbeeh, the prayer history and the adhan. Every tile opens its page
/// with a navigation sound.
class FaithTools extends StatelessWidget {
  const FaithTools({super.key});

  static const int columns = 3;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final tools = <_Tool>[
      (Icons.menu_book_rounded, l.quranModeMushaf, l.faithHubMushafHint, () => FaithNav.quran(context)),
      (Icons.psychology_rounded, l.hifzTitle, l.faithHubHifzHint, () => FaithNav.hifz(context)),
      (Icons.graphic_eq_rounded, l.recitationTitle, l.faithHubRecitationHint, () => FaithNav.recitation(context)),
      (Icons.blur_circular_rounded, l.adhkarTasbeehTitle, l.faithHubTasbeehHint, () => FaithNav.tasbeeh(context)),
      (Icons.insights_rounded, l.faithHubHistory, l.faithHubHistoryHint, () => FaithNav.tracker(context, history: true)),
      (Icons.notifications_active_rounded, l.faithHubAdhanTool, l.faithHubAdhanHint, () => FaithNav.adhanSettings(context)),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < tools.length; i += columns) {
      if (i > 0) rows.add(const SizedBox(height: Space.s));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = i; j < i + columns; j++) ...[
                if (j > i) const SizedBox(width: Space.s),
                Expanded(child: j < tools.length ? _ToolTile(tool: tools[j]) : const SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// Icon, name, hint (for screen readers) and where it leads.
typedef _Tool = (IconData, String, String, VoidCallback);

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});

  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (icon, title, hint, onTap) = tool;
    return MadarPressable(
      onTap: onTap,
      sfx: Sfx.navigate,
      semanticLabel: '$title. $hint',
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: GlassCard(
        glow: false,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.m, Space.xs, Space.m),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Seal(icon: icon),
            const SizedBox(height: Space.s),
            Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall!.copyWith(color: t.textPrimary, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

/// A brass eight-point seal holding a tool's icon (the Quran card's page
/// seal, in small).
class _Seal extends StatelessWidget {
  const _Seal({required this.icon});

  final IconData icon;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IslamicStar(size: size, color: t.accentSoft),
          IslamicStar(size: size, filled: false, color: t.brass.withValues(alpha: 0.8), strokeWidth: 1.2),
          Icon(icon, size: 20, color: t.accent),
        ],
      ),
    );
  }
}
