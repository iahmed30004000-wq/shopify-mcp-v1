import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../../orbit/domain/prayer_schedule.dart';
import '../../orbit/presentation/prayer/prayer_sheet.dart' show showPrayerSheet;
import '../application/prayer_providers.dart';
import '../application/prayer_settings_controller.dart';
import '../domain/prayer_clock.dart';
import '../domain/prayer_day.dart';
import 'adjustment_sheet.dart';
import 'location_sheet.dart';
import 'prayer_labels.dart';
import 'prayer_settings_screen.dart';
import 'widgets/prayer_widgets.dart';

/// Which view the prayer-times screen shows.
enum PrayerTimesView { day, month }

/// Handles a tap on one of today's obligatory prayers (e.g. to log it).
typedef PrayerTapHandler = void Function(BuildContext context, WidgetRef ref, Prayer prayer);

/// Today's prayer times: the Hijri and Gregorian dates, the location chip
/// (opens the location sheet), the next prayer with a live countdown and
/// the current window's progress, then every moment of the day – Fajr,
/// sunrise, Duha, Dhuhr (Jumuʿah on Fridays), Asr, Maghrib, Isha, midnight
/// and the last third of the night – with the current one highlighted.
/// Swipe (or use the arrows) for other days; switch to the month table.
class PrayerTimesScreen extends ConsumerStatefulWidget {
  const PrayerTimesScreen({
    super.key,
    this.onOpenSettings,
    this.onPrayerTap = defaultPrayerTap,
    this.initialView = PrayerTimesView.day,
  });

  /// Opens the settings; pushes [PrayerSettingsScreen] when null.
  final VoidCallback? onOpenSettings;

  /// Tap on one of today's obligatory prayers (default: the orbit's log
  /// sheet – prayed / late / missed with undo). Null disables the taps.
  final PrayerTapHandler? onPrayerTap;
  final PrayerTimesView initialView;

  static void defaultPrayerTap(BuildContext context, WidgetRef ref, Prayer prayer) =>
      unawaited(showPrayerSheet(context, ref, prayer));

