/// Pairing two phones: the states both two-phone transports move through,
/// the peer, this phone's player, and the base every pairable transport is
/// built on (status, the peer's frames, the role decided by the pairing).
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../domain/play_modes.dart';
import '../domain/player_profile.dart';
import '../domain/together_bounds.dart';
import '../protocol/envelope.dart';
import '../protocol/session.dart';
import '../protocol/transport.dart';

/// Where a pairing is.
enum PairingPhase {
  /// Nothing started ("Play together" / "Create a code" not tapped yet).
  idle,

  /// Nearby: the rationale is shown before Android's permission dialog.
  needsPermission,

  /// Nearby: the permission was refused ([PairingState.permanentlyDenied]:
  /// only the system settings can grant it now).
  permissionDenied,

  /// Nearby, Android 12L and older: location services are off (Bluetooth
  /// and Wi-Fi scans need them there).
  serviceOff,

  /// Online: no Firebase project entered, or online play turned off.
  needsSetup,

  /// Online: starting Firebase and signing in anonymously.
  signingIn,

  /// Nearby: advertising and discovering ([PairingState.found]).
  searching,

  /// Online host: the code is shown, waiting for the partner to type it.
  hosting,

  /// Online guest: checking and claiming the typed code.
  joining,

  /// Nearby: a connection was requested to [PairingState.peer].
  connecting,

  /// Confirm the peer – nearby: the four digits shown on both phones;
  /// online host: the partner who typed the code.
  confirm,

  /// This phone confirmed; the other one has not yet.
  waitingForPeer,

  connected,

  /// Nearby: the link dropped; searching for the same partner again until
  /// [PairingState.until].
  reconnecting,

  /// Nearby: the grace period ended without the partner.
  lost,

  failed,

  /// Closed (left, cancelled or disposed).
  closed,
}

/// Why a pairing failed.
enum PairingFailure {
  /// Bluetooth / Wi-Fi off or busy.
  radioOff,

  /// The partner's phone declined (the digits did not match, or the host
  /// declined the guest).
  declinedByPeer,

  /// Online: no open room with this code.
  notFound,

  /// Online: the code is too old.
  expired,

  /// Online: someone else already joined with this code.
  taken,

  /// Online: the code is for another game.
  differentGame,

  /// No connection to the online service.
  network,

  /// Online: Firebase refused the project settings (API key, app id…).
  setup,

  /// Online: anonymous sign-in failed (off in the Firebase project?).
  signIn,

  /// Online: the database refused access – the security rules are missing
  /// or different.
  rules,

  /// The partner left.
  peerLeft,

  unknown,
}

/// What a nearby pairing needs from Android before it can search.
enum NearbyPermissionNeed {
  /// Bluetooth scan / advertise / connect and nearby Wi-Fi devices – the
  /// "Nearby devices" permission (Android 12+).
  nearbyDevices,

  /// Location (Android 11 and older): Android ties Bluetooth and Wi-Fi scans
  /// to it there; Madar never reads the location.
  location,

  /// Both (Android 12 and 12L).
  nearbyDevicesAndLocation,
}

/// The other phone as the pairing shows it. Only a display name, an avatar
/// and a colour – nothing else about the partner ever reaches this phone.
@immutable
final class PairingPeer {
  const PairingPeer({required this.id, required this.name, this.avatar, this.colorIndex});

  /// The transport's handle (a Nearby endpoint id, a Firebase uid) – never
  /// shown.
  final String id;

  /// The partner's display name on their phone (cleaned, bounded).
  final String name;
  final TogetherAvatar? avatar;
  final int? colorIndex;

  @override
  bool operator ==(Object other) =>
      other is PairingPeer &&
      other.id == id &&
      other.name == name &&
      other.avatar == avatar &&
      other.colorIndex == colorIndex;

  @override
  int get hashCode => Object.hash(id, name, avatar, colorIndex);

  @override
  String toString() => 'PairingPeer($name)';
}

/// The player on this phone, as the pairing announces them: the display name
/// (a Nearby endpoint name, or the online room's profile) and, online only,
/// the avatar and colour.
@immutable
final class PairingIdentity {
  const PairingIdentity({required this.slot, required this.rawName, required this.avatar, required this.colorIndex});

  /// [profile] under its [displayName] (the typed name, or the localised
  /// "Player 1" / "Player 2").
  factory PairingIdentity.of(TogetherProfile profile, {required String displayName}) =>
      PairingIdentity(slot: profile.slot, rawName: displayName, avatar: profile.avatar, colorIndex: profile.colorIndex);

  /// This phone's player in the local profiles (each phone keeps both).
  final PlayerSlot slot;

  /// The display name as given (see [name]).
  final String rawName;
  final TogetherAvatar avatar;
  final int colorIndex;

  /// The display name, cleaned and cut to [TogetherBounds.maxNameLength]
  /// characters.
  String get name {
    final clean = TogetherBounds.cleanText(rawName, TogetherBounds.maxNameLength);
    return clean.isEmpty ? '?' : clean;
  }
}

/// One moment of a pairing.
@immutable
final class PairingState {
  const PairingState(
    this.phase, {
    this.peer,
    this.found = const [],
    this.token,
    this.code,
    this.expiresAt,
    this.until,
    this.failure,
    this.need,
    this.permanentlyDenied = false,
    this.paused = false,
    this.role,
  });

  static const PairingState initial = PairingState(PairingPhase.idle);

  final PairingPhase phase;

  /// The partner being confirmed / connected (or lost).
  final PairingPeer? peer;

