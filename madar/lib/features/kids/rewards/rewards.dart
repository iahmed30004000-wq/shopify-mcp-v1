/// Rewards of «مدار الصغار»: the star count, the shelf of lanterns, and the
/// overrides that make every section's stars real and kept on the device.
library;

import 'package:flutter/material.dart';

import '../core/kids_section.dart';
import 'presentation/play_kit.dart' show KidsColors;
import 'presentation/rewards_screen.dart';

export 'application/rewards_providers.dart' show kidsRewardsOverrides;

/// «جوائزي».
final KidsSection rewardsSection = KidsSection(
  id: 'rewards',
  title: (l) => l.kidsPlayRewardsTitle,
  icon: Icons.emoji_events_rounded,
  accent: KidsColors.sun500,
  order: 80,
  builder: (context) => const RewardsScreen(),
);
