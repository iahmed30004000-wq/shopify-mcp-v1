import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/db/database.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart'
    show FieldShell, InlineDatePicker, KitChip, PickerButton, TimeWheel, kitInputDecoration, kitNumberFormatter;
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/growth_providers.dart';
import '../data/growth_service.dart';
import '../domain/goal_math.dart';
import '../domain/growth_days.dart';
import '../domain/growth_goal.dart';
import 'growth_texts.dart';
import 'widgets/growth_widgets.dart';

/// Logs progress on [goal] – or edits [log] – and returns the draft (null
/// when dismissed).
Future<GoalLogDraft?> showLogProgressSheet(BuildContext context, {required GrowthGoal goal, GoalLogRow? log}) =>
    showInteractionSheet<GoalLogDraft>(
      context,
      builder: (_) => LogProgressSheet(goal: goal, log: log),
    );

/// The log sheet: a big amount with − / + and one-tap chips in the goal's
/// unit, a live preview of the new total (and of reaching the target), the
/// time (now by default, editable) and a note.
class LogProgressSheet extends ConsumerStatefulWidget {
  const LogProgressSheet({super.key, required this.goal, this.log});

  final GrowthGoal goal;
  final GoalLogRow? log;

  @override
  ConsumerState<LogProgressSheet> createState() => _LogProgressSheetState();
}

class _LogProgressSheetState extends ConsumerState<LogProgressSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _at;
  bool _atEdited = false;
  bool _dateOpen = false;
  bool _timeOpen = false;
  bool _error = false;
  bool _formatted = false;

  GrowthGoal get goal => widget.goal;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController()..addListener(_changed);
    _note = TextEditingController(text: widget.log?.note ?? '');
    _at = widget.log?.at ?? ref.read(growthClockProvider)();
    _atEdited = widget.log != null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_formatted) return;
    _formatted = true;
    _setAmount(widget.log?.amount ?? goal.usualAmount, silent: true);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _changed() => setState(() {
    if (_error && (_parsed ?? 0) > 0) _error = false;
  });

  double? get _parsed {
    final v = LocalizedNumbers.parse(_amount.text.trim());
    return v?.toDouble();
  }

  void _setAmount(double v, {bool silent = false}) {
    final text = GrowthTexts.of(context).fmt.formatNumber(v, maxDecimals: 2, grouping: false);
    _amount.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    if (!silent) setState(() {});
  }

  void _step(int dir) {
    final step = goal.unit.stepFor(goal.row.target);
    final current = _parsed ?? 0;
    // Snap to the step grid first (7 − 5 → 5, not 2).
    final snapped = dir > 0
        ? ((current / step + 1e-9).floor() + 1) * step
        : ((current / step - 1e-9).ceil() - 1) * step;
    _setAmount(math.max(0, snapped));
  }

  void _save() {
    final amount = _parsed;
    if (amount == null || amount <= 0) {
      Fx.fire(Sfx.error);
      setState(() => _error = true);
      return;
    }
    final at = _atEdited ? _at : ref.read(growthClockProvider)();
    Navigator.of(context).pop(GoalLogDraft(amount: amount, at: at, note: _note.text));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final text = Theme.of(context).textTheme;
    final today = ref.watch(growthTodayProvider);
    final color = GrowthColors.goal(t, goal.color);
    final editing = widget.log != null;
    final amount = _parsed ?? 0;
    final before = goal.stats.current - (widget.log?.amount ?? 0);
    final after = before + math.max(0, amount);
    final target = goal.row.target;
    final completes = !editing && GoalMath.crossesTarget(before: before, added: amount, target: target);
    final unitName = goal.unit.isEmpty ? null : texts.unitName(goal.unit);

    final atDay = GrowthDays.dateOnly(_at);
    final timeText = !_atEdited ? l.growthLogNow : texts.fmt.formatTime(_at);

    return InteractionSheetFrame(
      title: editing ? l.growthEditLog : l.growthLogProgress,
      subtitle: goal.name,
      icon: GrowthColors.unitIcon(goal.unit),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The amount: − big number + (the − sits on the reading side).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.m),
            decoration: BoxDecoration(
              color: t.glassFill,
              borderRadius: BorderRadius.circular(t.radiusL),
              border: Border.all(color: _error ? t.danger : color.withValues(alpha: 0.45), width: _error ? 1.4 : 1),
              boxShadow: [BoxShadow(color: color.withValues(alpha: t.isDark ? 0.18 : 0.1), blurRadius: 24)],
            ),
            child: Row(
              children: [
                MadarButton.icon(
                  icon: Icons.remove_rounded,
                  onPressed: amount > 0 ? () => _step(-1) : null,
                  semanticLabel: l.growthDecrease,
                  variant: MadarButtonVariant.secondary,
                  sfx: Sfx.countTick,
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        key: const ValueKey('growth-log-amount'),
                        controller: _amount,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [kitNumberFormatter],
                        style: text.displaySmall!.copyWith(
                          color: t.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (unitName != null) Text(unitName, style: text.labelLarge!.copyWith(color: t.textSecondary)),
                    ],
                  ),
                ),
                MadarButton.icon(
                  icon: Icons.add_rounded,
                  onPressed: () => _step(1),
                  semanticLabel: l.growthIncrease,
                  variant: MadarButtonVariant.secondary,
                  sfx: Sfx.countTick,
                ),
              ],
            ),
          ),
          if (_error)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.xs, start: Space.xs),
              child: Text(l.growthErrorAmount, style: text.labelMedium!.copyWith(color: t.danger)),
            ),
          const SizedBox(height: Space.m),
          Center(
            child: QuickAmountChips(goal: goal, selected: amount, onLog: _setAmount),
          ),
          const SizedBox(height: Space.l),
          _TotalPreview(
            before: before,
            after: after,
            target: target,
            color: color,
            completes: completes,
            label: l.growthLogNewTotal(
              l.growthProgressOf(texts.number(after), texts.amount(goal.unit, target)),
              texts.percent(target > 0 ? after / target : 1),
            ),
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.growthLogWhen,
            icon: Icons.schedule_rounded,
            trailing: _atEdited
                ? KitChip(
                    label: l.growthLogNow,
                    dense: true,
                    selected: false,
                    icon: Icons.restart_alt_rounded,
                    onTap: () => setState(() {
                      _atEdited = false;
                      _at = ref.read(growthClockProvider)();
                      _dateOpen = _timeOpen = false;
                    }),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PickerButton(
                        icon: Icons.event_rounded,
                        text: texts.dayLabel(atDay, today),
                        active: _dateOpen,
                        semanticLabel: l.growthLogDate,
                        onTap: () => setState(() {
                          _dateOpen = !_dateOpen;
                          _timeOpen = false;
                        }),
                      ),
                    ),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: PickerButton(
                        icon: Icons.access_time_rounded,
                        text: timeText,
                        active: _timeOpen,
                        semanticLabel: l.growthLogTime,
                        onTap: () => setState(() {
                          _timeOpen = !_timeOpen;
                          _dateOpen = false;
                        }),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: context.motion(MadarMotion.medium),
                  curve: MadarMotion.emphasized,
                  alignment: AlignmentDirectional.topStart,
                  child: _dateOpen
                      ? InlineDatePicker(
                          value: atDay,
                          now: today,
                          allowClear: false,
                          lastDate: today,
                          onChanged: (d) {
                            if (d == null) return;
                            setState(() {
                              _atEdited = true;
                              _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute);
                            });
                          },
                        )
                      : _timeOpen
                      ? Padding(
                          padding: const EdgeInsets.only(top: Space.s),
                          child: TimeWheel(
                            value: _hhmm(_at),
                            onChanged: (v) {
                              final parts = v.split(':');
                              setState(() {
                                _atEdited = true;
                                _at = DateTime(_at.year, _at.month, _at.day, int.parse(parts[0]), int.parse(parts[1]));
                              });
                            },
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.growthLogNote,
            icon: Icons.notes_rounded,
            optional: true,
            child: TextField(
              key: const ValueKey('growth-log-note'),
              controller: _note,
              minLines: 1,
              maxLines: 3,
              maxLength: 280,
              textCapitalization: TextCapitalization.sentences,
              decoration: kitInputDecoration(context, hint: l.growthLogNoteHint),
            ),
          ),
          const SizedBox(height: Space.s),
        ],
      ),
      footer: SheetButton(
        label: editing ? l.growthSave : l.growthLogSave,
        primary: true,
        icon: editing ? Icons.check_rounded : Icons.add_task_rounded,
        sfx: null,
        onPressed: _save,
      ),
    );
  }

  static String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// The new total as a bar: what was there, what this log adds (glowing),
