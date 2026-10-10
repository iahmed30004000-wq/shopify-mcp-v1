import 'dart:async';

import 'package:audio_service/audio_service.dart' show AudioService;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/i18n/formatters.dart';
import '../core/i18n/gen/app_localizations.dart';
import '../core/interaction/interaction.dart';
import '../core/quran/ayah.dart';
import '../core/routing/route_pages.dart';
import '../core/routing/router.dart';
import '../core/settings/app_settings.dart';
import '../core/sound/sound_api.dart';
import '../features/hifz/hifz.dart' show hifzImportProvider;
import '../features/quran/quran.dart' show quranAddToHifzProvider;
import '../features/quran/presentation/widgets/quran_toast.dart' show QuranToast;
import '../features/recitation/recitation.dart' show recitationOpenDownloadsProvider, recitationStateProvider;
import '../features/wird/wird.dart' show wirdReadNowProvider;

/// The Phase 3 features' cross-feature hooks, wired once for the whole app
/// (bootstrap and the test harness share them through `madarAppOverrides`):
///
/// * the Quran reader's "Add to Hifz" adds the ayat through Hifz's import
///   (the user's chunk size, chunks already there skipped) with an undo
///   toast – or says they are already in Hifz;
/// * the wird's "read now" opens the reader (a route) where the plan stands;
/// * recitation's per-reciter downloads open as a route.
List<Override> faithHookOverrides() => [
  quranAddToHifzProvider.overrideWith((ref) => (context, range) => addAyatToHifz(ref, context, range)),
  wirdReadNowProvider.overrideWithValue((context, request) => FaithNav.quranReader(context, ayah: request.start)),
  recitationOpenDownloadsProvider.overrideWithValue(FaithNav.recitationDownloads),
];

/// "Add to Hifz" from the reader's ayah menu. Shows its own feedback (an
/// undo toast, or "already in your Hifz") and so answers false – the
/// reader's plain "added" toast would only repeat it.
@visibleForTesting
Future<bool> addAyatToHifz(Ref ref, BuildContext context, AyahRange range) async {
  final l = L10n.of(context);
  final fmt = MadarFormatter.of(context);
  final overlay = Navigator.maybeOf(context, rootNavigator: true)?.overlay;
  try {
    final result = await ref.read(hifzImportProvider).addAyahRangeToHifz(range);
    if (overlay == null || !overlay.mounted) return false;
    if (result.added.isEmpty) {
      Fx.fire(Sfx.tap);
      if (context.mounted) QuranToast.show(context, l.faithHubHifzAlready);
      return false;
    }
    Fx.fire(Sfx.complete);
    unawaited(
      UndoToast.show(
        overlay,
        UndoableAction(label: fmt.localizeDigits(l.hifzAdded(result.added.length)), undo: result.undo),
      ),
    );
    return false;
  } catch (e) {
    Fx.fire(Sfx.error);
    debugPrint('Add to Hifz failed: $e');
    return false;
  }
}

/// Taps on the recitation's media notification (audio_service): `true` when
/// the app was brought up by one. Tests override it.
final recitationNotificationClicksProvider = Provider<Stream<bool>>((ref) => AudioService.notificationClicked);

/// A tap on the recitation's media notification opens the full player over
/// whatever page is showing (under the app lock, like every deep link) –
/// only while something is being recited.
class RecitationNotificationRouter {
  RecitationNotificationRouter(this._ref) {
    _clicks = _ref
        .read(recitationNotificationClicksProvider)
        .listen(_onClick, onError: (Object e) => debugPrint('Recitation notification: $e'));
  }

  final Ref _ref;
  late final StreamSubscription<bool> _clicks;

  void _onClick(bool clicked) {
    if (!clicked || !_ref.mounted) return;
    if (!_ref.read(appSettingsProvider).onboarded) return;
    if (!_ref.read(recitationStateProvider).active) return;
    final router = _ref.read(routerProvider);
    if (router.state.matchedLocation == AppRoutes.nowPlaying) return;
    unawaited(router.push<void>(AppRoutes.nowPlaying));
  }

  void dispose() => unawaited(_clicks.cancel());
}

final recitationNotificationRouterProvider = Provider<RecitationNotificationRouter>((ref) {
  final router = RecitationNotificationRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});
