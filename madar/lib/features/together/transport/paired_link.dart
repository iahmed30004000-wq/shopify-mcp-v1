/// Two phones, one game: who is who once the pairing is done.
///
/// The pairing decides which phone hosts (participant 0) – for Nearby the
/// phone whose connection request won, online the phone that created the
/// code – and that is unrelated to who moves first. [TwoPhoneSeating]
/// decouples the two: each phone maps the participants to its *own* profile
/// slots (each phone keeps both profiles, possibly the other way round), and
/// the host seats whoever starts on seat 0.
library;

import 'dart:math' as math;

import '../domain/play_modes.dart';
import '../domain/player_profile.dart';
import '../protocol/game_data.dart';
import '../protocol/session.dart';
import '../protocol/together_game.dart';
import 'pairing_state.dart';

/// Participant ↔ player on one of two paired phones.
final class TwoPhoneSeating {
  const TwoPhoneSeating({required this.role, required this.localSlot});

  /// This phone's side.
  final SessionRole role;

  /// This phone's player, in this phone's profiles.
  final PlayerSlot localSlot;

  /// Participant → player for `TogetherSession(seating: …)`: this phone's
  /// participant is its own player, the other participant the other player.
  List<PlayerSlot> get seating =>
      role == SessionRole.host ? [localSlot, localSlot.other] : [localSlot.other, localSlot];

  /// The participant of [slot] (a player in this phone's profiles).
  int participantOf(PlayerSlot slot) => seating.indexOf(slot);

  /// Host only – seat → participant for the start: [firstPlayer] (in this
  /// phone's profiles, as the launch sheet's "who starts" gives it) on seat
  /// 0, the other player on seat 1 ([partners]: seat 2), AIs elsewhere. The
  /// guest takes the seats from the host's start.
  List<int> seats({required PlayerSlot firstPlayer, required int seatCount, bool partners = false}) {
    final base = partners ? TogetherSeats.partners(seatCount) : TogetherSeats.rivals(seatCount);
    if (participantOf(firstPlayer) == 0) return base;
    return [for (final p in base) p == TogetherSeats.ai ? p : 1 - p];
  }
}

/// A finished pairing, handed to the game UI by the pairing sheet: the open
/// transport, this phone's player and the partner.
final class PairedLink {
  PairedLink({required this.transport, required this.identity})
    : assert(transport.role != null && transport.peer != null, 'the transport is not paired');

  final PairableTransport transport;

  /// This phone's player.
  final PairingIdentity identity;

  SessionRole get role => transport.role!;

  PairingPeer get peer => transport.peer!;

  PlayMode get mode => transport.mode;

  TwoPhoneSeating get seating => TwoPhoneSeating(role: role, localSlot: identity.slot);

  /// This phone's session of [adapter]. The host seats [firstPlayer] (this
  /// phone's "who starts") on seat 0 and must call `start()`; the guest
  /// follows the host's start (its [firstPlayer] is ignored).
  TogetherSession<S, M> session<S, M>({
    required TogetherGameAdapter<S, M> adapter,
    required PlayerSlot firstPlayer,
    bool partners = false,
    TogetherResultRecorder? recorder,
    GameData? config,
    math.Random? random,
    DateTime Function()? clock,
  }) => TogetherSession<S, M>(
    adapter: adapter,
    transport: transport,
    role: role,
    seating: seating.seating,
    seats: role == SessionRole.host
        ? seating.seats(firstPlayer: firstPlayer, seatCount: adapter.seatCount, partners: partners)
        : null,
    recorder: recorder,
    config: config,
    random: random,
    clock: clock,
  );

  /// Leaves: the partner is told by the session's `bye`; the transport stops
  /// its radios / deletes the online room.
  Future<void> close() => transport.close();
}
