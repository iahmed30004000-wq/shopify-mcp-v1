import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/domain/money.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/interaction/sheets/field_inputs.dart'
    show FieldShell, PickerButton, kitInputDecoration, kitNumberFormatter;
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/budget_repository.dart';
import '../domain/budget_draft.dart';
import '../domain/budget_edits.dart';
import '../domain/budget_plan.dart';
import 'budget_format.dart';
import 'budget_labels.dart';
import 'budget_picker.dart';
import 'widgets/budget_widgets.dart';

/// What the item sheet returns.
sealed class BudgetItemSheetResult {
  const BudgetItemSheetResult();
}

/// Save [node] (new when [isNew]).
final class BudgetItemSaved extends BudgetItemSheetResult {
  const BudgetItemSaved(this.node, {required this.isNew});

  final BudgetNode node;
  final bool isNew;
}

/// Delete item [id] (with its sub-items).
final class BudgetItemDeleteRequested extends BudgetItemSheetResult {
  const BudgetItemDeleteRequested(this.id);

  final String id;
}

/// Opens the item editor: name, parent, amount OR percentage (of the parent
/// or of the total) with the other value recalculated live, monthly or
/// weekly, currency, and a live preview of the effect on the budget.
///
/// Edits [itemId] of [math], or creates a new item (id [newId], default a
/// fresh UUID) under [parentId]. Nothing is written: the caller persists
/// the returned [BudgetItemSaved] / [BudgetItemDeleteRequested].
Future<BudgetItemSheetResult?> showBudgetItemSheet(
  BuildContext context, {
  required BudgetMath math,
  String? itemId,
  String? parentId,
  String? newId,
  BudgetCurrencies currencies = BudgetCurrencies.fallback,
}) {
  return showInteractionSheet<BudgetItemSheetResult>(
    context,
    builder: (_) => BudgetItemSheet(
      math: math,
      itemId: itemId,
      parentId: parentId,
      newId: newId,
      currencies: currencies,
      onDone: (result) => Navigator.of(context, rootNavigator: true).pop(result),
    ),
  );
}

/// The item editor's content (see [showBudgetItemSheet]).
class BudgetItemSheet extends StatefulWidget {
  const BudgetItemSheet({
    super.key,
    required this.math,
    required this.onDone,
    this.itemId,
    this.parentId,
    this.newId,
    this.currencies = BudgetCurrencies.fallback,
  });

  final BudgetMath math;
  final String? itemId;
  final String? parentId;
  final String? newId;
  final BudgetCurrencies currencies;
  final ValueChanged<BudgetItemSheetResult> onDone;

  @override
  State<BudgetItemSheet> createState() => _BudgetItemSheetState();
}

class _BudgetItemSheetState extends State<BudgetItemSheet> {
  late BudgetDraft _draft;
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _percent;
  final _amountFocus = FocusNode();
  final _percentFocus = FocusNode();
  String? _nameError;
  String? _amountError;
  String? _percentError;
  bool _initialised = false;
  bool _confirming = false;

  bool get _isNew => widget.itemId == null;

  @override
  void initState() {
    super.initState();
    _draft = _isNew
        ? BudgetDraft.create(widget.math, id: widget.newId ?? BudgetRepository.newItemId(), parentId: widget.parentId)
        : BudgetDraft.edit(widget.math, widget.itemId!);
    _name = TextEditingController(text: _draft.node.name);
    _amount = TextEditingController();
    _percent = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    _sync(force: true);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _percent.dispose();
    _amountFocus.dispose();
    _percentFocus.dispose();
    super.dispose();
  }

  BudgetFormat get _f => BudgetFormat.of(context, widget.currencies);

  /// Writes the draft's values into the fields the user is not typing in.
  void _sync({bool force = false}) {
    final f = _f;
    if (force || !_amountFocus.hasFocus) {
      final a = _draft.amountMilli;
      _amount.text = _isNew && a == 0 && _draft.mode != BudgetDraftMode.percent ? '' : f.inputAmount(a);
      _amountError = null;
    }
    if (force || !_percentFocus.hasFocus) {
      final p = _draft.percent;
      _percent.text = p == null || (_isNew && p == 0 && _draft.mode != BudgetDraftMode.percent)
          ? ''
          : f.inputPercent(p);
      _percentError = null;
    }
  }

  void _update(BudgetDraft next) {
    setState(() {
      _draft = next;
      _sync(force: true);
    });
  }

  void _onAmount(String text) {
    final l = L10n.of(context);
    if (text.trim().isEmpty) {
      setState(() => _draft = _draft.withAmount(0));
      _syncOther(amount: true);
      return;
    }
    final milli = MoneyText.parseMilli(text);
    if (milli == null || milli < 0) {
      setState(() => _amountError = l.budgetAmountInvalid);
      return;
    }
    setState(() {
      _amountError = null;
      _draft = _draft.withAmount(milli);
    });
    _syncOther(amount: true);
  }

