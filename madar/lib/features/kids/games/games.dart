/// Games of «مدار الصغار»: «أزواج النجوم», a calm memory-pairs game.
library;

import 'package:flutter/material.dart';

import '../core/kids_section.dart';
import '../rewards/presentation/play_kit.dart' show KidsColors;
import 'presentation/games_screen.dart';

/// «الألعاب».
final KidsSection gamesSection = KidsSection(
  id: 'games',
  title: (l) => l.kidsPlayGamesTitle,
  icon: Icons.extension_rounded,
  accent: KidsColors.teal500,
  order: 70,
  builder: (context) => const GamesScreen(),
);
