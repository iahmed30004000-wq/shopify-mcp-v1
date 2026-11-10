import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notifications.dart';
import '../core/routing/routes.dart';
import '../features/ramadan/ramadan.dart'
    show RamadanNotificationTaps, ramadanBridgeProvider, ramadanRegistrationProvider, ramadanSyncProvider;

/// «رمضان»'s services, watched once by `AppServices` (inside the database
/// gate, outside the app lock), right after the notification centre has
/// loaded the owner's mutes into the one gate:
///
/// * [ramadanRegistrationProvider] joins the centre (the Prayer group a Faith
///   mute holds, and the re-plan hook a restore calls);
/// * the reminders of the current (or next) Ramadan stay planned - re-planned
///   at start, when the day changes, when the Hijri shift, the location or the
///   switches change, and after a restore ([ramadanSyncProvider]);
/// * «صلّيت» answered while Madar runs is written on the app's own database
///   connection ([ramadanBridgeProvider]; with the app closed the background
///   entry point writes the night itself).
void watchRamadanServices(WidgetRef ref) {
  ref.watch(ramadanRegistrationProvider);
  ref.watch(ramadanSyncProvider);
  ref.watch(ramadanBridgeProvider);
}

/// Where a tap on the **body** of a Ramadan notification leads: «رمضان».
/// Its button is answered in the background and never opens anything.
String? ramadanNotificationLocation(NotificationTap tap) =>
    RamadanNotificationTaps.opensRamadan(tap) ? AppRoutes.ramadan : null;
