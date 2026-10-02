import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import 'board_screen.dart';
import 'project_screen.dart';
import 'projects_screen.dart';
import 'work_screen.dart';

/// How the app routes between the Work screens (e.g. through go_router).
/// Null (the default) pushes them with [WorkNavigation].
abstract interface class WorkRoutes {
  void work(BuildContext context);
  void board(BuildContext context, String boardId);
  void projects(BuildContext context);
  void project(BuildContext context, String projectId);
}

final workRoutesProvider = Provider<WorkRoutes?>((ref) => null);

/// Default navigation between the Work screens when the host passes no
/// callback: pushes on the nearest navigator with the shared-axis
/// transition (the app router may route instead).
abstract final class WorkNavigation {
  static Route<void> _route(String name, Widget page) => PageRouteBuilder<void>(
    settings: RouteSettings(name: name),
    pageBuilder: (_, _, _) => page,
    transitionDuration: MadarMotion.medium,
    reverseTransitionDuration: MadarMotion.medium,
    transitionsBuilder: MadarTransitions.sharedAxisHorizontalTransitions,
  );

  static Future<void> _push(BuildContext context, String name, Widget page) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(_route(name, page));
  }

  static Future<void> openWork(BuildContext context) => _push(context, 'work', const WorkScreen());

  static Future<void> openBoard(BuildContext context, String boardId) =>
      _push(context, 'work/board', BoardScreen(boardId: boardId));

  static Future<void> openProjects(BuildContext context) => _push(context, 'work/projects', const ProjectsScreen());

  static Future<void> openProject(BuildContext context, String projectId) =>
      _push(context, 'work/project', ProjectScreen(projectId: projectId));

  /// Through [workRoutesProvider] when the app sets it, else pushed.
  static void toWork(BuildContext context, WidgetRef ref) =>
      _via(ref, (r) => r.work(context), () => openWork(context));

  static void toBoard(BuildContext context, WidgetRef ref, String boardId) =>
      _via(ref, (r) => r.board(context, boardId), () => openBoard(context, boardId));

  static void toProjects(BuildContext context, WidgetRef ref) =>
      _via(ref, (r) => r.projects(context), () => openProjects(context));

  static void toProject(BuildContext context, WidgetRef ref, String projectId) =>
      _via(ref, (r) => r.project(context, projectId), () => openProject(context, projectId));

  static void _via(WidgetRef ref, void Function(WorkRoutes r) routed, Future<void> Function() pushed) {
    final r = ref.read(workRoutesProvider);
    if (r == null) {
      pushed();
    } else {
      Fx.fire(Sfx.navigate);
      routed(r);
    }
  }
}
