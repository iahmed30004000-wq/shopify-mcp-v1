import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// The five Madar themes.
enum MadarThemeId {
  /// Deep lapis-lazuli night with astrolabe gold (default).
  lapis,

  /// Mosque-tile emerald with gold.
  emerald,

  /// Desert night: warm umber, terracotta and copper.
  desert,

  /// Polar aurora: indigo sky, aurora teal and violet.
  aurora,

  /// Pearl: the light theme – mother-of-pearl, ink and gold.
  pearl,
}

/// Theme palettes. Every value here is a deliberate design decision; screens
/// must never hard-code colours.
abstract final class MadarPalettes {
  static MadarTokens tokensFor(MadarThemeId id) => switch (id) {
        MadarThemeId.lapis => _lapis,
        MadarThemeId.emerald => _emerald,
        MadarThemeId.desert => _desert,
        MadarThemeId.aurora => _aurora,
        MadarThemeId.pearl => _pearl,
      };

  static const _lapis = MadarTokens(
    brightness: Brightness.dark,
    space0: Color(0xFF03050F),
    space1: Color(0xFF070B1E),
    space2: Color(0xFF0D1430),
    space3: Color(0xFF16204A),
    glassFill: Color(0x3316224F),
    glassBorder: Color(0x33E8C77A),
    glassHighlight: Color(0x66FFF3D1),
    glassShadow: Color(0x99010208),
    textPrimary: Color(0xFFF4EEDD),
    textSecondary: Color(0xFFB8B4CB),
    textTertiary: Color(0xFF7C7A96),
    textOnAccent: Color(0xFF1A1405),
    accent: Color(0xFFE8C77A),
    accentSoft: Color(0x33E8C77A),
    accentGlow: Color(0x99F2CF7E),
    secondary: Color(0xFF3D5BD9),
    highlight: Color(0xFF7FD3FF),
    gold: Color(0xFFE8C77A),
    brass: Color(0xFFB8893A),
    brassDark: Color(0xFF5C3F12),
    success: Color(0xFF4FD69C),
    warning: Color(0xFFF2B84B),
    danger: Color(0xFFFF6B6B),
    info: Color(0xFF7FB8FF),
    nebulaA: Color(0xFF2B3FA8),
    nebulaB: Color(0xFF7A2E8C),
    starTint: Color(0xFFFFF1D6),
    dust: Color(0xFFB9A57A),
  );

  static const _emerald = MadarTokens(
    brightness: Brightness.dark,
    space0: Color(0xFF020A07),
    space1: Color(0xFF05140E),
    space2: Color(0xFF0A2219),
    space3: Color(0xFF123427),
    glassFill: Color(0x33123A2B),
    glassBorder: Color(0x33E6C76E),
    glassHighlight: Color(0x66E9FFE9),
    glassShadow: Color(0x99000503),
    textPrimary: Color(0xFFF0F2E6),
    textSecondary: Color(0xFFB2C4B8),
    textTertiary: Color(0xFF6F8A7C),
    textOnAccent: Color(0xFF171204),
    accent: Color(0xFFE6C76E),
    accentSoft: Color(0x33E6C76E),
    accentGlow: Color(0x99EBD27F),
    secondary: Color(0xFF19B37D),
    highlight: Color(0xFF9CF2C9),
    gold: Color(0xFFE6C76E),
    brass: Color(0xFFB58A35),
    brassDark: Color(0xFF4F3A10),
    success: Color(0xFF5BE3A5),
    warning: Color(0xFFF2C14E),
    danger: Color(0xFFFF7468),
    info: Color(0xFF86D4E8),
    nebulaA: Color(0xFF0F6B4E),
    nebulaB: Color(0xFF1E4F7A),
    starTint: Color(0xFFF3FFE8),
    dust: Color(0xFF9DBB8A),
  );

