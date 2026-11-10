import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui' show DartPluginRegistrant, IsolateNameServer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show NotificationResponse;

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/notifications/flutter_local_notifications_platform.dart';
import '../../../core/notifications/notification_envelope.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_platform.dart';
import '../../../core/notifications/notification_service.dart';
import '../../adhan/domain/adhan_sound.dart';
import '../../health/meds/data/meds_background.dart' show openExistingMadarDatabase;
import '../../prayer_tracker/data/prayer_tracker_repository.dart';
import '../../prayer_tracker/domain/tracker_prayers.dart';
import '../domain/iqama_event.dart';
import '../domain/iqama_settings.dart';
import 'iqama_scheduler.dart';
import 'iqama_texts.dart';

// «صلّيت» and «بعد شوي» on an iqama notification are answered without
// opening Madar – the medication tracker's background pattern, prayer for
// prayer:
//
// 1. If the app is running, the answer goes to it over an isolate port
//    ([iqamaActionPortName], registered by [IqamaActionReceiver]) and the
//    app writes it through its own database connection – the tracker's
//    lists and the Faith world update at once, and nothing opens the
//    encrypted file twice. No acknowledgement within a few seconds (a
//    stale port of a dead UI isolate) falls through to step 2.
// 2. Otherwise this handler opens the encrypted database itself: the file
//    must already exist and the SQLCipher key is read from Keystore-backed
//    secure storage (never created here), with no seeding. «صلّيت» is
//    written through the prayer tracker's own [PrayerTrackerRepository] –
//    never by touching its table – which writes exactly the row the
//    tracker's own button writes. A prayer already logged by hand is left
//    alone and a notice says so: no second row, ever.
// 3. If that fails too, a notice asks the user to open Madar – an answer is
//    never lost silently.
//
// «بعد شوي» needs no database at all: everything it needs (the snooze
// length, the channel, the next adhan it may not pass) travels in the
// notification's own payload, so the one snooze is armed even if the
// database cannot be opened. It is offered once: the snoozed notification
// carries no «بعد شوي», and [IqamaNotificationTaps.answerOf] refuses a
// second one whatever arrives.

/// Name of the port the running app listens on for answers given in the
/// background isolate.
const iqamaActionPortName = 'madar.iqama.actions';

/// What one answer did.
enum IqamaBackgroundOutcome {
  /// Not an iqama answer (a body tap, a notice, another feature's).
  ignored,

  /// The running app recorded it.
  forwarded,

  /// Logged here, in the background: one new row.
  logged,

  /// It was already logged (by hand, or by an earlier tap): nothing was
  /// written and the user was told.
  alreadyLogged,

  /// «بعد شوي»: armed once.
  snoozed,

  /// The snooze was refused – it would land after the next adhan, or it
  /// had already been taken.
  snoozeRefused,

  /// Could not be recorded; the user was asked to open Madar.
  failed,
}

/// Delivers an answer to the running app.
abstract interface class IqamaActionTransport {
  /// True once the app confirmed it handled [tap].
  Future<bool> forward(NotificationTap tap);
}

/// [IqamaActionTransport] over [IsolateNameServer] (one Dart VM per
/// process: the background engine and the app's engine share it).
class IsolateIqamaActionTransport implements IqamaActionTransport {
  const IsolateIqamaActionTransport({this.timeout = const Duration(seconds: 4)});

  final Duration timeout;

  @override
  Future<bool> forward(NotificationTap tap) async {
    final port = IsolateNameServer.lookupPortByName(iqamaActionPortName);
    if (port == null) return false;
    final reply = ReceivePort();
    try {
      port.send([jsonEncode(encodeTap(tap)), reply.sendPort]);
      final answer = await reply.first.timeout(timeout, onTimeout: () => false);
      return answer == true;
    } catch (e) {
      debugPrint('iqama: forwarding an answer failed: $e');
      return false;
    } finally {
      reply.close();
    }
  }

  /// A tap as it travels between the two isolates.
  static Map<String, Object?> encodeTap(NotificationTap tap) => {
    'id': tap.id,
    'a': tap.actionId,
    'c': tap.channelId,
    'd': tap.data,
  };

  static NotificationTap? decodeTap(Object? raw) {
    final map = raw is String ? jsonDecode(raw) : raw;
    if (map is! Map) return null;
    final data = map['d'];
    return NotificationTap(
      id: map['id'] is int ? map['id'] as int : null,
      namespace: IqamaNotificationTaps.namespace.name,
      data: data is Map ? Map<String, Object?>.from(data) : const {},
      actionId: map['a'] is String ? map['a'] as String : null,
      channelId: map['c'] is String ? map['c'] as String : null,
    );
  }
}

