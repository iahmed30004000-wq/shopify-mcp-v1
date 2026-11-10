import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/design/themes.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart' show InteractionIcons;
import '../data/custom_module_source.dart';
import '../data/search_source.dart';
import '../domain/search_doc.dart';

/// How a planet or a group (source / custom module) looks in the results.
@immutable
class SearchVisual {
  const SearchVisual(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// Names, icons and colours of planets and groups, from the planets table,
/// the registry and the custom modules.
class SearchVisuals {
  SearchVisuals({
    required this.l10n,
    required this.tokens,
    required this.registry,
    required List<PlanetRow> planets,
    required this._modules,
  }) : _planets = {for (final p in planets) p.key: p};

  final L10n l10n;
  final MadarTokens tokens;
  final SearchRegistry registry;
  final Map<String, PlanetRow> _planets;
  final Map<String, CustomModuleRowLike> _modules;

  bool get _arabic => l10n.localeName.startsWith('ar');

  static const List<String> _builtInOrder = ['faith', 'health', 'family', 'work', 'money', 'growth', 'body', 'travel'];

  static const Map<String, IconData> _planetIcons = {
    'faith': Icons.mosque_rounded,
    'health': Icons.favorite_rounded,
    'family': Icons.family_restroom_rounded,
    'work': Icons.work_rounded,
    'money': Icons.paid_rounded,
    'growth': Icons.grass_rounded,
    'body': Icons.fitness_center_rounded,
    'travel': Icons.flight_rounded,
    'custom': Icons.widgets_rounded,
  };

  SearchVisual planet(String key) {
    final row = _planets[key];
    final name = row == null
        ? (SearchLabels.builtInPlanet(l10n, key) ?? key)
        : (_arabic ? row.nameAr : row.nameEn);
    final color = PlanetPalettes.byKey[key]?.surface ?? (row == null ? tokens.accent : Color(row.color));
    final icon = _planetIcons[key] ?? InteractionIcons.resolve(row?.icon);
    return SearchVisual(name, icon, color);
  }

  /// Planets in orbit order: built-in ones, user-added ones (by their
  /// order), then modules without a planet.
  List<String> order(Iterable<String> keys) {
    int rank(String k) {
      final i = _builtInOrder.indexOf(k);
      if (i >= 0) return i;
      if (k == 'custom') return 1 << 20;
      return 100 + (_planets[k]?.sortOrder ?? 1000);
    }

    return keys.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  /// A group: a source ([SearchSourceBase.label] / icon, planet colour) or a
  /// custom module (its name, icon and colour); [sample] fills in a module
  /// the lookup does not know yet.
  SearchVisual group(String key, {SearchDoc? sample}) {
    if (key.startsWith('module:')) {
      final m = _modules[key.substring(7)];
      final label = m?.name ?? sample?.groupLabel ?? l10n.searchSourceCustomEntries;
      final icon = InteractionIcons.resolve(m?.icon ?? sample?.groupIcon, fallback: Icons.widgets_rounded);
      final argb = m?.color ?? sample?.groupColor;
      return SearchVisual(label, icon, argb == null ? tokens.accent : Color(argb));
    }
    final source = registry[key];
    if (source == null) {
      return SearchVisual(key, Icons.search_rounded, planet(sample?.planetKey ?? 'custom').color);
    }
    return SearchVisual(source.label(l10n), source.icon, planet(sample?.planetKey ?? source.planetKey).color);
  }

  /// The trailing date of a result: today / yesterday / tomorrow, the day
  /// and month this year, the full short date otherwise.
  static String date(DateTime date, DateTime now, L10n l, MadarFormatter fmt) {
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inHours;
    if (diff.abs() < 12) return l.searchToday;
    if (diff >= -36 && diff <= -12) return l.searchYesterday;
    if (diff >= 12 && diff <= 36) return l.searchTomorrow;
    try {
      return fmt.formatDate(day, style: day.year == now.year ? MadarDateStyle.dayMonth : MadarDateStyle.short);
    } on Object {
      return fmt.localizeDigits('${day.year}/${day.month}/${day.day}');
    }
  }
}

/// [text] with [ranges] lit in [highlight] (ranges clamped and ordered).
TextSpan searchHighlightSpan(String text, List<HighlightRange> ranges, TextStyle? style, TextStyle highlight) {
  if (ranges.isEmpty) return TextSpan(text: text, style: style);
  final children = <TextSpan>[];
  var at = 0;
  for (final r in ranges) {
    final a = r.start.clamp(at, text.length);
    final b = r.end.clamp(a, text.length);
    if (a > at) children.add(TextSpan(text: text.substring(at, a)));
    if (b > a) children.add(TextSpan(text: text.substring(a, b), style: highlight));
    at = b;
  }
  if (at < text.length) children.add(TextSpan(text: text.substring(at)));
  return TextSpan(style: style, children: children);
}

/// The reading direction of [text], from its first letter that has one
/// (digits and punctuation have none): a result in the other script than
/// the app's is laid out in its own direction («Call Omar!» keeps its «!»
/// at the end in the Arabic app, a snippet's leading «…» stays before the
/// first word). Null when [text] has no such letter.
TextDirection? searchTextDirection(String text) {
  for (final rune in text.runes) {
    if (_rtl(rune)) return TextDirection.rtl;
    if (_ltr(rune)) return TextDirection.ltr;
  }
  return null;
}

bool _rtl(int c) =>
    (c >= 0x0590 && c <= 0x05FF) || // Hebrew
    (c >= 0x0600 && c <= 0x06FF && !(c >= 0x0660 && c <= 0x0669) && !(c >= 0x06F0 && c <= 0x06F9) && c != 0x066B && c != 0x066C) ||
    (c >= 0x0700 && c <= 0x08FF) || // Syriac, Thaana, Arabic supplement / extended
    (c >= 0xFB1D && c <= 0xFDFF) || // Hebrew / Arabic presentation forms A
    (c >= 0xFE70 && c <= 0xFEFC) || // Arabic presentation forms B
    c == 0x200F; // RLM

bool _ltr(int c) =>
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    (c >= 0xC0 && c <= 0x24F && c != 0xD7 && c != 0xF7) || // Latin-1 and Latin Extended letters
    (c >= 0x0370 && c <= 0x058F) || // Greek, Cyrillic, Armenian
    (c >= 0x0900 && c <= 0x1FFF) || // Indic … Greek extended
    (c >= 0x3040 && c <= 0x9FFF) || // kana, CJK
    (c >= 0xAC00 && c <= 0xD7AF) || // Hangul
    c == 0x200E; // LRM
