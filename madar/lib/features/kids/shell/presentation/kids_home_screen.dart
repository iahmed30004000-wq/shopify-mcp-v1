import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../core/kids_section.dart';
import '../application/kids_providers.dart';
import 'kids_palette.dart';

/// Screen 2: the planet of small worlds. Only what [visibleKidsSectionsProvider]
/// holds is shown (religious sections never, while their flag is false); with
/// nothing registered it shows a calm empty state. The lock button opens the
/// parent gate; everything else stays inside `/kids/**`.
class KidsHomeScreen extends ConsumerWidget {
  const KidsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final sections = ref.watch(visibleKidsSectionsProvider);
    final stars = ref.watch(kidsStarCountProvider);
    final time = ref.watch(kidsTimeProvider);
    final scale = MediaQuery.textScalerOf(context).scale(1);

    return Material(
      key: const ValueKey('kids-home'),
      color: KidsColors.paper,
      child: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [KidsColors.night800, KidsColors.night500, KidsColors.rose500, KidsColors.sun300],
                stops: [0, 0.45, 0.8, 1],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.kidsShellGreeting, style: KidsText.title(Colors.white, size: 34)),
                          Text(l.kidsShellGreetingSub, style: KidsText.text(KidsColors.night100, size: 18)),
                        ],
                      ),
                    ),
                    KidsRoundButton(
                      key: const ValueKey('kids-lock'),
                      icon: Icons.lock_rounded,
                      semanticLabel: l.kidsShellLockSemantics,
                      onPressed: ref.read(kidsParentPhaseProvider.notifier).openGate,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: sections.isEmpty
                ? const _Empty()
                : LayoutBuilder(
                    builder: (context, box) {
                      final columns = box.maxWidth < 330 ? 2 : 3;
                      return GridView.builder(
                        key: const ValueKey('kids-grid'),
                        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          // Tall enough for a 64-point medallion and two
                          // lines of title at any text scale.
                          mainAxisExtent: 112 + 62 * scale,
                        ),
                        itemCount: sections.length,
                        itemBuilder: (context, i) => _WorldTile(section: sections[i]),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _Chip(
                    key: const ValueKey('kids-stars-chip'),
                    background: KidsColors.night800,
                    foreground: Colors.white,
                    leading: const KhatamStar(size: 28, color: KidsColors.sun500),
                    label: kidsDigits(context, l.kidsShellStars(stars)),
                  ),
                  if (time.remainingMinutes case final minutes?)
                    _Chip(
                      key: const ValueKey('kids-time-chip'),
                      background: KidsColors.teal100,
                      foreground: KidsColors.teal700,
                      leading: const Icon(Icons.hourglass_bottom_rounded, color: KidsColors.teal700, size: 26),
                      label: kidsDigits(context, l.kidsShellTimeLeft(minutes)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldTile extends StatelessWidget {
  const _WorldTile({required this.section});

  final KidsSection section;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final title = section.title(l);
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: Material(
        key: ValueKey('kids-tile-${section.id}'),
        color: Color.alphaBlend(section.accent.withValues(alpha: 0.16), KidsColors.paper),
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => context.push(AppRoutes.kidsSectionOf(section.id)),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KhatamStar(
                  size: 72,
                  color: section.accent,
                  child: Icon(section.icon, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KidsText.title(KidsColors.ink, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.background, required this.foreground, required this.leading, required this.label});

  final Color background;
  final Color foreground;
  final Widget leading;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(36)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kKidsMinTarget),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 10),
            Flexible(
              child: Text(label, style: KidsText.text(foreground, size: 18, weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Center(
      key: const ValueKey('kids-empty'),
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KhatamStar(size: 120, color: KidsColors.sun300, child: Icon(Icons.star_rounded, color: Colors.white, size: 48)),
            const SizedBox(height: 16),
            Text(l.kidsShellEmptyTitle, textAlign: TextAlign.center, style: KidsText.title(KidsColors.ink, size: 28)),
            const SizedBox(height: 8),
            Text(l.kidsShellEmptyBody, textAlign: TextAlign.center, style: KidsText.text(KidsColors.ink2, size: 20)),
          ],
        ),
      ),
    );
  }
}
