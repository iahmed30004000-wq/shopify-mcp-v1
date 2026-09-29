import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/body_providers.dart';
import '../../domain/body_clock.dart';
import '../../domain/body_week.dart';
import '../body_texts.dart';

/// The Body planet's semantic colours, derived from the theme tokens (so
/// all five themes, Pearl included, keep their contrast).
class BodyPalette {
  BodyPalette(this.t);

  factory BodyPalette.of(BuildContext context) => BodyPalette(context.tokens);

  final MadarTokens t;

  /// Training: an ember between the theme's warning and danger.
  Color get training => Color.lerp(t.warning, t.danger, 0.35)!;
  Color get trainingEnd => t.gold;
  Color get water => t.info;
  Color get waterEnd => Color.lerp(t.info, t.highlight, 0.6)!;
  Color get fasting => t.gold;
  Color get fastingEnd => Color.lerp(t.secondary, t.info, 0.25)!;
  Color get eating => t.success;
  Color get avoid => t.danger;
}

/// A titled glass card used across the Body tabs.
class BodyCard extends StatelessWidget {
  const BodyCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.iconColor,
    this.trailing,
    this.padding = const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.l),
    this.tint,
    this.glowColor,
    this.onTap,
    this.semanticLabel,
    this.seed = 0,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final Color? glowColor;
  final VoidCallback? onTap;
  final String? semanticLabel;
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
      semanticLabel: semanticLabel,
      glow: glowColor != null,
      glowColor: glowColor,
      borderRadius: BorderRadius.circular(t.radiusL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: iconColor ?? t.gold), const SizedBox(width: Space.s)],
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

/// A quiet one-line hint with an icon.
class BodyHint extends StatelessWidget {
  const BodyHint(this.text, {super.key, this.icon = Icons.info_outline_rounded, this.color});

  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.textTertiary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: c),
        ),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c)),
        ),
      ],
    );
  }
}

/// A small tinted pill with an icon and a value.
class BodyPill extends StatelessWidget {
  const BodyPill({super.key, required this.label, this.icon, required this.color, this.dense = false});

  final String label;
  final IconData? icon;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(dense ? 6 : Space.s, dense ? 2 : 3, dense ? 8 : Space.s + 2, dense ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: dense ? 12 : 14, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The seven weekdays in display order (Saturday first in Arabic), the
/// scheduled ones lit; today ringed.
class WeekdayDots extends ConsumerWidget {
  const WeekdayDots({super.key, required this.weekdays, required this.color, this.size = 20, this.dimmed = false});

  final List<int> weekdays;
  final Color color;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = BodyTexts.of(context);
    final start = BodyWeek.startFor(tx.fmt.languageCode);
    final today = ref.watch(bodyTodayProvider).weekday;
    final label = weekdays.isEmpty ? tx.l.bodyNoDays : tx.weekdayList(BodyWeek.inDisplayOrder(weekdays, start));
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in BodyWeek.ordered(start))
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 3),
              child: _DayDot(
                letter: tx.weekdayShort(d),
                on: weekdays.contains(d),
                today: d == today,
                color: dimmed ? t.textTertiary : color,
                size: size,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.letter, required this.on, required this.today, required this.color, required this.size});

  final String letter;
  final bool on;
  final bool today;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: size * 0.46,
      height: 1,
      fontWeight: on ? FontWeight.w700 : FontWeight.w400,
      color: on ? (t.isDark ? t.space0 : t.textOnAccent) : t.textTertiary,
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? color.withValues(alpha: 0.92) : t.glassFill,
        border: Border.all(
          color: today ? t.textPrimary.withValues(alpha: 0.85) : (on ? color : t.glassBorder),
          width: today ? 1.6 : 1,
        ),
      ),
      child: Text(letter, style: style, maxLines: 1, overflow: TextOverflow.clip, softWrap: false),
    );
  }
}

