import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/body_providers.dart';
import '../../domain/body_clock.dart';
import '../../domain/fasting.dart';
import '../body_actions.dart';
import '../body_texts.dart';
import 'body_widgets.dart';
import 'fasting_ring.dart';

/// The live intermittent-fasting clock with start / end. [compact] is the
/// one-row version for the Today tab and the Body planet hub ([onOpen]
/// opens the full fasting tab).
class FastingCard extends ConsumerWidget {
  const FastingCard({super.key, this.compact = false, this.onOpen});

  final bool compact;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(bodyFastingPlanProvider).value ?? const FastingPlan();
    final active = ref.watch(bodyActiveFastProvider);
    final lastEnd = ref.watch(bodyLastFastEndProvider);
    final clock = ref.watch(bodyWallClockProvider);
    return BodyTicker(
      builder: (context, now) {
        final status = FastingMath.status(plan: plan, now: now, active: active, lastEnd: lastEnd, clock: clock);
        return compact
            ? _CompactFasting(status: status, plan: plan, onOpen: onOpen)
            : _FullFasting(status: status, plan: plan);
      },
    );
  }
}

/// Texts of the ring's centre for one moment.
class FastingTexts {
  FastingTexts(this.status, this.plan, this.tx);

  final FastingStatus status;
  final FastingPlan plan;
  final BodyTexts tx;

  L10n get l => tx.l;

  DateTime get _opens => status.until.subtract(plan.eatingWindow);

  bool get _missed => status.missedStart();

  /// The big number: time fasted, time left to eat, time until the eating
  /// window opens (or the next fast), or the planned start of a missed fast.
  String get big => switch (status.phase) {
    FastingPhase.fasting => tx.timer(status.elapsed),
    FastingPhase.eating => tx.timer(status.remaining),
    FastingPhase.waiting when _missed => tx.fmt.formatTime(status.lastPlannedStart!),
    FastingPhase.waiting when plan.eatingWindow == Duration.zero => tx.timer(status.remaining),
    FastingPhase.waiting => tx.timer(_opens.difference(status.now)),
  };

  /// The line under it.
  String get caption {
    switch (status.phase) {
      case FastingPhase.fasting:
        if (status.reached) return l.bodyFastReached;
        return l.bodyFastRemaining(tx.duration(status.remaining));
      case FastingPhase.eating:
        return l.bodyEatingClosesAt(tx.fmt.formatTime(status.until));
      case FastingPhase.waiting:
        if (_missed) return l.bodyFastTimeNow;
        if (plan.eatingWindow == Duration.zero) return l.bodyNextFastAt(tx.fmt.formatTime(status.until));
        return l.bodyWindowOpensAt(tx.fmt.formatTime(_opens));
    }
  }

  /// A third line: the goal time, the overtime, or the next fast.
  String? get detail => switch (status.phase) {
    FastingPhase.fasting =>
      status.reached
          ? l.bodyFastOvertime(tx.duration(status.overtime))
          : l.bodyFastGoalAt(tx.timeOn(status.until, BodyDays.of(status.now))),
    FastingPhase.eating => l.bodyEatingClosesIn(tx.duration(status.remaining)),
    FastingPhase.waiting => _missed || plan.eatingWindow == Duration.zero
        ? null
        : l.bodyNextFastAt(tx.fmt.formatTime(status.until)),
  };

  String get semantics => l.bodyFastRingSemantics(tx.phase(status.phase), [big, caption, ?detail].join('. '));
}

Color _phaseColor(BodyPalette p, FastingStatus s) => switch (s.phase) {
  FastingPhase.fasting => s.reached ? p.eating : p.fasting,
  FastingPhase.eating => p.eating,
  FastingPhase.waiting => p.t.textSecondary,
};

class _FullFasting extends ConsumerWidget {
  const _FullFasting({required this.status, required this.plan});

