import 'package:flutter/material.dart';

import '../../motion/motion.dart';
import '../../sound/sound_api.dart';
import '../tokens.dart';
import 'glass.dart';
import 'pressable.dart';

/// Pure selection rules for [ChoicePills] (unit-tested).
abstract final class ChoiceSelection {
  /// Result of tapping [tapped] in a single-select group.
  static T? toggleSingle<T>(T? current, T tapped, {bool allowDeselect = false}) {
    if (current == tapped) return allowDeselect ? null : current;
    return tapped;
  }

  /// Result of tapping [tapped] in a multi-select group. Returns [current]
  /// unchanged (identical instance) when the tap would break
  /// [minSelected] / [maxSelected] – callers treat that as a rejection.
  static Set<T> toggleMulti<T>(Set<T> current, T tapped, {int minSelected = 0, int? maxSelected}) {
    if (current.contains(tapped)) {
      if (current.length <= minSelected) return current;
      return {...current}..remove(tapped);
    }
    if (maxSelected != null && current.length >= maxSelected) return current;
    return {...current, tapped};
  }
}

/// A selectable pill. Unselected it is quiet glass; selected it fills with
/// [color] (default: accent), gains a glowing rim and brightens its label.
class MadarChip extends StatelessWidget {
  const MadarChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.color,
    this.showCheck = false,
    this.showDot = false,
    this.sfx = Sfx.tap,
    this.dense = false,
  });

  final String label;
  final bool selected;

  /// Called with the requested new state; `null` makes the chip read-only.
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  /// Selection colour (e.g. a planet colour). Defaults to the theme accent.
  final Color? color;

  /// Show a check mark when selected (multi-select groups).
  final bool showCheck;

  /// Show a small [color] dot before the label.
  final bool showDot;

  /// Feedback on tap; `null` when a parent fires its own.
  final Sfx? sfx;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = color ?? t.accent;
    final text = Theme.of(context).textTheme.labelLarge!;
    final h = dense ? 32.0 : 38.0;
    return MadarPressable(
      onTap: onSelected == null ? null : () => onSelected!(!selected),
      sfx: sfx,
      selected: selected,
      semanticLabel: label,
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(h / 2),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selected ? 1 : 0),
        duration: context.motion(MadarMotion.short),
        curve: MadarMotion.standard,
        builder: (context, v, _) {
          final fg = Color.lerp(t.textSecondary, t.textPrimary, v)!;
          final leading = <Widget>[
            if (showCheck && v > 0.01)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: Space.xs + 2),
                child: SizedBox(
                  width: 16 * v,
                  child: Opacity(
                    opacity: v,
                    child: Icon(Icons.check_rounded, size: 16, color: accent),
                  ),
                ),
              )
            else if (icon != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: Space.xs + 2),
                child: Icon(icon, size: 16, color: Color.lerp(t.textTertiary, accent, v)),
              )
            else if (showDot)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: Space.s),
                child: _Dot(color: accent, glow: v),
              ),
          ];
          return CustomPaint(
            painter: ChipPainter(
              selection: v,
              fill: Color.alphaBlend(t.glassFill, t.space2.withValues(alpha: t.isDark ? 0.45 : 0.4)),
              border: t.glassBorder,
              accent: accent,
              highlight: t.glassHighlight,
            ),
            child: SizedBox(
              height: h,
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(horizontal: dense ? Space.m : Space.l - 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...leading,
                    Text(
                      label,
                      maxLines: 1,
                      style: text.copyWith(
                        color: fg,
                        fontSize: dense ? 12.5 : 13.5,
                        fontWeight: v > 0.5 ? FontWeight.w600 : FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.glow});

  final Color color;
  final double glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7 * glow), blurRadius: 6)],
      ),
    );
  }
}

/// Paints a chip pill at a given [selection] (0..1) blend.
class ChipPainter extends CustomPainter {
  const ChipPainter({
    required this.selection,
    required this.fill,
    required this.border,
    required this.accent,
    required this.highlight,
  });