/// − value + with a spring on each step (countTick + haptic).
class BodyStepper extends StatelessWidget {
  const BodyStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.min = 0,
    this.max = 999,
    this.decimals = 0,
    this.unit,
    this.icon,
    this.color,
  });

  final String label;

  /// Null = not set ("—"); + starts it at [step] (or [min]).
  final num? value;
  final ValueChanged<num?> onChanged;
  final num step;
  final num min;
  final num max;
  final int decimals;
  final String? unit;
  final IconData? icon;
  final Color? color;

  num _clamp(num v) => v < min ? min : (v > max ? max : v);

  void _change(int dir) {
    final v = value;
    num next;
    if (v == null) {
      if (dir < 0) return;
      next = min > 0 ? min : step;
    } else {
      next = v + dir * step;
      if (next <= 0 && min <= 0) {
        Fx.fire(Sfx.toggleOff);
        onChanged(null);
        return;
      }
    }
    next = _clamp(next);
    if (decimals == 0) next = next.round();
    Fx.fire(Sfx.countTick);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = context.formatter;
    final text = Theme.of(context).textTheme;
    final c = color ?? t.accent;
    final shown = value == null ? l.bodyNotSet : fmt.formatNumber(value!, maxDecimals: decimals);
    return Semantics(
      container: true,
      label: label,
      value: value == null ? l.bodyNotSet : [shown, ?unit].join(' '),
      increasedValue: value == null ? fmt.formatNumber(min > 0 ? min : step) : fmt.formatNumber(_clamp(value! + step)),
      decreasedValue: value == null ? null : fmt.formatNumber(_clamp(value! - step)),
      onIncrease: () => _change(1),
      onDecrease: value == null ? null : () => _change(-1),
      child: Container(
        padding: const EdgeInsets.all(Space.xs),
        decoration: BoxDecoration(
          color: t.glassFill,
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: value == null ? t.glassBorder : c.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 13, color: t.textTertiary), const SizedBox(width: 3)],
                  Flexible(
                    child: Text(
                      label,
                      style: text.labelSmall?.copyWith(color: t.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  label: l.bodyStepperDecrease(label),
                  enabled: value != null,
                  onTap: () => _change(-1),
                ),
                Expanded(
                  child: ExcludeSemantics(
                    child: AnimatedSwitcher(
                      duration: context.motion(MadarMotion.short),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: child),
                      ),
                      child: Column(
                        key: ValueKey(shown),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            shown,
                            style: text.titleMedium?.copyWith(
                              color: value == null ? t.textTertiary : t.textPrimary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                            maxLines: 1,
                          ),
                          if (unit != null)
                            Text(unit!, style: text.labelSmall?.copyWith(color: t.textTertiary, height: 1.1)),
                        ],
                      ),
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  label: l.bodyStepperIncrease(label),
                  enabled: value == null || value! < max,
                  onTap: () => _change(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.enabled, required this.onTap});

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: MadarPressable(
        onTap: enabled ? onTap : null,
        enabled: enabled,
        sfx: null,
        semanticLabel: label,
        pressScale: 0.88,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: enabled ? t.textPrimary : t.textTertiary.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

/// Glass segmented tabs whose thumb springs between them (follows the
/// reading direction).
class BodyTabBar<T> extends StatelessWidget {
  const BodyTabBar({super.key, required this.tabs, required this.value, required this.labels, required this.icons, required this.onChanged});

  final List<T> tabs;
  final T value;
  final Map<T, String> labels;
  final Map<T, IconData> icons;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final dir = Directionality.of(context);
    final index = tabs.indexOf(value);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: 58,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusL),
          color: t.glassFill,
          border: Border.all(color: t.glassBorder),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth / tabs.length;
            return Stack(
              children: [
                SpringBuilder(
                  value: index.toDouble(),
                  spring: MadarMotion.snappy,
                  builder: (context, v, _) {
                    final x = dir == TextDirection.rtl ? constraints.maxWidth - w * (v + 1) : w * v;
                    return Positioned(
                      left: x,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(t.radiusL - 4),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [t.accent.withValues(alpha: 0.32), t.accent.withValues(alpha: 0.16)],
                          ),
                          border: Border.all(color: t.accent.withValues(alpha: 0.55)),
                          boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: 0.25), blurRadius: 12)],
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    for (final tab in tabs)
                      Expanded(
                        child: MadarPressable(
                          semanticLabel: labels[tab],
                          selected: tab == value,
                          sfx: Sfx.navigate,
                          excludeChildSemantics: true,
                          onTap: () {
                            if (tab != value) onChanged(tab);
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icons[tab], size: 18, color: tab == value ? t.textPrimary : t.textTertiary),
                              const SizedBox(height: 2),
                              AnimatedDefaultTextStyle(
                                duration: context.motion(MadarMotion.short),
                                style: (text.labelSmall ?? const TextStyle()).copyWith(
                                  color: tab == value ? t.textPrimary : t.textSecondary,
                                  fontWeight: tab == value ? FontWeight.w600 : FontWeight.w400,
                                ),
                                child: Text(labels[tab]!, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Builds a tab when first shown, keeps it alive afterwards and cross-fades
/// between them.
class BodyFadeStack extends StatefulWidget {
  const BodyFadeStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<BodyFadeStack> createState() => _BodyFadeStackState();
}

class _BodyFadeStackState extends State<BodyFadeStack> {
  final Set<int> _built = {};

  @override
  Widget build(BuildContext context) {
    final d = context.motion(MadarMotion.short);
    final index = widget.index;
    final children = widget.children;
    _built.add(index);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          if (!_built.contains(i))
            const SizedBox.shrink()
          else
            IgnorePointer(
              ignoring: i != index,
              child: ExcludeSemantics(
                excluding: i != index,
                child: TickerMode(
                  enabled: i == index,
                  child: AnimatedOpacity(opacity: i == index ? 1 : 0, duration: d, child: children[i]),
                ),
              ),
            ),
      ],
    );
  }
}

/// Rebuilds [builder] with the Body clock's "now" once a second while it is
/// visible (TickerMode on). Rebuilds only when the second actually changed,
/// so a frozen test clock never keeps frames scheduled.
class BodyTicker extends ConsumerStatefulWidget {
  const BodyTicker({super.key, required this.builder, this.period = const Duration(seconds: 1)});

  final Widget Function(BuildContext context, DateTime now) builder;
  final Duration period;

  @override
  ConsumerState<BodyTicker> createState() => _BodyTickerState();
}

class _BodyTickerState extends ConsumerState<BodyTicker> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = ref.read(bodyClockProvider)();
    _timer = Timer.periodic(widget.period, (_) => _tick());
  }

  void _tick() {
    if (!mounted || !TickerMode.valuesOf(context).enabled) return;
    final now = ref.read(bodyClockProvider)();
    if (now.difference(_now).inSeconds.abs() >= 1 || now.second != _now.second) setState(() => _now = now);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A clock swapped in (tests) or the day turning refreshes at once.
    ref.listen(bodyClockProvider, (_, clock) => setState(() => _now = clock()));
    ref.watch(bodyTodayProvider);
    return widget.builder(context, _now);
  }
}

/// A heading between sections.
class BodySectionTitle extends StatelessWidget {
  const BodySectionTitle(this.title, {super.key, this.trailing, this.icon});

  final String title;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.l, Space.xs, Space.s),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: t.gold), const SizedBox(width: Space.s)],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: text.titleSmall?.copyWith(color: t.textSecondary, letterSpacing: 0.2)),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Today's date line: "الثلاثاء ٢٩ سبتمبر".
String bodyTodayLine(BuildContext context, DateTime today) =>
    context.formatter.formatDate(BodyDays.of(today), style: MadarDateStyle.weekdayDayMonth);

/// A light tick (sound + synced haptic) for chart touches and similar.
void bodyTick() => Fx.fire(Sfx.countTick, volume: 0.5);
