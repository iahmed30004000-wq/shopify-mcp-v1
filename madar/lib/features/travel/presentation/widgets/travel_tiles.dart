import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../prayer/domain/cities.dart';
import '../../domain/documents.dart';
import '../../domain/travel_overview.dart';
import '../../domain/trip_timeline.dart';
import '../../travel_texts.dart';
import '../document_sheet.dart' show DocMedallion;
import 'travel_widgets.dart';

/// A trip row: its world, destination and country, dates, countdown, any
/// document warning, and the packing ring.
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.now,
    this.cities,
    this.warnings = 0,
    this.worstWarning,
  });

  final TripView trip;
  final DateTime now;
  final CityDatabase? cities;
  final int warnings;
  final DocumentConflict? worstWarning;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TravelTexts.of(context);
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final row = trip.row;
    final name = trip.displayName(lang);
    final country = trip.countryName(lang, cities);
    final past = trip.phase == TripPhase.past;
    final p = trip.packing;
    return GlassCard(
      glow: trip.phase == TripPhase.current,
      glowColor: tripPalette(row.color).surface,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
      child: Row(
        children: [
          TripOrb(color: row.color, phase: trip.phase, size: 46),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: tx.name(name), style: text.titleMedium!.copyWith(color: past ? t.textSecondary : t.textPrimary)),
                      if (country != null && country != name)
                        TextSpan(
                          text: '${tx.l.interactionListSeparator}${tx.name(country)}',
                          style: text.bodySmall!.copyWith(color: t.textTertiary),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                TravelMetaLine(
                  icon: Icons.event_rounded,
                  text: tx.dateRange(row.startDate, row.endDate, now: now),
                ),
                const SizedBox(height: Space.xs),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TravelPill(label: tx.countdown(trip.countdown), tone: countdownTone(trip.countdown), dense: true),
                    if (trip.manual)
                      TravelPill(label: tx.status(trip.status), tone: PillTone.neutral, icon: Icons.push_pin_rounded, dense: true),
                    if (warnings > 0 && worstWarning != null)
                      TravelPill(
                        label: tx.n(warnings),
                        tone: conflictTone(worstWarning!),
                        icon: Icons.warning_amber_rounded,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (!p.isEmpty) ...[
            const SizedBox(width: Space.s),
            PackingRing(
              progress: p,
              size: 44,
              label: p.complete ? null : tx.fmt.localizeDigits('${p.packed}/${p.total}'),
              semanticLabel: tx.packedCount(p),
            ),
          ],
        ],
      ),
    );
  }
}

/// A document row: kind medallion, name (and holder), masked number, expiry
/// date and countdown, and the trip it endangers.
class DocumentTile extends StatelessWidget {
  const DocumentTile({super.key, required this.doc, required this.today, this.warning, this.warningTrip});

  final DocFacts doc;
  final DateTime today;
  final DocumentConflict? warning;
  final String? warningTrip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TravelTexts.of(context);
    final text = Theme.of(context).textTheme;
    final e = DocumentExpiry.of(expiry: doc.expiry, remindDaysBefore: doc.remindDaysBefore, today: today);
    final tone = expiryTone(e.state);
    final number = doc.number?.trim();
    final details = [
      if (doc.expiry != null) tx.fmt.formatDate(doc.expiry!, style: MadarDateStyle.medium),
      if (number != null && number.isNotEmpty) tx.maskedNumber(number),
    ].join(tx.l.commonFactSeparator);
    return GlassCard(
      glow: false,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DocMedallion(kind: doc.kind, tone: tone, size: 42),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.docTitle(doc), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                ],
                const SizedBox(height: Space.xs),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    TravelPill(label: tx.expiry(e, on: doc.expiry), tone: tone, dense: true),
                    if (doc.expiry != null)
                      TravelPill(
                        label: tx.remindLabel(doc.remindDaysBefore),
                        tone: PillTone.neutral,
                        icon: Icons.notifications_rounded,
                        dense: true,
                      ),
                  ],
                ),
                if (warning != null && warningTrip != null) ...[
                  const SizedBox(height: Space.xs),
                  TravelMetaLine(
                    icon: Icons.warning_amber_rounded,
                    color: pillColor(conflictTone(warning!), t),
                    text: tx.l.travelDocAffects(tx.name(warningTrip!)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A trip's document warnings, most serious first.
class TripWarningsCard extends StatelessWidget {
  const TripWarningsCard({super.key, required this.warnings});

  final List<TripDocumentWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TravelTexts.of(context);
    final text = Theme.of(context).textTheme;
    final worst = warnings.first.conflict;
    final c = pillColor(conflictTone(worst), t);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusM),
        color: c.withValues(alpha: t.isDark ? 0.12 : 0.08),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, w) in warnings.indexed) ...[
            if (i > 0) const SizedBox(height: Space.s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  w.conflict == DocumentConflict.validityShort ? Icons.info_rounded : Icons.warning_amber_rounded,
                  size: 18,
                  color: pillColor(conflictTone(w.conflict), t),
                ),
                const SizedBox(width: Space.s),
                Expanded(child: Text(tx.warning(w), style: text.bodyMedium!.copyWith(color: t.textPrimary, height: 1.4))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
