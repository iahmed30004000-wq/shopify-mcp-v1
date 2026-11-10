/// The two Together Mode players: name, avatar, colour and title.
///
/// Nothing personal is hard-coded: a fresh install has two generic players
/// (the UI shows "Player 1" / "Player 2" in the current language until a name
/// is typed) with generated avatars and distinct colours – all editable.
library;

import 'together_bounds.dart';

/// Which of the two players. [one] is seat 0 by default.
enum PlayerSlot {
  one,
  two;

  PlayerSlot get other => this == one ? two : one;

  static PlayerSlot? tryParse(Object? v) => switch (v) {
    'one' => one,
    'two' => two,
    _ => null,
  };
}

/// How an avatar is drawn.
enum AvatarKind {
  /// An original generated emblem: an Islamic star and a small constellation
  /// derived from the avatar's seed, in the player's colour.
  constellation,

  /// One emoji on the player's colour.
  emoji,

  /// The first letter of the player's name (Reem Kufi).
  initials,
}

/// A player's avatar. Only a kind, a seed and (for [AvatarKind.emoji]) one
/// emoji are stored – never an image.
final class TogetherAvatar {
  const TogetherAvatar._(this.kind, this.seed, this.emoji);

  const TogetherAvatar.constellation(int seed) : this._(AvatarKind.constellation, seed, null);

  const TogetherAvatar.emoji(String emoji, {int seed = 0}) : this._(AvatarKind.emoji, seed, emoji);

  const TogetherAvatar.initials({int seed = 0}) : this._(AvatarKind.initials, seed, null);

  /// Seeds are kept in 0..[seedCount) (the generator's pattern space).
  static const int seedCount = 1 << 16;

  final AvatarKind kind;
  final int seed;
  final String? emoji;

  TogetherAvatar withSeed(int seed) => TogetherAvatar._(kind, seed % seedCount, emoji);

  /// Bounded however the avatar was built: the seed within [seedCount], an
  /// over-long emoji dropped (it reads back as the fallback).
  Map<String, Object?> toJson() => {
    'k': kind.name,
    's': TogetherBounds.count(seed, max: seedCount - 1),
    if (emoji != null && emoji!.length <= TogetherBounds.maxEmojiLength) 'e': emoji,
  };

