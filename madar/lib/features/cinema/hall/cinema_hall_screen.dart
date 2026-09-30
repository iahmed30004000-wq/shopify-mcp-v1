import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion.dart' show MotionScope;
import '../../../core/motion/spring_press.dart';
import '../../../core/sound/sound_api.dart';
import '../../saved_games/saved_games.dart' show SavedGamesScreen, SavedGamesShelf, savedGamesLegacyImportProvider;
import '../engine/cinema_engine.dart';
import '../games/catalog.dart';
import 'cinema_game_screen.dart';
import 'cinema_records.dart';
import 'lobby/lobby_art.dart';
import 'lobby/programme.dart';
import 'posters/poster_painter.dart';

/// The Madar Cinema hub: a grand movie-palace lobby.
///
/// * The marquee: a deco sign ringed with chasing bulbs, searchlights
///   sweeping the night, a letterboard welcome.
/// * **Now Showing**: the Tier 1 features as lit poster cases in a carousel
///   (procedural one-sheets in each film's era, starring its cast), with the
///   centred film's billing, best score and a ticket to play – or a
///   "coming soon" plate.
/// * **The full programme**: era and kind filters (ticket-stub chips) over
///   shelves of posters – features, card, board, arcade, puzzle and word
///   shorts, backstage – with locked "coming attraction" slots.
/// * **Ticket book**: plays, happy endings, time watched, favourite show
///   (the hall's records, [cinemaRecordsProvider]).
/// * **Saved Games**: the web games shelf (`SavedGamesShelf`, built by the
///   Saved Games feature) – games play from their original links.
///
/// One animation controller drives the marquee (stopped under reduced
/// motion and whenever tickers are muted, e.g. when a game covers the hall).
class CinemaHallScreen extends ConsumerStatefulWidget {
  const CinemaHallScreen({super.key, this.catalog, this.showSavedGames = true});

  /// Overrides the programme (tests, previews).
  final List<GameCatalogEntry>? catalog;

  /// The Saved Games shelf slot (tests may hide it).
  final bool showSavedGames;

  @override
  ConsumerState<CinemaHallScreen> createState() => _CinemaHallScreenState();
}

class _CinemaHallScreenState extends ConsumerState<CinemaHallScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _marquee = AnimationController(vsync: this, duration: const Duration(seconds: 60));
  late final MarqueeSignPainter _sign = MarqueeSignPainter(
    t: () => _reduced ? 0 : _marquee.value * 60,
    signRect: _signRect,
    repaint: _marquee,
  );
  bool _reduced = false;
  final ProgrammeFilter _filter = ProgrammeFilter();

  List<GameCatalogEntry> get _catalog => widget.catalog ?? CinemaCatalog.all;

  @override
  void initState() {
    super.initState();
    unawaited(CinemaShaders.preload());
    // Move the hall's first Saved Games list (`cinema.savedGames`) into the
    // Saved Games store, once.
    try {
      ref.read(savedGamesLegacyImportProvider);
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MotionScope.reducedOf(context);
    if (_reduced) {
      _marquee.stop();
    } else if (!_marquee.isAnimating) {
      unawaited(_marquee.repeat());
    }
  }

  @override
  void dispose() {
    _marquee.dispose();
    _sign.dispose();
    super.dispose();
  }

  Rect _signRect(Size size) {
    final w = (size.width - 40).clamp(240.0, 380.0);
    return Rect.fromLTWH((size.width - w) / 2, size.height - 190, w, 124);
  }

  void _play(GameCatalogEntry entry, {Offset? origin}) {
    if (!entry.isPlayable) {
      _locked();
      return;
    }
    unawaited(
      Navigator.of(context)
          .push(CinemaGameScreen.route(entry.id, entry: widget.catalog == null ? null : entry, origin: origin)),
    );
  }

  void _locked() {
    final l10n = L10n.of(context);
    Fx.fire(Sfx.error, haptic: Haptic.warning);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Lobby.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Lobby.gold),
          ),
          content: Text(l10n.cinemaHallLockedHint, style: Lobby.text(14)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final pad = MediaQuery.paddingOf(context);
    final records = ref.watch(cinemaRecordsProvider).value ?? CinemaRecords.empty;
    final features = [
      for (final e in _catalog)
        if (e.tier == GameTier.feature) e,
    ];
    return Scaffold(
      backgroundColor: Lobby.wallDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: CustomPaint(painter: LobbyWallpaperPainter())),
          ),
          ListView(
            padding: EdgeInsets.only(bottom: pad.bottom + 32),
            children: [
              _Marquee(
                sign: _sign,
                top: pad.top,
                signRect: _signRect,
                l10n: l10n,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              if (features.isNotEmpty) ...[
                _SectionTitle(title: l10n.cinemaHallNowShowing, lit: true, t: _marquee),
                NowShowing(entries: features, records: records, onPlay: _play),
              ],
              const SizedBox(height: 28),
              _SectionTitle(title: l10n.cinemaHallProgramme, subtitle: l10n.cinemaHallShortsSoon),
              Programme(catalog: _catalog, filter: _filter, records: records, onPlay: _play, onLocked: _locked),
              const SizedBox(height: 28),
              _SectionTitle(title: l10n.cinemaHallTicketBook),
              TicketBook(records: records, catalog: _catalog),
              if (widget.showSavedGames) ...[
                const SizedBox(height: 30),
                const _VelvetRope(),
                const SizedBox(height: 14),
                SavedGamesShelf(onDarkBackdrop: true, onSeeAll: _openSavedGames),
              ],
              const SizedBox(height: 26),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  l10n.cinemaHallFooter,
                  textAlign: TextAlign.center,
                  style: Lobby.text(12, color: Lobby.cream.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openSavedGames() =>
      unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SavedGamesScreen())));
}

