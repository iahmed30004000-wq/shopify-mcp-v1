import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';

/// A glass segmented control whose thumb springs between segments (in the
/// reading direction). Each value may carry an icon and its own thumb tint.
class LedgerSegmented<T> extends StatelessWidget {
  const LedgerSegmented({
    super.key,
    required this.values,
    required this.value,
    required this.labels,
    required this.onChanged,
    this.icons = const {},
    this.tints = const {},
    this.height = 44,
    this.sfx = Sfx.toggleOn,
  });

  final List<T> values;
  final T value;
  final Map<T, String> labels;
  final Map<T, IconData> icons;
  final Map<T, Color> tints;
  final ValueChanged<T> onChanged;
  final double height;
  final Sfx sfx;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final dir = Directionality.of(context);
    final index = values.indexOf(value).clamp(0, values.length - 1);
    final tint = tints[value] ?? t.accent;
    final darkTint = ThemeData.estimateBrightnessForColor(tint) == Brightness.dark;
    final onTint = tints[value] == null
        ? t.textOnAccent
        : (darkTint ? (t.isDark ? t.textPrimary : t.space0) : (t.isDark ? t.space0 : t.textPrimary));
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: t.glassFill,
          border: Border.all(color: t.glassBorder),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth / values.length;
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
                      child: AnimatedContainer(
                        duration: context.motion(MadarMotion.short),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color.lerp(tint, t.starTint, 0.18)!, tint],
                          ),
                          boxShadow: t.isDark ? [BoxShadow(color: tint.withValues(alpha: 0.35), blurRadius: 12)] : null,
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    for (final v in values)
                      Expanded(
                        child: MadarPressable(
                          onTap: v == value ? null : () => onChanged(v),
                          sfx: sfx,
                          selected: v == value,
                          semanticLabel: labels[v],
                          excludeChildSemantics: true,
                          focusRadius: BorderRadius.circular(99),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (icons[v] != null) ...[
                                  Icon(icons[v], size: 16, color: v == value ? onTint : t.textTertiary),
                                  const SizedBox(width: Space.xs),
                                ],
                                Flexible(
                                  // Shrinks rather than cutting a label
                                  // ("Adjustm…", "٣ أ…") at a large text size.
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: AnimatedDefaultTextStyle(
                                      duration: context.motion(MadarMotion.short),
                                      style: text.labelLarge!.copyWith(
                                        color: v == value ? onTint : t.textSecondary,
                                        height: 1.2,
                                      ),
                                      child: Text(labels[v] ?? '', maxLines: 1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
