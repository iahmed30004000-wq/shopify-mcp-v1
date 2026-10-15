/// Every decision the daily chat makes, each with the app's undo toast.
///
/// This is deliberately the shape of Part 3's [PlanActions], because he
/// already knows and trusts that flow:
///
/// * **one piece at a time.** Every method takes one [DayChatPiece]; there
///   is no "file everything" and no loop over a reading that would be one
///   in disguise. His tap on that card is the only thing that writes;
/// * **nothing refused is ever offered.** [file] asks the engine, which
///   throws [DayChatRefused] for a piece that still needs him; the card
///   draws no «سجّلها» for such a piece, and if one ever slipped through the
///   engine still says no and the chat says why;
/// * **an edit changes a value, never the words.** The sheets in
///   `day_chat_edit.dart` hand back a fact of the same class, so the health
///   guard's verdict on his sentence cannot be edited away;
/// * **nothing leaves the phone.** The only door out is [askAi], which is
///   Part 3's own export sheet with his one sentence as the question – his
///   tap, his choice of what goes with it, and still nothing sent until he
///   shares or copies it himself.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../../ai_bridge/presentation/ai_bridge_export_sheet.dart' show showAiBridgeExportSheet;
import '../../custom_modules/data/custom_modules_providers.dart';
import '../data/day_chat_providers.dart';
import '../data/day_chat_service.dart';
import '../domain/day_chat_piece.dart';
import 'day_chat_edit.dart';
import 'day_chat_texts.dart';

/// What [DayChatActions.file] did, so the screen can drop an edit it was
/// carrying once it is stored.
enum DayChatFiled { written, alreadyThere, refused }

abstract final class DayChatActions {
  static UndoableAction _undo(String label, DayChatUndo undo) => UndoableAction(label: label, undo: undo);

  /// The one line a card says about itself, used in every toast.
  static String _what(BuildContext context, DayChatPiece piece) => DayChatTexts.of(context).title(piece);

  // --------------------------------------------------------------- decide --

  /// Writes **this one** piece into its own feature and shows the undo
  /// toast. A piece that still needs him is refused, loudly and in his
  /// words – the card never offers it in the first place.
  static Future<DayChatFiled> file(
    BuildContext context,
    WidgetRef ref,
    DayChatPiece piece, {
    required DateTime day,
  }) async {
    final l = L10n.of(context);
    final what = _what(context, piece);
    if (!piece.canApply) {
      Fx.fire(Sfx.error);
      _say(context, l.dayChatCannotFileYet);
      return DayChatFiled.refused;
    }
    final DayChatOutcome outcome;
    try {
      outcome = await ref.read(dayChatServiceProvider).apply(piece, day: day);
    } on DayChatRefused {
      Fx.fire(Sfx.error);
      if (context.mounted) _say(context, l.dayChatCannotFileYet);
      return DayChatFiled.refused;
    }
    if (!context.mounted) return DayChatFiled.written;
    if (outcome.alreadyApplied) {
      Fx.fire(Sfx.tap);
      _say(context, l.dayChatAlreadyFiled);
      return DayChatFiled.alreadyThere;
    }
    Fx.fire(Sfx.complete);
    unawaited(showUndoToast(context, _undo(l.dayChatFiledToast(what), outcome.undo)));
    return DayChatFiled.written;
  }

  /// He said no to this one piece. Writes nothing of his, and is undoable.
  static Future<void> reject(
    BuildContext context,
    WidgetRef ref,
    DayChatPiece piece, {
    required DateTime day,
  }) async {
    final l = L10n.of(context);
    final what = _what(context, piece);
    final DayChatUndo undo;
    try {
      undo = await ref.read(dayChatServiceProvider).reject(piece, day: day);
    } on DayChatRefused {
      Fx.fire(Sfx.error);
      return;
    }
    if (!context.mounted) return;
    Fx.fire(Sfx.tap);
    unawaited(showUndoToast(context, _undo(l.dayChatRejectedToast(what), undo)));
  }

  // ----------------------------------------------------------------- edit --

  /// Lets him correct this one piece and gives back the piece with that
  /// change on it. Nothing is written: the card carries the edit until he
  /// taps «سجّلها».
  static Future<DayChatPiece?> edit(BuildContext context, WidgetRef ref, DayChatPiece piece) async {
    final DayChatEditResult? result;
    try {
      result = await showDayChatEditSheet(context, ref, piece);
    } on DayChatNoTrackers {
      // He has no tracker at all: there is nothing to pick, and the card
      // already offers the only answer («اعمللي متابعة جديدة من هاي»).
      Fx.fire(Sfx.error);
      if (context.mounted) _say(context, L10n.of(context).dayChatNoModulesYet);
      return null;
    }
    if (result == null || !context.mounted) return null;
    final edited = piece.copyWith(
      kind: result.kind,
      fact: result.fact,
      // Everything the reader could not resolve is settled by the sheet,
      // which validated it – that is the whole contract of `applyEdited`.
      gaps: const [],
      edited: true,
    );
    Fx.fire(Sfx.complete);
    return edited;
  }