class _Marquee extends StatelessWidget {
  const _Marquee({
    required this.sign,
    required this.top,
    required this.signRect,
    required this.l10n,
    required this.onBack,
  });

  final MarqueeSignPainter sign;
  final double top;
  final Rect Function(Size) signRect;
  final L10n l10n;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final height = top + 250;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, height);
          final b = signRect(size);
          final board = Rect.fromCenter(center: Offset(b.center.dx, b.bottom + 34), width: b.width * 0.84, height: 34);
          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(child: CustomPaint(painter: sign)),
              ),
              Positioned.fromRect(
                rect: b.deflate(18),
                child: Semantics(
                  header: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.cinemaTitle,
                          style: Lobby.heading(44, color: Lobby.cream).copyWith(
                            shadows: const [
                              Shadow(color: Lobby.glow, blurRadius: 16),
                              Shadow(color: Lobby.ink, offset: Offset(0, 3)),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        l10n.cinemaHallSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Lobby.text(12.5, color: Lobby.goldLight),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: board,
                child: CustomPaint(
                  painter: const _LetterboardPainter(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.cinemaHallWelcome, style: Lobby.heading(15, color: Lobby.ink)),
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: 10,
                top: top + 8,
                child: _BrassButton(
                  icon: Icons.arrow_back_rounded,
                  label: MaterialLocalizations.of(context).backButtonTooltip,
                  onTap: onBack,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A marquee letterboard: cream board with slotted rails.
class _LetterboardPainter extends CustomPainter {
  const _LetterboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final p = Paint()..color = Lobby.ink;
    canvas.drawRect(r.shift(const Offset(0, 3)), p);
    p.color = Lobby.cream;
    canvas.drawRect(r, p);
    p
      ..color = Lobby.ink.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var y = 5.0; y < size.height; y += 6) {
      canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), p);
    }
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Lobby.goldDark;
    canvas.drawRect(r, p);
  }

  @override
  bool shouldRepaint(covariant _LetterboardPainter oldDelegate) => false;
}

/// A section heading on a deco plaque (lit bulbs for "Now Showing").
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle, this.lit = false, this.t});

  final String title;
  final String? subtitle;
  final bool lit;
  final Animation<double>? t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: _Rule()),
              Flexible(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Semantics(
                      header: true,
                      child: Text(title, style: Lobby.heading(24, color: Lobby.goldLight)),
                    ),
                  ),
                ),
              ),
              const Expanded(child: _Rule(flip: true)),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Lobby.text(13, color: Lobby.cream.withValues(alpha: 0.7)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({this.flip = false});

  final bool flip;

  @override
  Widget build(BuildContext context) => SizedBox(height: 14, child: CustomPaint(painter: _RulePainter(flip)));
}

