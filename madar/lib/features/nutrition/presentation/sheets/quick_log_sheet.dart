import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/interaction/sheets/field_inputs.dart'
    show FieldShell, KitChip, PickerButton, TimeWheel, kitInputDecoration, kitNumberFormatter;
import '../../../../core/interaction/src/labels.dart' show KitLabels;
import '../../../../core/sound/sound_api.dart';
import '../../../body/domain/body_clock.dart';
import '../../data/nutrition_providers.dart';
import '../../domain/food_library.dart';
import '../../domain/food_log.dart';
import '../nutrition_actions.dart';
import '../nutrition_texts.dart';
import '../widgets/nutrition_widgets.dart';

/// Opens the quick-log sheet and shows the undo toast for whatever was
/// logged. The fastest path in the app: one tap on a chip is a logged meal.
///
/// [slotId] ties what he logs to a planned meal (the sheet opened from a
/// slot); [at] overrides the day and the starting time.
Future<void> showQuickLogSheet(BuildContext context, {String? slotId, DateTime? at}) async {
  final action = await showInteractionSheet<UndoableAction>(
    context,
    builder: (_) => QuickLogSheet(slotId: slotId, at: at),
  );
  if (action == null || !context.mounted) return;
  unawaited(showUndoToast(context, action));
}

/// The body of [showQuickLogSheet] (public for tests).
class QuickLogSheet extends ConsumerStatefulWidget {
  const QuickLogSheet({super.key, this.slotId, this.at});

  final String? slotId;
  final DateTime? at;

