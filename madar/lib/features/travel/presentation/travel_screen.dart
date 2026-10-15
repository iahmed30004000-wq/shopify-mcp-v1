import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/travel_providers.dart';
import '../domain/documents.dart';
import '../domain/travel_overview.dart';
import '../domain/trip_timeline.dart';
import '../travel_texts.dart';
import 'packing_templates_screen.dart';
import 'travel_actions.dart';
import 'widgets/travel_tiles.dart';
import 'widgets/travel_widgets.dart';

enum TravelTab { trips, documents, templates }

/// Travel: trips (under way, coming up, past), documents by expiry with
/// trip warnings, and packing templates.
class TravelScreen extends ConsumerStatefulWidget {
  const TravelScreen({super.key, this.initialTab = TravelTab.trips, this.animateBackdrop = true, this.showPast});

  final TravelTab initialTab;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  /// Start with the past trips expanded (default: collapsed when there are
  /// current or upcoming trips).
  final bool? showPast;

  @override
  ConsumerState<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends ConsumerState<TravelScreen> {
  late TravelTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    // Keep stored statuses and document reminders in step while open.
    ref.watch(travelStatusSyncProvider);
    ref.watch(travelReminderSyncProvider);
    final (String fabLabel, VoidCallback onAdd) = switch (_tab) {
      TravelTab.trips => (l.travelAddTrip, () => TravelActions.addTrip(context, ref)),
      TravelTab.documents => (l.travelAddDocument, () => TravelActions.addDocument(context, ref)),
      TravelTab.templates => (l.travelAddTemplate, () => TravelActions.addTemplate(context, ref)),
    };
    return MadarScaffold(
      title: l.travelTitle,
      backdropSeed: 3.4,
      animateBackdrop: widget.animateBackdrop,
      floatingAction: MadarButton.icon(
        icon: Icons.add_rounded,
        semanticLabel: fabLabel,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
        onPressed: onAdd,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
            child: TravelTabBar<TravelTab>(
              tabs: TravelTab.values,
              value: _tab,
              labels: {
                TravelTab.trips: l.travelTabTrips,
                TravelTab.documents: l.travelTabDocuments,
                TravelTab.templates: l.travelTabTemplates,
              },
              onChanged: (tab) => setState(() => _tab = tab),
            ),
          ),
          Expanded(
            child: EntranceChoreo(
              id: _tab,
              child: TravelFadeStack(
                index: _tab.index,
                children: [
                  TravelEdgeFade(child: TripsView(key: const ValueKey('travel.trips'), showPast: widget.showPast)),
                  const TravelEdgeFade(child: DocumentsView(key: ValueKey('travel.documents'))),
                  const TravelEdgeFade(child: PackingTemplatesView(key: ValueKey('travel.templates'))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The trips tab.
class TripsView extends ConsumerStatefulWidget {
  const TripsView({super.key, this.showPast});

  final bool? showPast;

  @override
  ConsumerState<TripsView> createState() => _TripsViewState();
}

class _TripsViewState extends ConsumerState<TripsView> {
  bool? _showPast;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final tx = TravelTexts.of(context);
    final overview = ref.watch(travelOverviewProvider);
    if (overview == null) return const Center(child: OrbitLoader(size: 36));
    if (!overview.hasTrips) {
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, 120),
        children: [
          AnimatedEmptyState(
            kind: EmptyStateKind.emptyList,
            title: l.travelTripsEmptyTitle,
            body: '${l.travelTripsEmptyBody}\n${l.travelTripsEmptyExample}',
            actionLabel: l.travelAddTrip,
            actionIcon: Icons.flight_takeoff_rounded,
            onAction: () => TravelActions.addTrip(context, ref),
          ),
        ],
      );
    }
    final showPast = _showPast ?? widget.showPast ?? (overview.current.isEmpty && overview.upcoming.isEmpty);
    var index = 0;
    Widget section(String title, List<TripView> trips) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        for (final trip in trips)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Space.s),
            child: StaggerItem(index: index++, child: _TripRow(trip: trip, overview: overview)),
          ),
        const SizedBox(height: Space.s),
      ],
    );
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, 120),
      children: [
        if (overview.current.isNotEmpty) section(l.travelSectionCurrent, overview.current),
        if (overview.upcoming.isNotEmpty) section(l.travelSectionUpcoming, overview.upcoming),
        if (overview.past.isNotEmpty) ...[
          if (showPast)
            section(l.travelSectionPast, overview.past)
          else
            Align(
              alignment: AlignmentDirectional.center,
              child: MadarButton(
                label: l.travelShowPast(tx.n(overview.past.length)),
                icon: Icons.history_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                onPressed: () => setState(() => _showPast = true),
              ),
            ),
          if (showPast && (overview.current.isNotEmpty || overview.upcoming.isNotEmpty))
            Align(
              alignment: AlignmentDirectional.center,
              child: MadarButton(
                label: l.travelHidePast,
                icon: Icons.expand_less_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                onPressed: () => setState(() => _showPast = false),
              ),
            ),
        ],
      ],
    );
  }
}

