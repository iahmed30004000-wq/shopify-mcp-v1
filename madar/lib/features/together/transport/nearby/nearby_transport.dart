/// Two phones side by side over Google Nearby Connections – Bluetooth and
/// Wi-Fi Direct, no internet, no router, no server.
///
/// * **Pairing** – nothing is advertised or discovered until the player taps
///   "Play together" ([playTogether]); both phones then advertise *and*
///   discover the same service id (the app id, the protocol version and the
///   game – only phones opening the same game find each other). The endpoint
///   name is the player's display name, nothing else. A single phone found is
///   connected to automatically (with a little jitter so the two requests
///   rarely cross – Nearby breaks the tie when they do); several are listed.
///   Both phones then show the same four digits and each player confirms.
/// * **Roles** – the phone whose connection request won hosts
///   (participant 0), the other is the guest; the roles stay for the whole
///   game, reconnections included.
/// * **Radios** – advertising and discovery stop as soon as the phones are
///   paired, when the transport closes, and while the app is in the
///   background (they resume when it returns).
/// * **Reconnection** – a dropped link searches for the same partner (by
///   display name) for [NearbyTransport.reconnectGrace] and re-connects
///   without a second confirmation; then it reports [PairingPhase.lost].
/// * **Payloads** – only the frames' JSON bytes, cut to Nearby's 32 KiB
///   BYTES limit ([FrameChunks]); files and streams from the peer are
///   cancelled unread.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../domain/play_modes.dart';
import '../../domain/together_bounds.dart';
import '../../protocol/envelope.dart';
import '../../protocol/session.dart';
import '../../protocol/transport.dart';
import '../frame_chunks.dart';
import '../pairing_state.dart';
import 'nearby_api.dart';
import 'nearby_permissions.dart';

/// The Nearby service id of a game: derived from the app id.
abstract final class NearbyService {
  static const String appId = 'app.madar.orbit';

  static String idFor(String gameId) => '$appId.together.v${TogetherProtocol.version}.$gameId';
}

/// The four digits both phones show for a Nearby authentication token (the
/// token itself when it already is four digits).
abstract final class NearbyAuthDigits {
  static final RegExp _four = RegExp(r'^[0-9]{4}$');

  static String of(String token) {
    final t = token.trim();
    if (_four.hasMatch(t)) return t;
    // FNV-1a: the same token gives the same digits on both phones.
    var h = 0x811c9dc5;
    for (final c in t.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return (h % 10000).toString().padLeft(4, '0');
  }
}

final ValueNotifier<bool> _alwaysForeground = ValueNotifier(true);

class NearbyTransport extends PairingTransportBase {
  NearbyTransport({
    required this.api,
    required this.permissions,
    required this.request,
    ValueListenable<bool>? foreground,
    this.reconnectGrace = const Duration(seconds: 45),
    this.autoConnectDelay = const Duration(milliseconds: 400),
    this.connectTimeout = const Duration(seconds: 20),
    DateTime Function()? clock,
    math.Random? random,
  }) : _foreground = foreground ?? _alwaysForeground,
       _clock = clock ?? DateTime.now,
       _random = random ?? math.Random(),
       _reassembler = FrameReassembler(chunkSize: api.maxPayloadBytes),
       super(mode: PlayMode.nearby) {
    _events = api.events.listen(_onEvent);
    _foreground.addListener(_onForeground);
  }

  final NearbyApi api;
  final NearbyPermissions permissions;
  final TransportRequest request;

  /// How long a dropped partner is looked for.
  final Duration reconnectGrace;

  /// The (jittered) pause before connecting to the one phone found.
  final Duration autoConnectDelay;

  /// A requested connection that never starts is given up after this.
  final Duration connectTimeout;

  final ValueListenable<bool> _foreground;
  final DateTime Function() _clock;
  final math.Random _random;
  final FrameReassembler _reassembler;
  StreamSubscription<NearbyEvent>? _events;

  PairingIdentity? _me;

