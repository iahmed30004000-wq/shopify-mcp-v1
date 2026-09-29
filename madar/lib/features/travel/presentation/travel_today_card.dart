import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/sound/sound_api.dart';
import '../data/travel_providers.dart';
import '../domain/trip_timeline.dart';
import '../travel_texts.dart';
import 'document_sheet.dart' show DocMedallion;
import 'travel_actions.dart';
import 'travel_screen.dart';
import 'widgets/travel_widgets.dart';

/// Compact card for the Travel planet hub: the trip under way or the next
/// one with its countdown and packing progress, its most serious document
/// warning, and documents that need attention.
class TravelTodayCard extends ConsumerWidget {
  const TravelTodayCard({super.key, this.onOpen, this.onOpenTrip, this.maxDocuments = 2});

  /// Opens the travel screen (default: pushes [TravelScreen]).
  final void Function(BuildContext context)? onOpen;

  /// Opens a trip (default: pushes its trip screen).
  final void Function(BuildContext context, String tripId)? onOpenTrip;
  final int maxDocuments;

  void _open(BuildContext context) {
    if (onOpen != null) {
      Fx.fire(Sfx.navigate);
      onOpen!(context);
    } else {
      Fx.fire(Sfx.navigate);
      unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TravelScreen())));
    }
  }

  void _openTrip(BuildContext context, String id) {
    if (onOpenTrip != null) {
      Fx.fire(Sfx.navigate);
      onOpenTrip!(context, id);
    } else {
      TravelActions.openTrip(context, id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final tx = TravelTexts.of(context);
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final overview = ref.watch(travelOverviewProvider);
    final now = ref.watch(travelNowProvider);

    final header = Row(
      children: [
        Icon(Icons.flight_takeoff_rounded, size: 18, color: t.accent),
        const SizedBox(width: Space.s),
        Expanded(child: Text(l.travelTitle, style: text.titleMedium)),
        MadarPressable(
          onTap: () => _open(context),
          sfx: null,
          semanticLabel: l.travelTitle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(Space.xs),
            child: Icon(Icons.chevron_right_rounded, size: 20, color: t.accent, textDirection: Directionality.of(context)),
          ),
        ),
      ],
    );

    Widget body;
    if (overview == null) {
      body = const SizedBox(height: 56, child: Center(child: OrbitLoader(size: 26)));
    } else {
      final focus = overview.focus;
      final today = TravelDates.day(now);
      final attention = overview.attention(today).take(maxDocuments).toList();
      final warnings = focus == null ? const [] : overview.warningsFor(focus.id);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (focus == null)
            Row(
              children: [
                Expanded(child: Text(l.travelCardNoTrips, style: text.bodyMedium!.copyWith(color: t.textSecondary))),
                MadarButton(
                  label: l.travelAddTrip,
                  icon: Icons.add_rounded,
                  size: MadarButtonSize.small,
                  sfx: Sfx.sheetOpen,
                  onPressed: () => TravelActions.addTrip(context, ref),
                ),
              ],
            )
          else
            MadarPressable(
              onTap: () => _openTrip(context, focus.id),
              sfx: null,
              semanticLabel: l.travelOpenTrip(focus.displayName(lang)),
              child: Row(
                children: [
                  TripOrb(color: focus.row.color, phase: focus.phase, size: 38),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          focus.displayName(lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            TravelPill(label: tx.countdown(focus.countdown), tone: countdownTone(focus.countdown), dense: true),
                            const SizedBox(width: Space.s),
                            Flexible(
                              child: Text(
                                focus.packing.isEmpty
                                    ? l.travelCardNoPacking
                                    : l.travelCardPacked(tx.n(focus.packing.packed), tx.n(focus.packing.total)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelMedium!.copyWith(
                                  color: focus.packing.complete ? t.success : t.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!focus.packing.isEmpty)
                    PackingRing(
                      progress: focus.packing,
                      size: 36,
                      semanticLabel: tx.packedCount(focus.packing),
                    ),
                ],
              ),
            ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            TravelMetaLine(
              icon: Icons.warning_amber_rounded,
              color: pillColor(conflictTone(warnings.first.conflict), t),
              text: tx.warning(warnings.first),
              maxLines: 2,
            ),
          ],
          if (attention.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            Container(height: 1, color: t.glassBorder.withValues(alpha: 0.5)),
            const SizedBox(height: Space.s),
            for (final (d, e) in attention)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: Space.xs),
                child: Row(
                  children: [
                    DocMedallion(kind: d.kind, tone: expiryTone(e.state), size: 28),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: Text(
                        tx.docTitle(d),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium,
                      ),
                    ),
                    Text(
                      tx.expiry(e, on: d.expiry),
                      style: text.labelMedium!.copyWith(color: pillColor(expiryTone(e.state), t)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      );
    }

    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
      onTap: () => _open(context),
      semanticLabel: l.travelTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, const SizedBox(height: Space.s), body],
      ),
    );
  }
}
