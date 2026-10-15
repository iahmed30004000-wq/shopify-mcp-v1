import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/routing/life_route_pages.dart' show LifeRecordLinks;
import '../../../../core/routing/money_route_pages.dart' show MoneyNav;
import '../../../health/hub/health_hub_logic.dart';
import '../../../home/widgets/task_actions.dart';
import '../../../money/hub/money_links.dart';
import '../../domain/orbit_moons.dart';
import 'moon_sheet.dart';
import 'planet_modules.dart';

/// Opens the record a Neglect Radar entry or a reason points at: a moon's
/// sheet, a task's editor, a Health record's screen (doses past due →
/// today's doses, a slipping stress habit → the habits, an appointment, a
/// lab test – see [HealthRecordLinks]) or a Money record (an overdue debt or
/// bill → its sheet, a jar behind plan → the jar, an overspent budget item →
/// the budget's spending, stale entries → the ledger – see [MoneyLinks]) or
/// a life record (a project, a board, a person, a trip, a document, a
/// learning goal, the training plan, a tracker → its route – see
/// [LifeRecordLinks]). Other records with no screen of their own are not
/// openable – their rows are not buttons ([canOpen]).
abstract final class RecordOpener {
  /// Whether `refTable:refId` opens something from [planetKey]'s page (a
  /// Health reason about several medications has no [refId] and still
  /// opens today's doses).
  static bool canOpen(String? refTable, String? refId, List<OrbitMoon> moons, {String? planetKey}) {
    if (HealthRecordLinks.locationOf(refTable, refId, planetKey: planetKey) != null) return true;
    if (MoneyLinks.targetOf(refTable, refId) != null) return true;
    // Before the id check: a Body reason about the training plan has none.
    if (LifeRecordLinks.locationOf(refTable, refId) != null) return true;
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

  /// Where a Money record [item] (`refTable:refId`, or a bare `refTable`)
  /// leads, or null.
  static MoneyTarget? moneyTarget(String item) {
    final parsed = parse(item);
    if (parsed != null) return MoneyLinks.targetOf(parsed.$1, parsed.$2);
    return MoneyLinks.targetOf(item.contains(':') ? item.substring(0, item.indexOf(':')) : item, null);
  }

  /// The route of a life record [item] (`refTable:refId`, or a bare
  /// `refTable` for a reason with no single record – the training plan), or
  /// null ([LifeRecordLinks]).
  static String? lifeLocation(String item) {
    final parsed = parse(item);
    if (parsed != null) return LifeRecordLinks.locationOf(parsed.$1, parsed.$2);
    return LifeRecordLinks.locationOf(item.contains(':') ? item.substring(0, item.indexOf(':')) : item, null);
  }

  /// Splits an item id (`refTable:refId`).
  static (String, String)? parse(String item) {
    final i = item.indexOf(':');
    if (i <= 0 || i == item.length - 1) return null;
    return (item.substring(0, i), item.substring(i + 1));
  }

  /// Opens [item] (a moon of [moons] – its sheet –, a Health record of
  /// [planetKey]'s page or a life record – pushed as its route –, a Money
  /// record – its route or its sheet –, or a task – its editor); false when
  /// there is nothing to open.
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
    final money = moneyTarget(item);
    if (money != null) {
      unawaited(MoneyNav.open(context, money));
      return true;
    }
    final life = lifeLocation(item);
    if (life != null) {
      unawaited(context.push<void>(life));
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