  void _onPercent(String text) {
    final l = L10n.of(context);
    final v = text.trim().isEmpty ? 0.0 : MoneyText.parseNumber(text.replaceAll('%', '').replaceAll('٪', ''));
    if (v == null || v < 0 || !v.isFinite) {
      setState(() => _percentError = l.budgetPercentInvalid);
      return;
    }
    setState(() {
      _percentError = null;
      _draft = _draft.withPercent(v);
    });
    _syncOther(amount: false);
  }

  /// After typing in one field, recalculates the other.
  void _syncOther({required bool amount}) {
    final f = _f;
    setState(() {
      if (amount) {
        final p = _draft.percent;
        _percent.text = p == null ? '' : f.inputPercent(p);
        _percentError = null;
      } else {
        _amount.text = f.inputAmount(_draft.amountMilli);
        _amountError = null;
      }
    });
  }

  Future<void> _pickParent() async {
    final l = L10n.of(context);
    final own = BudgetEdits.subtree(_draft.preview, _draft.id).toSet();
    final pick = await showBudgetPicker(
      context,
      title: l.budgetFieldParent,
      selectedId: _draft.node.parentId,
      noneLabel: l.budgetTopLevel,
      noneIcon: Icons.vertical_align_top_rounded,
      disabledIds: own,
      showRemaining: false,
    );
    if (pick == null || !mounted) return;
    _update(_draft.withParent(pick.id));
  }

