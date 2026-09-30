import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/interaction/sheets/field_inputs.dart' show PickerButton, kitInputDecoration;
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/budget_providers.dart';
import '../data/budget_repository.dart';
import '../domain/budget_plan.dart';
import '../domain/budget_search.dart';
import '../domain/budget_spending.dart';
import 'budget_format.dart';
import 'widgets/budget_widgets.dart';

/// The answer of [showBudgetPicker]: the chosen item, or null for "no
/// item" (or "top level" when picking a parent). A dismissed picker returns
/// no [BudgetPick] at all.
@immutable
class BudgetPick {
  const BudgetPick(this.id);

  final String? id;

  @override
  bool operator ==(Object other) => other is BudgetPick && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Opens the budget tree picker as a glass sheet (search, indented tree,
/// what is left of each item this month). Used by the ledger for a
/// transaction's budget item and by the item editor for the parent.
///
/// * [selectedId] is marked as the current choice.
/// * [allowNone] adds a first row that picks no item ([noneLabel], by
///   default "No budget item").
/// * [disabledIds] are shown but cannot be picked (e.g. an item's own
///   subtree when choosing its parent).
Future<BudgetPick?> showBudgetPicker(
  BuildContext context, {
  String? selectedId,
  bool allowNone = true,
  String? title,
  String? noneLabel,
  IconData? noneIcon,
  Set<String> disabledIds = const {},
  bool showRemaining = true,
}) {
  return showInteractionSheet<BudgetPick>(
    context,
    builder: (_) => BudgetPicker(
      selectedId: selectedId,
      allowNone: allowNone,
      title: title,
      noneLabel: noneLabel,
      noneIcon: noneIcon,
      disabledIds: disabledIds,
      showRemaining: showRemaining,
      onPicked: (pick) => Navigator.of(context, rootNavigator: true).pop(pick),
    ),
  );
}

/// The picker sheet's content (see [showBudgetPicker]). Reads the budget
/// from the providers; [onPicked] receives the choice.
class BudgetPicker extends ConsumerStatefulWidget {
  const BudgetPicker({
    super.key,
    required this.onPicked,
    this.selectedId,
    this.allowNone = true,
    this.title,
    this.noneLabel,
    this.noneIcon,
    this.disabledIds = const {},
    this.showRemaining = true,
  });

  final ValueChanged<BudgetPick> onPicked;
  final String? selectedId;
  final bool allowNone;
  final String? title;
  final String? noneLabel;
  final IconData? noneIcon;
  final Set<String> disabledIds;
  final bool showRemaining;

  @override
  ConsumerState<BudgetPicker> createState() => _BudgetPickerState();
}

class _BudgetPickerState extends ConsumerState<BudgetPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _pick(String? id) {
    Fx.fire(Sfx.drop);
    widget.onPicked(BudgetPick(id));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final status = ref.watch(budgetStatusProvider).value;
    final currencies = ref.watch(budgetCurrenciesProvider).value;
    final stored = ref.watch(budgetStoredColorsProvider);
    final f = BudgetFormat.of(context, currencies ?? BudgetCurrencies.fallback);
    final plan = status?.plan;
    final lines = plan?.lines ?? const <BudgetLine>[];
    final searchable = lines.length > 7;
    final ids = BudgetSearch.filter([
      for (final l in lines) (id: l.id, parentId: l.parentId, name: l.name),
    ], _query.text);
    final colors = plan == null ? const <String, Color>{} : budgetLineColors(plan, t, stored: stored);
    final searching = _query.text.trim().isNotEmpty;

    Widget body;
    if (status == null) {
      body = const Padding(
        padding: EdgeInsets.all(Space.xl),
        child: Center(child: OrbitLoader()),
      );
    } else if (lines.isEmpty && !widget.allowNone) {
      body = _Message(text: l.budgetPickerEmpty, icon: Icons.account_tree_outlined);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.allowNone && !searching)
            _PickRow(
              label: widget.noneLabel ?? l.budgetPickerNone,
              icon: widget.noneIcon ?? Icons.do_not_disturb_on_outlined,
              depth: 0,
              color: t.textTertiary,
              selected: widget.selectedId == null,
              onTap: () => _pick(null),
            ),
          if (lines.isEmpty) _Message(text: l.budgetPickerEmpty, icon: Icons.account_tree_outlined),
          if (lines.isNotEmpty && ids.isEmpty) _Message(text: l.budgetPickerNoResults, icon: Icons.search_off_rounded),
          for (final id in ids)
            if (plan![id] case final line?)
              _PickRow(
                label: line.name,
                subtitle: searching && line.depth > 0 ? plan.pathOf(line.parentId!).join(' › ') : null,
                depth: searching ? 0 : line.depth,
                color: colors[id] ?? t.accent,
                selected: id == widget.selectedId,
                enabled: !widget.disabledIds.contains(id),
                trailing: widget.showRemaining ? _remaining(l, f, status.month.line(id)) : null,
                onTap: () => _pick(id),
              ),
        ],
      );
    }

    return InteractionSheetFrame(
      title: widget.title ?? l.budgetPickerTitle,
      icon: Icons.account_tree_rounded,
      toolbar: searchable
          ? TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: kitInputDecoration(
                context,
                hint: l.budgetPickerSearch,
              ).copyWith(prefixIcon: Icon(Icons.search_rounded, color: t.textTertiary), isDense: true),
            )
          : null,
      bodyPadding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.l),
      body: body,
    );
  }

  Widget? _remaining(L10n l, BudgetFormat f, SpendLine? s) {
    if (s == null || s.plannedMilli == 0 && s.spentMilli == 0) return null;
    final t = context.tokens;
    final over = s.remainingMilli < 0;
    return Text(
      over ? l.budgetOverBy(f.money(-s.remainingMilli)) : l.budgetLeft(f.money(s.remainingMilli)),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: over ? t.danger : t.textTertiary),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.depth,
    required this.color,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.trailing,
    this.enabled = true,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final int depth;
  final Color color;
  final bool selected;
  final bool enabled;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: MadarPressable(
        onTap: enabled ? onTap : null,
        enabled: enabled,
        sfx: null,
        selected: selected,
        semanticLabel: [label, ?subtitle, if (selected) l.budgetCurrentBadge].join(', '),
        excludeChildSemantics: true,
        focusRadius: BorderRadius.circular(t.radiusM),
        child: AnimatedContainer(
          duration: context.motion(MadarMotion.short),
          constraints: const BoxConstraints(minHeight: 50),
          margin: const EdgeInsetsDirectional.only(bottom: Space.xxs),
          padding: EdgeInsetsDirectional.fromSTEB(Space.m + depth * 20.0, Space.s, Space.m, Space.s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusM),
            color: selected ? t.accent.withValues(alpha: t.isDark ? 0.14 : 0.1) : null,
            border: Border.all(color: selected ? t.accent.withValues(alpha: 0.55) : const Color(0x00000000)),
          ),
          child: Row(
            children: [
              if (icon != null)
                Icon(icon, size: 18, color: color)
              else if (depth > 0)
                BudgetOrb(color: color.withValues(alpha: 0.75), size: 7, glow: false)
              else
                BudgetOrb(color: color, size: 11),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (depth == 0 ? text.titleSmall : text.bodyMedium)?.copyWith(
                        color: selected ? t.textPrimary : null,
                      ),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: Space.s), trailing!],
              if (selected) ...[
                const SizedBox(width: Space.s),
                Icon(Icons.check_circle_rounded, size: 20, color: t.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xl),
      child: Column(
        children: [
          Icon(icon, size: 32, color: t.textTertiary),
          const SizedBox(height: Space.s),
          Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textSecondary)),
        ],
      ),
    );
  }
}

/// A form field showing the chosen budget item's path ("Home food ›
/// Proteins") that opens [showBudgetPicker]. For the ledger's transaction
/// sheet.
class BudgetPickerField extends ConsumerWidget {
  const BudgetPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowNone = true,
    this.placeholder,
  });

  /// The chosen budget item id (null = none).
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowNone;
  final String? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final plan = ref.watch(budgetPlanProvider).value;
    final path = value == null || plan?[value!] == null ? null : plan!.pathOf(value!).join(' › ');
    return PickerButton(
      icon: Icons.account_tree_rounded,
      text: path ?? placeholder ?? l.budgetPickerPlaceholder,
      placeholder: path == null,
      active: path != null,
      semanticLabel: l.budgetPickerTitle,
      onTap: () async {
        final pick = await showBudgetPicker(context, selectedId: value, allowNone: allowNone);
        if (pick != null) onChanged(pick.id);
      },
    );
  }
}