  static const _desert = MadarTokens(
    brightness: Brightness.dark,
    space0: Color(0xFF0C0604),
    space1: Color(0xFF170D07),
    space2: Color(0xFF26160C),
    space3: Color(0xFF3A2213),
    glassFill: Color(0x333D2415),
    glassBorder: Color(0x33E09A5B),
    glassHighlight: Color(0x66FFE3C4),
    glassShadow: Color(0x99050201),
    textPrimary: Color(0xFFF7EBDD),
    textSecondary: Color(0xFFCDB7A2),
    textTertiary: Color(0xFF8E7462),
    textOnAccent: Color(0xFF1C0D03),
    accent: Color(0xFFE09A5B),
    accentSoft: Color(0x33E09A5B),
    accentGlow: Color(0x99F0AE6C),
    secondary: Color(0xFFC8553D),
    highlight: Color(0xFFFFD8A8),
    gold: Color(0xFFEBC27C),
    brass: Color(0xFFB9803F),
    brassDark: Color(0xFF55320F),
    success: Color(0xFF8FD694),
    warning: Color(0xFFF6B656),
    danger: Color(0xFFFF6F59),
    info: Color(0xFF9BC4E2),
    nebulaA: Color(0xFF8C3B1F),
    nebulaB: Color(0xFF3B2A6B),
    starTint: Color(0xFFFFEBD1),
    dust: Color(0xFFCB9A6A),
  );

  static const _aurora = MadarTokens(
    brightness: Brightness.dark,
    space0: Color(0xFF04030D),
    space1: Color(0xFF09081F),
    space2: Color(0xFF110F33),
    space3: Color(0xFF1C1A4D),
    glassFill: Color(0x33201D5C),
    glassBorder: Color(0x337CF5D3),
    glassHighlight: Color(0x66E6FFF7),
    glassShadow: Color(0x99010008),
    textPrimary: Color(0xFFEFF3FF),
    textSecondary: Color(0xFFB5B8DA),
    textTertiary: Color(0xFF75789E),
    textOnAccent: Color(0xFF02140F),
    accent: Color(0xFF7CF5D3),
    accentSoft: Color(0x337CF5D3),
    accentGlow: Color(0x998CFFE0),
    secondary: Color(0xFF9B6BFF),
    highlight: Color(0xFFFF7AD9),
    gold: Color(0xFFF0D48A),
    brass: Color(0xFFB99A55),
    brassDark: Color(0xFF4E3F1B),
    success: Color(0xFF6CF0B0),
    warning: Color(0xFFFFD166),
    danger: Color(0xFFFF6B8B),
    info: Color(0xFF8FB8FF),
    nebulaA: Color(0xFF1FAF8F),
    nebulaB: Color(0xFF7B3FD6),
    starTint: Color(0xFFE8F4FF),
    dust: Color(0xFF8D93C9),
  );

  static const _pearl = MadarTokens(
    brightness: Brightness.light,
    space0: Color(0xFFF7F3EA),
    space1: Color(0xFFEFE8DA),
    space2: Color(0xFFE5DCC8),
    space3: Color(0xFFD9CCB2),
    glassFill: Color(0x99FFFFFF),
    glassBorder: Color(0x55B8862F),
    glassHighlight: Color(0xCCFFFFFF),
    glassShadow: Color(0x33483A1C),
    textPrimary: Color(0xFF1D1A24),
    textSecondary: Color(0xFF4F4A5C),
    textTertiary: Color(0xFF8A8494),
    textOnAccent: Color(0xFFFFFBF1),
    accent: Color(0xFFB0802A),
    accentSoft: Color(0x33B0802A),
    accentGlow: Color(0x66D9A441),
    secondary: Color(0xFF2F4BB5),
    highlight: Color(0xFF2E8FBF),
    gold: Color(0xFFC39334),
    brass: Color(0xFF9C7127),
    brassDark: Color(0xFF5A3F10),
    success: Color(0xFF1E9E68),
    warning: Color(0xFFC77D0A),
    danger: Color(0xFFD64545),
    info: Color(0xFF2F6FB5),
    nebulaA: Color(0xFFE9D8B8),
    nebulaB: Color(0xFFD7DDF2),
    starTint: Color(0xFFB0802A),
    dust: Color(0xFFCDBB94),
  );
}

/// Signature palette of a planet (surface, glow, deep shadow).
@immutable
class PlanetPalette {
  const PlanetPalette(this.surface, this.glow, this.deep);
  final Color surface;
  final Color glow;
  final Color deep;
}

abstract final class PlanetPalettes {
  static const faith = PlanetPalette(Color(0xFFF2C14E), Color(0xFFFFE7A3), Color(0xFF7A5A12));
  static const health = PlanetPalette(Color(0xFF1FB5C9), Color(0xFF5CFFE4), Color(0xFF063A52));
  static const family = PlanetPalette(Color(0xFFD9774A), Color(0xFFFFC49B), Color(0xFF5C2412));
  static const work = PlanetPalette(Color(0xFF8A95A8), Color(0xFFFFB547), Color(0xFF1E2430));
  static const money = PlanetPalette(Color(0xFF7FE3C4), Color(0xFFF5D06F), Color(0xFF0E3B35));
  static const growth = PlanetPalette(Color(0xFF4CC96B), Color(0xFFB8F28A), Color(0xFF0F3D1E));
  static const body = PlanetPalette(Color(0xFFFF5A36), Color(0xFFFFB02E), Color(0xFF3A0E08));
  static const travel = PlanetPalette(Color(0xFF9C8CFF), Color(0xFFE6D3FF), Color(0xFF2A1F5C));

