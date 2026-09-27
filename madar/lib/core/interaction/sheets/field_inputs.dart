import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../domain/enums.dart';
import '../../i18n/gen/app_localizations.dart';
import '../../motion/motion.dart';
import '../../sound/sound_api.dart';
import '../numbers.dart';
import '../src/labels.dart';
import '../src/pressable.dart';
import 'field_spec.dart';

/// Label + input + animated inline error, shared by every field.
class FieldShell extends StatelessWidget {
  const FieldShell({
    super.key,
    required this.label,
    required this.child,
    this.icon,
    this.optional = false,
    this.error,
    this.trailing,
  });

  final String label;
  final IconData? icon;
  final bool optional;
  final String? error;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l10n = L10n.of(context);
    final motion = context.motion(MadarMotion.short);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: Space.s, start: Space.xxs),
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: t.accent), const SizedBox(width: Space.xs + 2)],
              // Label + "optional" take the free space so [trailing] sits at
              // the far end of the row.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(label, style: text.titleSmall?.copyWith(color: t.textSecondary)),
                    ),
                    if (optional)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: Space.s),
                        child: Text(l10n.interactionFieldOptional, style: text.labelSmall),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        child,
        AnimatedSize(
          duration: motion,
          curve: MadarMotion.emphasized,
          alignment: AlignmentDirectional.topStart,
          child: AnimatedSwitcher(
            duration: motion,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            child: error == null
                ? const SizedBox(width: double.infinity, key: ValueKey('ok'))
                : Padding(
                    key: ValueKey(error),
                    padding: const EdgeInsetsDirectional.only(top: Space.xs + 2, start: Space.xxs),
                    child: Semantics(
                      liveRegion: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(top: 2),
                            child: Icon(Icons.error_outline_rounded, size: 15, color: t.danger),
                          ),
                          const SizedBox(width: Space.xs),
                          Expanded(
                            child: Text(error!, style: text.bodySmall?.copyWith(color: t.danger)),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Glass input decoration consistent with the theme's input style.
InputDecoration kitInputDecoration(
  BuildContext context, {
  String? hint,
  bool error = false,
  String? suffix,
  Widget? suffixIcon,
}) {
  final t = context.tokens;
  final radius = BorderRadius.circular(t.radiusM);
  return InputDecoration(
    hintText: hint,
    suffixText: suffix,
    suffixIcon: suffixIcon,
    counterText: '',
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: error ? t.danger.withValues(alpha: 0.8) : t.glassBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: error ? t.danger : t.accent, width: 1.4),
    ),
  );
}

/// Allows digits of every script, separators and a minus sign.
final TextInputFormatter kitNumberFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9.,\u066B\u066C\-\u2212]', unicode: true),
);

