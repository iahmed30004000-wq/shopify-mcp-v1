// «مدار الصغار», assembled: the one place that lists every section and wires
// the pieces the kids folders deliberately leave open (the real parent check,
// the rewards, the religious gate). The folders never import each other; this
// file imports them all.
//
// The five religious sections are listed here too, but each carries
// `religious: true`, so the kids home never shows them (and no route reaches
// them) until the owner names the reviewing sheikh and the content is signed
// off – see [kidsReligiousUnlockedProvider].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'colouring/colouring.dart' show colouringParentGateProvider, colouringSection;
import 'core/kids_section.dart';
import 'faith/faith.dart'
    show juzAmmaSection, kidsAdhkarSection, mannersSection, prayerWuduSection, storiesOfProphetsSection;
import 'games/games.dart' show gamesSection;
import 'learn/learn.dart' show lettersSection, mathsSection;
import 'rewards/rewards.dart' show kidsRewardsOverrides, rewardsSection;
import 'shell/kids_shell.dart' show kidsParentCheckProvider;
import 'stories/stories.dart' show interactiveStorySection, kidsParentAskProvider, voiceStoriesSection;

export 'core/kids_section.dart';
export 'shell/kids_shell.dart' show KidsEntryCard, kidsModeOnProvider, kidsRoutes;

/// Every section, in no particular order (each carries its own `order`).
final List<KidsSection> kidsAllSections = [
  lettersSection,
  mathsSection,
  colouringSection,
  voiceStoriesSection,
  interactiveStorySection,
  gamesSection,
  rewardsSection,
  juzAmmaSection,
  prayerWuduSection,
  storiesOfProphetsSection,
  mannersSection,
  kidsAdhkarSection,
];

/// «Are you the parent?» for the few things a child must not do alone
/// (recording a story, adding or deleting a picture): the shell shows the same
/// PIN / fingerprint gate as leaving, over whatever is open, and answers yes or
/// no without leaving kids mode.
Future<bool> kidsAskParent(Ref ref) => ref.read(kidsParentCheckProvider.notifier).ask();

/// Added once to the root provider scope (`madarAppOverrides`).
List<Override> kidsOverrides() => [
  kidsSectionsProvider.overrideWithValue(kidsAllSections),
  ...kidsRewardsOverrides,
  kidsParentAskProvider.overrideWith((ref) => () => kidsAskParent(ref)),
  colouringParentGateProvider.overrideWith((ref) => () => kidsAskParent(ref)),
];
