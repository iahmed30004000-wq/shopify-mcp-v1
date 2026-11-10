import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/sound/sound_api.dart';
import '../../wird/data/wird_providers.dart';
import '../data/hifz_providers.dart';
import '../data/hifz_service.dart';
import '../domain/hifz_models.dart';
import 'hifz_sheets.dart';

/// Hifz user actions shared by the screens, the card and other features:
/// each writes through [HifzService], plays its sound and haptic, and offers
/// undo.
abstract final class HifzActions {
  static void _toast(BuildContext context, String label, HifzUndo undo) =>
      unawaited(showUndoToast(context, UndoableAction(label: label, undo: undo)));

  /// "What would you like to add?" and the flow for the choice.
  static Future<void> add(BuildContext context, WidgetRef ref) async {
    final kind = await showHifzAddChooser(context);
    if (kind == null || !context.mounted) return;
    switch (kind) {
      case HifzAddKind.ayat:
        await addAyat(context, ref);
      case HifzAddKind.hadith:
        await addHadith(context, ref);
      case HifzAddKind.custom:
        await addCustom(context, ref);
    }
  }

  static Future<void> addAyat(BuildContext context, WidgetRef ref, {AyahRange? initial}) async {
    final picked = await showHifzAyatSheet(context, initial: initial);
    if (picked == null || !context.mounted) return;
    final (range, chunk) = picked;
    final catalog = await ref.read(quranCatalogReadyProvider.future);
    final (added, undo) = await ref
        .read(hifzServiceProvider)
        .addAyahRange(range, ayahCount: catalog.ayahCount, chunkSize: chunk);
    if (!context.mounted || added.isEmpty) return;
    _addedToast(context, added.length, undo);
  }

  /// Adds [range] as chunks with the user's chunk size and shows an undo
  /// toast – the Quran reader's "add to Hifz".
  static Future<void> addAyahRangeToHifz(BuildContext context, WidgetRef ref, AyahRange range) async {
    final result = await ref.read(hifzImportProvider).addAyahRangeToHifz(range);
    if (!context.mounted || result.added.isEmpty) return;
    _addedToast(context, result.added.length, result.undo);
  }

  static void _addedToast(BuildContext context, int count, HifzUndo undo) {
    final l = L10n.of(context);
    Fx.fire(Sfx.complete);
    _toast(context, MadarFormatter.of(context).localizeDigits(l.hifzAdded(count)), undo);
  }

  static Future<void> addHadith(BuildContext context, WidgetRef ref) async {
    final picked = await showHadithPicker(context);
    if (picked == null || picked.isEmpty || !context.mounted) return;
    final collection = await ref.read(hadithCollectionProvider.future);
    final service = ref.read(hifzServiceProvider);
    final undos = <HifzUndo>[];
    for (final e in picked) {
      final r = await service.addHadith(collection, e);
      if (r != null) undos.add(r.$2);
    }
    if (!context.mounted || undos.isEmpty) return;
    _addedToast(context, undos.length, () async {
      for (final u in undos) {
        await u();
      }
    });
  }

  static Future<void> addCustom(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final values = await showEditSheet(
      context,
      title: l.hifzAddCustom,
      subtitle: l.hifzAddCustomHint,
      icon: Icons.edit_note_rounded,
      saveLabel: l.hifzAddButton,
      fields: [
        FieldSpec.text(
          'title',
          l.hifzCustomTitle,
          hint: l.hifzCustomTitleHint,
          icon: Icons.title_rounded,
          maxLength: 80,
        ),
        FieldSpec.multiline(
          'body',
          l.hifzCustomBody,
          required: true,
          icon: Icons.notes_rounded,
          validator: (v, _) => (v as String?)?.trim().isEmpty ?? true ? l.hifzBodyRequired : null,
        ),
        FieldSpec.text('source', l.hifzCustomSource, icon: Icons.menu_book_outlined, maxLength: 120),
      ],
    );
    if (values == null || !context.mounted) return;
    final body = (values['body'] as String?)?.trim() ?? '';
    if (body.isEmpty) return;
    final (_, undo) = await ref
        .read(hifzServiceProvider)
        .addCustom(title: (values['title'] as String?) ?? '', body: body, source: values['source'] as String?);
    if (context.mounted) _addedToast(context, 1, undo);
  }

