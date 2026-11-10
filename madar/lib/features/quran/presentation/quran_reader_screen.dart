import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/quran/quran_audio.dart';
import '../../../core/sound/sound_api.dart';
import '../data/quran_com_client.dart';
import '../data/quran_providers.dart';
import '../data/quran_services.dart';
import '../domain/quran_meta.dart';
import '../domain/quran_prefs.dart';
import '../domain/reading_tracker.dart';
import '../domain/tajweed.dart';
import 'quran_home_screen.dart';
import 'quran_labels.dart';
import 'quran_sheets.dart';
import 'widgets/mushaf_page.dart';
import 'widgets/quran_toast.dart';
import 'widgets/verse_list.dart';

/// The Quran reader: the Madani mushaf's 604 pages (swiped right-to-left)
/// or one sura as ayah cards with an optional translation. Opens at
/// [start] (lit briefly), at [page], or where the reader last stopped.
///
/// Tap an ayah for its actions; the ayah being recited is lit and followed
/// (page turn / scroll). Real reading time is logged as a QuranSessions row
/// + a `quran.read` activity when the reader closes or the app goes to the
/// background; the last position is kept for "continue reading".
class QuranReaderScreen extends ConsumerStatefulWidget {
  const QuranReaderScreen({super.key, this.start, this.page, this.mode});

  final AyahRef? start;

  /// A mushaf page 1–604 (ignored when [start] is given).
  final int? page;

  /// Overrides the saved layout for this visit.
  final QuranReaderMode? mode;

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> with WidgetsBindingObserver {
  bool _ready = false;
  late QuranReaderMode _mode;
  late int _page;
  late int _surah;
  late int _anchor;
  late AyahRef _focus;
  AyahRef? _selected;
  AyahRef? _flash;
  PageController? _pages;
  final GlobalKey<SurahVerseListState> _list = GlobalKey();
  final ReadingTracker _tracker = ReadingTracker();
  Timer? _saveTimer;
  Timer? _flashTimer;
  _Download _translationDownload = _Download.idle;

  // Captured once so dispose can record without touching ref.
  late QuranMeta _meta;
  late QuranSessionRecorder _recorder;
  late QuranPrefsStore _prefsStore;
  late DateTime Function() _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recorder = ref.read(quranSessionRecorderProvider);
    _prefsStore = ref.read(quranPrefsStoreProvider);
    _clock = ref.read(quranClockProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _flashTimer?.cancel();
    if (_ready) {
      unawaited(_saveLastRead());
      _flush();
    }
    _pages?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready) return;
    final now = _clock();
    switch (state) {
      case AppLifecycleState.resumed:
        _tracker.resume(now);
      case AppLifecycleState.inactive || AppLifecycleState.hidden:
        break;
      case AppLifecycleState.paused || AppLifecycleState.detached:
        _tracker.pause(now);
        _flush();
        unawaited(_saveLastRead());
    }
  }

  void _flush() {
    final summary = _tracker.flush(_clock());
    if (summary != null) unawaited(_recorder.record(summary, _meta));
  }

  void _init(QuranMeta meta, QuranReaderPrefs prefs, QuranLastRead? last) {
    _meta = meta;
    final start = widget.start != null && meta.isValid(widget.start!)
        ? widget.start!
        : widget.page != null
        ? meta.pageStart(widget.page!.clamp(1, QuranMeta.pageCount))
        : last?.ref ?? const AyahRef(1, 1);
    _mode = widget.mode ?? prefs.mode;
    _page = widget.page != null && widget.start == null ? widget.page!.clamp(1, QuranMeta.pageCount) : meta.pageOf(start);
    _surah = start.surah;
    _anchor = start.ayah;
    _focus = start;
    _pages = PageController(initialPage: _page - 1);
    if (widget.start != null) _lightUp(widget.start!);
    if (_mode == QuranReaderMode.mushaf) _tracker.show(_pageIndices(_page), _clock());
    _ready = true;
  }

  List<int> _pageIndices(int page) => [for (final r in _meta.ayatOnPage(page)) _meta.indexOf(r)];

