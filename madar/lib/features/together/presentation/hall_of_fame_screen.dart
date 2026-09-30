import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/together_providers.dart';
import '../domain/player_profile.dart';
import '../domain/trophies.dart';
import 'together_texts.dart';
import 'widgets/together_visuals.dart';

/// "Our Hall of Fame" (قاعة مجدنا): every trophy – earned ones in their
/// metal with the holder's jewel, the rest engraved with their progress.
class HallOfFameScreen extends ConsumerWidget {
  const HallOfFameScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = TogetherTexts.of(context);
    final overview = ref.watch(togetherOverviewProvider);
    return MadarScaffold(
      title: tx.l.togetherHallOfFame,
      backdropSeed: 6.1,
      animateBackdrop: animateBackdrop,
      body: switch (overview) {
        AsyncData(value: final o) => _HallBody(overview: o),
        AsyncError() => const Center(child: AnimatedEmptyState(kind: EmptyStateKind.noData)),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }
}

class _HallBody extends StatelessWidget {
  const _HallBody({required this.overview});

  final TogetherOverview overview;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final text = Theme.of(context).textTheme;
    final shelf = overview.trophies;
    final earnedIds = TrophyId.values.where(shelf.hasAny).length;
    final total = TrophyId.values.length;
    // Earned first (newest first), then the closest to earn.
    final ids = [...TrophyId.values]
      ..sort((a, b) {
        final ea = shelf.hasAny(a), eb = shelf.hasAny(b);
        if (ea != eb) return ea ? -1 : 1;
        if (ea) {
          DateTime latest(TrophyId id) =>
              shelf.trophies.where((x) => x.id == id).map((x) => x.earnedAt).reduce((p, q) => p.isAfter(q) ? p : q);
          return latest(b).compareTo(latest(a));
        }
        return TrophyRules.progress(b, overview.ledger).fraction.compareTo(TrophyRules.progress(a, overview.ledger).fraction);
      });
    return EntranceChoreo(
      id: 'together-hall',
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.l),
            sliver: SliverToBoxAdapter(
              child: StaggerItem(
                index: 0,
                child: GlassPanel(
                  seed: 7,
                  child: Row(
                    children: [
                      ProgressRing(
                        value: total == 0 ? 0 : earnedIds / total,
                        size: 84,
                        strokeWidth: 7,
                        color: t.gold,
                        semanticLabel: tx.l.togetherTrophiesEarned,
                        semanticValue: tx.digits(tx.l.togetherTrophiesProgress(tx.n(earnedIds), tx.n(total))),
                        child: Icon(Icons.emoji_events_rounded, color: t.gold, size: 30),
                      ),
                      const SizedBox(width: Space.l),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.digits(tx.l.togetherTrophiesProgress(tx.n(earnedIds), tx.n(total))),
                              style: text.headlineSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
                            ),
                            Text(tx.l.togetherTrophiesEarned, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
                            const SizedBox(height: Space.s),
                            Row(
                              children: [
                                for (final p in overview.profiles.both) ...[
                                  TogetherAvatarView(profile: p, displayName: tx.rawName(p), size: 28, ring: false),
                                  const SizedBox(width: Space.xs),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.xxxl),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 132,
                mainAxisSpacing: Space.m,
                crossAxisSpacing: Space.m,
                childAspectRatio: 0.66,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => StaggerItem(
                  index: i + 1,
                  child: _TrophyCell(id: ids[i], overview: overview),
                ),
                childCount: ids.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrophyCell extends StatelessWidget {
  const _TrophyCell({required this.id, required this.overview});

  final TrophyId id;
  final TogetherOverview overview;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final text = Theme.of(context).textTheme;
    final earned = overview.trophies.trophies.where((e) => e.id == id).toList();
    final isEarned = earned.isNotEmpty;
    final holders = {for (final e in earned) ?e.key.holder};
    final progress = TrophyRules.progress(id, overview.ledger);
    return GlassCard(
      key: ValueKey('together-trophy-${id.name}'),
      onTap: () => unawaited(showTrophySheet(context, id)),
      semanticLabel: '${tx.trophy(id)}${tx.arabic ? '،' : ','} ${isEarned ? tx.tier(id.tier) : tx.l.togetherLocked}',
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.m, Space.xs, Space.s),
      child: Column(
        children: [
          TrophyMedal(
            id: id,
            size: 58,
            earned: isEarned,
            holderColor: holders.length == 1 ? TogetherLook.colorOf(overview.profiles.of(holders.first)) : null,
          ),
          const SizedBox(height: Space.s),
          Text(
            tx.trophy(id),
            style: text.labelLarge?.copyWith(color: isEarned ? t.textPrimary : t.textSecondary),
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              tx.trophyDescription(id, gameId: earned.firstOrNull?.key.gameId),
              style: text.labelSmall?.copyWith(color: t.textTertiary, height: 1.3),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          if (isEarned)
            Text(
              earned.length > 1 ? '${tx.tier(id.tier)} ×${tx.n(earned.length)}' : tx.tier(id.tier),
              style: text.labelSmall?.copyWith(color: t.gold),
              maxLines: 1,
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 3,
                color: t.gold,
                backgroundColor: t.glassBorder,
              ),
            ),
            const SizedBox(height: 2),
            Text(tx.progress(progress), style: text.labelSmall?.copyWith(color: t.textTertiary)),
          ],
        ],
      ),
    );
  }
}

/// Details of one trophy: what it is for, who earned it and when, or how
/// close the couple is.
Future<void> showTrophySheet(BuildContext context, TrophyId id) =>
    showInteractionSheet<void>(context, builder: (_) => _TrophySheet(id: id));

class _TrophySheet extends ConsumerWidget {
  const _TrophySheet({required this.id});

  final TrophyId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final o = ref.watch(togetherOverviewProvider).value;
    if (o == null) return const SizedBox.shrink();
    final earned = o.trophies.newestFirst.where((e) => e.id == id).toList();
    final progress = TrophyRules.progress(id, o.ledger);
    return InteractionSheetFrame(
      title: tx.trophy(id),
      subtitle: tx.tier(id.tier),
      icon: TogetherLook.trophyIcon(id),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: TrophyMedal(id: id, size: 112, earned: earned.isNotEmpty)),
          const SizedBox(height: Space.l),
          Text(
            tx.trophyDescription(id, gameId: earned.firstOrNull?.key.gameId),
            style: text.titleMedium?.copyWith(color: t.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.l),
          if (earned.isEmpty) ...[
            Text(l.togetherLocked, style: text.bodyMedium?.copyWith(color: t.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: Space.s),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 6,
                color: t.gold,
                backgroundColor: t.glassBorder,
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(tx.progress(progress), style: text.labelMedium?.copyWith(color: t.textTertiary), textAlign: TextAlign.center),
          ] else
            for (final e in earned)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                child: GlassCard(
                  child: Row(
                    children: [
                      if (e.key.holder != null)
                        TogetherAvatarView(
                          profile: o.profiles.of(e.key.holder!),
                          displayName: tx.rawName(o.profiles.of(e.key.holder!)),
                          size: 36,
                        )
                      else
                        Icon(Icons.diversity_1_rounded, color: t.gold),
                      const SizedBox(width: Space.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.key.holder == null
                                  ? l.togetherTrophyShared
                                  : l.togetherTrophyHolder(tx.name(o.profiles.of(e.key.holder!))),
                              style: text.titleSmall,
                            ),
                            Text(
                              [
                                l.togetherEarnedOn(tx.date(e.earnedAt)),
                                if (e.key.gameId != null) tx.game(e.key.gameId!),
                              ].join(' · '),
                              style: text.bodySmall?.copyWith(color: t.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// After a match was recorded: celebrates the trophies it earned (stardust
/// burst + a sheet with the new medals). Nothing happens without new ones.
Future<void> celebrateNewTrophies(BuildContext context, RecordedMatch recorded) async {
  if (recorded.newTrophies.isEmpty) return;
  Fx.fire(Sfx.levelUp);
  Celebrate.burstFrom(context, kind: CelebrationKind.stardust);
  await showInteractionSheet<void>(context, builder: (_) => _NewTrophiesSheet(trophies: recorded.newTrophies));
}

class _NewTrophiesSheet extends ConsumerWidget {
  const _NewTrophiesSheet({required this.trophies});

  final List<EarnedTrophy> trophies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final text = Theme.of(context).textTheme;
    final profiles = ref.watch(togetherProfilesProvider).value ?? TogetherProfiles.defaults();
    return InteractionSheetFrame(
      title: tx.l.togetherNewTrophies,
      icon: Icons.emoji_events_rounded,
      body: Wrap(
        alignment: WrapAlignment.center,
        spacing: Space.l,
        runSpacing: Space.l,
        children: [
          for (final e in trophies)
            SizedBox(
              width: 120,
              child: Column(
                children: [
                  TrophyMedal(
                    id: e.id,
                    size: 84,
                    holderColor: e.key.holder == null ? null : TogetherLook.colorOf(profiles.of(e.key.holder!)),
                  ),
                  const SizedBox(height: Space.s),
                  Text(tx.trophy(e.id), style: text.titleSmall, textAlign: TextAlign.center),
                  Text(
                    tx.trophyDescription(e.id, gameId: e.key.gameId),
                    style: text.bodySmall?.copyWith(color: t.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