class _TripRow extends ConsumerWidget {
  const _TripRow({required this.trip, required this.overview});

  final TripView trip;
  final TravelOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final warnings = overview.warningsFor(trip.id);
    final row = trip.row;
    return ActionableItem(
      key: ValueKey(row.id),
      semanticLabel: l.travelOpenTrip(trip.displayName(lang)),
      onTap: () => TravelActions.openTrip(context, row.id),
      actions: ItemActions(
        onEdit: () async {
          final action = await TravelActions.editTrip(context, ref, row);
          if (action != null && context.mounted) await showUndoToast(context, action);
        },
        onDuplicate: () => TravelActions.duplicateTrip(context, ref, row),
        onDelete: () => TravelActions.deleteTrip(context, ref, row),
        extra: [
          if (trip.status != TripStatus.done)
            ItemAction(
              icon: Icons.flag_circle_rounded,
              label: l.travelMarkDone,
              tone: ActionTone.success,
              onSelected: () => TravelActions.setStatus(context, ref, row, TripStatus.done),
            ),
          if (trip.manual)
            ItemAction(
              icon: Icons.auto_mode_rounded,
              label: l.travelFollowDates,
              onSelected: () => TravelActions.setStatus(context, ref, row, null),
            ),
        ],
      ),
      onCompleteSwipe: trip.status == TripStatus.done
          ? null
          : () => TravelActions.setStatus(context, ref, row, TripStatus.done),
      completeIcon: Icons.flag_circle_rounded,
      completeLabel: l.travelMarkDone,
      swipeEnabled: trip.phase != TripPhase.past,
      child: TripCard(
        trip: trip,
        now: ref.watch(travelNowProvider),
        cities: ref.watch(travelCitiesProvider),
        warnings: warnings.length,
        worstWarning: warnings.firstOrNull?.conflict,
      ),
    );
  }
}

/// The documents tab: soonest expiry first, with the trips they endanger.
class DocumentsView extends ConsumerWidget {
  const DocumentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final overview = ref.watch(travelOverviewProvider);
    final rows = ref.watch(travelDocumentsProvider).value;
    if (overview == null || rows == null) return const Center(child: OrbitLoader(size: 36));
    if (overview.documents.isEmpty) {
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, 120),
        children: [
          AnimatedEmptyState(
            kind: EmptyStateKind.emptyList,
            title: l.travelDocsEmptyTitle,
            body: l.travelDocsEmptyBody,
            actionLabel: l.travelAddDocument,
            actionIcon: Icons.badge_rounded,
            onAction: () => TravelActions.addDocument(context, ref),
          ),
        ],
      );
    }
    final byId = {for (final r in rows) r.id: r};
    final today = TravelDates.day(ref.watch(travelNowProvider));
    final lang = Localizations.localeOf(context).languageCode;
    final trips = {for (final t in [...overview.current, ...overview.upcoming]) t.id: t};
    return ListView.builder(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 120),
      itemCount: overview.documents.length,
      itemBuilder: (context, i) {
        final d = overview.documents[i];
        final row = byId[d.id];
        if (row == null) return const SizedBox.shrink();
        final warning = overview.warnings.where((w) => w.doc.id == d.id).toList()
          ..sort((a, b) => b.conflict.severity.compareTo(a.conflict.severity));
        final w = warning.firstOrNull;
        return Padding(
          padding: const EdgeInsetsDirectional.only(bottom: Space.s),
          child: StaggerItem(
            index: i,
            child: _DocumentRow(
              row: row,
              facts: d,
              today: today,
              warning: w?.conflict,
              warningTrip: w == null ? null : trips[w.trip.id]?.displayName(lang) ?? w.trip.destination,
            ),
          ),
        );
      },
    );
  }
}

class _DocumentRow extends ConsumerWidget {
  const _DocumentRow({required this.row, required this.facts, required this.today, this.warning, this.warningTrip});

  final TravelDocumentRow row;
  final DocFacts facts;
  final DateTime today;
  final DocumentConflict? warning;
  final String? warningTrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionableItem(
      key: ValueKey(row.id),
      // No semanticLabel: the row's own texts say it once (a title-only label
      // made screen readers read the title twice).
      onTap: () async {
        final action = await TravelActions.editDocument(context, ref, row);
        if (action != null && context.mounted) await showUndoToast(context, action);
      },
      actions: ItemActions(
        onEdit: () async {
          final action = await TravelActions.editDocument(context, ref, row);
          if (action != null && context.mounted) await showUndoToast(context, action);
        },
        onDuplicate: () => TravelActions.duplicateDocument(context, ref, row),
        onSetReminder: () async {
          final action = await TravelActions.pickReminder(context, ref, row);
          if (action != null && context.mounted) await showUndoToast(context, action);
        },
        onDelete: () => TravelActions.deleteDocument(context, ref, row),
      ),
      swipeEnabled: false,
      child: DocumentTile(doc: facts, today: today, warning: warning, warningTrip: warningTrip),
    );
  }
}