  /// Edits a custom item's texts or an ayat item's range.
  static Future<void> edit(BuildContext context, WidgetRef ref, HifzCard card) async {
    final l = L10n.of(context);
    final service = ref.read(hifzServiceProvider);
    HifzUndo? undo;
    if (card.kind == HifzKind.custom) {
      final values = await showEditSheet(
        context,
        title: l.hifzEditTitle,
        icon: Icons.edit_note_rounded,
        initial: {'title': card.title ?? '', 'body': card.body ?? '', 'source': card.source ?? ''},
        fields: [
          FieldSpec.text('title', l.hifzCustomTitle, icon: Icons.title_rounded, maxLength: 80),
          FieldSpec.multiline(
            'body',
            l.hifzCustomBody,
            required: true,
            icon: Icons.notes_rounded,
            validator: (v, _) => (v as String?)?.trim().isEmpty ?? true ? l.hifzBodyRequired : null,
          ),
          FieldSpec.text('source', l.hifzCustomSource, icon: Icons.menu_book_outlined, maxLength: 120),
        ],
      );
      if (values == null) return;
      undo = await service.edit(
        card,
        title: (values['title'] as String?) ?? '',
        body: (values['body'] as String?) ?? '',
        source: (values['source'] as String?) ?? '',
      );
    } else if (card.kind == HifzKind.ayat && card.range != null) {
      final catalog = await ref.read(quranCatalogReadyProvider.future);
      if (!context.mounted) return;
      final count = catalog.ayahCount(card.range!.first.surah);
      final values = await showEditSheet(
        context,
        title: l.hifzEditTitle,
        icon: Icons.auto_stories_rounded,
        initial: {'from': card.ayahFrom, 'to': card.ayahTo},
        fields: [
          FieldSpec.number('from', l.hifzFromAyah, required: true, min: 1, max: count, step: 1),
          FieldSpec.number(
            'to',
            l.hifzToAyah,
            required: true,
            min: 1,
            max: count,
            step: 1,
            validator: (v, all) => (v as num? ?? 0) < (all['from'] as num? ?? 0) ? l.hifzToAyah : null,
          ),
        ],
      );
      if (values == null) return;
      final s = card.range!.first.surah;
      undo = await service.edit(
        card,
        range: AyahRange(AyahRef(s, (values['from'] as num).toInt()), AyahRef(s, (values['to'] as num).toInt())),
      );
    }
    if (undo != null && context.mounted) _toast(context, l.hifzSavedToast, undo);
  }

  static Future<UndoableAction> delete(BuildContext context, WidgetRef ref, HifzCard card) async {
    final l = L10n.of(context);
    return UndoableAction(label: l.hifzDeletedToast, undo: await ref.read(hifzServiceProvider).delete(card));
  }

  static Future<UndoableAction> toggleSuspend(BuildContext context, WidgetRef ref, HifzCard card) async {
    final l = L10n.of(context);
    Fx.fire(card.suspended ? Sfx.toggleOn : Sfx.toggleOff);
    final undo = await ref.read(hifzServiceProvider).setSuspended(card, !card.suspended);
    return UndoableAction(label: card.suspended ? l.hifzUnsuspendedToast : l.hifzSuspendedToast, undo: undo);
  }

  static Future<UndoableAction> reset(BuildContext context, WidgetRef ref, HifzCard card) async {
    final l = L10n.of(context);
    Fx.fire(Sfx.undo);
    return UndoableAction(label: l.hifzResetToast, undo: await ref.read(hifzServiceProvider).resetProgress(card));
  }
}
