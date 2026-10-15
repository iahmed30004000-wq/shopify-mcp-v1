import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/quran/ayah.dart';
import '../../data/quran_providers.dart';
import '../../domain/mushaf_layout.dart';
import '../../domain/quran_meta.dart';
import '../quran_labels.dart';
import 'ayah_spans.dart';
import 'quran_ornaments.dart';

/// Per-ayah state the page paints.
class MushafMarks {
  const MushafMarks({this.playing, this.playingBasmala, this.selected, this.flash, this.bookmarks = const {}});

  final AyahRef? playing;

  /// The sura whose basmala the reciter is reciting (lit instead of its
  /// first ayah, which comes next).
  final int? playingBasmala;
  final AyahRef? selected;

  /// Briefly lit (opened from search / go to).
  final AyahRef? flash;

  /// Bookmark colour (ARGB) by ayah.
  final Map<AyahRef, int?> bookmarks;

  /// The wash behind the text being recited.
  static Color playingColor(MadarTokens t) => t.gold.withValues(alpha: t.isDark ? 0.18 : 0.16);
}

/// One Madani page: its header (sura, juz, hizb), the framed text (sura
/// titles, basmalas and ayat in one justified paragraph per sura) and the
/// page number. The text size fits the page to the screen; [scale] zooms
/// from there (the reader's text-size setting).
class MushafPage extends StatefulWidget {
  const MushafPage({
    super.key,
    required this.page,
    required this.content,
    required this.scale,
    required this.tajweed,
    this.marks = const MushafMarks(),
    this.onAyahTap,
  });

  final int page;
  final QuranContent content;

  /// 1 = fit the page to the screen.
  final double scale;
  final bool tajweed;
  final MushafMarks marks;
  final void Function(AyahRef ayah)? onAyahTap;

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  final Map<int, TapGestureRecognizer> _recognizers = {};

  /// Keeps the page's scroll position when its edges start or stop fading.
  final GlobalKey _scroller = GlobalKey();

  /// Text runs past the frame's top / bottom edge (a zoomed page): that edge
  /// fades softly instead of cutting a line through its letters.
  bool _moreAbove = false;
  bool _moreBelow = false;