class _RulePainter extends CustomPainter {
  _RulePainter(this.flip);

  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Lobby.gold
      ..strokeWidth = 1.4;
    final y = size.height / 2;
    canvas
      ..drawLine(Offset(0, y - 2.5), Offset(size.width, y - 2.5), p)
      ..drawLine(Offset(0, y + 2.5), Offset(size.width, y + 2.5), p..strokeWidth = 0.8);
    final x = flip ? 3.0 : size.width - 3;
    canvas.drawCircle(Offset(x, y), 3, p..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _RulePainter old) => old.flip != flip;
}

class _VelvetRope extends StatelessWidget {
  const _VelvetRope();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 34, child: CustomPaint(painter: _VelvetRopePainter()));
}

class _VelvetRopePainter extends CustomPainter {
  const _VelvetRopePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final posts = [size.width * 0.12, size.width * 0.5, size.width * 0.88];
    final rope = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < posts.length - 1; i++) {
      final a = Offset(posts[i], 8), b = Offset(posts[i + 1], 8);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo((a.dx + b.dx) / 2, 30, b.dx, b.dy);
      canvas
        ..drawPath(
          path,
          rope
            ..color = Lobby.ink
            ..strokeWidth = 7,
        )
        ..drawPath(
          path,
          rope
            ..color = Lobby.velvet
            ..strokeWidth = 4.5,
        );
    }
    final p = Paint();
    for (final x in posts) {
      p.color = Lobby.ink;
      canvas.drawCircle(Offset(x, 8), 6.5, p);
      p.color = Lobby.gold;
      canvas.drawCircle(Offset(x, 8), 5, p);
      p.color = Lobby.goldLight;
      canvas.drawCircle(Offset(x - 1.5, 6.5), 1.6, p);
    }
  }

  @override
  bool shouldRepaint(covariant _VelvetRopePainter oldDelegate) => false;
}

/// A round brass button (back, shortcuts).
class _BrassButton extends StatelessWidget {
  const _BrassButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SpringPress(
    onTap: onTap,
    sfx: Sfx.back,
    semanticLabel: label,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Lobby.goldLight, Lobby.gold, Lobby.goldDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Lobby.ink, width: 2),
        boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(0, 3), blurRadius: 4)],
      ),
      child: Icon(icon, color: Lobby.ink, size: 22),
    ),
  );
}

/// The Tier 1 carousel: lit poster cases, the centred one's billing below.
class NowShowing extends StatefulWidget {
  const NowShowing({super.key, required this.entries, required this.records, required this.onPlay});

  final List<GameCatalogEntry> entries;
  final CinemaRecords records;
  final void Function(GameCatalogEntry entry, {Offset? origin}) onPlay;

  @override
  State<NowShowing> createState() => _NowShowingState();
}

