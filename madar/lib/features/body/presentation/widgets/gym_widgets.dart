/// The gym's own pieces: the machine's picture, the movement's video row,
/// one logged set, the rest clock, and the card that says what his own
/// numbers come to.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/gym_media.dart';
import '../../domain/gym.dart';
import '../../domain/training.dart';
import '../gym_texts.dart';
import 'body_widgets.dart';

/// The machine's picture, resolved from the file name stored on the
/// exercise. A file that is gone says so instead of showing a broken box;
/// nothing stored shows the icon of the planet.
class GymPhotoView extends ConsumerWidget {
  const GymPhotoView({
    super.key,
    required this.photo,
    required this.name,
    this.size = 72,
    this.radius,
    this.onTap,
  });

  /// The stored file name (null: he has not added one).
  final String? photo;

  /// The exercise's name, for the label a screen reader reads.
  final String name;
  final double size;
  final double? radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final r = radius ?? t.radiusM;
    final stored = photo;
    Widget frame(Widget child, {String? semantics}) => MadarPressable(
      onTap: onTap,
      enabled: onTap != null,
      sfx: onTap == null ? null : Sfx.tap,
      minTapTarget: onTap == null ? null : MadarPressable.minTouchTarget,
      semanticLabel: semantics ?? l.gymPhotoOf(name),
      excludeChildSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          color: t.glassFill,
          border: Border.all(color: t.glassBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
    if (stored == null) {
      return frame(
        Center(child: Icon(Icons.fitness_center_rounded, size: size * 0.4, color: p.training)),
        semantics: l.gymAddPhoto,
      );
    }
    return FutureBuilder<File?>(
      future: ref.watch(gymMediaProvider).photoFile(stored),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return frame(
            Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.xs),
                child: Text(
                  snapshot.connectionState == ConnectionState.waiting ? '' : l.gymPhotoMissing,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.textTertiary),
                ),
              ),
            ),
          );
        }
        return frame(Image.file(file, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()));
      },
    );
  }
}

/// His muscles, in his own words.
class GymMuscleChips extends StatelessWidget {
  const GymMuscleChips({super.key, required this.muscles});

  final List<String> muscles;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    if (muscles.isEmpty) {
      return Text(l.gymNoMuscles, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary));
    }
    return Semantics(
      label: '${l.gymMuscles}: ${muscles.join(l.bodyListSep)}',
      excludeSemantics: true,
      child: Wrap(
        spacing: Space.xs,
        runSpacing: Space.xs,
        children: [
          for (final m in muscles)
            BodyPill(label: m, icon: Icons.accessibility_new_rounded, color: BodyPalette(t).training, dense: true),
        ],
      ),
    );
  }
}

/// One set as it was logged: its number, a warm-up badge, and its reps × kg.
class GymSetLine extends StatelessWidget {
  const GymSetLine({super.key, required this.index, required this.set, this.dense = false});

  /// 1-based, as he counts them.
  final int index;
  final LoggedSet set;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final gx = GymTexts.of(context);
    final text = Theme.of(context).textTheme;
    final value = gx.set(set);
    return Semantics(
      label: [
        gx.fmt.localizeDigits(l.gymSetOf(gx.fmt.formatInt(index), gx.fmt.formatInt(index))),
        if (set.warmup) l.gymWarmup,
        value,
      ].join('. '),
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              gx.fmt.formatInt(index),
              style: text.labelMedium?.copyWith(color: t.textTertiary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: Space.xs),
          Expanded(child: Text(value, style: dense ? text.bodyMedium : text.titleSmall)),
          if (set.warmup) BodyPill(label: l.gymWarmup, icon: Icons.whatshot_outlined, color: t.gold, dense: true),
        ],
      ),
    );
  }
}

/// The rest between two sets.
///
/// It is driven by the Body clock, like every other running number on the
/// planet: it rebuilds only when the second actually changes, so a frozen
/// clock keeps no frames scheduled. With a rest he set it counts **down**
/// to it and pings once; with no rest set it counts **up**, so Madar never
/// puts a number of seconds in his mouth.
class GymRestCard extends ConsumerStatefulWidget {
  const GymRestCard({super.key, required this.start, required this.targetSec, required this.onDone, this.onAdd});

  /// When he finished the set.
  final DateTime start;

  /// The rest he set for this exercise, in seconds (null: count up).
  final int? targetSec;
  final VoidCallback onDone;

  /// Adds [GymRestCard.bump] seconds to the target.
  final VoidCallback? onAdd;

