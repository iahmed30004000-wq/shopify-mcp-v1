// Shared axes of the Phase 2 theme matrix screenshots.
//
// Narrow a run with environment variables, e.g.
//   MATRIX_THEMES=lapis,pearl MATRIX_LANGS=ar flutter test --tags screenshot …
import 'dart:io';

import 'package:madar/core/design/themes.dart';

List<String> _env(String name) =>
    (Platform.environment[name] ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

/// The five themes (or the subset in MATRIX_THEMES).
final List<MadarThemeId> matrixThemes = () {
  final only = _env('MATRIX_THEMES');
  return [
    for (final id in MadarThemeId.values)
      if (only.isEmpty || only.contains(id.name)) id,
  ];
}();

/// Arabic and English (or the subset in MATRIX_LANGS).
final List<String> matrixLanguages = () {
  final only = _env('MATRIX_LANGS');
  return [
    for (final l in const ['ar', 'en'])
      if (only.isEmpty || only.contains(l)) l,
  ];
}();

/// `phase2/themes/<screen>_<lang>_<theme>` (a path under `screenshots/`).
String matrixShot(String screen, String lang, MadarThemeId theme) => 'phase2/themes/${screen}_${lang}_${theme.name}';
