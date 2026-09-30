// Fakes for the two-phone transports: a shared "air" of Nearby phones and an
// in-memory Realtime Database that applies the online-play security rules
// (a Dart rendering of OnlineSecurityRules), plus permission fakes.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:madar/features/together/pairing/pairing.dart';

// ------------------------------------------------------------------ nearby

/// A connection between two fake phones.
class _Link {
  _Link(this.a, this.b, this.token);

  /// a requested, b advertised.
  final FakeNearbyApi a;
  final FakeNearbyApi b;
  final String token;
  bool acceptedA = false;
  bool acceptedB = false;
  bool connected = false;

  FakeNearbyApi other(FakeNearbyApi p) => identical(p, a) ? b : a;

  bool involves(FakeNearbyApi p) => identical(p, a) || identical(p, b);
}

/// Phones that can hear each other.
class FakeNearbyAir {
  FakeNearbyAir({int seed = 7}) : _random = math.Random(seed);

  final math.Random _random;
  final List<FakeNearbyApi> phones = [];
  final List<_Link> _links = [];

  /// Every BYTES payload sent over the air, in order: (from, to, bytes).
  final List<(String, String, Uint8List)> wire = [];

  /// Duplicates the next [n] payloads (delivered twice).
  int duplicateNext = 0;

  /// Whether the phones can hear each other at all.
  bool _inRange = true;

  bool get inRange => _inRange;

  /// Out of range: nothing is found and no connection can be made (existing
  /// links are cut).
  void goOutOfRange() {
    _inRange = false;
    for (final l in List.of(_links)) {
      cut(l.a, l.b);
    }
  }

  /// Back in range: advertising phones are found again.
  void comeBackIntoRange() {
    _inRange = true;
    for (final d in phones) {
      for (final a in phones) {
        if (a.advertising) _found(d, a);
      }
    }
  }

  /// Holds payloads (per sender) until [release].
  final Set<String> _holding = {};
  final Map<String, List<(FakeNearbyApi, Uint8List)>> _held = {};

  FakeNearbyApi phone(String label) {
    final p = FakeNearbyApi._(this, '${label.toUpperCase()}${phones.length}');
    phones.add(p);
    return p;
  }

  String _token() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return String.fromCharCodes([for (var i = 0; i < 4; i++) chars.codeUnitAt(_random.nextInt(chars.length))]);
  }

  _Link? _linkOf(FakeNearbyApi x, FakeNearbyApi y) =>
      _links.where((l) => l.involves(x) && l.involves(y)).firstOrNull;

  FakeNearbyApi? _byId(String id) => phones.where((p) => p.endpointId == id).firstOrNull;

  /// Breaks the link between two connected phones (out of range).
  void cut(FakeNearbyApi x, FakeNearbyApi y) {
    final l = _linkOf(x, y);
    if (l == null) return;
    _links.remove(l);
    x._emit(NearbyDisconnected(y.endpointId));
    y._emit(NearbyDisconnected(x.endpointId));
  }

  void hold(FakeNearbyApi from) => _holding.add(from.endpointId);

  /// Delivers held payloads (reversed: out of order).
  void release(FakeNearbyApi from, {bool reverse = false}) {
    _holding.remove(from.endpointId);
    final held = _held.remove(from.endpointId) ?? [];
    for (final (to, bytes) in reverse ? held.reversed : held) {
      to._emit(NearbyPayloadReceived(from.endpointId, payloadId: _random.nextInt(1 << 30), kind: NearbyPayloadKind.bytes, bytes: bytes));
    }
  }

  void _found(FakeNearbyApi discoverer, FakeNearbyApi advertiser) {
    if (identical(discoverer, advertiser) || !_inRange) return;
    if (discoverer.discoveringService == null || discoverer.discoveringService != advertiser.advertisingService) return;
    discoverer._emit(
      NearbyEndpointFound(advertiser.endpointId, name: advertiser.advertisingName!, serviceId: advertiser.advertisingService!),
    );
  }
}

/// One fake phone's Nearby client.
class FakeNearbyApi implements NearbyApi {
  FakeNearbyApi._(this.air, this.endpointId);

  final FakeNearbyAir air;

  /// How the other phones see this one.
  final String endpointId;

  String? advertisingName;
  String? advertisingService;
  String? discoveringService;

