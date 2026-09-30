import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_envelope.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../adhan/application/adhan_providers.dart' show adhanEventProvider, adhanSyncProvider;
import '../../adhan/domain/adhan_event.dart' show AdhanActions, AdhanEvent;
import '../../health/meds/data/meds_notifications.dart' show MedsNotificationTaps;
import '../../health/meds/data/meds_providers.dart' show medsNotificationBridgeProvider, medsReminderSyncProvider;
import '../domain/center_models.dart';
import 'center_providers.dart';

// ---------------------------------------------------------------------------
// Actions: the notifications' own buttons, answered from the center

/// One inline action pressed in the center.
@immutable
class CenterActionRequest {
  const CenterActionRequest({required this.notice, required this.actionId, required this.now, this.live = false});

  final CenterNotice notice;

  /// The feature's action id (the same as the notification button's).
  final String actionId;
  final DateTime now;

  /// The notification is still in the tray.
  final bool live;

  /// The tap the feature's own handler expects from its button.
  NotificationTap get tap => notice.toTap(actionId: actionId);
}

/// Answers one action; true when the feature recorded it.
typedef CenterActionHandler = Future<bool> Function(CenterActionRequest request);

/// The handlers behind the center's inline actions, by action id. The
/// built-ins route through each feature's existing handler – exactly what
/// the notification's own button does:
///
/// * `meds.taken` / `meds.snooze` / `meds.skip` → the medication tracker's
///   recorder (`MedsNotificationBridge.record`: the dose log, the stock,
///   the re-plan, the refill alert);
/// * `adhan.stop` → cancels the sounding notification (its channel sound
///   stops) and closes the full-screen adhan if it shows that very call.
///
/// Features (or the lead) [register] more.
class NotificationActionHandlers {
  NotificationActionHandlers([Map<String, CenterActionHandler> handlers = const {}]) : _handlers = {...handlers};

  final Map<String, CenterActionHandler> _handlers;

  void register(String actionId, CenterActionHandler handler) => _handlers[actionId] = handler;

  CenterActionHandler? operator [](String actionId) => _handlers[actionId];

  bool handles(String actionId) => _handlers.containsKey(actionId);

  Iterable<String> get actionIds => _handlers.keys;
}

final notificationActionHandlersProvider = Provider<NotificationActionHandlers>((ref) {
  Future<bool> meds(CenterActionRequest r) async {
    final action = MedsNotificationTaps.actionOf(r.tap, now: r.now);
    if (action == null) return false;
    return ref.read(medsNotificationBridgeProvider).record(action);
  }

  Future<bool> stopAdhan(CenterActionRequest r) async {
    // Its sound stops with it (a notification of the id still to come stays).
    await removeShownNotice(ref, r.notice);
    final event = AdhanEvent.fromTap(r.tap);
    if (event != null && ref.exists(adhanEventProvider) && ref.read(adhanEventProvider)?.key == event.key) {
      ref.read(adhanEventProvider.notifier).dismiss();
    }
    return true;
  }

  return NotificationActionHandlers({
    MedsNotificationTaps.actionTaken: meds,
    MedsNotificationTaps.actionSnooze: meds,
    MedsNotificationTaps.actionSkip: meds,
    AdhanActions.stop: stopAdhan,
  });
});

/// Takes [notice] (shown) out of the tray and stops its sound – unless its
/// id has another firing pending, which a cancel would take along (the
/// platform cancels by id: the alarm and the shown notification together)
/// – one still to come, or one Doze holds past its moment: then it stays in
/// the tray. True when it was removed.
Future<bool> removeShownNotice(Ref ref, CenterNotice notice) async {
  final gate = ref.read(notificationGateProvider);
  if (gate.attached) return gate.removeShown(notice);
  try {
    final service = ref.read(notificationServiceProvider);
    final shown = notice.at?.millisecondsSinceEpoch;
    for (final p in await service.pendingNotices()) {
      if (p.id != notice.id) continue;
      final at = NotificationEnvelope.decode(p.payload).at;
      if (at == null || shown == null || at.millisecondsSinceEpoch != shown) return false;
    }
    await service.cancel(notice.id);
    return true;
  } catch (e) {
    debugPrint('NotificationCenter: removing ${notice.key} from the tray failed (${e.runtimeType})');
    return false;
  }
}

