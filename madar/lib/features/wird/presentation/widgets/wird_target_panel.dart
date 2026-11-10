import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/quran/quran_catalog.dart';
import '../../../home/widgets/window_chips.dart' show windowIcon;
import '../../domain/wird_engine.dart';
import '../wird_labels.dart';

/// The unit word under the ring's number (`صفحات`, `آيات` …).
String wirdUnitWord(L10n l, WirdUnit unit) => switch (unit) {
  WirdUnit.pages => l.wirdTemplatePages,
  WirdUnit.juz => l.wirdTemplateJuz,
  WirdUnit.hizb => l.wirdTemplateHizb,
  WirdUnit.ayat => l.wirdTemplateAyat,
};

/// Today's portion of a plan: progress ring, the range with its pages, the
/// pace line (behind / ahead / done), and the actions – read now, mark
/// done, "I stopped at…".
class WirdTargetPanel extends StatelessWidget {
  const WirdTargetPanel({
    super.key,
    required this.state,
    required this.catalog,
    required this.onMarkDone,
    required this.onStoppedAt,
    this.onReadNow,
    this.onResume,
    this.primary = false,
  });

  final WirdPlanState state;
  final QuranCatalog catalog;
  final VoidCallback onMarkDone;
  final VoidCallback onStoppedAt;
  final VoidCallback? onReadNow;
  final VoidCallback? onResume;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final texts = WirdTexts(l, fmt, catalog);
    final target = state.target;
    final plan = state.plan;
    final done = state.started && !state.paused && target.met;
    final ringColor = done ? t.success : (state.paused ? t.textTertiary : t.accent);
    final range = target.range;

    final String status;
    Color statusColor = t.textSecondary;
    if (state.completed) {
      status = l.wirdKhatmaDone;
      statusColor = t.success;
    } else if (state.paused) {
      status = l.wirdPausedNote;
    } else if (!state.started) {
      status = l.wirdNotStarted(fmt.formatDate(plan.startDate, style: MadarDateStyle.weekdayDayMonth));
      statusColor = t.info;
    } else if (target.met && target.quota <= WirdEngine.eps) {
      status = l.wirdRestToday;
      statusColor = t.success;
    } else if (target.met) {
      status = texts.pace(state) ?? l.wirdMetToday;
      statusColor = t.success;
    } else {
      final pace = texts.pace(state);
      status = pace ?? l.wirdLeftToday(texts.amount(plan.unit, target.quota - target.done));
      statusColor = target.behind > 0 ? t.warning : (target.ahead > 0 ? t.success : t.textSecondary);
    }

    final quotaWhole = target.quota <= WirdEngine.eps ? 0.0 : target.quota;
    // Whole units in the ring (a fraction of a page reads as noise there).
    String whole(double v) => fmt.formatInt(v.isFinite ? (v + 1e-6).floor() : 0);
    final centreValue = whole(target.done.clamp(0, quotaWhole));
    final centreQuota = texts.amount(plan.unit, quotaWhole);
    final cross = range != null && range.first.surah != range.last.surah;

    return GlassPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.l),
      glowColor: done ? t.success.withValues(alpha: 0.5) : t.accentGlow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(windowIcon(plan.window ?? PrayerWindow.anytime), size: 16, color: t.brass),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  '${plan.name}${l.wirdSep}${texts.window(plan.window)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium!.copyWith(color: t.textSecondary),
                ),
              ),
              if (primary) ...[const SizedBox(width: Space.s), IslamicStar(size: 14, color: t.gold, glow: true)],
            ],
          ),
          const SizedBox(height: Space.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProgressRing(
                value: state.paused ? 0 : target.progress,
                size: 112,
                strokeWidth: 8,
                color: ringColor,
                glow: !state.paused,
                semanticLabel: l.wirdTodayTitle,
                semanticValue: l.wirdProgressOf(centreValue, centreQuota),
                child: done
                    ? Icon(Icons.check_rounded, size: 44, color: t.success)
                    : state.paused
                    ? Icon(Icons.pause_rounded, size: 40, color: t.textTertiary)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            centreValue,
                            style: MadarTypography.numerals(t, size: 34, color: t.textPrimary).copyWith(height: 1.05),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.wirdProgressOfShort(centreQuota),
                            style: text.labelMedium!.copyWith(color: t.textSecondary, height: 1.2),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.wirdTodayTitle, style: text.labelMedium!.copyWith(color: t.accent)),
                    const SizedBox(height: Space.xxs),
                    AnimatedSwitcher(
                      duration: context.motion(MadarMotion.medium),
                      child: Text(
                        range == null ? '—' : texts.range(range),
                        key: ValueKey(range),
                        maxLines: 2,
                        style: cross ? text.titleLarge : text.headlineSmall,
                      ),
                    ),
                    if (range != null) ...[
                      const SizedBox(height: Space.xxs),
                      Text(
                        '${texts.pages(range)}${l.wirdSep}${texts.amount(plan.unit, target.quota)}',
                        style: text.bodySmall,
                      ),
                    ],
                    const SizedBox(height: Space.s),
                    Text(
                      status,
                      style: text.bodySmall!.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          if (state.paused)
            MadarButton(
              label: l.wirdResume,
              icon: Icons.play_arrow_rounded,
              onPressed: onResume,
              variant: MadarButtonVariant.secondary,
              expand: true,
            )
          else if (!state.completed)
            Row(
              children: [
                Expanded(
                  child: MadarButton(
                    label: done ? l.wirdContinue : l.wirdReadNow,
                    icon: Icons.menu_book_rounded,
                    onPressed: onReadNow,
                    variant: done ? MadarButtonVariant.secondary : MadarButtonVariant.primary,
                    expand: true,
                  ),
                ),
                if (!done && state.started && target.remaining != null) ...[
                  const SizedBox(width: Space.s),
                  MadarButton(
                    label: l.wirdMarkDone,
                    icon: Icons.check_rounded,
                    onPressed: onMarkDone,
                    variant: MadarButtonVariant.secondary,
                  ),
                  const SizedBox(width: Space.xs),
                  MadarButton.icon(
                    icon: Icons.bookmark_add_outlined,
                    onPressed: onStoppedAt,
                    semanticLabel: l.wirdStoppedAt,
                    variant: MadarButtonVariant.ghost,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
