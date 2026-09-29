import 'package:flutter/material.dart';

import '../../../../../core/db/database.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../domain/dose_tracker.dart';
import '../../domain/med_models.dart';

/// The icon of a medication kind.
IconData medKindIcon(MedKind k) => switch (k) {
  MedKind.medication => Icons.medication_rounded,
  MedKind.supplement => Icons.spa_rounded,
  MedKind.injection => Icons.vaccines_rounded,
  MedKind.other => Icons.healing_rounded,
};

/// A medication's colour (the user's own, else the theme accent).
Color medColor(int? argb, MadarTokens t) => argb == null ? t.accent : Color(argb);

/// A small glowing orb in the medication's colour with its kind icon; a
/// check replaces the icon once taken.
class MedOrb extends StatelessWidget {
  const MedOrb({super.key, required this.med, this.size = 40, this.state});

  final MedSpec med;
  final double size;
  final DoseState? state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = medColor(med.color, t);
    final done = state == DoseState.taken;
    final dim = state == DoseState.skipped || state == DoseState.missed || !med.active;
    final c = dim ? Color.lerp(base, t.textTertiary, 0.6)! : base;
    return AnimatedContainer(
      duration: context.motion(MadarMotion.medium),
      curve: MadarMotion.standard,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.05,
          colors: [Color.lerp(c, t.starTint, t.isDark ? 0.3 : 0.5)!.withValues(alpha: 0.95), c.withValues(alpha: 0.55)],
        ),
        border: Border.all(color: c.withValues(alpha: 0.9), width: 1),
        boxShadow: dim || !t.isDark ? null : [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: size * 0.35)],
      ),
      child: AnimatedSwitcher(
        duration: context.motion(MadarMotion.short),
        transitionBuilder: (child, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: child)),
        child: Icon(
          done ? Icons.check_rounded : medKindIcon(med.kind),
          key: ValueKey(done),
          size: size * 0.5,
          color: t.textPrimary,
        ),
      ),
    );
  }
}

/// A tiny rounded label (state, "paused", "running low").
class MedBadge extends StatelessWidget {
  const MedBadge({super.key, required this.label, required this.color, this.icon, this.filled = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme.labelSmall!;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, 2, Space.s, 2),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: t.isDark ? 0.22 : 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.copyWith(color: color, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}

/// The colour a dose state speaks in.
Color doseStateColor(DoseState s, MadarTokens t) => switch (s) {
  DoseState.upcoming => t.textSecondary,
  DoseState.due => t.accent,
  DoseState.late => t.warning,
  DoseState.missed => t.danger,
  DoseState.taken => t.success,
  DoseState.skipped => t.textTertiary,
  DoseState.snoozed => t.info,
};

IconData doseStateIcon(DoseState s) => switch (s) {
  DoseState.upcoming => Icons.schedule_rounded,
  DoseState.due => Icons.notifications_active_rounded,
  DoseState.late => Icons.hourglass_bottom_rounded,
  DoseState.missed => Icons.remove_circle_outline_rounded,
  DoseState.taken => Icons.check_circle_rounded,
  DoseState.skipped => Icons.redo_rounded,
  DoseState.snoozed => Icons.snooze_rounded,
};

/// A header over a group of doses (prayer window) or a section.
class MedsGroupHeader extends StatelessWidget {
  const MedsGroupHeader({super.key, required this.label, this.icon, this.trailing});

  final String label;
  final IconData? icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.l, Space.xs, Space.s),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: t.gold), const SizedBox(width: Space.s)],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall!.copyWith(color: t.gold, letterSpacing: 0.2),
              ),
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: Container(
                height: 0.8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: [t.brass.withValues(alpha: 0.45), t.brass.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Space.s),
              Text(trailing!, style: text.labelMedium!.copyWith(color: t.textTertiary)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Adherence bars, one per day, oldest at the reading start (right in
/// Arabic, left in English) – Madar's time axes all read this way. A bar's
/// height is the share taken; a day with nothing due is a faint dot.
class AdherenceBars extends StatelessWidget {
  const AdherenceBars({super.key, required this.summary, this.height = 34, this.showLabels = false});

  final AdherenceSummary summary;
  final double height;

  /// Weekday initials under the bars (7-day view).
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final days = summary.days;
    final thin = days.length > 14;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: thin ? 1 : 3),
              child: _DayBar(
                day: days[i],
                height: height,
                index: i,
                label: showLabels ? fmt.formatDate(days[i].day, style: MadarDateStyle.short).characters.first : null,
                semantics: days[i].counted == 0
                    ? l.medsDayNothingDue(fmt.formatDate(days[i].day, style: MadarDateStyle.weekdayDayMonth))
                    : l.medsDayBarSemantics(
                        fmt.formatDate(days[i].day, style: MadarDateStyle.weekdayDayMonth),
                        fmt.formatInt(days[i].taken),
                        fmt.formatInt(days[i].counted),
                      ),
                labelStyle: text.labelSmall!.copyWith(color: t.textTertiary),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.height,
    required this.index,
    required this.semantics,
    required this.labelStyle,
    this.label,
  });

  final DayAdherence day;
  final double height;
  final int index;
  final String semantics;
  final String? label;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rate = day.rate;
    final color = rate == null
        ? t.textTertiary
        : rate >= 0.999
        ? t.success
        : rate >= 0.75
        ? t.accent
        : rate >= 0.5
        ? t.warning
        : t.danger;
    final bar = SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Track.
          Container(
            decoration: BoxDecoration(
              color: t.glassFill,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: t.glassBorder.withValues(alpha: 0.6), width: 0.6),
            ),
          ),
          if (rate == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(color: t.textTertiary.withValues(alpha: 0.6), shape: BoxShape.circle),
              ),
            )
          else
            SpringBuilder(
              value: rate.clamp(0.08, 1.0),
              from: 0,
              builder: (context, v, _) => FractionallySizedBox(
                heightFactor: v.clamp(0.0, 1.0),
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.lerp(color, t.starTint, 0.25)!, color.withValues(alpha: 0.75)],
                    ),
                    boxShadow: t.isDark ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6)] : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bar,
          if (label != null) ...[
            const SizedBox(height: Space.xxs),
            Text(label!, style: labelStyle, maxLines: 1),
          ],
        ],
      ),
    );
  }
}

