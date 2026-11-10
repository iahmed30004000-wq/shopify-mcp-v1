import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';

/// A project's checklist progress.
@immutable
class ProjectProgress {
  const ProjectProgress(this.done, this.total);

  static const ProjectProgress empty = ProjectProgress(0, 0);

  factory ProjectProgress.of(Iterable<bool> doneFlags) {
    var d = 0, n = 0;
    for (final f in doneFlags) {
      n++;
      if (f) d++;
    }
    return ProjectProgress(d, n);
  }

  final int done;
  final int total;

  int get open => total - done;

  /// 0..1 (0 without items).
  double get fraction => total == 0 ? 0 : done / total;

  bool get complete => total > 0 && done == total;

  /// Whether toggling one item from [before] to this completed the list.
  bool reachedFullFrom(ProjectProgress before) => complete && !before.complete;

  @override
  bool operator ==(Object other) => other is ProjectProgress && other.done == done && other.total == total;

  @override
  int get hashCode => Object.hash(done, total);

  @override
  String toString() => 'ProjectProgress($done/$total)';
}

abstract final class ProjectRules {
  /// Planet a project feeds when none is chosen.
  static const String defaultPlanet = 'work';

  /// Lists order: active, then paused, then done; the user's order within.
  static int statusRank(ProjectStatus s) => switch (s) {
    ProjectStatus.active => 0,
    ProjectStatus.paused => 1,
    ProjectStatus.done => 2,
  };

  /// The planet a project's activity is logged on.
  static String planetOf(String? planetKey) {
    final k = planetKey?.trim();
    return k == null || k.isEmpty ? defaultPlanet : k;
  }
}
