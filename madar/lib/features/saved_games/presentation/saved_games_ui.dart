import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../data/saved_games_providers.dart';
import '../data/saved_web_games_store.dart';
import '../domain/saved_web_game.dart';
import 'game_editor_sheet.dart';
import 'game_player_screen.dart';

/// The link pattern shown in the empty state (a pattern, not a real game),
/// isolated left-to-right inside Arabic text and kept in one piece (word
/// joiners) when the line wraps.
final String savedGamesLinkExample = BidiIsolate.ltr('claude.ai/\u2060public/\u2060artifacts/\u2060…');

/// "Last played …" / "New" for [game] at [now].
String lastPlayedLabel(L10n l, MadarFormatter f, SavedWebGame game, DateTime now) {
  final at = game.lastPlayedAt;
  if (at == null) return l.savedGamesNew;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return l.savedGamesLastPlayedToday;
  if (days == 1) return l.savedGamesLastPlayedYesterday;
  if (days < 30) return f.localizeDigits(l.savedGamesLastPlayedDays(days));
  return l.savedGamesLastPlayedOn(f.formatDate(at, style: MadarDateStyle.dayMonth));
}

String playCountLabel(L10n l, MadarFormatter f, SavedWebGame game) =>
    f.localizeDigits(l.savedGamesPlayCount(game.playCount));