  /// What «زيد» adds.
  static const int bump = 30;

  @override
  ConsumerState<GymRestCard> createState() => _GymRestCardState();
}

class _GymRestCardState extends ConsumerState<GymRestCard> {
  bool _pinged = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final gx = GymTexts.of(context);
    final text = Theme.of(context).textTheme;
    return BodyTicker(
      builder: (context, now) {
        final elapsed = now.difference(widget.start);
        final target = widget.targetSec;
        final counting = target == null;
        final left = counting ? elapsed : Duration(seconds: target) - elapsed;
        final over = !counting && left <= Duration.zero;
        if (over && !_pinged) {
          _pinged = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Fx.fire(Sfx.levelUp);
          });
        }
        return BodyCard(
          key: const ValueKey('gym.rest'),
          title: over ? l.gymRestOver : l.gymResting,
          icon: Icons.timer_outlined,
          iconColor: over ? t.success : p.water,
          seed: 3.3,
          semanticLabel: '${over ? l.gymRestOver : l.gymResting}: ${gx.clock(left.abs())}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  gx.clock(left.abs()),
                  style: text.displaySmall?.copyWith(
                    color: over ? t.success : t.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (counting) ...[
                const SizedBox(height: Space.xs),
                BodyHint(l.gymRestCountingUp, icon: Icons.hourglass_empty_rounded),
              ],
              const SizedBox(height: Space.m),
              Row(
                children: [
                  if (widget.onAdd != null) ...[
                    Expanded(
                      child: MadarButton(
                        key: const ValueKey('gym.rest.add'),
                        label: l.gymRestPlus(gx.seconds(GymRestCard.bump)),
                        icon: Icons.add_rounded,
                        variant: MadarButtonVariant.secondary,
                        onPressed: widget.onAdd,
                      ),
                    ),
                    const SizedBox(width: Space.s),
                  ],
                  Expanded(
                    flex: 2,
                    child: MadarButton(
                      key: const ValueKey('gym.rest.done'),
                      label: l.gymSkipRest,
                      icon: Icons.play_arrow_rounded,
                      variant: MadarButtonVariant.primary,
                      onPressed: widget.onDone,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What his own log comes to for the next session.
///
/// The card is arithmetic on his rows and says so on its face: the number,
/// then where it came from (last time, the step he took himself, how many
/// of his days were read), then one line in plain words that this is not
/// advice. [onUse] only fills the numbers into a sheet he is already
/// filling; nothing is ever logged for him.
class GymNextLoadCard extends StatelessWidget {
  const GymNextLoadCard({super.key, required this.load, this.onUse, this.compact = false});

  final NextLoad load;
  final VoidCallback? onUse;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final p = BodyPalette(t);
    final gx = GymTexts.of(context);
    final text = Theme.of(context).textTheme;
    if (!load.any) {
      return BodyCard(
        key: const ValueKey('gym.next.empty'),
        title: l.gymNextTitle,
        icon: Icons.calculate_outlined,
        seed: 2.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.gymNothingYet, style: text.titleSmall),
            const SizedBox(height: Space.xs),
            Text(l.gymNothingYetBody, style: text.bodySmall?.copyWith(color: t.textSecondary)),
          ],
        ),
      );
    }
    return BodyCard(
      key: const ValueKey('gym.next'),
      title: l.gymNextTitle,
      icon: Icons.calculate_outlined,
      iconColor: p.training,
      seed: 2.6,
      semanticLabel: gx.loadSemantics(load),
      trailing: load.isStepUp
          ? BodyPill(label: gx.stepValue(load), icon: Icons.north_east_rounded, color: t.success, dense: true)
          : null,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              gx.loadValue(load),
              style: text.headlineSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Space.xs),
            Text(gx.headline(load), style: text.bodyMedium?.copyWith(color: t.textSecondary)),
            const SizedBox(height: Space.s),
            for (final line in gx.evidence(load))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(line, style: text.bodySmall?.copyWith(color: t.textTertiary)),
              ),
            const SizedBox(height: Space.xs),
            // The health rule, in the words on the screen.
            BodyHint(l.gymNotAdvice, icon: Icons.info_outline_rounded),
            if (onUse != null && !compact) ...[
              const SizedBox(height: Space.m),
              MadarButton(
                key: const ValueKey('gym.next.use'),
                label: l.gymUseThese,
                icon: Icons.edit_note_rounded,
                variant: MadarButtonVariant.secondary,
                sfx: Sfx.sheetOpen,
                onPressed: onUse,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
