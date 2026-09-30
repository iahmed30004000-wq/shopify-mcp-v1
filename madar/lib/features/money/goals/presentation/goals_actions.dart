import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/goals_providers.dart';
import '../data/goals_service.dart';
import '../domain/debt_ledger.dart';
import '../domain/due_dates.dart';
import '../domain/due_reminders.dart';
import '../domain/goals_rates.dart';
import '../domain/goals_snapshot.dart';
import '../domain/jar_plan.dart';
import '../domain/obligation_plan.dart';
import '../goals_texts.dart';
import 'astrolabe_ring.dart';
import 'goals_ui.dart';

/// Every user action of the goals package: the editor sheets, the money
/// movements with their feedback (sound, haptics, a celebration when a jar
/// fills or a debt is paid off) and the undo actions the interaction kit
/// shows in its toast.
///
/// Create it in `build` (or a callback of a mounted widget): the texts,
/// service, snapshot and day are captured up front, so an action whose row
/// disappears while it runs (a paid obligation changing section, a settled
/// debt folding away) still returns its undo.
class GoalsActions {
  GoalsActions(this.context, this.ref)
    : l = L10n.of(context),
      _service = ref.read(goalsServiceProvider),
      _snap = ref.read(goalsSnapshotProvider),
      _today = ref.read(goalsTodayProvider) {
    _rates = _snap?.rates ?? GoalsRates.single('JOD');
    _texts = GoalsTexts.of(context, _rates);
  }

  final BuildContext context;
  final WidgetRef ref;
  final L10n l;
  final GoalsService _service;
  final GoalsSnapshot? _snap;
  final DateTime _today;
  late final GoalsRates _rates;
  late final GoalsTexts _texts;

  static const String _none = '';

  String? _positive(Object? v, Map<String, Object?> _) =>
      v is MoneyValue && v.amountMilli <= 0 ? l.goalsAmountPositive : null;

  List<SelectOption> _walletOptions() => [
    SelectOption(id: _none, label: l.goalsNoWallet, icon: Icons.do_not_disturb_on_outlined),
    for (final w in _snap?.wallets.values ?? const <WalletRow>[])
      SelectOption(
        id: w.id,
        label: '${w.name} · ${w.currency}',
        icon: GoalsIcons.wallet,
        color: w.color == null ? null : Color(w.color!),
      ),
  ];

  /// Budget items as a flattened tree ("Home food › Proteins").
  List<SelectOption> _budgetOptions() {
    final items = _snap?.budgetItems ?? const <String, BudgetItemRow>{};
    final children = <String?, List<BudgetItemRow>>{};
    for (final b in items.values) {
      final parent = b.parentId != null && items.containsKey(b.parentId) ? b.parentId : null;
      (children[parent] ??= []).add(b);
    }
    final out = <SelectOption>[
      SelectOption(id: _none, label: l.goalsNoBudgetItem, icon: Icons.do_not_disturb_on_outlined),
    ];
    final seen = <String>{};
    void walk(String? parent, List<String> path) {
      final kids = [...?children[parent]]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (final k in kids) {
        if (!seen.add(k.id)) continue;
        final p = [...path, k.name];
        out.add(SelectOption(id: k.id, label: p.join(' › '), icon: Icons.account_tree_outlined));
        walk(k.id, p);
      }
    }

    walk(null, const []);
    return out;
  }

  String? _id(Object? v) => v is String && v.isNotEmpty ? v : null;

  DateTime _firstDate(DateTime? existing) =>
      existing != null && existing.isBefore(_today) ? existing : CalendarDays.addDays(_today, -3650);

  DateTime get _lastDate => CalendarDays.addDays(_today, 365 * 50);

  // ================================================================= jars ==

  Future<void> addJar() => _jarEditor(null);

  Future<void> editJar(JarRow jar) => _jarEditor(jar);

