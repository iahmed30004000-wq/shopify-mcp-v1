/// Online rooms in the user's Realtime Database: the layout, the codes, the
/// time limits and the little profile each side shows the other.
///
/// ```text
/// rooms/<6-digit code>
///   h   host uid              g   guest uid (once joined)
///   v   1                     gm  game id
///   c   created (server ms)   x   expires (server ms)
///   ok  true once the host accepted the guest
///   ph  {n, a, k}  host's display name, avatar id, colour index
///   pg  {n, a, k}  guest's
///   f   {<push id>: {s: 0|1, t: "<Together frame JSON>", at: server ms}}
/// ```
///
/// Only frames and those three profile fields are ever written; the
/// recipient deletes each frame once read, and leaving deletes the room.
library;

import 'dart:convert';
import 'dart:math' as math;

import '../../../../core/db/encryption.dart' show SecretStore;
import '../../domain/player_profile.dart';
import '../../domain/together_bounds.dart';
import '../../protocol/envelope.dart';
import '../pairing_state.dart';
import 'rtdb.dart';

abstract final class OnlineRooms {
  static const String root = 'rooms';

  /// A new code works this long.
  static const Duration joinWindow = Duration(minutes: 15);

  /// A joined room lives this long after its last refresh (the rules cap it
  /// at 6 hours ahead).
  static const Duration ttl = Duration(hours: 6);

  /// How often a playing phone pushes [ttl] forward.
  static const Duration refreshEvery = Duration(hours: 1);

  /// The largest frame the rules accept (the protocol's own limit).
  static const int maxFrameChars = TogetherProtocol.maxFrameBytes;

  /// Own frames left unread by the partner before the oldest are withdrawn
  /// (the session retransmits what matters).
  static const int maxOwnPending = 64;

  static String room(String code) => '$root/$code';

  static String frames(String code) => '$root/$code/f';

  static final RegExp _code = RegExp(r'^[0-9]{6}$');

  static bool isValidCode(String code) => _code.hasMatch(code);

  /// A random code (100000–999999: no leading zero to mistype).
  static String newCode(math.Random random) => (100000 + random.nextInt(900000)).toString();

  /// The digits of typed text – Arabic-Indic (٠–٩) and Persian (۰–۹)
  /// digits included, everything else (spaces, dashes) dropped.
  static String normalizeCode(String input) {
    final out = StringBuffer();
    for (final c in input.runes) {
      if (c >= 0x30 && c <= 0x39) {
        out.writeCharCode(c);
      } else if (c >= 0x0660 && c <= 0x0669) {
        out.writeCharCode(0x30 + c - 0x0660);
      } else if (c >= 0x06F0 && c <= 0x06F9) {
        out.writeCharCode(0x30 + c - 0x06F0);
      }
    }
    return out.toString();
  }

  /// "123 456".
  static String displayCode(String code) => code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

  static int ms(DateTime t) => t.millisecondsSinceEpoch;

  /// A fresh room for [host].
  static Map<String, Object?> newRoom({
    required String hostUid,
    required String gameId,
    required PairingIdentity host,
    required DateTime now,
  }) => {
    'h': hostUid,
    'v': 1,
    'gm': gameId,
    'c': rtdbServerTimestamp,
    'x': ms(now.add(joinWindow)),
    'ph': profileOf(host),
  };

  /// A frame as stored.
  static Map<String, Object?> frame(int from, String text) => {'s': from, 't': text, 'at': rtdbServerTimestamp};

  /// The avatar as a short id: `c<seed>`, `i<seed>` or `e<seed>:<emoji>`.
  static String avatarId(TogetherAvatar a) => switch (a.kind) {
    AvatarKind.constellation => 'c${a.seed}',
    AvatarKind.initials => 'i${a.seed}',
    AvatarKind.emoji => 'e${a.seed}:${a.emoji ?? ''}',
  };

  static TogetherAvatar? avatarOf(Object? id) {
    if (id is! String || id.isEmpty || id.length > 32) return null;
    final kind = id[0];
    final rest = id.substring(1);
    final colon = rest.indexOf(':');
    final seed = int.tryParse(colon < 0 ? rest : rest.substring(0, colon));
    if (seed == null || seed < 0 || seed >= TogetherAvatar.seedCount) return null;
    return switch (kind) {
      'c' => TogetherAvatar.constellation(seed),
      'i' => TogetherAvatar.initials(seed: seed),
      'e' when colon > 0 && rest.length - colon - 1 <= TogetherBounds.maxEmojiLength && rest.length > colon + 1 =>
        TogetherAvatar.emoji(rest.substring(colon + 1), seed: seed),
      _ => null,
    };
  }

  /// The profile this phone shows the partner: display name, avatar id and
  /// colour – nothing else.
  static Map<String, Object?> profileOf(PairingIdentity me) => {
    'n': me.name,
    'a': avatarId(me.avatar),
    'k': TogetherPalette.clampIndex(me.colorIndex),
  };

  /// The partner of a stored profile (untrusted: cleaned and bounded).
  static PairingPeer peerOf(String uid, Object? json) {
    final m = json is Map ? json : const {};
    final name = TogetherBounds.cleanText(m['n'], TogetherBounds.maxNameLength);
    final k = m['k'];
    return PairingPeer(
      id: uid,
      name: name.isEmpty ? '?' : name,
      avatar: avatarOf(m['a']),
      colorIndex: k is int && k >= 0 && k < TogetherPalette.colors.length ? k : null,
    );
  }
}

/// The rooms this phone created or joined and has not deleted yet – deleted
/// at the next online pairing when the app died mid-game (secure storage
/// entry [OnlineRoomLedger.key]).
class OnlineRoomLedger {
  const OnlineRoomLedger(this.secrets);

  static const String key = 'together.online.rooms';
  static const int max = 8;

  final SecretStore secrets;

  Future<List<String>> codes() async {
    final raw = await secrets.read(key);
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw);
      return json is List
          ? [
              for (final c in json)
                if (c is String && OnlineRooms.isValidCode(c)) c,
            ]
          : const [];
    } on FormatException {
      return const [];
    }
  }

  Future<void> add(String code) async {
    final list = [...(await codes()).where((c) => c != code), code];
    await secrets.write(key, jsonEncode(list.length > max ? list.sublist(list.length - max) : list));
  }

  Future<void> remove(String code) async {
    final list = (await codes()).where((c) => c != code).toList();
    if (list.isEmpty) {
      await secrets.delete(key);
    } else {
      await secrets.write(key, jsonEncode(list));
    }
  }

  Future<void> clear() => secrets.delete(key);
}
