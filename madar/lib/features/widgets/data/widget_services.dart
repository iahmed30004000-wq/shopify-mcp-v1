import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/router.dart' show routerProvider;
import 'widget_platform.dart';
import 'widget_providers.dart';

/// Opens an app location for a widget tap: the app router (tests record
/// the location instead).
final widgetOpenLocationProvider = Provider<void Function(String location)>((ref) {
  return (location) => ref.read(routerProvider).go(location);
});

final widgetLaunchRouterProvider = Provider<WidgetLaunchRouter>((ref) {
  final router = WidgetLaunchRouter(ref, ref.watch(widgetOpenLocationProvider));
  ref.onDispose(router.dispose);
  return router;
});

/// The home-screen widgets' services, watched once by the unlocked app
/// (`AppServices.build`, inside the database gate – they read the encrypted
/// database – and outside the app lock):
///
/// * the widgets on the home screen are kept up to date
///   ([widgetSyncProvider]: data changes debounced, start, resume, midnight;
///   between app runs each widget moves on through its snapshot's pages by
///   itself – prayer times, midnight – and the periodic update redraws it);
/// * widget taps open their pages ([widgetLaunchRouterProvider]).
void watchWidgetServices(WidgetRef ref) {
  ref.watch(widgetSyncProvider);
  ref.watch(widgetLaunchRouterProvider);
}

/// "Delete all data": erases every widget's data and the widgets' key, and
/// turns the widgets back to "Open Madar". Works without the database and
/// without providers (the unlock screen's reset path); with a container
/// prefer `ref.read(widgetBridgeProvider).clearAll()`.
Future<void> clearWidgetData() => clearMadarWidgetData();
