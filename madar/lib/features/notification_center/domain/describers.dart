import 'package:flutter/material.dart';

import '../../../core/interaction/actions.dart' show ActionTone;
import '../../../core/notifications/notification_models.dart' show NotificationNamespaces;
import 'center_models.dart';
import 'center_texts.dart';

/// An inline action of a center row that mirrors one of the notification's
/// own buttons (a dose's Taken / Snooze / Skip, the adhan's Stop). Its [id]
/// is the feature's action id, so the answer runs through the feature's
/// existing handler (`NotificationActionHandlers`).
@immutable
class CenterActionSpec {
  const CenterActionSpec({
    required this.id,
    required this.label,
    required this.icon,
    this.tone = ActionTone.accent,
    this.primary = false,
    this.whenUpcoming = false,
    this.liveOnly = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final ActionTone tone;

  /// The row's main answer (filled button).
  final bool primary;

  /// Also offered before the notification arrives (a dose can be taken
  /// early; a snooze cannot).
  final bool whenUpcoming;

  /// Only while the notification is still in the tray (the adhan's Stop
  /// silences a sounding notification – nothing to stop afterwards).
  final bool liveOnly;

  bool availableFor(CenterItem item) {
    if (item.state.isUpcoming) return whenUpcoming && item.state == CenterItemState.scheduled;
    if (liveOnly) return item.live;
    return item.state != CenterItemState.acted;
  }
}

/// How the center presents one notification: its group, a human title (in
/// the UI language, from the payload), its kind and icon, and the inline
/// actions mirroring its buttons.
@immutable
class NotificationDescription {
  const NotificationDescription({
    required this.group,
    required this.kind,
    required this.title,
    required this.icon,
    this.body,
    this.actions = const [],
    this.snoozable = true,
    this.subject,
  });

  final NotificationGroup group;

  /// What sort of notification it is ("Dose reminder", "Maghrib adhan").
  final String kind;

  /// The main line (usually the notification's own title).
  final String title;

  /// The second line (its body – times, amounts …).
  final String? body;
  final IconData icon;
  final List<CenterActionSpec> actions;

  /// The center may re-arm it later (false for the adhan, whose moment is
  /// the point, and for notifications with their own snooze button).
  final bool snoozable;

  /// A stable reference to what it is about (`meds:<medId>`,
  /// `travelDocument:<id>` …) for the lead's settings / open links.
  final String? subject;
}

/// Turns one feature's notifications into [NotificationDescription]s.
///
/// Features contribute describers to the [NotificationDescriberRegistry]
/// (`notificationDescribersProvider`); the built-ins cover every namespace
/// Madar has today (see `builtInDescribers`).
abstract class NotificationDescriber {
  const NotificationDescriber();

  /// Stable id: registering another describer with the same id replaces it.
  String get id;

  /// The group of [notice], or null when this describer does not know it.
  /// Pure and cheap – the notification gate calls it for every schedule.
  NotificationGroup? groupOf(CenterNotice notice);

  /// Describes a notice [groupOf] claimed.
  NotificationDescription describe(CenterNotice notice, CenterTexts t);
}

/// A describer made of two functions.
class FunctionDescriber extends NotificationDescriber {
  const FunctionDescriber({
    required this.id,
    required NotificationGroup? Function(CenterNotice notice) groupOf,
    required NotificationDescription Function(CenterNotice notice, CenterTexts t) describe,
  }) : _groupOf = groupOf,
       _describe = describe;

  @override
  final String id;
  final NotificationGroup? Function(CenterNotice notice) _groupOf;
  final NotificationDescription Function(CenterNotice notice, CenterTexts t) _describe;

  @override
  NotificationGroup? groupOf(CenterNotice notice) => _groupOf(notice);

  @override
  NotificationDescription describe(CenterNotice notice, CenterTexts t) => _describe(notice, t);
}

/// The describers the center consults, first match wins; anything no
/// describer claims falls back to [fallbackGroupOf] and the notification's
/// own title.
class NotificationDescriberRegistry {
  NotificationDescriberRegistry([Iterable<NotificationDescriber> describers = const []])
    : _describers = [...describers];

  final List<NotificationDescriber> _describers;

  List<NotificationDescriber> get describers => List.unmodifiable(_describers);

  /// Adds [describer] – ahead of the others by default, so a feature's own
  /// describer wins over a built-in one – replacing any with the same id.
  void register(NotificationDescriber describer, {bool first = true}) {
    _describers.removeWhere((d) => d.id == describer.id);
    first ? _describers.insert(0, describer) : _describers.add(describer);
  }

  void unregister(String id) => _describers.removeWhere((d) => d.id == id);

  NotificationDescriber? describerOf(CenterNotice notice) {
    for (final d in _describers) {
      try {
        if (d.groupOf(notice) != null) return d;
      } catch (e) {
        debugPrint('NotificationDescriber ${d.id} failed on ${notice.key}: $e');
      }
    }
    return null;
  }

  NotificationGroup groupOf(CenterNotice notice) {
    final d = describerOf(notice);
    return d?.groupOf(notice) ?? fallbackGroupOf(notice);
  }

  NotificationDescription describe(CenterNotice notice, CenterTexts t) {
    final d = describerOf(notice);
    if (d != null) {
      try {
        return d.describe(notice, t);
      } catch (e) {
        debugPrint('NotificationDescriber ${d.id} failed to describe ${notice.key}: $e');
      }
    }
    return fallbackDescription(notice, t, group: groupOf(notice));
  }

  /// The group of a notification only its namespace tells about.
  static NotificationGroup fallbackGroupOf(CenterNotice notice) => switch (notice.namespace) {
    final ns when ns == NotificationNamespaces.adhan.name => NotificationGroup.prayer,
    final ns when ns == NotificationNamespaces.adhkar.name => NotificationGroup.adhkar,
    final ns when ns == NotificationNamespaces.meds.name => NotificationGroup.medications,
    final ns when ns == NotificationNamespaces.health.name => NotificationGroup.health,
    final ns when ns == NotificationNamespaces.wird.name => NotificationGroup.wird,
    _ => NotificationGroup.other,
  };

  static NotificationDescription fallbackDescription(
    CenterNotice notice,
    CenterTexts t, {
    NotificationGroup? group,
  }) {
    final g = group ?? fallbackGroupOf(notice);
    return NotificationDescription(
      group: g,
      kind: t.group(g),
      title: notice.title ?? t.l.ncKindOther,
      body: notice.body,
      icon: groupIcon(g),
    );
  }
}

/// The icon of each group (rows fall back to it).
IconData groupIcon(NotificationGroup g) => switch (g) {
  NotificationGroup.prayer => Icons.mosque_rounded,
  NotificationGroup.adhkar => Icons.auto_awesome_rounded,
  NotificationGroup.medications => Icons.medication_rounded,
  NotificationGroup.health => Icons.healing_rounded,
  NotificationGroup.money => Icons.payments_rounded,
  NotificationGroup.family => Icons.family_restroom_rounded,
  NotificationGroup.travel => Icons.luggage_rounded,
  NotificationGroup.wird => Icons.menu_book_rounded,
  NotificationGroup.customModules => Icons.dashboard_customize_rounded,
  NotificationGroup.other => Icons.notifications_rounded,
};