/// The app's end of [IsolateIqamaActionTransport]: registers the port while
/// the app runs and handles each answer with [onAnswer] (true = handled).
class IqamaActionReceiver {
  IqamaActionReceiver(this.onAnswer);

  final Future<bool> Function(NotificationTap tap) onAnswer;
  ReceivePort? _port;

  bool get isOpen => _port != null;

  void open() {
    close();
    final port = ReceivePort();
    _port = port;
    IsolateNameServer.removePortNameMapping(iqamaActionPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, iqamaActionPortName);
    port.listen(_onMessage);
  }

  Future<void> _onMessage(Object? message) async {
    if (message is! List || message.length != 2 || message[1] is! SendPort) return;
    final reply = message[1] as SendPort;
    var ok = false;
    try {
      final tap = IsolateIqamaActionTransport.decodeTap(message[0]);
      if (tap != null) ok = await onAnswer(tap);
    } catch (e) {
      debugPrint('iqama: handling a forwarded answer failed: $e');
    }
    reply.send(ok);
  }

  void close() {
    final port = _port;
    if (port == null) return;
    _port = null;
    port.close();
    IsolateNameServer.removePortNameMapping(iqamaActionPortName);
  }
}

/// Opens the existing encrypted database for a background answer (null
/// when there is none yet).
typedef IqamaDatabaseOpener = Future<MadarDatabase?> Function();

