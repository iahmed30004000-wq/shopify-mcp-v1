import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui' show DartPluginRegistrant, IsolateNameServer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show NotificationResponse;

import '../../../../core/db/database.dart';
import '../../../../core/db/encryption.dart';
import '../../../../core/db/open.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/notifications/flutter_local_notifications_platform.dart';
import '../../../../core/notifications/notification_envelope.dart';
import '../../../../core/notifications/notification_models.dart';
import '../../../../core/notifications/notification_platform.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../orbit/data/orbit_repository.dart' show OrbitRepository;
import '../../../orbit/domain/prayer_schedule.dart';
import '../../../prayer/domain/time_zones.dart';
import '../meds_texts.dart';
import 'meds_notifications.dart';
import 'meds_prayer_times.dart';
import 'meds_service.dart';

// Taken / Snooze / Skip on a dose notification run without opening the app.
//
// The buttons are background actions (`opensApp: false`): Android hands them
// to flutter_local_notifications' background isolate, whose entry point is
// [medsNotificationBackgroundTap]. There:
//
// 1. If the app is running, the answer is forwarded to it over an isolate
//    port ([medsActionPortName], registered by [MedsActionReceiver]) and the
//    app records it through its own database connection – its lists update
//    at once, and nothing opens the file twice. The app acknowledges; no
//    acknowledgement within a few seconds (a stale port of a dead UI
//    isolate) falls through to step 2.
// 2. Otherwise the handler opens the encrypted database itself: the file
//    must already exist and the SQLCipher key is read from the Keystore-backed
//    secure storage (never created here), with no seeding. It records the
//    answer through the same [MedsService] (idempotent: a repeated Taken
//    changes nothing), re-plans the next 48 hours of reminders (a snooze
//    becomes a reminder at its new time) and closes the database.
// 3. If that fails too, a notice asks the user to open Madar – an answer is
//    never lost silently.
//
// Why not open the app for every answer: taking a pill should be one tap on
// the lock screen, and the app may be behind its PIN lock. Opening the
// database in the background is safe: SQLite's locking (WAL, busy timeout)
// serialises the two connections of one process, and the key never leaves
// secure storage.

/// Name of the port the running app listens on for answers given in the
/// background isolate.
const medsActionPortName = 'madar.meds.actions';

/// Delivers an answer to the running app.
abstract interface class MedsActionTransport {
  /// True once the app confirmed it recorded [action].
  Future<bool> forward(MedDoseAction action);
}

/// [MedsActionTransport] over [IsolateNameServer] (one Dart VM per
/// process: the background engine and the app's engine share it).
class IsolateMedsActionTransport implements MedsActionTransport {
  const IsolateMedsActionTransport({this.timeout = const Duration(seconds: 4)});

  final Duration timeout;

  @override
  Future<bool> forward(MedDoseAction action) async {
    final port = IsolateNameServer.lookupPortByName(medsActionPortName);
    if (port == null) return false;
    final reply = ReceivePort();
    try {
      port.send([jsonEncode(action.toJson()), reply.sendPort]);
      final answer = await reply.first.timeout(timeout, onTimeout: () => false);
      return answer == true;
    } catch (e) {
      debugPrint('meds: forwarding a notification answer failed: $e');
      return false;
    } finally {
      reply.close();
    }
  }
}

/// The app's end of [IsolateMedsActionTransport]: registers the port while
/// the app runs and records each answer with [onAction] (true = recorded).
class MedsActionReceiver {
  MedsActionReceiver(this.onAction);

  final Future<bool> Function(MedDoseAction action) onAction;
  ReceivePort? _port;

  bool get isOpen => _port != null;

  void open() {
    close();
    final port = ReceivePort();
    _port = port;
    IsolateNameServer.removePortNameMapping(medsActionPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, medsActionPortName);
    port.listen(_onMessage);
  }

  Future<void> _onMessage(Object? message) async {
    if (message is! List || message.length != 2 || message[1] is! SendPort) return;
    final reply = message[1] as SendPort;
    var ok = false;
    try {
      final raw = message[0];
      final action = MedDoseAction.fromJson(raw is String ? jsonDecode(raw) : raw);
      if (action != null) ok = await onAction(action);
    } catch (e) {
      debugPrint('meds: recording a forwarded answer failed: $e');
    }
    reply.send(ok);
  }

  void close() {
    final port = _port;
    if (port == null) return;
    _port = null;
    port.close();
    IsolateNameServer.removePortNameMapping(medsActionPortName);
  }
}

enum MedsBackgroundOutcome {
  /// Not a dose action (a body tap, another feature's notification).
  ignored,

  /// The running app recorded it.
  forwarded,

  /// Recorded here, in the background.
  applied,

  /// Could not be recorded; the user was asked to open the app.
  failed,
}

