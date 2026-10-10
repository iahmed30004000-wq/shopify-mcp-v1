import 'package:flutter/material.dart';

import 'tokens.dart';

/// Typography: IBM Plex Sans Arabic for UI, Reem Kufi for display headings,
/// Amiri Quran for Quran text (KFGQPC-style Uthmani fallback: Amiri).
abstract final class MadarTypography {
  static const uiFamily = 'PlexArabic';
  static const displayFamily = 'ReemKufi';
  static const quranFamily = 'AmiriQuran';
  static const naskhFamily = 'Amiri';

  /// Arabic script needs extra line height for diacritics; Latin is tighter.
  static TextTheme textTheme(MadarTokens t, {required bool arabic}) {
    final h = arabic ? 1.5 : 1.3;
    TextStyle ui(double size, FontWeight w, Color c, {double? height, double spacing = 0}) => TextStyle(
          fontFamily: uiFamily,
          fontSize: size,
          fontWeight: w,
          color: c,
          height: height ?? h,
          letterSpacing: arabic ? 0 : spacing,
        );
    // Reem Kufi is a variable font: the weight must be set on its axis (a
    // bare w600 is synthesised – smeared, blobby Kufi). Latin headings keep
    // normal tracking (tight tracking ran the words together).
    TextStyle display(double size, Color c) => TextStyle(
          fontFamily: displayFamily,
          fontSize: size,
          fontWeight: FontWeight.w600,
          fontVariations: const [FontVariation.weight(600)],
          color: c,
          height: arabic ? 1.35 : 1.15,
          letterSpacing: 0,
          // Reem Kufi's space is only 0.13 em ("Designgallery"); widen the
          // Latin word gap to ~0.25 em. Arabic keeps the font's own spacing.
          wordSpacing: arabic ? null : size * 0.12,
        );
    return TextTheme(
      displayLarge: display(52, t.textPrimary),
      displayMedium: display(40, t.textPrimary),
      displaySmall: display(32, t.textPrimary),
      headlineLarge: display(28, t.textPrimary),
      headlineMedium: display(24, t.textPrimary),
      headlineSmall: display(20, t.textPrimary),
      titleLarge: ui(19, FontWeight.w600, t.textPrimary),
      titleMedium: ui(16, FontWeight.w600, t.textPrimary),
      titleSmall: ui(14, FontWeight.w600, t.textSecondary),
      bodyLarge: ui(16, FontWeight.w400, t.textPrimary),
      bodyMedium: ui(14, FontWeight.w400, t.textPrimary),
      bodySmall: ui(12.5, FontWeight.w400, t.textSecondary),
      labelLarge: ui(14, FontWeight.w600, t.textPrimary, spacing: 0.2),
      labelMedium: ui(12, FontWeight.w500, t.textSecondary, spacing: 0.3),
      labelSmall: ui(11, FontWeight.w500, t.textTertiary, spacing: 0.4),
    );
  }

  /// Quran text style (tajweed colouring is applied per span on top).
  static TextStyle quran(MadarTokens t, {double size = 26}) => TextStyle(
        fontFamily: quranFamily,
        fontSize: size,
        height: 2.1,
        color: t.textPrimary,
      );

  /// Monospaced-feel numerals for countdowns / engraved dials.
  static TextStyle numerals(MadarTokens t, {double size = 14, Color? color}) => TextStyle(
        fontFamily: uiFamily,
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? t.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
