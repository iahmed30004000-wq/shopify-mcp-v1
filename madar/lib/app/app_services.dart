import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notifications.dart';
import '../core/routing/router.dart';
import '../core/settings/app_settings.dart';
import '../features/adhkar/adhkar.dart' show AdhkarReminderTaps, adhkarReminderSyncProvider;
import '../features/prayer/domain/time_zones.dart';
import '../features/quran/quran.dart' show quranMetaProvider;
import '../features/recitation/recitation.dart' show RecitationPlayer, recitationPlayerProvider;
import '../features/wird/wird.dart' show WirdReminderTaps, wirdCompletionSyncProvider, wirdReminderSyncProvider;
import 'faith_services.dart';
import 'health_services.dart';
import 'life_services.dart';
import 'money_services.dart';

/// Prepares the services the app needs soon but never on the first frame:
/// the full time-zone database (prayer times of a location in another zone,
/// the adhan planner) and the notifications plugin, whose launch details
/// tell the adhan hub whether the app was opened by an adhan.
///
/// Called right after the first frame (see `bootstrap`); each step fails on
/// its own and only logs – without notifications Madar still runs, it just
/// cannot sound the adhan or remind. Last, the Quran's small structure file
/// is read (never the text): the Faith page and the wird need it first.
Future<void> warmUpServices(ProviderContainer container) async {
  try {
    MadarTimeZones.ensure();
  } catch (e, s) {
    _log('time zones', e, s);
  }
  try {
    await container.read(notificationServiceProvider).init();
  } catch (e, s) {
    _log('notifications', e, s);
  }
  // The Quran's structure (sura names, pages, juz – 13 KB) is warm before
  // the Faith page, the wird and the reader first ask for it; the text
  // itself stays lazy (the reader, search or Hifz load it on demand).
  try {
    await container.read(quranMetaProvider.future);
  } catch (e, s) {
    _log('quran structure', e, s);
  }
}

void _log(String what, Object error, StackTrace stack) {
  if (kDebugMode) debugPrint('Madar warm-up ($what) failed: $error\n$stack');
}

/// Routes the taps on Madar's notifications that open a page of the app (the
/// adhan's own taps are the adhan hub's: it presents the full-screen adhan
/// above everything).
///
/// * An adhkar reminder opens its set in the reader
///   (`/adhkar/<set>`), a wird reminder the wird page on its plan
///   (`/wird?plan=<id>`), a dose notification the medications (`/meds`),
///   an appointment reminder the appointments with it lit
///   (`/record/appointments?highlight=<id>`) and the worry window the
///   worries (`/wellbeing?tab=worries`), a debt's or an obligation's due
///   reminder the goals with its sheet up (`/goals?tab=debts&debt=<id>`),
///   the family's reach-out digest the Family page (`/family`), a birthday that
///   person's page (`/family/person/<id>`), a travel document's expiry the
///   documents (`/travel?tab=documents`), a fasting notice the fasting tab
///   (`/body?tab=fasting`) and a tracker's reminder that tracker
///   (`/modules/module/<id>`) – whether it launched the app (cold start) or
///   reached it running (warm). A dose's Taken / Snooze / Skip
///   buttons never navigate: they are recorded ([healthNotificationLocation]).
/// * The router moves underneath the app lock: when Madar is locked the lock
///   screen stays in front, and the reader is what the owner sees after
///   unlocking – a notification never reveals anything past the lock.
class AppNotificationRouter {
  AppNotificationRouter(this._ref) {
    final service = _ref.read(notificationServiceProvider);
    _taps = service.taps.listen(_onTap);
    unawaited(_readLaunch(service));
  }

  final Ref _ref;
  late final StreamSubscription<NotificationTap> _taps;

  /// Where [tap] leads, or null when it is not for the app shell.
  static String? locationOf(NotificationTap tap) {
    final set = AdhkarReminderTaps.categoryOf(tap);
    if (set != null) return AppRoutes.adhkarSetOf(set.name);
    final plan = WirdReminderTaps.planOf(tap);
    if (plan != null) return AppRoutes.wirdOf(plan);
    return healthNotificationLocation(tap) ?? moneyNotificationLocation(tap) ?? lifeNotificationLocation(tap);
  }

  Future<void> _readLaunch(NotificationService service) async {
    try {
      final tap = await service.takeLaunchTap(where: (t) => locationOf(t) != null);
      if (tap != null) _onTap(tap);
    } catch (e, s) {
      _log('launch notification', e, s);
    }
  }

  void _onTap(NotificationTap tap) {
    final location = locationOf(tap);
    if (location == null || !_ref.mounted) return;
    // Before onboarding nothing is scheduled; a stale tap must not skip it.
    if (!_ref.read(appSettingsProvider).onboarded) return;
    _ref.read(routerProvider).go(location);
  }

  void dispose() => unawaited(_taps.cancel());
}

final appNotificationRouterProvider = Provider<AppNotificationRouter>((ref) {
  final router = AppNotificationRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});

/// The unlocked app's background services, mounted once inside the database
/// gate (they read the encrypted database) and outside the app lock (they
/// run while it is locked):
///
/// * adhkar reminders stay planned (re-planned on settings, location,
///   language and day changes – [adhkarReminderSyncProvider]);
/// * wird reminders likewise, a week ahead after each plan's prayer
///   ([wirdReminderSyncProvider]), and a wird portion read in the Quran
///   reader is logged as done ([wirdCompletionSyncProvider]);
/// * notification taps open their pages ([AppNotificationRouter]), a tap on
///   the recitation's media notification the full player
///   ([RecitationNotificationRouter]);
/// * a listening session still open when the engine detaches from its last
///   activity is written ([RecitationPlayer.flushSession]);
/// * the health reminders stay planned – doses (48 h rolling), appointments,
///   the worry window – and a dose answered from its notification is
///   recorded ([watchHealthServices]);
/// * the debts' and obligations' due reminders stay planned
///   ([watchMoneyServices]);
/// * a card placed in a prayer window stays in step with its task, the Top
///   3 settles at midnight, trips follow their dates, and the family's,
///   travel documents', fasting and trackers' reminders stay planned
///   ([watchLifeServices]).
///
/// The adhan's own services (alarm planning, prayer quiet, the full-screen
/// adhan) live in `AdhanHost`, directly below this.
class AppServices extends ConsumerStatefulWidget {
  const AppServices({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppServices> createState() => _AppServicesState();
}

class _AppServicesState extends ConsumerState<AppServices> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only a player that exists (never create one to flush nothing).
    if (state == AppLifecycleState.detached && ref.exists(recitationPlayerProvider)) {
      unawaited(ref.read(recitationPlayerProvider).flushSession().catchError((Object e) => _logFlush(e)));
    }
  }

  static void _logFlush(Object e) {
    if (kDebugMode) debugPrint('Madar: recitation session flush failed: $e');
  }

  @override
  Widget build(BuildContext context) {
    // Slot kept free for the notification centre (Phase 9): it is watched
    // FIRST, so its policy is in the gate before any sync below re-plans.
    ref.watch(adhkarReminderSyncProvider);
    ref.watch(wirdReminderSyncProvider);
    ref.watch(wirdCompletionSyncProvider);
    ref.watch(appNotificationRouterProvider);
    ref.watch(recitationNotificationRouterProvider);
    watchHealthServices(ref);
    watchMoneyServices(ref);
    watchLifeServices(ref);
    return widget.child;
  }
}