  /// Every call, in order (method names).
  final List<String> calls = [];

  /// Payloads cancelled.
  final List<int> cancelled = [];

  /// Fails the next start of advertising with this error.
  NearbyApiException? failNextStart;

  /// Fails this many connection requests (a radio hiccup).
  int failRequests = 0;

  @override
  int maxPayloadBytes = 32 * 1024;

  final StreamController<NearbyEvent> _events = StreamController<NearbyEvent>.broadcast();

  @override
  Stream<NearbyEvent> get events => _events.stream;

  void _emit(NearbyEvent e) => scheduleMicrotask(() {
    if (!_events.isClosed) _events.add(e);
  });

  bool get advertising => advertisingService != null;

  bool get discovering => discoveringService != null;

  @override
  Future<void> startAdvertising({required String name, required String serviceId}) async {
    calls.add('startAdvertising');
    final fail = failNextStart;
    if (fail != null) {
      failNextStart = null;
      throw fail;
    }
    advertisingName = name;
    advertisingService = serviceId;
    for (final p in air.phones) {
      air._found(p, this);
    }
  }

  @override
  Future<void> startDiscovery({required String name, required String serviceId}) async {
    calls.add('startDiscovery');
    discoveringService = serviceId;
    for (final p in air.phones) {
      if (p.advertising) air._found(this, p);
    }
  }

  @override
  Future<void> stopAdvertising() async {
    calls.add('stopAdvertising');
    if (advertisingService == null) return;
    advertisingService = null;
    for (final p in air.phones) {
      if (!identical(p, this) && p.discovering) p._emit(NearbyEndpointLost(endpointId));
    }
  }

  @override
  Future<void> stopDiscovery() async {
    calls.add('stopDiscovery');
    discoveringService = null;
  }

  @override
  Future<void> requestConnection({required String name, required String endpointId}) async {
    calls.add('requestConnection');
    if (failRequests > 0) {
      failRequests--;
      throw const NearbyApiException(NearbyErrorKind.unknown, '8012: STATUS_ENDPOINT_IO_ERROR');
    }
    final target = air._byId(endpointId);
    if (target == null || !target.advertising || !air.inRange) {
      throw const NearbyApiException(NearbyErrorKind.unknown, '8011: STATUS_ENDPOINT_UNKNOWN');
    }
    if (air._linkOf(this, target) != null) {
      // Crossed requests: the first one stands (Nearby breaks the tie).
      throw const NearbyApiException(NearbyErrorKind.unknown, '8012: STATUS_ENDPOINT_IO_ERROR');
    }
    final link = _Link(this, target, air._token());
    air._links.add(link);
    _emit(NearbyConnectionInitiated(target.endpointId, name: target.advertisingName!, token: link.token, incoming: false));
    target._emit(NearbyConnectionInitiated(this.endpointId, name: name, token: link.token, incoming: true));
  }

  @override
  Future<void> acceptConnection(String endpointId) async {
    calls.add('acceptConnection');
    final other = air._byId(endpointId);
    final link = other == null ? null : air._linkOf(this, other);
    if (link == null || other == null) throw const NearbyApiException(NearbyErrorKind.unknown, 'not connecting');
    if (identical(link.a, this)) {
      link.acceptedA = true;
    } else {
      link.acceptedB = true;
    }
    if (link.acceptedA && link.acceptedB && !link.connected) {
      link.connected = true;
      _emit(NearbyConnectionResult(other.endpointId, NearbyConnectionStatus.connected));
      other._emit(NearbyConnectionResult(this.endpointId, NearbyConnectionStatus.connected));
    }
  }

  @override
  Future<void> rejectConnection(String endpointId) async {
    calls.add('rejectConnection');
    final other = air._byId(endpointId);
    final link = other == null ? null : air._linkOf(this, other);
    if (link == null || other == null) return;
    air._links.remove(link);
    _emit(NearbyConnectionResult(other.endpointId, NearbyConnectionStatus.rejected));
    other._emit(NearbyConnectionResult(this.endpointId, NearbyConnectionStatus.rejected));
  }

