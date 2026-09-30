/// Together Mode (spec M) – the user and his wife: two editable player
/// profiles, head-to-head history, streaks and "Our Hall of Fame"
/// (قاعة مجدنا); play modes (pass-and-play, split-screen, two phones nearby
/// and online – the last two "coming soon" until their transports exist);
/// the pass-and-play hand-off gate, the split-screen arena and the session
/// protocol every together game runs on.
///
/// For the app shell: route [TogetherHomeScreen] (and [HallOfFameScreen]),
/// put [TogetherSettingsTile] in Settings, wire FLAG_SECURE through
/// [togetherSecureScreenProvider] and, later, register the nearby / online
/// transports in [togetherTransportFactoriesProvider].
///
/// For game UIs: [showGameLaunchSheet] → [GameLaunchChoice]; a
/// [TogetherSession] over a [TogetherGameAdapter] (ready-made:
/// [BoardKitTogetherAdapter], [CardEngineTogetherAdapter]) with
/// `recorder: ref.read(togetherRecorderProvider)`; [HandOffGate] /
/// [FollowingHandOffGate] for pass-and-play (moves made from a private view
/// pass its participant: `session.play(move, participant: p)`),
/// [SplitScreenArena] for split-screen; [celebrateNewTrophies] after the
/// result is recorded.
///
/// Only game state ever travels: every message goes through the whitelist
/// [TogetherCodec]; health, money and personal data never leave the device.
library;

export 'adapters/rules_adapters.dart';
export 'data/together_providers.dart';
export 'data/together_repository.dart';
export 'domain/head_to_head.dart';
export 'domain/match_record.dart';
export 'domain/play_modes.dart';
export 'domain/player_profile.dart';
export 'domain/together_bounds.dart';
export 'domain/trophies.dart';
export 'presentation/game_launch_sheet.dart';
export 'presentation/hall_of_fame_screen.dart';
export 'presentation/handoff/hand_off.dart';
export 'presentation/mode_picker.dart';
export 'presentation/profile_sheet.dart';
export 'presentation/split/split_screen_arena.dart';
export 'presentation/together_home_screen.dart';
export 'presentation/together_texts.dart';
export 'presentation/widgets/together_visuals.dart';
export 'protocol/envelope.dart';
export 'protocol/game_data.dart';
export 'protocol/session.dart';
export 'protocol/together_game.dart';
export 'protocol/transport.dart';