  Future<void> _jarEditor(JarRow? jar) async {
    final rates = _rates;
    final values = await showEditSheet(
      context,
      title: jar == null ? l.goalsJarNew : l.goalsJarEdit,
      subtitle: jar == null ? l.goalsJarNewSubtitle : null,
      icon: GoalsIcons.jars,
      saveLabel: jar == null ? l.goalsCreate : l.actionSave,
      fields: [
        FieldSpec.text(
          'name',
          l.goalsFieldJarName,
          required: true,
          hint: l.goalsFieldJarNameHint,
          icon: Icons.label_outline_rounded,
          autofocus: jar == null,
          maxLength: 60,
        ),
        FieldSpec.currency(
          'target',
          l.goalsFieldTarget,
          required: true,
          currencies: rates.codes,
          defaultCurrency: jar?.currency ?? rates.base,
          validator: _positive,
          icon: Icons.flag_circle_outlined,
        ),
        FieldSpec.date(
          'deadline',
          l.goalsFieldDeadline,
          icon: GoalsIcons.deadline,
          firstDate: jar?.deadline != null && jar!.deadline!.isBefore(_today) ? jar.deadline : _today,
          lastDate: _lastDate,
        ),
        FieldSpec.icon('icon', l.goalsFieldIcon, icons: GoalsIcons.jarChoices),
        FieldSpec.color('color', l.goalsFieldColor, palette: CuratedPalette.colors),
      ],
      initial: {
        if (jar != null) ...{
          'name': jar.name,
          'target': MoneyValue(amountMilli: jar.targetMilli, currency: jar.currency),
          'deadline': jar.deadline,
          'icon': jar.icon,
          'color': jar.color,
        } else
          'icon': 'savings',
      },
      preview: (context, v) => _JarEditorPreview(values: v, rates: rates, today: _today, jar: jar),
    );
    if (values == null) return;
    final target = values['target'] as MoneyValue;
    final draft = JarDraft(
      name: values['name'] as String,
      targetMilli: target.amountMilli,
      currency: target.currency,
      deadline: values['deadline'] as DateTime?,
      icon: values['icon'] as String?,
      color: values['color'] as int?,
    );
    if (jar == null) {
      await _service.addJar(draft);
    } else {
      await _service.updateJar(jar.id, draft);
    }
  }

  /// Deposit into (or, with [withdraw], take out of) a jar.
  Future<UndoableAction?> moveMoney(JarView jar, {bool withdraw = false}) async {
    final rates = _rates;
    final texts = _texts;
    final currency = jar.jar.currency;
    final wallets = _walletOptions();
    final saved = math.max(0, jar.plan.savedMilli);
    final suggestion = withdraw ? null : jar.plan.requiredPerMonthMilli;
    final values = await showEditSheet(
      context,
      title: withdraw ? l.goalsWithdrawFrom(texts.user(jar.jar.name)) : l.goalsDepositTo(texts.user(jar.jar.name)),
      icon: withdraw ? GoalsIcons.withdraw : GoalsIcons.deposit,
      saveLabel: withdraw ? l.goalsWithdraw : l.goalsDeposit,
      fields: [
        FieldSpec.currency(
          'amount',
          l.goalsFieldAmount,
          required: true,
          currencies: [currency],
          defaultCurrency: currency,
          decimals: rates.decimalsOf(currency),
          icon: withdraw ? GoalsIcons.withdraw : GoalsIcons.deposit,
          validator: (v, all) {
            final p = _positive(v, all);
            if (p != null) return p;
            if (withdraw && v is MoneyValue && v.amountMilli > saved) {
              return l.goalsWithdrawTooMuch(texts.money(saved, currency));
            }
            return null;
          },
        ),
        if (wallets.length > 1)
          FieldSpec.singleSelect(
            'wallet',
            withdraw ? l.goalsFieldToWallet : l.goalsFieldFromWallet,
            options: wallets,
            icon: GoalsIcons.wallet,
          ),
        FieldSpec.date('date', l.goalsFieldDate, required: true, lastDate: _today, icon: GoalsIcons.calendar),
        FieldSpec.text('note', l.goalsFieldNote, icon: GoalsIcons.note, maxLength: 120),
      ],
      initial: {
        'date': _today,
        'wallet': _none,
        if (suggestion != null && suggestion > 0) 'amount': MoneyValue(amountMilli: suggestion, currency: currency),
      },
      preview: (context, v) => _MovePreview(jar: jar, values: v, withdraw: withdraw, rates: rates),
    );
    if (values == null || !context.mounted) return null;
    final amount = (values['amount'] as MoneyValue).amountMilli;
    final result = await _service.moveJarMoney(
      jar.id,
      amountMilli: amount,
      withdraw: withdraw,
      date: values['date'] as DateTime?,
      walletId: _id(values['wallet']),
      note: values['note'] as String?,
    );
    if (result.reachedNow && context.mounted) {
      Celebrate.burstFrom(
        context,
        kind: CelebrationKind.orbitalRing,
        color: context.tokens.metalGold,
      );
    }
    Fx.fire(result.reachedNow ? Sfx.levelUp : (withdraw ? Sfx.swipe : Sfx.complete));
    final label = result.reachedNow
        ? l.goalsJarReached(texts.user(jar.jar.name))
        : (withdraw
              ? l.goalsWithdrawn(texts.money(amount, currency))
              : l.goalsDeposited(texts.money(amount, currency)));
    return UndoableAction(label: label, undo: result.undo);
  }

