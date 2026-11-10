import 'package:flutter/material.dart';

import '../../../core/notifications/notification_models.dart' show NotificationNamespaces;
import '../../notification_center/domain/center_models.dart';
import '../../notification_center/domain/center_texts.dart';
import '../../notification_center/domain/describers.dart';

/// «تذكير الصيام» in the notification centre: the **Prayer** group, which is
/// what a Faith mute means in the centre (it already holds the adhan and the
/// iqama), so one mute of that group silences the fasting reminders with
/// them - and un-muting brings them back.
///
/// Registered by `watchFastingServices` (it is a feature's own describer, not
/// a built-in), ahead of the built-ins, before the first plan is sent to the
/// gate.
class FastingDescriber extends NotificationDescriber {
  const FastingDescriber();

  static const String describerId = 'fasting.reminders';

  @override
  String get id => describerId;

  @override
  NotificationGroup? groupOf(CenterNotice n) =>
      n.namespace == NotificationNamespaces.fasting.name ? NotificationGroup.prayer : null;

  @override
  NotificationDescription describe(CenterNotice n, CenterTexts t) {
    final l = t.l;
    return NotificationDescription(
      group: NotificationGroup.prayer,
      kind: l.fastRemTitle,
      title: n.title ?? l.fastRemTitle,
      body: n.body,
      icon: Icons.nightlight_round,
      // It comes again at its own time, and its buttons answer it.
      snoozable: false,
      subject: 'fasting',
    );
  }
}
