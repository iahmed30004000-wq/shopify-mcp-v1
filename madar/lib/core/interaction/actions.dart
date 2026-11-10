import 'dart:async';

import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// Something that can be reverted from the undo toast.
@immutable
class UndoableAction {
  const UndoableAction({required this.label, required this.undo});

  /// What happened, e.g. "Deleted" / "تم الحذف" – shown in the toast.
  final String label;

  /// Reverts the change.
  final Future<void> Function() undo;
}

/// Semantic colour of an action, resolved against [MadarTokens] so actions
/// never carry literal colours.
enum ActionTone {
  neutral,
  accent,
  success,
  warning,
  danger,
  info;

  Color resolve(MadarTokens t) => switch (this) {
    ActionTone.neutral => t.textPrimary,
    ActionTone.accent => t.accent,
    ActionTone.success => t.success,
    ActionTone.warning => t.warning,
    ActionTone.danger => t.danger,
    ActionTone.info => t.info,
  };
}

/// An extra entry of the long-press context menu.
@immutable
class ItemAction {
  const ItemAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.tone = ActionTone.neutral,
    this.enabled = true,
  });

  final IconData icon;
  final String label;

  /// Runs after the menu has closed. Returning an [UndoableAction] shows the
  /// undo toast.
  final FutureOr<UndoableAction?> Function() onSelected;
  final ActionTone tone;
  final bool enabled;
}

/// The universal item actions offered by the long-press menu. Only non-null
/// callbacks appear in the menu.
///
/// Callbacks returning an [UndoableAction] (duplicate, move, delete) get an
/// undo toast automatically. Callbacks run after the menu has closed, with the
/// item still mounted, so they can open sheets from the item's context.
@immutable
class ItemActions {
  const ItemActions({
    this.onEdit,
    this.onDuplicate,
    this.onMove,
    this.onSetReminder,
    this.onDelete,
    this.extra = const [],
  });

  final FutureOr<void> Function()? onEdit;
  final FutureOr<UndoableAction?> Function()? onDuplicate;
  final FutureOr<UndoableAction?> Function()? onMove;
  final FutureOr<void> Function()? onSetReminder;

  /// Deletes the item. The row dissolves first; return an [UndoableAction]
  /// to offer undo (recommended – Madar never asks "are you sure?").
  final FutureOr<UndoableAction?> Function()? onDelete;

  /// Feature-specific entries, shown after the standard ones and before
  /// Delete.
  final List<ItemAction> extra;

  static const none = ItemActions();

  bool get isEmpty =>
      onEdit == null &&
      onDuplicate == null &&
      onMove == null &&
      onSetReminder == null &&
      onDelete == null &&
      extra.isEmpty;
}

/// A button in the tray revealed by swiping an item to the LEFT.
@immutable
class QuickAction {
  const QuickAction({required this.icon, required this.label, required this.onPressed, this.tone = ActionTone.accent});

  final IconData icon;
  final String label;
  final FutureOr<UndoableAction?> Function() onPressed;
  final ActionTone tone;
}
