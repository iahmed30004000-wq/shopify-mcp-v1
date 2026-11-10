import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/motion/motion.dart';
import '../domain/center_models.dart';
import '../domain/describers.dart' show groupIcon;

/// Each group's hue, from the theme's tokens (never literals): prayer in
/// the astrolabe's gold, medications in success green, money in warning
/// amber, family a warm coral between danger and gold …
Color groupColor(NotificationGroup g, MadarTokens t) => switch (g) {
  NotificationGroup.prayer => t.gold,
  NotificationGroup.adhkar => t.highlight,
  NotificationGroup.medications => t.success,
  NotificationGroup.health => t.info,
  NotificationGroup.money => t.warning,
  NotificationGroup.family => Color.lerp(t.danger, t.gold, 0.35)!,
  NotificationGroup.travel => t.secondary,
  NotificationGroup.wird => t.accent,
  NotificationGroup.customModules => Color.lerp(t.accent, t.secondary, 0.5)!,
  NotificationGroup.other => t.textSecondary,
};

/// A glowing disc with a notification's icon in its group's hue. [live]
/// adds a soft halo (still in the tray); [dim] quiets it (muted, skipped).
class CenterGroupDisc extends StatelessWidget {
  const CenterGroupDisc({
    super.key,
    required this.group,
    this.icon,
    this.size = 44,
    this.live = false,
    this.dim = false,
  });

  final NotificationGroup group;
  final IconData? icon;
  final double size;
  final bool live;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hue = groupColor(group, t);
    final a = dim ? 0.45 : 1.0;
    return AnimatedContainer(
      duration: context.motion(MadarMotion.medium),
      curve: MadarMotion.standard,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const AlignmentDirectional(-0.35, -0.45).resolve(Directionality.of(context)),
          colors: [
            hue.withValues(alpha: (t.isDark ? 0.42 : 0.30) * a),
            hue.withValues(alpha: (t.isDark ? 0.16 : 0.12) * a),
          ],
        ),
        border: Border.all(
          color: hue.withValues(alpha: (live ? 0.85 : 0.35) * a),
          width: live ? 1.6 : 1,
        ),
        boxShadow: live && !dim
            ? [BoxShadow(color: hue.withValues(alpha: 0.38), blurRadius: 14, spreadRadius: 1)]
            : null,
      ),
      child: Icon(
        icon ?? groupIcon(group),
        size: size * 0.48,
        color: hue.withValues(alpha: dim ? 0.6 : 1),
      ),
    );
  }
}

/// A small rounded label (state, count).
class CenterBadge extends StatelessWidget {
  const CenterBadge({super.key, required this.label, required this.color, this.icon, this.filled = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fg = filled ? t.textOnAccent : color;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, 2, Space.s, 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: filled ? color : color.withValues(alpha: t.isDark ? 0.14 : 0.10),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall!.copyWith(color: fg, height: 1.25, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