  final FastingStatus status;
  final FastingPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final ft = FastingTexts(status, plan, tx);
    final color = _phaseColor(p, status);
    final active = status.active;
    return BodyCard(
      title: l.bodyFastingTitle,
      icon: Icons.nights_stay_rounded,
      seed: 2.2,
      glowColor: status.reached ? p.eating.withValues(alpha: 0.3) : null,
      trailing: BodyPill(label: tx.planRatio(plan), icon: Icons.hourglass_bottom_rounded, color: p.fasting),
      child: Column(
        children: [
          Semantics(
            liveRegion: false,
            label: ft.semantics,
            excludeSemantics: true,
            child: FastingRing(
              key: const ValueKey('body.fasting.ring'),
              status: status,
              size: 236,
              child: Padding(
                padding: const EdgeInsets.all(Space.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tx.phase(status.phase),
                      style: text.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                    ),
                    const SizedBox(height: Space.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        ft.big,
                        style: text.titleLarge?.copyWith(
                          fontSize: 34,
                          height: 1.15,
                          color: t.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      ft.caption,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: status.reached ? p.eating : t.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (ft.detail != null) ...[
            const SizedBox(height: Space.s),
            Text(ft.detail!, style: text.bodySmall?.copyWith(color: t.textTertiary), textAlign: TextAlign.center),
          ],
          const SizedBox(height: Space.l),
          if (active != null)
            Row(
              children: [
                Expanded(
                  child: MadarButton(
                    key: const ValueKey('body.fasting.end'),
                    label: l.bodyEndFast,
                    icon: Icons.stop_circle_outlined,
                    variant: status.reached ? MadarButtonVariant.primary : MadarButtonVariant.secondary,
                    sfx: Sfx.tap,
                    expand: true,
                    onPressed: () => BodyActions.stopFast(context, ref, active),
                  ),
                ),
                const SizedBox(width: Space.s),
                MadarButton.icon(
                  icon: Icons.edit_calendar_rounded,
                  semanticLabel: l.bodyFastEditTitle,
                  variant: MadarButtonVariant.ghost,
                  sfx: Sfx.sheetOpen,
                  onPressed: () => BodyActions.editFast(context, ref, active.id),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: MadarButton(
                    key: const ValueKey('body.fasting.start'),
                    label: l.bodyStartFast,
                    icon: Icons.play_arrow_rounded,
                    expand: true,
                    sfx: Sfx.tap,
                    onPressed: () => BodyActions.startFast(context, ref),
                  ),
                ),
                const SizedBox(width: Space.s),
                MadarButton(
                  label: l.bodyStartedEarlier,
                  variant: MadarButtonVariant.ghost,
                  size: MadarButtonSize.small,
                  sfx: Sfx.sheetOpen,
                  onPressed: () => BodyActions.startFastEarlier(context, ref),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CompactFasting extends ConsumerWidget {
  const _CompactFasting({required this.status, required this.plan, this.onOpen});

  final FastingStatus status;
  final FastingPlan plan;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final tx = BodyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final ft = FastingTexts(status, plan, tx);
    final active = status.active;
    return BodyCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.s, Space.m),
      onTap: onOpen,
      semanticLabel: ft.semantics,
      seed: 3.1,
      child: Row(
        children: [
          ExcludeSemantics(
            child: FastingRing(
              status: status,
              size: 76,
              strokeWidth: 7,
              ticks: false,
              child: Icon(
                status.phase == FastingPhase.eating ? Icons.restaurant_rounded : Icons.nights_stay_rounded,
                size: 22,
                color: _phaseColor(p, status),
              ),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.phase(status.phase),
                    style: text.labelMedium?.copyWith(color: _phaseColor(p, status), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ft.big,
                    style: text.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    maxLines: 1,
                  ),
                  Text(
                    ft.caption,
                    style: text.bodySmall?.copyWith(color: t.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.short),
            child: active != null
                ? MadarButton.icon(
                    key: const ValueKey('stop'),
                    icon: Icons.stop_rounded,
                    semanticLabel: l.bodyEndFast,
                    variant: status.reached ? MadarButtonVariant.primary : MadarButtonVariant.secondary,
                    onPressed: () => BodyActions.stopFast(context, ref, active),
                  )
                : MadarButton.icon(
                    key: const ValueKey('start'),
                    icon: Icons.play_arrow_rounded,
                    semanticLabel: l.bodyStartFast,
                    variant: MadarButtonVariant.secondary,
                    onPressed: () => BodyActions.startFast(context, ref),
                  ),
          ),
        ],
      ),
    );
  }
}
