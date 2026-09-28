import 'package:flutter/material.dart';

import 'contrast.dart';
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
///
/// Legibility contract (WCAG AA, enforced by test/core/design/theme_contrast_test.dart):
/// every colour a screen may use for text – `textPrimary/Secondary/Tertiary`,
/// `accent`, `gold`, `success`, `warning`, `danger`, `info`, `highlight` –
/// reaches 4.5:1 on every surface of [textSurfaces] and on the raised
/// `space2`, and `textOnAccent` reaches 4.5:1 on `accent` (`brass` is a
/// metal for rings and rules: 3:1). On the night themes the same holds on the
/// brightest ground measured on rendered screens – smoked glass lit by the
/// nebula (rendered_contrast_screenshot_test.dart measures every text as
/// painted) – which is why their secondary / tertiary text is brighter than
/// the token surfaces alone would need. Pearl's metals and status colours are
/// deep "ink" tones rather than the bright jewel tones of the dark themes.
abstract final class MadarPalettes {
  static MadarTokens tokensFor(MadarThemeId id) => switch (id) {
        MadarThemeId.lapis => _lapis,
        MadarThemeId.emerald => _emerald,
        MadarThemeId.desert => _desert,
        MadarThemeId.aurora => _aurora,
        MadarThemeId.pearl => _pearl,
      };

  /// The theme's tokens, with the user's custom [accent] applied when given
  /// (see [withAccent]). What `buildMadarTheme` installs.
  static MadarTokens resolve(MadarThemeId id, {Color? accent}) {
    final base = tokensFor(id);
    if (accent == null) return base;
    // Memoised: adapting an accent runs a contrast search, and swatches,
    // the hue rail and the theme all ask for the same few pairs.
    final key = (id, accent.toARGB32());
    final hit = _resolved[key];
    if (hit != null) return hit;
    if (_resolved.length >= 256) _resolved.clear();
    return _resolved[key] = withAccent(base, accent);
  }

  static final Map<(MadarThemeId, int), MadarTokens> _resolved = {};

  /// The surfaces text sits on in theme [t]: the page backgrounds, the
  /// glass fill composited over them, the raised [MadarTokens.space2] and
  /// the hardest ground measured on screen ([MadarTokens.glassLit]).
  static List<Color> textSurfaces(MadarTokens t) => [
        t.space0,
        t.space1,
        MadarContrast.over(t.glassFill, t.space0),
        MadarContrast.over(t.glassFill, t.space2),
        t.space2,
        t.glassLit,
      ];

  /// The contrast a custom accent is fitted to on [textSurfaces]: the
  /// themes' own accents all clear 5:1, and a colour fitted to exactly 4.5
  /// dropped below AA on a selected chip, whose wash of that same accent
  /// lifts the ground (measured 4.1:1 on Lapis for a picked pure blue).
  static const double accentHeadroom = 5.0;

  /// Ink on light accents / light ink on deep accents.
  static const Color _onAccentLight = Color(0xFFFFFBF1);
  static const Color _onAccentDark = Color(0xFF14110A);

