/// Together Mode on two phones: Google Nearby Connections side by side, and
/// the optional online play over the user's own Firebase project – the
/// transports, the pairing sheet, the online-play settings and the "your
/// turn" alerts.
///
/// For the app shell: add `...togetherTransportOverrides(suspender:
/// lockSuspender)` to the root overrides (registers both modes in
/// `togetherTransportFactoriesProvider`), and offer
/// [showOnlinePlaySheet] from the Together settings.
///
/// For game UIs: after `showGameLaunchSheet` picked [PlayMode.nearby] or
/// [PlayMode.online], `final link = await showPairingSheet(context, game:
/// …, mode: choice.mode)`; then `link.session(adapter: …, firstPlayer:
/// choice.firstPlayer, recorder: …)` – the host calls `start()`. Optionally
/// `ref.read(togetherTurnAlertsProvider).watch(session, texts: …)` for
/// "your turn" notifications while the app is in the background.
///
/// Only game state ever travels: the transports carry nothing but the
/// whitelist codec's frames (plus, online, each side's display name,
/// avatar and colour in the room).
library;

export '../transport/device_store.dart';
export '../transport/frame_chunks.dart';
export '../transport/nearby/nearby_api.dart';
export '../transport/nearby/nearby_permissions.dart';
export '../transport/nearby/nearby_transport.dart';
export '../transport/online/online_config.dart';
export '../transport/online/online_rooms.dart';
export '../transport/online/online_transport.dart';
export '../transport/online/rtdb.dart';
export '../transport/online/security_rules.dart';
export '../transport/paired_link.dart';
export '../transport/pairing_state.dart';
export '../transport/together_net_providers.dart';
export '../transport/turn_alerts.dart';
export 'online_play_sheet.dart';
export 'pairing_sheet.dart';
export 'pairing_texts.dart';
export 'pairing_visuals.dart';
export 'permission_rationale.dart';
