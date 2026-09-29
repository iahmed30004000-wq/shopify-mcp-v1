import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import '../hifz_labels.dart';

/// The six SM-2 grades as two rows of three, from "blank" at the reading
/// start to "perfect" at its end; each names the grade and says what it
/// means.
class HifzGradeBar extends StatelessWidget {
  const HifzGradeBar({super.key, required this.onGrade, this.enabled = true});

  final ValueChanged<int> onGrade;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget row(List<int> grades) => Row(
      children: [
        for (final (i, q) in grades.indexed) ...[
          if (i > 0) const SizedBox(width: Space.s),
          Expanded(
            child: _GradeButton(grade: q, enabled: enabled, onTap: () => onGrade(q)),
          ),
        ],
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row(const [0, 1, 2]),
        const SizedBox(height: Space.s),
        row(const [3, 4, 5]),
      ],
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({required this.grade, required this.enabled, required this.onTap});

  final int grade;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = hifzGradeColor(t, grade);
    final sfx = grade >= 4 ? Sfx.complete : (grade >= 3 ? Sfx.tap : Sfx.toggleOff);
    return MadarPressable(
      onTap: enabled ? onTap : null,
      sfx: sfx,
      semanticLabel: '${fmt.formatInt(grade)}: ${hifzGradeLabel(l, grade)}. ${hifzGradeHint(l, grade)}',
      excludeChildSemantics: true,
      child: Container(
        // Grows with larger text so the hint – what the grade means – stays
        // readable rather than cut off.
        height: MediaQuery.textScalerOf(context).scale(72).clamp(72.0, 124.0),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.s, Space.s, Space.xs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              c.withValues(alpha: t.isDark ? 0.20 : 0.14),
              c.withValues(alpha: t.isDark ? 0.08 : 0.05),
            ],
          ),
          border: Border.all(color: c.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    hifzGradeLabel(l, grade),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall!.copyWith(color: c, height: 1.2),
                  ),
                ),
                Text(fmt.formatInt(grade), style: text.labelSmall!.copyWith(color: c.withValues(alpha: 0.8))),
              ],
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                hifzGradeHint(l, grade),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall!.copyWith(color: t.textSecondary, height: 1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
