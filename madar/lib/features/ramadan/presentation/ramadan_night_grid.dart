import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/sound/sound_api.dart';
import '../domain/last_ten_nights.dart';

/// A wrapping grid of the nights of the month, every cell a 48 dp target:
/// the number, filled when the night is done, ringed when it is the selected
/// one, a star on the odd nights of the last ten (when [markOdd]) and a dot on
/// tonight.
class RamadanNightGrid extends StatelessWidget {
  const RamadanNightGrid({
    super.key,
    required this.nights,
    required this.isDone,
    required this.onTap,
    this.selected,
    this.tonight,
    this.markOdd = false,
    this.keyPrefix = 'ramadan.night',
  });

  final List<int> nights;
  final bool Function(int night) isDone;

  /// Null makes the cells read-only.
  final ValueChanged<int>? onTap;
  final int? selected;
  final int? tonight;
  final bool markOdd;
  final String keyPrefix;

  static const double gap = Space.s;
  static const double minCell = 48;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 280.0;
        final columns = ((width + gap) / (minCell + gap)).floor().clamp(1, 12);
        final cell = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final n in nights)
              SizedBox(
                width: cell,
                height: minCell,
                child: _Cell(
                  key: ValueKey('$keyPrefix.$n'),
                  night: n,
                  done: isDone(n),
                  selected: n == selected,
                  tonight: n == tonight,
                  odd: markOdd && LastTenNights.isOddSought(n),
                  onTap: onTap == null ? null : () => onTap!(n),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.night,
    required this.done,
    required this.selected,
    required this.tonight,
    required this.odd,
    required this.onTap,
  });

  final int night;
  final bool done;
  final bool selected;
  final bool tonight;
  final bool odd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final number = fmt.formatInt(night, grouping: false);
    final state = done ? l.ramadanNightPrayed : l.ramadanNightNotPrayed;
    final radius = BorderRadius.circular(t.radiusS);
    return MadarPressable(
      onTap: onTap,
      sfx: Sfx.tap,
      selected: selected,
      toggled: done,
      semanticLabel: [
        l.ramadanNightCell(number, state),
        if (odd) l.ramadanLastTenOdd,
        if (tonight) l.ramadanLastTenTonight,
      ].join('. '),
      excludeChildSemantics: true,
      focusRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: done ? t.accent : t.glassFill,
          border: Border.all(
            color: selected ? t.gold : (tonight ? t.accent : t.glassBorder),
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              number,
              style: text.titleSmall!.copyWith(
                color: done ? t.textOnAccent : t.textPrimary,
                fontWeight: done || selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            if (odd)
              PositionedDirectional(
                top: 3,
                end: 4,
                child: Icon(Icons.star_rounded, size: 11, color: done ? t.textOnAccent : t.gold),
              ),
            if (tonight)
              PositionedDirectional(
                bottom: 4,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: done ? t.textOnAccent : t.accent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