/// A Madar glass confirmation sheet; true when the user confirmed.
Future<bool> showGameConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  IconData icon = Icons.help_outline_rounded,
  bool danger = false,
}) async {
  final ok = await showInteractionSheet<bool>(
    context,
    builder: (context) {
      final t = context.tokens;
      return InteractionSheetFrame(
        title: title,
        icon: icon,
        body: Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textSecondary)),
        footer: Row(
          children: [
            Expanded(
              child: SheetButton(label: cancelLabel, sfx: Sfx.back, onPressed: () => Navigator.of(context).pop(false)),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: SheetButton(
                label: confirmLabel,
                primary: true,
                tone: danger ? t.danger : null,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      );
    },
  );
  return ok ?? false;
}

/// A short message in a floating snack bar (the undo toast is for undo).
void showGameNote(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
}

/// The actions shared by the screen, the shelf and the player.
abstract final class SavedGamesActions {
  /// Opens the add sheet (optionally pre-filled with shared text) and saves
  /// the result. Returns the added game.
  static Future<SavedWebGame?> add(BuildContext context, WidgetRef ref, {String? initialText}) async {
    final l = L10n.of(context);
    final store = ref.read(savedWebGamesStoreProvider);
    final state = await store.read();
    if (!context.mounted) return null;
    if (state.isFull) {
      Fx.fire(Sfx.error);
      showGameNote(context, l.savedGamesFull(context.formatter.formatInt(SavedGamesLimits.maxGames)));
      return null;
    }
    final draft = await showGameEditorSheet(context, initialText: initialText);
    if (draft == null) return null;
    final result = await store.add(draft);
    if (!context.mounted) return result.game;
    switch (result.status) {
      case AddGameStatus.added:
        Fx.fire(Sfx.complete);
        showGameNote(context, l.savedGamesAdded(BidiIsolate.isolate(draft.title)));
      case AddGameStatus.duplicate:
        Fx.fire(Sfx.error);
        showGameNote(context, l.savedGamesUrlDuplicate(BidiIsolate.isolate(result.game?.title ?? draft.title)));
      case AddGameStatus.full:
        Fx.fire(Sfx.error);
        showGameNote(context, l.savedGamesFull(context.formatter.formatInt(SavedGamesLimits.maxGames)));
    }
    return result.status == AddGameStatus.added ? result.game : null;
  }

  static Future<void> edit(BuildContext context, WidgetRef ref, SavedWebGame game) async {
    final l = L10n.of(context);
    // Read before awaiting: the calling widget may be gone afterwards.
    final store = ref.read(savedWebGamesStoreProvider);
    final edited = await showGameEditorSheet(context, existing: game);
    if (edited == null) return;
    await store.update(edited);
    if (context.mounted) showGameNote(context, l.savedGamesUpdated);
  }

  /// Deletes with the universal undo toast (Madar never asks "are you
  /// sure?").
  static Future<UndoableAction?> delete(BuildContext context, WidgetRef ref, SavedWebGame game) async {
    final l = L10n.of(context);
    final store = ref.read(savedWebGamesStoreProvider);
    final removed = await store.remove(game.id);
    if (removed == null) return null;
    return UndoableAction(
      label: l.savedGamesDeleted(BidiIsolate.isolate(game.title)),
      undo: () => store.restore(removed),
    );
  }

  /// Deletes and shows the undo toast (for callers outside [ActionableItem]).
  static Future<void> deleteWithToast(BuildContext context, WidgetRef ref, SavedWebGame game) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    Fx.fire(Sfx.delete);
    final action = await delete(context, ref, game);
    if (action != null && overlay != null && overlay.mounted) {
      unawaited(UndoToast.show(overlay, action));
    }
  }

  /// Asks, then marks the game's site data to be cleared on its next open.
  static Future<void> scheduleClearData(BuildContext context, WidgetRef ref, SavedWebGame game) async {
    final l = L10n.of(context);
    final store = ref.read(savedWebGamesStoreProvider);
    final ok = await showGameConfirm(
      context,
      title: l.savedGamesClearDataTitle(BidiIsolate.isolate(game.title)),
      body: l.savedGamesClearDataBody,
      confirmLabel: l.savedGamesConfirmClear,
      cancelLabel: l.savedGamesCancel,
      icon: Icons.cleaning_services_rounded,
      danger: true,
    );
    if (!ok) return;
    await store.setClearDataPending(game.id, true);
    if (context.mounted) showGameNote(context, l.savedGamesClearDataScheduled);
  }

  static Future<void> clearAllData(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final cleaner = ref.read(gameWebDataCleanerProvider);
    final ok = await showGameConfirm(
      context,
      title: l.savedGamesClearAllTitle,
      body: l.savedGamesClearAllBody,
      confirmLabel: l.savedGamesConfirmClear,
      cancelLabel: l.savedGamesCancel,
      icon: Icons.cleaning_services_rounded,
      danger: true,
    );
    if (!ok) return;
    final done = await cleaner.clearAll();
    if (!context.mounted) return;
    Fx.fire(done ? Sfx.complete : Sfx.error);
    showGameNote(context, done ? l.savedGamesClearAllDone : l.savedGamesClearFailed);
  }

  /// Opens [game]'s link in the user's browser.
  static Future<void> openExternally(BuildContext context, WidgetRef ref, SavedWebGame game) async {
    final l = L10n.of(context);
    final ok = await ref.read(gameLinkOpenerProvider).openExternally(game.url);
    if (!ok && context.mounted) showGameNote(context, l.savedGamesExternalFailed);
  }

  /// Plays [game] full screen (root navigator, above the app's bars).
  static Future<void> play(BuildContext context, SavedWebGame game) {
    return Navigator.of(context, rootNavigator: true).push(SavedGamePlayerScreen.route(game));
  }

  /// The long-press menu of a game.
  static ItemActions itemActions(BuildContext context, WidgetRef ref, SavedWebGame game) {
    final l = L10n.of(context);
    return ItemActions(
      onEdit: () => edit(context, ref, game),
      onDelete: () => delete(context, ref, game),
      extra: [
        ItemAction(
          icon: Icons.open_in_new_rounded,
          label: l.savedGamesOpenExternal,
          onSelected: () async {
            await openExternally(context, ref, game);
            return null;
          },
        ),
        ItemAction(
          icon: Icons.cleaning_services_rounded,
          label: l.savedGamesClearData,
          tone: ActionTone.warning,
          onSelected: () async {
            await scheduleClearData(context, ref, game);
            return null;
          },
        ),
      ],
    );
  }
}
