import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/database.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/interaction/sheets/field_inputs.dart' show TimeWheel;
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/wellbeing_providers.dart';
import '../../domain/wellbeing_data.dart';
import '../wellbeing_texts.dart';

/// A titled glass card used across the wellbeing tabs.
class WbCard extends StatelessWidget {
  const WbCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.l),
    this.tint,
    this.onTap,
    this.seed = 0,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final VoidCallback? onTap;
  final double seed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: padding,
      tint: tint,
      onTap: onTap,
      seed: seed,
      borderRadius: BorderRadius.circular(t.radiusL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: t.gold), const SizedBox(width: Space.s)],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title!, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: Space.m),
          ],
          child,
        ],
      ),
    );
  }
}

/// Multi-select chips over one editable vocabulary, with "+ Add" and an
/// optional "Edit list" entry. Labels selected but no longer in the list
/// (renamed elsewhere, imported) still show, so nothing is lost silently.
class WbTagPicker extends ConsumerWidget {
  const WbTagPicker({
    super.key,
    required this.kind,
    required this.selected,
    required this.onChanged,
    required this.label,
    this.icon,
    this.onManage,
    this.color,
  });

  final TagKind kind;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String label;
  final IconData? icon;
  final VoidCallback? onManage;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final options = ref.watch(wellbeingTagsProvider(kind)).value ?? const <TagOptionRow>[];
    final labels = [for (final o in options) o.label];
    final extra = [
      for (final s in selected)
        if (!labels.contains(s)) s,
    ];
    void toggle(String v) {
      final next = selected.contains(v)
          ? [
              for (final s in selected)
                if (s != v) s,
            ]
          : [...selected, v];
      onChanged(next);
    }

    Future<void> add() async {
      final result = await showEditSheet(
        context,
        title: l.wbTagAddTitle(WbTexts.of(context).tagKindName(kind)),
        icon: Icons.add_rounded,
        fields: [FieldSpec.text('label', l.wbTagName, required: true, autofocus: true, maxLength: 40)],
        saveLabel: l.wbAdd,
      );
      final value = (result?['label'] as String?)?.trim();
      if (value == null || value.isEmpty) return;
      final row = await ref.read(wellbeingServiceProvider).addTag(kind, value);
      if (row != null && !selected.contains(row.label)) onChanged([...selected, row.label]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: color ?? t.gold), const SizedBox(width: Space.s)],
            Expanded(child: Text(label, style: text.titleSmall)),
            if (onManage != null)
              MadarButton(
                label: l.wbEditList,
                icon: Icons.tune_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetOpen,
                onPressed: onManage,
              ),
          ],
        ),
        const SizedBox(height: Space.s),
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final o in [...labels, ...extra])
              MadarChip(
                label: o,
                selected: selected.contains(o),
                color: color,
                showCheck: true,
                dense: true,
                sfx: null,
                onSelected: (_) {
                  Fx.fire(selected.contains(o) ? Sfx.toggleOff : Sfx.toggleOn);
                  toggle(o);
                },
              ),
            MadarChip(
              label: l.wbAdd,
              icon: Icons.add_rounded,
              dense: true,
              sfx: Sfx.sheetOpen,
              onSelected: (_) => add(),
            ),
          ],
        ),
      ],
    );
  }
}

/// "When": today / yesterday chips and an inline clock, collapsed to one
/// line until tapped. Defaults to now.
class WbWhenField extends StatefulWidget {
  const WbWhenField({super.key, required this.value, required this.onChanged, required this.now});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime now;

  @override
  State<WbWhenField> createState() => _WbWhenFieldState();
}

class _WbWhenFieldState extends State<WbWhenField> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = WbTexts.of(context);
    final v = widget.value;
    final today = WbDays.dateOf(widget.now);
    final day = WbDays.dateOf(v);
    String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    DateTime withDay(DateTime d) => DateTime(d.year, d.month, d.day, v.hour, v.minute);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MadarPressable(
          semanticLabel: '${l.wbWhen}: ${tx.dayTime(v, today)}',
          sfx: _open ? Sfx.sheetClose : Sfx.tap,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: t.gold),
                const SizedBox(width: Space.s),
                Text(l.wbWhen, style: text.titleSmall),
                const Spacer(),
                Text(tx.dayTime(v, today), style: text.bodyMedium?.copyWith(color: t.textPrimary)),
                const SizedBox(width: Space.xs),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: context.motion(MadarMotion.short),
                  child: Icon(Icons.expand_more_rounded, size: 20, color: t.textSecondary),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.standard,
          alignment: AlignmentDirectional.topStart,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Space.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: Space.s,
                        runSpacing: Space.s,
                        children: [
                          for (var back = 0; back <= 2; back++)
                            MadarChip(
                              label: tx.relativeDay(WbDays.add(today, -back), today),
                              selected: day == WbDays.add(today, -back),
                              dense: true,
                              onSelected: (_) => widget.onChanged(withDay(WbDays.add(today, -back))),
                            ),
                          MadarChip(
                            label: l.wbNow,
                            icon: Icons.bolt_rounded,
                            dense: true,
                            onSelected: (_) => widget.onChanged(widget.now),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.s),
                      TimeWheel(
                        value: hhmm(v),
                        onChanged: (s) {
                          final parts = s.split(':');
                          widget.onChanged(DateTime(v.year, v.month, v.day, int.parse(parts[0]), int.parse(parts[1])));
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// A small glowing pill with a value (e.g. "stress 6/10").
class WbValuePill extends StatelessWidget {
  const WbValuePill({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.xxs + 1, Space.s + 2, Space.xxs + 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: Space.xs)],
          Text(label, style: text.labelMedium?.copyWith(color: t.textPrimary)),
        ],
      ),
    );
  }
}

/// Range pills (e.g. 7 / 30 / 90 days).
class WbRangePills extends StatelessWidget {
  const WbRangePills({super.key, required this.values, required this.value, required this.onChanged});

  final List<int> values;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tx = WbTexts.of(context);
    return ChoicePills<int>.single(
      options: [for (final d in values) ChoiceOption(value: d, label: tx.daysShort(d))],
      selected: value,
      dense: true,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Empty/hint line inside a card.
class WbHint extends StatelessWidget {
  const WbHint(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary, height: 1.5);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon ?? Icons.auto_awesome_outlined, size: 16, color: t.textTertiary),
        const SizedBox(width: Space.s),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// Wraps a service undo into the kit's [UndoableAction].
UndoableAction? wbUndo(String label, Future<void> Function()? undo) =>
    undo == null ? null : UndoableAction(label: label, undo: undo);

/// A chevron pointing in the reading direction (forward); the icon mirrors
/// itself in right-to-left layouts.
IconData wbForwardChevron(BuildContext context) => Icons.chevron_right_rounded;