  /// A stored avatar; [fallback] when missing or corrupt.
  static TogetherAvatar fromJson(Object? json, {required TogetherAvatar fallback}) {
    if (json is! Map) return fallback;
    final kind = AvatarKind.values.where((k) => k.name == json['k']).firstOrNull;
    if (kind == null) return fallback;
    final seed = TogetherBounds.count(json['s'], max: seedCount - 1);
    switch (kind) {
      case AvatarKind.constellation:
        return TogetherAvatar.constellation(seed);
      case AvatarKind.initials:
        return TogetherAvatar.initials(seed: seed);
      case AvatarKind.emoji:
        final raw = json['e'];
        if (raw is! String) return fallback;
        final e = raw.trim();
        if (e.isEmpty || e.length > TogetherBounds.maxEmojiLength) return fallback;
        return TogetherAvatar.emoji(e, seed: seed);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is TogetherAvatar && other.kind == kind && other.seed == seed && other.emoji == emoji;

  @override
  int get hashCode => Object.hash(kind, seed, emoji);
}

/// Curated avatar emoji (the picker's choices).
abstract final class TogetherEmoji {
  static const List<String> choices = [
    '🦁', '🐪', '🦅', '🦉', '🐎', '🦊', '🐬', '🐢', '🦋', '🐼', //
    '🌙', '⭐', '🌟', '🪐', '🚀', '🔥', '🌸', '🌷', '🌵', '🌴',
    '☕', '🍉', '🍋', '🎯', '🎲', '🧩', '🎨', '🏆', '⚽', '🏐',
  ];
}

/// The players' colours (ARGB). Bright jewel tones that read on every theme
/// – dark night skies and the light Pearl theme alike.
abstract final class TogetherPalette {
  static const List<int> colors = [
    0xFF4F8DF7, // sapphire
    0xFFE8657F, // rose
    0xFF2FBF8F, // emerald
    0xFFF2A93B, // amber
    0xFF9B7BF2, // violet
    0xFF26B3C6, // teal
    0xFFF07A4F, // coral
    0xFFD4B048, // gold
    0xFFD35BC0, // orchid
    0xFF86C23F, // lime
  ];

  static int clampIndex(Object? i) => i is int && i >= 0 && i < colors.length ? i : 0;
}

/// Preset titles a player can wear (localised in the UI). A custom title can
/// be typed instead.
enum PlayerTitle {
  strategist,
  cardShark,
  luckyStar,
  challenger,
  grandmaster,
  quizWhiz,
  comebackKing,
  lightning,
  peacemaker,
  dreamer,
}

/// One player's profile.
final class TogetherProfile {
  const TogetherProfile({
    required this.slot,
    this.name = '',
    required this.avatar,
    required this.colorIndex,
    this.title,
    this.customTitle = '',
  });

  /// The generic starting profile of [slot] (no name: the UI shows the
  /// localised "Player 1" / "Player 2").
  factory TogetherProfile.defaults(PlayerSlot slot) => switch (slot) {
    PlayerSlot.one => const TogetherProfile(
      slot: PlayerSlot.one,
      avatar: TogetherAvatar.constellation(1207),
      colorIndex: 0,
    ),
    PlayerSlot.two => const TogetherProfile(
      slot: PlayerSlot.two,
      avatar: TogetherAvatar.constellation(40503),
      colorIndex: 3,
    ),
  };

  final PlayerSlot slot;

  /// The typed name ('' = the localised default).
  final String name;
  final TogetherAvatar avatar;

  /// Index into [TogetherPalette.colors].
  final int colorIndex;

  /// A preset title (wins over [customTitle]).
  final PlayerTitle? title;

  /// A typed title ('' = none).
  final String customTitle;

  int get colorValue => TogetherPalette.colors[TogetherPalette.clampIndex(colorIndex)];

  bool get hasTitle => title != null || customTitle.isNotEmpty;

  TogetherProfile copyWith({
    String? name,
    TogetherAvatar? avatar,
    int? colorIndex,
    PlayerTitle? title,
    bool clearTitle = false,
    String? customTitle,
  }) => TogetherProfile(
    slot: slot,
    name: name == null ? this.name : TogetherBounds.cleanText(name, TogetherBounds.maxNameLength),
    avatar: avatar ?? this.avatar,
    colorIndex: colorIndex == null ? this.colorIndex : TogetherPalette.clampIndex(colorIndex),
    title: clearTitle ? null : (title ?? this.title),
    customTitle: customTitle == null
        ? this.customTitle
        : TogetherBounds.cleanText(customTitle, TogetherBounds.maxTitleLength),
  );

  /// Cleaned and bounded on the way out too: a profile built with the
  /// constructor (not [copyWith]) never stores an unbounded value.
  Map<String, Object?> toJson() {
    final ct = TogetherBounds.cleanText(customTitle, TogetherBounds.maxTitleLength);
    return {
      'n': TogetherBounds.cleanText(name, TogetherBounds.maxNameLength),
      'a': avatar.toJson(),
      'c': TogetherPalette.clampIndex(colorIndex),
      if (title != null) 't': title!.name,
      if (ct.isNotEmpty) 'ct': ct,
    };
  }

  /// A stored profile of [slot]; the defaults for anything missing or corrupt.
  static TogetherProfile fromJson(PlayerSlot slot, Object? json) {
    final d = TogetherProfile.defaults(slot);
    if (json is! Map) return d;
    return TogetherProfile(
      slot: slot,
      name: TogetherBounds.cleanText(json['n'], TogetherBounds.maxNameLength),
      avatar: TogetherAvatar.fromJson(json['a'], fallback: d.avatar),
      colorIndex: json.containsKey('c') ? TogetherPalette.clampIndex(json['c']) : d.colorIndex,
      title: PlayerTitle.values.where((t) => t.name == json['t']).firstOrNull,
      customTitle: TogetherBounds.cleanText(json['ct'], TogetherBounds.maxTitleLength),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TogetherProfile &&
      other.slot == slot &&
      other.name == name &&
      other.avatar == avatar &&
      other.colorIndex == colorIndex &&
      other.title == title &&
      other.customTitle == customTitle;

  @override
  int get hashCode => Object.hash(slot, name, avatar, colorIndex, title, customTitle);
}

/// Both players.
final class TogetherProfiles {
  const TogetherProfiles(this.one, this.two);

  factory TogetherProfiles.defaults() =>
      TogetherProfiles(TogetherProfile.defaults(PlayerSlot.one), TogetherProfile.defaults(PlayerSlot.two));

  final TogetherProfile one;
  final TogetherProfile two;

  TogetherProfile of(PlayerSlot slot) => slot == PlayerSlot.one ? one : two;

  List<TogetherProfile> get both => [one, two];

  TogetherProfiles withProfile(TogetherProfile p) =>
      p.slot == PlayerSlot.one ? TogetherProfiles(p, two) : TogetherProfiles(one, p);

  Map<String, Object?> toJson() => {'v': 1, 'one': one.toJson(), 'two': two.toJson()};

  static TogetherProfiles fromJson(Object? json) {
    if (json is! Map) return TogetherProfiles.defaults();
    return TogetherProfiles(
      TogetherProfile.fromJson(PlayerSlot.one, json['one']),
      TogetherProfile.fromJson(PlayerSlot.two, json['two']),
    );
  }

  @override
  bool operator ==(Object other) => other is TogetherProfiles && other.one == one && other.two == two;

  @override
  int get hashCode => Object.hash(one, two);
}
