import 'package:flutter/foundation.dart';

import 'widget_kind.dart';
import 'widget_links.dart';
import 'widget_snapshot.dart';
import 'widget_texts.dart';

/// A dose as the meds widget sees it (mapped from the tracker's
/// `TrackedDose` by the providers – the builder knows nothing of rules,
/// courses or snoozes).
@immutable
class WidgetDose {
  const WidgetDose({required this.name, required this.at, this.dose, this.state = WidgetRowState.open});

  final String name;

  /// "5 mg · With breakfast" (already localised), or null.
  final String? dose;

  /// Its time in the plan (device-local).
  final DateTime at;
  final WidgetRowState state;

  bool get answered => state != WidgetRowState.open;
}

/// The meds widget's snapshot (pure): today's doses from the start, the
/// next day's from midnight (so the list turns over without the app), stale
/// after that.
///
/// Details shown: answered / total, the next dose's time and name, and a
/// row per dose (✓ taken, – skipped, ○ open) that opens today's doses.
/// Counts only: answered / total, how many are left and the state dots – no
/// names, no times.
abstract final class MedsWidgetBuilder {
  /// Rows written into a page (a 4×4 widget shows about six).
  static const int maxRows = 8;

  static WidgetSnapshot build({
    required DateTime now,
    required List<WidgetDose> today,
    required List<WidgetDose> tomorrow,
    required bool hasMeds,
    required WidgetTexts texts,
    required bool details,
  }) {
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return WidgetSnapshot(
      kind: MadarWidgetKind.meds,
      languageCode: texts.languageCode,
      private: !details,
      title: texts.title(MadarWidgetKind.meds),
      until: DateTime(now.year, now.month, now.day + 2),
      stale: texts.stale,
      link: WidgetLinks.meds,
      pages: [
        page(from: null, doses: today, hasMeds: hasMeds, texts: texts, details: details),
        page(from: midnight, doses: tomorrow, hasMeds: hasMeds, texts: texts, details: details),
      ],
    );
  }

  static WidgetPage page({
    required DateTime? from,
    required List<WidgetDose> doses,
    required bool hasMeds,
    required WidgetTexts texts,
    required bool details,
  }) {
    final l = texts.l;
    if (doses.isEmpty) {
      return WidgetPage(from: from, empty: hasMeds ? l.widgetsMedsNoneToday : l.widgetsMedsSetUp);
    }
    final sorted = [...doses]..sort((a, b) => a.at.compareTo(b.at));
    final answered = sorted.where((d) => d.answered).length;
    final open = sorted.length - answered;
    final next = sorted.where((d) => !d.answered).firstOrNull;
    final String detail;
    if (next == null) {
      detail = l.widgetsMedsAllDone;
    } else if (details) {
      detail = l.widgetsMedsNext(texts.fmt.formatTime(next.at), texts.name(next.name));
    } else {
      detail = texts.digits(l.widgetsMedsPending(open));
    }
    if (!details) {
      return WidgetPage(
        from: from,
        headline: texts.fraction(answered, sorted.length),
        detail: detail,
        note: WidgetTexts.dots(answered, sorted.length),
      );
    }
    final rows = [
      for (final d in sorted.take(maxRows))
        WidgetRow(
          text: d.dose == null || d.dose!.isEmpty ? texts.name(d.name) : '${texts.name(d.name)} · ${d.dose}',
          time: texts.fmt.formatTime(d.at),
          state: d.state,
          link: WidgetLinks.meds,
        ),
    ];
    return WidgetPage(
      from: from,
      headline: texts.fraction(answered, sorted.length),
      detail: detail,
      rows: rows,
      more: [for (var k = 1; k < sorted.length; k++) texts.digits(l.widgetsMore(k))],
    );
  }
}