  @override
  ConsumerState<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends ConsumerState<PrayerTimesScreen> {
  static const _center = 10000;

  late final PageController _pages = PageController(initialPage: _center);
  late PrayerTimesView _view = widget.initialView;
  int _page = _center;

  /// Set while the arrows / "today" move the pages: their buttons already
  /// sounded, so the page change stays silent.
  bool _programmaticPage = false;
  DateTime? _month;
  Timer? _minute;

  /// Today's row of the month table: opening the month (or returning to
  /// this month) glides it into view instead of leaving it below the fold.
  final GlobalKey _todayRow = GlobalKey(debugLabel: 'prayer-month-today');

  /// The month table's column heads; once they scroll under the app bar a
  /// copy stays pinned there, so the times never lose their names.
  final GlobalKey _monthHead = GlobalKey(debugLabel: 'prayer-month-head');
  final ValueNotifier<bool> _pinHead = ValueNotifier(false);

  bool _pinCheckScheduled = false;

  /// Scroll notifications arrive before the frame lays the list out at its
  /// new offset: measure after it.
  void _schedulePinCheck(double top) {
    if (_pinCheckScheduled) return;
    _pinCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinCheckScheduled = false;
      if (mounted) _updatePinnedHead(top);
    });
  }

  void _updatePinnedHead(double top) {
    final head = _monthHead.currentContext?.findRenderObject();
    final pinned =
        _view == PrayerTimesView.month &&
        head is RenderBox &&
        head.attached &&
        head.localToGlobal(Offset.zero).dy < top;
    if (_pinHead.value != pinned) _pinHead.value = pinned;
  }

  late DateTime _now = ref.read(prayerClockProvider)();

  @override
  void initState() {
    super.initState();
    _armMinute();
    if (_view == PrayerTimesView.month) _revealTodayRow();
  }

  @override
  void dispose() {
    _minute?.cancel();
    _pages.dispose();
    _pinHead.dispose();
    super.dispose();
  }

  /// Rows and highlights change at whole minutes (prayer times are whole
  /// minutes); the hero ticks every second on its own.
  void _armMinute() {
    _minute?.cancel();
    final now = ref.read(prayerClockProvider)();
    final wait = Duration(seconds: 60 - now.second, milliseconds: -now.millisecond);
    _minute = Timer(wait <= Duration.zero ? const Duration(seconds: 1) : wait, () {
      if (!mounted) return;
      setState(() => _now = ref.read(prayerClockProvider)());
      _armMinute();
    });
  }

  void _openSettings() {
    final open = widget.onOpenSettings;
    if (open != null) {
      open();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrayerSettingsScreen()));
  }

  void _revealTodayRow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _todayRow.currentContext;
      if (!mounted || row == null) return;
      unawaited(
        Scrollable.ensureVisible(
          row,
          alignment: 0.6,
          duration: context.reducedMotion ? Duration.zero : MadarMotion.medium,
          curve: MadarMotion.standard,
        ),
      );
    });
  }

  Future<void> _goToPage(int page) async {
    if (page == _page) return;
    _programmaticPage = true;
    try {
      if (context.reducedMotion) {
        _pages.jumpToPage(page);
      } else {
        await _pages.animateToPage(page, duration: MadarMotion.medium, curve: MadarMotion.standard);
      }
    } finally {
      _programmaticPage = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final power = ref.watch(appSettingsProvider.select((a) => a.powerMode));
    final settings = ref.watch(prayerSettingsControllerProvider);
    final schedule = ref.watch(prayerLiveScheduleProvider);
    final cities = ref.watch(cityDatabaseProvider).value;
    final now = _now;
    // The prayer day runs Fajr → next Fajr: after midnight and before Fajr
    // the centre card is still the previous date's ("tonight"), while labels
    // and the month table follow the location's calendar date.
    final today = schedule.prayerDayOf(now);
    final calendarToday = schedule.dateOf(now);
    final wallNow = schedule.wallClock(now);
    final clock = prayerClockOf(context, settings);

    final header = Column(
      children: [
        HijriDateText(
          at: now,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: MadarTypography.naskhFamily,
            fontSize: 27,
            fontWeight: FontWeight.w700,
            height: 1.35,
            color: t.gold,
            shadows: [Shadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 16)],
          ),
        ),
        Text(
          fmt.formatDate(wallNow, style: MadarDateStyle.full),
          textAlign: TextAlign.center,
          style: text.bodyMedium!.copyWith(color: t.textSecondary),
        ),
        const SizedBox(height: Space.m),
        PrayerLocationChip(onTap: () => showPrayerLocationSheet(context)),
        if (schedule.differsFromDevice(now))
          Padding(
            padding: const EdgeInsetsDirectional.only(top: Space.xs),
            child: Text(
              l.ptZoneDiffers(l.placeLabel(settings, lang, cities: cities, withCountry: false)),
              style: text.bodySmall!.copyWith(color: t.warning),
            ),
          ),
      ],
    );

    final segments = Center(
      child: ChoicePills<PrayerTimesView>.single(
        options: [
          ChoiceOption(value: PrayerTimesView.day, label: l.ptViewDay, icon: Icons.view_day_rounded),
          ChoiceOption(value: PrayerTimesView.month, label: l.ptViewMonth, icon: Icons.calendar_month_rounded),
        ],
        selected: _view,
        onChanged: (v) {
          if (v == null) return;
          setState(() => _view = v);
          if (v == PrayerTimesView.month) {
            _revealTodayRow();
          } else {
            _pinHead.value = false;
          }
        },
      ),
    );

    final List<Widget> content;
    if (_view == PrayerTimesView.day) {
      final date = DateTime(today.year, today.month, today.day + (_page - _center));
      content = [
        _DayHeader(
          date: date,
          prayerDay: today,
          calendarToday: calendarToday,
          settings: settings,
          onPrevious: () => unawaited(_goToPage(_page - 1)),
          onNext: () => unawaited(_goToPage(_page + 1)),
          onToday: _page == _center ? null : () => unawaited(_goToPage(_center)),
        ),
        const SizedBox(height: Space.s),
        SizedBox(
          height: _DayCard.heightFor(MediaQuery.textScalerOf(context)),
          child: PageView.builder(
            controller: _pages,
            // The card's glow must not be cut at the pager's edges; while
            // swiping, the cards slide across the full screen width.
            clipBehavior: Clip.none,
            onPageChanged: (p) {
              if (!_programmaticPage) Fx.fire(Sfx.swipe);
              setState(() => _page = p);
            },
            itemBuilder: (context, i) {
              final d = DateTime(today.year, today.month, today.day + (i - _center));
              return Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.xxs),
                child: _DayCard(
                  day: PrayerTimesDay.of(schedule, d),
                  schedule: schedule,
                  clock: clock,
                  now: now,
                  isToday: i == _center,
                  onPrayerTap: widget.onPrayerTap == null || i != _center
                      ? null
                      : (p) => widget.onPrayerTap!(context, ref, p),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Space.m),
        _AdjustHint(text: l.ptAdjustHint),
      ];
    } else {
      final month = _month ?? DateTime(calendarToday.year, calendarToday.month);
      content = [
        _MonthHeader(
          month: month,
          settings: settings,
          onPrevious: () => setState(() => _month = DateTime(month.year, month.month - 1)),
          onNext: () => setState(() => _month = DateTime(month.year, month.month + 1)),
          onToday: month.year == calendarToday.year && month.month == calendarToday.month
              ? null
              : () {
                  setState(() => _month = DateTime(calendarToday.year, calendarToday.month));
                  _revealTodayRow();
                },
        ),
        const SizedBox(height: Space.s),
        _MonthTable(
          month: month,
          schedule: schedule,
          clock: clock,
          today: calendarToday,
          todayKey: _todayRow,
          headKey: _monthHead,
        ),
      ];
    }

    return MadarScaffold(
      title: l.ptTitle,
      extendBodyBehindAppBar: true,
      animateBackdrop: power != PowerMode.batterySaver,
      backdropSeed: 0.23,
      actions: [
        MadarButton.icon(
          icon: Icons.tune_rounded,
          semanticLabel: l.ptOpenSettings,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.navigate,
          onPressed: _openSettings,
        ),
        const SizedBox(width: Space.s),
      ],
      // The insets (app bar included) are only known inside the scaffold.
      body: Builder(
        builder: (context) {
          final top = MediaQuery.paddingOf(context).top;
          final list = ListView(
            padding: EdgeInsetsDirectional.fromSTEB(
              Space.gutter,
              MediaQuery.paddingOf(context).top + Space.s,
              Space.gutter,
              MediaQuery.paddingOf(context).bottom + Space.xxxl,
            ),
            children: [
              StaggerIn(
                id: 'prayer-times',
                fade: false,
                spacing: Space.l,
                children: [
                  header,
                  _NextPrayerHero(schedule: schedule, clock: clock),
                  segments,
                  AnimatedSwitcher(
                    duration: context.motion(MadarMotion.medium),
                    switchInCurve: MadarMotion.decelerate,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey(_view),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: content,
                    ),
                  ),
                ],
              ),
            ],
          );
          return Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (_) {
                  _schedulePinCheck(top);
                  return false;
                },
                child: list,
              ),
              PositionedDirectional(
                top: top,
                start: Space.gutter,
                end: Space.gutter,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _pinHead,
                  builder: (context, pinned, _) => IgnorePointer(
                    child: AnimatedSwitcher(
                      duration: context.motion(MadarMotion.short),
                      child: pinned
                          ? const _MonthColumnsBar(key: ValueKey('prayer-month-pinned-head'))
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The month table's column heads, pinned under the app bar while the
/// table scrolls beneath it (same columns and insets as [_MonthTable]).
class _MonthColumnsBar extends StatelessWidget {
  const _MonthColumnsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(t.glassFill, t.space1).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(t.radiusS),
          border: Border.all(color: t.glassBorder.withValues(alpha: 0.6), width: 0.8),
          boxShadow: [BoxShadow(color: t.glassShadow, blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.xs),
          child: _MonthTable.headRow(context),
        ),
      ),
    );
  }
}

/// The next prayer, a live countdown (every second) and the current
/// window's progress ring.
class _NextPrayerHero extends ConsumerStatefulWidget {
  const _NextPrayerHero({required this.schedule, required this.clock});

  final PrayerSchedule schedule;
  final PrayerClockFormat clock;

  @override
  ConsumerState<_NextPrayerHero> createState() => _NextPrayerHeroState();
}

class _NextPrayerHeroState extends ConsumerState<_NextPrayerHero> {
  Timer? _tick;
  late DateTime _now = ref.read(prayerClockProvider)();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = ref.read(prayerClockProvider)());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static Prayer? _prayerOfWindow(PrayerWindow w) => switch (w) {
    PrayerWindow.fajr => Prayer.fajr,
    PrayerWindow.dhuhr => Prayer.dhuhr,
    PrayerWindow.asr => Prayer.asr,
    PrayerWindow.maghrib => Prayer.maghrib,
    PrayerWindow.isha => Prayer.isha,
    _ => null,
  };

  static PrayerMoment _momentOfWindow(PrayerWindow w) => switch (w) {
    PrayerWindow.fajr => PrayerMoment.fajr,
    PrayerWindow.duha => PrayerMoment.duha,
    PrayerWindow.dhuhr => PrayerMoment.dhuhr,
    PrayerWindow.asr => PrayerMoment.asr,
    PrayerWindow.maghrib => PrayerMoment.maghrib,
    _ => PrayerMoment.isha,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final s = widget.schedule;
    final now = _now;
    final w = s.windowAt(now);
    final nextDate = s.dateOf(w.nextPrayerAt);
    final friday = nextDate.weekday == DateTime.friday;
    final nextName = l.prayerName(w.nextPrayer, friday: friday && w.nextPrayer == Prayer.dhuhr);
    final left = w.nextPrayerAt.difference(now);
    final countdown = widget.clock.countdown(left);
    final at = widget.clock.format(s.wallClock(w.nextPrayerAt));
    final justBegan = _prayerOfWindow(w.window);
    final sinceStart = now.difference(w.start);
    final itsTime = justBegan != null && !sinceStart.isNegative && sinceStart < const Duration(minutes: 1);
    final windowName = switch (w.window) {
      PrayerWindow.fajr => l.windowFajr,
      PrayerWindow.duha => l.windowDuha,
      PrayerWindow.dhuhr => l.windowDhuhr,
      PrayerWindow.asr => l.windowAsr,
      PrayerWindow.maghrib => l.windowMaghrib,
      PrayerWindow.isha => l.windowIsha,
      PrayerWindow.anytime => l.windowAnytime,
    };

    return Semantics(
      container: true,
      label: l.ptCountdownSemantics(nextName, fmt.formatDurationWords(l, left)),
      child: ExcludeSemantics(
        child: GlassPanel(
          seed: 0.31,
          glowColor: t.accentGlow.withValues(alpha: 0.35),
          padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.l),
          child: Row(
            children: [
              ProgressRing(
                value: w.progressAt(now),
                size: 96,
                strokeWidth: 7,
                color: t.accent,
                gradientEnd: t.gold,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(momentIcon(_momentOfWindow(w.window)), color: t.gold, size: 26),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s),
                      // "Dhuhr → Asr" shrinks to fit the ring instead of
                      // losing its second name under large text.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(windowName, maxLines: 1, style: text.labelSmall!.copyWith(color: t.textSecondary)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: context.motion(MadarMotion.medium),
                      child: Text(
                        itsTime ? l.ptItsTime(l.prayerName(justBegan)) : l.ptNextIn(nextName),
                        key: ValueKey(itsTime),
                        style: (itsTime ? text.titleMedium : text.titleSmall)!.copyWith(
                          color: itsTime ? t.gold : t.textSecondary,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        countdown,
                        style: MadarTypography.numerals(t, size: 40, color: t.textPrimary).copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          shadows: [Shadow(color: t.accentGlow.withValues(alpha: 0.4), blurRadius: 18)],
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(l.ptAtTime(at.joined), style: text.bodySmall!.copyWith(color: t.accent)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.date,
    required this.prayerDay,
    required this.calendarToday,
    required this.settings,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime date;

  /// The prayer day now running (the previous date between midnight and
  /// Fajr).
  final DateTime prayerDay;

  /// The location's calendar date now.
  final DateTime calendarToday;
  final PrayerSettings settings;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final title = prayerDayTitle(l, Localizations.localeOf(context).languageCode, date, prayerDay, calendarToday);
    final hijri = hijriOfDate(settings, date);
    final sub =
        '${fmt.formatDate(date, style: MadarDateStyle.dayMonth)}${l.commonFactSeparator}${l.hijriDayMonth(hijri, fmt)}';
    return Row(
      children: [
        MadarButton.icon(
          icon: Icons.chevron_left_rounded,
          semanticLabel: l.ptPrevDay,
          variant: MadarButtonVariant.ghost,
          size: MadarButtonSize.small,
          sfx: Sfx.swipe,
          onPressed: onPrevious,
        ),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: text.titleMedium),
                  if (onToday != null) ...[
                    const SizedBox(width: Space.s),
                    MadarPressable(
                      onTap: onToday,
                      sfx: Sfx.navigate,
                      semanticLabel: l.ptBackToToday,
                      excludeChildSemantics: true,
                      child: Container(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(t.radiusS),
                          color: t.accentSoft,
                          border: Border.all(color: t.accent.withValues(alpha: 0.5), width: 0.7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.today_rounded, size: 13, color: t.accent),
                            const SizedBox(width: 3),
                            Text(l.ptToday, style: text.labelSmall!.copyWith(color: t.accent)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                sub,
                style: text.bodySmall!.copyWith(color: t.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        MadarButton.icon(
          icon: Icons.chevron_right_rounded,
          semanticLabel: l.ptNextDay,
          variant: MadarButtonVariant.ghost,
          size: MadarButtonSize.small,
          sfx: Sfx.swipe,
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// One day's moments on a glass card.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.schedule,
    required this.clock,
    required this.now,
    required this.isToday,
    this.onPrayerTap,
  });

  final PrayerTimesDay day;
  final PrayerSchedule schedule;
  final PrayerClockFormat clock;
  final DateTime now;
  final bool isToday;
  final ValueChanged<Prayer>? onPrayerTap;

  static const _rowBase = 44.0;
  static const _rowPerScale = 14.0;
  static const _nightHeader = 40.0;
  static const _padding = Space.s;

  static double rowHeight(TextScaler scaler) => _rowBase + _rowPerScale * scaler.scale(1).clamp(1.0, 2.0);

  /// The card's height for the text scale (7 day rows, the night label and
  /// 2 night rows).
  static double heightFor(TextScaler scaler) =>
      2 * _padding + 9 * rowHeight(scaler) + _nightHeader * scaler.scale(1).clamp(1.0, 2.0);

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final friday = day.date.weekday == DateTime.friday;
    final rowH = rowHeight(MediaQuery.textScalerOf(context));
    final next = isToday ? day.nextAt(now) : null;
    Widget row(PrayerMomentTime m) {
      final status = isToday ? day.statusOf(m.moment, now) : null;
      String? detail = l.momentHint(m.moment);
      if (next != null && next.moment == m.moment) {
        detail = fmt.formatDurationWords(l, m.at.difference(now));
      }
      final prayer = m.moment.prayer;
      return _MomentRow(
        height: rowH,
        moment: m.moment,
        name: l.momentName(m.moment, friday: friday),
        detail: detail,
        detailIsCountdown: next != null && next.moment == m.moment,
        time: clock.format(schedule.wallClock(m.at)),
        status: status,
        onTap: prayer != null && onPrayerTap != null && status != MomentStatus.upcoming
            ? () => onPrayerTap!(prayer)
            : null,
        onLongPress: adjustmentKeyOf(m.moment) == null
            ? null
            : () => showPrayerAdjustmentSheet(context, m.moment, date: day.date),
      );
    }

    final moments = day.moments;
    return GlassCard(
      seed: day.date.day / 31,
      padding: const EdgeInsetsDirectional.all(_padding),
      child: Column(
        children: [
          for (final m in moments.where((m) => !m.moment.isNight)) row(m),
          SizedBox(
            height: _nightHeader * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
            child: Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m),
                child: PrayerOrnamentLabel(l.ptNightSection),
              ),
            ),
          ),
          for (final m in moments.where((m) => m.moment.isNight)) row(m),
        ],
      ),
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({
    required this.height,
    required this.moment,
    required this.name,
    required this.detail,
    required this.detailIsCountdown,
    required this.time,
    required this.status,
    this.onTap,
    this.onLongPress,
  });

  final double height;
  final PrayerMoment moment;
  final String name;
  final String? detail;
  final bool detailIsCountdown;
  final PrayerClockText time;
  final MomentStatus? status;
  final VoidCallback? onTap;

  /// Opens the minute adjustment of this time.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final obligatory = moment.isObligatory;
    final current = status == MomentStatus.current;
    final past = status == MomentStatus.past;
    final nameColor = current
        ? t.textPrimary
        : (past ? t.textTertiary : (obligatory ? t.textPrimary : t.textSecondary));
    final timeColor = current ? t.accent : (past ? t.textTertiary : (obligatory ? t.textPrimary : t.textSecondary));
    final iconColor = current ? t.gold : (past ? t.textTertiary : (obligatory ? t.accent : t.textTertiary));

    Widget content = AnimatedContainer(
      duration: context.motion(MadarMotion.medium),
      height: height,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusM),
        gradient: current
            ? LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [t.accent.withValues(alpha: 0.22), t.accent.withValues(alpha: 0.06)],
              )
            : null,
        border: current ? Border.all(color: t.accent.withValues(alpha: 0.55), width: 1) : null,
        boxShadow: current ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.25), blurRadius: 16)] : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: current ? 0.18 : 0.10),
              border: Border.all(color: iconColor.withValues(alpha: current ? 0.6 : 0.3), width: 0.8),
            ),
            child: Icon(momentIcon(moment), size: 17, color: iconColor),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (obligatory ? text.titleMedium : text.bodyLarge)!.copyWith(
                    color: nameColor,
                    fontWeight: obligatory ? FontWeight.w600 : FontWeight.w500,
                    height: 1.25,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(
                      color: detailIsCountdown ? t.accent : (current ? t.textSecondary : t.textTertiary),
                      height: 1.25,
                    ),
                  ),
              ],
            ),
          ),
          if (current) ...[
            Container(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: 2),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radiusS), color: t.accent),
              child: Text(
                l.ptNow,
                style: text.labelSmall!.copyWith(color: t.textOnAccent, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: Space.s),
          ],
          PrayerTimeText(
            time,
            size: obligatory ? 20 : 17,
            color: timeColor,
            weight: obligatory ? FontWeight.w600 : FontWeight.w500,
          ),
        ],
      ),
    );

    final semantics = [name, time.joined, if (current) l.ptNow, ?detail].join(', ');
    if (onTap == null && onLongPress == null) {
      return Semantics(label: semantics, excludeSemantics: true, child: content);
    }
    return MadarPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      button: onTap != null,
      sfx: Sfx.sheetOpen,
      semanticLabel: semantics,
      excludeChildSemantics: true,
      pressScale: 0.985,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: content,
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.settings,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final PrayerSettings settings;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    String title;
    try {
      title = DateFormat.yMMMM(lang).format(month);
    } catch (_) {
      title = DateFormat.yMMMM('en').format(month);
    }
    title = fmt.localizeDigits(title);
    final first = hijriOfDate(settings, month);
    final last = hijriOfDate(settings, DateTime(month.year, month.month + 1, 0));
    String part(int m, int y, {bool year = true}) =>
        year ? '${l.hijriMonth(m)} ${fmt.formatInt(y, grouping: false)}' : l.hijriMonth(m);
    final span = first.month == last.month
        ? part(first.month, first.year)
        : l.ptMonthHijriSpan(part(first.month, first.year, year: first.year != last.year), part(last.month, last.year));
    return Row(
      children: [
        MadarButton.icon(
          icon: Icons.chevron_left_rounded,
          semanticLabel: l.ptPrevMonth,
          variant: MadarButtonVariant.ghost,
          size: MadarButtonSize.small,
          sfx: Sfx.swipe,
          onPressed: onPrevious,
        ),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(title, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (onToday != null) ...[
                    const SizedBox(width: Space.s),
                    MadarPressable(
                      onTap: onToday,
                      sfx: Sfx.navigate,
                      semanticLabel: l.ptBackToToday,
                      excludeChildSemantics: true,
                      child: Icon(Icons.today_rounded, size: 18, color: t.accent),
                    ),
                  ],
                ],
              ),
              Text(
                span,
                style: text.bodySmall!.copyWith(color: t.gold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        MadarButton.icon(
          icon: Icons.chevron_right_rounded,
          semanticLabel: l.ptNextMonth,
          variant: MadarButtonVariant.ghost,
          size: MadarButtonSize.small,
          sfx: Sfx.swipe,
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// The month's times as a table: date (with the Hijri day) and the six
/// daily times; today highlighted, Fridays tinted.
class _MonthTable extends ConsumerWidget {
  const _MonthTable({
    required this.month,
    required this.schedule,
    required this.clock,
    required this.today,
    this.todayKey,
    this.headKey,
  });

  final DateTime month;
  final PrayerSchedule schedule;
  final PrayerClockFormat clock;
  final DateTime today;

  /// Given to today's row (when this month holds today).
  final Key? todayKey;

  /// Given to the column heads (the screen pins a copy once they scroll
  /// away).
  final Key? headKey;

  /// "Day, Fajr, Sunrise …": the column heads, also pinned by the screen.
  static Widget headRow(BuildContext context, {Key? key}) {
    final t = context.tokens;
    final l = L10n.of(context);
    final head = Theme.of(context).textTheme.labelSmall!.copyWith(color: t.gold, fontWeight: FontWeight.w600);
    Widget cellBox(Widget child) => Expanded(child: Center(child: child));
    return SizedBox(
      key: key,
      height: 30,
      child: Row(
        children: [
          cellBox(Text(l.ptMonthDay, style: head, maxLines: 1)),
          for (final m in _moments)
            cellBox(Text(l.momentName(m), style: head, maxLines: 1, overflow: TextOverflow.fade)),
        ],
      ),
    );
  }

  static const _moments = [
    PrayerMoment.fajr,
    PrayerMoment.sunrise,
    PrayerMoment.dhuhr,
    PrayerMoment.asr,
    PrayerMoment.maghrib,
    PrayerMoment.isha,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final settings = ref.watch(prayerSettingsControllerProvider);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cell = MadarTypography.numerals(t, size: 13.5);
    Widget cellBox(Widget child) => Expanded(child: Center(child: child));

    return GlassPanel(
      seed: 0.52,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.s, Space.xs, Space.s),
      child: Column(
        children: [
          headRow(context, key: headKey),
          Container(height: 0.8, color: t.glassBorder),
          for (var d = 1; d <= days; d++)
            Builder(
              builder: (context) {
                final date = DateTime(month.year, month.month, d);
                final isToday = date == today;
                final friday = date.weekday == DateTime.friday;
                final pd = PrayerTimesDay.of(schedule, date);
                final hijri = hijriOfDate(settings, date);
                final times = [for (final m in _moments) clock.format(schedule.wallClock(pd.timeOf(m))).clock];
                return Semantics(
                  key: isToday ? todayKey : null,
                  label:
                      '${fmt.formatDate(date, style: MadarDateStyle.weekdayDayMonth)}: '
                      '${[for (var i = 0; i < _moments.length; i++) '${l.momentName(_moments[i])} ${times[i]}'].join(l.interactionListSeparator)}',
                  excludeSemantics: true,
                  child: Container(
                    height: 36 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(t.radiusS),
                      color: isToday
                          ? t.accent.withValues(alpha: 0.18)
                          : (friday ? t.gold.withValues(alpha: t.isDark ? 0.06 : 0.09) : null),
                      border: isToday ? Border.all(color: t.accent.withValues(alpha: 0.55), width: 0.9) : null,
                    ),
                    child: Row(
                      children: [
                        cellBox(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                fmt.formatInt(d),
                                style: cell.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isToday ? t.accent : (friday ? t.gold : t.textPrimary),
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                fmt.formatInt(hijri.day),
                                style: text.labelSmall!.copyWith(color: t.textTertiary, height: 1.0, fontSize: 9.5),
                              ),
                            ],
                          ),
                        ),
                        for (final s in times)
                          cellBox(
                            Text(
                              s,
                              maxLines: 1,
                              style: cell.copyWith(color: isToday ? t.textPrimary : t.textSecondary),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// The day title of the day view: «الليلة» for the night still running
/// after midnight (the previous date's prayer day), otherwise today /
/// tomorrow / yesterday by the location's calendar date, else the weekday.
@visibleForTesting
String prayerDayTitle(L10n l, String languageCode, DateTime date, DateTime prayerDay, DateTime calendarToday) {
  int days(DateTime a, DateTime b) =>
      DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;
  if (days(date, prayerDay) == 0 && days(prayerDay, calendarToday) != 0) return l.ptTonight;
  return switch (days(date, calendarToday)) {
    0 => l.ptToday,
    1 => l.ptTomorrow,
    -1 => l.ptYesterday,
    _ => DateFormat.EEEE(languageCode).format(date),
  };
}

/// A quiet footnote under the day card: how to adjust a time.
class _AdjustHint extends StatelessWidget {
  const _AdjustHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(color: t.textTertiary, height: 1.4);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app_outlined, size: 15, color: t.textTertiary),
        const SizedBox(width: Space.xs),
        Flexible(
          child: Text(text, style: style, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