  final double selection;
  final Color fill;
  final Color border;
  final Color accent;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final v = selection.clamp(0.0, 1.0);
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    if (v > 0) {
      paintOuterGlow(canvas, rrect, accent.withValues(alpha: 0.45 * v), 6);
    }
    canvas.drawRRect(
      rrect,
      Paint()..color = Color.lerp(fill, Color.alphaBlend(accent.withValues(alpha: 0.22), fill), v)!,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            highlight.withValues(alpha: highlight.a * (0.12 + 0.1 * v)),
            highlight.withValues(alpha: 0),
          ],
          stops: const [0, 0.6],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Color.lerp(border, accent.withValues(alpha: 0.85), v)!,
    );
  }

  @override
  bool shouldRepaint(ChipPainter old) =>
      old.selection != selection ||
      old.fill != fill ||
      old.border != border ||
      old.accent != accent ||
      old.highlight != highlight;
}

/// One option of a [ChoicePills] group.
@immutable
class ChoiceOption<T> {
  const ChoiceOption({required this.value, required this.label, this.icon, this.color});

  final T value;
  final String label;
  final IconData? icon;

  /// Per-option selection colour (e.g. planet colours); shows a dot.
  final Color? color;
}

/// A group of [MadarChip]s with single- or multi-select semantics.
///
/// Rejected taps (min/max limits) play [Sfx.error] instead of changing.
class ChoicePills<T> extends StatelessWidget {
  /// Exactly one (or, with [allowDeselect], at most one) option selected.
  const ChoicePills.single({
    super.key,
    required this.options,
    required this._selected,
    required ValueChanged<T?> onChanged,
    this.allowDeselect = false,
    this.scrollable = false,
    this.spacing = Space.s,
    this.runSpacing = Space.s,
    this.dense = false,
    this.padding = EdgeInsetsDirectional.zero,
  }) : _onSingle = onChanged,
       _selectedSet = null,
       _onMulti = null,
       minSelected = 0,
       maxSelected = 1,
       showCheck = false;

  /// Any number of options (bounded by [minSelected]/[maxSelected]).
  const ChoicePills.multi({
    super.key,
    required this.options,
    required Set<T> selected,
    required ValueChanged<Set<T>> onChanged,
    this.minSelected = 0,
    this.maxSelected,
    this.showCheck = true,
    this.scrollable = false,
    this.spacing = Space.s,
    this.runSpacing = Space.s,
    this.dense = false,
    this.padding = EdgeInsetsDirectional.zero,
  }) : _selectedSet = selected,
       _onMulti = onChanged,
       _selected = null,
       _onSingle = null,
       allowDeselect = true;

  final List<ChoiceOption<T>> options;
  final bool allowDeselect;
  final int minSelected;
  final int? maxSelected;
  final bool showCheck;

  /// One horizontally scrolling row instead of a wrapping block.
  final bool scrollable;
  final double spacing;
  final double runSpacing;
  final bool dense;
  final EdgeInsetsGeometry padding;

  final T? _selected;
  final ValueChanged<T?>? _onSingle;
  final Set<T>? _selectedSet;
  final ValueChanged<Set<T>>? _onMulti;

  bool get isMulti => _onMulti != null;

  bool isSelected(T value) => isMulti ? _selectedSet!.contains(value) : _selected == value;

  void _tap(T value) {
    if (isMulti) {
      final current = _selectedSet!;
      final next = ChoiceSelection.toggleMulti(current, value, minSelected: minSelected, maxSelected: maxSelected);
      if (identical(next, current)) {
        Fx.fire(Sfx.error);
        return;
      }
      Fx.fire(next.contains(value) ? Sfx.toggleOn : Sfx.toggleOff);
      _onMulti!(next);
    } else {
      final next = ChoiceSelection.toggleSingle(_selected, value, allowDeselect: allowDeselect);
      if (next == _selected) return;
      Fx.fire(Sfx.tap);
      _onSingle!(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final o in options)
        MadarChip(
          label: o.label,
          icon: o.icon,
          color: o.color,
          showDot: o.color != null && o.icon == null,
          selected: isSelected(o.value),
          showCheck: showCheck,
          dense: dense,
          sfx: null,
          onSelected: (_) => _tap(o.value),
        ),
    ];
    final Widget body;
    if (scrollable) {
      body = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[if (i > 0) SizedBox(width: spacing), chips[i]],
          ],
        ),
      );
    } else {
      body = Padding(
        padding: padding,
        child: Wrap(spacing: spacing, runSpacing: runSpacing, children: chips),
      );
    }
    return Semantics(container: true, explicitChildNodes: true, child: body);
  }
}