  @override
  ConsumerState<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends ConsumerState<QuickLogSheet> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _portion = TextEditingController();
  final TextEditingController _unit = TextEditingController();
  String _query = '';
  int? _minutes;
  bool _timeOpen = false;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    _portion.dispose();
    _unit.dispose();
    super.dispose();
  }

  /// The instant being logged: the day of [widget.at] (today by default) at
  /// the chosen minute, or exactly now while he has not touched the time.
  DateTime _when() {
    final now = ref.read(nutritionClockProvider)();
    final base = widget.at ?? now;
    final minutes = _minutes;
    if (minutes == null) return base;
    return DateTime(base.year, base.month, base.day, minutes ~/ 60, minutes % 60);
  }

  double? _portionValue() {
    final text = _portion.text.trim();
    if (text.isEmpty) return null;
    final v = LocalizedNumbers.parse(text);
    return v == null || v <= 0 ? null : v.toDouble();
  }

  String? _unitValue() {
    final text = _unit.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _finish(Future<UndoableAction?> Function() work) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final action = await work();
      if (!mounted) return;
      Navigator.of(context).pop(action);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _logUsage(FoodUsage usage) => unawaited(
    _finish(() async {
      // A portion or a unit typed in the sheet wins over the food's own.
      final portion = _portionValue();
      final unit = _unitValue();
      final food = usage.foodId == null
          ? null
          : ref.read(nutritionFoodsProvider).where((f) => f.id == usage.foodId).firstOrNull;
      if (food != null) {
        return NutritionActions.logFood(
          context,
          ref,
          food,
          at: _when(),
          portion: portion,
          unit: unit,
          slotId: widget.slotId,
        );
      }
      if (portion == null && unit == null) {
        return NutritionActions.logAgain(context, ref, usage, at: _when());
      }
      return NutritionActions.logNewFood(
        context,
        ref,
        usage.name,
        at: _when(),
        portion: portion,
        unit: unit,
        slotId: widget.slotId,
      );
    }),
  );

  void _logFood(Food food) => unawaited(
    _finish(
      () => NutritionActions.logFood(
        context,
        ref,
        food,
        at: _when(),
        portion: _portionValue(),
        unit: _unitValue(),
        slotId: widget.slotId,
      ),
    ),
  );

  void _logTyped() {
    final text = _query.trim();
    if (text.isEmpty) return;
    unawaited(
      _finish(
        () => NutritionActions.logNewFood(
          context,
          ref,
          text,
          at: _when(),
          portion: _portionValue(),
          unit: _unitValue(),
          slotId: widget.slotId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = NutritionTexts.of(context);
    final p = NutritionPalette.of(context);
    final text = Theme.of(context).textTheme;
    final typed = _query.trim();
    final matches = typed.isEmpty ? const <FoodMatch>[] : ref.watch(nutritionFoodSearchProvider(typed));
    final frequent = ref.watch(nutritionFrequentProvider);
    final recent = ref.watch(nutritionRecentProvider);
    final exact = matches.where((m) => FoodLookup.sameWord(m.food.name, typed)).isNotEmpty;
    final nothing = frequent.isEmpty && recent.isEmpty;

    Widget section(String title) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, Space.m, 0, Space.s),
      child: Semantics(
        header: true,
        child: Text(title, style: text.titleSmall?.copyWith(color: t.textSecondary)),
      ),
    );

    return InteractionSheetFrame(
      title: l.nutritionLogTitle,
      subtitle: l.nutritionLogSubtitle,
      icon: Icons.restaurant_rounded,
      toolbar: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.s),
        child: TextField(
          key: const ValueKey('nutrition.quickLog.search'),
          controller: _search,
          textInputAction: TextInputAction.done,
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: (_) => _logTyped(),
          decoration: kitInputDecoration(
            context,
            hint: l.nutritionSearchHint,
            suffixIcon: Icon(Icons.search_rounded, size: 20, color: t.textTertiary),
          ),
        ),
      ),
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(
              key: const ValueKey('nutrition.quickLog.save'),
              label: typed.isEmpty ? l.nutritionQuickLog : l.nutritionAddNew(tx.name(typed)),
              icon: Icons.check_rounded,
              primary: true,
              enabled: typed.isNotEmpty && !_busy,
              sfx: Sfx.complete,
              onPressed: _logTyped,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The time and the amount: both optional, both above the chips so
          // one tap below lands with them already set.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FieldShell(
                  label: l.nutritionLogWhen,
                  icon: Icons.schedule_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PickerButton(
                        icon: Icons.schedule_rounded,
                        text: _minutes == null ? l.nutritionLogNow : KitLabels.time(context, BodyTimes.format(_minutes!)),
                        placeholder: false,
                        active: _timeOpen,
                        semanticLabel: l.nutritionChangeTime,
                        onTap: () => setState(() {
                          final now = ref.read(nutritionClockProvider)();
                          _minutes ??= now.hour * 60 + now.minute;
                          _timeOpen = !_timeOpen;
                        }),
                      ),
                      if (_timeOpen) ...[
                        const SizedBox(height: Space.s),
                        TimeWheel(
                          value: BodyTimes.format(_minutes ?? 0),
                          onChanged: (v) => setState(() => _minutes = BodyTimes.parse(v) ?? _minutes),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FieldShell(
                  label: l.nutritionPortionLabel,
                  icon: Icons.straighten_rounded,
                  child: TextField(
                    key: const ValueKey('nutrition.quickLog.portion'),
                    controller: _portion,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [kitNumberFormatter],
                    decoration: kitInputDecoration(context),
                  ),
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: FieldShell(
                  label: l.nutritionUnitLabel,
                  child: TextField(
                    key: const ValueKey('nutrition.quickLog.unit'),
                    controller: _unit,
                    maxLength: 24,
                    decoration: kitInputDecoration(context, hint: l.nutritionUnitHint),
                  ),
                ),
              ),
            ],
          ),

          if (typed.isNotEmpty) ...[
            section(l.nutritionSearchLabel),
            if (matches.isEmpty)
              BodyHintLine(l.nutritionNoResults)
            else
              for (final m in matches.take(12))
                _FoodRow(
                  key: ValueKey('nutrition.quickLog.match.${m.food.id}'),
                  title: m.food.name,
                  subtitle: m.food.tags.isEmpty ? null : m.food.tags.join(l.nutritionListSep),
                  icon: m.food.favorite ? Icons.star_rounded : Icons.restaurant_rounded,
                  color: p.food,
                  onTap: () => _logFood(m.food),
                ),
            if (!exact)
              _FoodRow(
                key: const ValueKey('nutrition.quickLog.new'),
                title: l.nutritionAddNew(tx.name(typed)),
                subtitle: l.nutritionAddNewHint,
                icon: Icons.add_circle_outline_rounded,
                color: p.plan,
                onTap: _logTyped,
              ),
          ] else ...[
            if (nothing)
              Padding(
                padding: const EdgeInsets.only(top: Space.l),
                child: BodyHintLine(l.nutritionNoResults),
              ),
            if (frequent.isNotEmpty) ...[
              section(l.nutritionFrequent),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final u in frequent)
                    KitChip(
                      key: ValueKey('nutrition.quickLog.frequent.${u.key}'),
                      label: u.name,
                      selected: false,
                      icon: Icons.restaurant_rounded,
                      sfx: Sfx.tap,
                      onTap: () => _logUsage(u),
                    ),
                ],
              ),
            ],
            if (recent.isNotEmpty) ...[
              section(l.nutritionRecent),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final u in recent)
                    KitChip(
                      key: ValueKey('nutrition.quickLog.recent.${u.key}'),
                      label: u.name,
                      selected: false,
                      icon: Icons.history_rounded,
                      sfx: Sfx.tap,
                      onTap: () => _logUsage(u),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// A quiet one-line hint inside a sheet.
class BodyHintLine extends StatelessWidget {
  const BodyHintLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.info_outline_rounded, size: 14, color: t.textTertiary),
        ),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary)),
        ),
      ],
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final sub = subtitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.m, Space.s + 2),
        borderRadius: BorderRadius.circular(context.tokens.radiusM),
        onTap: onTap,
        semanticLabel: sub == null ? title : '$title. $sub',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48 - 2 * (Space.s + 2)),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (sub != null)
                        Text(sub, style: text.bodySmall?.copyWith(color: t.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
