/// «مدار الصغار»'s shell: the one-way door into the kids section.
///
/// * Kids mode (on/off, daily limit, today's play time) is persisted
///   ([kidsModeProvider]); a relaunch with it on lands inside `/kids`.
/// * The router redirects EVERY location outside `/kids/**` into it while it
///   is on ([kidsModeRedirect], wired in `lib/core/routing/router.dart`).
/// * The shell's own routes ([kidsRoutes]) hold the home and the sections the
///   other kids folders register through `kidsSectionsProvider`.
/// * Leaving needs the PIN or the fingerprint ([KidsParentGate]); the parent
///   corner holds the screen-time limit and the screen-pinning re-offer.
/// * [KidsSpeakButton] is an optional, silent-until-voices speaker button any
///   kids screen may place next to a text.
/// * [KidsEntryCard] is the card at the top of Settings.
library;

export 'application/kids_actions.dart' show KidsActions, kidsActionsProvider;
export 'application/kids_parent_check.dart';
export 'application/kids_providers.dart';
export 'data/kids_store.dart';
export 'domain/kids_logic.dart';
export 'kids_routes.dart' show kidsRoutes;
export 'presentation/kids_entry_card.dart' show KidsEntryCard, ensureParentPin;
export 'presentation/kids_overlays.dart' show KidsSpeakButton;
export 'presentation/kids_palette.dart'
    show KhatamStar, KidsBigButton, KidsButtonTone, KidsColors, KidsRoundButton, KidsText, kKidsMinTarget, kidsDigits;