// ---------------------------------------------------------------------------
// Re-plans: a feature re-sends its own requests

/// Re-plans one feature's notifications now (its sync, as on a settings
/// change).
typedef NotificationReplan = Future<void> Function();

/// The feature re-plans the center asks for, by namespace name, when the
/// gate had to rebuild some of their requests from what the plugin
/// reported (after a restart the original request – its buttons, its
/// alarm-clock timing – is gone). Mute a group in a fresh run and undo it:
/// without a re-plan the adhan would come back without its Stop button
/// until its next scheduled re-plan (hours). Built in: the adhan and the
/// medication tracker, the two whose notifications carry buttons – each
/// only when its sync is already running (never started from here). The
/// lead [register]s others if wanted.
class NotificationReplanHooks {
  NotificationReplanHooks([Map<String, NotificationReplan> hooks = const {}]) : _hooks = {...hooks};

  final Map<String, NotificationReplan> _hooks;

  void register(String namespace, NotificationReplan replan) => _hooks[namespace] = replan;

  NotificationReplan? operator [](String namespace) => _hooks[namespace];

  Iterable<String> get namespaces => _hooks.keys;
}

final notificationReplanHooksProvider = Provider<NotificationReplanHooks>(
  (ref) => NotificationReplanHooks({
    NotificationNamespaces.adhan.name: () async {
      if (ref.exists(adhanSyncProvider)) await ref.read(adhanSyncProvider.notifier).syncNow();
    },
    NotificationNamespaces.meds.name: () async {
      if (ref.exists(medsReminderSyncProvider)) await ref.read(medsReminderSyncProvider.notifier).syncNow();
    },
  }),
);

// ---------------------------------------------------------------------------
// Links the lead wires: opening an item, a group's reminder settings

/// Opens what a notification is about. True when it went somewhere.
typedef CenterOpenLink = FutureOr<bool> Function(BuildContext context, NotificationTap tap);

/// Opens the reminder settings of [group] – of [notice] in particular when
/// given (a medication's, a document's …; `NotificationDescription.subject`
/// names it).
typedef CenterSettingsLink = FutureOr<void> Function(
  BuildContext context,
  NotificationGroup group,
  CenterNotice? notice,
);

/// The app-level navigation the center cannot know (routes live with the
/// app shell). Nothing is wired by default – the rows then offer no "Open"
/// and no "Reminder settings". The lead overrides
/// [notificationCenterLinksProvider], e.g.:
///
/// ```dart
/// notificationCenterLinksProvider.overrideWith((ref) => NotificationCenterLinks(
///   canOpen: (tap) => AppNotificationRouter.locationOf(tap) != null,
///   open: (context, tap) {
///     final location = AppNotificationRouter.locationOf(tap);
///     if (location == null) return false;
///     ref.read(routerProvider).go(location);
///     return true;
///   },
///   settings: {
///     NotificationGroup.prayer: (context, _, _) => context.push(AppRoutes.adhanSettings),
///     NotificationGroup.medications: (context, _, _) => MedsActions.openSettings(context, ref),
///     …
///   },
/// ));
/// ```
@immutable
class NotificationCenterLinks {
  const NotificationCenterLinks({this.open, this.canOpen, this.settings = const {}});

  final CenterOpenLink? open;

  /// Whether [open] leads anywhere for a tap (null: assume it does).
  final bool Function(NotificationTap tap)? canOpen;

  final Map<NotificationGroup, CenterSettingsLink> settings;

  bool opens(NotificationTap tap) => open != null && (canOpen?.call(tap) ?? true);

  bool hasSettings(NotificationGroup group) => settings.containsKey(group);
}

final notificationCenterLinksProvider = Provider<NotificationCenterLinks>((ref) => const NotificationCenterLinks());
