// What the kids shell lists from this folder: «الحروف» and «الحساب».
// The colouring section is in ../colouring/colouring.dart.
import 'package:flutter/material.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../core/kids_section.dart';
import 'letters/letters_screen.dart';
import 'maths/maths_screen.dart';
import 'ui/kids_tokens.dart';

export 'voice/kids_voice.dart' show KidsVoice, AssetKidsVoice, SilentKidsVoice, kidsVoiceProvider;

/// The Arabic letters: forms, example words, tracing, quiz.
final KidsSection lettersSection = KidsSection(
  id: 'letters',
  title: (L10n l) => l.kidsLettersTitle,
  icon: Icons.abc_rounded,
  accent: KidsColors.sun500,
  order: 40,
  builder: (context) => const LettersScreen(),
);

/// Multiplication, division and simple fractions for a nine-year-old.
final KidsSection mathsSection = KidsSection(
  id: 'maths',
  title: (L10n l) => l.kidsMathsTitle,
  icon: Icons.calculate_rounded,
  accent: KidsColors.teal500,
  order: 50,
  builder: (context) => const MathsScreen(),
);
