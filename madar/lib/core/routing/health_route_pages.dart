import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/health/meds/meds.dart' show MedsScreen, MedsTab;
import '../../features/health/record/record.dart'
    show AppointmentsScreen, LabTestScreen, RecordNavigation, RecordScreen, RecordTab;
import '../../features/health/wellbeing/wellbeing.dart'
    show BreathingPattern, BreathingScreen, WellbeingScreen, WellbeingTab;
import '../settings/app_settings.dart';
import 'routes.dart';

/// Adapters between the router and the Phase 4 health screens (the Health
/// world's hub, Settings › Health, notification taps): every health screen
/// is a route, so back, deep links and notification taps share one stack.
///
/// In-app links `push` (back returns to the Health page or wherever they
/// were opened); notification deep links `go` (see `AppNotificationRouter`).
abstract final class HealthNav {
  static void meds(BuildContext context, {MedsTab tab = MedsTab.today}) =>
      context.push(AppRoutes.medsOf(tab: tab.name));

  static void record(BuildContext context, {RecordTab tab = RecordTab.labs}) =>
      context.push(AppRoutes.recordOf(tab: tab.name));

  static void labTest(BuildContext context, String testId) => context.push(AppRoutes.labTestOf(testId));

  static void appointments(BuildContext context, {String? highlightId}) =>
      context.push(AppRoutes.appointmentsOf(highlightId: highlightId));

  static void wellbeing(BuildContext context, {WellbeingTab tab = WellbeingTab.today}) =>
      context.push(AppRoutes.wellbeingOf(tab: tab.name));

  static void breathing(BuildContext context, {String? pattern}) =>
      context.push(AppRoutes.breathingOf(pattern: pattern));

  static void settings(BuildContext context) => context.push(AppRoutes.healthSettings);
}

/// The record's own navigation, routed (installed app-wide through
/// `healthHookOverrides`): a lab test, the appointments and the record's
/// tabs open as routes instead of the package's fallback pushes.
class RoutedRecordNavigation extends RecordNavigation {
  const RoutedRecordNavigation();

  @override
  Future<void> openLabTest(BuildContext context, String testId) => context.push<void>(AppRoutes.labTestOf(testId));

  @override
  Future<void> openAppointments(BuildContext context, {String? highlightId}) =>
      context.push<void>(AppRoutes.appointmentsOf(highlightId: highlightId));

  @override
  Future<void> openRecord(BuildContext context, {RecordTab tab = RecordTab.labs}) =>
      context.push<void>(AppRoutes.recordOf(tab: tab.name));
}

/// Whether decorative backdrops rest (battery saver).
bool _saver(WidgetRef ref) => ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));

/// The enum value of [values] named [name], else [fallback] (pure).
T _named<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// `/meds[?tab=meds|courses]`.
class MedsRoutePage extends ConsumerWidget {
  const MedsRoutePage({super.key, this.tab = MedsTab.today});

  final MedsTab tab;

  static MedsTab tabOf(String? name) => _named(MedsTab.values, name, MedsTab.today);

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      MedsScreen(key: ValueKey('meds:${tab.name}'), initialTab: tab, animateBackdrop: !_saver(ref));
}

/// `/record[?tab=appointments|questions|conditions]`.
class RecordRoutePage extends ConsumerWidget {
  const RecordRoutePage({super.key, this.tab = RecordTab.labs});

  final RecordTab tab;

  static RecordTab tabOf(String? name) => _named(RecordTab.values, name, RecordTab.labs);

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      RecordScreen(key: ValueKey('record:${tab.name}'), initialTab: tab, animateBackdrop: !_saver(ref));
}

/// `/record/lab/:id` (an unknown test shows the screen's own "not found").
class LabTestRoutePage extends ConsumerWidget {
  const LabTestRoutePage({super.key, required this.testId});

  final String testId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      LabTestScreen(key: ValueKey('lab:$testId'), testId: testId, animateBackdrop: !_saver(ref));
}

/// `/record/appointments[?highlight=<id>]`.
class AppointmentsRoutePage extends ConsumerWidget {
  const AppointmentsRoutePage({super.key, this.highlightId});

  final String? highlightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppointmentsScreen(
    key: ValueKey('appointments:$highlightId'),
    highlightId: highlightId,
    animateBackdrop: !_saver(ref),
  );
}

/// `/wellbeing[?tab=pain|habits|worries|insights]`: guided breathing opens
/// as a route.
class WellbeingRoutePage extends ConsumerWidget {
  const WellbeingRoutePage({super.key, this.tab = WellbeingTab.today});

  final WellbeingTab tab;

  static WellbeingTab tabOf(String? name) => _named(WellbeingTab.values, name, WellbeingTab.today);

  @override
  Widget build(BuildContext context, WidgetRef ref) => WellbeingScreen(
    key: ValueKey('wellbeing:${tab.name}'),
    initialTab: tab,
    animateBackdrop: !_saver(ref),
    onBreathe: () => HealthNav.breathing(context),
  );
}

/// `/wellbeing/breathing[?pattern=478|box]`.
class BreathingRoutePage extends ConsumerWidget {
  const BreathingRoutePage({super.key, this.pattern});

  /// A known pattern id, or null (the user's last pattern).
  final String? pattern;

  /// The pattern named by the `pattern` query parameter, or null.
  static String? patternOf(String? id) {
    for (final p in BreathingPattern.all) {
      if (p.id == id) return p.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      BreathingScreen(key: ValueKey('breathing:$pattern'), pattern: pattern, animateBackdrop: !_saver(ref));
}
