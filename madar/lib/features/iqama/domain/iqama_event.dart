import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/settings/app_settings.dart' show DigitStyle;
import '../../adhan/domain/adhan_slot.dart';
import 'iqama_plan.dart';

/// The iqama notification's action ids. Both run **in the background**
/// (`opensApp: false`): answering from the shade never opens Madar, and
/// never has to pass the app lock.
abstract final class IqamaActions {
  /// «صلّيت» – log that prayer in the tracker.
  static const prayed = 'iqama.prayed';

  /// «بعد شوي» – the one snooze.
  static const later = 'iqama.later';
}

/// What an answer asks for.
enum IqamaAnswerKind { prayed, later }

/// An answer given on an iqama notification, as the background isolate and
/// the running app both see it.
@immutable
class IqamaAnswer {
  const IqamaAnswer({
    required this.slot,
    required this.day,
    required this.kind,
    required this.prayerAt,
    this.nextAdhanAt,
    this.snoozeMinutes = 5,
    this.snoozed = false,
    this.channelId,
    this.language = 'ar',
    this.digits = DigitStyle.auto,
  });

  final AdhanSlot slot;

  /// The prayer day (calendar date, UTC midnight – as the payload carries
  /// it).
  final DateTime day;
  final IqamaAnswerKind kind;
  final DateTime prayerAt;

  /// The next prayer's adhan; nothing is re-armed past it.
  final DateTime? nextAdhanAt;
  final int snoozeMinutes;

  /// The notification answered was already the one snooze (so «بعد شوي»
  /// is gone from it, and a second snooze is refused whatever arrives).
  final bool snoozed;

  /// The channel the notification came on, reused by the snooze (the
  /// background isolate cannot build a channel for a recording: only the
  /// app can read its content URI).
  final String? channelId;
  final String language;
  final DigitStyle digits;

  /// The obligatory prayer this answer logs.
  Prayer get prayer => slot.prayer!;

  /// The prayer day as the tracker stores it (local midnight).
  DateTime get localDay => DateTime(day.year, day.month, day.day);

  /// The alarm the one «بعد شوي» re-arms, at [at].
  IqamaAlarm asAlarm({required DateTime at}) => IqamaAlarm(
    id: IqamaIds.of(day, slot),
    slot: slot,
    at: at,
    prayerAt: prayerAt,
    day: day,
    minutes: 0,
    nextAdhanAt: nextAdhanAt,
  );

  @override
  String toString() => 'IqamaAnswer(${kind.name} ${slot.name} ${IqamaNotificationTaps.dayKey(day)})';
}

/// Reading an iqama notification's payload – the one place that knows the
/// payload's shape, shared by the planner, the app's tap routing, the
/// notification centre's describer and the background isolate.
abstract final class IqamaNotificationTaps {
  static const namespace = NotificationNamespaces.iqama;

  /// Payload fields: slot, prayer day, the adhan's instant, the next
  /// adhan's instant, the snooze length, whether this *is* the snooze, and
  /// the language / digit style it was written in.
  static const kSlot = 's',
      kDay = 'day',
      kPrayerAt = 'p',
      kNextAt = 'n',
      kSnoozeMinutes = 'z',
      kIsSnooze = 'sn',
      kLanguage = 'l',
      kDigits = 'g',
      kKind = 'k';

  /// A notice (already logged / not recorded), not an iqama itself.
  static const kindNotice = 'notice';

  static bool isIqama(NotificationTap tap) => tap.namespace == namespace.name;

  /// A tap on the body (the buttons are answered in the background).
  static bool opensIqama(NotificationTap tap) => isIqama(tap) && tap.actionId == null;

  static AdhanSlot? slotOf(NotificationTap tap) {
    if (!isIqama(tap)) return null;
    final slot = AdhanSlot.byName(tap.data[kSlot]);
    return slot != null && slot.isPrayer ? slot : null;
  }

  static DateTime? dayOf(NotificationTap tap) => parseDayKey(tap.data[kDay]);

  static DateTime? prayerAtOf(NotificationTap tap) {
    final p = tap.data[kPrayerAt];
    return p is int ? DateTime.fromMillisecondsSinceEpoch(p, isUtc: true) : null;
  }

  static bool isSnooze(NotificationTap tap) => tap.data[kIsSnooze] == 1 || tap.data[kIsSnooze] == true;

  static bool isNotice(NotificationTap tap) => tap.data[kKind] == kindNotice;

  /// The UI language / digit style the notification was written in (a
  /// follow-up is written the same way).
  static String languageOf(NotificationTap tap) => tap.data[kLanguage] == 'en' ? 'en' : 'ar';

  static DigitStyle digitsOf(NotificationTap tap) =>
      DigitStyle.values.where((d) => d.name == tap.data[kDigits]).firstOrNull ?? DigitStyle.auto;

  /// The answer an action button gives – null for a tap on the body, a
  /// notice, a malformed payload, a foreign notification, or a second
  /// «بعد شوي» on a notification that is already the snooze (one snooze,
  /// and no more).
  static IqamaAnswer? answerOf(NotificationTap tap) {
    if (!isIqama(tap) || isNotice(tap)) return null;
    final slot = slotOf(tap);
    final day = dayOf(tap);
    final prayerAt = prayerAtOf(tap);
    if (slot == null || day == null || prayerAt == null) return null;
    final kind = switch (tap.actionId) {
      IqamaActions.prayed => IqamaAnswerKind.prayed,
      IqamaActions.later => IqamaAnswerKind.later,
      _ => null,
    };
    if (kind == null) return null;
    final snoozed = isSnooze(tap);
    // The one snooze has already been taken.
    if (kind == IqamaAnswerKind.later && snoozed) return null;
    final n = tap.data[kNextAt];
    final z = tap.data[kSnoozeMinutes];
    return IqamaAnswer(
      slot: slot,
      day: day,
      kind: kind,
      prayerAt: prayerAt,
      nextAdhanAt: n is int ? DateTime.fromMillisecondsSinceEpoch(n, isUtc: true) : null,
      snoozeMinutes: z is int && z > 0 ? z : 5,
      snoozed: snoozed,
      channelId: tap.channelId,
      language: languageOf(tap),
      digits: digitsOf(tap),
    );
  }

  /// The payload data of [alarm].
  static Map<String, Object?> dataOf(
    IqamaAlarm alarm, {
    required int snoozeMinutes,
    required String language,
    required DigitStyle digits,
    bool snooze = false,
  }) => {
    kSlot: alarm.slot.name,
    kDay: dayKey(alarm.day),
    kPrayerAt: alarm.prayerAt.toUtc().millisecondsSinceEpoch,
    if (alarm.nextAdhanAt != null) kNextAt: alarm.nextAdhanAt!.toUtc().millisecondsSinceEpoch,
    kSnoozeMinutes: snoozeMinutes,
    if (snooze) kIsSnooze: 1,
    kLanguage: language == 'en' ? 'en' : 'ar',
    kDigits: digits.name,
  };

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? parseDayKey(Object? raw) {
    if (raw is! String) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (m == null) return null;
    return DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
}
