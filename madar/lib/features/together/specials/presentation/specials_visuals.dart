import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/painters/painters.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/player_profile.dart';
import '../../presentation/together_texts.dart';
import '../../presentation/widgets/together_visuals.dart';

/// A round jewel badge with an icon (the specials' emblem).
class SpecialsBadge extends StatelessWidget {
  const SpecialsBadge({super.key, required this.icon, this.size = 44, this.color});

  final IconData icon;
  final double size;

  /// The jewel's colour (default: the theme accent).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.accent;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.35),
            colors: [c.withValues(alpha: t.isDark ? 0.42 : 0.28), c.withValues(alpha: 0.08)],
          ),
          border: Border.all(color: t.gold.withValues(alpha: 0.55), width: 0.9),
          boxShadow: [BoxShadow(color: c.withValues(alpha: t.isDark ? 0.35 : 0.18), blurRadius: size * 0.35)],
        ),
        child: Icon(icon, size: size * 0.5, color: Color.lerp(c, t.textPrimary, t.isDark ? 0.15 : 0.35)),
      ),
    );
  }
}

/// A row of the specials section: badge, title, one or two lines of
/// status and a trailing widget.
class SpecialsTile extends StatelessWidget {
  const SpecialsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      onTap: onTap,
      semanticLabel: semanticLabel ?? '$title. $subtitle',
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
      child: Row(
        children: [
          SpecialsBadge(icon: icon, color: color),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(color: t.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Space.s), trailing!],
        ],
      ),
    );
  }
}

/// One player's "I did it" for the weekly challenge: their avatar, a gold
/// check when done, their name and state.
class DuoDoneButton extends StatelessWidget {
  const DuoDoneButton({
    super.key,
    required this.profile,
    required this.done,
    required this.onToggle,
    this.size = 72,
  });

  final TogetherProfile profile;
  final bool done;
  final VoidCallback? onToggle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final text = Theme.of(context).textTheme;
    final color = TogetherLook.colorOf(profile);
    final name = tx.rawName(profile);
    return MadarPressable(
      onTap: onToggle,
      sfx: done ? Sfx.toggleOff : Sfx.complete,
      toggled: done,
      semanticLabel: '$name: ${done ? tx.l.togetherWeeklyDone : tx.l.togetherWeeklyMarkDone}',
      excludeChildSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: size + 12,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: size + 12,
                  height: size + 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: done ? t.gold : t.glassBorder, width: done ? 2 : 1),
                    boxShadow: done ? [BoxShadow(color: t.gold.withValues(alpha: 0.35), blurRadius: 16)] : null,
                  ),
                ),
                TogetherAvatarView(profile: profile, displayName: name, size: size, dim: !done, glow: done),
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: AnimatedScale(
                    scale: done ? 1 : 0.8,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: size * 0.36,
                      height: size * 0.36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? t.gold : t.space2,
                        border: Border.all(color: done ? Color.lerp(t.gold, Colors.white, 0.4)! : color, width: 1.5),
                      ),
                      child: Icon(
                        done ? Icons.check_rounded : Icons.add_rounded,
                        size: size * 0.24,
                        color: done ? TogetherLook.inkOn(t.gold) : color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            name,
            style: text.titleSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            done ? tx.l.togetherWeeklyDone : tx.l.togetherWeeklyMarkDone,
            style: text.labelMedium?.copyWith(color: done ? t.gold : t.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A slowly turning girih rosette behind a hero element (static under
/// reduced motion and in tests).
class SpecialsRosette extends StatelessWidget {
  const SpecialsRosette({super.key, required this.color, this.size = 220, this.folds = 10});

  final Color color;
  final double size;
  final int folds;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: GirihRosettePainter(
            folds: folds,
            strandColor: Color.lerp(color, Colors.white, 0.2)!.withValues(alpha: t.isDark ? 0.16 : 0.2),
            ringColor: t.metalGold.withValues(alpha: 0.18),
            rotation: math.pi / folds,
          ),
        ),
      ),
    );
  }
}