  @override
  Future<void> sendBytes(String endpointId, Uint8List bytes) async {
    calls.add('sendBytes');
    final other = air._byId(endpointId);
    final link = other == null ? null : air._linkOf(this, other);
    if (link == null || other == null || !link.connected) {
      throw const NearbyApiException(NearbyErrorKind.unknown, '8005: STATUS_NOT_CONNECTED_TO_ENDPOINT');
    }
    if (bytes.length > maxPayloadBytes) throw const NearbyApiException(NearbyErrorKind.unknown, 'payload too large');
    air.wire.add((this.endpointId, other.endpointId, Uint8List.fromList(bytes)));
    if (air._holding.contains(this.endpointId)) {
      (air._held[this.endpointId] ??= []).add((other, Uint8List.fromList(bytes)));
      return;
    }
    final copies = air.duplicateNext > 0 ? 2 : 1;
    if (air.duplicateNext > 0) air.duplicateNext--;
    for (var i = 0; i < copies; i++) {
      other._emit(
        NearbyPayloadReceived(this.endpointId, payloadId: air._random.nextInt(1 << 30), kind: NearbyPayloadKind.bytes, bytes: Uint8List.fromList(bytes)),
      );
    }
  }

  /// A file payload from [from] (never accepted by the transport).
  void receiveFile(FakeNearbyApi from, int payloadId) =>
      _emit(NearbyPayloadReceived(from.endpointId, payloadId: payloadId, kind: NearbyPayloadKind.file));

  /// Raw bytes from [from] (as if sent).
  void receiveBytes(FakeNearbyApi from, Uint8List bytes) =>
      _emit(NearbyPayloadReceived(from.endpointId, payloadId: 1, kind: NearbyPayloadKind.bytes, bytes: bytes));

  @override
  Future<void> cancelPayload(int payloadId) async {
    calls.add('cancelPayload');
    cancelled.add(payloadId);
  }

  @override
  Future<void> disconnect(String endpointId) async {
    calls.add('disconnect');
    final other = air._byId(endpointId);
    if (other != null) air.cut(this, other);
  }

  @override
  Future<void> stopAllEndpoints() async {
    calls.add('stopAllEndpoints');
    for (final l in List.of(air._links)) {
      if (l.involves(this)) air.cut(l.a, l.b);
    }
  }
}

/// Scripted Nearby permissions.
class FakeNearbyPermissions implements NearbyPermissions {
  FakeNearbyPermissions({
    this.status = NearbyPermissionStatus.granted,
    this.afterRequest = NearbyPermissionStatus.granted,
    this.needValue = NearbyPermissionNeed.nearbyDevices,
  });

  NearbyPermissionStatus status;
  NearbyPermissionStatus afterRequest;
  NearbyPermissionNeed needValue;
  int requests = 0;
  int appSettings = 0;
  int locationSettings = 0;

  @override
  Future<NearbyPermissionNeed> need() async => needValue;

  @override
  Future<NearbyPermissionStatus> check() async => status;

  @override
  Future<NearbyPermissionStatus> request() async {
    requests++;
    status = afterRequest;
    return status;
  }

  @override
  Future<void> openAppSettings() async => appSettings++;

  @override
  Future<void> openLocationSettings() async => locationSettings++;
}

// -------------------------------------------------------------------- RTDB

/// One logged write: the path and the value written (server times resolved;
/// null for a deletion).
typedef RtdbWrite = ({String uid, String path, Object? value});

/// An in-memory Realtime Database enforcing the online-play rules.
class FakeRtdb {
  FakeRtdb({DateTime? now}) : nowMs = (now ?? DateTime.utc(2026, 9, 30, 18)).millisecondsSinceEpoch;

  /// The server clock (ms).
  int nowMs;

  Map<String, Object?> root = {};

  /// Every accepted write.
  final List<RtdbWrite> writes = [];

  /// Every refused write (rules).
  final List<RtdbWrite> refused = [];

  final List<FakeRtdbClient> clients = [];
  int _pushCounter = 0;

  /// Anonymous sign-in off in the project.
  bool anonymousAuthEnabled = true;

  /// The rules are the online-play rules (false: Firebase's locked default).
  bool rulesInstalled = true;

  void advance(Duration d) {
    nowMs += d.inMilliseconds;
    _notify();
  }

  FakeRtdbClient client({String? uid}) {
    final c = FakeRtdbClient._(this, uid ?? 'uid${clients.length + 1}');
    clients.add(c);
    return c;
  }

