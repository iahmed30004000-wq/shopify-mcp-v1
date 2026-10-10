/// Play modes, settings and the catalogue of games that can be played
/// together.
library;

import 'together_bounds.dart';

/// How the two players share a game.
enum PlayMode {
  /// One phone handed back and forth; a hand-off screen hides private
  /// information between turns.
  passAndPlay,

  /// One phone, two halves: each player controls their side with multi-touch.
  splitScreen,

  /// Two phones side by side, no internet (a transport comes later).
  nearby,

  /// Two phones anywhere (optional, off by default; a transport comes later).
  online;

  /// Both players on one device.
  bool get sameDevice => this == passAndPlay || this == splitScreen;

  static PlayMode? tryParse(Object? v) => values.where((m) => m.name == v).firstOrNull;
}

/// Whether a mode can be picked right now for a game.
enum ModeAvailability {
  available,

  /// The game does not offer this mode.
  unsupported,

  /// No transport for it yet ("coming soon").
  comingSoon,

  /// Turned off in the settings (online play).
  disabled,
}

/// How [PlayMode.splitScreen] divides the screen.
enum SplitLayout {
  /// Top and bottom halves; the far half is turned 180° so each player faces
  /// their side when the phone lies flat between them.
  faceToFace,

  /// Left and right halves, both upright (landscape, sitting side by side).
  sideBySide,

  /// Left and right halves turned 90° towards the short edges (landscape,
  /// phone flat, players at either end).
  endToEnd;

  static SplitLayout? tryParse(Object? v) => values.where((m) => m.name == v).firstOrNull;
}

/// Turn-based games (pass-and-play, nearby, online) or real-time ones
/// (split-screen, nearby, online).
enum TogetherGameKind { turnBased, realTime }

/// Together Mode preferences (stored encrypted on the device).
final class TogetherSettings {
  const TogetherSettings({
    this.defaultMode = PlayMode.passAndPlay,
    this.onlineEnabled = false,
    this.splitLayout = SplitLayout.faceToFace,
    this.hideInRecents = true,
  });

  /// Pre-selected at the start of every game (if the game offers it).
  final PlayMode defaultMode;

  /// Online play – off until the user turns it on (and a transport exists).
  final bool onlineEnabled;
  final SplitLayout splitLayout;

  /// Hide the app from the recents thumbnail / screenshots while private
  /// information is on screen (FLAG_SECURE, wired by the app shell).
  final bool hideInRecents;

  TogetherSettings copyWith({PlayMode? defaultMode, bool? onlineEnabled, SplitLayout? splitLayout, bool? hideInRecents}) =>
      TogetherSettings(
        defaultMode: defaultMode ?? this.defaultMode,
        onlineEnabled: onlineEnabled ?? this.onlineEnabled,
        splitLayout: splitLayout ?? this.splitLayout,
        hideInRecents: hideInRecents ?? this.hideInRecents,
      );

  Map<String, Object?> toJson() => {
    'v': 1,
    'mode': defaultMode.name,
    'online': onlineEnabled,
    'split': splitLayout.name,
    'secure': hideInRecents,
  };