  void _lightUp(AyahRef ayah) {
    _flash = ayah;
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 900), () => unawaited(_saveLastRead()));
  }

  Future<void> _saveLastRead() => _prefsStore.saveLastRead(
    QuranLastRead(ref: _focus, page: _meta.pageOf(_focus), at: _clock(), mode: _mode),
  );

  // ------------------------------------------------------------- events

  void _onPageChanged(int i) {
    final page = i + 1;
    if (page == _page) return;
    Fx.fire(Sfx.swipe);
    setState(() {
      _page = page;
      _focus = _meta.pageStart(page);
      _selected = null;
    });
    _tracker.show(_pageIndices(page), _clock());
    _scheduleSave();
  }

  void _onVisible(List<int> indices) {
    if (indices.isEmpty) return;
    _tracker.show(indices, _clock());
    final top = _meta.refAt(indices.first);
    if (top != _focus) {
      setState(() => _focus = top);
      _scheduleSave();
    }
  }

  Future<void> _onAyahTap(AyahRef ayah, QuranContent content) async {
    _tracker.activity(_clock());
    setState(() => _selected = ayah);
    await showAyahActions(context, ref, content.ayah(_meta.indexOf(ayah)));
    if (mounted) setState(() => _selected = null);
  }

  Future<void> _quickBookmark(AyahRef ayah) async {
    _tracker.activity(_clock());
    final existing = ref.read(quranBookmarksByAyahProvider)[ayah];
    if (existing != null) {
      await editBookmark(context, ref, ayah, existing: existing);
      return;
    }
    await ref.read(quranBookmarkServiceProvider).add(ayah);
    Fx.fire(Sfx.complete);
    if (mounted) QuranToast.show(context, L10n.of(context).quranBookmarkSaved, icon: Icons.bookmark_rounded);
  }

  void _play(AyahRef ayah) {
    _tracker.activity(_clock());
    unawaited(ref.read(quranAudioProvider).play(AyahRange(ayah, _meta.surah(ayah.surah).last)));
  }

  void _openSurah(int surah) {
    _tracker.activity(_clock());
    setState(() {
      _surah = surah;
      _anchor = 1;
      _focus = AyahRef(surah, 1);
    });
    _scheduleSave();
  }

  Future<void> _setMode(QuranReaderMode mode) async {
    if (mode == _mode) return;
    _tracker.activity(_clock());
    setState(() {
      _mode = mode;
      if (mode == QuranReaderMode.list) {
        _surah = _focus.surah;
        _anchor = _focus.ayah;
      } else {
        _page = _meta.pageOf(_focus);
        _pages?.dispose();
        _pages = PageController(initialPage: _page - 1);
        _tracker.show(_pageIndices(_page), _clock());
      }
    });
    await _prefsStore.updatePrefs((p) => p.copyWith(mode: mode));
  }

  /// Follows the recitation: turns the page / scrolls to the ayah.
  void _follow(QuranPlayback? previous, QuranPlayback next) {
    final current = next.current;
    if (!_ready || current == null || current == previous?.current || !_meta.isValid(current)) return;
    if (_mode == QuranReaderMode.mushaf) {
      final page = _meta.pageOf(current);
      if (page != _page && _pages != null && _pages!.hasClients) {
        final reduced = context.reducedMotion;
        if (reduced) {
          _pages!.jumpToPage(page - 1);
        } else {
          unawaited(_pages!.animateToPage(page - 1, duration: MadarMotion.long, curve: MadarMotion.standard));
        }
      }
    } else if (current.surah != _surah) {
      setState(() {
        _surah = current.surah;
        _anchor = current.ayah;
      });
    } else if (!(_list.currentState?.reveal(current.ayah) ?? false)) {
      setState(() => _anchor = current.ayah);
    }
  }

  Future<void> _downloadTranslation(int surah, int id) async {
    setState(() => _translationDownload = _Download.running);
    var outcome = _Download.idle;
    try {
      await ref.read(quranDownloadsProvider).translation(surah, id);
      Fx.fire(Sfx.complete);
    } on QuranComException catch (e) {
      outcome = e.problem == QuranComProblem.offline ? _Download.failedOffline : _Download.failed;
      Fx.fire(Sfx.error);
    }
    if (mounted) setState(() => _translationDownload = outcome);
  }

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final metaAsync = ref.watch(quranMetaProvider);
    final textAsync = ref.watch(quranTextProvider);
    final prefsAsync = ref.watch(quranReaderPrefsProvider);
    final lastAsync = ref.watch(quranLastReadProvider);
    ref.listen(quranPlaybackProvider, (prev, next) {
      final value = next.value;
      if (value != null) _follow(prev?.value, value);
    });
    final error = metaAsync.hasError || textAsync.hasError;
    final loaded = metaAsync.hasValue && textAsync.hasValue && prefsAsync.hasValue && !lastAsync.isLoading;
    if (!_ready && loaded) _init(metaAsync.requireValue, prefsAsync.requireValue, lastAsync.value);
    if (!_ready || error) {
      return MadarScaffold(
        title: l.quranTitle,
        body: Center(
          child: error
              ? AnimatedEmptyState(
                  kind: EmptyStateKind.noData,
                  title: l.quranLoadError,
                  body: '',
                  actionLabel: l.quranRetry,
                  onAction: () {
                    ref.invalidate(quranMetaProvider);
                    ref.invalidate(quranTextProvider);
                  },
                )
              : const OrbitLoader(size: 40),
        ),
      );
    }
    final prefs = prefsAsync.requireValue;
    final tajweedIndex = prefs.tajweed ? ref.watch(quranTajweedProvider).value : null;
    final surahsInView = _mode == QuranReaderMode.mushaf ? _meta.surahsOnPage(_page) : [_surah];
    final remote = <AyahRef, TajweedText>{};
    if (prefs.tajweed && prefs.tajweedSource == TajweedSource.quranCom) {
      for (final s in surahsInView) {
        remote.addAll(ref.watch(quranComTajweedProvider(s)).value ?? const {});
      }
    }
    final content = QuranContent(meta: _meta, text: textAsync.requireValue, tajweed: tajweedIndex, quranCom: remote);
    final playback = ref.watch(quranPlaybackProvider).value;
    final bookmarks = ref.watch(quranBookmarksByAyahProvider);
    final sounding = playback != null && (playback.playing || playback.loading);
    final marks = MushafMarks(
      // While the basmala before ayah 1 is recited, the basmala is lit.
      playing: sounding && !playback.basmala ? playback.current : null,
      playingBasmala: sounding && playback.basmala ? playback.current?.surah : null,
      selected: _selected,
      flash: _flash,
      bookmarks: {for (final e in bookmarks.entries) e.key: e.value.color},
    );
    final focusSurah = _meta.surah(_mode == QuranReaderMode.mushaf ? _focus.surah : _surah);
    return MadarScaffold(
      title: l.quranSurahName(focusSurah),
      actions: [
        MadarButton.icon(
          icon: _mode == QuranReaderMode.mushaf ? Icons.view_agenda_outlined : Icons.menu_book_rounded,
          semanticLabel: _mode == QuranReaderMode.mushaf ? l.quranShowList : l.quranShowMushaf,
          variant: MadarButtonVariant.ghost,
          onPressed: () => unawaited(
            _setMode(_mode == QuranReaderMode.mushaf ? QuranReaderMode.list : QuranReaderMode.mushaf),
          ),
        ),
        MadarButton.icon(
          icon: Icons.tune_rounded,
          semanticLabel: l.quranSettingsTitle,
          variant: MadarButtonVariant.ghost,
          onPressed: () => unawaited(showReaderSettings(context, surah: focusSurah.number)),
        ),
      ],
      body: Listener(
        onPointerDown: (_) => _tracker.activity(_clock()),
        child: AnimatedSwitcher(
          duration: context.reducedMotion ? MadarMotion.reduced : MadarMotion.medium,
          child: _mode == QuranReaderMode.mushaf
              ? _mushaf(content, prefs, marks)
              : _verses(content, prefs, marks),
        ),
      ),
    );
  }

  Widget _mushaf(QuranContent content, QuranReaderPrefs prefs, MushafMarks marks) {
    return Directionality(
      // The mushaf turns right-to-left whatever the interface language.
      textDirection: TextDirection.rtl,
      child: PageView.builder(
        key: const ValueKey('quran-mushaf'),
        controller: _pages,
        itemCount: QuranMeta.pageCount,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, i) => Directionality(
          textDirection: Directionality.of(this.context),
          child: Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: MushafPage(
              page: i + 1,
              content: content,
              scale: prefs.fontSize / QuranReaderPrefs.defaultFontSize,
              tajweed: prefs.tajweed,
              marks: marks,
              onAyahTap: (a) => unawaited(_onAyahTap(a, content)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _verses(QuranContent content, QuranReaderPrefs prefs, MushafMarks marks) {
    final translation = prefs.translation
        ? ref.watch(quranTranslationProvider((_surah, prefs.translationId)))
        : const AsyncData<QuranTranslation?>(null);
    final missing = prefs.translation && translation.hasValue && translation.value == null;
    return Column(
      key: const ValueKey('quran-verses'),
      children: [
        if (missing)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.s),
            child: _TranslationBanner(
              state: _translationDownload,
              onDownload: () => unawaited(_downloadTranslation(_surah, prefs.translationId)),
            ),
          ),
        Expanded(
          child: SurahVerseList(
            key: _list,
            surah: _meta.surah(_surah),
            anchor: _anchor,
            content: content,
            fontSize: prefs.fontSize,
            tajweed: prefs.tajweed,
            translation: translation.value,
            marks: marks,
            onAyahTap: (a) => unawaited(_onAyahTap(a, content)),
            onPlay: _play,
            onBookmark: (a) => unawaited(_quickBookmark(a)),
            onVisible: _onVisible,
            onOpenSurah: _openSurah,
            onActivity: () => _tracker.activity(_clock()),
          ),
        ),
      ],
    );
  }
}

enum _Download { idle, running, failedOffline, failed }

class _TranslationBanner extends StatelessWidget {
  const _TranslationBanner({required this.state, required this.onDownload});

  final _Download state;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final (message, color) = switch (state) {
      _Download.failedOffline => (l.quranDownloadOffline, t.warning),
      _Download.failed => (l.quranDownloadFailed, t.danger),
      _ => (l.quranTranslationMissing, t.textSecondary),
    };
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.translate_rounded, size: 18, color: t.accent),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: text.bodyMedium!.copyWith(color: color)),
                    Text(l.quranDownloadNote, style: text.labelSmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: MadarButton(
              label: l.quranDownloadTranslation,
              icon: Icons.download_rounded,
              size: MadarButtonSize.small,
              variant: MadarButtonVariant.secondary,
              loading: state == _Download.running,
              onPressed: state == _Download.running ? null : onDownload,
            ),
          ),
        ],
      ),
    );
  }
}

