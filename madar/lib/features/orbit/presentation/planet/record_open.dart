import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/repositories/repositories.dart';
import '../../../home/widgets/task_actions.dart';
import '../../domain/orbit_moons.dart';
import 'moon_sheet.dart';
import 'planet_modules.dart';

/// Opens the record a Neglect Radar entry or a reason points at: a moon's
/// sheet, or a task's editor. Records with no sheet of their own (a
/// medication, a habit, a budget line …) are not openable – their rows are
/// not buttons ([canOpen]).
abstract final class RecordOpener {
  /// Whether `refTable:refId` opens something from a world's page.
  static bool canOpen(String? refTable, String? refId, List<OrbitMoon> moons) {
    if (refTable == null || refId == null) return false;
    return moonOf(PlanetModules.itemOf(refTable, refId), moons) != null || refTable == 'tasks';
  }

  /// The moon whose item id is [item].
  static OrbitMoon? moonOf(String item, List<OrbitMoon> moons) {
    for (final m in moons) {
      if (m.id == item) return m;
    }
    return null;
  }

  /// Splits an item id (`refTable:refId`).
  static (String, String)? parse(String item) {
    final i = item.indexOf(':');
    if (i <= 0 || i == item.length - 1) return null;
    return (item.substring(0, i), item.substring(i + 1));
  }

  /// Opens [item] (a moon of [moons] or a task); false when there is
  /// nothing to open.
  static Future<bool> open(BuildContext context, WidgetRef ref, String item, List<OrbitMoon> moons) async {
    final moon = moonOf(item, moons);
    if (moon != null) {
      unawaited(showMoonSheet(context, ref, moon));
      return true;
    }
    final parsed = parse(item);
    if (parsed == null || parsed.$1 != 'tasks') return false;
    final task = await ref.read(repositoriesProvider).tasks.byId(parsed.$2);
    if (task == null || !context.mounted) return false;
    unawaited(TaskActions(ref, context).edit(task));
    return true;
  }
}
