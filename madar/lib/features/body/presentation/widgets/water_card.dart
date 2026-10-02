import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/body_providers.dart';
import '../../domain/water.dart';
import '../body_actions.dart';
import '../body_texts.dart';
import 'body_widgets.dart';

/// Today's water: a progress ring against the daily target and one-tap
/// +250 / +500 / other amounts (each with undo). [compact] is the one-row
/// version for the Today tab and the Body planet hub.
class WaterCard extends ConsumerWidget {
  const WaterCard({super.key, this.compact = false, this.onOpen});

  final bool compact;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(bodyWaterTodayProvider);
    final target = ref.watch(bodyWaterTargetProvider);
    return compact
        ? _CompactWater(total: total, target: target, onOpen: onOpen)
        : _FullWater(total: total, target: target);
  }
}

String _waterStatus(BodyTexts tx, int total, int target) =>
    total >= target ? tx.l.bodyWaterGoalMet : tx.l.bodyWaterLeft(tx.ml(target - total));

class _FullWater extends ConsumerWidget {
  const _FullWater({required this.total, required this.target});

  final int total;
  final int target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final met = total >= target;
    final streak = ref.watch(bodyWaterStreakProvider);
    return BodyCard(
      title: l.bodyWaterTitle,
      icon: Icons.water_drop_rounded,
      iconColor: p.water,
      seed: 5.3,
      glowColor: met ? p.water.withValues(alpha: 0.3) : null,
      trailing: MadarButton(
        key: const ValueKey('body.water.target'),
        label: tx.ml(target),
        icon: Icons.flag_rounded,
        variant: MadarButtonVariant.ghost,
        size: MadarButtonSize.small,
        sfx: Sfx.sheetOpen,
        semanticLabel: '${l.bodyWaterTarget}: ${tx.ml(target)}',
        onPressed: () => BodyActions.editWaterTarget(context, ref),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(
                key: const ValueKey('body.water.ring'),
                value: WaterMath.progress(total, target),
                size: 132,
                strokeWidth: 11,
                color: p.water,
                gradientEnd: p.waterEnd,
                semanticLabel: l.bodyWaterTitle,
                semanticValue: '${tx.ml(total)} ${l.bodyWaterOf(tx.ml(target))}',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RingTotal(
                      total: total,
                      tx: tx,
                      style: text.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
                    ),
                    Text(l.bodyWaterOf(tx.ml(target)), style: text.labelSmall?.copyWith(color: t.textTertiary)),
                  ],
                ),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.volumeWater(total),
                      style: text.titleLarge?.copyWith(color: p.water, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(
                      _waterStatus(tx, total, target),
                      style: text.bodyMedium?.copyWith(color: met ? p.water : t.textSecondary),
                    ),
                    if (streak > 0) ...[
                      const SizedBox(height: Space.s),
                      BodyPill(
                        label: tx.fmt.localizeDigits(l.bodyDaysInRow(streak, tx.fmt.formatInt(streak))),
                        icon: Icons.local_fire_department_outlined,
                        color: t.gold,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          Row(
            children: [
              for (final (i, ml) in WaterMath.quick.indexed) ...[
                Expanded(
                  child: _WaterButton(
                    key: ValueKey('body.water.add.$ml'),
                    label: l.bodyAddAmount(tx.ml(ml)),
                    semanticLabel: l.bodyAddWaterSemantics(tx.ml(ml)),
                    icon: i == 0 ? Icons.local_drink_rounded : Icons.water_drop_rounded,
                    color: p.water,
                    onTap: () => BodyActions.addWater(context, ref, ml),
                  ),
                ),
                const SizedBox(width: Space.s),
              ],
              Expanded(
                child: _WaterButton(
                  key: const ValueKey('body.water.custom'),
                  label: l.bodyWaterCustom,
                  semanticLabel: l.bodyWaterCustom,
                  icon: Icons.tune_rounded,
                  color: t.textSecondary,
                  onTap: () => BodyActions.customWater(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The ring's total: an odometer roll with Western digits; with
/// Arabic-Indic digits (whose narrow ١ and ٠ would sit in wide tabular
/// columns and read as "١ ٢٥ ٠") a quick count to the new value instead.
class _RingTotal extends StatelessWidget {
  const _RingTotal({required this.total, required this.tx, this.style});

  final int total;
  final BodyTexts tx;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (!tx.fmt.arabicIndic) {
      return RollingNumber(value: total, formatter: (v) => tx.fmt.formatInt(v.round()), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: total.toDouble()),
      duration: context.motion(MadarMotion.medium),
      curve: MadarMotion.decelerate,
      builder: (context, v, _) => Text(tx.fmt.formatInt(v.round()), style: style, maxLines: 1),
    );
  }
}

class _WaterButton extends StatelessWidget {
  const _WaterButton({super.key, required this.label, required this.semanticLabel, required this.icon, required this.color, required this.onTap});

  final String label;
  final String semanticLabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: onTap,
      sfx: null,
      semanticLabel: semanticLabel,
      excludeChildSemantics: true,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: Space.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: t.isDark ? 0.20 : 0.14), color.withValues(alpha: t.isDark ? 0.08 : 0.05)],
          ),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: Space.xs),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: text.labelLarge?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactWater extends ConsumerWidget {
  const _CompactWater({required this.total, required this.target, this.onOpen});

  final int total;
  final int target;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final ml = WaterMath.quick.first;
    return BodyCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.s, Space.m),
      onTap: onOpen,
      semanticLabel: '${l.bodyWaterTitle}: ${tx.ml(total)} ${l.bodyWaterOf(tx.ml(target))}. ${_waterStatus(tx, total, target)}',
      seed: 3.7,
      child: Row(
        children: [
          ExcludeSemantics(
            child: ProgressRing(
              value: WaterMath.progress(total, target),
              size: 76,
              strokeWidth: 7,
              color: p.water,
              gradientEnd: p.waterEnd,
              child: Icon(Icons.water_drop_rounded, size: 22, color: p.water),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.bodyCardWater, style: text.labelMedium?.copyWith(color: p.water, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${tx.fmt.formatInt(total)} / ${tx.ml(target)}',
                    style: text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    maxLines: 1,
                  ),
                  Text(
                    _waterStatus(tx, total, target),
                    style: text.bodySmall?.copyWith(color: total >= target ? p.water : t.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          MadarButton.icon(
            key: const ValueKey('body.water.quick'),
            icon: Icons.add_rounded,
            semanticLabel: l.bodyAddWaterSemantics(tx.ml(ml)),
            variant: MadarButtonVariant.secondary,
            onPressed: () => BodyActions.addWater(context, ref, ml),
          ),
        ],
      ),
    );
  }
}
