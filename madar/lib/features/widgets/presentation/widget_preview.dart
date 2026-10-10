import 'package:flutter/material.dart';

import '../../../core/i18n/formatters.dart';
import '../domain/widget_build.dart';
import '../domain/widget_kind.dart';
import '../domain/widget_snapshot.dart';
import '../render/mini_astrolabe.dart';

/// The colours of the Android widgets (res/values*/widget_colors.xml).
@immutable
class WidgetPreviewColors {
  const WidgetPreviewColors._({
    required this.surface,
    required this.stroke,
    required this.primary,
    required this.secondary,
    required this.muted,
    required this.accent,
    required this.warn,
    required this.track,
    required this.fill,
  });

  static const light = WidgetPreviewColors._(
    surface: Color(0xF5F7F3EA),
    stroke: Color(0x55B8862F),
    primary: Color(0xFF1D1A24),
    secondary: Color(0xFF474353),
    muted: Color(0xFF686270),
    accent: Color(0xFF77540E),
    warn: Color(0xFFAB2828),
    track: Color(0x29483A1C),
    fill: Color(0xFF9C7127),
  );

  static const dark = WidgetPreviewColors._(
    surface: Color(0xF20D1430),
    stroke: Color(0x40E8C77A),
    primary: Color(0xFFF4EEDD),
    secondary: Color(0xFFC7C3D6),
    muted: Color(0xFF8E8FA4),
    accent: Color(0xFFE8C77A),
    warn: Color(0xFFFF9393),
    track: Color(0x33E8C77A),
    fill: Color(0xFFE8C77A),
  );

  final Color surface, stroke, primary, secondary, muted, accent, warn, track, fill;
}

/// A widget as the Android provider draws it (`MadarWidgetRenderer`), in
/// Flutter: the settings show it, and screenshot tests render it. Same size
/// classes, same page choice, same fields – so what the settings promise
/// ("counts only") is what the home screen shows.
class MadarWidgetPreview extends StatelessWidget {
  const MadarWidgetPreview({
    super.key,
    required this.source,
    required this.now,
    this.size = const Size(250, 120),
    this.dark = true,
  });

  final WidgetBuild source;

  /// The moment shown (picks the page; the countdown is frozen at it).
  final DateTime now;

  /// Logical size in dp (2×2 ≈ 120 × 120, 4×2 ≈ 250 × 120, 4×3 ≈ 250 × 200).
  final Size size;
  final bool dark;

  bool get _small => size.width < 180;

  /// Rows a list widget of this size shows (MadarWidgetRenderer.rowsFor,
  /// LIST_WIDE_DP / LIST_TALL_DP).
  int get _rows => size.height < 136 ? 2 : (size.height < 200 ? 3 : 6);