/// and a note when it reaches the target.
class _TotalPreview extends StatelessWidget {
  const _TotalPreview({
    required this.before,
    required this.after,
    required this.target,
    required this.color,
    required this.completes,
    required this.label,
  });

  final double before;
  final double after;
  final double target;
  final Color color;
  final bool completes;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final scale = math.max(target, after);
    final a = scale <= 0 ? 0.0 : (before / scale).clamp(0.0, 1.0);
    final b = scale <= 0 ? 0.0 : (after / scale).clamp(0.0, 1.0);
    final motion = context.motion(MadarMotion.medium);
    return Semantics(
      liveRegion: true,
      label: completes ? '$label. ${l.growthLogWillComplete}' : label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
          const SizedBox(height: Space.s),
          SizedBox(
            height: 10,
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: t.glassFill,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: t.glassBorder, width: 0.8),
                      ),
                    ),
                    AnimatedPositionedDirectional(
                      duration: motion,
                      curve: MadarMotion.emphasized,
                      start: 0,
                      top: 0,
                      bottom: 0,
                      width: w * b,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: GrowthColors.glow(t, color),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      bottom: 0,
                      width: w * a,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          AnimatedSize(
            duration: motion,
            alignment: AlignmentDirectional.topStart,
            child: completes
                ? Padding(
                    padding: const EdgeInsets.only(top: Space.s),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 18, color: t.gold),
                        const SizedBox(width: Space.s),
                        Expanded(
                          child: Text(l.growthLogWillComplete, style: text.labelLarge!.copyWith(color: t.gold)),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