  /// Nearby, while searching: the phones found so far.
  final List<PairingPeer> found;

  /// Nearby: the four digits both phones show to confirm the pairing.
  final String? token;

  /// Online: the room code.
  final String? code;

  /// Online: when the code stops working.
  final DateTime? expiresAt;

  /// Nearby, reconnecting: when the search for the partner stops.
  final DateTime? until;

  final PairingFailure? failure;

  /// Nearby: which permission the rationale explains.
  final NearbyPermissionNeed? need;
  final bool permanentlyDenied;

  /// Nearby: the app is in the background – the radios are stopped until it
  /// comes back.
  final bool paused;

  /// This phone's side once connected.
  final SessionRole? role;

  bool get isConnected => phase == PairingPhase.connected;

  /// The partner has been found and the pairing is moving (the sheet no
  /// longer offers to start over).
  bool get busy => switch (phase) {
    PairingPhase.signingIn ||
    PairingPhase.joining ||
    PairingPhase.connecting ||
    PairingPhase.confirm ||
    PairingPhase.waitingForPeer => true,
    _ => false,
  };

  PairingState copyWith({bool? paused, List<PairingPeer>? found}) => PairingState(
    phase,
    peer: peer,
    found: found ?? this.found,
    token: token,
    code: code,
    expiresAt: expiresAt,
    until: until,
    failure: failure,
    need: need,
    permanentlyDenied: permanentlyDenied,
    paused: paused ?? this.paused,
    role: role,
  );

  @override
  bool operator ==(Object other) =>
      other is PairingState &&
      other.phase == phase &&
      other.peer == peer &&
      listEquals(other.found, found) &&
      other.token == token &&
      other.code == code &&
      other.expiresAt == expiresAt &&
      other.until == until &&
      other.failure == failure &&
      other.need == need &&
      other.permanentlyDenied == permanentlyDenied &&
      other.paused == paused &&
      other.role == role;

  @override
  int get hashCode => Object.hash(
    phase,
    peer,
    Object.hashAll(found),
    token,
    code,
    expiresAt,
    until,
    failure,
    need,
    permanentlyDenied,
    paused,
    role,
  );

  @override
  String toString() => 'PairingState(${phase.name}${failure == null ? '' : ', ${failure!.name}'})';
}

/// A two-phone transport that pairs before it carries frames. The pairing
/// decides the [role]: the session on this phone must use it.
abstract class PairableTransport implements TogetherTransport {
  ValueListenable<PairingState> get pairing;

  /// Host (participant 0) or guest (participant 1); null before pairing.
  SessionRole? get role;

  /// The partner once confirmed.
  PairingPeer? get peer;
}

/// The plumbing shared by the nearby and online transports: the status, the
/// pairing state, the role and the peer's frames – buffered (a few) until the
/// session subscribes, because the host may start the game before the guest's
/// session exists.
abstract class PairingTransportBase implements PairableTransport {
  PairingTransportBase({required this.mode});

  @override
  final PlayMode mode;

  final ValueNotifier<TransportStatus> _status = ValueNotifier(TransportStatus.connecting);
  final ValueNotifier<PairingState> _pairing = ValueNotifier(PairingState.initial);
  late final StreamController<String> _incoming = StreamController<String>.broadcast(onListen: _flush);
  final ListQueue<String> _early = ListQueue();

  /// Frames kept while no session listens (older ones are dropped: the
  /// session's sync recovers them).
  static const int maxEarlyFrames = 64;

  SessionRole? roleValue;
  PairingPeer? peerValue;
  bool _closed = false;

  bool get closed => _closed;

  @override
  ValueListenable<TransportStatus> get status => _status;

  @override
  ValueListenable<PairingState> get pairing => _pairing;

  @override
  SessionRole? get role => roleValue;

  @override
  PairingPeer? get peer => peerValue;

  @override
  Set<int> get localParticipants => switch (roleValue) {
    SessionRole.host => const {0},
    SessionRole.guest => const {1},
    null => const {},
  };

  @override
  Stream<String> get incoming => _incoming.stream;

  PairingState get state => _pairing.value;

  @protected
  void setPairing(PairingState s) {
    if (_closed && s.phase != PairingPhase.closed) return;
    _pairing.value = s;
  }

  @protected
  void setStatus(TransportStatus s) {
    if (_closed && s != TransportStatus.closed) return;
    _status.value = s;
  }

  /// Hands a peer frame to the session (untrusted: the session decodes it
  /// through the whitelist codec).
  @protected
  void deliver(String text) {
    if (_closed || _incoming.isClosed) return;
    if (_incoming.hasListener) {
      _incoming.add(text);
      return;
    }
    _early.addLast(text);
    while (_early.length > maxEarlyFrames) {
      _early.removeFirst();
    }
  }

  void _flush() {
    while (_early.isNotEmpty && !_incoming.isClosed) {
      _incoming.add(_early.removeFirst());
    }
  }

  /// Marks the transport closed (idempotent); true the first time.
  @protected
  bool markClosed() {
    if (_closed) return false;
    _closed = true;
    return true;
  }

  /// Final state after [markClosed] and the transport's own clean-up.
  @protected
  Future<void> finishClose() async {
    _early.clear();
    _status.value = TransportStatus.closed;
    if (_pairing.value.phase != PairingPhase.failed) _pairing.value = const PairingState(PairingPhase.closed);
    if (!_incoming.isClosed) await _incoming.close();
  }

  /// Sends [frame] to the peer (dropped silently while not connected).
  @override
  Future<void> send(TogetherFrame frame);
}
