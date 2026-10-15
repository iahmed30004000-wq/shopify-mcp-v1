import 'package:flutter/foundation.dart';

import 'widget_kind.dart';
import 'widget_links.dart';
import 'widget_snapshot.dart';
import 'widget_texts.dart';

/// A Top 3 item as the widget sees it (mapped from the Work planet's
/// `FocusItem` by the providers).
@immutable
class WidgetTask {
  const WidgetTask({required this.title, this.done = false, this.link});

  final String title;
  final bool done;

  /// Where a tap on it leads (see [WidgetLinks.task] / [WidgetLinks.card]).
  final String? link;
}

/// The Top 3 widget's snapshot (pure). Today's Top 3 from the start; from
/// midnight the choice is yesterday's (Top 3 rules: flags belong to the day
/// they were set for), so the next page asks for a new Top 3 and says how
/// many are waiting to be carried over – the app's morning prompt settles
/// them.
///
/// Details shown: done / total and a row per item with its check (a tap
/// opens the item). Counts only: done / total, how many are left and the
/// state dots.
abstract final class TasksWidgetBuilder {
  static WidgetSnapshot build({
    required DateTime now,
    required List<WidgetTask> items,
    required WidgetTexts texts,
    required bool details,
    int carriedOver = 0,
  }) {
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final open = items.where((i) => !i.done).length;
    return WidgetSnapshot(
      kind: MadarWidgetKind.tasks,
      languageCode: texts.languageCode,
      private: !details,
      title: texts.title(MadarWidgetKind.tasks),
      until: DateTime(now.year, now.month, now.day + 2),
      stale: texts.stale,
      link: WidgetLinks.tasks,
      pages: [
        items.isEmpty
            ? _choose(null, carriedOver, texts)
            : _today(items, texts: texts, details: details),
        _choose(midnight, items.isEmpty ? carriedOver : open, texts),
      ],
    );
  }

  static WidgetPage _today(List<WidgetTask> items, {required WidgetTexts texts, required bool details}) {
    final l = texts.l;
    final done = items.where((i) => i.done).length;
    final open = items.length - done;
    final detail = open == 0 ? l.widgetsTasksAllDone : texts.digits(l.widgetsTasksLeft(open));
    if (!details) {
      return WidgetPage(
        from: null,
        headline: texts.fraction(done, items.length),
        detail: detail,
        note: WidgetTexts.dots(done, items.length),
      );
    }
    return WidgetPage(
      from: null,
      headline: texts.fraction(done, items.length),
      detail: detail,
      rows: [
        for (final i in items)
          WidgetRow(
            text: texts.name(i.title),
            state: i.done ? WidgetRowState.done : WidgetRowState.open,
            link: i.link,
          ),
      ],
    );
  }

  /// No Top 3 for the day yet ([carried] unfinished ones from yesterday).
  static WidgetPage _choose(DateTime? from, int carried, WidgetTexts texts) => WidgetPage(
    from: from,
    empty: texts.l.widgetsTasksEmpty,
    note: carried > 0 ? texts.digits(texts.l.widgetsTasksCarried(carried)) : null,
  );
}