  /// Phones found while searching (endpoint → display name).
  final Map<String, String> _found = {};

  /// Endpoints the player declined in this search.
  final Set<String> _declined = {};

  /// The endpoint this phone asked to connect to.
  String? _requested;

  /// The endpoint whose connection is being set up (confirm / accept).
  String? _initiating;
  String _initiatingName = '';
  String _initiatingToken = '';
  bool _initiatingIncoming = false;

  /// The connected partner's endpoint.
  String? _endpoint;

  bool _wantRadios = false;
  bool _advertising = false;
  bool _discovering = false;
  Timer? _autoTimer;
  Timer? _connectTimer;
  Timer? _graceTimer;
  Future<void> _sendChain = Future<void>.value();

  String get serviceId => NearbyService.idFor(request.gameId);

  /// This phone's player (after [playTogether]).
  PairingIdentity? get identity => _me;

  @visibleForTesting
  bool get advertising => _advertising;

  @visibleForTesting
  bool get discovering => _discovering;

  // ------------------------------------------------------------ the player

  /// "Play together": checks the permissions (the rationale comes first when
  /// one is missing), then advertises and discovers.
  Future<void> playTogether(PairingIdentity me) async {
    if (closed) return;
    _me = me;
    if (roleValue != null) return;
    switch (state.phase) {
      case PairingPhase.searching ||
          PairingPhase.connecting ||
          PairingPhase.confirm ||
          PairingPhase.waitingForPeer ||
          PairingPhase.connected:
        return;
      default:
        await _checkAndSearch();
    }
  }

  /// After the rationale: Android's permission dialog, then the search.
  Future<void> grantPermissions() async {
    if (closed || _me == null) return;
    final NearbyPermissionStatus status;
    try {
      status = await permissions.request();
    } on Object {
      setPairing(PairingState(PairingPhase.permissionDenied, need: await permissions.need()));
      return;
    }
    if (closed) return;
    await _afterCheck(status, asked: true);
  }

  /// Location services are off (Android 12L and older): search anyway –
  /// Bluetooth may still find the partner.
  Future<void> searchAnyway() async {
    if (closed || _me == null || state.phase != PairingPhase.serviceOff) return;
    await _startSearching();
  }

  /// The system page that can fix [PairingPhase.permissionDenied] /
  /// [PairingPhase.serviceOff].
  Future<void> openSettings() async {
    try {
      if (state.phase == PairingPhase.serviceOff) {
        await permissions.openLocationSettings();
      } else {
        await permissions.openAppSettings();
      }
    } on Object {
      // Nothing to open on this device.
    }
  }

  /// Connects to one of several phones found.
  void connectTo(String endpointId) {
    if (closed || state.phase != PairingPhase.searching || !_found.containsKey(endpointId)) return;
    _autoTimer?.cancel();
    _request(endpointId);
  }

  /// "The digits match".
  Future<void> confirmToken() async {
    if (closed || state.phase != PairingPhase.confirm || _initiating == null) return;
    setPairing(PairingState(PairingPhase.waitingForPeer, peer: state.peer, token: state.token));
    await _accept();
  }

  /// "They don't match": refuses that phone and searches on.
  Future<void> declineToken() async {
    final id = _initiating;
    if (closed || state.phase != PairingPhase.confirm || id == null) return;
    _initiating = null;
    _declined.add(id);
    await _quietly(() => api.rejectConnection(id));
    _backToSearching();
  }

  /// Starts over after [PairingPhase.failed] / [PairingPhase.lost] /
  /// [PairingPhase.permissionDenied].
  Future<void> searchAgain() async {
    if (closed || _me == null) return;
    if (roleValue != null) {
      if (state.phase == PairingPhase.lost || state.phase == PairingPhase.failed) _startReconnecting();
      return;
    }
    _declined.clear();
    await _checkAndSearch();
  }

  // ---------------------------------------------------------- permissions

  Future<void> _checkAndSearch() async {
    NearbyPermissionStatus status;
    try {
      status = await permissions.check();
    } on Object {
      status = NearbyPermissionStatus.needed;
    }
    if (closed) return;
    await _afterCheck(status, asked: false);
  }

