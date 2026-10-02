import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../data/tracker_providers.dart';
import '../domain/tracker_prayers.dart';
import 'widgets/fard_tile.dart';
import 'widgets/nafl_tiles.dart';

/// Opens the editor of one prayer day (from the week strip or the month
/// heatmap): its five prayers with their rawatib and the nawafil, with the
/// same gestures as the Today tab – so a past day can be filled in or
/// corrected.
Future<void> showTrackerDaySheet(BuildContext context, DateTime day) =>
    showInteractionSheet<void>(context, builder: (_) => TrackerDaySheet(day: DateTime(day.year, day.month, day.day)));

class TrackerDaySheet extends ConsumerWidget {
  const TrackerDaySheet({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final view = ref.watch(trackerDayProvider(day)).value;
    final title = fmt.formatDate(day, style: MadarDateStyle.weekdayDayMonth);
    return InteractionSheetFrame(
      title: title,
      subtitle: view == null
          ? null
          : l.trackerProgress(fmt.formatInt(view.prayedCount), fmt.formatInt(TrackerPrayers.obligatory.length)),
      icon: Icons.event_available_rounded,
      body: view == null
          ? const Padding(
              padding: EdgeInsetsDirectional.all(Space.xl),
              child: Center(child: OrbitLoader(size: 36)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in TrackerPrayers.obligatory)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                    child: FardPrayerTile(key: ValueKey(p), view: view, prayer: p),
                  ),
                SectionHeader(
                  title: l.trackerVoluntary,
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.m, Space.xs, Space.s),
                ),
                NaflTiles(view: view),
              ],
            ),
    );
  }
}