  Future<UndoableAction?> setArchived(JarView jar, bool archived) async {
    final undo = await _service.setJarArchived(jar.id, archived);
    Fx.fire(archived ? Sfx.swipe : Sfx.drop);
    return UndoableAction(label: archived ? l.goalsJarArchived : l.goalsJarRestored, undo: undo);
  }

  Future<UndoableAction?> deleteJar(JarView jar) async {
    final undo = await _service.deleteJar(jar.id);
    return undo == null ? null : UndoableAction(label: l.itemDeleted, undo: undo);
  }

  Future<UndoableAction?> deleteJarMovement(JarDepositRow move) async {
    final undo = await _service.deleteJarMovement(move.id);
    return undo == null ? null : UndoableAction(label: l.itemDeleted, undo: undo);
  }

  // ================================================================ debts ==

  Future<void> addDebt({DebtDirection? direction}) => _debtEditor(null, direction: direction);

  Future<void> editDebt(DebtRow debt) => _debtEditor(debt);

  Future<void> _debtEditor(DebtRow? debt, {DebtDirection? direction}) async {
    final rates = _rates;
    final wallets = _walletOptions();
    final walletId = debt == null ? null : await _service.debtWalletOf(debt.id);
    if (!context.mounted) return;
    final values = await showEditSheet(
      context,
      title: debt == null ? l.goalsDebtNew : l.goalsDebtEdit,
      icon: GoalsIcons.debts,
      saveLabel: debt == null ? l.goalsCreate : l.actionSave,
      fields: [
        FieldSpec.singleSelect(
          'direction',
          l.goalsFieldDirection,
          required: true,
          options: [
            SelectOption(id: DebtDirection.iOwe.name, label: l.goalsIOwe, icon: GoalsIcons.iOwe),
            SelectOption(id: DebtDirection.owedToMe.name, label: l.goalsOwedToMe, icon: GoalsIcons.owedToMe),
          ],
        ),
        FieldSpec.text(
          'person',
          l.goalsFieldPerson,
          required: true,
          hint: l.goalsFieldPersonHint,
          icon: Icons.person_outline_rounded,
          autofocus: debt == null,
          maxLength: 60,
        ),
        FieldSpec.currency(
          'amount',
          l.goalsFieldAmount,
          required: true,
          currencies: rates.codes,
          defaultCurrency: debt?.currency ?? rates.base,
          validator: _positive,
        ),
        FieldSpec.date(
          'due',
          l.goalsFieldDueDate,
          icon: GoalsIcons.calendar,
          firstDate: _firstDate(debt?.dueDate),
          lastDate: _lastDate,
        ),
        if (wallets.length > 1)
          FieldSpec.singleSelect('wallet', l.goalsFieldDebtWallet, options: wallets, icon: GoalsIcons.wallet),
        FieldSpec.multiline('note', l.goalsFieldNote, icon: GoalsIcons.note, maxLength: 300),
      ],
      initial: {
        'direction': (debt?.direction ?? direction ?? DebtDirection.iOwe).name,
        'wallet': walletId != null && wallets.any((w) => w.id == walletId) ? walletId : _none,
        if (debt != null) ...{
          'person': debt.person,
          'amount': MoneyValue(amountMilli: debt.amountMilli, currency: debt.currency),
          'due': debt.dueDate,
          'note': debt.note,
        },
      },
      preview: wallets.length > 1
          ? (context, v) => _DebtEditorPreview(values: v, rates: rates, wallets: _snap?.wallets ?? const {})
          : null,
    );
    if (values == null) return;
    final amount = values['amount'] as MoneyValue;
    final draft = DebtDraft(
      direction: DebtDirection.values.byName(values['direction'] as String),
      person: values['person'] as String,
      amountMilli: amount.amountMilli,
      currency: amount.currency,
      dueDate: values['due'] as DateTime?,
      note: values['note'] as String?,
      // Without the field (no wallets) an existing link is kept.
      walletId: wallets.length > 1 ? _id(values['wallet']) : walletId,
    );
    if (debt == null) {
      await _service.addDebt(draft);
    } else {
      await _service.updateDebt(debt.id, draft);
    }
  }

