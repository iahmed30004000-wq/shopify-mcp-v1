/// Stories of «مدار الصغار»: stories in the parent's own voice, and one
/// interactive story with voice and motion.
library;

import 'package:flutter/material.dart';

import '../core/kids_section.dart';
import '../rewards/presentation/play_kit.dart' show KidsColors;
import 'presentation/interactive_story_screen.dart';
import 'presentation/voice_stories_screen.dart';

export 'application/voice_providers.dart' show kidsParentAskProvider;

/// «حكايات بصوت الأهل»: the child listens; the parent records behind the gate.
final KidsSection voiceStoriesSection = KidsSection(
  id: 'voice_stories',
  title: (l) => l.kidsPlayVoiceTitle,
  icon: Icons.record_voice_over_rounded,
  accent: KidsColors.rose500,
  order: 40,
  builder: (context) => const VoiceStoriesScreen(),
);

/// «قصة تفاعلية»: «حكاية النجمة», with voice and motion.
final KidsSection interactiveStorySection = KidsSection(
  id: 'interactive_story',
  title: (l) => l.kidsPlayInteractiveTitle,
  icon: Icons.auto_awesome_rounded,
  accent: KidsColors.night500,
  order: 41,
  builder: (context) => const InteractiveStoryScreen(),
);