  bool _onMetrics(ScrollMetrics m) {
    final above = m.pixels > 0.5;
    final below = m.pixels < m.maxScrollExtent - 0.5;
    if (above != _moreAbove || below != _moreBelow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _moreAbove = above;
            _moreBelow = below;
          });
        }
      });
    }
    return false;
  }

  Widget _softEdges(Widget child) {
    if (!_moreAbove && !_moreBelow) return child;
    const clear = Color(0x00FFFFFF), solid = Color(0xFFFFFFFF);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_moreAbove ? clear : solid, solid, solid, _moreBelow ? clear : solid],
        stops: [0, (18 / rect.height).clamp(0.0, 0.5), (1 - 28 / rect.height).clamp(0.5, 1.0), 1],
      ).createShader(rect),
      child: child,
    );
  }

  TapGestureRecognizer _recognizer(AyahRef ref, int index) =>
      (_recognizers[index] ??= TapGestureRecognizer())..onTap = () => widget.onAyahTap?.call(ref);

  @override
  void didUpdateWidget(MushafPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) _disposeRecognizers();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final meta = widget.content.meta;
    final blocks = MushafLayout.page(meta, widget.page);
    final first = meta.pageStart(widget.page);
    final quarter = meta.quarterPosition(meta.quarterOf(first));
    final text = Theme.of(context).textTheme;
    final surahNames = meta.surahsOnPage(widget.page).map((s) => l.quranSurahName(meta.surah(s)));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.l, 0, Space.l, Space.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.quranJoin(surahNames),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge!.copyWith(color: t.gold),
                ),
              ),
              Text(
                l.quranJuzHizb(fmt.formatInt(quarter.juz), fmt.formatInt(quarter.hizb)),
                style: text.labelMedium!.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.m),
            child: MushafFrame(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: LayoutBuilder(
                builder: (context, box) {
                  final size = MushafFit.fontSize(
                    page: widget.page,
                    blocks: blocks,
                    content: widget.content,
                    width: box.maxWidth,
                    height: box.maxHeight,
                    style: (s) => _quranStyle(t, s),
                    // Measured exactly as drawn: the system text size and
                    // the header's subtitle line.
                    textScaler: MediaQuery.textScalerOf(context),
                    subtitle: Theme.of(context).textTheme.labelMedium,
                  );
                  final fontSize = (size * widget.scale).clamp(12.0, 64.0);
                  return _softEdges(
                    NotificationListener<ScrollMetricsNotification>(
                      onNotification: (n) => _onMetrics(n.metrics),
                      child: NotificationListener<ScrollUpdateNotification>(
                        onNotification: (n) => _onMetrics(n.metrics),
                        child: SingleChildScrollView(
                          key: _scroller,
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: box.maxHeight),
                            child: Column(
                              mainAxisAlignment: blocks.first is SurahHeaderBlock && widget.page <= 2
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [for (final b in blocks) _block(context, b, fontSize)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: Space.xs),
          child: Text(
            fmt.formatInt(widget.page),
            style: MadarTypography.numerals(t, size: 13, color: t.textSecondary),
          ),
        ),
      ],
    );
  }

  static TextStyle _quranStyle(MadarTokens t, double size) =>
      MadarTypography.quran(t, size: size).copyWith(height: MushafFit.lineHeight);

  Widget _block(BuildContext context, PageBlock block, double fontSize) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final scale = MushafFit.ornamentScale(fontSize);
    switch (block) {
      case SurahHeaderBlock(:final surah):
        return Padding(
          padding: EdgeInsets.only(top: 4 * scale, bottom: 2 * scale),
          child: SurahCartouche(
            surah: surah,
            scale: scale,
            subtitle: l.quranJoin([
              surah.makki ? l.quranMakki : l.quranMadani,
              fmt.localizeDigits(l.quranAyatCount(surah.ayahCount)),
            ]),
          ),
        );
      case BasmalaBlock(:final surah):
        final basmala = widget.content.basmala(surah);
        if (basmala == null) return const SizedBox.shrink();
        return BasmalaLine(
          text: basmala.$1,
          marks: basmala.$2,
          fontSize: fontSize,
          tajweed: widget.tajweed,
          highlight: widget.marks.playingBasmala == surah.number ? MushafMarks.playingColor(t) : null,
        );
      case AyatBlock(:final indices, :final surah):
        final base = _quranStyle(t, fontSize);
        final marks = widget.marks;
        return Text.rich(
          TextSpan(
            children: [
              for (final i in indices) ..._ayah(context, i, base, marks, surah),
            ],
          ),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
        );
    }
  }

  List<InlineSpan> _ayah(BuildContext context, int index, TextStyle base, MushafMarks marks, SurahInfo surah) {
    final t = context.tokens;
    final content = widget.content.ayah(index);
    final ref = content.ref;
    Color? highlight;
    if (ref == marks.playing) {
      highlight = MushafMarks.playingColor(t);
    } else if (ref == marks.selected) {
      highlight = t.accent.withValues(alpha: t.isDark ? 0.20 : 0.14);
    } else if (ref == marks.flash) {
      highlight = t.highlight.withValues(alpha: 0.18);
    }
    final bookmark = marks.bookmarks[ref];
    return AyahSpans.ayah(
      content,
      base,
      t,
      paint: AyahPaint(
        tajweed: widget.tajweed,
        highlight: highlight,
        markerColor: marks.bookmarks.containsKey(ref) ? (bookmark == null ? t.accent : Color(bookmark)) : null,
        recognizer: widget.onAyahTap == null ? null : _recognizer(ref, index),
      ),
    );
  }
}

/// Finds the text size at which a page fills its frame (cached per page and
/// frame size): the sizes of the paragraphs are measured, not guessed.
abstract final class MushafFit {
  static const double lineHeight = 2.0;
  static const double minSize = 14;
  static const double maxSize = 30;

  static final Map<(int, int, int, int, bool), double> _cache = {};

  /// Ornaments (titles) grow with the text.
  static double ornamentScale(double fontSize) => (fontSize / 24).clamp(0.72, 1.5);

  /// The text size at which [blocks] fill [width] × [height] when drawn
  /// with [textScaler] (the page's own). Everything is measured as the page
  /// draws it: the display text ([QuranDisplay.glue] keeps pause marks on
  /// their word, which changes where lines break), the basmala, and the
  /// sura header with its [subtitle] line.
  static double fontSize({
    required int page,
    required List<PageBlock> blocks,
    required QuranContent content,
    required double width,
    required double height,
    required TextStyle Function(double size) style,
    TextScaler textScaler = TextScaler.noScaling,
    TextStyle? subtitle,
  }) {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) return 22;
    final key = (page, width.round(), height.round(), textScaler.scale(1000).round(), content.quranCom.isNotEmpty);
    final cached = _cache[key];
    if (cached != null) return cached;
    final subtitleHeight = subtitle == null
        ? textScaler.scale(18)
        : _height('مكية ١', subtitle, width, TextAlign.center, textScaler);
    double measure(double size) {
      var total = 0.0;
      final scale = ornamentScale(size);
      for (final b in blocks) {
        switch (b) {
          case SurahHeaderBlock():
            total += 50 * scale + 6 * scale + subtitleHeight + 4 * scale;
          case BasmalaBlock(:final surah):
            final basmala = content.basmala(surah);
            if (basmala != null) {
              total += _height(
                QuranDisplay.glue(basmala.$1),
                style(size).copyWith(height: 1.9),
                width,
                TextAlign.center,
                textScaler,
              );
            }
          case AyatBlock(:final indices):
            final buffer = StringBuffer();
            for (final i in indices) {
              final a = content.ayah(i);
              buffer.write('${QuranDisplay.glue(a.text)} ${quranAyahMark(a.ref.ayah)} ');
            }
            total += _height(buffer.toString(), style(size), width, TextAlign.justify, textScaler);
        }
      }
      return total;
    }

    var lo = minSize;
    var hi = maxSize;
    if (measure(lo) > height) {
      _remember(key, lo);
      return lo;
    }
    for (var i = 0; i < 7; i++) {
      final mid = (lo + hi) / 2;
      if (measure(mid) <= height) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final result = (lo * 10).floorToDouble() / 10;
    _remember(key, result);
    return result;
  }

  static void _remember((int, int, int, int, bool) key, double v) {
    if (_cache.length > 64) _cache.remove(_cache.keys.first);
    _cache[key] = v;
  }

  static double _height(String text, TextStyle style, double width, TextAlign align, TextScaler textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      textAlign: align,
      textScaler: textScaler,
    )..layout(maxWidth: math.max(1, width));
    final h = painter.height;
    painter.dispose();
    return h;
  }

  /// Forgets measured sizes (fonts changed, tests).
  static void clearCache() => _cache.clear();
}
