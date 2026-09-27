import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../domain/prayer_day.dart';

/// Localised name of a prayer window.
String windowLabel(L10n l, PrayerWindow w) => switch (w) {
  PrayerWindow.fajr => l.windowFajr,
  PrayerWindow.duha => l.windowDuha,
  PrayerWindow.dhuhr => l.windowDhuhr,
  PrayerWindow.asr => l.windowAsr,
  PrayerWindow.maghrib => l.windowMaghrib,
  PrayerWindow.isha => l.windowIsha,
  PrayerWindow.anytime => l.windowAnytime,
};

/// Localised name of an obligatory prayer.
String prayerLabel(L10n l, Prayer p) => switch (p) {
  Prayer.fajr => l.prayerFajr,
  Prayer.dhuhr => l.prayerDhuhr,
  Prayer.asr => l.prayerAsr,
  Prayer.maghrib => l.prayerMaghrib,
  Prayer.isha => l.prayerIsha,
  _ => l.prayerSunrise,
};

/// Icon of a prayer window (sky position of the sun / moon).
IconData windowIcon(PrayerWindow w) => switch (w) {
  PrayerWindow.fajr => Icons.wb_twilight_rounded,
  PrayerWindow.duha => Icons.wb_sunny_outlined,
  PrayerWindow.dhuhr => Icons.wb_sunny_rounded,
  PrayerWindow.asr => Icons.light_mode_outlined,
  PrayerWindow.maghrib => Icons.nights_stay_outlined,
  PrayerWindow.isha => Icons.dark_mode_rounded,
  PrayerWindow.anytime => Icons.all_inclusive_rounded,
};

/// The six prayer-window chips of the home panel: start time above the
/// window's name; the focused one fills with the accent, the current one
/// carries a glowing "now" dot. Scrolls horizontally and keeps the focused
/// chip in view.
class WindowChips extends StatefulWidget {
  const WindowChips({
    super.key,
    required this.times,
    required this.focused,
    required this.current,
    required this.onSelected,
  });

  final PrayerDayTimes times;
  final PrayerWindow focused;
  final PrayerWindow current;
  final ValueChanged<PrayerWindow> onSelected;

  @override
  State<WindowChips> createState() => _WindowChipsState();
}

class _WindowChipsState extends State<WindowChips> {
  final Map<PrayerWindow, GlobalKey> _keys = {for (final w in PrayerDayTimes.windows) w: GlobalKey()};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
  }

  @override
  void didUpdateWidget(WindowChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focused != widget.focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: true));
    }
  }

  void _reveal({required bool animate}) {
    final ctx = _keys[widget.focused]?.currentContext;
    if (ctx == null || !mounted) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: animate ? context.motion(MadarMotion.medium) : Duration.zero,
      curve: MadarMotion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
        itemCount: PrayerDayTimes.windows.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.s),
        itemBuilder: (context, i) {
          final w = PrayerDayTimes.windows[i];
          final start = widget.times.startOf(w);
          final time = fmt.formatClock(start.inHours, start.inMinutes.remainder(60));
          return _WindowChip(
            key: _keys[w],
            label: windowLabel(l, w),
            time: time,
            icon: windowIcon(w),
            selected: w == widget.focused,
            isNow: w == widget.current,
            nowLabel: l.homeNow,
            semanticLabel: l.homeWindowStarts(windowLabel(l, w), time),
            onTap: () => widget.onSelected(w),
          );
        },
      ),
    );
  }
}

class _WindowChip extends StatelessWidget {
  const _WindowChip({
    super.key,
    required this.label,
    required this.time,
    required this.icon,
    required this.selected,
    required this.isNow,
    required this.nowLabel,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final String time;
  final IconData icon;
  final bool selected;
  final bool isNow;
  final String nowLabel;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: selected ? null : onTap,
      sfx: Sfx.tap,
      selected: selected,
      semanticLabel: isNow ? '$semanticLabel · $nowLabel' : semanticLabel,
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selected ? 1 : 0),
        duration: context.motion(MadarMotion.short),
        curve: MadarMotion.standard,
        builder: (context, v, _) {
          final fg = Color.lerp(t.textSecondary, t.textPrimary, v)!;
          return CustomPaint(
            painter: ChipPainter(
              selection: v,
              fill: Color.alphaBlend(t.glassFill, t.space2.withValues(alpha: t.isDark ? 0.45 : 0.4)),
              border: t.glassBorder,
              accent: t.accent,
              highlight: t.glassHighlight,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xs + 2, Space.l, Space.xs + 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: Color.lerp(t.textTertiary, t.accent, v)),
                  const SizedBox(width: Space.s),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: text.labelSmall!.copyWith(
                              color: Color.lerp(t.textTertiary, t.accent, v),
                              height: 1.1,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (isNow) ...[const SizedBox(width: Space.xs + 2), _NowDot(color: t.accent)],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        style: text.labelLarge!.copyWith(
                          color: fg,
                          height: 1.15,
                          fontWeight: v > 0.5 ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NowDot extends StatelessWidget {
  const _NowDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 6, spreadRadius: 0.5)],
      ),
    );
  }
}
