/// The Realtime Database security rules the user pastes into their Firebase
/// project (Realtime Database › Rules). Online play only works with them.
///
/// What they enforce:
/// * nothing outside `rooms/` can be read or written;
/// * a room is readable only by its two signed-in members (its game id and
///   expiry – no names – by any signed-in user, so a joining phone can say
///   "wrong game" or "expired");
/// * only a signed-in user can create a room, as its host, and only under a
///   free or expired 6-digit code; a room lives at most 6 hours ahead;
/// * exactly one guest can join, before the room expires, and only the host
///   can accept them;
/// * each side writes only its own profile (display name ≤ 48 UTF-16 units,
///   avatar id ≤ 32, colour index 0–15) and only frames that look like
///   Together frames, sent as itself (`s` = 0 host, 1 guest), stamped with
///   the server's clock;
/// * either member can delete a frame (the recipient deletes what it read)
///   or the whole room (leaving); anyone signed in can delete an expired
///   room;
/// * no other field can ever be written.
library;

abstract final class OnlineSecurityRules {
  static const String json = r'''{
  "rules": {
    ".read": false,
    ".write": false,
    "rooms": {
      "$code": {
        ".read": "auth != null && (!data.exists() || data.child('h').val() === auth.uid || data.child('g').val() === auth.uid)",
        ".write": "auth != null && $code.matches(/^[0-9][0-9][0-9][0-9][0-9][0-9]$/) && ((newData.exists() && (!data.exists() || data.child('x').val() < now) && newData.child('h').val() === auth.uid && !newData.hasChild('g') && !newData.hasChild('ok') && !newData.hasChild('pg') && !newData.hasChild('f')) || (!newData.exists() && data.exists() && (data.child('h').val() === auth.uid || data.child('g').val() === auth.uid || data.child('x').val() < now)))",
        ".validate": "newData.hasChildren(['h', 'v', 'gm', 'c', 'x'])",
        "h": {
          ".validate": "newData.isString() && newData.val().length <= 128"
        },
        "v": {
          ".validate": "newData.val() === 1"
        },
        "gm": {
          ".read": "auth != null",
          ".validate": "newData.isString() && newData.val().length <= 40 && newData.val().matches(/^[A-Za-z0-9_-]+$/)"
        },
        "c": {
          ".validate": "newData.isNumber() && newData.val() <= now"
        },
        "x": {
          ".read": "auth != null",
          ".write": "auth != null && data.exists() && data.val() >= now && (newData.parent().child('h').val() === auth.uid || newData.parent().child('g').val() === auth.uid)",
          ".validate": "newData.isNumber() && newData.val() > now && newData.val() <= now + 21600000"
        },
        "g": {
          ".write": "auth != null && !data.exists() && newData.val() === auth.uid && data.parent().child('h').val() !== auth.uid && data.parent().child('x').val() >= now",
          ".validate": "newData.isString() && newData.val().length <= 128"
        },
        "ok": {
          ".write": "auth != null && data.parent().child('h').val() === auth.uid && data.parent().hasChild('g')",
          ".validate": "newData.val() === true"
        },
        "ph": {
          ".validate": "newData.hasChildren(['n', 'a', 'k'])",
          "n": { ".validate": "newData.isString() && newData.val().length >= 1 && newData.val().length <= 48" },
          "a": { ".validate": "newData.isString() && newData.val().length <= 32" },
          "k": { ".validate": "newData.isNumber() && newData.val() >= 0 && newData.val() <= 15" },
          "$other": { ".validate": false }
        },
        "pg": {
          ".write": "auth != null && !data.exists() && newData.parent().child('g').val() === auth.uid",
          ".validate": "newData.hasChildren(['n', 'a', 'k'])",
          "n": { ".validate": "newData.isString() && newData.val().length >= 1 && newData.val().length <= 48" },
          "a": { ".validate": "newData.isString() && newData.val().length <= 32" },
          "k": { ".validate": "newData.isNumber() && newData.val() >= 0 && newData.val() <= 15" },
          "$other": { ".validate": false }
        },
        "f": {
          "$frame": {
            ".write": "auth != null && root.child('rooms').child($code).child('x').val() >= now && ((!data.exists() && newData.exists() && ((newData.child('s').val() === 0 && root.child('rooms').child($code).child('h').val() === auth.uid) || (newData.child('s').val() === 1 && root.child('rooms').child($code).child('g').val() === auth.uid))) || (data.exists() && !newData.exists() && (root.child('rooms').child($code).child('h').val() === auth.uid || root.child('rooms').child($code).child('g').val() === auth.uid)))",
            ".validate": "newData.hasChildren(['s', 't', 'at'])",
            "s": { ".validate": "newData.val() === 0 || newData.val() === 1" },
            "t": { ".validate": "newData.isString() && newData.val().length <= 262144 && newData.val().matches(/^[{]\"p\":\"madar[.]together\",\"v\":1,\"sid\":\"[A-Za-z0-9_-]+\",\"k\":\"(hello|start|move|input|snapshot|sync|resync|result|bye)\",/)" },
            "at": { ".validate": "newData.val() === now" },
            "$other": { ".validate": false }
          }
        },
        "$other": { ".validate": false }
      }
    }
  }
}''';
}