  Future<void> _afterCheck(NearbyPermissionStatus status, {required bool asked}) async {
    switch (status) {
      case NearbyPermissionStatus.granted:
        await _startSearching();
      case NearbyPermissionStatus.needed:
        final need = await permissions.need();
        if (closed) return;
        setPairing(PairingState(asked ? PairingPhase.permissionDenied : PairingPhase.needsPermission, need: need));
      case NearbyPermissionStatus.permanentlyDenied:
        final need = await permissions.need();
        if (closed) return;
        setPairing(PairingState(PairingPhase.permissionDenied, need: need, permanentlyDenied: true));
      case NearbyPermissionStatus.serviceOff:
        setPairing(const PairingState(PairingPhase.serviceOff));
    }
  }

  // --------------------------------------------------------------- radios

  Future<void> _startSearching() async {
    _found.clear();
    _requested = null;
    _initiating = null;
    setPairing(PairingState(PairingPhase.searching, paused: !_foreground.value));
    await _radiosOn();
  }

  Future<void> _radiosOn() async {
    _wantRadios = true;
    final me = _me;
    if (closed || me == null || !_foreground.value) return;
    try {
      if (!_advertising) {
        _advertising = true;
        await api.startAdvertising(name: me.name, serviceId: serviceId);
      }
      if (!_discovering) {
        _discovering = true;
        await api.startDiscovery(name: me.name, serviceId: serviceId);
      }
    } on NearbyApiException catch (e) {
      if (e.kind == NearbyErrorKind.alreadyActive || closed) return;
      await _radiosOff();
      if (e.kind == NearbyErrorKind.permission) {
        setPairing(PairingState(PairingPhase.permissionDenied, need: await permissions.need()));
      } else {
        setPairing(
          PairingState(
            PairingPhase.failed,
            failure: e.kind == NearbyErrorKind.radio ? PairingFailure.radioOff : PairingFailure.unknown,
            peer: peerValue,
          ),
        );
      }
    }
  }

  Future<void> _radiosOff({bool keepWanted = false}) async {
    if (!keepWanted) _wantRadios = false;
    _autoTimer?.cancel();
    if (_advertising) {
      _advertising = false;
      await _quietly(api.stopAdvertising);
    }
    if (_discovering) {
      _discovering = false;
      await _quietly(api.stopDiscovery);
    }
  }

  void _onForeground() {
    if (closed) return;
    if (!_foreground.value) {
      if (_advertising || _discovering) unawaited(_radiosOff(keepWanted: true));
      if (_wantRadios) setPairing(state.copyWith(paused: true));
    } else if (_wantRadios) {
      setPairing(state.copyWith(paused: false));
      unawaited(_radiosOn());
    }
  }

  // --------------------------------------------------------------- events

  void _onEvent(NearbyEvent e) {
    if (closed) return;
    switch (e) {
      case NearbyEndpointFound():
        _onFound(e);
      case NearbyEndpointLost():
        _onLost(e.endpointId);
      case NearbyConnectionInitiated():
        unawaited(_onInitiated(e));
      case NearbyConnectionResult():
        unawaited(_onResult(e));
      case NearbyDisconnected():
        _onDisconnected(e.endpointId);
      case NearbyPayloadReceived():
        _onPayload(e);
    }
  }

  static String _clean(String name) {
    final clean = TogetherBounds.cleanText(name, TogetherBounds.maxNameLength);
    return clean.isEmpty ? '?' : clean;
  }

  List<PairingPeer> get _candidates => [
    for (final e in _found.entries)
      if (!_declined.contains(e.key)) PairingPeer(id: e.key, name: e.value),
  ];

  void _publishFound() =>
      setPairing(PairingState(PairingPhase.searching, found: _candidates, paused: !_foreground.value));

