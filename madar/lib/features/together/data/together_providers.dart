import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../home/home_providers.dart' show appForegroundProvider, homeClockProvider;
import '../domain/head_to_head.dart';
import '../domain/match_record.dart';
import '../domain/play_modes.dart';
import '../domain/player_profile.dart';
import '../domain/trophies.dart';
import '../protocol/session.dart';
import '../protocol/transport.dart';
import 'together_repository.dart';

/// Together Mode storage over the unlocked database.
final togetherRepositoryProvider = Provider<TogetherRepository>(
  (ref) => TogetherRepository(ref.watch(databaseProvider)),
);

/// The clock used for "played today" / streak checks: the app's wall clock
/// ([homeClockProvider]); tests override either.
final togetherClockProvider = Provider<DateTime Function()>((ref) => ref.watch(homeClockProvider));

final togetherProfilesProvider = StreamProvider<TogetherProfiles>(
  (ref) => ref.watch(togetherRepositoryProvider).watchProfiles(),
);

final togetherSettingsProvider = StreamProvider<TogetherSettings>(
  (ref) => ref.watch(togetherRepositoryProvider).watchSettings(),
);

/// Head-to-head history, newest first.
final togetherHistoryProvider = StreamProvider<List<MatchRecord>>(
  (ref) => ref.watch(togetherRepositoryProvider).watchHistory(),
);

final togetherLedgerProvider = StreamProvider<TogetherLedger>(
  (ref) => ref.watch(togetherRepositoryProvider).watchLedger(),
);

final togetherTrophiesProvider = StreamProvider<TrophyShelf>(
  (ref) => ref.watch(togetherRepositoryProvider).watchTrophies(),
);

/// Records finished matches into the history (give it to every
/// [TogetherSession] as its `recorder`).
final togetherRecorderProvider = Provider<TogetherResultRecorder>(
  (ref) => ref.watch(togetherRepositoryProvider).recordMatch,
);

/// Transports for the two-phone modes, registered by the app shell once
/// they exist (Google Nearby Connections → [PlayMode.nearby], the optional
/// online service → [PlayMode.online]). Empty: both show "coming soon".
final togetherTransportFactoriesProvider = Provider<Map<PlayMode, TogetherTransportFactory>>((ref) => const {});

/// Whether [PlayMode]s can be picked, given the game's modes (null: every
/// mode the device could offer), the registered transports and the
/// settings.
final togetherModeAvailabilityProvider = Provider<ModeAvailability Function(PlayMode mode, {Set<PlayMode>? gameModes})>((
  ref,
) {
  final transports = ref.watch(togetherTransportFactoriesProvider);
  final settings = ref.watch(togetherSettingsProvider).value ?? const TogetherSettings();
  return (mode, {gameModes}) => togetherModeAvailability(
    mode,
    gameModes: gameModes,
    transports: transports.keys.toSet(),
    settings: settings,
  );
});

/// Pure availability rule behind [togetherModeAvailabilityProvider].
ModeAvailability togetherModeAvailability(
  PlayMode mode, {
  Set<PlayMode>? gameModes,
  required Set<PlayMode> transports,
  required TogetherSettings settings,
}) {
  if (gameModes != null && !gameModes.contains(mode)) return ModeAvailability.unsupported;
  if (mode.sameDevice) return ModeAvailability.available;
  if (!transports.contains(mode)) return ModeAvailability.comingSoon;
  if (mode == PlayMode.online && !settings.onlineEnabled) return ModeAvailability.disabled;
  return ModeAvailability.available;
}

/// Everything the Together home shows, at one moment.
final class TogetherOverview {
  const TogetherOverview({
    required this.profiles,
    required this.ledger,
    required this.history,
    required this.trophies,
    required this.settings,
    required this.now,
  });

  final TogetherProfiles profiles;
  final TogetherLedger ledger;

  /// Newest first.
  final List<MatchRecord> history;
  final TrophyShelf trophies;
  final TogetherSettings settings;
  final DateTime now;

  bool get hasMatches => !ledger.isEmpty || history.isNotEmpty;

  int get dayStreak => ledger.currentDayStreak(now);
}

/// Everything the Together screens show. Its [TogetherOverview.now] is taken
/// when it is built – so it is disposed with the last screen that shows it
/// and rebuilt when the app comes back to the foreground: a streak that
/// lapsed overnight, or "played today", is never shown stale.
final togetherOverviewProvider = Provider.autoDispose<AsyncValue<TogetherOverview>>((ref) {
  final foreground = ref.watch(appForegroundProvider);
  var wasForeground = foreground.value;
  void onForeground() {
    final now = foreground.value;
    if (now && !wasForeground) ref.invalidateSelf();
    wasForeground = now;
  }

  foreground.addListener(onForeground);
  ref.onDispose(() => foreground.removeListener(onForeground));

  final profiles = ref.watch(togetherProfilesProvider);
  final ledger = ref.watch(togetherLedgerProvider);
  final history = ref.watch(togetherHistoryProvider);
  final trophies = ref.watch(togetherTrophiesProvider);
  final settings = ref.watch(togetherSettingsProvider);
  final parts = <AsyncValue<Object?>>[profiles, ledger, history, trophies, settings];
  for (final p in parts) {
    if (p case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  }
  if (parts.any((p) => !p.hasValue)) return const AsyncLoading();
  return AsyncData(
    TogetherOverview(
      profiles: profiles.requireValue,
      ledger: ledger.requireValue,
      history: history.requireValue,
      trophies: trophies.requireValue,
      settings: settings.requireValue,
      now: ref.watch(togetherClockProvider)(),
    ),
  );
});

// --------------------------------------------------------------- privacy

/// Keeps the window out of the recents thumbnail and screenshots while
/// private information (cards, answers) is on screen.
///
/// Android's FLAG_SECURE is native: the app shell implements the
/// `madar/together_privacy` method channel in MainActivity –
///
/// ```kotlin
/// MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "madar/together_privacy")
///   .setMethodCallHandler { call, result ->
///     if (call.method == "setSecure") {
///       if (call.arguments as Boolean) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
///       else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
///       result.success(null)
///     } else result.notImplemented()
///   }
/// ```
///
/// – or overrides [togetherSecureScreenProvider] with its own hook (for
/// example one shared with the app lock). Calls are reference-counted: the
/// flag stays on while any private surface is mounted.
abstract class SecureScreenHook {
  Future<void> setSecure(bool secure);
}

/// The method-channel hook (missing native side: silently nothing).
class MethodChannelSecureScreen implements SecureScreenHook {
  const MethodChannelSecureScreen([this.channel = const MethodChannel('madar/together_privacy')]);

  final MethodChannel channel;

  @override
  Future<void> setSecure(bool secure) async {
    try {
      await channel.invokeMethod<void>('setSecure', secure);
    } on MissingPluginException {
      // The app shell has not wired FLAG_SECURE (tests, desktop).
    } on PlatformException catch (e) {
      debugPrint('Together privacy: $e');
    }
  }
}

/// Records calls instead of touching the window (tests, previews).
class RecordingSecureScreen implements SecureScreenHook {
  final List<bool> calls = [];

  bool get secure => calls.isNotEmpty && calls.last;

  @override
  Future<void> setSecure(bool secure) async => calls.add(secure);
}

final togetherSecureScreenProvider = Provider<SecureScreenHook>((ref) => const MethodChannelSecureScreen());
