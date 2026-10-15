import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notifications.dart';
import '../core/routing/routes.dart';
import '../features/iqama/iqama.dart' show IqamaNotificationTaps, iqamaBridgeProvider, iqamaSyncProvider;

/// «الإقامة»'s services, watched once by `AppServices` (inside the
/// database gate, outside the app lock):
///
/// * the next week of iqamas stays planned – re-planned whenever an offset,
///   a switch, the adhan settings, the location, the language or the day
///   changes, when the phone changes time zone and every six hours
///   ([iqamaSyncProvider]);
/// * «صلّيت» and «بعد شوي» answered while Madar runs – forwarded from the
///   background isolate over its port, or delivered through the taps
///   stream – are recorded on the app's own database connection, so the
///   tracker's lists and the Faith world update at once
///   ([iqamaBridgeProvider]; with the app closed the background entry
///   point writes the row itself).
void watchIqamaServices(WidgetRef ref) {
  ref.watch(iqamaSyncProvider);
  ref.watch(iqamaBridgeProvider);
}

/// Where a tap on the **body** of an iqama notification leads: the prayer
/// tracker, which is what it is about. Its two buttons are answered in the
/// background and never open anything.
String? iqamaNotificationLocation(NotificationTap tap) =>
    IqamaNotificationTaps.opensIqama(tap) ? AppRoutes.prayerTracker : null;