  // ------------------------------------------------- the unread sentence --

  /// «خليها ملاحظة» – his words kept exactly as he typed them, filed as his
  /// own note and nothing else.
  static Future<DayChatFiled> keepAsNote(
    BuildContext context,
    WidgetRef ref,
    DayChatPiece piece, {
    required DateTime day,
  }) {
    final fact = piece.fact;
    final text = switch (fact) {
      UnreadFact(:final text) => text,
      NoteFact(:final text) => text,
      _ => piece.text,
    };
    final asNote = piece.copyWith(
      kind: DayChatKind.note,
      fact: NoteFact(text: text.trim(), day: day, planetKey: piece.planetKey),
      gaps: const [],
      edited: true,
    );
    return file(context, ref, asNote, day: day);
  }

  /// «صحّحها» – he says it another way, and the chat reads the new words as
  /// a line of its own. The sentence he replaced is settled as refused, so
  /// the chat does not keep asking about it.
  ///
  /// Returns the text he sent, or null when he left it as it was.
  static Future<String?> reword(
    BuildContext context,
    WidgetRef ref,
    DayChatPiece piece, {
    required DateTime day,
  }) async {
    final text = await showDayChatRewordSheet(context, piece);
    if (text == null || !context.mounted) return null;
    final service = ref.read(dayChatServiceProvider);
    await service.reject(piece, day: day);
    final reading = await service.read(text, day: day);
    await service.remember(reading);
    if (context.mounted) Fx.fire(Sfx.complete);
    return text;
  }

  /// «اسأل الذكاء» – **his** tap, and nothing before it: Part 3's export
  /// sheet opens with this one sentence as his question, he chooses what
  /// data goes with it, and he is the one who copies or shares it. Madar
  /// opens no connection of its own here or anywhere else in the chat.
  static Future<void> askAi(BuildContext context, DayChatPiece piece) async {
    Fx.fire(Sfx.sheetOpen);
    await showAiBridgeExportSheet(context, initialAsk: piece.text);
  }

  // ------------------------------------------- a number with no tracker --

  /// «اعمللي متابعة جديدة من هاي» – builds the tracker the number was
  /// waiting for, then files the number into it.
  ///
  /// One tap, **one** undo: taking it back removes the reading and the
  /// tracker that was born for it, in that order. Two toasts for one
  /// decision would make him undo the same thing twice.
  static Future<DayChatFiled> makeTracker(
    BuildContext context,
    WidgetRef ref,
    DayChatPiece piece, {
    required DateTime day,
  }) async {
    final fact = piece.fact;
    if (fact is! ModuleFact) return DayChatFiled.refused;
    final draft = await showDayChatTrackerSheet(context, fact);
    if (draft == null || !context.mounted) return DayChatFiled.refused;
    final l = L10n.of(context);
    final modules = ref.read(customModulesServiceProvider);
    final module = await modules.createModule(draft.definition());
    final field = module.fields.first;
    if (!context.mounted) {
      await modules.deleteModule(module.id);
      return DayChatFiled.refused;
    }
    final filled = piece.copyWith(
      kind: DayChatKind.moduleEntry,
      fact: ModuleFact(
        moduleId: module.id,
        moduleName: module.name,
        at: fact.at,
        fieldId: field.id,
        fieldLabel: field.label,
        value: fact.value,
      ),
      gaps: const [],
      edited: true,
    );
    final DayChatOutcome outcome;
    try {
      outcome = await ref.read(dayChatServiceProvider).apply(filled, day: day);
    } on DayChatRefused {
      // The tracker was born for this number: if the number did not land,
      // the tracker must not stay behind on its own.
      await modules.deleteModule(module.id);
      Fx.fire(Sfx.error);
      if (context.mounted) _say(context, l.dayChatCannotFileYet);
      return DayChatFiled.refused;
    }
    if (!context.mounted) return DayChatFiled.written;
    Fx.fire(Sfx.complete);
    unawaited(
      showUndoToast(
        context,
        _undo(l.dayChatTrackerToast(DayChatTexts.of(context).name(module.name)), () async {
          await outcome.undo();
          await modules.deleteModule(module.id);
        }),
      ),
    );
    return outcome.alreadyApplied ? DayChatFiled.alreadyThere : DayChatFiled.written;
  }

  // -------------------------------------------------------------- notices --

  /// One short, spoken-out line for something that did **not** happen (a
  /// second tap on a filed card, a refusal). Not an undo – there is nothing
  /// to take back – so it carries no action.
  static void _say(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
