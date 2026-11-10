// «جزء عمّ» (design 03): a mushaf-style framed page of one short surah, with
// the CURRENT WORD lit while the recitation plays.
//
// Text: the bundled, verified Tanzil Uthmani text through the Quran feature's
// providers; nothing is typed here. Sound: only recitation the parent already
// downloaded (see data/kids_audio.dart); otherwise a calm «الصوت مش محمّل».
// No network call is made from this screen. Surahs: the sheikh's CONFIG list
// (domain/juz_amma_config.dart); empty => «قريبًا».
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/quran/ayah.dart';
import '../../../quran/data/quran_providers.dart' show quranMetaProvider, quranTextProvider;
import '../../../quran/domain/quran_meta.dart';
import '../../../quran/domain/quran_text.dart';
import '../../core/kids_section.dart' show kidsReligiousUnlockedProvider;
import '../application/faith_providers.dart';
import '../domain/juz_amma_config.dart';
import '../domain/recitation_check.dart' show kidsRecitationCheckerProvider;
import '../domain/word_highlight.dart';
import 'kids_recitation_screen.dart';
import 'widgets/kids_faith_ui.dart';

class JuzAmmaScreen extends ConsumerWidget {
  const JuzAmmaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final open = ref.watch(kidsReligiousUnlockedProvider);
    final surahs = cleanJuzAmmaSurahs(ref.watch(kidsJuzAmmaSurahsProvider));
    final meta = ref.watch(quranMetaProvider).value;
    final text = ref.watch(quranTextProvider).value;
    final ready = open && surahs.isNotEmpty && meta != null && text != null;
    return KidsFaithScaffold(
      title: l.kidsFaithJuzAmmaTitle,
      background: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [KP.sand, KP.paper]),
      ),
      child: ready ? _Reader(surahs: surahs, meta: meta, text: text) : const KidsSoonState(),
    );
  }
}

class _Reader extends ConsumerStatefulWidget {
  const _Reader({required this.surahs, required this.meta, required this.text});

  final List<int> surahs;
  final QuranMeta meta;
  final QuranText text;

  @override
  ConsumerState<_Reader> createState() => _ReaderState();
}

class _ReaderState extends ConsumerState<_Reader> {
  static const Duration _tick = Duration(milliseconds: 100);

  int _surahIndex = 0;
  int _ayah = 1;
  bool _started = false;
  bool _playing = false;
  bool _basmala = false;
  Duration _elapsed = Duration.zero;
  int? _lit;
  Timer? _timer;
  final Map<int, GlobalKey> _ayahKeys = {};

  SurahInfo get _surah => widget.meta.surah(widget.surahs[_surahIndex]);