  void _onFound(NearbyEndpointFound e) {
    if (!_wantRadios || e.serviceId != serviceId) return;
    final name = _clean(e.name);
    _found[e.endpointId] = name;
    switch (state.phase) {
      case PairingPhase.reconnecting:
        if (name == peerValue?.name && _requested == null && _initiating == null) _request(e.endpointId);
      case PairingPhase.searching:
        _publishFound();
        _scheduleAutoConnect();
      default:
        break;
    }
  }

  void _onLost(String id) {
    if (_found.remove(id) == null) return;
    if (state.phase == PairingPhase.searching) _publishFound();
  }

  void _scheduleAutoConnect() {
    _autoTimer?.cancel();
    final candidates = _candidates;
    if (candidates.length != 1 || _requested != null || _initiating != null) return;
    final id = candidates.single.id;
    final delay = autoConnectDelay * (0.5 + _random.nextDouble());
    _autoTimer = Timer(delay, () {
      if (closed || state.phase != PairingPhase.searching) return;
      if (_requested != null || _initiating != null || !_found.containsKey(id)) return;
      _request(id);
    });
  }

  void _request(String id) {
    final me = _me;
    if (me == null) return;
    _requested = id;
    if (state.phase == PairingPhase.searching) {
      setPairing(
        PairingState(
          PairingPhase.connecting,
          peer: PairingPeer(id: id, name: _found[id] ?? '?'),
        ),
      );
    }
    _connectTimer?.cancel();
    _connectTimer = Timer(connectTimeout, () => _onConnectTimeout(id));
    unawaited(_requestAsync(me.name, id));
  }

  Future<void> _requestAsync(String name, String id) async {
    try {
      await api.requestConnection(name: name, endpointId: id);
    } on NearbyApiException catch (e) {
      if (e.kind == NearbyErrorKind.alreadyConnected || _requested != id) return;
      _requested = null;
      _connectTimer?.cancel();
      // A crossed request the peer won arrives as an incoming initiation.
      if (_initiating == null) _backToSearching();
    }
  }

  void _onConnectTimeout(String id) {
    if (closed || _requested != id || _initiating != null) return;
    _backToSearching();
  }

  void _backToSearching() {
    _requested = null;
    _initiating = null;
    _connectTimer?.cancel();
    if (closed) return;
    if (roleValue != null) {
      // Reconnecting: discovery reports a phone only once – start it again so
      // the partner is found (and asked) anew.
      if (state.phase == PairingPhase.reconnecting) unawaited(_restartRadios());
      return;
    }
    _publishFound();
    _scheduleAutoConnect();
  }

  Future<void> _restartRadios() async {
    _found.clear();
    await _radiosOff(keepWanted: true);
    if (!closed && state.phase == PairingPhase.reconnecting) await _radiosOn();
  }

  Future<void> _onInitiated(NearbyConnectionInitiated e) async {
    final name = _clean(e.name);
    final reconnecting = state.phase == PairingPhase.reconnecting;
    final busy = (_initiating != null && _initiating != e.endpointId) || _endpoint != null;
    final unexpected = roleValue != null && !reconnecting;
    final stranger = reconnecting && name != peerValue?.name;
    if (busy || unexpected || stranger || _declined.contains(e.endpointId) || _me == null) {
      await _quietly(() => api.rejectConnection(e.endpointId));
      return;
    }
    _autoTimer?.cancel();
    _connectTimer?.cancel();
    _requested = null;
    _initiating = e.endpointId;
    _initiatingName = name;
    _initiatingIncoming = e.incoming;
    _initiatingToken = NearbyAuthDigits.of(e.token);
    if (reconnecting) {
      // The same partner coming back within the grace period.
      await _accept();
      return;
    }
    setPairing(
      PairingState(
        PairingPhase.confirm,
        peer: PairingPeer(id: e.endpointId, name: name),
        token: _initiatingToken,
      ),
    );
  }

  Future<void> _accept() async {
    final id = _initiating;
    if (id == null) return;
    try {
      await api.acceptConnection(id);
    } on NearbyApiException {
      if (_initiating == id) _backToSearching();
    }
  }