  /// Records a (partial) payment.
  Future<UndoableAction?> recordPayment(DebtView debt) async {
    final rates = _rates;
    final texts = _texts;
    final currency = debt.debt.currency;
    final wallets = _walletOptions();
    final iOwe = debt.debt.direction == DebtDirection.iOwe;
    final values = await showEditSheet(
      context,
      title: iOwe ? l.goalsPayTo(texts.user(debt.debt.person)) : l.goalsReceiveFrom(texts.user(debt.debt.person)),
      icon: GoalsIcons.paid,
      saveLabel: l.goalsRecordPayment,
      fields: [
        FieldSpec.currency(
          'amount',
          l.goalsFieldAmount,
          required: true,
          currencies: [currency],
          defaultCurrency: currency,
          decimals: rates.decimalsOf(currency),
          validator: _positive,
        ),
        if (wallets.length > 1)
          FieldSpec.singleSelect(
            'wallet',
            iOwe ? l.goalsFieldFromWallet : l.goalsFieldToWallet,
            options: wallets,
            icon: GoalsIcons.wallet,
          ),
        FieldSpec.date('date', l.goalsFieldDate, required: true, lastDate: _today, icon: GoalsIcons.calendar),
        FieldSpec.text('note', l.goalsFieldNote, icon: GoalsIcons.note, maxLength: 120),
      ],
      initial: {
        'amount': MoneyValue(amountMilli: debt.state.remainingMilli, currency: currency),
        'date': _today,
        'wallet': _none,
      },
      preview: (context, v) => _DebtPaymentPreview(debt: debt, values: v, rates: rates),
    );
    if (values == null || !context.mounted) return null;
    final amount = (values['amount'] as MoneyValue).amountMilli;
    final result = await _service.addDebtPayment(
      debt.id,
      amountMilli: amount,
      date: values['date'] as DateTime?,
      walletId: _id(values['wallet']),
      note: values['note'] as String?,
    );
    if (result.paidOff && context.mounted) {
      Celebrate.burstFrom(context, kind: CelebrationKind.stardust);
    }
    Fx.fire(result.paidOff ? Sfx.levelUp : Sfx.complete);
    return UndoableAction(
      label: result.paidOff
          ? l.goalsDebtPaidOff(texts.user(debt.debt.person))
          : l.goalsPaymentRecorded(texts.money(amount, currency)),
      undo: result.undo,
    );
  }

  Future<UndoableAction?> settle(DebtView debt) async {
    final undo = await _service.settleDebt(debt.id);
    Fx.fire(Sfx.complete);
    return UndoableAction(label: l.goalsDebtSettled(_texts.user(debt.debt.person)), undo: undo);
  }

  Future<UndoableAction?> reopen(DebtView debt) async {
    final undo = await _service.reopenDebt(debt.id);
    Fx.fire(Sfx.toggleOff);
    return UndoableAction(label: l.goalsDebtReopened, undo: undo);
  }

  Future<UndoableAction?> deleteDebt(DebtView debt) async {
    final undo = await _service.deleteDebt(debt.id);
    return undo == null ? null : UndoableAction(label: l.itemDeleted, undo: undo);
  }

  Future<UndoableAction?> deleteDebtPayment(DebtPaymentRow payment) async {
    final undo = await _service.deleteDebtPayment(payment.id);
    return undo == null ? null : UndoableAction(label: l.itemDeleted, undo: undo);
  }

  // ========================================================== obligations ==

  Future<void> addObligation() => _obligationEditor(null);

  Future<void> editObligation(ObligationRow o) => _obligationEditor(o);