  /// [base] with a custom accent. The user's colour keeps its hue and
  /// saturation but its lightness is moved – as little as needed – so that
  /// accent-coloured text and icons keep [accentHeadroom] on every surface of
  /// the theme (a pale mint accent turns deep teal on Pearl; a deep blue
  /// brightens on the night themes), and the label on an accent-filled
  /// button reads at 4.5:1 too.
  static MadarTokens withAccent(MadarTokens base, Color accent) {
    var a = MadarContrast.ensure(accent.withValues(alpha: 1), textSurfaces(base), min: accentHeadroom);
    if (base.isDark) {
      // Dark ink on the filled accent needs a little more light.
      a = MadarContrast.ensure(a, const [_onAccentDark]);
    } else {
      a = MadarContrast.ensure(a, const [_onAccentLight]);
    }
    final onAccent = MadarContrast.bestOn(a, const [_onAccentLight, _onAccentDark]);
    return base.copyWith(
      accent: a,
      accentSoft: a.withValues(alpha: 0.2),
      accentGlow: a.withValues(alpha: 0.6),
      textOnAccent: onAccent,
    );
  }

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
    textSecondary: Color(0xFFC7C3D6),
    textTertiary: Color(0xFFADACBD),
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
    danger: Color(0xFFFF9393),
    info: Color(0xFF7FB8FF),
    nebulaA: Color(0xFF2B3FA8),
    nebulaB: Color(0xFF7A2E8C),
    starTint: Color(0xFFFFF1D6),
    dust: Color(0xFFB9A57A),
    // Measured: glass lit by the nebula (Settings › Motion, rendered).
    glassLit: Color(0xFF383854),
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
    textSecondary: Color(0xFFB9CABF),
    textTertiary: Color(0xFFA7B9AF),
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
    danger: Color(0xFFFF948A),
    info: Color(0xFF86D4E8),
    nebulaA: Color(0xFF0F6B4E),
    nebulaB: Color(0xFF1E4F7A),
    starTint: Color(0xFFF3FFE8),
    dust: Color(0xFF9DBB8A),
    // Measured: glass lit by the nebula (Settings › Motion, rendered).
    glassLit: Color(0xFF2C4840),
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
    textSecondary: Color(0xFFD5C3B1),
    textTertiary: Color(0xFFBEADA0),
    textOnAccent: Color(0xFF1C0D03),
    accent: Color(0xFFF0AE74),
    accentSoft: Color(0x33F0AE74),
    accentGlow: Color(0x99F0AE6C),
    secondary: Color(0xFFC8553D),
    highlight: Color(0xFFFFD8A8),
    gold: Color(0xFFEBC27C),
    brass: Color(0xFFB9803F),
    brassDark: Color(0xFF55320F),
    success: Color(0xFF8FD694),
    warning: Color(0xFFF6B656),
    danger: Color(0xFFFF9483),
    info: Color(0xFF9BC4E2),
    nebulaA: Color(0xFF8C3B1F),
    nebulaB: Color(0xFF3B2A6B),
    starTint: Color(0xFFFFEBD1),
    dust: Color(0xFFCB9A6A),
    // Measured: glass lit by the nebula (Settings › Motion, rendered).
    glassLit: Color(0xFF4B372F),
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
    textSecondary: Color(0xFFC1C4E0),
    textTertiary: Color(0xFFADB0C6),
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
    danger: Color(0xFFFF90A8),
    info: Color(0xFF8FB8FF),
    nebulaA: Color(0xFF137A63),
    nebulaB: Color(0xFF7B3FD6),
    starTint: Color(0xFFE8F4FF),
    dust: Color(0xFF8D93C9),
    // Measured: glass lit by the nebula (Settings › Motion, rendered).
    glassLit: Color(0xFF373A5D),
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
    textSecondary: Color(0xFF474353),
    textTertiary: Color(0xFF5E5867),
    textOnAccent: Color(0xFFFFFBF1),
    accent: Color(0xFF77540E),
    accentSoft: Color(0x3377540E),
    accentGlow: Color(0x66D9A441),
    secondary: Color(0xFF2F4BB5),
    highlight: Color(0xFF1E6082),
    gold: Color(0xFF755517),
    brass: Color(0xFF75551C),
    // The astrolabe's polished brass on the pearl (not for text).
    metalGold: Color(0xFFC39334),
    metalBrass: Color(0xFF9C7127),
    brassDark: Color(0xFF5A3F10),
    success: Color(0xFF126744),
    warning: Color(0xFF805005),
    danger: Color(0xFFAB2828),
    info: Color(0xFF265C98),
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
  final tokens = MadarPalettes.resolve(id, accent: customAccent);
  final scheme = ColorScheme(
    brightness: tokens.brightness,
    primary: tokens.accent,
    onPrimary: tokens.textOnAccent,
    primaryContainer: tokens.accentSoft,
    onPrimaryContainer: tokens.textPrimary,
    secondary: tokens.secondary,
    // Whichever ink reads best on the fill (Emerald's bright green and
    // Aurora's violet need dark ink; white on them was 2.4 / 3.2 : 1).
    onSecondary: MadarContrast.bestOn(tokens.secondary, [tokens.textPrimary, tokens.space0, const Color(0xFFFFFFFF)]),
    tertiary: tokens.highlight,
    onTertiary: tokens.space0,
    error: tokens.danger,
    // White on the night themes' bright corals was 2.6–2.8 : 1.
    onError: MadarContrast.bestOn(tokens.danger, [const Color(0xFFFFFFFF), tokens.space0]),
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
    // Material's tooltip long-press vibrates through HapticFeedback directly,
    // bypassing the user's haptics setting and without a Madar sound.
    tooltipTheme: const TooltipThemeData(enableFeedback: false),
    dividerTheme: DividerThemeData(color: tokens.glassBorder.withValues(alpha: 0.18), thickness: 0.6),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: tokens.textPrimary,
      centerTitle: true,
      titleTextStyle: text.titleLarge,
    ),
    // Material's calendar heads its month in onSurface at 60 % – 4.4:1 on
    // Pearl's sheets (measured): the theme's own secondary ink instead.
    datePickerTheme: DatePickerThemeData(subHeaderForegroundColor: tokens.textSecondary),
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

/// [theme] with its typography – the text theme and every style derived
/// from it (app bar title, snack bar, field hint / label) – rebuilt for the
/// script ([arabic]: taller lines for diacritics, no Latin tracking) from
/// the theme's own, possibly mid-animation, tokens. Returns [theme] itself
/// when nothing changes.
ThemeData withMadarTypography(ThemeData theme, {required bool arabic}) {
  final tokens = theme.extension<MadarTokens>();
  if (tokens == null) return theme;
  // Merged over the platform typography exactly as the ThemeData
  // constructor does (explicit `decoration: none` and friends included).
  final base = tokens.isDark ? theme.typography.white : theme.typography.black;
  final text = base.merge(MadarTypography.textTheme(tokens, arabic: arabic));
  if (text == theme.textTheme) return theme;
  final body = text.bodyMedium;
  return theme.copyWith(
    textTheme: text,
    appBarTheme: theme.appBarTheme.copyWith(titleTextStyle: text.titleLarge),
    snackBarTheme: theme.snackBarTheme.copyWith(contentTextStyle: body),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      hintStyle: body?.copyWith(color: tokens.textTertiary),
      labelStyle: body?.copyWith(color: tokens.textSecondary),
      floatingLabelStyle: body?.copyWith(color: tokens.accent),
    ),
  );
}

