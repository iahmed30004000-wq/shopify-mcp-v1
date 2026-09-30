import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/together_providers.dart';
import '../domain/head_to_head.dart';
import '../domain/match_record.dart';
import '../domain/player_profile.dart';
import '../domain/trophies.dart';
import 'hall_of_fame_screen.dart';
import 'mode_picker.dart';
import 'profile_sheet.dart';
import 'together_texts.dart';
import 'widgets/together_visuals.dart';

/// Together Mode home: the two players face to face with the overall score,
/// the streaks, a preview of "Our Hall of Fame", head-to-head per game and
/// the recent matches.
class TogetherHomeScreen extends ConsumerWidget {
  const TogetherHomeScreen({super.key, this.onOpenHallOfFame, this.animateBackdrop = true});

  /// Opens the Hall of Fame; default: pushes [HallOfFameScreen].
  final VoidCallback? onOpenHallOfFame;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = TogetherTexts.of(context);
    final overview = ref.watch(togetherOverviewProvider);
    void openHall() {
      final open = onOpenHallOfFame;
      if (open != null) {
        open();
      } else {
        Fx.fire(Sfx.navigate);
        unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HallOfFameScreen())));
      }
    }

    return MadarScaffold(
      title: tx.l.togetherTitle,
      backdropSeed: 4.4,
      animateBackdrop: animateBackdrop,
      actions: [
        MadarButton.icon(
          key: const ValueKey('together-settings'),
          icon: Icons.tune_rounded,
          onPressed: () => unawaited(showTogetherSettingsSheet(context)),
          semanticLabel: tx.l.togetherSettingsTitle,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
        ),
      ],
      body: switch (overview) {
        AsyncData(value: final o) => _HomeBody(overview: o, onOpenHallOfFame: openHall),
        AsyncError() => const Center(child: AnimatedEmptyState(kind: EmptyStateKind.noData)),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.overview, required this.onOpenHallOfFame});

  final TogetherOverview overview;
  final VoidCallback onOpenHallOfFame;

  @override
  Widget build(BuildContext context) {
    final tx = TogetherTexts.of(context);
    final l = tx.l;
    final o = overview;
    final games = o.ledger.gamesByRecency.take(6).toList();
    final recent = o.history.take(8).toList();
    var i = 0;
    const header = EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.m);
    return EntranceChoreo(
      id: 'together-home',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        children: [
          StaggerItem(index: i++, child: _RivalryHero(overview: o)),
          const SizedBox(height: Space.m),
          StaggerItem(index: i++, child: _StreakStrip(overview: o)),
          StaggerItem(
            index: i++,
            child: SectionHeader(
              title: l.togetherHallOfFame,
              actionLabel: l.togetherSeeAll,
              onAction: onOpenHallOfFame,
              padding: header,
            ),
          ),
          StaggerItem(
            index: i++,
            child: _ShelfPreview(overview: o, onOpen: onOpenHallOfFame),
          ),
          if (games.isNotEmpty) ...[
            StaggerItem(
              index: i++,
              child: SectionHeader(title: l.togetherHeadToHead, padding: header),
            ),
            for (final g in games)
              StaggerItem(
                index: i++,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                  child: _GameRow(gameId: g.key, tally: g.value, profiles: o.profiles),
                ),
              ),
          ],
          StaggerItem(
            index: i++,
            child: SectionHeader(title: l.togetherRecentMatches, padding: header),
          ),
          if (recent.isEmpty)
            StaggerItem(
              index: i++,
              child: GlassCard(
                key: const ValueKey('together-empty'),
                padding: const EdgeInsetsDirectional.all(Space.l),
                child: Column(
                  children: [
                    Icon(Icons.sports_esports_rounded, size: 36, color: context.tokens.gold),
                    const SizedBox(height: Space.s),
                    Text(l.togetherEmptyTitle, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: Space.xs),
                    Text(
                      l.togetherEmptyBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final r in recent)
              StaggerItem(
                index: i++,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                  child: TogetherMatchTile(record: r, profiles: o.profiles),
                ),
              ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- hero

class _RivalryHero extends StatelessWidget {
  const _RivalryHero({required this.overview});

  final TogetherOverview overview;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final all = overview.ledger.overall;
    final profiles = overview.profiles;
    final leader = all.leader;
    final caption = !overview.hasMatches
        ? l.togetherEmptyTitle
        : leader == null
        ? l.togetherAllSquare
        : l.togetherLeads(tx.name(profiles.of(leader)), tx.n((all.winsOne - all.winsTwo).abs()));

    Widget player(TogetherProfile p) {
      final title = tx.title(p);
      return Expanded(
        child: MadarPressable(
          key: ValueKey('together-avatar-${p.slot.name}'),
          onTap: () => unawaited(showTogetherProfileSheet(context, p.slot)),
          sfx: Sfx.sheetOpen,
          semanticLabel: l.togetherEditProfile(tx.name(p)),
          excludeChildSemantics: true,
          child: Column(
            children: [
              TogetherAvatarView(
                profile: p,
                displayName: tx.rawName(p),
                size: 78,
                glow: leader == p.slot,
              ),
              const SizedBox(height: Space.s),
              Text(
                tx.rawName(p),
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: t.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                title ?? ' ',
                style: text.labelSmall?.copyWith(color: t.gold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GlassPanel(
      key: const ValueKey('together-hero'),
      seed: 3,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.l, Space.m, Space.l),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              player(profiles.one),
              AstrolabeRing(
                size: 128,
                showNumerals: false,
                child: Semantics(
                  label: '${l.togetherWinsLabel}: ${tx.name(profiles.one)} ${tx.n(all.winsOne)}, '
                      '${tx.name(profiles.two)} ${tx.n(all.winsTwo)}',
                  excludeSemantics: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Score(value: all.winsOne, color: TogetherLook.colorOf(profiles.one)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                            child: Text('–', style: text.headlineSmall?.copyWith(color: t.textTertiary)),
                          ),
                          _Score(value: all.winsTwo, color: TogetherLook.colorOf(profiles.two)),
                        ],
                      ),
                      Text(l.togetherWinsLabel, style: text.labelSmall?.copyWith(color: t.textSecondary)),
                    ],
                  ),
                ),
              ),
              player(profiles.two),
            ],
          ),
          const SizedBox(height: Space.m),
          Text(
            caption,
            style: text.titleSmall?.copyWith(color: t.textPrimary),
            textAlign: TextAlign.center,
          ),
          if (overview.hasMatches) ...[
            const SizedBox(height: Space.xxs),
            Text(
              '${tx.matches(all.matches)} · ${tx.draws(all.draws)}',
              style: text.bodySmall?.copyWith(color: t.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tx = TogetherTexts.of(context);
    return Text(
      tx.n(value),
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        color: Color.lerp(color, context.tokens.textPrimary, 0.25),
        fontWeight: FontWeight.w700,
        shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 12)],
      ),
    );
  }
}

// ----------------------------------------------------------------- streaks

class _StreakStrip extends StatelessWidget {
  const _StreakStrip({required this.overview});

  final TogetherOverview overview;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final l = tx.l;
    final o = overview;
    final all = o.ledger.overall;
    final days = o.dayStreak;
    final holder = all.streakHolder;
    final playedToday = o.ledger.playedToday(o.now);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MiniTile(
              key: const ValueKey('together-streak-days'),
              icon: Icons.local_fire_department_rounded,
              color: t.warning,
              label: l.togetherDayStreakLabel,
              value: days > 0 ? tx.days(days) : '—',
              caption: days == 0
                  ? l.togetherNoStreak
                  : playedToday
                  ? l.togetherPlayedToday
                  : l.togetherPlayTodayHint,
            ),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: _MiniTile(
              key: const ValueKey('together-streak-wins'),
              icon: Icons.bolt_rounded,
              color: holder == null ? t.gold : TogetherLook.colorOf(o.profiles.of(holder)),
              label: l.togetherWinStreakLabel,
              value: holder == null || all.streakLength < 2 ? '—' : '×${tx.n(all.streakLength)}',
              caption: holder == null || all.streakLength < 2 ? l.togetherNoStreak : tx.rawName(o.profiles.of(holder)),
            ),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: _MiniTile(
              key: const ValueKey('together-streak-team'),
              icon: Icons.diversity_1_rounded,
              color: t.success,
              label: l.togetherCoopLabel,
              value: tx.n(all.coopWins),
              caption: all.coopStreak > 1 ? '×${tx.n(all.coopStreak)}' : ' ',
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label: $value. $caption',
      excludeSemantics: true,
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.s, Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color, shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 10)]),
            const SizedBox(height: Space.xs),
            Text(
              value,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: t.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(label, style: text.labelSmall?.copyWith(color: t.textSecondary), maxLines: 2),
            const Spacer(),
            Text(
              caption,
              style: text.labelSmall?.copyWith(color: t.textTertiary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- shelf

/// Up to eight medals: the newest trophies, then the closest ones to earn.
class _ShelfPreview extends StatelessWidget {
  const _ShelfPreview({required this.overview, required this.onOpen});

  final TogetherOverview overview;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final text = Theme.of(context).textTheme;
    final earned = overview.trophies.newestFirst;
    final lockedIds = [
      for (final id in TrophyId.values)
        if (!overview.trophies.hasAny(id)) id,
    ]..sort((a, b) => TrophyRules.progress(b, overview.ledger).fraction.compareTo(TrophyRules.progress(a, overview.ledger).fraction));
    final items = <Widget>[
      for (final e in earned.take(8))
        _ShelfItem(
          id: e.id,
          earned: true,
          holderColor: e.key.holder == null ? null : TogetherLook.colorOf(overview.profiles.of(e.key.holder!)),
          caption: tx.date(e.earnedAt),
        ),
      for (final id in lockedIds.take(earned.isEmpty ? 5 : 3))
        _ShelfItem(
          id: id,
          earned: false,
          progress: TrophyRules.progress(id, overview.ledger),
          caption: tx.progress(TrophyRules.progress(id, overview.ledger)),
        ),
    ];
    return MadarPressable(
      key: const ValueKey('together-shelf'),
      onTap: onOpen,
      sfx: Sfx.navigate,
      pressScale: 0.99,
      semanticLabel: tx.l.togetherHallOfFame,
      child: GlassPanel(
        seed: 5,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.m, Space.s, Space.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (earned.isEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Space.s, start: Space.s),
                child: Text(tx.l.togetherShelfEmpty, style: text.bodySmall?.copyWith(color: t.textSecondary)),
              ),
            SizedBox(
              height: 128,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: items,
              ),
            ),
            // The brass shelf.
            Container(
              height: 3,
              margin: const EdgeInsetsDirectional.symmetric(horizontal: Space.s),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(colors: [t.brassDark.withValues(alpha: 0), t.brass, t.gold, t.brass, t.brassDark.withValues(alpha: 0)]),
                boxShadow: [BoxShadow(color: t.gold.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfItem extends StatelessWidget {
  const _ShelfItem({required this.id, required this.earned, required this.caption, this.holderColor, this.progress});

  final TrophyId id;
  final bool earned;
  final String caption;
  final Color? holderColor;
  final TrophyProgress? progress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          TrophyMedal(id: id, size: 60, earned: earned, holderColor: holderColor),
          const SizedBox(height: Space.xs),
          Text(
            tx.trophy(id),
            style: text.labelMedium?.copyWith(color: earned ? t.textPrimary : t.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            caption,
            style: text.labelSmall?.copyWith(color: earned ? t.gold : t.textTertiary),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ head to head

class _GameRow extends StatelessWidget {
  const _GameRow({required this.gameId, required this.tally, required this.profiles});

  final String gameId;
  final GameTally tally;
  final TogetherProfiles profiles;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final text = Theme.of(context).textTheme;
    final c1 = TogetherLook.colorOf(profiles.one);
    final c2 = TogetherLook.colorOf(profiles.two);
    final coop = tally.versusMatches == 0 && tally.matches > 0;
    final segments = coop
        ? [(tally.coopWins, t.success), (tally.coopLosses, t.danger.withValues(alpha: 0.7))]
        : [(tally.winsOne, c1), (tally.draws, t.textTertiary.withValues(alpha: 0.5)), (tally.winsTwo, c2)];
    final total = segments.fold<int>(0, (s, e) => s + e.$1);
    return GlassCard(
      key: ValueKey('together-game-$gameId'),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
      child: Row(
        children: [
          _GameBadge(gameId: gameId),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tx.game(gameId),
                        style: text.titleSmall?.copyWith(color: t.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      coop ? tx.score(tally.coopWins, tally.coopLosses) : tx.score(tally.winsOne, tally.winsTwo),
                      style: text.titleSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: total == 0
                        ? ColoredBox(color: t.glassBorder)
                        : Row(
                            children: [
                              for (final (n, color) in segments)
                                if (n > 0) Expanded(flex: n, child: ColoredBox(color: color)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  tally.draws > 0 && !coop ? '${tx.matches(tally.matches)} · ${tx.draws(tally.draws)}' : tx.matches(tally.matches),
                  style: text.labelSmall?.copyWith(color: t.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameBadge extends StatelessWidget {
  const _GameBadge({required this.gameId, this.size = 40});

  final String gameId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [t.accentSoft, t.accent.withValues(alpha: 0.05)]),
        border: Border.all(color: t.gold.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Icon(TogetherLook.gameIcon(gameId), size: size * 0.5, color: t.accent),
    );
  }
}

/// One recorded match: game, result, score and date.
class TogetherMatchTile extends StatelessWidget {
  const TogetherMatchTile({super.key, required this.record, required this.profiles});

  final MatchRecord record;
  final TogetherProfiles profiles;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final text = Theme.of(context).textTheme;
    final winner = record.outcome.winner;
    final Widget lead = winner != null
        ? TogetherAvatarView(profile: profiles.of(winner), displayName: tx.rawName(profiles.of(winner)), size: 30, ring: false)
        : Icon(
            switch (record.outcome) {
              MatchOutcome.teamWon => Icons.diversity_1_rounded,
              MatchOutcome.teamLost => Icons.sentiment_neutral_rounded,
              _ => Icons.handshake_rounded,
            },
            size: 24,
            color: record.outcome == MatchOutcome.teamWon ? t.success : t.textTertiary,
          );
    return GlassCard(
      key: ValueKey('together-match-${record.id}'),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.m, Space.s + 2),
      child: Row(
        children: [
          _GameBadge(gameId: record.gameId, size: 36),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.game(record.gameId),
                  style: text.titleSmall?.copyWith(color: t.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${tx.outcome(record, profiles)} · ${tx.date(record.endedAt)}',
                  style: text.bodySmall?.copyWith(color: t.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (record.hasScores) ...[
            Text(
              tx.score(record.scoreOne!, record.scoreTwo!),
              style: text.titleSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: Space.s),
          ],
          lead,
        ],
      ),
    );
  }
}
