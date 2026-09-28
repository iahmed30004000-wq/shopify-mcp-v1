import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/design/themes.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion.dart';

/// The visual row of a task: a planet orb (or a check when done), title,
/// one line of detail (reminder / notes / planet) and the drag handle.
/// Pure presentation – actions are wired by the panel.
class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, this.dragHandle, this.planet, this.planetName, this.reminder});

  final TaskRow task;

  /// The reorder handle (null: none, e.g. on a world's page).
  final Widget? dragHandle;
  final PlanetRow? planet;
  final String? planetName;

  /// Human description of the reminder, when one is set.
  final String? reminder;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final done = task.done;
    final notes = task.notes?.trim();
    final detail = <InlineSpan>[
      if (reminder != null) ...[
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: Space.xs),
            child: Icon(Icons.notifications_active_rounded, size: 13, color: t.accent),
          ),
        ),
        TextSpan(text: reminder),
      ] else if (notes != null && notes.isNotEmpty)
        TextSpan(text: notes.split('\n').first)
      else if (planetName != null)
        TextSpan(text: planetName),
    ];
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.xs, Space.m),
      glow: false,
      child: Row(
        children: [
          _Orb(planet: planet, done: done),
          const SizedBox(width: Space.m),
          Expanded(
            child: AnimatedOpacity(
              opacity: done ? 0.62 : 1,
              duration: context.motion(MadarMotion.short),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium!.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: t.textTertiary,
                      color: done ? t.textSecondary : t.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  if (detail.isNotEmpty)
                    Text.rich(
                      TextSpan(children: detail),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.35),
                    ),
                ],
              ),
            ),
          ),
          dragHandle ?? const SizedBox(width: Space.s),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.planet, required this.done});

  final PlanetRow? planet;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = planet;
    final palette = p == null ? null : (PlanetPalettes.byKey[p.key] ?? PlanetPalettes.fromColor(Color(p.color)));
    final Widget orb;
    if (done) {
      orb = Container(
        key: const ValueKey('done'),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.success.withValues(alpha: 0.18),
          border: Border.all(color: t.success.withValues(alpha: 0.9), width: 1.4),
          boxShadow: [BoxShadow(color: t.success.withValues(alpha: 0.35), blurRadius: 10)],
        ),
        child: Icon(Icons.check_rounded, size: 18, color: t.success),
      );
    } else if (palette != null) {
      orb = Container(
        key: ValueKey(p!.key),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.4),
            colors: [palette.glow, palette.surface, palette.deep],
            stops: const [0, 0.55, 1],
          ),
          boxShadow: [BoxShadow(color: palette.surface.withValues(alpha: 0.45), blurRadius: 12)],
        ),
        child: Icon(InteractionIcons.resolve(p.icon), size: 17, color: palette.deep),
      );
    } else {
      orb = SizedBox(
        key: const ValueKey('none'),
        width: 34,
        height: 34,
        child: Center(child: IslamicStar(size: 22, filled: false, color: t.brass, strokeWidth: 1.3)),
      );
    }
    return AnimatedSwitcher(
      duration: context.motion(MadarMotion.medium),
      switchInCurve: MadarMotion.decelerate,
      transitionBuilder: (child, a) => ScaleTransition(
        scale: a,
        child: FadeTransition(opacity: a, child: child),
      ),
      child: orb,
    );
  }
}