/// Default navigation into the reader (the app router may route instead).
abstract final class QuranNavigation {
  static Route<void> route(Widget page, String name) => PageRouteBuilder<void>(
    settings: RouteSettings(name: name),
    pageBuilder: (_, _, _) => page,
    transitionDuration: MadarMotion.medium,
    reverseTransitionDuration: MadarMotion.medium,
    transitionsBuilder: MadarTransitions.sharedAxisHorizontalTransitions,
  );

  /// Opens the Quran home (index, search, bookmarks, continue reading).
  static Future<void> openHome(BuildContext context) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(route(const QuranHomeScreen(), 'quran'));
  }

  /// Opens the reader at [ayah] (lit briefly), at [page], or where the
  /// reader last stopped.
  static Future<void> openReader(BuildContext context, {AyahRef? ayah, int? page, QuranReaderMode? mode}) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(
      route(QuranReaderScreen(start: ayah, page: page, mode: mode), 'quran/reader'),
    );
  }
}

/// Opens the reader (the host's router, or [QuranNavigation.openReader]).
typedef QuranOpenReader = void Function(BuildContext context, {AyahRef? ayah, int? page});

/// Formats "page N of 604".
String quranPageCounter(L10n l, MadarFormatter fmt, int page) =>
    l.quranPageCounter(fmt.formatInt(page), fmt.formatInt(QuranMeta.pageCount));