  void _save() {
    final l = L10n.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      Fx.fire(Sfx.error);
      setState(() => _nameError = l.fieldRequired);
      return;
    }
    if (_amountError != null || _percentError != null) {
      Fx.fire(Sfx.error);
      return;
    }
    Fx.fire(Sfx.complete);
    widget.onDone(BudgetItemSaved(_draft.withName(name).toSave, isNew: _isNew));
  }

  void _askDiscard() {
    if (_confirming) return;
    FocusScope.of(context).unfocus();
    Fx.fire(Sfx.notify, haptic: Haptic.warning);
    setState(() => _confirming = true);
  }

  Widget _discardBar(L10n l) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('discard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: t.warning, size: 20),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${l.interactionDiscardTitle}  ', style: text.titleMedium),
                      TextSpan(text: l.interactionDiscardBody, style: text.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        Row(
          children: [
            Expanded(
              child: SheetButton(
                label: l.interactionDiscardConfirm,
                tone: t.danger,
                sfx: Sfx.delete,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: SheetButton(
                label: l.interactionKeepEditing,
                primary: true,
                onPressed: () => setState(() => _confirming = false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final f = _f;
    final draft = _draft;
    final parentName = draft.parent?.node.name;
    final title = !_isNew
        ? l.budgetEditItem
        : widget.parentId == null
        ? l.budgetNewItem
        : l.budgetNewChild(BudgetLabels.name(widget.math[widget.parentId!]?.node.name ?? ''));
    final plan = BudgetPlan(draft.preview);
    final canSave = _amountError == null && _percentError == null && draft.dirty;
    final currencyCodes = [
      widget.currencies.base,
      for (final c in widget.currencies.codes)
        if (c != widget.currencies.base) c,
      if (!widget.currencies.codes.contains(draft.currency) && draft.currency != widget.currencies.base) draft.currency,
    ];

    final changed = _isNew ? (_name.text.trim().isNotEmpty || draft.amountMilli != 0) : draft.dirty;
    return PopScope<BudgetItemSheetResult>(
      canPop: !changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askDiscard();
      },
      child: InteractionSheetFrame(
        title: title,
        subtitle: _isNew || draft.node.parentId == null ? null : plan.pathOf(draft.node.parentId!).join(' › '),
        icon: Icons.account_tree_rounded,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldShell(
              label: l.budgetFieldName,
              icon: Icons.label_outline_rounded,
              error: _nameError,
              child: TextField(
                key: const ValueKey('budget.sheet.name'),
                controller: _name,
                autofocus: _isNew,
                textInputAction: TextInputAction.next,
                maxLength: 60,
                onChanged: (v) => setState(() {
                  _nameError = null;
                  _draft = _draft.withName(v);
                }),
                decoration: kitInputDecoration(context, hint: l.budgetFieldNameHint, error: _nameError != null),
              ),
            ),
            const SizedBox(height: Space.l),
            FieldShell(
              label: l.budgetFieldParent,
              icon: Icons.subdirectory_arrow_left_rounded,
              child: PickerButton(
                icon: draft.node.parentId == null ? Icons.vertical_align_top_rounded : Icons.account_tree_outlined,
                text: draft.node.parentId == null ? l.budgetTopLevel : plan.pathOf(draft.node.parentId!).join(' › '),
                semanticLabel: l.budgetFieldParent,
                onTap: _pickParent,
              ),
            ),
            const SizedBox(height: Space.l),
            FieldShell(
              label: l.budgetFieldSetBy,
              icon: Icons.tune_rounded,
              child: ChoicePills<BudgetDraftMode>.single(
                options: [
                  ChoiceOption(value: BudgetDraftMode.amount, label: l.budgetModeAmount, icon: Icons.payments_outlined),
                  ChoiceOption(value: BudgetDraftMode.percent, label: l.budgetModePercent, icon: Icons.percent_rounded),
                  if (draft.hasChildren)
                    ChoiceOption(value: BudgetDraftMode.sum, label: l.budgetModeSum, icon: Icons.functions_rounded),
                ],
                selected: draft.mode,
                onChanged: (m) {
                  if (m != null) _update(_draft.withMode(m));
                },
              ),
            ),
            const SizedBox(height: Space.m),
            _ValueFields(
              draft: draft,
              amount: _amount,
              percent: _percent,
              amountFocus: _amountFocus,
              percentFocus: _percentFocus,
              amountError: _amountError,
              percentError: _percentError,
              onAmount: _onAmount,
              onPercent: _onPercent,
              currencySymbol: f.symbol(draft.currency),
            ),
            if (draft.mode == BudgetDraftMode.sum)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: Space.s, start: Space.xxs),
                child: Text(l.budgetSumHint, style: Theme.of(context).textTheme.bodySmall),
              ),
            if (draft.node.parentId != null && draft.mode == BudgetDraftMode.percent) ...[
              const SizedBox(height: Space.m),
              ChoicePills<PercentBase>.single(
                options: [
                  ChoiceOption(value: PercentBase.parent, label: l.budgetOfParent(BudgetLabels.name(parentName ?? ''))),
                  ChoiceOption(value: PercentBase.total, label: l.budgetOfTotal),
                ],
                selected: draft.percentBase,
                onChanged: (b) {
                  if (b != null) _update(_draft.withPercentBase(b));
                },
              ),
            ],
            const SizedBox(height: Space.l),
            FieldShell(
              label: l.budgetFieldPeriod,
              icon: Icons.event_repeat_rounded,
              child: ChoicePills<BudgetPeriod>.single(
                options: [
                  ChoiceOption(value: BudgetPeriod.monthly, label: l.budgetMonthly, icon: Icons.calendar_month_rounded),
                  ChoiceOption(value: BudgetPeriod.weekly, label: l.budgetWeekly, icon: Icons.view_week_rounded),
                ],
                selected: draft.node.period,
                onChanged: (p) {
                  if (p != null) _update(_draft.withPeriod(p));
                },
              ),
            ),
            if (currencyCodes.length > 1) ...[
              const SizedBox(height: Space.l),
              FieldShell(
                label: l.budgetFieldCurrency,
                icon: Icons.currency_exchange_rounded,
                child: ChoicePills<String>.single(
                  scrollable: true,
                  options: [
                    for (final c in currencyCodes)
                      ChoiceOption(value: c, label: c == widget.currencies.base ? l.budgetBaseCurrency(c) : c),
                  ],
                  selected: draft.currency,
                  onChanged: (c) {
                    if (c != null) _update(_draft.withCurrency(c));
                  },
                ),
              ),
            ],
            const SizedBox(height: Space.l),
            _Preview(draft: draft, plan: plan, format: f),
          ],
        ),
        footer: AnimatedSwitcher(
          duration: context.motion(MadarMotion.short),
          child: _confirming
              ? _discardBar(l)
              : Row(
                  key: const ValueKey('actions'),
                  children: [
                    if (!_isNew) ...[
                      SheetButton(
                        label: l.actionDelete,
                        icon: Icons.delete_outline_rounded,
                        tone: t.danger,
                        sfx: null,
                        onPressed: () => widget.onDone(BudgetItemDeleteRequested(draft.id)),
                      ),
                      const SizedBox(width: Space.m),
                    ],
                    Expanded(
                      child: SheetButton(
                        label: l.actionSave,
                        icon: Icons.check_rounded,
                        primary: true,
                        enabled: canSave,
                        sfx: null,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Amount and percent side by side; the one that sets the plan is lit, the
/// other shows its live recalculated value (typing in it switches mode).
class _ValueFields extends StatelessWidget {
  const _ValueFields({
    required this.draft,
    required this.amount,
    required this.percent,
    required this.amountFocus,
    required this.percentFocus,
    required this.amountError,
    required this.percentError,
    required this.onAmount,
    required this.onPercent,
    required this.currencySymbol,
  });

  final BudgetDraft draft;
  final TextEditingController amount;
  final TextEditingController percent;
  final FocusNode amountFocus;
  final FocusNode percentFocus;
  final String? amountError;
  final String? percentError;
  final ValueChanged<String> onAmount;
  final ValueChanged<String> onPercent;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final sum = draft.mode == BudgetDraftMode.sum;
    final byPercent = draft.mode == BudgetDraftMode.percent;

    InputDecoration deco(String? error, bool derived, {String? suffix}) {
      final base = kitInputDecoration(context, error: error != null, suffix: suffix);
      if (error != null) return base;
      final radius = BorderRadius.circular(t.radiusM);
      if (!derived) {
        // The value that sets the plan is lit.
        return base.copyWith(
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: t.accent.withValues(alpha: 0.7), width: 1.2),
          ),
        );
      }
      return base.copyWith(
        prefixIcon: Tooltip(
          message: l.budgetCalculated,
          child: Icon(Icons.auto_awesome_rounded, size: 16, color: t.info, semanticLabel: l.budgetCalculated),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: t.textTertiary.withValues(alpha: 0.3)),
        ),
      );
    }

    TextStyle? style(bool derived) => Theme.of(context).textTheme.titleMedium?.copyWith(
      color: derived ? t.textSecondary : t.textPrimary,
      fontWeight: derived ? FontWeight.w400 : FontWeight.w600,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: FieldShell(
            label: l.budgetFieldAmount,
            error: amountError,
            child: TextField(
              key: const ValueKey('budget.sheet.amount'),
              controller: amount,
              focusNode: amountFocus,
              readOnly: sum,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [kitNumberFormatter],
              onChanged: onAmount,
              style: style(byPercent || sum),
              decoration: deco(amountError, byPercent || sum, suffix: currencySymbol),
            ),
          ),
        ),
        const SizedBox(width: Space.m),
        Expanded(
          flex: 2,
          child: FieldShell(
            label: l.budgetFieldPercent,
            error: percentError,
            child: TextField(
              key: const ValueKey('budget.sheet.percent'),
              controller: percent,
              focusNode: percentFocus,
              readOnly: sum,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [kitNumberFormatter],
              onChanged: onPercent,
              style: style(!byPercent),
              decoration: deco(percentError, !byPercent, suffix: '%'),
            ),
          ),
        ),
      ],
    );
  }
}

/// The draft's effect on the budget: monthly value, shares, the parent's
/// allocation and any warning, updated on every keystroke.
class _Preview extends StatelessWidget {
  const _Preview({required this.draft, required this.plan, required this.format});

  final BudgetDraft draft;
  final BudgetPlan plan;
  final BudgetFormat format;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final f = format;
    final line = plan[draft.id];
    final parent = draft.parent;
    final foreign = draft.currency != draft.baseCurrency;
    final issues = [for (final w in draft.warnings) BudgetIssue.of(w, draft.preview)]
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));

    Widget row(IconData icon, String s, {Color? color}) => Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: Icon(icon, size: 16, color: color ?? t.gold),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(s, style: text.bodyMedium?.copyWith(color: color ?? t.textSecondary)),
          ),
        ],
      ),
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: AnimatedSize(
        duration: context.motion(MadarMotion.short),
        curve: MadarMotion.emphasized,
        alignment: AlignmentDirectional.topStart,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusL),
            color: t.accent.withValues(alpha: t.isDark ? 0.07 : 0.05),
            border: Border.all(color: t.brass.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(l.budgetPreviewTitle, style: text.titleSmall?.copyWith(color: t.gold)),
                  ),
                  BudgetAmountText(
                    BudgetLabels.perPeriod(l, draft.node.period, f.money(draft.amountMilli, draft.currency)),
                    size: 15,
                  ),
                ],
              ),
              if (foreign || draft.node.period == BudgetPeriod.weekly)
                row(Icons.calendar_month_rounded, l.budgetApproxMonthly(f.money(draft.monthlyMilli))),
              if (draft.node.period == BudgetPeriod.monthly)
                row(Icons.view_week_rounded, l.budgetWeeklyEquivalent(f.money(draft.weeklyMilli))),
              if (line != null)
                row(Icons.pie_chart_outline_rounded, l.budgetPercentOfTotal(f.percent(line.percentOfTotal))),
              if (parent != null && line != null)
                row(
                  Icons.account_tree_outlined,
                  l.budgetPercentOf(f.percent(line.percentOfParent), BudgetLabels.name(parent.node.name)),
                ),
              if (parent != null && !parent.derivedFromChildren && parent.childrenSumMilli != null && issues.isEmpty)
                row(
                  Icons.check_circle_outline_rounded,
                  l.budgetChildrenSum(f.money(parent.childrenSumMilli!), f.money(parent.monthlyMilli)),
                  color: t.success,
                ),
              for (final i in issues)
                row(
                  BudgetLabels.issueIcon(i.kind),
                  BudgetLabels.issue(l, f, plan, i),
                  color: BudgetLabels.severityColor(t, i.severity),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
