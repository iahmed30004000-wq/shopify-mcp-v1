import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/spring_press.dart';
import '../../../../core/sound/sound_api.dart';
import '../../engine/cinema_engine.dart';
import '../../engine/stage/stage_kit.dart';
import '../cinema_records.dart';
import '../posters/poster_painter.dart';
import 'lobby_art.dart';

/// The shelves of the programme.
enum ProgrammeShelf { features, cards, board, arcade, puzzle, word, backstage }

/// Which shelf an entry sits on.
ProgrammeShelf shelfOf(GameCatalogEntry e) {
  if (e.tier == GameTier.feature) return ProgrammeShelf.features;
  return switch (e.genre) {
    GameGenre.card => ProgrammeShelf.cards,
    GameGenre.board => ProgrammeShelf.board,
    GameGenre.puzzle => ProgrammeShelf.puzzle,
    GameGenre.word => ProgrammeShelf.word,
    GameGenre.demo => ProgrammeShelf.backstage,
    _ => ProgrammeShelf.arcade,
  };
}

String shelfLabel(L10n l10n, ProgrammeShelf s) => switch (s) {
  ProgrammeShelf.features => l10n.cinemaFeatures,
  ProgrammeShelf.cards => l10n.cinemaHallGenreCards,
  ProgrammeShelf.board => l10n.cinemaHallGenreBoard,
  ProgrammeShelf.arcade => l10n.cinemaHallGenreArcade,
  ProgrammeShelf.puzzle => l10n.cinemaHallGenrePuzzle,
  ProgrammeShelf.word => l10n.cinemaHallGenreWord,
  ProgrammeShelf.backstage => l10n.cinemaHallBackstage,
};

/// Tier 2 shelves announce what is coming with locked slots.
bool _announces(ProgrammeShelf s) =>
    s == ProgrammeShelf.cards ||
    s == ProgrammeShelf.board ||
    s == ProgrammeShelf.arcade ||
    s == ProgrammeShelf.puzzle ||
    s == ProgrammeShelf.word;

/// The programme filters (era, kind, ready to play).
class ProgrammeFilter extends ChangeNotifier {
  Era? _era;
  ProgrammeShelf? _shelf;
  bool _readyOnly = false;

  Era? get era => _era;
  ProgrammeShelf? get shelf => _shelf;
  bool get readyOnly => _readyOnly;

  set era(Era? v) {
    if (v == _era) return;
    _era = v;
    notifyListeners();
  }

  set shelf(ProgrammeShelf? v) {
    if (v == _shelf) return;
    _shelf = v;
    notifyListeners();
  }

  set readyOnly(bool v) {
    if (v == _readyOnly) return;
    _readyOnly = v;
    notifyListeners();
  }

  bool accepts(GameCatalogEntry e) => (_era == null || e.era == _era) && (!_readyOnly || e.isPlayable);

  /// Locked slots show only on the unfiltered programme.
  bool get showsLocked => _era == null && !_readyOnly;
}

/// One shelf's content after filtering.
class ShelfContent {
  const ShelfContent(this.shelf, this.entries, this.locked);
  final ProgrammeShelf shelf;
  final List<GameCatalogEntry> entries;
  final int locked;
}

/// The shelves [filter] lets through for [catalog].
List<ShelfContent> programmeShelves(List<GameCatalogEntry> catalog, ProgrammeFilter filter) {
  final out = <ShelfContent>[];
  for (final s in ProgrammeShelf.values) {
    if (filter.shelf != null && filter.shelf != s) continue;
    final entries = [
      for (final e in catalog)
        if (shelfOf(e) == s && filter.accepts(e)) e,
    ];
    final locked = _announces(s) && filter.showsLocked ? math.max(0, 3 - entries.length) : 0;
    if (entries.isEmpty && locked == 0) continue;
    out.add(ShelfContent(s, entries, locked));
  }
  return out;
}

/// Filter chips and poster shelves.
class Programme extends StatelessWidget {
  const Programme({
    super.key,
    required this.catalog,
    required this.filter,
    required this.records,
    required this.onPlay,
    required this.onLocked,
  });