  Future<void> _obligationEditor(ObligationRow? o) async {
    final rates = _rates;
    final wallets = _walletOptions();
    final budget = _budgetOptions();
    final values = await showEditSheet(
      context,
      title: o == null ? l.goalsObligationNew : l.goalsObligationEdit,
      subtitle: o == null ? l.goalsObligationNewSubtitle : null,
      icon: GoalsIcons.obligations,
      saveLabel: o == null ? l.goalsCreate : l.actionSave,
      fields: [
        FieldSpec.text(
          'name',
          l.goalsFieldObligationName,
          required: true,
          hint: l.goalsFieldObligationNameHint,
          icon: Icons.label_outline_rounded,
          autofocus: o == null,
          maxLength: 60,
        ),
        FieldSpec.currency(
          'amount',
          l.goalsFieldAmount,
          required: true,
          currencies: rates.codes,
          defaultCurrency: o?.currency ?? rates.base,
          validator: _positive,
        ),
        FieldSpec.singleSelect(
          'frequency',
          l.goalsFieldFrequency,
          required: true,
          icon: Icons.repeat_rounded,
          options: [
            SelectOption(id: Recurrence.weekly.name, label: l.goalsWeekly),
            SelectOption(id: Recurrence.monthly.name, label: l.goalsMonthly),
            SelectOption(id: Recurrence.yearly.name, label: l.goalsYearly),
          ],
        ),
        FieldSpec.number(
          'interval',
          l.goalsFieldInterval,
          required: true,
          min: 1,
          max: 99,
          step: 1,
          hint: l.goalsFieldIntervalHint,
          icon: Icons.linear_scale_rounded,
        ),
        FieldSpec.date(
          'nextDue',
          l.goalsFieldNextDue,
          required: true,
          icon: GoalsIcons.calendar,
          firstDate: _firstDate(o?.nextDue),
          lastDate: _lastDate,
        ),
        if (wallets.length > 1)
          FieldSpec.singleSelect('wallet', l.goalsFieldPayFromWallet, options: wallets, icon: GoalsIcons.wallet),
        if (budget.length > 1)
          FieldSpec.singleSelect(
            'budget',
            l.goalsFieldBudgetItem,
            options: budget,
            icon: Icons.pie_chart_outline_rounded,
          ),
        FieldSpec.multiline('note', l.goalsFieldNote, icon: GoalsIcons.note, maxLength: 300),
      ],
      initial: {
        'frequency': (o?.frequency ?? Recurrence.monthly).name,
        'interval': o == null ? 1 : math.max(1, o.interval),
        'nextDue': o?.nextDue ?? _today,
        'wallet': o?.walletId ?? _none,
        'budget': o?.budgetItemId ?? _none,
        if (o != null) ...{
          'name': o.name,
          'amount': MoneyValue(amountMilli: o.amountMilli, currency: o.currency),
          'note': o.note,
        },
      },
      preview: (context, v) => _ObligationPreview(values: v, rates: rates, today: _today),
    );
    if (values == null) return;
    final amount = values['amount'] as MoneyValue;
    final draft = ObligationDraft(
      name: values['name'] as String,
      amountMilli: amount.amountMilli,
      currency: amount.currency,
      frequency: Recurrence.values.byName(values['frequency'] as String),
      interval: (values['interval'] as num?)?.toInt() ?? 1,
      nextDue: values['nextDue'] as DateTime,
      walletId: _id(values['wallet']) ?? (wallets.length > 1 ? null : o?.walletId),
      budgetItemId: _id(values['budget']) ?? (budget.length > 1 ? null : o?.budgetItemId),
      note: values['note'] as String?,
    );
    if (o == null) {
      await _service.addObligation(draft);
    } else {
      await _service.updateObligation(o.id, draft);
    }
  }

  /// "Paid": one tap with the obligation's amount and wallet; asks for a
  /// wallet first when none is set but some exist.
  Future<UndoableAction?> pay(ObligationView o) async {
    final wallets = _snap?.wallets ?? const {};
    final walletId = o.obligation.walletId;
    if ((walletId == null || !wallets.containsKey(walletId)) && wallets.isNotEmpty) return payCustom(o);
    final result = await _service.payObligation(o.id);
    Fx.fire(Sfx.complete);
    return UndoableAction(
      label: l.goalsObligationPaid(_texts.shortDate(result.step.nextDue, _today)),
      undo: result.undo,
    );
  }

