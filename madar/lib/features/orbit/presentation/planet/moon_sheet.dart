import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/design/themes.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/orbit_providers.dart';
import '../../domain/neglect_text.dart';
import '../../domain/orbit_moons.dart';
import '../../domain/planet_scores.dart';
import '../../domain/scene_snapshot.dart';
import 'planet_modules.dart';

/// The record behind a data moon, read for its sheet (pure data).
@immutable
class MoonRecord {
  const MoonRecord({required this.name, this.lastContact, this.startDate});

  /// The record's own name (a person, a wallet, a board, a trip's
  /// destination, a module).
  final String name;

  /// A person's last contact.
  final DateTime? lastContact;

  /// A trip's start date.
  final DateTime? startDate;
}

/// Reads and edits the records behind data moons (`people`, `wallets`,
/// `boards`, `trips`, `custom_modules`) – every moon opens a real item.
class MoonRecords {
  MoonRecords(this.repos, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() _clock;

  /// Activity kind and table of "in touch today" (a person's moon) – the
  /// same as a contact logged from the quick-add bar.
  static const contactKind = 'family.contact', contactTable = 'contact_logs';

  /// Column holding the record's name in [refTable].
  static String nameColumn(String refTable) => refTable == 'trips' ? 'destination' : 'name';

  /// The record [refTable] / [refId], or null when it is gone.
  Future<MoonRecord?> read(String refTable, String refId) async {
    switch (refTable) {
      case 'people':
        final p = await repos.people.byId(refId);
        return p == null ? null : MoonRecord(name: p.name, lastContact: p.lastContact);
      case 'wallets':
        final w = await repos.wallets.byId(refId);
        return w == null ? null : MoonRecord(name: w.name);
      case 'boards':
        final b = await repos.boards.byId(refId);
        return b == null ? null : MoonRecord(name: b.name);
      case 'trips':
        final t = await repos.trips.byId(refId);
        return t == null ? null : MoonRecord(name: t.destination, startDate: t.startDate);
      case 'custom_modules':
        final m = await repos.customModules.byId(refId);
        return m == null ? null : MoonRecord(name: m.name);
    }
    return null;
  }

  /// Renames the record; the returned undo restores the old name.
  Future<Future<void> Function()> rename(String refTable, String refId, String name) async {
    final before = await read(refTable, refId);
    final column = nameColumn(refTable);
    Future<void> set(String value) => switch (refTable) {
      'people' => repos.people.setColumn(refId, column, value),
      'wallets' => repos.wallets.setColumn(refId, column, value),
      'boards' => repos.boards.setColumn(refId, column, value),
      'trips' => repos.trips.setColumn(refId, column, value),
      _ => repos.customModules.setColumn(refId, column, value),
    };
    await set(name);
    return () async {
      if (before != null) await set(before.name);
    };
  }

  /// A person's moon: "in touch today" – logs a contact (as the quick-add
  /// bar does: a contact-log row, the person's last contact, a Family
  /// completion so the world pulses). The undo removes exactly that contact
  /// and restores the previous last-contact date.
  Future<Future<void> Function()> logContact(
    String refId, {
    required String planetKey,
    required Future<void> Function(String planetKey, String kind, String refTable, String refId, DateTime at) record,
  }) async {
    final person = await repos.people.byId(refId);
    final previous = person?.lastContact;
    final now = _clock();
    final log = await repos.db.transaction(() async {
      final log = await repos.contactLogs.insert(ContactLogsCompanion.insert(personId: refId, at: now));
      if (previous == null || previous.isBefore(now)) {
        await repos.people.update(PeopleCompanion(id: Value(refId), lastContact: Value(now)));
      }
      return log;
    });
    await record(planetKey, contactKind, contactTable, log.id, now);
    return () => repos.db.transaction(() async {
      await repos.people.update(PeopleCompanion(id: Value(refId), lastContact: Value(previous)));
      await repos.contactLogs.delete(log.id);
      await repos.activity.removeFor(refTable: contactTable, refId: log.id, kind: contactKind);
    });
  }
}

/// The moon records service of the running app.
final moonRecordsProvider = Provider<MoonRecords>(
  (ref) => MoonRecords(ref.watch(repositoriesProvider), clock: ref.watch(orbitClockProvider)),
);

/// Opens [moon]'s record: what it is and which world it circles, how fresh
/// it is, the concrete reasons it needs care, and what can be done right
/// here – rename it, and for a person, log that you were in touch today
/// (the Family world pulses). Every change can be undone.
Future<void> showMoonSheet(BuildContext context, WidgetRef ref, OrbitMoon moon) async {
  final records = ref.read(moonRecordsProvider);
  final record = await records.read(moon.refTable, moon.refId);
  if (!context.mounted) return;
  final snapshot = ref.read(sceneSnapshotProvider).value;
  final planet = snapshot?.planet(moon.planetKey);
  final action = await showInteractionSheet<_MoonAction>(
    context,
    builder: (_) => _MoonSheet(moon: moon, planet: planet, record: record),
  );
  if (action == null || !context.mounted) return;
  final l = L10n.of(context);
  switch (action) {
    case _MoonAction.inTouch:
      final hub = ref.read(orbitPulseHubProvider);
      final undo = await records.logContact(
        moon.refId,
        planetKey: moon.planetKey,
        record: (planetKey, kind, refTable, refId, at) =>
            hub.recordCompletion(planetKey, kind, refTable, refId, at: at),
      );
      if (!context.mounted) return;
      unawaited(showUndoToast(context, UndoableAction(label: l.orbitUiMoonInTouchLogged(moon.label), undo: undo)));
    case _MoonAction.rename:
      final values = await showEditSheet(
        context,
        title: l.orbitUiMoonRename,
        subtitle: record?.name ?? moon.label,
        icon: Icons.drive_file_rename_outline_rounded,
        fields: [FieldSpec.text('name', l.orbitUiFieldName, required: true, maxLength: 60, autofocus: true)],
        initial: {'name': record?.name ?? moon.label},
      );
      final name = (values?['name'] as String?)?.trim();
      if (name == null || name.isEmpty || name == (record?.name ?? moon.label) || !context.mounted) return;
      final undo = await records.rename(moon.refTable, moon.refId, name);
      if (!context.mounted) return;
      unawaited(showUndoToast(context, UndoableAction(label: l.orbitUiMoonRenamed, undo: undo)));
  }
}

enum _MoonAction { inTouch, rename }

class _MoonSheet extends StatelessWidget {
  const _MoonSheet({required this.moon, required this.planet, required this.record});

