import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/sound/sound_api.dart';
import '../data/wird_providers.dart';
import '../domain/wird_engine.dart';
import 'wird_actions.dart';
import 'wird_labels.dart';
import 'wird_navigation.dart';

/// Compact card for the Faith planet page: the primary plan's portion today
/// (ring, range, pages, pace) with "read" and "done"; a call to start a
/// plan when there is none. Tapping the card opens the wird screen
/// ([onOpen], else pushed with [WirdNavigation]).
class WirdTodayCard extends ConsumerWidget {
  const WirdTodayCard({super.key, this.onOpen, this.onReadNow});

  final void Function(BuildContext context)? onOpen;
  final WirdReadNow? onReadNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    ref.watch(wirdCompletionSyncProvider);
    final primary = ref.watch(wirdPrimaryStateProvider);
    final catalog = ref.watch(quranCatalogReadyProvider).value;
    final readNow = onReadNow ?? ref.watch(wirdReadNowProvider);

    void open() {
      if (onOpen != null) {
        Fx.fire(Sfx.navigate);
        onOpen!(context);
      } else {
        unawaited(WirdNavigation.openWird(context, onReadNow: onReadNow));
      }
    }

    final state = primary.value;
    final header = Row(
      children: [
        Icon(Icons.auto_stories_rounded, size: 18, color: t.accent),
        const SizedBox(width: Space.s),
        Expanded(child: Text(l.wirdTodayTitle, style: text.titleMedium)),
        if (state != null)
          MadarPressable(
            onTap: open,
            sfx: null,
            semanticLabel: l.wirdOpenAll,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.wirdOpenAll, style: text.labelLarge!.copyWith(color: t.accent)),
                  // Mirrored automatically in RTL.
                  Icon(Icons.chevron_right_rounded, size: 18, color: t.accent),
                ],
              ),
            ),
          ),
      ],
    );

    Widget body;
    if (primary.isLoading && state == null || catalog == null) {
      body = const SizedBox(height: 64, child: Center(child: OrbitLoader(size: 28)));
    } else if (state == null) {
      body = Row(
        children: [
          Expanded(child: Text(l.wirdEmptyBody, style: text.bodySmall)),
          const SizedBox(width: Space.m),
          MadarButton(
            label: l.wirdStartPlanCta,
            icon: Icons.add_rounded,
            size: MadarButtonSize.small,
            onPressed: () => WirdActions.create(context, ref),
            sfx: Sfx.sheetOpen,
          ),
        ],
      );
    } else {
      final texts = WirdTexts(l, fmt, catalog);
      final target = state.target;
      final met = state.started && !state.paused && target.met;
      final range = target.range;
      final String line;
      Color lineColor = t.textSecondary;
      if (state.completed) {
        line = l.wirdKhatmaDone;
        lineColor = t.success;
      } else if (state.paused) {
        line = l.wirdPausedNote;
      } else if (!state.started) {
        line = l.wirdNotStarted(fmt.formatDate(state.plan.startDate, style: MadarDateStyle.weekdayDayMonth));
      } else if (met) {
        line = target.quota <= WirdEngine.eps ? l.wirdRestToday : l.wirdMetToday;
        lineColor = t.success;
      } else {
        line =
            texts.pace(state, short: true) ??
            l.wirdLeftToday(texts.amount(state.plan.unit, target.quota - target.done));
        if (target.behind > 0) lineColor = t.warning;
      }
      body = Row(
        children: [
          Expanded(
            child: MadarPressable(
              onTap: open,
              sfx: null,
              semanticLabel: l.wirdOpenAll,
              child: Row(
                children: [
                  ProgressRing(
                    value: state.paused ? 0 : target.progress,
                    size: 56,
                    strokeWidth: 5,
                    color: met ? t.success : t.accent,
                    glow: met,
                    semanticLabel: l.wirdTodayTitle,
                    semanticValue: fmt.formatPercent(target.progress),
                    child: met
                        ? Icon(Icons.check_rounded, size: 24, color: t.success)
                        : Text(
                            fmt.formatPercent(target.progress),
                            style: text.labelMedium!.copyWith(color: t.textPrimary),
                          ),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A range wraps rather than be cut inside a
                        // reference («البقرة ١…» would misstate the portion).
                        Text(
                          range == null ? state.plan.name : texts.range(range),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
                        ),
                        if (range != null)
                          Text(
                            '${texts.pages(range)}${l.wirdSep}${texts.amount(state.plan.unit, target.quota)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall,
                          ),
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium!.copyWith(color: lineColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!met && !state.paused && state.started && !state.completed) ...[
            const SizedBox(width: Space.s),
            MadarButton.icon(
              icon: Icons.check_rounded,
              onPressed: target.remaining == null ? null : () => WirdActions.markDone(context, ref, state),
              semanticLabel: l.wirdMarkDone,
              size: MadarButtonSize.small,
              variant: MadarButtonVariant.secondary,
              sfx: Sfx.complete,
            ),
            const SizedBox(width: Space.xs),
            MadarButton.icon(
              icon: Icons.menu_book_rounded,
              onPressed: readNow == null || target.resumeAt == null
                  ? null
                  : () => WirdActions.readNow(context, readNow, state),
              semanticLabel: l.wirdReadNow,
              size: MadarButtonSize.small,
              variant: MadarButtonVariant.primary,
              sfx: Sfx.navigate,
            ),
          ],
        ],
      );
    }

    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: Space.m),
          body,
        ],
      ),
    );
  }
}
