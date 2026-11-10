// The seam every part of «مدار الصغار» plugs into.
//
// The kids section is built by several people at once, each in their own
// folder under lib/features/kids/, so nothing in one folder imports another:
// each folder exposes one or more [KidsSection]s, and the kids home (the shell)
// shows whatever the registry holds. The integrator lists the sections in one
// place at the end.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

/// One thing a child can open: a small world on the kids home.
@immutable
class KidsSection {
  const KidsSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.accent,
    required this.builder,
    this.order = 100,
    this.religious = false,
  });

  /// Stable, lower-case, unique ('letters', 'maths', 'colouring', ...).
  final String id;

  /// The name on its tile, in the child's language.
  final String Function(L10n l) title;

  final IconData icon;

  /// Its colour on the home (see docs/kids/DESIGN.md for the palette).
  final Color accent;

  /// The screen it opens. It runs INSIDE the kids shell: it must never push a
  /// route outside `/kids/**` and never reach another part of Madar.
  final WidgetBuilder builder;

  /// Where the tile sits on the home (lower first).
  final int order;

  /// Quran, prayer, wudu, the prophets' stories, manners, adhkar: anything
  /// religious. Hidden from the home (and unreachable) until the owner has
  /// named the sheikh who reviewed it and flipped
  /// [kidsReligiousUnlockedProvider]. The work is built and kept dark.
  final bool religious;
}

/// Everything the kids home may show. Empty by default; the integrator
/// overrides it with the real list.
final kidsSectionsProvider = Provider<List<KidsSection>>((ref) => const []);

/// The religious gate. **false** until the owner names the reviewing sheikh and
/// the content is signed off; the shell filters [KidsSection.religious] by it
/// and a test fails the build if any religious content is reachable while it
/// is false.
final kidsReligiousUnlockedProvider = Provider<bool>((ref) => false);

/// The sections a child can actually see right now, in order.
final visibleKidsSectionsProvider = Provider<List<KidsSection>>((ref) {
  final unlocked = ref.watch(kidsReligiousUnlockedProvider);
  final all = ref.watch(kidsSectionsProvider);
  return [
    for (final s in all)
      if (!s.religious || unlocked) s,
  ]..sort((a, b) => a.order.compareTo(b.order));
});

/// How many stars the child has collected (shown on the kids home). The rewards
/// folder overrides this with the real count; stars are only ever a collection:
/// they never lock content and are never taken away.
final kidsStarCountProvider = Provider<int>((ref) => 0);

/// Records one earned star (and why), so any section can reward a child without
/// knowing how rewards are stored. The rewards folder overrides it.
typedef KidsStarAward = Future<void> Function(String reason);

final kidsStarAwardProvider = Provider<KidsStarAward>((ref) => (reason) async {});
