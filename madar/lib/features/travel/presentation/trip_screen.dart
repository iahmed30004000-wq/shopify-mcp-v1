import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../data/travel_providers.dart';
import '../domain/packing.dart';
import '../domain/travel_overview.dart';
import '../domain/trip_timeline.dart';
import '../travel_texts.dart';
import 'travel_actions.dart';
import 'widgets/destination_prayer_card.dart';
import 'widgets/packing_widgets.dart';
import 'widgets/travel_tiles.dart';
import 'widgets/travel_widgets.dart';

/// One trip: its world and countdown, document warnings, the packing list
/// grouped by category (check, add, drag to reorder or to another
/// category, templates in and out), the destination's prayer times and
/// qibla, and notes.
class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({super.key, required this.tripId, this.animateBackdrop = true});

  final String tripId;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  final _ringKey = GlobalKey();
  final _heroKey = GlobalKey<ActionableItemState>();
  String _addCategory = PackingCategories.misc;

  Future<void> _pickAddCategory(List<TripItemRow> items) async {
    final l = L10n.of(context);
    final target = await showMoveSheet(
      context,
      title: l.travelFieldCategory,
      icon: Icons.category_rounded,
      targets: [
        for (final o in TravelActions.categoryOptions(context, custom: items.map((i) => PackingCategories.of(i.category))))
          MoveTarget(id: o.id, label: o.label, icon: o.icon, isCurrent: o.id == _addCategory),
      ],
    );
    if (target != null && mounted) setState(() => _addCategory = target.id);
  }

  Future<void> _edit(TripRow row) async {
    final action = await TravelActions.editTrip(context, ref, row);
    if (action != null && mounted) unawaited(showUndoToast(context, action));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final view = ref.watch(travelTripViewProvider(widget.tripId));
    final loaded = ref.watch(travelTripViewsProvider) != null;
    // Keep statuses and reminders in step while a trip is open.
    ref.watch(travelStatusSyncProvider);

    if (view == null) {
      return MadarScaffold(
        title: l.travelTitle,
        animateBackdrop: widget.animateBackdrop,
        body: Center(
          child: loaded
              ? AnimatedEmptyState(kind: EmptyStateKind.noResults, title: l.travelTripNotFound, body: '')
              : const OrbitLoader(size: 36),
        ),
      );
    }

    final lang = Localizations.localeOf(context).languageCode;
    final row = view.row;
    final items = ref.watch(travelItemsProvider(widget.tripId)).value ?? const <TripItemRow>[];
    final overview = ref.watch(travelOverviewProvider);
    final warnings = overview?.warningsFor(row.id) ?? const [];
    final groups = PackingLayout.group(items, categoryOf: (i) => i.category, packedOf: (i) => i.packed);
    final entries = PackingLayout.entries(groups);
    final progress = PackingProgress.of(items.map((i) => i.packed));
    final prayerFirst = view.phase == TripPhase.current;

    final prayerCard = Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.l),
      child: DestinationPrayerCard(trip: view, onPickCity: () => _edit(row)),
    );

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActionableItem(
          key: _heroKey,
          semanticLabel: view.displayName(lang),
          onTap: () => _edit(row),
          swipeEnabled: false,
          actions: _tripActions(context, view),
          child: _TripHero(trip: view),
        ),
        if (warnings.isNotEmpty) ...[const SizedBox(height: Space.m), TripWarningsCard(warnings: warnings)],
        if (prayerFirst) prayerCard,
        const SizedBox(height: Space.l),
        PackingSummary(
          progress: progress,
          ringKey: _ringKey,
          onFromTemplate: () => TravelActions.addFromTemplates(context, ref, row.id),
          onSaveAsTemplate: items.isEmpty
              ? null
              : () => TravelActions.saveAsTemplate(context, ref, row.id, suggestedName: view.displayName(lang)),
          onUnpackAll: progress.packed == 0 ? null : () => TravelActions.unpackAll(context, ref, row.id),
        ),
        const SizedBox(height: Space.s),
        PackingAddRow(
          category: _addCategory,
          onPickCategory: () => _pickAddCategory(items),
          onAdd: (body) => unawaited(TravelActions.addItem(ref, row.id, body, category: _addCategory)),
        ),
        if (items.isEmpty) ...[
          const SizedBox(height: Space.s),
          AnimatedEmptyState(
            kind: EmptyStateKind.emptyList,
            title: l.travelPackingEmptyTitle,
            body: l.travelPackingEmptyBody,
            illustrationSize: 96,
            actionLabel: l.travelFromTemplate,
            actionIcon: Icons.playlist_add_rounded,
            onAction: () => TravelActions.addFromTemplates(context, ref, row.id),
          ),
        ],
      ],
    );

    final notes = row.notes?.trim();
    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!prayerFirst) prayerCard,
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: Space.l),
          GlassCard(
            glow: false,
            onTap: () => _edit(row),
            semanticLabel: l.travelFieldNotes,
            padding: const EdgeInsetsDirectional.all(Space.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notes_rounded, size: 18, color: context.tokens.gold),
                    const SizedBox(width: Space.s),
                    Text(l.travelFieldNotes, style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: Space.s),
                Text(notes, style: Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ],
    );

    return MadarScaffold(
      title: view.displayName(lang),
      backdropSeed: 4.2,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        MadarButton.icon(
          icon: Icons.edit_rounded,
          semanticLabel: l.travelEdit,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => _edit(row),
        ),
        MadarButton.icon(
          icon: Icons.more_vert_rounded,
          semanticLabel: l.travelMore,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.tap,
          onPressed: () => _heroKey.currentState?.openMenu(),
        ),
      ],
      body: ReorderableGlassList<PackingEntry<TripItemRow>>(
        items: entries,
        itemKey: (e) => switch (e) {
          PackingHeader<TripItemRow>() => 'h:${e.category}',
          PackingItemEntry<TripItemRow>() => e.item.id,
        },
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 48),
        spacing: Space.xs,
        header: header,
        footer: footer,
        onReorder: (order) {
          final r = PackingLayout.applyReorder(order);
          unawaited(
            ref
                .read(travelServiceProvider)
                .reorderItems(
                  [for (final i in r.order) i.id],
                  recategorize: {for (final e in r.recategorized.entries) e.key.id: e.value},
                ),
          );
        },
        itemBuilder: (context, e, index, handle) => switch (e) {
          PackingHeader<TripItemRow>() => PackingCategoryHeader(category: e.category, progress: e.group.progress),
          PackingItemEntry<TripItemRow>() => _itemRow(context, e.item, handle, items),
        },
      ),
    );
  }

  Widget _itemRow(BuildContext context, TripItemRow item, Widget handle, List<TripItemRow> items) {
    final l = L10n.of(context);
    Future<UndoableAction?> toggle() =>
        TravelActions.togglePacked(context, ref, item, celebrateFrom: _ringKey.currentContext);
    return ActionableItem(
      key: ValueKey(item.id),
      // No semanticLabel: the row's own texts say it once (a title-only label
      // made screen readers read the title twice).
      onTap: () async {
        await toggle();
      },
      onCompleteSwipe: toggle,
      completeIcon: item.packed ? Icons.undo_rounded : Icons.check_rounded,
      completeLabel: item.packed ? l.travelUnpack : l.travelPack,
      actions: ItemActions(
        onEdit: () => TravelActions.editItem(context, ref, item),
        onMove: () => TravelActions.moveItem(context, ref, item, custom: items.map((i) => PackingCategories.of(i.category))),
        onDelete: () => TravelActions.deleteItem(context, ref, item),
      ),
      quickActions: [
        QuickAction(
          icon: Icons.category_rounded,
          label: l.travelMoveToCategory,
          onPressed: () =>
              TravelActions.moveItem(context, ref, item, custom: items.map((i) => PackingCategories.of(i.category))),
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: MaterialLocalizations.of(context).deleteButtonTooltip,
          tone: ActionTone.danger,
          onPressed: () => TravelActions.deleteItem(context, ref, item),
        ),
      ],
      child: PackingItemTile(item: item, dragHandle: handle),
    );
  }

  ItemActions _tripActions(BuildContext context, TripView view) {
    final l = L10n.of(context);
    final row = view.row;
    return ItemActions(
      onEdit: () => _edit(row),
      onDuplicate: () => TravelActions.duplicateTrip(context, ref, row),
      onDelete: () async {
        final action = await TravelActions.deleteTrip(context, ref, row);
        if (context.mounted) unawaited(Navigator.of(context).maybePop());
        return action;
      },
      extra: [
        if (view.status != TripStatus.done)
          ItemAction(
            icon: Icons.flag_circle_rounded,
            label: l.travelMarkDone,
            tone: ActionTone.success,
            onSelected: () => TravelActions.setStatus(context, ref, row, TripStatus.done),
          ),
        if (view.manual)
          ItemAction(
            icon: Icons.auto_mode_rounded,
            label: l.travelFollowDates,
            onSelected: () => TravelActions.setStatus(context, ref, row, null),
          ),
      ],
    );
  }
}