class _NowShowingState extends State<NowShowing> {
  final PageController _pages = PageController(viewportFraction: 0.64);
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final caseW = w * 0.64 - 22;
    final posterW = caseW - 20;
    final caseH = posterW * 1.5 + 20;
    final entry = widget.entries[_page.clamp(0, widget.entries.length - 1)];
    final best = widget.records.best(entry.id);
    return Column(
      children: [
        SizedBox(
          height: caseH + 34,
          child: PageView.builder(
            controller: _pages,
            itemCount: widget.entries.length,
            onPageChanged: (i) {
              Fx.fire(Sfx.swipe);
              setState(() => _page = i);
            },
            itemBuilder: (context, i) {
              final e = widget.entries[i];
              final b = widget.records.best(e.id);
              return AnimatedBuilder(
                animation: _pages,
                builder: (context, child) {
                  final page = _pages.hasClients && _pages.position.haveDimensions
                      ? (_pages.page ?? _page.toDouble())
                      : _page.toDouble();
                  final d = (page - i).abs().clamp(0.0, 1.0);
                  return Transform.scale(
                    scale: 1 - 0.13 * d,
                    child: Opacity(opacity: 1 - 0.4 * d, child: child),
                  );
                },
                child: Center(
                  child: _PosterCase(
                    entry: e,
                    best: b == null ? null : fmt.formatInt(b),
                    width: caseW,
                    height: caseH,
                    l10n: l10n,
                    onTap: (origin) {
                      if (i != _page) {
                        unawaited(
                          _pages.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.easeOutCubic,
                          ),
                        );
                      } else {
                        widget.onPlay(e, origin: origin);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
        _SprocketDots(count: widget.entries.length, index: _page),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: _Billing(
            key: ValueKey(entry.id),
            entry: entry,
            best: best == null ? null : fmt.formatInt(best),
            onPlay: () => widget.onPlay(entry),
          ),
        ),
      ],
    );
  }
}

class _PosterCase extends StatelessWidget {
  const _PosterCase({
    required this.entry,
    required this.best,
    required this.width,
    required this.height,
    required this.l10n,
    required this.onTap,
  });

  final GameCatalogEntry entry;
  final String? best;
  final double width;
  final double height;
  final L10n l10n;
  final void Function(Offset origin) onTap;

  @override
  Widget build(BuildContext context) {
    final label = [
      l10n.cinemaHallPosterLabel(entry.title(l10n), entry.era.label(l10n)),
      if (!entry.isPlayable) l10n.cinemaComingSoon,
    ].join('، ');
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTapUp: (d) => onTap(d.globalPosition),
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: PosterCasePainter(),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: PosterPainter(entry: entry, l10n: l10n, best: best, direction: Directionality.of(context)),
                  foregroundPainter: const GlassSheenPainter(),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SprocketDots extends StatelessWidget {
  const _SprocketDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? Lobby.gold : Lobby.cream.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    ),
  );
}

/// The centred feature's billing: title, tagline, homage, era, best, ticket.
class _Billing extends StatelessWidget {
  const _Billing({super.key, required this.entry, required this.best, required this.onPlay});

  final GameCatalogEntry entry;
  final String? best;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final homage = entry.homage?.call(l10n);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Text(entry.title(l10n), textAlign: TextAlign.center, style: Lobby.heading(26)),
          const SizedBox(height: 2),
          Text(
            entry.tagline(l10n),
            textAlign: TextAlign.center,
            style: Lobby.text(14, color: Lobby.cream.withValues(alpha: 0.85)),
          ),
          if (homage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                homage,
                textAlign: TextAlign.center,
                style: Lobby.text(12, color: Lobby.goldLight.withValues(alpha: 0.75)),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(text: entry.era.label(l10n)),
              if (best != null) _Pill(text: l10n.cinemaHallBestBadge(best!), icon: Icons.emoji_events_rounded),
            ],
          ),
          const SizedBox(height: 14),
          TicketButton(
            label: entry.isPlayable ? l10n.cinemaPlay : l10n.cinemaComingSoon,
            icon: entry.isPlayable ? Icons.play_arrow_rounded : Icons.lock_clock_rounded,
            enabled: entry.isPlayable,
            onTap: onPlay,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: Lobby.gold.withValues(alpha: 0.7)),
      borderRadius: BorderRadius.circular(20),
      color: Lobby.ink.withValues(alpha: 0.35),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 14, color: Lobby.gold), const SizedBox(width: 4)],
        Text(text, style: Lobby.text(12, color: Lobby.goldLight)),
      ],
    ),
  );
}

/// A ticket-shaped call to action.
class TicketButton extends StatelessWidget {
  const TicketButton({super.key, required this.label, required this.icon, required this.onTap, this.enabled = true});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fill = enabled ? Lobby.gold : Lobby.cream.withValues(alpha: 0.18);
    final ink = enabled ? Lobby.ink : Lobby.cream.withValues(alpha: 0.75);
    return SpringPress(
      onTap: onTap,
      sfx: enabled ? Sfx.navigate : null,
      semanticLabel: label,
      child: SizedBox(
        width: 220,
        height: 54,
        child: CustomPaint(
          painter: TicketPainter(fill: fill, ink: enabled ? Lobby.ink : Lobby.gold.withValues(alpha: 0.6), notch: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: ink, size: 24),
              const SizedBox(width: 8),
              Text(label, style: Lobby.heading(19, color: ink)),
            ],
          ),
        ),
      ),
    );
  }
}