  List<String> _words(int ayah) => ayahWords(widget.text.ayahText(_surah.firstIndex + ayah - 1));

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onPlayback(AsyncValue<dynamic>? prev, AsyncValue<dynamic> next) {
    final p = next.value;
    if (p == null) return;
    final cur = p.current as AyahRef?;
    final playing = p.playing as bool;
    setState(() {
      if (cur != null && cur.surah == _surah.number) {
        if (cur.ayah != _ayah || p.basmala != _basmala || (!_playing && playing && !_started)) {
          _elapsed = Duration.zero;
        }
        _ayah = cur.ayah;
        _started = true;
      }
      _basmala = p.basmala as bool;
      _playing = playing;
      _lit = _basmala || !_started ? null : _computeLit();
    });
    _syncTimer();
    final key = _ayahKeys[_ayah];
    if (playing && key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.3,
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
      );
    }
  }

  int? _computeLit() {
    final n = _words(_ayah).length;
    return litWordIndex(wordCount: n, elapsed: _elapsed, duration: estimatedAyahDuration(n));
  }

  void _syncTimer() {
    if (_playing && !_basmala) {
      _timer ??= Timer.periodic(_tick, (_) {
        _elapsed += _tick;
        final next = _computeLit();
        if (next != _lit && mounted) setState(() => _lit = next);
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _goSurah(int delta) {
    final n = widget.surahs.length;
    ref.read(kidsAyahAudioProvider).stop();
    _timer?.cancel();
    _timer = null;
    setState(() {
      _surahIndex = (_surahIndex + delta) % n;
      if (_surahIndex < 0) _surahIndex += n;
      _ayah = 1;
      _started = false;
      _playing = false;
      _lit = null;
      _elapsed = Duration.zero;
      _ayahKeys.clear();
    });
  }

  Future<void> _playPause(bool onPhone) async {
    if (!onPhone) return;
    final audio = ref.read(kidsAyahAudioProvider);
    final v = audio.value;
    final mine = v.current != null && v.current!.surah == _surah.number;
    if (mine && v.playing) return audio.pause();
    if (mine && !v.playing) return audio.resume();
    await audio.play(AyahRange(AyahRef(_surah.number, _ayah), _surah.last));
  }

  Future<void> _repeatAyah(bool onPhone) async {
    if (!onPhone) return;
    setState(() => _elapsed = Duration.zero);
    await ref.read(kidsAyahAudioProvider).play(AyahRange.single(AyahRef(_surah.number, _ayah)));
  }

  Future<void> _tryYourself() async {
    final moveOn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => KidsRecitationScreen(
          ayahKey: '${_surah.number}:$_ayah',
          ayahText: widget.text.ayahText(_surah.firstIndex + _ayah - 1),
        ),
      ),
    );
    if (moveOn == true && mounted && _ayah < _surah.ayahCount) setState(() => _ayah++);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(kidsPlaybackProvider, _onPlayback);
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final surah = _surah;
    final onPhone = ref.watch(kidsSurahOnPhoneProvider((surah.number, surah.ayahCount))).value ?? false;
    final reciter = ref.watch(kidsAyahAudioProvider).reciter;
    final canTry = ref.watch(kidsRecitationCheckerProvider) != null;
    final basmala = widget.text.basmalaOf(surah);
    final arabic = fmt.isArabic;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (widget.surahs.length > 1) _starButton(l.kidsFaithNext, Icons.chevron_right_rounded, () => _goSurah(1)),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(color: KP.sun100, borderRadius: BorderRadius.circular(24), border: Border.all(color: KP.sun500, width: 2)),
                  child: Text(
                    arabic ? surah.nameArabic : surah.nameEnglish,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: KP.heading, fontSize: 28, color: KP.sun700),
                  ),
                ),
              ),
              if (widget.surahs.length > 1) _starButton(l.kidsFaithPrevious, Icons.chevron_left_rounded, () => _goSurah(-1)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _MushafFrame(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (basmala != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(basmala, textAlign: TextAlign.center, style: const TextStyle(fontFamily: KP.quran, fontSize: 26, color: KP.ink2)),
                      ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var a = 1; a <= surah.ayahCount; a++) ..._ayahWidgets(a, fmt),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!onPhone)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Semantics(
              liveRegion: true,
              child: DecoratedBox(
                decoration: BoxDecoration(color: KP.retryFill, borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_off_rounded, color: KP.retryText, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${l.kidsFaithAudioNotDownloaded}. ${l.kidsFaithAudioNotDownloadedHint}',
                          style: const TextStyle(fontFamily: KP.body, fontSize: 16, color: KP.retryText),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.kidsFaithReciter(reciter.name(arabic: arabic)), style: const TextStyle(fontFamily: KP.body, fontSize: 16, color: KP.ink2)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: surah.ayahCount == 0 ? 0 : _ayah / surah.ayahCount, minHeight: 12, backgroundColor: KP.sand2, color: KP.sun500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(l.kidsFaithAyahOfTotal(fmt.formatInt(_ayah), fmt.formatInt(surah.ayahCount)), style: const TextStyle(fontFamily: KP.heading, fontSize: 20, color: KP.ink2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (canTry) KidsRoundButton(icon: Icons.mic_rounded, label: l.kidsFaithTryYourself, color: KP.retryFill, iconColor: KP.retryText, onPressed: _tryYourself) else const SizedBox(width: 64),
              KidsRoundButton(
                icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                label: _playing ? l.kidsFaithPause : l.kidsFaithListen,
                color: KP.sun500,
                iconColor: KP.night900,
                onPressed: onPhone ? () => _playPause(onPhone) : null,
              ),
              KidsRoundButton(icon: Icons.replay_rounded, label: l.kidsFaithRepeatAyah, onPressed: onPhone ? () => _repeatAyah(onPhone) : null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _starButton(String label, IconData icon, VoidCallback onTap) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: KhatamBadge(size: 64, color: KP.teal500, child: Icon(icon, color: Colors.white, size: 28)),
    ),
  );

  List<Widget> _ayahWidgets(int a, MadarFormatter fmt) {
    final words = _words(a);
    final key = _ayahKeys.putIfAbsent(a, GlobalKey.new);
    return [
      for (var w = 0; w < words.length; w++)
        _Word(
          key: w == 0 ? key : null,
          text: words[w],
          state: _wordState(a, w),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: KhatamBadge(size: 44, color: KP.sun100, child: Text(fmt.formatInt(a), style: const TextStyle(fontFamily: KP.heading, fontSize: 18, color: KP.sun700))),
      ),
    ];
  }

  _WordState _wordState(int ayah, int word) {
    if (!_started) return _WordState.idle;
    if (ayah < _ayah) return _WordState.read;
    if (ayah > _ayah) return _WordState.idle;
    final lit = _lit;
    if (lit == null) return _WordState.idle;
    if (word == lit) return _WordState.current;
    return word < lit ? _WordState.read : _WordState.idle;
  }
}

enum _WordState { idle, read, current }

class _Word extends StatelessWidget {
  const _Word({super.key, required this.text, required this.state});

  final String text;
  final _WordState state;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      _WordState.current => (KP.sun500, KP.night900),
      _WordState.read => (KP.teal100, KP.teal700),
      _WordState.idle => (Colors.transparent, KP.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontFamily: KP.quran, fontSize: 30, height: 1.9, color: fg)),
    );
  }
}

/// The double gold frame with a khatam in each corner.
class _MushafFrame extends StatelessWidget {
  const _MushafFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: KP.paper, borderRadius: BorderRadius.circular(28), border: Border.all(color: KP.sun500, width: 4), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))]),
          child: Container(margin: const EdgeInsets.all(6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: KP.sun300, width: 2)), child: child),
        ),
      ),
      for (final a in const [AlignmentDirectional.topStart, AlignmentDirectional.topEnd, AlignmentDirectional.bottomStart, AlignmentDirectional.bottomEnd])
        Align(alignment: a, child: const KhatamBadge(size: 24, color: KP.sun500)),
    ],
  );
}