/// Opens the existing encrypted database for a background answer (null
/// when there is none yet).
typedef MedsDatabaseOpener = Future<MadarDatabase?> Function();

/// Builds the reminder engine for a background answer (texts in the
/// notification's language, the stored prayer schedule).
typedef MedsEngineBuilder = Future<MedsReminderEngine> Function(MedsService service, NotificationTap tap);

/// Records a notification answer when the app may not be running (see the
/// comment at the top of this file).
class MedsBackgroundHandler {
  MedsBackgroundHandler({
    required this.transport,
    required this.openDatabase,
    required this.notifications,
    required this.engineFor,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MedsActionTransport transport;
  final MedsDatabaseOpener openDatabase;
  final NotificationService notifications;
  final MedsEngineBuilder engineFor;
  final DateTime Function() _clock;

  Future<MedsBackgroundOutcome> handle(NotificationTap tap) async {
    final action = MedsNotificationTaps.actionOf(tap, now: _clock());
    if (action == null) return MedsBackgroundOutcome.ignored;
    if (await transport.forward(action)) return MedsBackgroundOutcome.forwarded;
    MadarDatabase? db;
    try {
      db = await openDatabase();
      if (db == null) throw StateError('no Madar database on this device');
      final service = MedsService(Repositories(db), clock: _clock);
      final result = await service.apply(action);
      try {
        final engine = await engineFor(service, tap);
        await engine.resync();
        await engine.refillIfNeeded(action.medId, result);
      } catch (e) {
        // The answer is recorded; reminders are re-planned when the app next
        // starts.
        debugPrint('meds: background re-plan failed: $e');
      }
      return MedsBackgroundOutcome.applied;
    } catch (e) {
      debugPrint('meds: background answer failed: $e');
      try {
        await notifications.show(MedsReminderPlanner.failedNotice(action: action, texts: textsFor(tap)));
      } catch (e) {
        debugPrint('meds: could not post the failure notice: $e');
      }
      return MedsBackgroundOutcome.failed;
    } finally {
      try {
        await db?.close();
      } catch (_) {}
    }
  }

  /// Texts in the language the notification was written in.
  static MedsTexts textsFor(NotificationTap tap) =>
      MedsTexts.forLanguage(MedsNotificationTaps.languageOf(tap), digits: MedsNotificationTaps.digitsOf(tap));
}

/// Opens the encrypted database if it exists and its key is in secure
/// storage; never creates either, never seeds.
Future<MadarDatabase?> openExistingMadarDatabase({DatabaseKeyStore? keyStore}) async {
  final file = await madarDatabaseFile();
  if (!await file.exists()) return null;
  final key = await (keyStore ?? DatabaseKeyStore()).readKey();
  if (key == null) return null;
  return openMadarDatabase(key: key, file: file, seed: null);
}

/// The production [MedsEngineBuilder]: the stored prayer settings and the
/// notification's language.
Future<MedsReminderEngine> buildBackgroundEngine(
  MedsService service,
  NotificationTap tap,
  NotificationService notifications,
) async {
  try {
    MadarTimeZones.ensure();
  } catch (_) {}
  final settings = await service.repos.keyValues.get(OrbitRepository.prayerSettingsKv) ?? const PrayerSettings();
  return MedsReminderEngine(
    service: service,
    notifications: notifications,
    texts: MedsBackgroundHandler.textsFor(tap),
    prayerTime: prayerTimeOf(PrayerSchedule(settings)),
  );
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

/// Runs a dose answer given in the notification shade (production wiring
/// of [MedsBackgroundHandler]).
Future<MedsBackgroundOutcome> runMedsBackgroundAction(NotificationTap tap) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final notifications = NotificationService(_BackgroundNotificationPlatform(FlutterLocalNotificationsPlatform()));
  final handler = MedsBackgroundHandler(
    transport: const IsolateMedsActionTransport(),
    openDatabase: openExistingMadarDatabase,
    notifications: notifications,
    engineFor: (service, tap) => buildBackgroundEngine(service, tap, notifications),
  );
  return handler.handle(tap);
}

/// Background entry point for notification actions that do not open the
/// app. Dose answers (Taken / Snooze / Skip) are recorded; every other
/// response is left alone, exactly like the core's default
/// `madarNotificationBackgroundTap` (whose actions – the adhan's "Stop" –
/// are fully handled natively).
///
/// Pass it to `FlutterLocalNotificationsPlatform(backgroundHandler: …)`.
@pragma('vm:entry-point')
void medsNotificationBackgroundTap(NotificationResponse response) {
  final action = response.actionId;
  final tap = NotificationEnvelope.decode(
    response.payload,
    id: response.id,
    actionId: action == null || action.isEmpty ? null : action,
  );
  if (!MedsNotificationTaps.isMeds(tap) || tap.actionId == null) return;
  unawaited(runMedsBackgroundAction(tap));
}
