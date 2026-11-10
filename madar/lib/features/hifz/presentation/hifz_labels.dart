import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/quran/quran_catalog.dart';
import '../../wird/presentation/wird_labels.dart';
import '../domain/hadith_collection.dart';
import '../domain/hifz_models.dart';

/// Texts about Hifz items in the UI language.
class HifzTexts {
  HifzTexts(this.l, this.fmt, {this.catalog, this.hadith}) : arabic = l.localeName.startsWith('ar');

  final L10n l;
  final MadarFormatter fmt;
  final QuranCatalog? catalog;
  final HadithCollection? hadith;
  final bool arabic;

  WirdTexts? get _quran => catalog == null ? null : WirdTexts(l, fmt, catalog!);

  HadithEntry? entryOf(HifzCard c) => c.kind == HifzKind.hadith ? hadith?.byKey(c.source) : null;

  /// `الملك ١–٥`, a hadith's title, or a custom item's title.
  String title(HifzCard c) {
    switch (c.kind) {
      case HifzKind.ayat:
        final r = c.range;
        if (r == null) return l.hifzKindAyat;
        return _quran?.range(r) ?? '${r.first.surah}:${r.first.ayah}–${r.last.ayah}';
      case HifzKind.hadith:
        final e = entryOf(c);
        if (e != null) return e.title(arabic: arabic);
        return c.title ?? _excerpt(c.body);
      case HifzKind.custom:
        return (c.title?.trim().isNotEmpty ?? false) ? c.title! : _excerpt(c.body);
    }
  }

  /// `ص ٥٦٢، ٥ آيات`, `الأربعون النووية، ١٢`, or a custom item's source.
  String subtitle(HifzCard c) {
    switch (c.kind) {
      case HifzKind.ayat:
        final r = c.range, q = _quran;
        if (r == null || q == null) return l.hifzKindAyat;
        return '${q.pages(r)}${l.wirdSep}${fmt.localizeDigits(l.wirdUnitAyat(c.ayahCount))}';
      case HifzKind.hadith:
        final e = entryOf(c), h = hadith;
        if (e == null || h == null) return c.source ?? l.hifzKindHadith;
        return l.hifzHadithSource(h.title(arabic: arabic), fmt.formatInt(e.number));
      case HifzKind.custom:
        return (c.source?.trim().isNotEmpty ?? false) ? c.source! : l.hifzKindCustom;
    }
  }

  /// `جديد`, `غدًا`, `بعد ٦ أيام`, `فات موعده منذ يومين`.
  String due(HifzCard c, DateTime today) {
    final d = c.dueInDays(today);
    if (d == null) return l.hifzNewBadge;
    if (d < 0) return fmt.localizeDigits(l.hifzOverdue(-d));
    final s = fmt.localizeDigits(l.hifzDueIn(d));
    // "today" / "in 6 days" start a label here: capitalise (Latin only).
    return arabic || s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  }

  String kind(HifzKind k) => switch (k) {
    HifzKind.ayat => l.hifzKindAyat,
    HifzKind.hadith => l.hifzKindHadith,
    HifzKind.custom => l.hifzKindCustom,
  };

  String _excerpt(String? body) {
    final words = (body ?? '').trim().split(RegExp(r'\s+'));
    return words.length <= 5 ? words.join(' ') : '${words.take(5).join(' ')}…';
  }
}

/// `كل يوم`, `كل ٦ أيام`.
String hifzIntervalText(L10n l, MadarFormatter fmt, int days) =>
    days <= 1 ? l.hifzEveryDay : l.hifzInterval(fmt.localizeDigits(l.wirdDays(days)));

IconData hifzKindIcon(HifzKind k) => switch (k) {
  HifzKind.ayat => Icons.auto_stories_rounded,
  HifzKind.hadith => Icons.format_quote_rounded,
  HifzKind.custom => Icons.edit_note_rounded,
};

/// SM-2 grade names (0–5).
String hifzGradeLabel(L10n l, int q) => switch (q) {
  0 => l.hifzGrade0,
  1 => l.hifzGrade1,
  2 => l.hifzGrade2,
  3 => l.hifzGrade3,
  4 => l.hifzGrade4,
  _ => l.hifzGrade5,
};

/// What each grade means.
String hifzGradeHint(L10n l, int q) => switch (q) {
  0 => l.hifzGrade0Hint,
  1 => l.hifzGrade1Hint,
  2 => l.hifzGrade2Hint,
  3 => l.hifzGrade3Hint,
  4 => l.hifzGrade4Hint,
  _ => l.hifzGrade5Hint,
};

/// Grade colours: forgotten (danger) → hard (warning / brass) → good
/// (accent) → perfect (success).
Color hifzGradeColor(MadarTokens t, int q) => switch (q) {
  0 || 1 => t.danger,
  2 => t.warning,
  3 => t.brass,
  4 => t.accent,
  _ => t.success,
};
