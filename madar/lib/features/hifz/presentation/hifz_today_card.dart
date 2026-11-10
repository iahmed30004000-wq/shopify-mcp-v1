import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/sound/sound_api.dart';
import '../data/hifz_providers.dart';
import 'hifz_actions.dart';
import 'hifz_navigation.dart';

/// Compact card for the Faith planet page: today's reviews (due and new)
/// with a ring and "start"; tap opens the Hifz screen ([onOpen], else
/// pushed with [HifzNavigation]); [onStartReview] likewise.
class HifzTodayCard extends ConsumerWidget {
  const HifzTodayCard({super.key, this.onOpen, this.onStartReview});

  final void Function(BuildContext context)? onOpen;
  final HifzStartReview? onStartReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final stats = ref.watch(hifzStatsProvider).value;

    void open() {
      if (onOpen != null) {
        Fx.fire(Sfx.navigate);
        onOpen!(context);
      } else {
        unawaited(HifzNavigation.openHifz(context));
      }
    }

    void start() {
      if (onStartReview != null) {
        Fx.fire(Sfx.navigate);
        onStartReview!(context);
      } else {
        unawaited(HifzNavigation.openReview(context));
      }
    }

    final empty = stats != null && stats.total == 0;
    final left = stats?.sessionSize ?? 0;
    final done = stats?.reviewedToday ?? 0;
    final all = stats != null && !empty && left == 0;
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, size: 18, color: t.accent),
              const SizedBox(width: Space.s),
              Expanded(child: Text(l.hifzTodayTitle, style: text.titleMedium)),
              if (!empty)
                MadarPressable(
                  onTap: open,
                  sfx: null,
                  semanticLabel: l.hifzOpenAll,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.hifzOpenAll, style: text.labelLarge!.copyWith(color: t.accent)),
                        // Mirrored automatically in RTL.
                        Icon(Icons.chevron_right_rounded, size: 18, color: t.accent),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.m),
          if (stats == null)
            const SizedBox(height: 56, child: Center(child: OrbitLoader(size: 28)))
          else if (empty)
            Row(
              children: [
                Expanded(child: Text(l.hifzEmptyBody, style: text.bodySmall)),
                const SizedBox(width: Space.m),
                MadarButton(
                  label: l.hifzStartCta,
                  icon: Icons.add_rounded,
                  size: MadarButtonSize.small,
                  sfx: Sfx.sheetOpen,
                  onPressed: () => HifzActions.add(context, ref),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: MadarPressable(
                    onTap: open,
                    sfx: null,
                    semanticLabel: l.hifzOpenAll,
                    child: Row(
                      children: [
                        ProgressRing(
                          value: all ? 1 : done / (done + left),
                          size: 56,
                          strokeWidth: 5,
                          color: all ? t.success : t.accent,
                          glow: all,
                          semanticLabel: l.hifzTodayTitle,
                          semanticValue: fmt.localizeDigits(l.hifzDueCount(left)),
                          child: all
                              ? Icon(Icons.check_rounded, size: 24, color: t.success)
                              : Text(fmt.formatInt(left), style: text.titleMedium!.copyWith(color: t.textPrimary)),
                        ),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                all ? l.hifzNothingDue : fmt.localizeDigits(l.hifzDueCount(stats.dueToday)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleMedium,
                              ),
                              Text(
                                all
                                    ? l.hifzAllCaughtUp
                                    : [
                                        if (stats.newLeftToday > 0)
                                          fmt.localizeDigits(l.hifzNewCount(stats.newLeftToday)),
                                        if (stats.retention != null)
                                          '${l.hifzStatRetention} ${fmt.formatPercent(stats.retention!)}',
                                      ].join(l.wirdSep),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall!.copyWith(color: all ? t.success : t.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!all) ...[
                  const SizedBox(width: Space.s),
                  MadarButton(
                    label: done > 0 ? l.hifzContinueReview : l.hifzStartReview,
                    icon: Icons.play_arrow_rounded,
                    size: MadarButtonSize.small,
                    sfx: Sfx.navigate,
                    onPressed: start,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
