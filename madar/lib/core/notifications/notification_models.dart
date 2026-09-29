import 'package:flutter/foundation.dart';

/// How loudly / prominently a channel interrupts.
enum NotificationImportance {
  /// Shade only, no sound.
  low,

  /// Sound, no heads-up.
  normal,

  /// Sound + heads-up.
  high,

  /// Sound + heads-up + may launch a full-screen intent (alarms, adhan).
  urgent,
}

/// Which audio stream a channel's sound plays on. [alarm] follows the alarm
/// volume and keeps sounding in silent mode and (by default) in Do Not
/// Disturb, like an alarm clock.
enum NotificationAudioUsage { notification, alarm }

/// Android's notification category – how the system ranks and filters it.
enum NotificationCategory { alarm, reminder, event, status }

/// How precisely a scheduled notification fires.
enum NotificationTiming {
  /// `AlarmManager.setAlarmClock`: exact, wakes the device from Doze,
  /// unaffected by battery saver and app standby, shows the alarm icon. For
  /// the adhan.
  alarmClock,

  /// `setExactAndAllowWhileIdle`: exact, fires in Doze but rate-limited
  /// there (about one per 9 minutes per app).
  exactWhileIdle,

  /// `setAndAllowWhileIdle`: may drift by minutes; no exact-alarm permission
  /// needed. The fallback when exact alarms are not permitted.
  inexactWhileIdle,
}

/// The sound a channel plays. Fixed at channel creation on Android 8+.
@immutable
class NotificationSoundSpec {
  const NotificationSoundSpec._(this.kind, this.value);

  /// The system's default notification sound.
  const NotificationSoundSpec.systemDefault() : this._(NotificationSoundKind.systemDefault, null);

  /// No sound at all.
  const NotificationSoundSpec.silent() : this._(NotificationSoundKind.silent, null);

  /// A file in `android/app/src/main/res/raw/` ([name] without extension).
  const NotificationSoundSpec.raw(String name) : this._(NotificationSoundKind.raw, name);

  /// Any URI the system can read (e.g. a `content://` URI of Madar's sound
  /// provider).
  const NotificationSoundSpec.uri(String uri) : this._(NotificationSoundKind.uri, uri);

  final NotificationSoundKind kind;
  final String? value;

  String get signature => value == null ? kind.name : '${kind.name}:$value';

  @override
  bool operator ==(Object other) => other is NotificationSoundSpec && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => 'NotificationSoundSpec($signature)';
}

enum NotificationSoundKind { systemDefault, silent, raw, uri }

/// An Android notification channel. Sound, vibration and audio usage are
/// frozen when the channel is first created, so a different sound needs a
/// different channel [id] (see [signature]).
@immutable
class NotificationChannelSpec {
  const NotificationChannelSpec({
    required this.id,
    required this.name,
    this.description,
    this.importance = NotificationImportance.high,
    this.sound = const NotificationSoundSpec.systemDefault(),
    this.vibrate = true,
    this.vibrationPattern,
    this.usage = NotificationAudioUsage.notification,
    this.showBadge = true,
    this.groupId,
  });

  final String id;

  /// User-visible (system settings › notifications). Can be renamed later.
  final String name;
  final String? description;
  final NotificationImportance importance;
  final NotificationSoundSpec sound;
  final bool vibrate;

  /// Milliseconds: off, on, off, on…
  final List<int>? vibrationPattern;
  final NotificationAudioUsage usage;
  final bool showBadge;
  final String? groupId;

  /// The properties Android freezes at creation.
  String get signature =>
      '${importance.name}|${sound.signature}|${vibrate ? 'v' : '-'}|${vibrationPattern?.join(',') ?? ''}|${usage.name}';

  @override
  bool operator ==(Object other) =>
      other is NotificationChannelSpec &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.signature == signature &&
      other.showBadge == showBadge &&
      other.groupId == groupId;

  @override
  int get hashCode => Object.hash(id, name, description, signature, showBadge, groupId);
}

/// A button on a notification. With [opensApp] false it runs in the
/// background (the notification is dismissed when [cancels] – which also
/// stops its sound).
@immutable
class NotificationActionSpec {
  const NotificationActionSpec({required this.id, required this.title, this.cancels = true, this.opensApp = false});

  final String id;
  final String title;
  final bool cancels;
  final bool opensApp;

  String get signature => '$id:$title:${cancels ? 1 : 0}${opensApp ? 1 : 0}';
}

/// A contiguous block of notification ids owned by one feature, so features
/// never overwrite each other's alarms and a feature can reconcile exactly
/// its own pending notifications.
@immutable
class NotificationNamespace {
  const NotificationNamespace(this.name, this.first, this.last) : assert(first <= last);

  final String name;
  final int first;
  final int last;

  int get size => last - first + 1;

  bool contains(int id) => id >= first && id <= last;

  /// The id at [offset] inside the block.
  int id(int offset) {
    if (offset < 0 || offset >= size) throw RangeError.range(offset, 0, size - 1, 'offset');
    return first + offset;
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationNamespace && other.name == name && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(name, first, last);

  @override
  String toString() => 'NotificationNamespace($name, $first–$last)';
}

/// The id blocks of every Madar feature. Add new features here (never
/// overlap; android ids are 32-bit ints).
abstract final class NotificationNamespaces {
  static const adhan = NotificationNamespace('adhan', 100000, 101999);
  static const adhkar = NotificationNamespace('adhkar', 110000, 111999);
  static const meds = NotificationNamespace('meds', 120000, 129999);
  static const reminders = NotificationNamespace('reminders', 130000, 139999);

  /// The daily wird's reminders (after the plan's prayer).
  static const wird = NotificationNamespace('wird', 140000, 140999);

  static const all = [adhan, adhkar, meds, reminders, wird];

