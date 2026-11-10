// The kids faith folder's public face: five [KidsSection]s, ALL religious.
//
// None of them is ever shown while `kidsReligiousUnlockedProvider` is false
// (the owner has not named the reviewing sheikh yet), and each screen also
// checks the gate and the per-item sign-off itself. The integrator lists
// these in `kidsSectionsProvider`; nothing here reaches outside /kids/**.
import 'package:flutter/material.dart';

import '../core/kids_section.dart';
import 'presentation/kids_adhkar_screen.dart';
import 'presentation/kids_juz_amma_screen.dart';
import 'presentation/kids_steps_screen.dart';
import 'presentation/kids_stories_screen.dart';

export 'application/faith_providers.dart' show kidsReligiousBundleProvider, kidsAyahAudioProvider;
export 'data/kids_audio.dart' show KidsAyahAudio, LocalOnlyKidsAudio;
export 'domain/juz_amma_config.dart' show kidsJuzAmmaSurahsProvider;
export 'domain/recitation_check.dart' show KidsRecitationChecker, KidsRecitationResult, kidsRecitationCheckerProvider;

final KidsSection juzAmmaSection = KidsSection(
  id: 'juz_amma',
  title: (l) => l.kidsFaithJuzAmmaTitle,
  icon: Icons.menu_book_rounded,
  accent: const Color(0xFF2FA59C),
  builder: (_) => const JuzAmmaScreen(),
  order: 30,
  religious: true,
);

final KidsSection prayerWuduSection = KidsSection(
  id: 'prayer_wudu',
  title: (l) => l.kidsFaithPrayerWuduTitle,
  icon: Icons.water_drop_rounded,
  accent: const Color(0xFF17706C),
  builder: (_) => const PrayerWuduScreen(),
  order: 31,
  religious: true,
);

final KidsSection storiesOfProphetsSection = KidsSection(
  id: 'prophet_stories',
  title: (l) => l.kidsFaithStoriesTitle,
  icon: Icons.auto_stories_rounded,
  accent: const Color(0xFF2F2A78),
  builder: (_) => const StoriesScreen(),
  order: 32,
  religious: true,
);

final KidsSection mannersSection = KidsSection(
  id: 'manners',
  title: (l) => l.kidsFaithMannersTitle,
  icon: Icons.favorite_rounded,
  accent: const Color(0xFFE26A89),
  builder: (_) => const MannersScreen(),
  order: 33,
  religious: true,
);

final KidsSection kidsAdhkarSection = KidsSection(
  id: 'kids_adhkar',
  title: (l) => l.kidsFaithAdhkarTitle,
  icon: Icons.brightness_5_rounded,
  accent: const Color(0xFFF5B431),
  builder: (_) => const KidsAdhkarScreen(),
  order: 34,
  religious: true,
);
