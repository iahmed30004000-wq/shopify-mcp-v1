import 'package:flutter/widgets.dart';

import '../../../core/i18n/gen/app_localizations.dart';
import '../domain/guide_entry.dart';
import '../domain/guide_samples.dart';
import '../domain/guide_seen_store.dart';

/// Gives the screens below it the guide: the registry, how to read its text
/// in the current language, and the "already seen" store. The app puts one
/// above the router.
class GuideScope extends InheritedWidget {
  const GuideScope({super.key, required this.registry, required this.resolverFor, required this.store, required super.child});

  /// Only the three sample entries, in memory: previews and tests.
  GuideScope.samples({super.key, GuideSeenStore? store, required super.child})
    : registry = GuideSamples.registry(),
      resolverFor = _sampleResolver,
      store = store ?? MemoryGuideSeenStore();

  final GuideRegistry registry;

  /// Builds the text resolver for the language of the given context.
  final GuideTextResolver Function(BuildContext context) resolverFor;
  final GuideSeenStore store;

  static GuideTextResolver _sampleResolver(BuildContext c) => guideResolverFor(L10n.of(c));

  static GuideScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<GuideScope>();

  static GuideScope of(BuildContext context) {
    final s = maybeOf(context);
    assert(s != null, 'No GuideScope above this context');
    return s!;
  }

  /// The entry [id] in the current language.
  GuideEntry? entry(BuildContext context, String id) => registry.entry(id, resolverFor(context));

  @override
  bool updateShouldNotify(GuideScope old) =>
      old.registry != registry || old.store != store || old.resolverFor != resolverFor;
}
