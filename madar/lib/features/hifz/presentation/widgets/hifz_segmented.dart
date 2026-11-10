import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';

/// A glass segmented control whose golden thumb springs between segments
/// (follows the reading direction); each segment may show a count.
class HifzSegmented<T> extends StatelessWidget {
  const HifzSegmented({
    super.key,
    required this.values,
    required this.value,
    required this.labels,
    required this.onChanged,
    this.counts = const {},
  });

  final List<T> values;
  final T value;
  final Map<T, String> labels;
  final Map<T, String> counts;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final dir = Directionality.of(context);
    final index = values.indexOf(value);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(4),
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
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color.lerp(t.accent, t.starTint, 0.18)!, t.accent],
                          ),
                          boxShadow: t.isDark
                              ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 14)]
                              : null,
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
                          sfx: Sfx.navigate,
                          selected: v == value,
                          semanticLabel: [labels[v], ?counts[v]].join(' '),
                          excludeChildSemantics: true,
                          focusRadius: BorderRadius.circular(99),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: AnimatedDefaultTextStyle(
                                    duration: context.motion(MadarMotion.short),
                                    style: text.labelLarge!.copyWith(
                                      color: v == value ? t.textOnAccent : t.textSecondary,
                                      height: 1.2,
                                    ),
                                    child: Text(labels[v] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                                if (counts[v] != null) ...[
                                  const SizedBox(width: Space.xs),
                                  AnimatedContainer(
                                    duration: context.motion(MadarMotion.short),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(99),
                                      color: v == value ? t.textOnAccent.withValues(alpha: 0.16) : t.accentSoft,
                                    ),
                                    child: Text(
                                      counts[v]!,
                                      style: text.labelSmall!.copyWith(
                                        color: v == value ? t.textOnAccent : t.accent,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
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