  final List<GameCatalogEntry> catalog;
  final ProgrammeFilter filter;
  final CinemaRecords records;
  final void Function(GameCatalogEntry entry, {Offset? origin}) onPlay;
  final VoidCallback onLocked;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ListenableBuilder(
      listenable: filter,
      builder: (context, _) {
        final shelves = programmeShelves(catalog, filter);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChipRow(
              children: [
                TicketChip(label: l10n.cinemaHallAllEras, selected: filter.era == null, onTap: () => filter.era = null),
                for (final era in Era.values)
                  TicketChip(
                    label: era.label(l10n),
                    selected: filter.era == era,
                    swatch: EraSkins.of(era).palette.accent,
                    onTap: () => filter.era = filter.era == era ? null : era,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _ChipRow(
              children: [
                TicketChip(
                  label: l10n.cinemaHallAllKinds,
                  selected: filter.shelf == null,
                  onTap: () => filter.shelf = null,
                ),
                for (final s in ProgrammeShelf.values)
                  TicketChip(
                    label: shelfLabel(l10n, s),
                    selected: filter.shelf == s,
                    onTap: () => filter.shelf = filter.shelf == s ? null : s,
                  ),
                TicketChip(
                  label: l10n.cinemaHallReadyOnly,
                  selected: filter.readyOnly,
                  icon: Icons.play_circle_outline_rounded,
                  onTap: () => filter.readyOnly = !filter.readyOnly,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (shelves.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.cinemaHallNothingMatches, textAlign: TextAlign.center, style: Lobby.text(14)),
              ),
            for (final s in shelves) _Shelf(content: s, records: records, onPlay: onPlay, onLocked: onLocked),
          ],
        );
      },
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  // A handful of chips: built eagerly (a lazy list would drop off-screen
  // chips from semantics and tests).
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          SizedBox(height: 40, child: children[i]),
        ],
      ],
    ),
  );
}

