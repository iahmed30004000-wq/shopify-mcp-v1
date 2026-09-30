import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'widget_kind.dart';

/// What one row of a list widget (a dose, a Top 3 item) shows.
enum WidgetRowState {
  /// Waiting (a dose not answered yet, a task not done).
  open('o'),

  /// Taken / done.
  done('d'),

  /// Skipped (doses only).
  skipped('s');

  const WidgetRowState(this.wire);

  final String wire;

  static WidgetRowState fromWire(Object? wire) => switch (wire) {
    'd' => done,
    's' => skipped,
    _ => open,
  };
}

/// One row of a list widget.
@immutable
class WidgetRow {
  const WidgetRow({required this.text, this.time, this.state = WidgetRowState.open, this.link});

  final String text;

  /// Shown at the row's end (a dose's time); null for none.
  final String? time;
  final WidgetRowState state;

  /// App location a tap on the row opens (null: the widget's own link).
  final String? link;

  Map<String, Object?> toJson() => {
    'text': text,
    'time': ?time,
    'st': state.wire,
    'link': ?link,
  };

  factory WidgetRow.fromJson(Map<String, Object?> j) => WidgetRow(
    text: j['text'] as String? ?? '',
    time: j['time'] as String?,
    state: WidgetRowState.fromWire(j['st']),
    link: j['link'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is WidgetRow && other.text == text && other.time == time && other.state == state && other.link == link;

  @override
  int get hashCode => Object.hash(text, time, state, link);

  @override
  String toString() => 'WidgetRow($text, $time, ${state.name})';
}

/// What a widget shows from [from] until the next page's [from] (or the
/// snapshot's [WidgetSnapshot.until]).
///
/// Every field is optional: the Android provider fills the views its
/// layout has for the fields that are present (see `MadarWidgetRenderer`).
@immutable
class WidgetPage {
  const WidgetPage({
    required this.from,
    this.headline,
    this.detail,
    this.note,
    this.countdownTo,
    this.countdownFormat,
    this.image,
    this.rows = const [],
    this.more,
    this.empty,
    this.bar,
    this.warn = false,
    this.link,
  });

  /// When the page starts (null: from the start – the first page).
  final DateTime? from;

  /// The big text (a prayer's name, "2/5", an amount, "62%").
  final String? headline;

  /// The line under it (a prayer's time, the next dose, "of 500 JOD").
  final String? detail;

  /// The small line at the bottom (the Hijri date, "12 days left").
  final String? note;

  /// A countdown Android ticks by itself (a `Chronometer`) to this instant.
  final DateTime? countdownTo;

  /// The countdown's text with one `%s` for the ticking time ("in %s").
  final String? countdownFormat;

  /// Key of the page's image (light and dark PNGs published with it).
  final String? image;
  final List<WidgetRow> rows;

  /// "+2 more doses" under a list cut short.
  final String? more;

  /// Shown instead of the rows when there are none.
  final String? empty;

  /// A progress bar, 0…1000 (the budget left).
  final int? bar;

  /// Draw the bar / headline in the warning colour.
  final bool warn;

  /// App location a tap on the widget opens (overrides the snapshot's).
  final String? link;

  Map<String, Object?> toJson() => {
    if (from case final f?) 'from': f.millisecondsSinceEpoch,
    'big': ?headline,
    'sub': ?detail,
    'note': ?note,
    if (countdownTo case final c?) 'cd': c.millisecondsSinceEpoch,
    'cdFmt': ?countdownFormat,
    'img': ?image,
    if (rows.isNotEmpty) 'rows': [for (final r in rows) r.toJson()],
    'more': ?more,
    'empty': ?empty,
    'bar': ?bar,
    if (warn) 'warn': true,
    'link': ?link,
  };

  factory WidgetPage.fromJson(Map<String, Object?> j) {
    DateTime? at(Object? ms) => ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
    return WidgetPage(
      from: at(j['from']),
      headline: j['big'] as String?,
      detail: j['sub'] as String?,
      note: j['note'] as String?,
      countdownTo: at(j['cd']),
      countdownFormat: j['cdFmt'] as String?,
      image: j['img'] as String?,
      rows: [
        for (final r in (j['rows'] as List?) ?? const [])
          if (r is Map) WidgetRow.fromJson(r.cast<String, Object?>()),
      ],
      more: j['more'] as String?,
      empty: j['empty'] as String?,
      bar: (j['bar'] as num?)?.toInt(),
      warn: j['warn'] == true,
      link: j['link'] as String?,
    );
  }

  @override
  String toString() => 'WidgetPage(from: $from, $headline | $detail | $note, rows: ${rows.length})';
}

/// Everything one home-screen widget shows until [until], as the Android
/// provider reads it (`files/…/widgets/<kind>.bin`, encrypted there).
///
/// A snapshot is a *timeline*: [pages] start at their `from` instants
/// (prayer times, midnight, the end of a budget period), so the widget moves
/// on at those moments without the app – the provider shows the last page
/// that has started and arms an alarm for the next one. After [until] it
/// shows [stale] ("Open Madar to refresh").
///
/// Nothing volatile (no "generated at") goes into the JSON: equal content
/// encodes equally, so the bridge writes only what changed.
@immutable
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.kind,
    required this.languageCode,
    required this.private,
    required this.title,
    required this.until,
    required this.stale,
    required this.pages,
    this.link,
  });

  static const int version = 1;

  final MadarWidgetKind kind;
  final String languageCode;

  /// Details hidden (counts only): nothing personal is in the snapshot.
  final bool private;
  final String title;

  /// The data runs out here.
  final DateTime until;

  /// Shown after [until].
  final String stale;

  /// In time order; the first page's `from` is null (from the start).
  final List<WidgetPage> pages;

  /// App location a tap on the widget opens.
  final String? link;

  bool get rtl => languageCode == 'ar';

  /// The page shown at [now] (what the Android provider picks), or null
  /// after [until].
  WidgetPage? pageAt(DateTime now) {
    if (!now.isBefore(until) || pages.isEmpty) return null;
    var current = pages.first;
    for (final p in pages) {
      final from = p.from;
      if (from == null || !from.isAfter(now)) current = p;
    }
    return current;
  }

  /// When the widget has to change next after [now] (the next page, else
  /// [until]).
  DateTime nextChangeAfter(DateTime now) {
    for (final p in pages) {
      final from = p.from;
      if (from != null && from.isAfter(now)) return from;
    }
    return until;
  }

  /// Image keys the pages use.
  Set<String> get imageKeys => {
    for (final p in pages)
      if (p.image case final i?) i,
  };

  Map<String, Object?> toJson() => {
    'v': version,
    'kind': kind.wire,
    'lang': languageCode,
    'rtl': rtl,
    'private': private,
    'title': title,
    'until': until.millisecondsSinceEpoch,
    'stale': stale,
    'link': ?link,
    'pages': [for (final p in pages) p.toJson()],
  };

  String encode() => jsonEncode(toJson());

  static WidgetSnapshot? decode(String json) {
    try {
      final j = (jsonDecode(json) as Map).cast<String, Object?>();
      final kind = MadarWidgetKind.fromWire(j['kind']);
      if (kind == null || j['v'] != version) return null;
      return WidgetSnapshot(
        kind: kind,
        languageCode: j['lang'] as String? ?? 'ar',
        private: j['private'] == true,
        title: j['title'] as String? ?? '',
        until: DateTime.fromMillisecondsSinceEpoch((j['until'] as num).toInt()),
        stale: j['stale'] as String? ?? '',
        link: j['link'] as String?,
        pages: [
          for (final p in (j['pages'] as List?) ?? const [])
            if (p is Map) WidgetPage.fromJson(p.cast<String, Object?>()),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'WidgetSnapshot(${kind.wire}, $languageCode, private: $private, ${pages.length} pages)';
}
