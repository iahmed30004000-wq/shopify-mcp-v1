import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notifications.dart';
import '../core/routing/routes.dart';
import '../features/fasting/fasting.dart'
    show FastingNotificationTaps, fastingBridgeProvider, fastingRegistrationProvider, fastingSyncProvider;

/// «تذكير الصيام»'s services, watched once by `AppServices` (inside the
/// database gate, outside the app lock), right after the notification centre
/// has loaded the owner's mutes into the one gate:
///
/// * [fastingRegistrationProvider] joins the centre (the Prayer group a
///   Faith mute holds, and the re-plan hook a restore calls);
/// * the next 21 days of reminders stay planned - re-planned at start, when
///   the day changes, when the Hijri shift, the location or the switches
///   change, and after a restore ([fastingSyncProvider]);
/// * «ناوي» and «لأ» answered while Madar runs are written on the app's own
///   database connection ([fastingBridgeProvider]; with the app closed the
///   background entry point writes the row itself).
void watchFastingServices(WidgetRef ref) {
  ref.watch(fastingRegistrationProvider);
  ref.watch(fastingSyncProvider);
  ref.watch(fastingBridgeProvider);
}

/// Where a tap on the **body** of a fasting notification leads: «صيامي».
/// Its two buttons are answered in the background and never open anything.
String? fastingNotificationLocation(NotificationTap tap) =>
    FastingNotificationTaps.opensFasting(tap) ? AppRoutes.fasting : null;