/// A filter chip cut like a ticket stub.
class TicketChip extends StatelessWidget {
  const TicketChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.swatch,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? swatch;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? Lobby.ink : Lobby.cream;
    return Semantics(
      selected: selected,
      child: SpringPress(
        onTap: onTap,
        sfx: selected ? Sfx.toggleOff : Sfx.toggleOn,
        semanticLabel: label,
        child: CustomPaint(
          painter: TicketPainter(
            fill: selected ? Lobby.gold : Lobby.ink.withValues(alpha: 0.45),
            ink: selected ? Lobby.ink : Lobby.gold.withValues(alpha: 0.7),
            notch: 5,
            perforation: false,
            shadow: selected,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (swatch != null) ...[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(color: ink, width: 1),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (icon != null) ...[Icon(icon, size: 15, color: ink), const SizedBox(width: 4)],
                Text(
                  label,
                  style: Lobby.text(13, color: ink, weight: FontWeight.w600).copyWith(height: 1.1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.content, required this.records, required this.onPlay, required this.onLocked});

  final ShelfContent content;
  final CinemaRecords records;
  final void Function(GameCatalogEntry entry, {Offset? origin}) onPlay;
  final VoidCallback onLocked;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final n = content.entries.length + content.locked;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(width: 4, height: 18, color: Lobby.gold),
                const SizedBox(width: 8),
                Semantics(header: true, child: Text(shelfLabel(l10n, content.shelf), style: Lobby.heading(19))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 232,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: n,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                if (i >= content.entries.length) {
                  return LockedSlot(
                    label: l10n.cinemaHallLockedSlot,
                    seed: i + content.shelf.index,
                    glyph: _glyphOf(content.shelf),
                    onTap: onLocked,
                  );
                }
                final e = content.entries[i];
                final best = records.best(e.id);
                return MiniPoster(
                  entry: e,
                  best: best == null ? null : fmt.formatInt(best),
                  onTap: (o) => onPlay(e, origin: o),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A small poster on a shelf with its title and era under it.
class MiniPoster extends StatelessWidget {
  const MiniPoster({super.key, required this.entry, required this.onTap, this.best});

  final GameCatalogEntry entry;
  final String? best;
  final void Function(Offset origin) onTap;

  static const double width = 116;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final label = [
      l10n.cinemaHallPosterLabel(entry.title(l10n), entry.era.label(l10n)),
      if (!entry.isPlayable) l10n.cinemaComingSoon,
    ].join('، ');
    return SizedBox(
      width: width,
      child: Builder(
        builder: (context) => SpringPress(
          onTap: () {
            final box = context.findRenderObject() as RenderBox?;
            onTap(box == null ? Offset.zero : box.localToGlobal(box.size.center(Offset.zero)));
          },
          sfx: entry.isPlayable ? Sfx.tap : null,
          semanticLabel: label,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: width * 1.5,
                decoration: BoxDecoration(
                  border: Border.all(color: Lobby.gold, width: 2),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: const [BoxShadow(color: Color(0xCC000000), offset: Offset(0, 4), blurRadius: 6)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: PosterPainter(
                        entry: entry,
                        l10n: l10n,
                        best: best,
                        direction: Directionality.of(context),
                        compact: true,
                      ),
                      foregroundPainter: const GlassSheenPainter(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                entry.title(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Lobby.heading(14),
              ),
              Text(
                entry.era.label(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Lobby.text(11, color: Lobby.goldLight.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

LockedGlyph _glyphOf(ProgrammeShelf s) => switch (s) {
  ProgrammeShelf.cards => LockedGlyph.cards,
  ProgrammeShelf.board => LockedGlyph.board,
  ProgrammeShelf.arcade => LockedGlyph.arcade,
  ProgrammeShelf.puzzle => LockedGlyph.puzzle,
  ProgrammeShelf.word => LockedGlyph.word,
  _ => LockedGlyph.star,
};

/// A "coming attraction" slot: a poster case with its curtains drawn.
class LockedSlot extends StatelessWidget {
  const LockedSlot({
    super.key,
    required this.label,
    required this.seed,
    required this.onTap,
    this.glyph = LockedGlyph.star,
  });

  final String label;
  final int seed;
  final LockedGlyph glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: MiniPoster.width,
    child: SpringPress(
      onTap: onTap,
      sfx: null,
      semanticLabel: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: MiniPoster.width * 1.5,
            decoration: BoxDecoration(
              border: Border.all(color: Lobby.goldDark, width: 2),
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [BoxShadow(color: Color(0xCC000000), offset: Offset(0, 4), blurRadius: 6)],
            ),
            child: RepaintBoundary(
              child: CustomPaint(
                painter: LockedSlotPainter(
                  label: label,
                  seed: seed,
                  glyph: glyph,
                  direction: Directionality.of(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Icon(Icons.lock_outline_rounded, size: 16, color: Lobby.cream.withValues(alpha: 0.5)),
        ],
      ),
    ),
  );
}

/// The player's ticket book: shows, happy endings, time watched, favourite.
class TicketBook extends StatelessWidget {
  const TicketBook({super.key, required this.records, required this.catalog});

  final CinemaRecords records;
  final List<GameCatalogEntry> catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final fav = records.favourite;
    GameCatalogEntry? favEntry;
    for (final e in catalog) {
      if (e.id == fav?.gameId) favEntry = e;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: CustomPaint(
        painter: const TicketPainter(fill: Lobby.cream, ink: Lobby.ink, notch: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 14, 30, 18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 22, height: 22, child: CustomPaint(painter: _EmblemPainter())),
                  const SizedBox(width: 8),
                  Text(
                    l10n.cinemaStageAdmitOne,
                    style: Lobby.text(12, color: Lobby.velvet, weight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (records.isEmpty)
                Text(
                  l10n.cinemaHallFirstTicket,
                  textAlign: TextAlign.center,
                  style: Lobby.text(15, color: Lobby.ink),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _Stat(value: fmt.formatInt(records.totalPlays), label: l10n.cinemaHallStatShows),
                    ),
                    Expanded(
                      child: _Stat(value: fmt.formatInt(records.totalWins), label: l10n.cinemaHallStatWins),
                    ),
                    Expanded(
                      child: _Stat(
                        value: fmt.formatDurationWords(l10n, records.totalTime),
                        label: l10n.cinemaHallStatTime,
                      ),
                    ),
                  ],
                ),
                if (favEntry != null) ...[
                  const SizedBox(height: 10),
                  Container(height: 1, color: Lobby.ink.withValues(alpha: 0.2)),
                  const SizedBox(height: 8),
                  Text(l10n.cinemaHallStatFavourite, style: Lobby.text(12, color: Lobby.ink.withValues(alpha: 0.65))),
                  Text(favEntry.title(l10n), style: Lobby.heading(20, color: Lobby.ink)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, style: Lobby.heading(24, color: Lobby.ink)),
      ),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Lobby.text(11.5, color: Lobby.ink.withValues(alpha: 0.7)),
      ),
    ],
  );
}

class _EmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => Ornaments.orbitEmblem(
    canvas,
    size.center(Offset.zero),
    size.width * 0.45,
    ring: Lobby.velvet,
    planet: Lobby.gold,
    ink: Lobby.ink,
    lineWidth: 1,
  );

  @override
  bool shouldRepaint(covariant _EmblemPainter oldDelegate) => false;
}
