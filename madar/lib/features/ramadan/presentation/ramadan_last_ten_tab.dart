import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../settings/widgets/settings_widgets.dart';
import '../application/ramadan_providers.dart';
import '../domain/last_ten_nights.dart';
import '../domain/qadr_supplication.dart';
import '../domain/ramadan_year_log.dart';
import 'ramadan_hub_card.dart' show ramadanUndoToast;
import 'ramadan_night_grid.dart';

/// «العشر الأواخر»: the nights from the twenty-first to the end of the month
/// with the odd ones starred, a note he can write for each night, and the slot
/// for the supplication of Laylat al-Qadr.
///
/// **The app writes no supplication.** The slot is his: he types the text, its
/// source and its grading; they are stored, editable, and shown back exactly
/// as typed with the source and the grading under the text.
class RamadanLastTenTab extends ConsumerStatefulWidget {
  const RamadanLastTenTab({super.key});

  @override
  ConsumerState<RamadanLastTenTab> createState() => _RamadanLastTenTabState();
}

class _RamadanLastTenTabState extends ConsumerState<RamadanLastTenTab> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final texts = ref.watch(ramadanTextsProvider);
    final today = ref.watch(ramadanTodayProvider);
    final span = ref.watch(ramadanFocusSpanProvider);
    final book = ref.watch(ramadanLogBookProvider).value ?? RamadanLogBook();
    final log = book.ofOrEmpty(span.hijriYear).taraweeh;
    final live = today.inRamadan;
    final nights = LastTenNights.nights(monthLength: span.length);
    final tonight = today.lastTenTonight ? today.tonight : null;
    final selected = live ? (_selected ?? tonight) : null;
    final entry = selected == null ? null : log.entryOf(selected);
    final odd = selected != null && LastTenNights.isOddSought(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: l.ramadanLastTenSection,
          subtitle: l.ramadanLastTenHint,
          seed: 0.35,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
              child: RamadanNightGrid(
                keyPrefix: 'ramadan.lastTen',
                nights: nights,
                isDone: log.isDone,
                selected: selected,
                tonight: tonight,
                markOdd: true,
                onTap: live ? (night) => setState(() => _selected = night) : null,
              ),
            ),
            if (!live) SettingsNote(l.ramadanLastTenEmpty),
            if (selected != null)
              SettingsTile(
                key: const ValueKey('ramadan.lastTen.note'),
                icon: odd ? Icons.star_rounded : Icons.edit_note_rounded,
                iconColor: odd ? context.tokens.gold : null,
                title: l.ramadanNightNoteLabel(texts.number(selected)),
                subtitle: [
                  if (odd) l.ramadanLastTenOdd,
                  entry?.note ?? l.ramadanNightNoteHint,
                ].join(l.commonFactSeparator),
                navigates: true,
                onTap: () => unawaited(_editNote(context, span.hijriYear, selected, entry?.note)),
              ),
          ],
        ),
        _SupplicationSlot(),
      ],
    );
  }

  Future<void> _editNote(BuildContext context, int year, int night, String? current) async {
    final l = L10n.of(context);
    final number = ref.read(ramadanTextsProvider).number(night);
    final result = await showEditSheet(
      context,
      title: l.ramadanNightNoteLabel(number),
      icon: Icons.edit_note_rounded,
      fields: [FieldSpec.multiline('note', l.ramadanNightNoteLabel(number), hint: l.ramadanNightNoteHint, maxLength: 400)],
      initial: {'note': current},
    );
    if (result == null || !context.mounted) return;
    final undo = await ref.read(ramadanServiceProvider).setNightNote(year, night, '${result['note'] ?? ''}');
    if (context.mounted) ramadanUndoToast(context, l.ramadanNightNoteSaved, undo);
  }
}

/// «دعاء ليلة القدر»: empty until he fills it, then his own text with its
/// source and grading under it.
class _SupplicationSlot extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final value = ref.watch(ramadanSupplicationProvider).value;
    return SettingsSection(
      title: l.ramadanQadrTitle,
      seed: 0.45,
      children: [
        if (value == null) ...[
          SettingsTile(
            key: const ValueKey('ramadan.qadr.empty'),
            icon: Icons.edit_note_rounded,
            title: l.ramadanQadrEmpty,
            subtitle: l.ramadanQadrEmptyHint,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.xs, Space.l, Space.m),
            child: MadarButton(
              key: const ValueKey('ramadan.qadr.add'),
              label: l.ramadanQadrAdd,
              icon: Icons.add_rounded,
              expand: true,
              onPressed: () => unawaited(_edit(context, ref, null)),
            ),
          ),
        ] else ...[
          Padding(
            key: const ValueKey('ramadan.qadr.filled'),
            padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Shown exactly as typed.
                SelectableText(
                  value.text,
                  key: const ValueKey('ramadan.qadr.text'),
                  style: text.titleLarge!.copyWith(
                    fontFamily: MadarTypography.naskhFamily,
                    fontSize: 21,
                    height: 1.9,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: Space.s),
                if (value.hasSource)
                  Text(
                    l.ramadanQadrSource(value.source),
                    key: const ValueKey('ramadan.qadr.source'),
                    style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.4),
                  )
                else
                  Text(l.ramadanQadrNoSource, style: text.bodySmall!.copyWith(color: t.warning)),
                if (value.hasGrading)
                  Text(
                    l.ramadanQadrGrading(value.grading),
                    key: const ValueKey('ramadan.qadr.grading'),
                    style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.4),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.xs, Space.l, Space.m),
            child: Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                MadarButton(
                  key: const ValueKey('ramadan.qadr.edit'),
                  label: l.ramadanQadrEdit,
                  icon: Icons.edit_rounded,
                  variant: MadarButtonVariant.secondary,
                  onPressed: () => unawaited(_edit(context, ref, value)),
                ),
                MadarButton(
                  key: const ValueKey('ramadan.qadr.clear'),
                  label: l.ramadanQadrClear,
                  icon: Icons.delete_outline_rounded,
                  variant: MadarButtonVariant.ghost,
                  onPressed: () => unawaited(_clear(context, ref)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, QadrSupplication? current) async {
    final l = L10n.of(context);
    final result = await showEditSheet(
      context,
      title: l.ramadanQadrTitle,
      icon: Icons.edit_note_rounded,
      fields: [
        FieldSpec.multiline('text', l.ramadanQadrTextLabel, required: true, maxLength: 1000),
        FieldSpec.text('source', l.ramadanQadrSourceLabel, maxLength: 200),
        FieldSpec.text('grading', l.ramadanQadrGradingLabel, maxLength: 120),
      ],
      initial: {'text': current?.text, 'source': current?.source, 'grading': current?.grading},
    );
    if (result == null || !context.mounted) return;
    final text = '${result['text'] ?? ''}'.trim();
    if (text.isEmpty) return;
    final undo = await ref
        .read(ramadanServiceProvider)
        .saveSupplication(QadrSupplication(text: text, source: '${result['source'] ?? ''}'.trim(), grading: '${result['grading'] ?? ''}'.trim()));
    if (context.mounted) ramadanUndoToast(context, l.ramadanQadrSavedToast, undo);
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final undo = await ref.read(ramadanServiceProvider).saveSupplication(null);
    if (context.mounted) ramadanUndoToast(context, l.ramadanQadrClearedToast, undo);
  }
}