  // -------------------------------------------------------------- the tree

  static List<String> _split(String path) => path.split('/').where((s) => s.isNotEmpty).toList();

  static Object? _get(Object? node, List<String> path) {
    var n = node;
    for (final k in path) {
      if (n is! Map) return null;
      n = n[k];
    }
    return n;
  }

  static Object? _deepCopy(Object? v) => v == null ? null : jsonDecode(jsonEncode(v));

  Object? _resolve(Object? v) {
    if (v is Map && v.length == 1 && v['.sv'] == 'timestamp') return nowMs;
    if (v is Map) {
      final out = <String, Object?>{};
      for (final e in v.entries) {
        final r = _resolve(e.value);
        if (r != null) out['${e.key}'] = r;
      }
      return out.isEmpty ? null : out;
    }
    if (v is List) return [for (final e in v) _resolve(e)];
    return v;
  }

  static Map<String, Object?> _with(Map<String, Object?> tree, List<String> path, Object? value) {
    final copy = (_deepCopy(tree) as Map<String, Object?>?) ?? <String, Object?>{};
    if (path.isEmpty) return (value as Map<String, Object?>?) ?? {};
    var n = copy;
    for (var i = 0; i < path.length - 1; i++) {
      final next = n[path[i]];
      if (next is Map<String, Object?>) {
        n = next;
      } else {
        final m = <String, Object?>{};
        n[path[i]] = m;
        n = m;
      }
    }
    if (value == null) {
      n.remove(path.last);
    } else {
      n[path.last] = _deepCopy(value);
    }
    return _prune(copy) ?? {};
  }

  static Map<String, Object?>? _prune(Map<String, Object?> m) {
    for (final k in m.keys.toList()) {
      final v = m[k];
      if (v is Map<String, Object?>) {
        final p = _prune(v);
        if (p == null) {
          m.remove(k);
        } else {
          m[k] = p;
        }
      }
    }
    return m.isEmpty ? null : m;
  }

  // ------------------------------------------------------------- the rules

  static final RegExp _code = RegExp(r'^[0-9]{6}$');
  static final RegExp _game = RegExp(r'^[A-Za-z0-9_-]+$');
  static final RegExp _frame = RegExp(
    r'^[{]"p":"madar[.]together","v":1,"sid":"[A-Za-z0-9_-]+","k":"(hello|start|move|input|snapshot|sync|resync|result|bye)",',
  );
  static const int _sixHours = 21600000;

  bool canRead(String? uid, String path) {
    if (!rulesInstalled || uid == null) return false;
    final p = _split(path);
    if (p.length < 2 || p[0] != 'rooms') return false;
    final room = _get(root, ['rooms', p[1]]);
    if (room is! Map) return true;
    if (room['h'] == uid || room['g'] == uid) return true;
    return p.length >= 3 && (p[2] == 'gm' || p[2] == 'x');
  }

  bool _canWrite(String uid, List<String> p, Map<String, Object?> newRoot) {
    if (!rulesInstalled || p.length < 2 || p[0] != 'rooms') return false;
    final code = p[1];
    final data = _get(root, ['rooms', code]);
    final newData = _get(newRoot, ['rooms', code]);
    final now = nowMs;
    num? x(Object? r) => r is Map && r['x'] is num ? r['x'] as num : null;
    // Room level.
    if (_code.hasMatch(code)) {
      if (newData is Map) {
        final free = data is! Map || (x(data) ?? 0) < now;
        if (free &&
            newData['h'] == uid &&
            !newData.containsKey('g') &&
            !newData.containsKey('ok') &&
            !newData.containsKey('pg') &&
            !newData.containsKey('f')) {
          return true;
        }
      } else if (data is Map && (data['h'] == uid || data['g'] == uid || (x(data) ?? 0) < now)) {
        return true;
      }
    }
    if (p.length < 3 || data is! Map) return false;
    final nd = newData is Map ? newData : const {};
    switch (p[2]) {
      case 'x':
        return x(data) != null && x(data)! >= now && (nd['h'] == uid || nd['g'] == uid);
      case 'g':
        return data['g'] == null && nd['g'] == uid && data['h'] != uid && (x(data) ?? 0) >= now;
      case 'ok':
        return data['h'] == uid && data.containsKey('g');
      case 'pg':
        return data['pg'] == null && nd['g'] == uid;
      case 'f':
        if (p.length < 4 || (x(data) ?? 0) < now) return false;
        final before = _get(data, ['f', p[3]]);
        final after = _get(nd, ['f', p[3]]);
        if (before == null && after is Map) {
          final s = after['s'];
          return (s == 0 && data['h'] == uid) || (s == 1 && data['g'] == uid);
        }
        if (after == null) return data['h'] == uid || data['g'] == uid;
        return false;
    }
    return false;
  }

