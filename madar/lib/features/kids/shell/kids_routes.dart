import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion/transitions.dart';
import '../../../core/routing/routes.dart';
import '../core/kids_section.dart';
import 'presentation/kids_home_screen.dart';
import 'presentation/kids_palette.dart';
import 'presentation/kids_shell_frame.dart';

/// The kids shell's routes: ONE shell route (its own nested navigator) holding
/// the home and the sections. Nothing in here links outside `/kids/**`; a
/// section the child may not see (unknown, or religious while its flag is
/// false) redirects to the home, so a deep link cannot reach it.
List<RouteBase> kidsRoutes() => [
  ShellRoute(
    pageBuilder: (context, state, child) => MadarTransitions.fadeThrough<void>(
      context: context,
      key: state.pageKey,
      child: KidsShellFrame(child: child),
    ),
    routes: [
      GoRoute(
        path: AppRoutes.kids,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          name: state.uri.path,
          child: const KidsHomeScreen(),
        ),
        routes: [
          GoRoute(
            path: 's/:id',
            redirect: (context, state) {
              final id = state.pathParameters['id'];
              final container = ProviderScope.containerOf(
                context,
                listen: false,
              );
              final visible = container
                  .read(visibleKidsSectionsProvider)
                  .any((s) => s.id == id);
              return visible ? null : AppRoutes.kids;
            },
            pageBuilder: (context, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              name: state.uri.path,
              transitionDuration: const Duration(milliseconds: 220),
              transitionsBuilder: (context, animation, secondary, child) =>
                  FadeTransition(opacity: animation, child: child),
              child: _KidsSectionPage(id: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
  ),
];

class _KidsSectionPage extends ConsumerWidget {
  const _KidsSectionPage({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(visibleKidsSectionsProvider);
    final section = sections.where((s) => s.id == id).firstOrNull;
    if (section == null) {
      // The list changed under an open page (the flag flipped back): home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.kids);
      });
      return const SizedBox.shrink();
    }
    return Material(
      key: ValueKey('kids-section-$id'),
      color: KidsColors.paper,
      child: section.builder(context),
    );
  }
}
