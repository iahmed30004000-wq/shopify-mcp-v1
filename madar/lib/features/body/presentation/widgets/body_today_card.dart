import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../data/body_providers.dart';
import '../../domain/fasting.dart';
import '../../domain/water.dart';
import '../body_texts.dart';
import 'body_widgets.dart';
import 'fasting_card.dart';
import 'fasting_ring.dart';

/// The Body planet at a glance for its hub: today's session, water and the
/// fasting clock as three small gauges. [onOpen] opens [BodyScreen].
class BodyTodayCard extends ConsumerWidget {
  const BodyTodayCard({super.key, this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final day = ref.watch(bodyTrainingTodayProvider);
    final water = ref.watch(bodyWaterTodayProvider);
    final target = ref.watch(bodyWaterTargetProvider);
    final plan = ref.watch(bodyFastingPlanProvider).value ?? const FastingPlan();
    final active = ref.watch(bodyActiveFastProvider);
    final lastEnd = ref.watch(bodyLastFastEndProvider);
    final clock = ref.watch(bodyWallClockProvider);
    final training = day.isRestDay
        ? l.bodyRestDay
        : tx.fmt.localizeDigits(l.bodyFraction(tx.fmt.formatInt(day.done), tx.fmt.formatInt(day.planned)));
    return BodyCard(
      title: l.bodyCardTitle,
      icon: Icons.local_fire_department_rounded,
      iconColor: p.training,
      onTap: onOpen,
      seed: 1.9,
      trailing: onOpen == null
          ? null
          : Icon(Icons.chevron_right_rounded, color: t.textTertiary, textDirection: Directionality.of(context)),
      child: BodyTicker(
        period: const Duration(seconds: 30),
        builder: (context, now) {
          final status = FastingMath.status(plan: plan, now: now, active: active, lastEnd: lastEnd, clock: clock);
          final ft = FastingTexts(status, plan, tx);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Gauge(
                  label: l.bodyCardTraining,
                  value: training,
                  semantic: '${l.bodyCardTraining}: $training',
                  ring: ProgressRing(
                    value: day.progress,
                    size: 58,
                    strokeWidth: 6,
                    color: p.training,
                    gradientEnd: p.trainingEnd,
                    child: Icon(
                      day.isRestDay ? Icons.self_improvement_rounded : Icons.fitness_center_rounded,
                      size: 20,
                      color: day.isRestDay ? t.textTertiary : p.training,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _Gauge(
                  label: l.bodyCardWater,
                  value: tx.volumeWater(water),
                  semantic: '${l.bodyCardWater}: ${tx.ml(water)} ${l.bodyWaterOf(tx.ml(target))}',
                  ring: ProgressRing(
                    value: WaterMath.progress(water, target),
                    size: 58,
                    strokeWidth: 6,
                    color: p.water,
                    gradientEnd: p.waterEnd,
                    child: Icon(Icons.water_drop_rounded, size: 20, color: p.water),
                  ),
                ),
              ),
              Expanded(
                child: _Gauge(
                  label: l.bodyCardFasting,
                  value: switch (status.phase) {
                    FastingPhase.fasting => tx.fmt.formatDuration(status.elapsed),
                    FastingPhase.eating => tx.fmt.formatDuration(status.remaining),
                    FastingPhase.waiting => tx.phase(status.phase),
                  },
                  semantic: ft.semantics,
                  ring: FastingRing(
                    status: status,
                    size: 58,
                    strokeWidth: 5,
                    ticks: false,
                    child: Icon(
                      status.phase == FastingPhase.eating ? Icons.restaurant_rounded : Icons.nights_stay_rounded,
                      size: 18,
                      color: status.phase == FastingPhase.eating ? p.eating : p.fasting,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.label, required this.value, required this.semantic, required this.ring});

  final String label;
  final String value;
  final String semantic;
  final Widget ring;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: semantic,
      excludeSemantics: true,
      child: Column(
        children: [
          ring,
          const SizedBox(height: Space.xs),
          Text(label, style: text.labelSmall?.copyWith(color: t.textTertiary), maxLines: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]), maxLines: 1),
          ),
        ],
      ),
    );
  }
}
