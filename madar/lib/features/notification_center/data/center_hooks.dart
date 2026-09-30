import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../adhan/application/adhan_providers.dart' show adhanEventProvider;
import '../../adhan/domain/adhan_event.dart' show AdhanActions, AdhanEvent;
import '../../health/meds/data/meds_notifications.dart' show MedsNotificationTaps;
import '../../health/meds/data/meds_providers.dart' show medsNotificationBridgeProvider;
import '../domain/center_models.dart';

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
    await ref.read(notificationServiceProvider).cancel(r.notice.id);
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
