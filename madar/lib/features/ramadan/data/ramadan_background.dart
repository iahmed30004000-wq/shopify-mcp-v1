import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui' show DartPluginRegistrant, IsolateNameServer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show NotificationResponse;

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/notifications/flutter_local_notifications_platform.dart';
import '../../../core/notifications/notification_envelope.dart';
import '../../../core/notifications/notification_models.dart';
import '../../../core/notifications/notification_platform.dart';
import '../../../core/notifications/notification_service.dart';
import '../../health/meds/data/meds_background.dart' show openExistingMadarDatabase;
import 'ramadan_notifications.dart';
import 'ramadan_repository.dart';
import 'ramadan_texts.dart';

// «صلّيت» on the Taraweeh reminder is answered without opening Madar - the
// medication tracker's, the iqama's and the fasting reminder's background
// pattern:
//
// 1. If the app is running, the answer goes to it over an isolate port
//    ([ramadanActionPortName], registered by [RamadanActionReceiver]) and
//    the app writes it through its own database connection - its screen
//    updates at once and nothing opens the encrypted file twice. No
//    acknowledgement within a few seconds (a stale port of a dead UI
//    isolate) falls through to step 2.
// 2. Otherwise this handler opens the encrypted database itself: the file
//    must already exist and the SQLCipher key is read from Keystore-backed
//    secure storage (never created here), with no seeding. It writes the
//    night through [RamadanRepository] - one entry per night, so a double tap
//    leaves exactly one row (and a night already logged, with its rakaat
//    count, is left as it is).
// 3. If that fails, a notice asks the user to open Madar - an answer is
//    never lost silently.
//
// Nothing is re-planned here: the reminder that was answered has already
// fired, and the next ones are planned when Madar next starts.

/// Name of the port the running app listens on for answers given in the
/// background isolate.
const ramadanActionPortName = 'madar.ramadan.actions';

/// What one answer did.
enum RamadanBackgroundOutcome {
  /// Not a Taraweeh answer (a body tap, a notice, another feature's).
  ignored,

  /// The running app recorded it.
  forwarded,

  /// Written here, in the background: the night's one entry.
  recorded,

  /// The same answer was already there (a double tap): nothing was written.
  alreadyRecorded,

  /// Could not be recorded; the user was asked to open Madar.
  failed,
}

/// Delivers an answer to the running app.
abstract interface class RamadanActionTransport {
  /// True once the app confirmed it handled [tap].
  Future<bool> forward(NotificationTap tap);
}

/// [RamadanActionTransport] over [IsolateNameServer] (one Dart VM per
/// process: the background engine and the app's engine share it).
class IsolateRamadanActionTransport implements RamadanActionTransport {
  const IsolateRamadanActionTransport({this.timeout = const Duration(seconds: 4)});

  final Duration timeout;

  @override
  Future<bool> forward(NotificationTap tap) async {
    final port = IsolateNameServer.lookupPortByName(ramadanActionPortName);
    if (port == null) return false;
    final reply = ReceivePort();
    try {
      port.send([jsonEncode(encodeTap(tap)), reply.sendPort]);
      final answer = await reply.first.timeout(timeout, onTimeout: () => false);
      return answer == true;
    } catch (e) {
      debugPrint('ramadan: forwarding an answer failed: $e');
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
      namespace: RamadanNotificationTaps.namespace.name,
      data: data is Map ? Map<String, Object?>.from(data) : const {},
      actionId: map['a'] is String ? map['a'] as String : null,
      channelId: map['c'] is String ? map['c'] as String : null,
    );
  }
}

/// The app's end of [IsolateRamadanActionTransport]: registers the port
/// while the app runs and handles each answer with [onAnswer] (true =
/// handled).
class RamadanActionReceiver {
  RamadanActionReceiver(this.onAnswer);

  final Future<bool> Function(NotificationTap tap) onAnswer;
  ReceivePort? _port;

  bool get isOpen => _port != null;

  void open() {
    close();
    final port = ReceivePort();
    _port = port;
    IsolateNameServer.removePortNameMapping(ramadanActionPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, ramadanActionPortName);
    port.listen(_onMessage);
  }

