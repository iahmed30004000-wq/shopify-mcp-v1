import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/repositories/repositories.dart';
import '../../../health/hub/health_hub_logic.dart';
import '../../../home/widgets/task_actions.dart';
import '../../domain/orbit_moons.dart';
import 'moon_sheet.dart';
import 'planet_modules.dart';

/// Opens the record a Neglect Radar entry or a reason points at: a moon's
/// sheet, a task's editor, or a Health record's screen (doses past due →
/// today's doses, a slipping stress habit → the habits, an appointment, a
/// lab test – see [HealthRecordLinks]). Other records with no sheet of
/// their own (a budget line, a debt …) are not openable – their rows are not
/// buttons ([canOpen]).
abstract final class RecordOpener {
  /// Whether `refTable:refId` opens something from [planetKey]'s page (a
  /// Health reason about several medications has no [refId] and still
  /// opens today's doses).
  static bool canOpen(String? refTable, String? refId, List<OrbitMoon> moons, {String? planetKey}) {
    if (HealthRecordLinks.locationOf(refTable, refId, planetKey: planetKey) != null) return true;
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

  /// The route of a Health record [item] (`refTable:refId`, or a bare
  /// `refTable` for a reason about several records), or null.
  static String? healthLocation(String item, {String? planetKey}) {
    final parsed = parse(item);
    final table = parsed?.$1 ?? (item.contains(':') ? item.substring(0, item.indexOf(':')) : item);
    return HealthRecordLinks.locationOf(table, parsed?.$2, planetKey: planetKey);
  }

  /// Splits an item id (`refTable:refId`).
  static (String, String)? parse(String item) {
    final i = item.indexOf(':');
    if (i <= 0 || i == item.length - 1) return null;
    return (item.substring(0, i), item.substring(i + 1));
  }

  /// Opens [item] (a moon of [moons], a task, or a Health record of
  /// [planetKey]'s page – pushed as its route); false when there is nothing
  /// to open.
  static Future<bool> open(
    BuildContext context,
    WidgetRef ref,
    String item,
    List<OrbitMoon> moons, {
    String? planetKey,
  }) async {
    final moon = moonOf(item, moons);
    if (moon != null) {
      unawaited(showMoonSheet(context, ref, moon));
      return true;
    }
    final health = healthLocation(item, planetKey: planetKey);
    if (health != null) {
      unawaited(context.push<void>(health));
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