  bool _profileOk(Object? v) {
    if (v is! Map) return false;
    if (v.keys.any((k) => k != 'n' && k != 'a' && k != 'k')) return false;
    final n = v['n'];
    final a = v['a'];
    final k = v['k'];
    return n is String && n.isNotEmpty && n.length <= 48 && a is String && a.length <= 32 && k is num && k >= 0 && k <= 15;
  }

  bool _frameOk(Object? v) {
    if (v is! Map) return false;
    if (v.keys.any((k) => k != 's' && k != 't' && k != 'at')) return false;
    final t = v['t'];
    return (v['s'] == 0 || v['s'] == 1) && t is String && t.length <= 262144 && _frame.hasMatch(t) && v['at'] == nowMs;
  }

  bool _validate(Map<String, Object?> newRoot, List<List<String>> written) {
    for (final p in written) {
      if (p.length < 2) return false;
      final room = _get(newRoot, ['rooms', p[1]]);
      if (room is! Map) continue; // deleted
      for (final k in ['h', 'v', 'gm', 'c', 'x']) {
        if (!room.containsKey(k)) return false;
      }
      final touched = p.length == 2 ? room.keys.cast<String>().toList() : [p[2]];
      for (final k in touched) {
        final v = room[k];
        if (v == null) continue;
        final ok = switch (k) {
          'h' || 'g' => v is String && v.length <= 128,
          'v' => v == 1,
          'gm' => v is String && v.length <= 40 && _game.hasMatch(v),
          'c' => v is num && v <= nowMs,
          'x' => v is num && v > nowMs && v <= nowMs + _sixHours,
          'ok' => v == true,
          'ph' || 'pg' => _profileOk(v),
          'f' => v is Map && (p.length >= 4 ? _frameOk(v[p[3]]) || v[p[3]] == null : v.values.every(_frameOk)),
          _ => false,
        };
        if (!ok) return false;
      }
    }
    return true;
  }

  /// Applies [changes] (path → value) atomically if the rules allow them all.
  bool _write(String uid, Map<String, Object?> changes) {
    var next = root;
    final written = <List<String>>[];
    final resolved = <String, Object?>{};
    for (final e in changes.entries) {
      final p = _split(e.key);
      final v = _resolve(e.value);
      resolved[e.key] = v;
      next = _with(next, p, v);
      written.add(p);
    }
    final allowed = written.every((p) => _canWrite(uid, p, next)) && _validate(next, written);
    for (final e in resolved.entries) {
      (allowed ? writes : refused).add((uid: uid, path: e.key, value: e.value));
    }
    if (!allowed) return false;
    root = next;
    _notify();
    return true;
  }

  String _pushKey() => '-N${(_pushCounter++).toString().padLeft(8, '0')}';

  void _notify() {
    for (final c in List.of(clients)) {
      c._refresh();
    }
  }

  /// The room of [code] (for assertions).
  Map<String, Object?>? room(String code) => _get(root, ['rooms', code]) as Map<String, Object?>?;
}

class _Listener {
  _Listener(this.path, this.children, this.controller);

  final String path;
  final bool children;
  final StreamController<Object?> controller;
  final Set<String> seen = {};
  String? lastJson;
  bool started = false;
}

class FakeRtdbClient implements RtdbClient {
  FakeRtdbClient._(this.db, this._uid);

  final FakeRtdb db;
  final String _uid;
  bool _signedIn = false;
  final ValueNotifier<bool> _connected = ValueNotifier(true);
  final List<_Listener> _listeners = [];
  final List<(Completer<void>, void Function())> _queued = [];
  bool closedCalled = false;

  @override
  String? get uid => _signedIn ? _uid : null;

  @override
  ValueListenable<bool> get connected => _connected;