/// The health record's standing alerts, pinned above the medications
/// (read-only here; they are edited in the health record).
class MedsStandingAlerts extends StatelessWidget {
  const MedsStandingAlerts({super.key, required this.alerts});

  final List<HealthAlertRow> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: l.medsAlertsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in alerts)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
              child: Builder(
                builder: (context) {
                  final c = switch (a.severity) {
                    Severity.critical => t.danger,
                    Severity.warning => t.warning,
                    Severity.info => t.info,
                  };
                  return GlassCard(
                    tint: c.withValues(alpha: t.isDark ? 0.14 : 0.08),
                    borderColor: c.withValues(alpha: 0.6),
                    glowColor: c.withValues(alpha: 0.25),
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.l, Space.s + 2),
                    child: Row(
                      children: [
                        Icon(
                          a.severity == Severity.info ? Icons.info_outline_rounded : Icons.report_rounded,
                          size: 20,
                          color: c,
                        ),
                        const SizedBox(width: Space.s + 2),
                        Expanded(
                          child: Text(
                            a.body,
                            textDirection: BidiIsolate.directionOf(a.body),
                            textAlign: TextAlign.start,
                            style: text.titleSmall!.copyWith(color: t.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// − value + stepper for small counts.
class MedsStepper extends StatelessWidget {
  const MedsStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
    required this.label,
    this.display,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String label;
  final String? display;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: label,
      value: display ?? fmt.formatInt(value),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: t.glassFill,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: t.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MadarButton.icon(
              icon: Icons.remove_rounded,
              onPressed: value > min ? () => onChanged(value - 1) : null,
              semanticLabel: '−',
              size: MadarButtonSize.small,
              variant: MadarButtonVariant.ghost,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 36),
              child: Text(
                display ?? fmt.formatInt(value),
                textAlign: TextAlign.center,
                style: text.titleMedium!.copyWith(color: t.textPrimary),
              ),
            ),
            MadarButton.icon(
              icon: Icons.add_rounded,
              onPressed: value < max ? () => onChanged(value + 1) : null,
              semanticLabel: '+',
              size: MadarButtonSize.small,
              variant: MadarButtonVariant.ghost,
            ),
          ],
        ),
      ),
    );
  }
}