  Future<void> _onMessage(Object? message) async {
    if (message is! List || message.length != 2 || message[1] is! SendPort) return;
    final reply = message[1] as SendPort;
    var ok = false;
    try {
      final tap = IsolateRamadanActionTransport.decodeTap(message[0]);
      if (tap != null) ok = await onAnswer(tap);
    } catch (e) {
      debugPrint('ramadan: handling a forwarded answer failed: $e');
    }
    reply.send(ok);
  }

  void close() {
    final port = _port;
    if (port == null) return;
    _port = null;
    port.close();
    IsolateNameServer.removePortNameMapping(ramadanActionPortName);
  }
}

/// Opens the existing encrypted database for a background answer (null
/// when there is none yet).
typedef RamadanDatabaseOpener = Future<MadarDatabase?> Function();

/// Records a Taraweeh night when the app may not be running (see the
/// comment at the top of this file).
class RamadanBackgroundHandler {
  RamadanBackgroundHandler({
    required this.transport,
    required this.openDatabase,
    required this.notifications,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RamadanActionTransport transport;
  final RamadanDatabaseOpener openDatabase;
  final NotificationService notifications;
  final DateTime Function() _clock;

  Future<RamadanBackgroundOutcome> handle(NotificationTap tap) async {
    final answer = RamadanNotificationTaps.prayedOf(tap);
    if (answer == null) return RamadanBackgroundOutcome.ignored;
    if (await transport.forward(tap)) return RamadanBackgroundOutcome.forwarded;
    MadarDatabase? db;
    try {
      db = await openDatabase();
      if (db == null) throw StateError('no Madar database on this device');
      final repo = RamadanRepository(Repositories(db).keyValues);
      final wrote = await repo.markTaraweehDone(answer.hijriYear, answer.night);
      return wrote ? RamadanBackgroundOutcome.recorded : RamadanBackgroundOutcome.alreadyRecorded;
    } catch (e) {
      debugPrint('ramadan: recording a Taraweeh night from the shade failed: $e');
      try {
        await notifications.show(
          RamadanNotifications.failedNotice(answer: answer, t: textsFor(answer), now: _clock()),
        );
      } catch (e) {
        debugPrint('ramadan: posting a notice failed: $e');
      }
      return RamadanBackgroundOutcome.failed;
    } finally {
      try {
        await db?.close();
      } catch (_) {}
    }
  }

  /// Texts in the language the notification was written in.
  static RamadanTexts textsFor(RamadanPrayedAnswer answer) =>
      RamadanTexts.forLanguage(answer.language, digits: answer.digits);
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

/// Runs a Taraweeh answer given in the notification shade (production wiring
/// of [RamadanBackgroundHandler]). [wrapPlatform] decorates the plugin - the
/// app passes a gated platform, so even the "not saved" notice goes through
/// the one notification gate.
Future<RamadanBackgroundOutcome> runRamadanBackgroundAction(
  NotificationTap tap, {
  NotificationPlatform Function(NotificationPlatform platform)? wrapPlatform,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final NotificationPlatform base = _BackgroundNotificationPlatform(FlutterLocalNotificationsPlatform());
  final notifications = NotificationService(wrapPlatform?.call(base) ?? base);
  final handler = RamadanBackgroundHandler(
    transport: const IsolateRamadanActionTransport(),
    openDatabase: openExistingMadarDatabase,
    notifications: notifications,
  );
  return handler.handle(tap);
}

/// Background entry point for the Taraweeh button that does not open the app.
/// «صلّيت» is handled; every other response is left alone.
///
/// Pass it to `FlutterLocalNotificationsPlatform(backgroundHandler: …)` where
/// the app does not already route every feature
/// (`madarAppNotificationBackgroundTap` does).
@pragma('vm:entry-point')
void ramadanNotificationBackgroundTap(NotificationResponse response) {
  final action = response.actionId;
  final tap = NotificationEnvelope.decode(
    response.payload,
    id: response.id,
    actionId: action == null || action.isEmpty ? null : action,
  );
  if (!RamadanNotificationTaps.isRamadan(tap) || tap.actionId == null) return;
  unawaited(runRamadanBackgroundAction(tap));
}
