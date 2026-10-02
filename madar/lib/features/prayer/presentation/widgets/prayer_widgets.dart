import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../application/prayer_providers.dart';
import '../../application/prayer_settings_controller.dart';
import '../../domain/prayer_clock.dart';
import '../prayer_labels.dart';

/// The Hijri date (Umm al-Qura + the user's offset; Maghrib rollover when
/// enabled) of [at] – "now" of the prayer clock when null. Arabic month
/// names and Arabic-Indic digits in Arabic.
class HijriDateText extends ConsumerWidget {
  const HijriDateText({super.key, this.at, this.style, this.textAlign, this.dayMonthOnly = false});

  final DateTime? at;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// «١٦ ربيع الآخر» without the year.
  final bool dayMonthOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final instant = at ?? ref.watch(prayerClockProvider)();
    final h = ref.watch(hijriDateProvider(instant));
    final text = dayMonthOnly ? l.hijriDayMonth(h, fmt) : l.hijriDate(h, fmt);
    return Text(text, style: style, textAlign: textAlign);
  }
}

/// A prayer time set in type: large tabular digits and the day-period word
/// smaller beside them.
class PrayerTimeText extends StatelessWidget {
  const PrayerTimeText(this.time, {super.key, this.size = 20, this.color, this.weight = FontWeight.w600});

  final PrayerClockText time;
  final double size;
  final Color? color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.textPrimary;
    return Semantics(
      label: time.joined,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            time.clock,
            style: MadarTypography.numerals(t, size: size, color: c).copyWith(fontWeight: weight, height: 1.1),
          ),
          if (time.period != null) ...[
            SizedBox(width: size * 0.18),
            Text(
              time.period!,
              style: TextStyle(
                fontFamily: MadarTypography.uiFamily,
                fontSize: size * 0.56,
                fontWeight: FontWeight.w500,
                color: c.withValues(alpha: 0.72),
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// − value + : a compact stepper for minutes, angles and day offsets. Every
/// step ticks (sound + haptic); the value is announced to screen readers.
class ValueStepper extends StatelessWidget {
  const ValueStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.canDecrement = true,
    this.canIncrement = true,
    this.minWidth = 64,
    this.valueAfter,
  });

  /// The formatted value shown between the buttons.
  final String value;

  /// The value one step down (−1) or up (+1), announced by screen readers
  /// before they step; [value] when null.
  final String Function(int delta)? valueAfter;

  /// Called with −1 or +1.
  final ValueChanged<int> onChanged;

  /// What is being adjusted (for screen readers).
  final String label;
  final bool canDecrement;
  final bool canIncrement;
  final double minWidth;

  /// A step from an accessibility action (the buttons sound on their own).
  void _step(int d) {
    Fx.fire(Sfx.countTick);
    onChanged(d);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: label,
      value: value,
      increasedValue: canIncrement ? (valueAfter?.call(1) ?? value) : null,
      decreasedValue: canDecrement ? (valueAfter?.call(-1) ?? value) : null,
      onIncrease: canIncrement ? () => _step(1) : null,
      onDecrease: canDecrement ? () => _step(-1) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: MadarButton.icon(
              icon: Icons.remove_rounded,
              semanticLabel: l.ptDecrease,
              size: MadarButtonSize.small,
              sfx: Sfx.countTick,
              onPressed: canDecrement ? () => onChanged(-1) : null,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: AnimatedSwitcher(
              duration: context.motion(MadarMotion.short),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(anim), child: child),
              ),
              child: Text(
                value,
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: text.titleMedium!.copyWith(color: t.accent, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
          ExcludeSemantics(
            child: MadarButton.icon(
              icon: Icons.add_rounded,
              semanticLabel: l.ptIncrease,
              size: MadarButtonSize.small,
              sfx: Sfx.countTick,
              onPressed: canIncrement ? () => onChanged(1) : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// The location pill (📍 عمّان، الأردن ⌄) that opens the location sheet.
class PrayerLocationChip extends ConsumerWidget {
  const PrayerLocationChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final settings = ref.watch(prayerSettingsControllerProvider);
    final cities = ref.watch(cityDatabaseProvider).value;
    final label = l.placeLabel(settings, lang, cities: cities);
    return MadarPressable(
      onTap: onTap,
      sfx: Sfx.sheetOpen,
      semanticLabel: '${l.ptLocationTitle}: $label',
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusXL),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.s, Space.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusXL),
          color: t.glassFill,
          border: Border.all(color: t.glassBorder, width: 0.9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_rounded, size: 18, color: t.accent),
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge!.copyWith(color: t.textPrimary),
              ),
            ),
            const SizedBox(width: Space.xxs),
            Icon(Icons.expand_more_rounded, size: 18, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// A small gold ornament row: star · label · star.
class PrayerOrnamentLabel extends StatelessWidget {
  const PrayerOrnamentLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    Widget line(bool flip) => Expanded(
      child: Container(
        height: 0.8,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: flip ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
            end: flip ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
            colors: [t.brass.withValues(alpha: 0), t.brass.withValues(alpha: 0.55)],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          line(false),
          const SizedBox(width: Space.s),
          IslamicStar(size: 11, color: t.gold),
          const SizedBox(width: Space.s),
          Flexible(
            flex: 3,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium!.copyWith(color: t.gold, letterSpacing: 0),
            ),
          ),
          const SizedBox(width: Space.s),
          IslamicStar(size: 11, color: t.gold),
          const SizedBox(width: Space.s),
          line(true),
        ],
      ),
    );
  }
}
