import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/sound/sound_api.dart';
import '../custom_texts.dart';
import '../data/custom_modules_providers.dart';
import 'custom_modules_navigation.dart';
import 'widgets/module_tile.dart';

/// The user's trackers and lists attached to [planetKey], compact, for any
/// planet hub: up to [maxModules] rows with their one-tap log, "See all",
/// and – when there are none – a gentle "create one for this planet".
class CustomModulesCard extends ConsumerWidget {
  const CustomModulesCard({
    super.key,
    required this.planetKey,
    this.maxModules = 4,
    this.onOpenModule,
    this.onSeeAll,
    this.showWhenEmpty = true,
  });

  final String planetKey;
  final int maxModules;

  /// Opens a module; default: [CustomModulesNavigation.openModule].
  final CustomOpenModule? onOpenModule;

  /// Opens all modules; default: [CustomModulesNavigation.openModules].
  final VoidCallback? onSeeAll;

  /// Without modules: show the "create" prompt (true) or nothing.
  final bool showWhenEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final modules = ref.watch(customPlanetModulesProvider(planetKey)).value;
    if (modules == null) return const SizedBox.shrink();
    if (modules.isEmpty) {
      if (!showWhenEmpty) return const SizedBox.shrink();
      return GlassCard(
        borderRadius: BorderRadius.circular(t.radiusL),
        padding: const EdgeInsets.all(Space.m),
        onTap: () {
          Fx.fire(Sfx.sheetOpen);
          unawaited(CustomModulesNavigation.startNew(context, planetKey: planetKey));
        },
        semanticLabel: '${l.cmodCardEmpty}. ${l.cmodCardEmptyHint}',
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.metalBrass.withValues(alpha: 0.6), width: 1.2),
                color: t.metalBrass.withValues(alpha: 0.08),
              ),
              child: Icon(Icons.add_rounded, color: t.metalBrass),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.cmodCardEmpty, style: text.titleSmall),
                  Text(l.cmodCardEmptyHint, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final shown = modules.take(maxModules).toList();
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: t.metalBrass),
              const SizedBox(width: Space.s),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.cmodCardTitle, style: text.titleSmall!.copyWith(color: t.metalBrass)),
                ),
              ),
              TextButton(
                onPressed: () {
                  final cb = onSeeAll;
                  if (cb != null) {
                    Fx.fire(Sfx.navigate);
                    cb();
                  } else {
                    unawaited(CustomModulesNavigation.openModules(context));
                  }
                },
                child: Text(
                  modules.length > shown.length ? '${l.cmodCardSeeAll} (${tx.count(modules.length)})' : l.cmodCardSeeAll,
                ),
              ),
            ],
          ),
          for (final s in shown) ...[
            ModuleTile(key: ValueKey(s.id), summary: s, compact: true, onOpenModule: onOpenModule),
            if (s != shown.last) const SizedBox(height: Space.s),
          ],
        ],
      ),
    );
  }
}
