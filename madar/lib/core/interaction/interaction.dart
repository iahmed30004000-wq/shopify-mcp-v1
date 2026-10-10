/// Madar's universal interaction kit.
///
/// * [ActionableItem] – tap / long-press menu / swipe-right complete /
///   swipe-left quick actions for any row.
/// * [showUndoToast] – glass undo toast with a countdown ring.
/// * [ReorderableGlassList] + [ReorderGrip] – drag-to-reorder lists.
/// * [showEditSheet] (+ [FieldSpec]), [showMoveSheet], [showReminderSheet] –
///   animated glass bottom sheets; nothing requires leaving the screen.
/// * [QuickAddParser], [QuickAddBar], [quickAddHandlerProvider] – natural
///   language quick add.
library;

export 'actionable_item.dart' show ActionableItem, ActionableItemState;
export 'actions.dart';
export 'interaction_math.dart' show reorderItems;
export 'numbers.dart';
export 'quick_add/parser.dart';
export 'quick_add/preview.dart';
export 'quick_add/quick_add_bar.dart';
export 'quick_add/quick_add_handler.dart';
export 'reorderable_glass_list.dart';
export 'sheets/curated.dart';
export 'sheets/edit_sheet.dart' show showEditSheet, EditSheet, EditSheetPreview;
export 'sheets/field_spec.dart';
export 'sheets/move_sheet.dart';
export 'sheets/reminder_rule.dart';
export 'sheets/reminder_sheet.dart';
export 'sheets/sheet.dart' show showInteractionSheet, InteractionSheetFrame, SheetButton;
export 'undo_toast.dart';
