import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import 'growth_texts.dart';

/// What the celebration says about the finished goal.
@immutable
class GoalCelebrationInfo {
  const GoalCelebrationInfo({required this.name, required this.amount, required this.days, required this.color});

  final String name;

  /// The total reached, with its unit.
  final String amount;

  /// Days it took (first day to the finishing log, both counted).
  final int days;
  final int? color;
}

/// Celebrates a goal reaching 100 %: a glowing full ring, particles and the
/// level-up chime (none under reduced motion). Returns true when the user
/// asks for a new goal.
Future<bool> showGoalCelebration(BuildContext context, GoalCelebrationInfo info) async =>
    await showInteractionSheet<bool>(context, builder: (_) => GoalCelebrationSheet(info: info)) ?? false;

class GoalCelebrationSheet extends StatefulWidget {
  const GoalCelebrationSheet({super.key, required this.info});

  final GoalCelebrationInfo info;

  @override
  State<GoalCelebrationSheet> createState() => _GoalCelebrationSheetState();
}

class _GoalCelebrationSheetState extends State<GoalCelebrationSheet> {
  final GlobalKey _ring = GlobalKey();

  @override
  void initState() {
    super.initState();
    Fx.fire(Sfx.levelUp);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ring = _ring.currentContext;
      if (!mounted || ring == null) return;
      final color = GrowthColors.goal(context.tokens, widget.info.color);
      Celebrate.burstFrom(ring, kind: CelebrationKind.orbitalRing, color: color);
      Future<void>.delayed(const Duration(milliseconds: 260), () {
        if (mounted && ring.mounted) {
          Celebrate.burstFrom(ring, kind: CelebrationKind.stardust, color: context.tokens.gold);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final text = Theme.of(context).textTheme;
    final info = widget.info;
    final color = GrowthColors.goal(t, info.color);
    return InteractionSheetFrame(
      title: l.growthCelebrateTitle,
      icon: Icons.emoji_events_rounded,
      body: Column(
        children: [
          const SizedBox(height: Space.m),
          SpringBuilder(
            value: 1,
            from: 0.6,
            builder: (context, v, child) => Transform.scale(scale: v, child: child),
            child: ProgressRing(
              key: _ring,
              value: 1,
              size: 148,
              strokeWidth: 11,
              color: color,
              gradientEnd: t.gold,
              semanticLabel: l.growthCelebrateTitle,
              child: Icon(Icons.emoji_events_rounded, size: 60, color: t.gold),
            ),
          ),
          const SizedBox(height: Space.xl),
          Text(info.name, textAlign: TextAlign.center, style: text.titleLarge),
          const SizedBox(height: Space.xs),
          Text(
            l.growthCelebrateBody(info.amount, texts.days(info.days)),
            textAlign: TextAlign.center,
            style: text.bodyLarge!.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: Space.l),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(
              label: l.growthCelebrateNext,
              icon: Icons.add_rounded,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: SheetButton(
              label: l.growthCelebrateThanks,
              primary: true,
              icon: Icons.favorite_rounded,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
        ],
      ),
    );
  }
}
