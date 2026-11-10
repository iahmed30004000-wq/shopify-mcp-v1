// The approved «مدار الصغار» palette and type (docs/kids/DESIGN.md sections 2-3).
//
// Kept in the learn folder because the shell agent owns its own tokens; both
// are the same values, so nothing visible differs. There is no red anywhere:
// the "soft retry" colour is amber.
import 'package:flutter/material.dart';

abstract final class KidsColors {
  static const night900 = Color(0xFF17143F);
  static const night800 = Color(0xFF221E5A);
  static const night700 = Color(0xFF2F2A78);
  static const night500 = Color(0xFF5650B0);
  static const night300 = Color(0xFFA9A5E6);
  static const night100 = Color(0xFFE6E4FA);

  static const sun700 = Color(0xFFA8680F);
  static const sun500 = Color(0xFFF5B431);
  static const sun300 = Color(0xFFFFD479);
  static const sun100 = Color(0xFFFFF0CC);

  static const teal700 = Color(0xFF17706C);
  static const teal500 = Color(0xFF2FA59C);
  static const teal200 = Color(0xFFB6E6DF);
  static const teal100 = Color(0xFFE2F5F1);

  static const rose700 = Color(0xFFA93556);
  static const rose500 = Color(0xFFE26A89);
  static const rose300 = Color(0xFFF6A9BC);
  static const rose100 = Color(0xFFFCE3EA);

  /// The soft "try again" state. Replaces red everywhere.
  static const retry = Color(0xFFF7A94B);
  static const retryFill = Color(0xFFFFEBD0);
  static const retryText = Color(0xFF8A4B05);

  static const paper = Color(0xFFFFF8EA);
  static const sand = Color(0xFFF7E9CF);
  static const sand2 = Color(0xFFEBD5A8);
  static const ink = Color(0xFF26214F);
  static const ink2 = Color(0xFF5A5482);
}

abstract final class KidsType {
  static const display = 'ReemKufi';
  static const body = 'PlexArabic';
  static const letter = 'Amiri';

  static TextStyle title(double size, {Color color = KidsColors.ink}) => TextStyle(
    fontFamily: display,
    fontSize: size,
    height: 1.3,
    color: color,
    fontWeight: FontWeight.w700,
    fontVariations: const [FontVariation.weight(700)],
    // Reem Kufi's own word gap is too tight (design section 3).
    wordSpacing: size * 0.18,
  );

  static TextStyle bodyText(double size, {Color color = KidsColors.ink, FontWeight weight = FontWeight.w500}) =>
      TextStyle(fontFamily: body, fontSize: size, height: 1.5, color: color, fontWeight: weight);

  static TextStyle letterStyle(double size, {Color color = KidsColors.ink}) =>
      TextStyle(fontFamily: letter, fontSize: size, height: 1.3, color: color, fontWeight: FontWeight.w700);
}

/// Every target in the kids section is at least this big (design principle 4).
const double kKidsTarget = 64;
