import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/gen/app_localizations.dart';
import '../engine/cinema_engine.dart';
import '../games/catalog.dart';
import 'cinema_store.dart';
import 'saved_games/saved_game.dart';
import 'saved_games/saved_game_launcher.dart';
import 'saved_games/saved_games_store.dart';

/// The Madar Cinema hub: the programme (features + shorts) and the user's
/// Saved Games. Skeleton – owner: hall agent (period lobby, animated
/// marquee, procedural posters, best scores).
class CinemaHallScreen extends ConsumerStatefulWidget {
  const CinemaHallScreen({super.key});

  @override
  ConsumerState<CinemaHallScreen> createState() => _CinemaHallScreenState();
}

class _CinemaHallScreenState extends ConsumerState<CinemaHallScreen> {
  static const _lobby = Color(0xFF120D0A);
  static const _marquee = Color(0xFFFFE3A8);

  @override
  void initState() {
    super.initState();
    unawaited(CinemaShaders.preload());
  }

  void _play(GameCatalogEntry entry) {
    if (!entry.isPlayable) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CinemaGameScreen(entry: entry)));
  }

  Future<void> _addGame() async {
    final game = await showDialog<SavedGame>(context: context, builder: (_) => const _AddGameDialog());
    if (game != null) await ref.read(savedGamesStoreProvider).add(game);
  }

  Future<void> _open(SavedGame game) async {
    final ok = await ref.read(savedGameLauncherProvider).open(game);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.of(context).cinemaOpenGameFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final saved = ref.watch(savedGamesProvider);
    return Scaffold(
      backgroundColor: _lobby,
      appBar: AppBar(backgroundColor: _lobby, foregroundColor: _marquee, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text(
            l10n.cinemaTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'ReemKufi', fontSize: 40, color: _marquee),
          ),
          Text(
            l10n.cinemaHallSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: _marquee.withValues(alpha: 0.7)),
          ),
          _Section(l10n.cinemaFeatures),
          for (final e in CinemaCatalog.ofTier(GameTier.feature)) _Poster(entry: e, onTap: () => _play(e)),
          _Section(l10n.cinemaShorts),
          for (final e in CinemaCatalog.ofTier(GameTier.short)) _Poster(entry: e, onTap: () => _play(e)),
          _Section(l10n.cinemaSavedGames),
          Text(l10n.cinemaSavedGamesNote, style: TextStyle(color: _marquee.withValues(alpha: 0.6), fontSize: 13)),
          const SizedBox(height: 8),
          ...switch (saved) {
            AsyncData(:final value) when value.isNotEmpty => [
              for (final g in value)
                Card(
                  color: const Color(0xFF221A15),
                  child: ListTile(
                    title: Text(g.title, style: const TextStyle(color: _marquee)),
                    subtitle: Text(g.url.host, style: TextStyle(color: _marquee.withValues(alpha: 0.6))),
                    onTap: () => _open(g),
                    trailing: IconButton(
                      tooltip: l10n.cinemaRemoveGame,
                      icon: const Icon(Icons.close, color: _marquee),
                      onPressed: () => ref.read(savedGamesStoreProvider).remove(g.id),
                    ),
                  ),
                ),
            ],
            AsyncData() => [Text(l10n.cinemaSavedGamesEmpty, style: const TextStyle(color: _marquee))],
            _ => const <Widget>[],
          },
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addGame,
            icon: const Icon(Icons.add),
            label: Text(l10n.cinemaAddGame),
            style: OutlinedButton.styleFrom(foregroundColor: _marquee, side: const BorderSide(color: _marquee)),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(title, style: const TextStyle(fontFamily: 'ReemKufi', fontSize: 22, color: Color(0xFFFFE3A8))),
  );
}

/// A programme card in the entry's era colours (placeholder poster).
class _Poster extends StatelessWidget {
  const _Poster({required this.entry, required this.onTap});

  final GameCatalogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final skin = EraSkins.of(entry.era);
    final pal = skin.palette;
    final font = skin.titles.fontFamily;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: pal.paper,
        shape: RoundedRectangleBorder(side: BorderSide(color: pal.ink, width: 3)),
        child: InkWell(
          onTap: entry.isPlayable ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.title(l10n),
                        style: TextStyle(fontFamily: font, fontSize: 24, fontWeight: FontWeight.w700, color: pal.ink),
                      ),
                    ),
                    if (!entry.isPlayable)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        color: pal.ink,
                        child: Text(l10n.cinemaComingSoon, style: TextStyle(color: pal.paper, fontSize: 12)),
                      ),
                  ],
                ),
                Text(entry.tagline(l10n), style: TextStyle(color: pal.shadow)),
                const SizedBox(height: 4),
                Text(
                  [entry.era.label(l10n), if (entry.homage != null) entry.homage!(l10n)].join(' · '),
                  style: TextStyle(color: pal.ink.withValues(alpha: 0.7), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddGameDialog extends StatefulWidget {
  const _AddGameDialog();

  @override
  State<_AddGameDialog> createState() => _AddGameDialogState();
}

class _AddGameDialogState extends State<_AddGameDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _save() {
    final uri = parseGameUrl(_url.text);
    if (uri == null) {
      setState(() => _invalid = true);
      return;
    }
    final now = DateTime.now();
    final title = _name.text.trim().isEmpty ? uri.host : _name.text.trim();
    Navigator.of(context).pop(SavedGame(id: 'g${now.microsecondsSinceEpoch}', title: title, url: uri, addedAt: now));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.cinemaAddGame),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, decoration: InputDecoration(labelText: l10n.cinemaGameName)),
          TextField(
            key: const ValueKey('cinema.url'),
            controller: _url,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: l10n.cinemaGameUrl, errorText: _invalid ? l10n.cinemaInvalidUrl : null),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cinemaCancel)),
        FilledButton(onPressed: _save, child: Text(l10n.cinemaSave)),
      ],
    );
  }
}

/// Plays one catalog entry full screen (immersive) with persistent scores.
class CinemaGameScreen extends ConsumerStatefulWidget {
  const CinemaGameScreen({super.key, required this.entry});

  final GameCatalogEntry entry;

  @override
  ConsumerState<CinemaGameScreen> createState() => _CinemaGameScreenState();
}

class _CinemaGameScreenState extends ConsumerState<CinemaGameScreen> {
  @override
  void initState() {
    super.initState();
    _systemUi(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _systemUi(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  static void _systemUi(SystemUiMode mode) {
    try {
      unawaited(SystemChrome.setEnabledSystemUIMode(mode).catchError((Object _) {}));
    } catch (_) {}
  }

  ScoreSink? _sink() {
    try {
      return ref.read(hallScoreSinkProvider);
    } catch (_) {
      return null; // no database (previews/tests): the view's default sink
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: CinemaGameView(builder: widget.entry.builder!, scoreSink: _sink()),
  );
}