  final OrbitMoon moon;
  final OrbitPlanet? planet;
  final MoonRecord? record;

  static IconData iconOf(OrbitMoon m) => switch (m.refTable) {
    'people' => Icons.person_rounded,
    'wallets' => Icons.account_balance_wallet_rounded,
    'boards' => Icons.view_kanban_rounded,
    'trips' => Icons.flight_takeoff_rounded,
    _ => Icons.auto_awesome_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final kind = PlanetModules.moonKindLabel(l, moon);
    final reasons = <NeglectReason>[
      for (final r in planet?.score.reasons ?? const <NeglectReason>[])
        if (r.refTable == moon.refTable && r.refId == moon.refId) r,
    ];
    final palette = PlanetPalettes.fromColor(moon.color);
    void pick(_MoonAction a) => Navigator.of(context).pop(a);
    final details = <String>[
      if (moon.refTable == 'people')
        l.orbitUiMoonLastContact(
          record?.lastContact == null
              ? l.orbitUiMoonNever
              : fmt.formatDate(record!.lastContact!, style: MadarDateStyle.dayMonth),
        ),
      if (moon.refTable == 'trips' && record?.startDate != null)
        l.orbitUiMoonTripStarts(fmt.formatDate(record!.startDate!, style: MadarDateStyle.dayMonth)),
    ];
    return InteractionSheetFrame(
      title: record?.name ?? moon.label,
      subtitle: planet == null ? kind : l.orbitUiMoonOf(kind, fmt.isolate(planet!.name)),
      icon: iconOf(moon),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.4),
                    colors: [palette.glow, palette.surface, palette.deep],
                    stops: const [0, 0.55, 1],
                  ),
                  boxShadow: [BoxShadow(color: palette.surface.withValues(alpha: 0.45), blurRadius: 12)],
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text(
                  l.orbitUiMoonFreshness(fmt.formatPercent(moon.score)),
                  style: text.titleSmall!.copyWith(color: t.textPrimary),
                ),
              ),
            ],
          ),
          for (final d in details) ...[
            const SizedBox(height: Space.s),
            Text(d, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
          ],
          const SizedBox(height: Space.l),
          if (reasons.isEmpty)
            Text(l.orbitUiReasonsNone, style: text.bodyMedium!.copyWith(color: t.textSecondary))
          else
            for (final r in reasons.take(4))
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: r.severity >= 0.6 ? t.danger : t.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Text(neglectReasonText(l, r, fmt), style: text.bodyMedium!.copyWith(color: t.textPrimary)),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: Space.m),
          if (moon.refTable == 'people') ...[
            SheetButton(
              label: l.orbitUiMoonInTouch,
              icon: Icons.favorite_rounded,
              primary: true,
              sfx: Sfx.complete,
              onPressed: () => pick(_MoonAction.inTouch),
            ),
            const SizedBox(height: Space.s),
          ],
          SheetButton(
            label: l.orbitUiMoonRename,
            icon: Icons.drive_file_rename_outline_rounded,
            onPressed: () => pick(_MoonAction.rename),
          ),
        ],
      ),
    );
  }
}
