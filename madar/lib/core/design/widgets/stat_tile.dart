import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';
import 'glass.dart';

/// Direction of a stat's change; decides colour and arrow.
enum StatTrend { up, down, flat }

/// A compact metric on faux glass: tinted icon badge, big tabular value
/// with unit, label, optional trend pill and caption. Tappable when
/// [onTap] is set.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.color,
    this.trend,
    this.trendLabel,
    this.trendIsGood = true,
    this.caption,
    this.onTap,
  });

  final String label;

  /// Pre-formatted value (callers own digit style / locale formatting).
  final String value;
  final String? unit;
  final IconData? icon;

  /// Badge colour (e.g. a planet colour); defaults to the accent.
  final Color? color;
  final StatTrend? trend;

  /// Pre-formatted change, e.g. "+12%".
  final String? trendLabel;

  /// Whether [StatTrend.up] is good news (green) – false for e.g. spending.
  final bool trendIsGood;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = color ?? t.accent;
    final semantics = [label, value, ?unit, ?trendLabel, ?caption].join(', ');
    final card = GlassCard(
      onTap: onTap,
      semanticLabel: semantics,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l - 2, Space.l - 2, Space.l - 2, Space.m + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) _Badge(icon: icon!, color: c),
              const Spacer(),
              if (trend != null && trendLabel != null) _TrendPill(trend: trend!, label: trendLabel!, good: trendIsGood),
            ],
          ),
          const SizedBox(height: Space.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                // A value is never cut ("112.50 …" hid the currency at a
                // large text size): it shrinks to fit instead.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: MadarTypography.numerals(
                      t,
                      size: 26,
                      color: t.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600, height: 1.1),
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: Space.xs + 1),
                Text(unit!, style: text.bodySmall!.copyWith(color: t.textSecondary)),
              ],
            ],
          ),
          const SizedBox(height: Space.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelLarge!.copyWith(color: t.textSecondary, fontWeight: FontWeight.w500),
          ),
          if (caption != null)
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall!.copyWith(color: t.textTertiary),
            ),
        ],
      ),
    );
    if (onTap != null) return card;
    return Semantics(container: true, label: semantics, excludeSemantics: true, child: card);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [color.withValues(alpha: 0.34), color.withValues(alpha: 0.12)],
        ),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: -2)],
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.trend, required this.label, required this.good});

  final StatTrend trend;
  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final positive = trend == StatTrend.up ? good : !good;
    final c = trend == StatTrend.flat ? t.textTertiary : (positive ? t.success : t.danger);
    final icon = switch (trend) {
      StatTrend.up => Icons.arrow_upward_rounded,
      StatTrend.down => Icons.arrow_downward_rounded,
      StatTrend.flat => Icons.remove_rounded,
    };
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs + 2, Space.xxs, Space.s, Space.xxs),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: 0.3), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: Space.xxs),
          Text(
            label,
            textDirection: TextDirection.ltr,
            style: MadarTypography.numerals(t, size: 11.5, color: c).copyWith(fontWeight: FontWeight.w600, height: 1.2),
          ),
        ],
      ),
    );
  }
}
