import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/sound/sound_api.dart';
import '../data/adhkar_providers.dart';
import '../domain/adhkar_models.dart';
import 'adhkar_labels.dart';
import 'adhkar_navigation.dart';

/// Compact card for the Faith planet page: today's five sets as small rings
/// (tap one to read it), the set that fits the moment and the tasbeeh total.
///
/// Callbacks let the host route; by default the screens are pushed with
/// [AdhkarNavigation].
class AdhkarTodayCard extends ConsumerWidget {
  const AdhkarTodayCard({super.key, this.onOpenSet, this.onOpenHome, this.onOpenTasbeeh});

  final AdhkarOpenSet? onOpenSet;
  final AdhkarOpenScreen? onOpenHome;
  final AdhkarOpenScreen? onOpenTasbeeh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final summary = ref.watch(adhkarDaySummaryProvider).value;
    final tasbeeh = ref.watch(tasbeehTodayCountProvider);
    void openSet(AdhkarCategoryId c) {
      final prayer = c == AdhkarCategoryId.afterPrayer ? summary?.suggestedPrayer : null;
      if (onOpenSet != null) {
        Fx.fire(Sfx.navigate);
        onOpenSet!(context, c, prayer);
      } else {
        unawaited(AdhkarNavigation.openSet(context, c, prayer: prayer));
      }
    }

    void openHome() {
      if (onOpenHome != null) {
        Fx.fire(Sfx.navigate);
        onOpenHome!(context);
      } else {
        unawaited(AdhkarNavigation.openHome(context));
      }
    }

    void openTasbeeh() {
      if (onOpenTasbeeh != null) {
        Fx.fire(Sfx.navigate);
        onOpenTasbeeh!(context);
      } else {
        unawaited(AdhkarNavigation.openTasbeeh(context));
      }
    }

    final total = AdhkarCategoryId.values.length;
    final done = summary?.setsDone ?? 0;
    final all = summary != null && done == total;
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_stories_rounded, size: 18, color: t.accent),
              const SizedBox(width: Space.s),
              Expanded(child: Text(l.adhkarTodayTitle, style: text.titleMedium)),
              MadarPressable(
                onTap: openHome,
                sfx: null,
                semanticLabel: l.adhkarAllAdhkar,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.adhkarAllAdhkar, style: text.labelLarge!.copyWith(color: t.accent)),
                      Icon(Icons.chevron_right_rounded, size: 18, color: t.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in AdhkarCategoryId.values)
                Expanded(
                  child: _MiniSet(
                    category: c,
                    progress: summary?.progress[c] ?? 0,
                    suggested: summary?.suggested == c && !(summary?.suggestedDone ?? false),
                    onTap: () => openSet(c),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Expanded(
                child: Text(
                  summary == null
                      ? ''
                      : all
                      ? l.adhkarSuggestAllDone
                      : done == 0
                      ? l.adhkarMoment(summary)
                      : l.adhkarTodayLine(l.adhkarMoment(summary), fmt.formatInt(done), fmt.formatInt(total)),
                  style: text.bodySmall!.copyWith(color: all ? t.success : t.textSecondary),
                ),
              ),
              const SizedBox(width: Space.s),
              MadarPressable(
                onTap: openTasbeeh,
                sfx: null,
                semanticLabel: l.adhkarTasbeehTitle,
                child: Container(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: Space.xxs),
                  decoration: BoxDecoration(
                    color: t.accentSoft,
                    borderRadius: BorderRadius.circular(t.radiusS),
                    border: Border.all(color: t.glassBorder),
                  ),
                  child: Text(
                    // Zero is shown as the bare name ("٠" alone reads as a dot).
                    tasbeeh > 0 ? l.adhkarTasbeehChip(fmt.formatInt(tasbeeh)) : l.adhkarTasbeehTitle,
                    style: text.labelMedium!.copyWith(color: t.accent),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniSet extends StatelessWidget {
  const _MiniSet({required this.category, required this.progress, required this.suggested, required this.onTap});

  final AdhkarCategoryId category;
  final double progress;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final done = progress >= 1;
    return MadarPressable(
      onTap: onTap,
      sfx: null,
      semanticLabel: '${l.adhkarCategoryName(category)} ${fmt.formatPercent(progress)}',
      child: Column(
        children: [
          ProgressRing(
            value: progress,
            size: 48,
            strokeWidth: 4,
            color: done ? t.success : t.accent,
            glow: suggested || done,
            child: Icon(
              done ? Icons.check_rounded : adhkarCategoryIcon(category),
              size: 20,
              color: done ? t.success : (suggested ? t.accent : t.textSecondary),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            l.adhkarCategoryShort(category),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.labelSmall!.copyWith(color: suggested ? t.accent : t.textSecondary),
          ),
        ],
      ),
    );
  }
}
