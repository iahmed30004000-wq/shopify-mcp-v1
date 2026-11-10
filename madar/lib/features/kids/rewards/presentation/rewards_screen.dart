import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../../core/kids_section.dart';
import '../domain/lanterns.dart';
import 'lantern_painter.dart';
import 'play_kit.dart';

/// «جوائزي»: the stars collected and the shelf of lanterns (design 11).
/// Stars are only a collection: nothing here locks or takes anything.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final stars = ref.watch(kidsStarCountProvider);
    final lit = Lanterns.litCount(stars);
    final toNext = Lanterns.starsToNext(stars);
    return Scaffold(
      backgroundColor: KidsColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            PlayHeader(title: l.kidsPlayRewardsTitle, showStars: false),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StarCard(stars: stars),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            toNext == 0 ? l.kidsPlayAllLanternsLit : l.kidsPlayNextLantern,
                            style: KidsText.subtitle,
                          ),
                        ),
                        if (toNext > 0)
                          Text(
                            l.kidsPlayStarsLeft(kidsNumber(context, toNext)),
                            style: KidsText.small.copyWith(fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ProgressBar(value: Lanterns.progress(stars)),
                    const SizedBox(height: 20),
                    for (var row = 0; row < 3; row++)
                      _Shelf(
                        children: [
                          for (var i = row * 3; i < row * 3 + 3; i++)
                            LanternView(
                              color: lanternColors[i % lanternColors.length],
                              lit: i < lit,
                              semanticLabel: i < lit
                                  ? l.kidsPlayLanternLit(kidsNumber(context, i + 1))
                                  : l.kidsPlayLanternDark(kidsNumber(context, i + 1)),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: KidsColors.teal100,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, color: KidsColors.teal700),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                l.kidsPlayStarsSafe,
                                style: KidsText.small.copyWith(color: KidsColors.teal700, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarCard extends StatelessWidget {
  const _StarCard({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Semantics(
      label: l.kidsPlayStarsSemantics(kidsNumber(context, stars)),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: KidsColors.night800,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [BoxShadow(color: KidsColors.night900.withValues(alpha: .25), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            const KhatamStarIcon(size: 84, core: KidsColors.sun300),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      kidsNumber(context, stars),
                      style: KidsText.display.copyWith(color: Colors.white, fontSize: 56, height: 1.1),
                    ),
                  ),
                  Text(l.kidsPlayStarsCollected, style: KidsText.subtitle.copyWith(color: KidsColors.sun300)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      height: 20,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: KidsColors.sand)),
          // Fills from the reading start (the right in Arabic).
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.02, 1.0),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [KidsColors.sun300, KidsColors.sun500]),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: children),
        const SizedBox(height: 4),
        Container(
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [KidsColors.sand2, KidsColors.sand],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    ),
  );
}