/// Records an iqama answer when the app may not be running (see the
/// comment at the top of this file).
class IqamaBackgroundHandler {
  IqamaBackgroundHandler({
    required this.transport,
    required this.openDatabase,
    required this.notifications,
    this.beforeSnooze,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final IqamaActionTransport transport;
  final IqamaDatabaseOpener openDatabase;
  final NotificationService notifications;

  /// Runs before the snooze is armed (the app loads the stored mute policy
  /// into its background gate there). Never blocks the answer.
  final Future<void> Function()? beforeSnooze;

  final DateTime Function() _clock;

  Future<IqamaBackgroundOutcome> handle(NotificationTap tap) async {
    final answer = IqamaNotificationTaps.answerOf(tap);
    if (answer == null) {
      // A second «بعد شوي» on the snooze itself: refused, and the user is
      // not pestered with a notice about it.
      return IqamaNotificationTaps.isIqama(tap) && tap.actionId == IqamaActions.later
          ? IqamaBackgroundOutcome.snoozeRefused
          : IqamaBackgroundOutcome.ignored;
    }
    if (await transport.forward(tap)) return IqamaBackgroundOutcome.forwarded;
    return switch (answer.kind) {
      IqamaAnswerKind.later => _snooze(answer),
      IqamaAnswerKind.prayed => _log(answer),
    };
  }

  /// Arms the one snooze – never past the next adhan.
  Future<IqamaBackgroundOutcome> _snooze(IqamaAnswer answer) async {
    final now = _clock();
    final at = now.add(Duration(minutes: answer.snoozeMinutes));
    final next = answer.nextAdhanAt;
    if (next != null && !at.isBefore(next)) return IqamaBackgroundOutcome.snoozeRefused;
    final before = beforeSnooze;
    if (before != null) {
      try {
        await before();
      } catch (e) {
        debugPrint('iqama: loading the stored notification policy failed: $e');
      }
    }
    try {
      final ok = await notifications.schedule(_snoozeRequest(answer, at));
      return ok ? IqamaBackgroundOutcome.snoozed : IqamaBackgroundOutcome.failed;
    } catch (e) {
      debugPrint('iqama: arming the snooze failed: $e');
      return IqamaBackgroundOutcome.failed;
    }
  }

  NotificationRequest _snoozeRequest(IqamaAnswer answer, DateTime at) {
    final texts = textsFor(answer);
    return IqamaNotifications.request(
      answer.asAlarm(at: at),
      settings: IqamaSettings(snoozeMinutes: answer.snoozeMinutes),
      texts: texts,
      channelId: answer.channelId ?? IqamaNotifications.channelId(const AdhanSoundRef.tone(TanbihTone.chime), vibrate: true),
      snooze: true,
      at: at,
    );
  }

  /// «صلّيت»: one row through the tracker's own repository – and never a
  /// second one.
  Future<IqamaBackgroundOutcome> _log(IqamaAnswer answer) async {
    final now = _clock();
    MadarDatabase? db;
    try {
      db = await openDatabase();
      if (db == null) throw StateError('no Madar database on this device');
      final tracker = PrayerTrackerRepository(Repositories(db), clock: () => now);
      final day = answer.localDay;
      final existing = await tracker.logOf(day, answer.prayer);
      if (existing != null && existing.status.counts) {
        await _notice(
          IqamaNotifications.alreadyLogged(slot: answer.slot, day: answer.day, texts: textsFor(answer), now: now),
        );
        return IqamaBackgroundOutcome.alreadyLogged;
      }
      await tracker.setStatus(day, answer.prayer, PrayerStatus.prayed);
      return IqamaBackgroundOutcome.logged;
    } catch (e) {
      debugPrint('iqama: logging a prayer from the shade failed: $e');
      await _notice(
        IqamaNotifications.failedNotice(slot: answer.slot, day: answer.day, texts: textsFor(answer), now: now),
      );
      return IqamaBackgroundOutcome.failed;
    } finally {
      try {
        await db?.close();
      } catch (_) {}
    }
  }

  Future<void> _notice(NotificationRequest request) async {
    try {
      await notifications.show(request);
    } catch (e) {
      debugPrint('iqama: posting a notice failed: $e');
    }
  }

  /// Texts in the language the notification was written in.
  static IqamaTexts textsFor(IqamaAnswer answer) =>
      IqamaTexts.forLanguage(answer.language, digits: answer.digits);
}

/// The notifications plugin as the background isolate uses it: never
/// re-initialised there (that would re-register the app's background entry
/// point, which the app owns).
class _BackgroundNotificationPlatform implements NotificationPlatform {
  _BackgroundNotificationPlatform(this._inner);

  final NotificationPlatform _inner;

  @override
  Future<void> initialize({required void Function(RawNotificationTap tap) onTap}) async {}

  @override
  Future<RawNotificationTap?> launchTap() async => null;

  @override
  Future<void> createChannelGroup(String id, String name) => _inner.createChannelGroup(id, name);

  @override
  Future<void> createChannel(NotificationChannelSpec spec) => _inner.createChannel(spec);

  @override
  Future<void> deleteChannel(String id) => _inner.deleteChannel(id);

  @override
  Future<List<String>> channelIds() => _inner.channelIds();

  @override
  Future<void> schedule(NotificationRequest request, String payload, {required NotificationTiming timing}) =>
      _inner.schedule(request, payload, timing: timing);

  @override
  Future<void> show(NotificationRequest request, String payload) => _inner.show(request, payload);

  @override
  Future<void> cancel(int id) => _inner.cancel(id);

  @override
  Future<List<PendingNotice>> pending() => _inner.pending();

  @override
  Future<Set<int>?> armedIds(Iterable<int> ids) => _inner.armedIds(ids);

  @override
  Future<List<int>> activeIds() => _inner.activeIds();

  @override
  Future<bool> notificationsEnabled() => _inner.notificationsEnabled();

  @override
  Future<bool> requestNotifications() async => false;

  @override
  Future<bool> canScheduleExact() => _inner.canScheduleExact();

  @override
  Future<bool> requestExactAlarms() async => false;

  @override
  Future<bool> requestFullScreenIntent() async => false;
}

/// Runs an iqama answer given in the notification shade (production wiring
/// of [IqamaBackgroundHandler]).
///
/// Two seams the app shell uses, and nothing else does (see
/// `lib/app/background_notifications.dart`):
///
/// * [wrapPlatform] decorates the plugin – the app passes a
///   `GatedNotificationPlatform` over a background `NotificationGate`, so
///   the snooze armed here cannot slip past a Prayer mute;
/// * [beforeSnooze] loads the stored mute policy into that gate first. It
///   never blocks the answer: an error is swallowed, because the prayer
///   log matters more than the snooze.
Future<IqamaBackgroundOutcome> runIqamaBackgroundAction(
  NotificationTap tap, {
  NotificationPlatform Function(NotificationPlatform platform)? wrapPlatform,
  Future<void> Function()? beforeSnooze,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final NotificationPlatform base = _BackgroundNotificationPlatform(FlutterLocalNotificationsPlatform());
  final notifications = NotificationService(wrapPlatform?.call(base) ?? base);
  final handler = IqamaBackgroundHandler(
    transport: const IsolateIqamaActionTransport(),
    openDatabase: openExistingMadarDatabase,
    notifications: notifications,
    beforeSnooze: beforeSnooze,
  );
  return handler.handle(tap);
}

/// Background entry point for iqama buttons that do not open the app.
/// «صلّيت» and «بعد شوي» are handled; every other response is left alone.
///
/// Pass it to `FlutterLocalNotificationsPlatform(backgroundHandler: …)`
/// where the app does not already route both features
/// (`madarAppNotificationBackgroundTap` does).
@pragma('vm:entry-point')
void iqamaNotificationBackgroundTap(NotificationResponse response) {
  final action = response.actionId;
  final tap = NotificationEnvelope.decode(
    response.payload,
    id: response.id,
    actionId: action == null || action.isEmpty ? null : action,
  );
  if (!IqamaNotificationTaps.isIqama(tap) || tap.actionId == null) return;
  unawaited(runIqamaBackgroundAction(tap));
}
