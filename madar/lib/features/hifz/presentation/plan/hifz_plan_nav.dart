/// «الحفظ» · how its screens open one another (Part 14, step 2).
///
/// Every hop goes through a provider, so the app pushes a real route (back
/// returns where he came from) and a test can record where a tap would
/// have led without building the whole router.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/quran/ayah.dart';
import '../../../../core/routing/routes.dart';
import '../../domain/hifz_daily_plan.dart';
import '../../domain/hifz_modes.dart';
import 'hifz_drill_screen.dart';

/// Which of «الحفظ»'s screens to open.
enum HifzPlanDestination {
  /// «الحفظ» – the morning screen.
  plan,

  /// «خريطة الصفحات».
  map,

  /// «أهدافي».
  goals,

  /// «شازام القرآن», typed.
  find,
}

String hifzPlanLocationOf(HifzPlanDestination to) => switch (to) {
  HifzPlanDestination.plan => AppRoutes.hifzPlan,
  HifzPlanDestination.map => AppRoutes.hifzMap,
  HifzPlanDestination.goals => AppRoutes.hifzGoals,
  HifzPlanDestination.find => AppRoutes.hifzFind,
};

typedef HifzPlanNavigator = void Function(BuildContext context, HifzPlanDestination to);

final hifzPlanNavigatorProvider = Provider<HifzPlanNavigator>(
  (ref) => (context, to) => unawaited(context.push<void>(hifzPlanLocationOf(to))),
);

/// Opens [to] from anywhere inside «الحفظ».
void hifzPlanGo(BuildContext context, WidgetRef ref, HifzPlanDestination to) =>
    ref.read(hifzPlanNavigatorProvider)(context, to);

/// What one drill is run on: a stretch of the mushaf, one method, and the
/// settings the plan chose for it.
@immutable
class HifzDrillRequest {
  const HifzDrillRequest({
    required this.range,
    required this.method,
    this.stage,
    this.seed = 0,
    this.repetitions = 3,
    this.track,
  });

  /// From a portion of today's plan, exactly as the plan sized it.
  factory HifzDrillRequest.ofPortion(HifzPortion portion, {HifzMethod? method}) => HifzDrillRequest(
    range: portion.range,
    method: method ?? portion.method,
    stage: portion.stage,
    seed: portion.seed,
    repetitions: portion.repetitions,
    track: portion.track,
  );

  final AyahRange range;
  final HifzMethod method;

  /// Where the hiding ladder starts (null: from the strength's own stage).
  final HidingStage? stage;

  /// The deterministic seed of a fill-in-the-blank drill.
  final int seed;
  final int repetitions;
  final HifzTrack? track;

  HifzDrillRequest withMethod(HifzMethod m) => HifzDrillRequest(
    range: range,
    method: m,
    stage: stage,
    seed: seed,
    repetitions: repetitions,
    track: track,
  );

  @override
  String toString() => 'HifzDrillRequest($range, ${method.name})';
}

/// How a drill opens. The default pushes it on the nearest navigator, so
/// «رجوع» lands back on the morning screen.
typedef HifzDrillNavigator = void Function(BuildContext context, HifzDrillRequest request);

final hifzDrillNavigatorProvider = Provider<HifzDrillNavigator>(
  (ref) => (context, request) => unawaited(
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        settings: RouteSettings(name: 'hifz/drill/${request.method.name}'),
        pageBuilder: (_, _, _) => HifzDrillScreen(request: request),
      ),
    ),
  ),
);

/// Starts [request]'s drill.
void hifzStartDrill(BuildContext context, WidgetRef ref, HifzDrillRequest request) =>
    ref.read(hifzDrillNavigatorProvider)(context, request);

/// How an ayah opens in the mushaf (a search hit, a «شازام» result).
typedef HifzAyahNavigator = void Function(BuildContext context, AyahRef ayah);

final hifzAyahNavigatorProvider = Provider<HifzAyahNavigator>(
  (ref) => (context, ayah) => unawaited(context.push<void>(AppRoutes.quranReaderOf(ayah: ayah))),
);

void hifzOpenAyah(BuildContext context, WidgetRef ref, AyahRef ayah) =>
    ref.read(hifzAyahNavigatorProvider)(context, ayah);