  static const byKey = <String, PlanetPalette>{
    'faith': faith,
    'health': health,
    'family': family,
    'work': work,
    'money': money,
    'growth': growth,
    'body': body,
    'travel': travel,
  };

  /// Palette for any colour (user-added planets / recolouring).
  static PlanetPalette fromColor(Color c) {
    final hsl = HSLColor.fromColor(c);
    return PlanetPalette(
      c,
      hsl.withLightness((hsl.lightness + 0.25).clamp(0.0, 0.92)).toColor(),
      hsl.withLightness((hsl.lightness * 0.35).clamp(0.05, 0.3)).toColor(),
    );
  }
}

/// Builds the full [ThemeData] for a theme id, optional custom accent and
/// locale (Arabic vs Latin typography metrics).
ThemeData buildMadarTheme(MadarThemeId id, {Color? customAccent, required bool arabic}) {
  var tokens = MadarPalettes.tokensFor(id);
  if (customAccent != null) {
    final onAccent = ThemeData.estimateBrightnessForColor(customAccent) == Brightness.dark
        ? const Color(0xFFFFFBF1)
        : const Color(0xFF14110A);
    tokens = tokens.copyWith(
      accent: customAccent,
      accentSoft: customAccent.withValues(alpha: 0.2),
      accentGlow: customAccent.withValues(alpha: 0.6),
      textOnAccent: onAccent,
    );
  }
  final isDark = tokens.isDark;
  final scheme = ColorScheme(
    brightness: tokens.brightness,
    primary: tokens.accent,
    onPrimary: tokens.textOnAccent,
    primaryContainer: tokens.accentSoft,
    onPrimaryContainer: tokens.textPrimary,
    secondary: tokens.secondary,
    onSecondary: isDark ? tokens.textPrimary : const Color(0xFFFFFFFF),
    tertiary: tokens.highlight,
    onTertiary: tokens.space0,
    error: tokens.danger,
    onError: const Color(0xFFFFFFFF),
    surface: tokens.space1,
    onSurface: tokens.textPrimary,
    onSurfaceVariant: tokens.textSecondary,
    surfaceContainerLowest: tokens.space0,
    surfaceContainerLow: tokens.space1,
    surfaceContainer: tokens.space2,
    surfaceContainerHigh: tokens.space3,
    surfaceContainerHighest: tokens.space3,
    outline: tokens.glassBorder,
    outlineVariant: tokens.glassBorder.withValues(alpha: 0.12),
    shadow: tokens.glassShadow,
    scrim: const Color(0xCC000000),
    inverseSurface: tokens.textPrimary,
    onInverseSurface: tokens.space0,
    inversePrimary: tokens.brass,
  );
  final text = MadarTypography.textTheme(tokens, arabic: arabic);
  return ThemeData(
    useMaterial3: true,
    brightness: tokens.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.space0,
    canvasColor: tokens.space0,
    fontFamily: MadarTypography.uiFamily,
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    extensions: [tokens],
    iconTheme: IconThemeData(color: tokens.textPrimary, size: 22),
    dividerTheme: DividerThemeData(color: tokens.glassBorder.withValues(alpha: 0.18), thickness: 0.6),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: tokens.textPrimary,
      centerTitle: true,
      titleTextStyle: text.titleLarge,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalBackgroundColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens.space3,
      contentTextStyle: text.bodyMedium,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.glassFill,
      hintStyle: text.bodyMedium?.copyWith(color: tokens.textTertiary),
      labelStyle: text.bodyMedium?.copyWith(color: tokens.textSecondary),
      floatingLabelStyle: text.bodyMedium?.copyWith(color: tokens.accent),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusM),
        borderSide: BorderSide(color: tokens.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusM),
        borderSide: BorderSide(color: tokens.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusM),
        borderSide: BorderSide(color: tokens.accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusM),
        borderSide: BorderSide(color: tokens.danger),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