/// The trip's head: its world, name and country, dates, countdown and
/// status.
class _TripHero extends ConsumerWidget {
  const _TripHero({required this.trip});

  final TripView trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = TravelTexts.of(context);
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final cities = ref.watch(travelCitiesProvider);
    final now = ref.watch(travelNowProvider);
    final row = trip.row;
    final country = trip.countryName(lang, cities);
    final length = trip.timeline.lengthDays;
    final palette = tripPalette(row.color);
    return GlassCard(
      glowColor: palette.surface,
      padding: const EdgeInsetsDirectional.all(Space.l),
      child: Row(
        children: [
          TripOrb(color: row.color, phase: trip.phase, size: 64),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.displayName(lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineSmall!.copyWith(height: 1.15),
                ),
                if (country != null && country != trip.displayName(lang))
                  Text(country, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
                const SizedBox(height: Space.xs),
                TravelMetaLine(
                  icon: Icons.event_rounded,
                  text: [
                    tx.dateRange(row.startDate, row.endDate, now: now),
                    if (length != null && length > 1) tx.days(length),
                  ].join(tx.l.commonFactSeparator),
                ),
                const SizedBox(height: Space.s),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    TravelPill(label: tx.countdown(trip.countdown), tone: countdownTone(trip.countdown)),
                    TravelPill(
                      label: tx.status(trip.status),
                      tone: PillTone.neutral,
                      icon: trip.manual ? Icons.push_pin_rounded : Icons.auto_mode_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
