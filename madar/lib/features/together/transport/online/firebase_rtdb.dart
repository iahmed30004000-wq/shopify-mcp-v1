/// [RtdbClient] over the user's own Firebase project: a *secondary* Firebase
/// app named [FirebaseRtdbClient.appName] initialised at run time from the
/// entered [OnlineConfig] (never the default app, never a bundled
/// google-services.json), anonymous sign-in and the Realtime Database.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'online_config.dart';
import 'rtdb.dart';

extension OnlineConfigFirebase on OnlineConfig {
  FirebaseOptions toFirebaseOptions() => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    databaseURL: databaseUrl,
  );
}

class FirebaseRtdbClient implements RtdbClient {
  FirebaseRtdbClient._(this._auth, this._db) {
    _subs.add(
      _db
          .ref('.info/connected')
          .onValue
          .listen((e) => _connected.value = e.snapshot.value == true, onError: (Object _) => _connected.value = false),
    );
    _subs.add(
      _db.ref('.info/serverTimeOffset').onValue.listen((e) {
        final v = e.snapshot.value;
        if (v is num) _offsetMs = v.round();
      }, onError: (Object _) {}),
    );
  }

  /// The secondary app's name.
  static const String appName = 'together';

  /// Starts (or reuses) the secondary app for [config] and connects.
  static Future<FirebaseRtdbClient> open(OnlineConfig config) async {
    final FirebaseApp app;
    try {
      app = await _app(config);
    } on FirebaseException catch (e) {
      throw RtdbException(RtdbErrorKind.setup, e.message);
    } on Object catch (e) {
      throw RtdbException(RtdbErrorKind.setup, '$e');
    }
    final db = FirebaseDatabase.instanceFor(app: app, databaseURL: config.databaseUrl);
    await db.goOnline();
    return FirebaseRtdbClient._(FirebaseAuth.instanceFor(app: app), db);
  }

  static Future<FirebaseApp> _app(OnlineConfig config) async {
    final options = config.toFirebaseOptions();
    final existing = Firebase.apps.where((a) => a.name == appName).firstOrNull;
    if (existing != null) {
      final o = existing.options;
      final same =
          o.apiKey == options.apiKey &&
          o.appId == options.appId &&
          o.projectId == options.projectId &&
          o.databaseURL == options.databaseURL;
      if (same) return existing;
      await existing.delete();
    }
    return Firebase.initializeApp(name: appName, options: options);
  }

  final FirebaseAuth _auth;
  final FirebaseDatabase _db;
  final ValueNotifier<bool> _connected = ValueNotifier(false);
  final List<StreamSubscription<Object?>> _subs = [];
  int _offsetMs = 0;

  @override
  String? get uid => _auth.currentUser?.uid;

  @override
  ValueListenable<bool> get connected => _connected;

  @override
  DateTime serverNow() => DateTime.now().add(Duration(milliseconds: _offsetMs));

  static RtdbException _map(Object e) {
    if (e is RtdbException) return e;
    if (e is FirebaseException) {
      final code = e.code.toLowerCase();
      if (code.contains('permission')) return RtdbException(RtdbErrorKind.permissionDenied, e.message);
      if (code.contains('network') || code.contains('unavailable') || code.contains('disconnected')) {
        return RtdbException(RtdbErrorKind.network, e.message);
      }
      return RtdbException(RtdbErrorKind.unknown, '${e.code}: ${e.message}');
    }
    return RtdbException(RtdbErrorKind.unknown, '$e');
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<String> signIn() async {
    final current = _auth.currentUser;
    if (current != null) return current.uid;
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) throw const RtdbException(RtdbErrorKind.signIn);
      return user.uid;
    } on FirebaseAuthException catch (e) {
      final code = e.code.toLowerCase();
      if (code.contains('network')) throw RtdbException(RtdbErrorKind.network, e.message);
      if (code.contains('api-key') || code.contains('app-not-authorized') || code.contains('invalid')) {
        throw RtdbException(RtdbErrorKind.setup, e.message);
      }
      throw RtdbException(RtdbErrorKind.signIn, '${e.code}: ${e.message}');
    }
  }

  @override
  Future<Object?> read(String path) => _guard(() async => (await _db.ref(path).get()).value);

  @override
  Future<void> set(String path, Object? value) => _guard(() => _db.ref(path).set(value));

  @override
  Future<void> update(String path, Map<String, Object?> values) => _guard(() => _db.ref(path).update(values));

  @override
  Future<String> push(String path, Object? value) => _guard(() async {
    final ref = _db.ref(path).push();
    await ref.set(value);
    return ref.key!;
  });

  @override
  Future<void> remove(String path) => _guard(() => _db.ref(path).remove());

  @override
  Stream<RtdbChild> childAdded(String path) => _db
      .ref(path)
      .onChildAdded
      .map((e) => RtdbChild(e.snapshot.key ?? '', e.snapshot.value))
      .handleError((Object e) => throw _map(e));

  @override
  Stream<Object?> watch(String path) =>
      _db.ref(path).onValue.map((e) => e.snapshot.value).handleError((Object e) => throw _map(e));

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _connected.value = false;
    try {
      await _db.goOffline();
    } on Object {
      // Already offline.
    }
  }
}
