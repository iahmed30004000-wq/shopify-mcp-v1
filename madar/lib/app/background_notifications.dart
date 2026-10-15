import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show NotificationResponse;

import '../core/db/database.dart' show MadarDatabase;
import '../core/db/repositories/repositories.dart' show KeyValueRepository, Repositories;
import '../core/notifications/notifications.dart';
import '../features/health/meds/meds.dart'
    show MedsNotificationTaps, openExistingMadarDatabase, runMedsBackgroundAction;
import '../features/iqama/iqama.dart' show IqamaNotificationTaps, runIqamaBackgroundAction;
import '../features/notification_center/notification_center.dart'
    show GatedNotificationPlatform, NotificationGate, loadStoredNotificationPolicy;

/// The app's background entry point for notification actions that never
/// open Madar: a dose's Taken / Snooze / Skip pressed in the shade, and
/// the iqama's «صلّيت» / «بعد شوي».
///
/// It is the medication tracker's own handler with one difference, and that
/// difference is the point: the re-plan runs **through a gate**
/// ([NotificationGate.background]) carrying the owner's stored mute and
/// skip policy, so answering a dose while "Medications" is muted no longer
/// re-arms the doses the mute holds back. The background gate never sweeps
/// (the app's own gate owns what is held) and never silences an immediate
/// notice, so the "your answer was not recorded" message always arrives.
///
/// The policy is loaded inside the isolate's own database, after it opens
/// and before the re-plan ([loadStoredNotificationPolicy]); a policy that
/// cannot be read holds nothing back, and an error there never keeps the
/// dose from being recorded.
///
/// It is passed to `FlutterLocalNotificationsPlatform(backgroundHandler:)`
/// in `suspendingFlowOverrides()`. The name differs from the core's
/// default `madarNotificationBackgroundTap` and from the tracker's own
/// `medsNotificationBackgroundTap` (which stays ungated, for tests and any
/// caller that is not the app) on purpose.
@pragma('vm:entry-point')
void madarAppNotificationBackgroundTap(NotificationResponse response) {
  final action = response.actionId;
  final tap = NotificationEnvelope.decode(
    response.payload,
    id: response.id,
    actionId: action == null || action.isEmpty ? null : action,
  );
  if (tap.actionId == null) return;
  final seams = madarBackgroundGateSeams(NotificationGate.background());
  if (MedsNotificationTaps.isMeds(tap)) {
    unawaited(runMedsBackgroundAction(tap, wrapPlatform: seams.wrapPlatform, beforeReplan: seams.beforeReplan));
    return;
  }
  // «صلّيت» writes the prayer log whatever the policy says; only the one
  // «بعد شوي» passes the gate (a Prayer mute must not be re-armed around).
  if (IqamaNotificationTaps.isIqama(tap)) {
    unawaited(
      runIqamaBackgroundAction(
        tap,
        wrapPlatform: seams.wrapPlatform,
        beforeSnooze: () => madarBackgroundPolicyInto(seams.beforeReplan),
      ),
    );
  }
}

/// The two seams [madarAppNotificationBackgroundTap] hands the medication
/// tracker, around [gate]: every platform call of that isolate goes through
/// the gate, and the stored policy is loaded into it before the re-plan.
///
/// A named helper, not a pair of closures inline, so the test of the
/// background behaviour runs the very composition production runs
/// (`test/features/health/meds/meds_background_gate_test.dart`).
@visibleForTesting
({
  NotificationPlatform Function(NotificationPlatform platform) wrapPlatform,
  Future<void> Function(KeyValueRepository keyValues) beforeReplan,
})
madarBackgroundGateSeams(NotificationGate gate) => (
  wrapPlatform: (platform) => GatedNotificationPlatform(platform, gate),
  beforeReplan: (keyValues) => loadStoredNotificationPolicy(gate, keyValues),
);

/// Loads the owner's stored mute and skip policy into a background gate
/// when the isolate has no database open of its own (the iqama's
/// «بعد شوي» needs none: everything it re-arms travels in the payload).
///
/// It opens the encrypted database, hands its `key_values` to [into] and
/// closes it again. Guarded end to end and never rethrows: a policy that
/// cannot be read holds nothing back, which is the safe direction – the
/// snooze is armed either way.
@visibleForTesting
Future<void> madarBackgroundPolicyInto(Future<void> Function(KeyValueRepository keyValues) into) async {
  MadarDatabase? db;
  try {
    db = await openExistingMadarDatabase();
    if (db == null) return;
    await into(Repositories(db).keyValues);
  } catch (e) {
    debugPrint('Madar: loading the stored notification policy in the background failed (${e.runtimeType})');
  } finally {
    try {
      await db?.close();
    } catch (_) {}
  }
}