  Future<void> _onResult(NearbyConnectionResult e) async {
    if (e.endpointId != _initiating) return;
    _initiating = null;
    switch (e.status) {
      case NearbyConnectionStatus.connected:
        _endpoint = e.endpointId;
        roleValue ??= _initiatingIncoming ? SessionRole.guest : SessionRole.host;
        peerValue = PairingPeer(id: e.endpointId, name: _initiatingName);
        _graceTimer?.cancel();
        _connectTimer?.cancel();
        _reassembler.reset();
        await _radiosOff();
        if (closed) return;
        setStatus(TransportStatus.connected);
        setPairing(PairingState(PairingPhase.connected, peer: peerValue, role: roleValue, token: _initiatingToken));
      case NearbyConnectionStatus.rejected:
        if (state.phase == PairingPhase.reconnecting) return;
        final peer = state.peer;
        await _radiosOff();
        setPairing(PairingState(PairingPhase.failed, failure: PairingFailure.declinedByPeer, peer: peer));
      case NearbyConnectionStatus.error:
        _backToSearching();
    }
  }

  void _onDisconnected(String id) {
    if (id == _initiating) {
      _initiating = null;
      _backToSearching();
      return;
    }
    if (id != _endpoint) return;
    _endpoint = null;
    _reassembler.reset();
    setStatus(TransportStatus.disconnected);
    _startReconnecting();
  }

  void _startReconnecting() {
    _found.clear();
    _requested = null;
    _initiating = null;
    setPairing(
      PairingState(
        PairingPhase.reconnecting,
        peer: peerValue,
        role: roleValue,
        until: _clock().add(reconnectGrace),
        paused: !_foreground.value,
      ),
    );
    _graceTimer?.cancel();
    _graceTimer = Timer(reconnectGrace, _onGraceOver);
    unawaited(_radiosOn());
  }

  void _onGraceOver() {
    if (closed || state.phase != PairingPhase.reconnecting) return;
    unawaited(_radiosOff());
    setPairing(PairingState(PairingPhase.lost, peer: peerValue, role: roleValue));
  }

  void _onPayload(NearbyPayloadReceived e) {
    if (e.kind != NearbyPayloadKind.bytes) {
      // Files and streams are never taken: cancelled unread.
      unawaited(_quietly(() => api.cancelPayload(e.payloadId)));
      return;
    }
    final bytes = e.bytes;
    if (e.endpointId != _endpoint || bytes == null) return;
    final text = _reassembler.add(bytes);
    if (text != null) deliver(text);
  }

  // ------------------------------------------------------------ transport

  @override
  Future<void> send(TogetherFrame frame) {
    final id = _endpoint;
    if (closed || id == null || status.value != TransportStatus.connected) return Future<void>.value();
    final chunks = FrameChunks.ofText(frame.text, api.maxPayloadBytes);
    final next = _sendChain.then((_) async {
      for (final chunk in chunks) {
        if (_endpoint != id) return;
        try {
          await api.sendBytes(id, chunk);
        } on Object {
          return; // lost: the session's sync recovers it
        }
      }
    });
    _sendChain = next;
    return next;
  }

  Future<void>? _closing;

  /// Leaves (idempotent: every call waits for the same clean-up).
  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    if (!markClosed()) return;
    _autoTimer?.cancel();
    _connectTimer?.cancel();
    _graceTimer?.cancel();
    _foreground.removeListener(_onForeground);
    // Let the session's last frames (its `bye`) go out first.
    try {
      await _sendChain.timeout(const Duration(seconds: 2));
    } on Object {
      // Gone or stuck: leave anyway.
    }
    await _events?.cancel();
    await _radiosOff();
    final id = _endpoint ?? _initiating;
    _endpoint = null;
    _initiating = null;
    if (id != null) await _quietly(() => api.disconnect(id));
    await _quietly(api.stopAllEndpoints);
    await finishClose();
  }

  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } on Object {
      // Best effort: the radios may already be off.
    }
  }
}