/// Tappable glass "field" that opens an inline picker.
class PickerButton extends StatelessWidget {
  const PickerButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.placeholder = false,
    this.active = false,
    this.error = false,
    this.semanticLabel,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool placeholder;
  final bool active;
  final bool error;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodyLarge;
    final border = error ? t.danger : (active ? t.accent : t.glassBorder);
    return KitPressable(
      onTap: onTap,
      pressScale: 0.985,
      semanticLabel: semanticLabel,
      child: AnimatedContainer(
        duration: context.motion(MadarMotion.short),
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l, vertical: Space.m),
        decoration: BoxDecoration(
          color: active ? t.accentSoft.withValues(alpha: t.accentSoft.a * 0.7) : t.glassFill,
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: border, width: active ? 1.4 : 1),
          boxShadow: active ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.2), blurRadius: 14)] : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: active ? t.accent : t.textSecondary),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(text, style: style?.copyWith(color: placeholder ? t.textTertiary : t.textPrimary)),
            ),
            AnimatedRotation(
              turns: active ? 0.5 : 0,
              duration: context.motion(MadarMotion.short),
              child: Icon(Icons.expand_more_rounded, size: 20, color: t.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A glass chip (single / multi select, quick picks).
class KitChip extends StatelessWidget {
  const KitChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.swatch,
    this.showCheck = false,
    this.sfx,
    this.onRemove,
    this.removeLabel,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? swatch;
  final bool showCheck;
  final Sfx? sfx;
  final VoidCallback? onRemove;
  final String? removeLabel;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme.labelLarge;
    final motion = context.motion(MadarMotion.short);
    final fg = selected ? t.textOnAccent : t.textPrimary;
    return KitPressable(
      onTap: onTap,
      sfx: sfx ?? (selected ? Sfx.toggleOff : Sfx.toggleOn),
      selected: selected,
      semanticLabel: label,
      excludeSemantics: onRemove == null,
      pressScale: 0.95,
      child: AnimatedContainer(
        duration: motion,
        curve: MadarMotion.emphasized,
        height: dense ? 34 : 40,
        padding: EdgeInsetsDirectional.only(
          start: dense ? Space.m : Space.l,
          end: onRemove != null ? Space.xs : (dense ? Space.m : Space.l),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusXL),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(t.accent, t.glassHighlight, 0.2)!, t.accent],
                )
              : null,
          color: selected ? null : t.glassFill,
          border: Border.all(color: selected ? t.accent : t.glassBorder, width: 0.9),
          boxShadow: selected ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 12)] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: motion,
              curve: MadarMotion.emphasized,
              child: showCheck && selected
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(end: Space.xs),
                      child: Icon(Icons.check_rounded, size: 16, color: fg),
                    )
                  : const SizedBox.shrink(),
            ),
            if (swatch != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: swatch,
                  boxShadow: [BoxShadow(color: swatch!.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: Space.s),
            ],
            if (icon != null) ...[
              Icon(icon, size: 17, color: selected ? fg : t.textSecondary),
              const SizedBox(width: Space.xs + 2),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text?.copyWith(color: fg),
              ),
            ),
            if (onRemove != null)
              KitPressable(
                onTap: onRemove,
                sfx: Sfx.delete,
                semanticLabel: removeLabel,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(Space.xs + 2),
                  child: Icon(Icons.close_rounded, size: 15, color: selected ? fg : t.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ time wheel --

/// Hour + minute wheels (always laid out left-to-right like a clock).
class TimeWheel extends StatefulWidget {
  const TimeWheel({super.key, required this.value, required this.onChanged, this.minuteStep = 1});

  /// `"HH:mm"`.
  final String value;
  final ValueChanged<String> onChanged;
  final int minuteStep;

  @override
  State<TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<TimeWheel> {
  late int _h;
  late int _m;
  late final FixedExtentScrollController _hc;
  late final FixedExtentScrollController _mc;

  int get _minuteCount => 60 ~/ widget.minuteStep;

  @override
  void initState() {
    super.initState();
    final (h, m) = ClockTime.parts(widget.value);
    _h = h;
    _m = (m ~/ widget.minuteStep) * widget.minuteStep;
    _hc = FixedExtentScrollController(initialItem: 24 * 50 + _h);
    _mc = FixedExtentScrollController(initialItem: _minuteCount * 50 + _m ~/ widget.minuteStep);
  }

  /// True while the wheels are moved to follow a new [TimeWheel.value]; the
  /// selection callbacks they fire must not echo back to the parent (that
  /// would call setState on it in the middle of its own build).
  bool _syncing = false;

  @override
  void didUpdateWidget(TimeWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final (h, m) = ClockTime.parts(widget.value);
      final hourChanged = h != _h;
      final minuteChanged = m != _m;
      _h = h;
      _m = m;
      _syncing = true;
      try {
        if (hourChanged && _hc.hasClients) _jump(_hc, h, 24);
        if (minuteChanged && _mc.hasClients) _jump(_mc, m ~/ widget.minuteStep, _minuteCount);
      } finally {
        _syncing = false;
      }
    }
  }

  void _jump(FixedExtentScrollController c, int target, int count) {
    final current = c.selectedItem;
    final base = current - current % count;
    c.jumpToItem(base + target);
  }

  @override
  void dispose() {
    _hc.dispose();
    _mc.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(ClockTime.format(_h, _m));

  void _setHour(int h) {
    if (h == _h || _syncing) return;
    _h = h;
    Fx.fire(Sfx.countTick, volume: 0.35);
    _emit();
  }

  void _setMinute(int m) {
    if (m == _m || _syncing) return;
    _m = m;
    Fx.fire(Sfx.countTick, volume: 0.35, pitch: 1.1);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = L10n.of(context);
    Widget wheel({
      required FixedExtentScrollController controller,
      required int count,
      required int Function(int index) valueAt,
      required ValueChanged<int> onValue,
      required String label,
      required int current,
      required int step,
      required int modulo,
    }) {
      return Semantics(
        label: label,
        value: current.toString().padLeft(2, '0'),
        increasedValue: ((current + step) % modulo).toString().padLeft(2, '0'),
        decreasedValue: ((current - step + modulo) % modulo).toString().padLeft(2, '0'),
        onIncrease: () => controller.animateToItem(
          controller.selectedItem + 1,
          duration: MadarMotion.short,
          curve: MadarMotion.standard,
        ),
        onDecrease: () => controller.animateToItem(
          controller.selectedItem - 1,
          duration: MadarMotion.short,
          curve: MadarMotion.standard,
        ),
        child: SizedBox(
          width: 76,
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 42,
            diameterRatio: 1.5,
            perspective: 0.004,
            overAndUnderCenterOpacity: 0.4,
            useMagnifier: true,
            magnification: 1.18,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (i) => onValue(valueAt(i % count)),
            childDelegate: ListWheelChildLoopingListDelegate(
              children: [
                for (var i = 0; i < count; i++)
                  Center(
                    child: Text(valueAt(i).toString().padLeft(2, '0'), style: MadarTypography.numerals(t, size: 24)),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: 168,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Selection band.
            IgnorePointer(
              child: Container(
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: Space.xl),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(t.radiusM),
                  color: t.accentSoft.withValues(alpha: t.accentSoft.a * 0.8),
                  border: Border.all(color: t.accent.withValues(alpha: 0.45), width: 0.9),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                wheel(
                  controller: _hc,
                  count: 24,
                  valueAt: (i) => i,
                  onValue: _setHour,
                  label: l10n.interactionTimeHour,
                  current: _h,
                  step: 1,
                  modulo: 24,
                ),
                Text(':', style: MadarTypography.numerals(t, size: 26, color: t.accent)),
                wheel(
                  controller: _mc,
                  count: _minuteCount,
                  valueAt: (i) => i * widget.minuteStep,
                  onValue: _setMinute,
                  label: l10n.interactionTimeMinute,
                  current: _m,
                  step: widget.minuteStep,
                  modulo: 60,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ date input --

/// Inline date picker: quick chips + calendar.
class InlineDatePicker extends StatelessWidget {
  const InlineDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.allowClear = true,
    this.now,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool allowClear;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final first = firstDate ?? DateTime(today.year - 10);
    final last = lastDate ?? DateTime(today.year + 10, 12, 31);
    bool inRange(DateTime d) => !d.isBefore(first) && !d.isAfter(last);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    var initial = value ?? today;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: Space.m),
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            if (inRange(today))
              KitChip(
                dense: true,
                label: l10n.interactionDateToday,
                selected: value == today,
                sfx: Sfx.tap,
                onTap: () => onChanged(today),
              ),
            if (inRange(tomorrow))
              KitChip(
                dense: true,
                label: l10n.interactionDateTomorrow,
                selected: value == tomorrow,
                sfx: Sfx.tap,
                onTap: () => onChanged(tomorrow),
              ),
            if (allowClear && value != null)
              KitChip(
                dense: true,
                label: l10n.interactionFieldClear,
                icon: Icons.close_rounded,
                selected: false,
                sfx: Sfx.toggleOff,
                onTap: () => onChanged(null),
              ),
          ],
        ),
        CalendarDatePicker(
          key: ValueKey(initial),
          initialDate: initial,
          currentDate: today,
          firstDate: first,
          lastDate: last,
          onDateChanged: (d) {
            Fx.fire(Sfx.tap);
            onChanged(DateTime(d.year, d.month, d.day));
          },
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- switches --

class GlassSwitch extends StatelessWidget {
  const GlassSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final motion = context.motion(MadarMotion.medium);
    return Semantics(
      toggled: value,
      label: semanticLabel,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: KitPressable(
          onTap: () => onChanged(!value),
          sfx: value ? Sfx.toggleOff : Sfx.toggleOn,
          pressScale: 0.94,
          child: AnimatedContainer(
            duration: motion,
            curve: MadarMotion.emphasized,
            width: 54,
            height: 32,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: value ? t.accent : t.glassFill,
              border: Border.all(color: value ? t.accent : t.glassBorder, width: 0.9),
              boxShadow: value ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.45), blurRadius: 12)] : null,
            ),
            child: AnimatedAlign(
              duration: motion,
              curve: context.reducedMotion ? Curves.linear : Curves.easeOutBack,
              alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? t.textOnAccent : t.textSecondary,
                  boxShadow: [BoxShadow(color: t.glassShadow, blurRadius: 4, offset: const Offset(0, 1))],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- rating --

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = 5,
    this.allowClear = true,
    this.semanticLabel,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final int max;
  final bool allowClear;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = L10n.of(context);
    final v = value ?? 0;
    return Semantics(
      label: semanticLabel,
      value: l10n.interactionFieldRating(v, max),
      increasedValue: l10n.interactionFieldRating(math.min(max, v + 1), max),
      decreasedValue: l10n.interactionFieldRating(math.max(0, v - 1), max),
      onIncrease: () => onChanged(math.min(max, v + 1)),
      onDecrease: () => onChanged(v - 1 <= 0 ? null : v - 1),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 1; i <= max; i++)
              KitPressable(
                key: ValueKey('star$i'),
                sfx: null,
                pressScale: 0.85,
                onTap: () {
                  Fx.fire(Sfx.tap, pitch: 0.9 + 0.06 * i);
                  onChanged(allowClear && value == i ? null : i);
                },
                child: SizedBox.square(
                  dimension: 46,
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('s$i-${i <= v}'),
                      tween: Tween(begin: i <= v ? 0.6 : 1, end: 1),
                      duration: context.motion(MadarMotion.medium),
                      curve: context.reducedMotion ? Curves.linear : Curves.elasticOut,
                      builder: (context, s, child) => Transform.scale(scale: s, child: child),
                      child: Icon(
                        i <= v ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 34,
                        color: i <= v ? t.gold : t.textTertiary,
                        shadows: i <= v ? [Shadow(color: t.accentGlow, blurRadius: 12)] : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- slider --

class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.labels = const {},
    this.semanticLabel,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final Map<int, String> labels;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final span = math.max(1, max - min);
    final fraction = (value - min) / span;
    final tone = Color.lerp(t.success, t.danger, fraction) ?? t.accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            activeTrackColor: t.accent,
            inactiveTrackColor: t.glassBorder,
            thumbColor: t.accent,
            overlayColor: t.accentSoft,
            activeTickMarkColor: t.textOnAccent.withValues(alpha: 0.5),
            inactiveTickMarkColor: t.textTertiary.withValues(alpha: 0.5),
            valueIndicatorColor: t.space3,
            valueIndicatorTextStyle: MadarTypography.numerals(t, size: 14),
            showValueIndicator: ShowValueIndicator.onDrag,
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: span,
            label: '$value',
            semanticFormatterCallback: (v) =>
                '${v.round()}${labels[v.round()] != null ? ' – ${labels[v.round()]}' : ''}',
            onChanged: (v) {
              final r = v.round();
              if (r == value) return;
              Fx.fire(Sfx.countTick, volume: 0.4, pitch: 0.85 + 0.3 * ((r - min) / span));
              onChanged(r);
            },
          ),
        ),
        if (labels.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
            child: SizedBox(
              height: 20,
              child: Stack(
                children: [
                  for (final e in labels.entries)
                    Align(
                      alignment: AlignmentDirectional(-1 + 2 * ((e.key - min) / span), 0),
                      child: Text(
                        e.value,
                        style: text.labelSmall?.copyWith(color: e.key == value ? tone : t.textTertiary),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------- swatches --

class SwatchPicker extends StatelessWidget {
  const SwatchPicker({super.key, required this.colors, required this.value, required this.onChanged});

  final List<Color> colors;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = L10n.of(context);
    final motion = context.motion(MadarMotion.medium);
    return Wrap(
      spacing: Space.m,
      runSpacing: Space.m,
      children: [
        for (final (i, c) in colors.indexed)
          KitPressable(
            sfx: Sfx.tap,
            selected: c.toARGB32() == value,
            semanticLabel: l10n.interactionFieldColor(i + 1),
            onTap: () => onChanged(c.toARGB32()),
            child: AnimatedScale(
              duration: motion,
              curve: context.reducedMotion ? Curves.linear : Curves.easeOutBack,
              scale: c.toARGB32() == value ? 1.12 : 1,
              child: AnimatedContainer(
                duration: motion,
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    colors: [Color.lerp(c, t.glassHighlight, 0.35)!, c],
                  ),
                  border: Border.all(
                    color: c.toARGB32() == value ? t.textPrimary : t.glassBorder,
                    width: c.toARGB32() == value ? 2.2 : 0.8,
                  ),
                  boxShadow: c.toARGB32() == value
                      ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 14)]
                      : null,
                ),
                child: c.toARGB32() == value
                    ? Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? t.starTint : t.space0,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class IconGrid extends StatelessWidget {
  const IconGrid({super.key, required this.icons, required this.value, required this.onChanged});

  final Map<String, IconData> icons;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final motion = context.motion(MadarMotion.short);
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final e in icons.entries)
          KitPressable(
            sfx: Sfx.tap,
            selected: e.key == value,
            semanticLabel: e.key,
            onTap: () => onChanged(e.key),
            child: AnimatedContainer(
              duration: motion,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(t.radiusM),
                color: e.key == value ? t.accentSoft : t.glassFill,
                border: Border.all(color: e.key == value ? t.accent : t.glassBorder, width: e.key == value ? 1.4 : 0.8),
                boxShadow: e.key == value
                    ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 12)]
                    : null,
              ),
              child: Icon(e.value, size: 22, color: e.key == value ? t.accent : t.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// The six windows (+ anytime) as chips.
class PrayerWindowPicker extends StatelessWidget {
  const PrayerWindowPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.includeAnytime = true,
    this.allowClear = true,
    this.usePrayerNames = false,
  });

  final PrayerWindow? value;
  final ValueChanged<PrayerWindow?> onChanged;
  final bool includeAnytime;
  final bool allowClear;

  /// Label chips with the prayer name ("Asr") instead of the window range.
  final bool usePrayerNames;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final w in PrayerWindow.values)
          if (includeAnytime || w != PrayerWindow.anytime)
            KitChip(
              label: usePrayerNames ? KitLabels.prayer(l10n, w) : KitLabels.window(l10n, w),
              icon: KitLabels.windowIcon(w),
              selected: value == w,
              sfx: Sfx.tap,
              onTap: () => onChanged(allowClear && value == w ? null : w),
            ),
      ],
    );
  }
}

/// Formats a number field's value bound for display in a hint.
String kitNumberText(num v) => LocalizedNumbers.formatNum(v);
