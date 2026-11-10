import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../settings/widgets/settings_widgets.dart';
import '../application/ramadan_providers.dart';
import '../domain/ramadan_year_log.dart';
import '../domain/taraweeh_log.dart';
import 'ramadan_hub_card.dart' show ramadanUndoToast;
import 'ramadan_night_grid.dart';

/// «سجلّ التراويح»: the nights of the month as a grid. One tap on a night
/// logs it (a second un-logs it); the selected night opens its detail - the
/// switch and the optional number of rakaat. Every write has an undo.
class RamadanTaraweehTab extends ConsumerStatefulWidget {
  const RamadanTaraweehTab({super.key});

  @override
  ConsumerState<RamadanTaraweehTab> createState() => _RamadanTaraweehTabState();
}

class _RamadanTaraweehTabState extends ConsumerState<RamadanTaraweehTab> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final texts = ref.watch(ramadanTextsProvider);
    final today = ref.watch(ramadanTodayProvider);
    final year = ref.watch(ramadanLogYearProvider);
    final book = ref.watch(ramadanLogBookProvider).value ?? RamadanLogBook();

    if (year == null) {
      return SettingsSection(
        title: l.ramadanTaraweehSection,
        seed: 0.2,
        children: [
          AnimatedEmptyState(
            key: const ValueKey('ramadan.taraweeh.empty'),
            kind: EmptyStateKind.emptyList,
            title: l.ramadanTaraweehEmptyTitle,
            body: l.ramadanTaraweehEmptyBody,
            illustrationSize: 88,
          ),
        ],
      );
    }

    final log = book.ofOrEmpty(year).taraweeh;
    final length = year == today.hijriYear ? today.monthLength : ref.watch(ramadanCalendarProvider).spanOfYear(year).length;
    final tonight = year == today.hijriYear ? today.tonight : null;
    final selected = (_selected ?? tonight)?.clamp(1, length);
    final entry = selected == null ? null : log.entryOf(selected);
    final service = ref.read(ramadanServiceProvider);
    final prayed = [for (var n = 1; n <= length; n++) if (log.isDone(n)) n].length;

    return SettingsSection(
      title: l.ramadanTaraweehSection,
      subtitle: l.ramadanTaraweehHint,
      seed: 0.2,
      children: [
        SettingsTile(
          key: const ValueKey('ramadan.taraweeh.summary'),
          icon: Icons.mosque_rounded,
          title: l.ramadanTaraweehYear(texts.number(year)),
          subtitle: l.ramadanTaraweehSummary(texts.number(prayed), texts.number(length)),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
          child: RamadanNightGrid(
            nights: [for (var n = 1; n <= length; n++) n],
            isDone: log.isDone,
            selected: selected,
            tonight: tonight,
            onTap: (night) async {
              setState(() => _selected = night);
              final wasDone = log.isDone(night);
              final undo = await service.toggleTaraweeh(year, night);
              if (context.mounted) {
                ramadanUndoToast(context, wasDone ? l.ramadanTaraweehRemovedToast : l.ramadanTaraweehLoggedToast, undo);
              }
            },
          ),
        ),
        if (selected != null) ...[
          SettingsSwitchTile(
            key: const ValueKey('ramadan.taraweeh.done'),
            icon: Icons.check_circle_outline_rounded,
            title: l.ramadanNightPrayedSwitch,
            subtitle: l.ramadanNightTitle(texts.number(selected)),
            value: log.isDone(selected),
            onChanged: (_) async {
              final wasDone = log.isDone(selected);
              final undo = await service.toggleTaraweeh(year, selected);
              if (context.mounted) {
                ramadanUndoToast(context, wasDone ? l.ramadanTaraweehRemovedToast : l.ramadanTaraweehLoggedToast, undo);
              }
            },
          ),
          SettingsTile(
            key: const ValueKey('ramadan.taraweeh.rakaat'),
            icon: Icons.format_list_numbered_rounded,
            title: l.ramadanRakaatLabel,
            subtitle: entry?.rakaat == null ? l.ramadanRakaatOptional : texts.rakaat(entry!.rakaat!),
            navigates: true,
            onTap: () => unawaited(_editRakaat(context, year, selected, entry)),
          ),
        ],
      ],
    );
  }

  Future<void> _editRakaat(BuildContext context, int year, int night, TaraweehEntry? entry) async {
    final l = L10n.of(context);
    final result = await showEditSheet(
      context,
      title: l.ramadanRakaatLabel,
      subtitle: l.ramadanNightTitle(ref.read(ramadanTextsProvider).number(night)),
      icon: Icons.format_list_numbered_rounded,
      fields: [FieldSpec.number('rakaat', l.ramadanRakaatLabel, min: 0, max: 99, hint: l.ramadanRakaatOptional)],
      initial: {'rakaat': entry?.rakaat},
    );
    if (result == null || !context.mounted) return;
    final value = result['rakaat'];
    final undo = await ref.read(ramadanServiceProvider).setRakaat(year, night, value is int ? value : null);
    if (context.mounted) ramadanUndoToast(context, l.ramadanTaraweehRakaatToast, undo);
  }
}