  /// "Paid" with a different amount, wallet or day.
  Future<UndoableAction?> payCustom(ObligationView o) async {
    final rates = _rates;
    final texts = _texts;
    final wallets = _walletOptions();
    final values = await showEditSheet(
      context,
      title: l.goalsPayObligation(texts.user(o.obligation.name)),
      subtitle: l.goalsForDue(texts.date(o.state.nextDue)),
      icon: GoalsIcons.paid,
      saveLabel: l.goalsMarkPaid,
      fields: [
        FieldSpec.currency(
          'amount',
          l.goalsFieldAmount,
          required: true,
          currencies: [o.obligation.currency],
          defaultCurrency: o.obligation.currency,
          decimals: rates.decimalsOf(o.obligation.currency),
          validator: _positive,
        ),
        if (wallets.length > 1)
          FieldSpec.singleSelect('wallet', l.goalsFieldPayFromWallet, options: wallets, icon: GoalsIcons.wallet),
        FieldSpec.date('date', l.goalsFieldPaidOn, required: true, lastDate: _today, icon: GoalsIcons.calendar),
      ],
      initial: {
        'amount': MoneyValue(amountMilli: o.obligation.amountMilli, currency: o.obligation.currency),
        'wallet': o.obligation.walletId ?? _none,
        'date': _today,
      },
    );
    if (values == null || !context.mounted) return null;
    final paidOn = values['date'] as DateTime?;
    final result = await _service.payObligation(
      o.id,
      amountMilli: (values['amount'] as MoneyValue).amountMilli,
      walletId: _id(values['wallet']),
      paidOn: paidOn == null || CalendarDays.of(paidOn) == _today ? null : paidOn,
      recordTransaction: _id(values['wallet']) != null,
    );
    Fx.fire(Sfx.complete);
    return UndoableAction(
      label: l.goalsObligationPaid(_texts.shortDate(result.step.nextDue, _today)),
      undo: result.undo,
    );
  }

  Future<UndoableAction?> skip(ObligationView o) async {
    final result = await _service.skipObligation(o.id);
    Fx.fire(Sfx.swipe);
    return UndoableAction(
      label: l.goalsObligationSkipped(_texts.shortDate(result.step.nextDue, _today)),
      undo: result.undo,
    );
  }

  Future<UndoableAction?> setActive(ObligationView o, bool active) async {
    final undo = await _service.setObligationActive(o.id, active);
    Fx.fire(active ? Sfx.toggleOn : Sfx.toggleOff);
    return UndoableAction(label: active ? l.goalsObligationResumed : l.goalsObligationPaused, undo: undo);
  }

  Future<UndoableAction?> deleteObligation(ObligationView o) async {
    final undo = await _service.deleteObligation(o.id);
    return undo == null ? null : UndoableAction(label: l.itemDeleted, undo: undo);
  }

  Future<UndoableAction?> deleteObligationPayment(ObligationPaymentRow p) async {
    final undo = await _service.deleteObligationPayment(p.id);
    return undo == null ? null : UndoableAction(label: l.itemDeleted, undo: undo);
  }

  // ============================================================ settings ==

  Future<void> reminderSettings() async {
    final current = ref.read(goalsReminderSettingsProvider).value ?? const GoalsReminderSettings();
    String two(int n) => n.toString().padLeft(2, '0');
    final values = await showEditSheet(
      context,
      title: l.goalsRemindersTitle,
      subtitle: l.goalsRemindersSubtitle,
      icon: GoalsIcons.reminders,
      fields: [
        FieldSpec.toggle('enabled', l.goalsRemindersEnabled, hint: l.goalsRemindersEnabledHint),
        FieldSpec.singleSelect(
          'lead',
          l.goalsRemindersLead,
          required: true,
          icon: Icons.schedule_rounded,
          options: [
            for (final d in GoalsReminderSettings.leadChoices)
              SelectOption(
                id: '$d',
                label: d == 0
                    ? l.goalsRemindersLeadNone
                    : _texts.fmt.localizeDigits(l.goalsRemindersLeadDays(d, _texts.fmt.formatInt(d))),
              ),
          ],
        ),
        FieldSpec.toggle('onDue', l.goalsRemindersOnDueDay),
        FieldSpec.time('time', l.goalsRemindersTime, required: true, icon: Icons.alarm_rounded),
      ],
      initial: {
        'enabled': current.enabled,
        'lead': '${GoalsReminderSettings.leadChoices.contains(current.leadDays) ? current.leadDays : 1}',
        'onDue': current.onDueDay,
        'time': '${two(current.hour)}:${two(current.minute)}',
      },
    );
    if (values == null) return;
    final time = (values['time'] as String?)?.split(':');
    await _service.setReminderSettings(
      GoalsReminderSettings(
        enabled: values['enabled'] as bool? ?? current.enabled,
        leadDays: int.tryParse(values['lead'] as String? ?? '') ?? current.leadDays,
        onDueDay: values['onDue'] as bool? ?? current.onDueDay,
        minuteOfDay: time == null || time.length != 2
            ? current.minuteOfDay
            : (int.tryParse(time[0]) ?? current.hour) * 60 + (int.tryParse(time[1]) ?? current.minute),
      ),
    );
  }
}

// ============================================================== previews ==

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusL),
        color: t.glassFill,
        border: Border.all(color: t.glassBorder),
      ),
      child: child,
    );
  }
}

