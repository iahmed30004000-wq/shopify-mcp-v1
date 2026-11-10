import 'package:flutter/material.dart';

import '../../../core/notifications/notification_models.dart' show NotificationNamespaces;
import '../../notification_center/domain/center_models.dart';
import '../../notification_center/domain/center_texts.dart';
import '../../notification_center/domain/describers.dart';

/// «رمضان» in the notification centre: the **Prayer** group, which is what a
/// Faith mute means in the centre (it already holds the adhan, the iqama and
/// the fasting reminders), so one mute of that group silences Ramadan's
/// reminders with them - and un-muting brings them back.
///
/// Registered by `ramadanRegistrationProvider`, ahead of the built-ins,
/// before the first plan is sent to the gate.
class RamadanDescriber extends NotificationDescriber {
  const RamadanDescriber();

  static const String describerId = 'ramadan.reminders';

  @override
  String get id => describerId;

  @override
  NotificationGroup? groupOf(CenterNotice n) =>
      n.namespace == NotificationNamespaces.ramadan.name ? NotificationGroup.prayer : null;

  @override
  NotificationDescription describe(CenterNotice n, CenterTexts t) {
    final l = t.l;
    return NotificationDescription(
      group: NotificationGroup.prayer,
      kind: l.ramadanTitle,
      title: n.title ?? l.ramadanTitle,
      body: n.body,
      icon: Icons.mosque_rounded,
      // It comes again at its own time, and its button answers it.
      snoozable: false,
      subject: 'ramadan',
    );
  }
}