  bool get online => _connected.value;

  /// Loses / regains the connection (writes queue meanwhile, as in Firebase).
  void goOffline() => _connected.value = false;

  void goOnline() {
    _connected.value = true;
    final queued = List.of(_queued);
    _queued.clear();
    for (final (done, run) in queued) {
      run();
      done.complete();
    }
    _refresh();
  }

  @override
  DateTime serverNow() => DateTime.fromMillisecondsSinceEpoch(db.nowMs);

  @override
  Future<String> signIn() async {
    if (!db.anonymousAuthEnabled) throw const RtdbException(RtdbErrorKind.signIn, 'operation-not-allowed');
    _signedIn = true;
    return _uid;
  }

  void _requireSignIn() {
    if (!_signedIn) throw const RtdbException(RtdbErrorKind.permissionDenied, 'not signed in');
  }

  @override
  Future<Object?> read(String path) async {
    _requireSignIn();
    if (!online) throw const RtdbException(RtdbErrorKind.network);
    if (!db.canRead(_uid, path)) throw const RtdbException(RtdbErrorKind.permissionDenied);
    return FakeRtdb._deepCopy(FakeRtdb._get(db.root, FakeRtdb._split(path)));
  }

  Future<void> _apply(Map<String, Object?> changes) {
    _requireSignIn();
    void run() {
      if (!db._write(_uid, changes)) throw const RtdbException(RtdbErrorKind.permissionDenied);
    }

    if (online) {
      try {
        run();
      } on RtdbException catch (e) {
        return Future.error(e);
      }
      return Future.value();
    }
    final done = Completer<void>();
    _queued.add((
      done,
      () {
        try {
          db._write(_uid, changes);
        } on Object {
          // Refused later: dropped, like Firebase's rejected queued write.
        }
      },
    ));
    return done.future;
  }

  @override
  Future<void> set(String path, Object? value) => _apply({path: value});

  @override
  Future<void> update(String path, Map<String, Object?> values) =>
      _apply({for (final e in values.entries) '$path/${e.key}': e.value});

  @override
  Future<String> push(String path, Object? value) async {
    final key = db._pushKey();
    await _apply({'$path/$key': value});
    return key;
  }

  @override
  Future<void> remove(String path) => _apply({path: null});

  Stream<Object?> _listen(String path, {required bool children}) {
    late final _Listener l;
    final controller = StreamController<Object?>(
      onListen: () => scheduleMicrotask(() => _refreshOne(l)),
      onCancel: () => _listeners.remove(l),
    );
    l = _Listener(path, children, controller);
    _listeners.add(l);
    return controller.stream;
  }

  @override
  Stream<RtdbChild> childAdded(String path) => _listen(path, children: true).cast<RtdbChild>();

  @override
  Stream<Object?> watch(String path) => _listen(path, children: false);

  void _refresh() {
    for (final l in List.of(_listeners)) {
      _refreshOne(l);
    }
  }

  void _refreshOne(_Listener l) {
    if (!online || l.controller.isClosed || !l.controller.hasListener) return;
    if (!db.canRead(_uid, l.path)) {
      l.controller.addError(const RtdbException(RtdbErrorKind.permissionDenied));
      _listeners.remove(l);
      unawaited(l.controller.close());
      return;
    }
    final value = FakeRtdb._get(db.root, FakeRtdb._split(l.path));
    if (l.children) {
      if (value is! Map) return;
      final keys = value.keys.cast<String>().toList()..sort();
      for (final k in keys) {
        if (l.seen.add(k)) l.controller.add(RtdbChild(k, FakeRtdb._deepCopy(value[k])));
      }
      return;
    }
    final json = jsonEncode(value);
    if (l.started && json == l.lastJson) return;
    l.started = true;
    l.lastJson = json;
    l.controller.add(FakeRtdb._deepCopy(value));
  }

  @override
  Future<void> close() async {
    closedCalled = true;
    for (final l in List.of(_listeners)) {
      await l.controller.close();
    }
    _listeners.clear();
  }
}

/// A random with a fixed sequence of codes for room creation.
class ScriptedRandom implements math.Random {
  ScriptedRandom(this.values);

  final List<int> values;
  var _i = 0;

  @override
  int nextInt(int max) => values[_i++ % values.length] % max;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.5;
}