  static NotificationNamespace? byName(String name) {
    for (final ns in all) {
      if (ns.name == name) return ns;
    }
    return null;
  }

  static NotificationNamespace? owning(int id) {
    for (final ns in all) {
      if (ns.contains(id)) return ns;
    }
    return null;
  }
}

/// One notification to show now or at [at].
@immutable
class NotificationRequest {
  const NotificationRequest({
    required this.namespace,
    required this.id,
    required this.channelId,
    required this.title,
    required this.body,
    required this.at,
    this.data = const {},
    this.category = NotificationCategory.reminder,
    this.timing = NotificationTiming.exactWhileIdle,
    this.fullScreen = false,
    this.publicOnLockScreen = false,
    this.timeout,
    this.dropIfLateBy,
    this.actions = const [],
    this.ongoing = false,
    this.autoCancel = true,
    this.colorArgb,
    this.subText,
  });

  final NotificationNamespace namespace;
  final int id;
  final String channelId;
  final String title;
  final String body;

  /// When it fires (an instant; time zones do not move it).
  final DateTime at;

  /// Feature data handed back on tap (JSON-encodable values).
  final Map<String, Object?> data;
  final NotificationCategory category;
  final NotificationTiming timing;

  /// Launch Madar full-screen (over the lock screen) when it fires.
  final bool fullScreen;

  /// Show the full content on the lock screen.
  final bool publicOnLockScreen;

  /// Removed automatically (sound included) after this long.
  final Duration? timeout;

  /// After a reboot the alarm is restored only while it is at most this late
  /// (a Fajr adhan must not sound at 9:00 because the phone was off at dawn).
  /// `null` = always restore (the plugin's default behaviour).
  final Duration? dropIfLateBy;
  final List<NotificationActionSpec> actions;
  final bool ongoing;
  final bool autoCancel;
  final int? colorArgb;
  final String? subText;

  /// Everything that changes what the user sees or hears – part of the
  /// payload envelope so a changed request is re-scheduled and an unchanged
  /// one is left alone.
  String get contentSignature => [
    title,
    body,
    category.name,
    timing.name,
    fullScreen ? 'fs' : '',
    publicOnLockScreen ? 'pub' : '',
    timeout?.inSeconds ?? '',
    for (final a in actions) a.signature,
    ongoing ? 'on' : '',
    autoCancel ? 'ac' : '',
    colorArgb ?? '',
    subText ?? '',
  ].join('␟');

  NotificationRequest copyWith({DateTime? at, NotificationTiming? timing, int? id, Map<String, Object?>? data}) =>
      NotificationRequest(
        namespace: namespace,
        id: id ?? this.id,
        channelId: channelId,
        title: title,
        body: body,
        at: at ?? this.at,
        data: data ?? this.data,
        category: category,
        timing: timing ?? this.timing,
        fullScreen: fullScreen,
        publicOnLockScreen: publicOnLockScreen,
        timeout: timeout,
        dropIfLateBy: dropIfLateBy,
        actions: actions,
        ongoing: ongoing,
        autoCancel: autoCancel,
        colorArgb: colorArgb,
        subText: subText,
      );
}

/// A notification the user tapped (or that launched Madar full-screen), or
/// one of its action buttons.
@immutable
class NotificationTap {
  const NotificationTap({
    required this.id,
    required this.namespace,
    required this.data,
    this.actionId,
    this.channelId,
    this.at,
    this.fromLaunch = false,
  });

  final int? id;

  /// The feature that posted it (`null` for foreign / legacy payloads).
  final String? namespace;
  final Map<String, Object?> data;

  /// The action button, or `null` for the notification body.
  final String? actionId;
  final String? channelId;

  /// When it was scheduled to fire.
  final DateTime? at;

  /// It launched the app (cold start), rather than reaching a running one.
  final bool fromLaunch;

  @override
  String toString() => 'NotificationTap($namespace#$id action=$actionId at=$at data=$data launch=$fromLaunch)';
}

/// A pending (scheduled, not yet shown) notification as the platform
/// reports it.
@immutable
class PendingNotice {
  const PendingNotice(this.id, this.payload);

  final int id;
  final String? payload;
}

/// What a [NotificationService.sync] did.
@immutable
class NotificationSyncReport {
  const NotificationSyncReport({
    this.scheduled = 0,
    this.unchanged = 0,
    this.cancelled = 0,
    this.skippedPast = 0,
    this.inexactFallback = 0,
    this.failed = 0,
    this.rearmed = 0,
  });

  /// Newly scheduled or re-scheduled with changes.
  final int scheduled;

  /// Already pending with identical content (left alone).
  final int unchanged;

  /// Pending but no longer wanted.
  final int cancelled;

  /// Requested for a moment already past.
  final int skippedPast;

  /// Scheduled inexactly because exact alarms are not permitted.
  final int inexactFallback;

  /// Could not be scheduled at all.
  final int failed;

  /// Listed as pending by the plugin but no longer armed with the system
  /// (force stop, OEM task killer, revoked exact-alarm permission) – so
  /// scheduled again; counted in [scheduled] too.
  final int rearmed;

  int get pending => scheduled + unchanged;

  @override
  String toString() =>
      'NotificationSyncReport(scheduled: $scheduled, unchanged: $unchanged, cancelled: $cancelled, '
      'skippedPast: $skippedPast, inexact: $inexactFallback, failed: $failed, rearmed: $rearmed)';
}

/// Thrown by a [NotificationPlatform] when exact alarms are not permitted.
class ExactAlarmNotPermittedException implements Exception {
  const ExactAlarmNotPermittedException([this.message = 'exact alarms not permitted']);

  final String message;

  @override
  String toString() => 'ExactAlarmNotPermittedException: $message';
}
