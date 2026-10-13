import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../data/list_providers.dart';
import '../data/list_service.dart';
import '../domain/list_money.dart';
import 'list_texts.dart';
import '../domain/record_list.dart';


UndoableAction _undo(String label, ListUndo undo) => UndoableAction(label: label, undo: undo);

/// Every write the list screens make, with the undo the engine handed
/// back: the sheets, the ticking, the ordering and the deletes.
///
/// Actions that return an [UndoableAction] are called from an
/// [ActionableItem], which shows the undo toast itself; the others show
/// their own. No arithmetic lives here.
abstract final class ListActions {
  static ListService _service(WidgetRef ref) => ref.read(listServiceProvider);

  // ------------------------------------------------------------ lists ----

  /// The sheet for a new list on [host] (or for renaming [row]). Returns
  /// the new list's id when one was created.
  static Future<String?> editList(
    BuildContext context,
    WidgetRef ref, {
    ListHost? host,
    RecordListRow? row,
    String? suggestedName,
  }) async {
    final l = L10n.of(context);
    final service = _service(ref);
    final values = await showEditSheet(
      context,
      title: row == null ? l.listsNewList : l.listsEditListTitle,
      icon: Icons.checklist_rtl_rounded,
      saveLabel: l.actionSave,
      fields: [
        FieldSpec.text(
          'name',
          l.listsNameLabel,
          required: true,
          autofocus: row == null,
          hint: l.listsNameHint,
          maxLength: 80,
        ),
        FieldSpec.multiline('note', l.listsNoteLabel, maxLength: 400),
      ],
      initial: {'name': row?.name ?? suggestedName ?? '', 'note': row?.note},
    );
    if (values == null) return null;
    final name = (values['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final draft = ListDraft(name: name, note: values['note'] as String?);
    if (row != null) {
      final undo = await service.updateList(row, draft);
      if (context.mounted) unawaited(showUndoToast(context, _undo(l.listsListSaved, undo)));
      return row.id;
    }
    if (host == null) return null;
    final currencies = ref.read(listCurrenciesProvider).value ?? ListCurrencies.fallback;
    final hostCurrency = await _hostCurrency(ref, host);
    final (created, undo) = await service.addList(
      host,
      ListDraft(name: name, note: draft.note, currency: currencies.of(hostCurrency)),
    );
    if (context.mounted) unawaited(showUndoToast(context, _undo(l.listsListAdded, undo)));
    return created.id;
  }

  /// Copies a list onto the same host, unticked – how next week's shopping
  /// starts from this week's.
  static Future<UndoableAction?> duplicateList(BuildContext context, WidgetRef ref, RecordListRow row) async {
    final l = L10n.of(context);
    final (_, undo) = await _service(ref).duplicateList(row, name: '${row.name} (${l.listsCopySuffix})');
    return _undo(l.listsListCopied, undo);
  }

  static Future<UndoableAction?> deleteList(BuildContext context, WidgetRef ref, RecordListRow row) async {
    final l = L10n.of(context);
    final undo = await _service(ref).deleteList(row.id);
    Fx.fire(Sfx.delete);
    return _undo(l.listsListDeleted, undo);
  }

  static Future<void> reorderLists(WidgetRef ref, List<String> ids) => _service(ref).reorderLists(ids);

  // ------------------------------------------------------------ lines ----

  /// Adds what he typed in the add row.
  static Future<void> addItem(BuildContext context, WidgetRef ref, String listId, String title) async {
    final text = title.trim();
    if (text.isEmpty) return;
    final l = L10n.of(context);
    final (_, undo) = await _service(ref).addItem(listId, ListItemDraft(title: text));
    Fx.fire(Sfx.tap);
    if (context.mounted) unawaited(showUndoToast(context, _undo(l.listsItemAdded, undo)));
  }

  /// The sheet of one line: his words, how much, his own unit, the price
  /// and a note. Opens empty for a new line.
  static Future<void> editItem(
    BuildContext context,
    WidgetRef ref, {
    required String listId,
    RecordListItemRow? row,
    String? currency,
  }) async {
    final l = L10n.of(context);
    final currencies = ref.read(listCurrenciesProvider).value ?? ListCurrencies.fallback;
    final code = currencies.of(currency);
    final texts = ListTexts.of(context, currencies);
    // With a quantity, the price is the price of one («السعر للكيلو»);
    // the live total underneath says what the line will cost, so the two
    // can never be read the wrong way round.
    final unit = row?.unit?.trim();
    final priceLabel = unit == null || unit.isEmpty ? l.listsPriceLabel : l.listsPricePerUnit(texts.name(unit));
    final values = await showEditSheet(
      context,
      title: row == null ? l.listsNewItemTitle : l.listsEditItemTitle,
      icon: Icons.shopping_basket_rounded,
      saveLabel: l.actionSave,
      preview: (context, live) {
        final total = _lineOf(live).totalMilli;
        if (total == null) return const SizedBox.shrink();
        return Text(
          l.listsLineTotal(texts.money(total, currency)),
          key: const ValueKey('lists.item.total'),
          style: Theme.of(context).textTheme.titleSmall,
        );
      },
      fields: [
        FieldSpec.text('title', l.listsItemLabel, required: true, autofocus: row == null, maxLength: 120),
        FieldSpec.number('quantity', l.listsQuantityLabel, min: 0, decimals: 3),
        FieldSpec.text('unit', l.listsUnitLabel, hint: l.listsUnitHint, maxLength: 24),
        FieldSpec.currency(
          'price',
          priceLabel,
          currencies: [code],
          defaultCurrency: code,
          min: 0,
          decimals: currencies.decimalsOf(code),
        ),
        FieldSpec.multiline('note', l.listsNoteLabel, maxLength: 400),
      ],
      initial: {
        'title': row?.title ?? '',
        'quantity': row?.quantity,
        'unit': row?.unit,
        'price': row?.priceMilli == null ? null : MoneyValue(amountMilli: row!.priceMilli!, currency: code),
        'note': row?.note,
      },
    );
    if (values == null) return;
    final title = (values['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return;
    final quantity = switch (values['quantity']) {
      final num q => q.toDouble(),
      _ => null,
    };
    final draft = ListItemDraft(
      title: title,
      quantity: quantity,
      unit: values['unit'] as String?,
      priceMilli: (values['price'] as MoneyValue?)?.amountMilli,
      note: values['note'] as String?,
    );
    final service = _service(ref);
    if (row == null) {
      final (_, undo) = await service.addItem(listId, draft);
      if (context.mounted) unawaited(showUndoToast(context, _undo(l.listsItemAdded, undo)));
    } else {
      final undo = await service.updateItem(row, draft);
      if (context.mounted) unawaited(showUndoToast(context, _undo(l.listsItemSaved, undo)));
    }
  }

  /// Ticks or un-ticks one line (the shop, the suitcase).
  static Future<UndoableAction?> toggle(BuildContext context, WidgetRef ref, RecordListItemRow row) async {
    final l = L10n.of(context);
    final done = !row.done;
    final undo = await _service(ref).setDone(row, done);
    Fx.fire(done ? Sfx.complete : Sfx.tap);
    return _undo(done ? l.listsTickedToast : l.listsUntickedToast, undo);
  }

  static Future<UndoableAction?> deleteItem(BuildContext context, WidgetRef ref, RecordListItemRow row) async {
    final l = L10n.of(context);
    final undo = await _service(ref).deleteItem(row);
    Fx.fire(Sfx.delete);
    return _undo(l.listsItemDeleted, undo);
  }

  static Future<void> reorderItems(WidgetRef ref, List<String> ids) => _service(ref).reorderItems(ids);

  /// Takes every tick off a list (he starts the shop again).
  static Future<void> untickAll(BuildContext context, WidgetRef ref, String listId) async {
    final l = L10n.of(context);
    final undo = await _service(ref).setAllDone(listId, false);
    Fx.fire(Sfx.tap);
    if (context.mounted) unawaited(showUndoToast(context, _undo(l.listsUntickedAllToast, undo)));
  }

  /// Clears what he has already ticked off the list, keeping the rest.
  static Future<void> clearDone(BuildContext context, WidgetRef ref, String listId) async {
    final l = L10n.of(context);
    final (count, undo) = await _service(ref).deleteDone(listId);
    if (count == 0) return;
    Fx.fire(Sfx.delete);
    if (context.mounted) {
      final label = MadarFormatter.of(context).localizeDigits(l.listsDoneClearedToast(count));
      unawaited(showUndoToast(context, _undo(label, undo)));
    }
  }

  /// The line the sheet's current values describe (for its live total).
  static ListLine _lineOf(Map<String, Object?> values) => ListLine(
    id: '',
    listId: '',
    title: '${values['title'] ?? ''}',
    quantity: switch (values['quantity']) {
      final num q when q > 0 => q.toDouble(),
      _ => null,
    },
    unit: values['unit'] as String?,
    priceMilli: (values['price'] as MoneyValue?)?.amountMilli,
  );

  // ---------------------------------------------------------- helpers ----

  /// A budget envelope's own currency, so a list of it holds prices in the
  /// currency he budgeted in. Null for any other host (the base currency).
  static Future<String?> _hostCurrency(WidgetRef ref, ListHost host) async {
    if (host.table != ListHost.budgetItems) return null;
    final row = await ref.read(repositoriesProvider).budgetItems.byId(host.id);
    return row?.currency;
  }
}