  static TogetherSettings fromJson(Object? json) {
    if (json is! Map) return const TogetherSettings();
    return TogetherSettings(
      defaultMode: PlayMode.tryParse(json['mode']) ?? PlayMode.passAndPlay,
      onlineEnabled: json['online'] == true,
      splitLayout: SplitLayout.tryParse(json['split']) ?? SplitLayout.faceToFace,
      hideInRecents: json['secure'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TogetherSettings &&
      other.defaultMode == defaultMode &&
      other.onlineEnabled == onlineEnabled &&
      other.splitLayout == splitLayout &&
      other.hideInRecents == hideInRecents;

  @override
  int get hashCode => Object.hash(defaultMode, onlineEnabled, splitLayout, hideInRecents);
}

/// A game that can be played together. [id] is the stable key of its
/// head-to-head history.
final class TogetherGameInfo {
  const TogetherGameInfo({required this.id, required this.kind, required this.modes, this.coop = false});

  final String id;
  final TogetherGameKind kind;

  /// The modes the game offers.
  final Set<PlayMode> modes;

  /// The couple plays on the same side (results are "won / lost together").
  final bool coop;
}

/// The Together Mode games (spec M). Game UIs pass their own
/// [TogetherGameInfo] to the launch sheet; ids missing here still work
/// (their history shows the id's fallback label).
abstract final class TogetherGames {
  static const Set<PlayMode> _turnModes = {PlayMode.passAndPlay, PlayMode.nearby, PlayMode.online};
  static const Set<PlayMode> _liveModes = {PlayMode.splitScreen, PlayMode.nearby, PlayMode.online};

  static const TogetherGameKind _turn = TogetherGameKind.turnBased;
  static const TogetherGameKind _live = TogetherGameKind.realTime;

  // Real-time.
  static const airHockey = TogetherGameInfo(id: 'airHockey', kind: _live, modes: _liveModes);
  static const beachVolley = TogetherGameInfo(id: 'beachVolley', kind: _live, modes: _liveModes);
  static const kartDash = TogetherGameInfo(id: 'kartDash', kind: _live, modes: _liveModes);
  static const snowballFight = TogetherGameInfo(id: 'snowballFight', kind: _live, modes: _liveModes);
  static const paddleDuel = TogetherGameInfo(id: 'paddleDuel', kind: _live, modes: _liveModes);
  static const tankDuel = TogetherGameInfo(id: 'tankDuel', kind: _live, modes: _liveModes);
  static const metropolisCoop = TogetherGameInfo(id: 'metropolisCoop', kind: _live, modes: _liveModes, coop: true);

  // Turn-based.
  static const tarneeb = TogetherGameInfo(id: 'tarneeb', kind: _turn, modes: _turnModes);
  static const trix = TogetherGameInfo(id: 'trix', kind: _turn, modes: _turnModes);
  static const basra = TogetherGameInfo(id: 'basra', kind: _turn, modes: _turnModes);
  static const konkan = TogetherGameInfo(id: 'konkan', kind: _turn, modes: _turnModes);
  static const backgammon = TogetherGameInfo(id: 'backgammon', kind: _turn, modes: _turnModes);
  static const chess = TogetherGameInfo(id: 'chess', kind: _turn, modes: _turnModes);
  static const dominoes = TogetherGameInfo(id: 'dominoes', kind: _turn, modes: _turnModes);
  static const ludo = TogetherGameInfo(id: 'ludo', kind: _turn, modes: _turnModes);
  static const fourInARow = TogetherGameInfo(id: 'fourInARow', kind: _turn, modes: _turnModes);
  static const wordDuel = TogetherGameInfo(id: 'wordDuel', kind: _turn, modes: _turnModes);
  static const quizDuel = TogetherGameInfo(id: 'quizDuel', kind: _turn, modes: _turnModes);
  static const drawGuess = TogetherGameInfo(id: 'drawGuess', kind: _turn, modes: _turnModes);
  static const miniGolf = TogetherGameInfo(id: 'miniGolf', kind: _turn, modes: _turnModes);

  // Couple specials.
  static const knowMe = TogetherGameInfo(id: 'knowMe', kind: _turn, modes: {PlayMode.passAndPlay, PlayMode.nearby});

  static const List<TogetherGameInfo> all = [
    tarneeb,
    trix,
    basra,
    konkan,
    backgammon,
    chess,
    dominoes,
    ludo,
    fourInARow,
    wordDuel,
    quizDuel,
    drawGuess,
    miniGolf,
    knowMe,
    airHockey,
    beachVolley,
    kartDash,
    snowballFight,
    paddleDuel,
    tankDuel,
    metropolisCoop,
  ];

  static TogetherGameInfo? byId(String id) => all.where((g) => g.id == id).firstOrNull;

  /// Whether [id] is a storable game id.
  static bool isValidId(String id) => id.length <= 40 && TogetherBounds.isValidId(id);
}