  @override
  Widget build(BuildContext context) {
    final c = dark ? WidgetPreviewColors.dark : WidgetPreviewColors.light;
    final snapshot = source.snapshot;
    final page = snapshot.pageAt(now);
    final Widget body;
    if (page == null) {
      body = _Placeholder(title: snapshot.title, message: snapshot.stale, colors: c);
    } else {
      body = switch (snapshot.kind) {
        MadarWidgetKind.prayer => _small ? _prayerSmall(page, c) : _prayerWide(snapshot, page, c),
        MadarWidgetKind.meds || MadarWidgetKind.tasks =>
          snapshot.private || _small || page.empty != null
              ? _counts(snapshot, page, c)
              : _list(snapshot, page, c, _rows),
        MadarWidgetKind.budget => _budget(snapshot, page, c),
      };
    }
    // The preview is a picture of what Android draws on the home screen, at
    // the widget's own fixed size: it must not follow the phone's text
    // scale, or a large setting would push the drawing out of the frame
    // (the real widget is laid out by Android, not by this code).
    return MediaQuery.withNoTextScaling(
      child: Directionality(
        textDirection: snapshot.rtl ? TextDirection.rtl : TextDirection.ltr,
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: 'PlexArabic',
            color: c.primary,
            fontSize: 13,
            height: 1.25,
            decoration: TextDecoration.none,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: SizedBox.fromSize(
            size: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: c.stroke),
              ),
              child: Padding(padding: const EdgeInsets.all(12), child: body),
            ),
          ),
        ),
      ),
    );
  }

  MiniAstrolabeSpec? _spec(WidgetPage page) => page.image == null ? null : source.images[page.image];

  Widget _astro(WidgetPage page, double side) {
    final spec = _spec(page);
    if (spec == null) return SizedBox.square(dimension: side);
    return SizedBox.square(
      dimension: side,
      child: CustomPaint(painter: _AstroPainter(spec, dark: dark)),
    );
  }

  String _countdown(WidgetPage page) {
    final to = page.countdownTo;
    if (to == null) return '';
    var d = to.difference(now);
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final clock = h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
    final text = (page.countdownFormat ?? '%s').replaceFirst('%s', clock);
    // Android's Chronometer writes the phone's digits; the preview follows
    // the snapshot's language.
    return source.snapshot.rtl ? Digits.toArabicIndic(text) : text;
  }

  Widget _prayerSmall(WidgetPage page, WidgetPreviewColors c) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _astro(page, 40),
      const SizedBox(height: 2),
      Text(page.headline ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      Text(page.detail ?? '', style: TextStyle(color: c.secondary, fontSize: 12)),
      Text(_countdown(page), style: TextStyle(color: c.accent, fontSize: 11)),
    ],
  );

  Widget _prayerWide(WidgetSnapshot s, WidgetPage page, WidgetPreviewColors c) => Row(
    children: [
      _astro(page, 72),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title, style: TextStyle(color: c.secondary, fontSize: 12)),
            Text(page.headline ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(page.detail ?? '', style: const TextStyle(fontSize: 14)),
            Text(_countdown(page), style: TextStyle(color: c.accent, fontSize: 12)),
            if (page.note != null) Text(page.note!, style: TextStyle(color: c.muted, fontSize: 11)),
          ],
        ),
      ),
    ],
  );

  Widget _counts(WidgetSnapshot s, WidgetPage page, WidgetPreviewColors c) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(s.title, style: TextStyle(color: c.secondary, fontSize: 12)),
      if (page.empty == null) ...[
        if (page.headline != null)
          Text(
            page.headline!,
            style: TextStyle(color: c.accent, fontSize: 28, fontWeight: FontWeight.w700),
          ),
        if (page.detail != null) Text(page.detail!, style: TextStyle(color: c.secondary), maxLines: 2),
      ],
      if (page.note != null) _Dots.orText(page.note!, TextStyle(color: c.accent, fontSize: 12), c.accent),
      if (page.empty != null) Text(page.empty!, maxLines: 3),
    ],
  );

  Widget _list(WidgetSnapshot s, WidgetPage page, WidgetPreviewColors c, int capacity) {
    final total = page.more.isNotEmpty ? page.more.length + 1 : page.rows.length;
    final shown = page.rows.length < capacity ? page.rows.length : capacity;
    final hidden = total - shown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (page.headline != null)
              Text(
                page.headline!,
                style: TextStyle(color: c.accent, fontWeight: FontWeight.w700),
              ),
          ],
        ),
        if (page.detail != null) Text(page.detail!, style: TextStyle(color: c.secondary, fontSize: 12)),
        const SizedBox(height: 4),
        for (final r in page.rows.take(shown))
          SizedBox(
            height: 22,
            child: Row(
              children: [
                Icon(
                  switch (r.state) {
                    WidgetRowState.done => Icons.check_rounded,
                    WidgetRowState.skipped => Icons.remove_rounded,
                    WidgetRowState.open => Icons.radio_button_unchecked_rounded,
                  },
                  size: 14,
                  color: r.state == WidgetRowState.open ? c.accent : c.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.text,
                    style: TextStyle(
                      color: r.state == WidgetRowState.open ? c.primary : c.muted,
                      decoration:
                          r.state == WidgetRowState.skipped ||
                              (r.state == WidgetRowState.done && s.kind == MadarWidgetKind.tasks)
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                if (r.time != null) Text(r.time!, style: TextStyle(color: c.secondary, fontSize: 12)),
              ],
            ),
          ),
        if (hidden > 0 && hidden - 1 < page.more.length)
          Text(page.more[hidden - 1], style: TextStyle(color: c.muted, fontSize: 11)),
      ],
    );
  }

  Widget _budget(WidgetSnapshot s, WidgetPage page, WidgetPreviewColors c) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(s.title, style: TextStyle(color: c.secondary, fontSize: 12)),
      if (page.empty != null)
        Text(page.empty!, maxLines: 3)
      else ...[
        // Android shrinks the amount to fit (autosize 24 → 13 sp).
        SizedBox(
          height: 30,
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              page.headline ?? '',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: page.warn ? c.warn : c.primary),
            ),
          ),
        ),
        if (page.detail != null) Text(page.detail!, style: TextStyle(color: c.secondary)),
        if (page.bar != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: page.bar! / 1000,
                backgroundColor: c.track,
                color: page.warn ? c.warn : c.fill,
              ),
            ),
          ),
        ],
        if (size.height >= 120 && !_small && page.note != null) ...[
          const SizedBox(height: 6),
          Text(page.note!, style: TextStyle(color: c.muted, fontSize: 11)),
        ],
      ],
    ],
  );
}

/// The counts-only state dots ("● ● ○") drawn as dots, or [text] as is.
class _Dots extends StatelessWidget {
  const _Dots(this.done, this.total, this.color);

  final int done, total;
  final Color color;

  static Widget orText(String text, TextStyle style, Color color) {
    final marks = text.replaceAll(' ', '');
    if (marks.isEmpty || !RegExp(r'^[●○]+$').hasMatch(marks)) return Text(text, style: style);
    return _Dots('●'.allMatches(marks).length, marks.length, color);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsetsDirectional.only(end: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? color : null,
              border: Border.all(color: color, width: 1.3),
            ),
          ),
      ],
    ),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title, required this.message, required this.colors});

  final String title;
  final String message;
  final WidgetPreviewColors colors;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.brightness_7_outlined, color: colors.accent, size: 28),
      const SizedBox(height: 6),
      Text(
        title,
        style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
      Text(
        message,
        style: TextStyle(color: colors.secondary),
        maxLines: 2,
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _AstroPainter extends CustomPainter {
  _AstroPainter(this.spec, {required this.dark});

  final MiniAstrolabeSpec spec;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) =>
      MiniAstrolabePainter(spec, MiniAstrolabePainter.paletteFor(dark: dark)).paint(canvas, size);

  @override
  bool shouldRepaint(_AstroPainter old) => old.spec != spec || old.dark != dark;
}
