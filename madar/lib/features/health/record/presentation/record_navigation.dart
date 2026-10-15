import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/motion_kit.dart';
import 'appointments_screen.dart';
import 'lab_test_screen.dart';
import 'record_screen.dart';

/// How the record opens its own screens. The default pushes them with the
/// shared-axis transition; the app may override [recordNavigationProvider]
/// to route them through go_router instead.
class RecordNavigation {
  const RecordNavigation();

  Future<void> _push(BuildContext context, Widget child) =>
      Navigator.of(context)
          .push<void>(MadarTransitions.sharedAxis<void>(context: context, child: child).createRoute(context));

  Future<void> openLabTest(BuildContext context, String testId) => _push(context, LabTestScreen(testId: testId));

  Future<void> openAppointments(BuildContext context, {String? highlightId}) =>
      _push(context, AppointmentsScreen(highlightId: highlightId));

  Future<void> openRecord(BuildContext context, {RecordTab tab = RecordTab.labs}) =>
      _push(context, RecordScreen(initialTab: tab));
}

final recordNavigationProvider = Provider<RecordNavigation>((ref) => const RecordNavigation());