/// The ring and monthly requirement of a jar being edited.
class _JarEditorPreview extends StatelessWidget {
  const _JarEditorPreview({required this.values, required this.rates, required this.today, this.jar});

  final Map<String, Object?> values;
  final GoalsRates rates;
  final DateTime today;
  final JarRow? jar;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final t = context.tokens;
        final text = Theme.of(context).textTheme;
        final l = L10n.of(context);
        final texts = GoalsTexts.of(context, rates);
        final target = values['target'];
        final currency = target is MoneyValue ? target.currency : (jar?.currency ?? rates.base);
        final existing = jar == null ? null : ref.watch(goalsJarProvider(jar!.id));
        final plan = JarPlan.compute(
          targetMilli: target is MoneyValue ? target.amountMilli : 0,
          currency: currency,
          movements: [
            for (final m in existing?.movements ?? const <JarDepositRow>[]) JarMovement(m.amountMilli, m.date),
          ],
          today: today,
          rates: rates,
          start: jar?.createdAt ?? today,
          deadline: values['deadline'] as DateTime?,
        );
        final color = values['color'] is int ? Color(values['color'] as int) : t.accent;
        final lines = <String>[
          if (plan.targetMilli > 0) l.goalsTargetOf(texts.money(plan.targetMilli, currency)),
          if (plan.requiredPerMonthMilli != null)
            l.goalsNeedPerMonth(texts.money(plan.requiredPerMonthMilli!, currency))
          else if (plan.targetMilli > 0 && plan.deadline == null)
            l.goalsNoDeadlineHint,
        ];
        return _PreviewFrame(
          child: Row(
            children: [
              AstrolabeProgressRing(
                progress: plan.progress,
                size: 72,
                dense: true,
                color: color,
                reached: plan.reached,
                child: GoalsJarGlyph(icon: values['icon'] as String?, color: color),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (values['name'] as String?)?.trim().isNotEmpty == true
                          ? values['name'] as String
                          : l.goalsFieldJarNameHint,
                      style: text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(line, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A jar's balance after the movement being entered (and the wallet amount
/// when the wallet uses another currency).
class _MovePreview extends StatelessWidget {
  const _MovePreview({required this.jar, required this.values, required this.withdraw, required this.rates});

  final JarView jar;
  final Map<String, Object?> values;
  final bool withdraw;
  final GoalsRates rates;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final t = context.tokens;
        final text = Theme.of(context).textTheme;
        final l = L10n.of(context);
        final texts = GoalsTexts.of(context, rates);
        final currency = jar.jar.currency;
        final amount = values['amount'] is MoneyValue ? (values['amount'] as MoneyValue).amountMilli : 0;
        final after = jar.plan.savedMilli + (withdraw ? -amount : amount);
        final target = jar.plan.targetMilli;
        final progress = target <= 0 ? (after > 0 ? 1.0 : 0.0) : (after / target).clamp(0.0, 1.0);
        final walletId = values['wallet'];
        final wallet = walletId is String ? ref.watch(goalsSnapshotProvider)?.wallets[walletId] : null;
        final lines = <String>[
          l.goalsBalanceAfter(texts.money(after, currency)),
          if (target > 0) l.goalsPercentOfTarget(texts.percent(progress)),
          if (wallet != null && wallet.currency.toUpperCase() != currency.toUpperCase() && amount > 0)
            l.goalsWalletAmount(texts.money(rates.convert(amount, currency, wallet.currency), wallet.currency)),
        ];
        final color = jar.jar.color == null ? t.accent : Color(jar.jar.color!);
        return _PreviewFrame(
          child: Row(
            children: [
              AstrolabeProgressRing(
                progress: progress,
                size: 64,
                dense: true,
                color: color,
                reached: target > 0 && after >= target,
                child: Icon(withdraw ? GoalsIcons.withdraw : GoalsIcons.deposit, size: 20, color: color),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(line, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What remains of a debt after the payment being entered.
class _DebtPaymentPreview extends StatelessWidget {
  const _DebtPaymentPreview({required this.debt, required this.values, required this.rates});

  final DebtView debt;
  final Map<String, Object?> values;
  final GoalsRates rates;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final texts = GoalsTexts.of(context, rates);
    final s = debt.state;
    final amount = values['amount'] is MoneyValue ? (values['amount'] as MoneyValue).amountMilli : 0;
    final paid = s.paidMilli + amount;
    final left = math.max(0, s.amountMilli - paid);
    final ratio = s.amountMilli <= 0 ? 1.0 : (paid / s.amountMilli).clamp(0.0, 1.0);
    final color = debt.debt.direction == DebtDirection.iOwe ? t.warning : t.success;
    return _PreviewFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            left == 0 ? l.goalsPaysOff : l.goalsRemainingAfter(texts.money(left, debt.debt.currency)),
            style: text.bodyMedium?.copyWith(color: left == 0 ? t.success : t.textPrimary),
          ),
          const SizedBox(height: Space.s),
          GoalsBar(value: ratio, color: color),
          const SizedBox(height: Space.xs),
          Text(
            l.goalsPaidOfTotal(texts.money(paid, debt.debt.currency), texts.money(s.amountMilli, debt.debt.currency)),
            style: text.labelSmall?.copyWith(color: t.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// What a debt being edited does to the wallet it went through.
class _DebtEditorPreview extends StatelessWidget {
  const _DebtEditorPreview({required this.values, required this.rates, required this.wallets});

  final Map<String, Object?> values;
  final GoalsRates rates;
  final Map<String, WalletRow> wallets;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final texts = GoalsTexts.of(context, rates);
    final iOwe = values['direction'] != DebtDirection.owedToMe.name;
    final wallet = wallets[values['wallet']];
    final amount = values['amount'];
    final String line;
    if (wallet == null || amount is! MoneyValue || amount.amountMilli <= 0) {
      line = l.goalsDebtNoWalletHint;
    } else {
      final moved = texts.money(rates.convert(amount.amountMilli, amount.currency, wallet.currency), wallet.currency);
      final name = texts.user(wallet.name);
      line = iOwe ? l.goalsDebtBorrowedInto(name, moved) : l.goalsDebtLentFrom(name, moved);
    }
    final color = wallet == null ? t.textTertiary : debtColor(t, iOwe ? DebtDirection.iOwe : DebtDirection.owedToMe);
    return _PreviewFrame(
      child: Row(
        children: [
          Icon(iOwe ? GoalsIcons.iOwe : GoalsIcons.owedToMe, color: color, size: 22),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text(
              line,
              style: text.bodySmall?.copyWith(color: wallet == null ? t.textSecondary : t.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The next due dates and monthly cost of an obligation being edited.
class _ObligationPreview extends StatelessWidget {
  const _ObligationPreview({required this.values, required this.rates, required this.today});

  final Map<String, Object?> values;
  final GoalsRates rates;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final texts = GoalsTexts.of(context, rates);
    final freq = Recurrence.values.where((r) => r.name == values['frequency']).firstOrNull ?? Recurrence.monthly;
    final interval = (values['interval'] as num?)?.toInt() ?? 1;
    final next = values['nextDue'] as DateTime? ?? today;
    final state = ObligationState.compute(frequency: freq, interval: interval, nextDue: next, today: today);
    final amount = values['amount'];
    final dates = state.upcoming(3).map((d) => texts.shortDate(d, today)).join(' · ');
    return _PreviewFrame(
      child: Row(
        children: [
          Icon(Icons.event_repeat_rounded, color: t.gold, size: 22),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texts.recurrence(freq, interval), style: text.titleSmall),
                const SizedBox(height: 2),
                Text(l.goalsNextDates(dates), style: text.bodySmall?.copyWith(color: t.textSecondary), maxLines: 2),
                if (amount is MoneyValue && amount.amountMilli > 0 && (freq != Recurrence.monthly || interval > 1))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Consumer(
                      builder: (context, ref, _) => Text(
                        l.goalsAboutPerMonth(
                          texts.money(
                            ObligationTotals.monthlyShare(
                              amount.amountMilli,
                              state.rule,
                              weeksPerMonth: ref.watch(goalsSnapshotProvider)?.weeksPerMonth ?? 4,
                            ).roundHalfUp(),
                            amount.currency,
                          ),
                        ),
                        style: text.labelSmall?.copyWith(color: t.textTertiary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Debt direction colour.
Color debtColor(MadarTokens t, DebtDirection direction) => direction == DebtDirection.iOwe ? t.warning : t.success;

/// A debt state phrase ("2 days overdue", "Due tomorrow", "Settled").
String debtDuePhrase(GoalsTexts texts, DebtState s, DateTime today) {
  final l = texts.l;
  if (s.settled) return s.settledOn == null ? l.goalsSettled : l.goalsSettledOn(texts.shortDate(s.settledOn!, today));
  if (s.dueDate == null) return l.goalsNoDueDate;
  return texts.dueRelative(s.dueDate!, today);
}
