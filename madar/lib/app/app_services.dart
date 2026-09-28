import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notifications.dart';
import '../core/routing/router.dart';
import '../core/settings/app_settings.dart';
import '../features/adhkar/adhkar.dart' show AdhkarReminderTaps, adhkarReminderSyncProvider;
import '../features/prayer/domain/time_zones.dart';

/// Prepares the services the app needs soon but never on the first frame:
/// the full time-zone database (prayer times of a location in another zone,
/// the adhan planner) and the notifications plugin, whose launch details
/// tell the adhan hub whether the app was opened by an adhan.
///
/// Called right after the first frame (see `bootstrap`); each step fails on
/// its own and only logs – without notifications Madar still runs, it just
/// cannot sound the adhan or remind.
Future<void> warmUpServices(ProviderContainer container) async {
  try {
    MadarTimeZones.ensure();
  } catch (e, s) {
    _log('time zones', e, s);
  }
  try {
    await container.read(notificationServiceProvider).init();
  } catch (e, s) {
    _log('notifications', e, s);
  }
}

void _log(String what, Object error, StackTrace stack) {
  if (kDebugMode) debugPrint('Madar warm-up ($what) failed: $error\n$stack');
}

/// Routes the taps on Madar's notifications that open a page of the app (the
/// adhan's own taps are the adhan hub's: it presents the full-screen adhan
/// above everything).
///
/// * An adhkar reminder opens its set in the reader
///   (`/adhkar/<set>`), whether it launched the app (cold start) or reached
///   it running (warm).
/// * The router moves underneath the app lock: when Madar is locked the lock
///   screen stays in front, and the reader is what the owner sees after
///   unlocking – a notification never reveals anything past the lock.
class AppNotificationRouter {
  AppNotificationRouter(this._ref) {
    final service = _ref.read(notificationServiceProvider);
    _taps = service.taps.listen(_onTap);
    unawaited(_readLaunch(service));
  }

  final Ref _ref;
  late final StreamSubscription<NotificationTap> _taps;

  /// Where [tap] leads, or null when it is not for the app shell.
  static String? locationOf(NotificationTap tap) {
    final set = AdhkarReminderTaps.categoryOf(tap);
    if (set != null) return AppRoutes.adhkarSetOf(set.name);
    return null;
  }

  Future<void> _readLaunch(NotificationService service) async {
    try {
      final tap = await service.takeLaunchTap(where: (t) => locationOf(t) != null);
      if (tap != null) _onTap(tap);
    } catch (e, s) {
      _log('launch notification', e, s);
    }
  }

  void _onTap(NotificationTap tap) {
    final location = locationOf(tap);
    if (location == null || !_ref.mounted) return;
    // Before onboarding nothing is scheduled; a stale tap must not skip it.
    if (!_ref.read(appSettingsProvider).onboarded) return;
    _ref.read(routerProvider).go(location);
  }

  void dispose() => unawaited(_taps.cancel());
}

final appNotificationRouterProvider = Provider<AppNotificationRouter>((ref) {
  final router = AppNotificationRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});

/// The unlocked app's background services, mounted once inside the database
/// gate (they read the encrypted database) and outside the app lock (they
/// run while it is locked):
///
/// * adhkar reminders stay planned (re-planned on settings, location,
///   language and day changes – [adhkarReminderSyncProvider]);
/// * notification taps open their pages ([AppNotificationRouter]).
///
/// The adhan's own services (alarm planning, prayer quiet, the full-screen
/// adhan) live in `AdhanHost`, directly below this.
class AppServices extends ConsumerWidget {
  const AppServices({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adhkarReminderSyncProvider);
    ref.watch(appNotificationRouterProvider);
    return child;
  }
}