/// Makes a language switch re-lay-out every text in the frame it happens.
///
/// `MaterialApp` cross-fades one theme into the next ([MadarTokens.lerp]),
/// and the Arabic and Latin typography differ in line height and tracking –
/// so, left alone, every paragraph would keep shrinking or growing for the
/// length of the cross-fade after the language flips. Placed in
/// `MaterialApp.builder`, this scope pins the metrics to the current
/// language at once while colours still glide with a theme change.
class MadarTypographyScope extends StatefulWidget {
  const MadarTypographyScope({super.key, required this.arabic, required this.child});

  /// Whether the UI language is Arabic.
  final bool arabic;
  final Widget child;

  @override
  State<MadarTypographyScope> createState() => _MadarTypographyScopeState();
}

class _MadarTypographyScopeState extends State<MadarTypographyScope> {
  ThemeData? _source;
  bool? _arabic;
  late ThemeData _pinned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Memoised on the incoming theme instance: an unrelated rebuild (a
    // volume drag, the digit style) hands the subtree the very same
    // ThemeData, so nothing below rebuilds for it.
    if (!identical(theme, _source) || widget.arabic != _arabic) {
      _source = theme;
      _arabic = widget.arabic;
      _pinned = withMadarTypography(theme, arabic: widget.arabic);
    }
    // Always a Theme (never the bare child), so the subtree below keeps its
    // place – and its state – whether or not the metrics needed pinning.
    return Theme(data: _pinned, child: widget.child);
  }
}
