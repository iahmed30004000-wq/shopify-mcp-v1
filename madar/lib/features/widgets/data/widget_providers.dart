import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/budget_math.dart' show BudgetWindow;
import '../../../core/domain/enums.dart' show BudgetPeriod;
import '../../../core/settings/app_settings.dart';
import '../../health/meds/data/meds_providers.dart'
    show medLogsProvider, medsListProvider, medsSchedulerProvider, medsNotificationTextsProvider;
import '../../health/meds/domain/dose_tracker.dart';
import '../../health/meds/domain/meds_planner.dart';
import '../../home/home_providers.dart' show appForegroundProvider, homeClockProvider;
import '../../lock/application/lock_controller.dart' show lockControllerProvider, lockHintStoreProvider;
import '../../money/budget/data/budget_providers.dart'
    show budgetCurrenciesProvider, budgetExpensesProvider, budgetMathProvider, budgetWeekStartProvider;
import '../../money/budget/data/budget_repository.dart' show BudgetCurrencies;
import '../../money/budget/domain/budget_spending.dart' show BudgetSpending;
import '../../money/budget/presentation/budget_format.dart';
import '../../orbit/data/orbit_providers.dart' show orbitTodayProvider, prayerScheduleProvider, prayerSettingsProvider;
import '../../work/data/work_providers.dart' show workTop3Provider;
import '../../work/domain/top3.dart';
import '../domain/budget_widget.dart';
import '../domain/meds_widget.dart';
import '../domain/prayer_widget.dart';
import '../domain/tasks_widget.dart';
import '../domain/widget_build.dart';
import '../domain/widget_kind.dart';
import '../domain/widget_links.dart';
import '../domain/widget_prefs.dart';
import '../domain/widget_snapshot.dart';
import '../domain/widget_texts.dart';
import 'widget_bridge.dart';
import 'widget_platform.dart';

// ------------------------------------------------------------ platform ----

/// The Android side (a [FakeWidgetPlatform] in tests).
final widgetPlatformProvider = Provider<WidgetPlatform>((ref) {
  final platform = MethodChannelWidgetPlatform();
  ref.onDispose(platform.dispose);
  return platform;
});

final widgetBridgeProvider = Provider<WidgetBridge>((ref) => WidgetBridge(ref.watch(widgetPlatformProvider)));

// ------------------------------------------------------------- settings ----

/// The widgets' own settings (SharedPreferences, nothing personal).
final widgetPrefsProvider = NotifierProvider<WidgetPrefsController, WidgetPrefs>(WidgetPrefsController.new);

class WidgetPrefsController extends Notifier<WidgetPrefs> {
  static const String key = 'madar.widgets.v1';

  @override
  WidgetPrefs build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(key);
    if (raw == null) return const WidgetPrefs();
    try {
      return WidgetPrefs.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      return const WidgetPrefs();
    }
  }

  /// [show] null: back to the default (hidden while the app lock is on).
  ///
  /// "Hide" is always kept: hiding never puts anything on the home screen,
  /// so a widget hidden under the lock stays hidden when the lock is turned
  /// off. "Show" is kept only as a departure from the default – the user's
  /// explicit opt-in while the lock is on; picked while the lock is off (the
  /// default then) it is no choice and is not kept, so names, times and
  /// amounts leave the home screen once the lock is turned on.
  Future<void> setDetails(MadarWidgetKind kind, bool? show) {
    final byDefault = const WidgetPrefs().showsDetails(kind, appLockOn: ref.read(widgetAppLockOnProvider));
    return _save(state.withDetails(kind, show == true && byDefault ? null : show));
  }

  Future<void> setBudgetPeriod(BudgetPeriod period) => _save(state.withBudgetPeriod(period));

  Future<void> _save(WidgetPrefs next) async {
    state = next;
    await ref.read(sharedPreferencesProvider).setString(key, jsonEncode(next.toJson()));
  }
}

/// Whether the app lock is on (enabled with a PIN set – what locks the app).
/// While it is, widgets show counts only unless the user chose otherwise.
final widgetAppLockOnProvider = Provider<bool>((ref) {
  if (!ref.watch(appSettingsProvider.select((s) => s.lockEnabled))) return false;
  final (loaded, hasPin) = ref.watch(lockControllerProvider.select((s) => (s.loaded, s.hasPin)));
  if (loaded) return hasPin;
  // Before the secure record is read: the first-frame hint.
  return ref.read(lockHintStoreProvider).read().pin;
});

/// Whether [kind] shows details (names, times, amounts) or counts only.
final widgetShowsDetailsProvider = Provider.family<bool, MadarWidgetKind>((ref, kind) {
  final prefs = ref.watch(widgetPrefsProvider);
  return prefs.showsDetails(kind, appLockOn: ref.watch(widgetAppLockOnProvider));
});

/// The widgets' texts in the app's language and digits.
final widgetTextsProvider = Provider<WidgetTexts>((ref) {
  final (lang, digits) = ref.watch(appSettingsProvider.select((s) => (s.languageCode, s.digits)));
  return WidgetTexts.forLanguage(lang, digits: digits);
});

// ---------------------------------------------------------------- clock ----

/// The widgets' wall clock (home's; tests freeze it).
final widgetClockProvider = Provider<DateTime Function()>((ref) => ref.watch(homeClockProvider));

/// "Now" for the snapshots: re-read when the app comes back to the
/// foreground and at midnight (today turns over). Between app runs the
/// widgets move on by themselves through their pages (prayer times,
/// midnight), which cover the next one to three days – no timer of its own.
final widgetNowProvider = NotifierProvider<WidgetNow, DateTime>(WidgetNow.new);

class WidgetNow extends Notifier<DateTime> {
  @override
  DateTime build() {
    final clock = ref.watch(widgetClockProvider);
    // Midnight rebuilds this with a fresh "now".
    ref.watch(orbitTodayProvider);
    final foreground = ref.watch(appForegroundProvider);
    void onForeground() {
      if (foreground.value) state = clock();
    }

    foreground.addListener(onForeground);
    ref.onDispose(() => foreground.removeListener(onForeground));
    return clock();
  }
}

// ------------------------------------------------------------ snapshots ----

/// The snapshot of [kind] for the current data, or loading while its data
/// is (null: nothing to show yet). Only watched for widgets on a home
/// screen ([widgetSyncProvider]) – nothing is read for the others.
final widgetBuildProvider = Provider.autoDispose.family<AsyncValue<WidgetBuild>, MadarWidgetKind>((ref, kind) {
  final texts = ref.watch(widgetTextsProvider);
  final details = ref.watch(widgetShowsDetailsProvider(kind));
  final now = ref.watch(widgetNowProvider);
  try {
    return switch (kind) {
      MadarWidgetKind.prayer => _prayer(ref, now, texts, details),
      MadarWidgetKind.meds => _meds(ref, now, texts, details),
      MadarWidgetKind.tasks => _tasks(ref, now, texts, details),
      MadarWidgetKind.budget => _budget(ref, now, texts, details),
    };
  } catch (e, s) {
    return AsyncError(e, s);
  }
});

AsyncValue<WidgetBuild> _prayer(Ref ref, DateTime now, WidgetTexts texts, bool details) {
  // Wait for the stored settings: the defaults (Amman) must never reach a
  // home screen for a user elsewhere.
  final settings = ref.watch(prayerSettingsProvider);
  if (settings case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  if (!settings.hasValue) return const AsyncLoading();
  final schedule = ref.watch(prayerScheduleProvider);
  return AsyncData(PrayerWidgetBuilder.build(schedule: schedule, now: now, texts: texts, details: details));
}

AsyncValue<WidgetBuild> _meds(Ref ref, DateTime now, WidgetTexts texts, bool details) {
  final scheduler = ref.watch(medsSchedulerProvider);
  final logs = ref.watch(medLogsProvider);
  final meds = ref.watch(medsListProvider);
  for (final a in [logs, meds]) {
    if (a case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  }
  if (scheduler == null || !logs.hasValue || !meds.hasValue) return const AsyncLoading();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final period = MedsPlanner.period(scheduler, from: today, count: 2, logs: logs.requireValue, now: now);
  final medsTexts = ref.watch(medsNotificationTextsProvider);
  List<WidgetDose> map(List<TrackedDose> doses) => [
    for (final d in doses)
      WidgetDose(
        name: d.dose.med.name,
        dose: medsTexts.doseLine(d.dose),
        at: d.dose.at,
        state: switch (d.state) {
          DoseState.taken => WidgetRowState.done,
          DoseState.skipped => WidgetRowState.skipped,
          _ => WidgetRowState.open,
        },
      ),
  ];
  return AsyncData(
    WidgetBuild(
      MedsWidgetBuilder.build(
        now: now,
        today: map(period.on(today)),
        tomorrow: map(period.on(tomorrow)),
        hasMeds: meds.requireValue.any((m) => m.active),
        texts: texts,
        details: details,
      ),
    ),
  );
}

AsyncValue<WidgetBuild> _tasks(Ref ref, DateTime now, WidgetTexts texts, bool details) {
  return ref.watch(workTop3Provider).whenData((state) {
    final items = [
      for (final i in state.items)
        WidgetTask(
          title: i.title,
          done: i.done,
          link: i.kind == FocusKind.task ? WidgetLinks.task(i.id) : WidgetLinks.card(i.id, boardId: i.boardId),
        ),
    ];
    return WidgetBuild(
      TasksWidgetBuilder.build(
        now: now,
        items: items,
        carriedOver: state.leftovers.length,
        texts: texts,
        details: details,
      ),
    );
  });
}

AsyncValue<WidgetBuild> _budget(Ref ref, DateTime now, WidgetTexts texts, bool details) {
  final period = ref.watch(widgetPrefsProvider.select((p) => p.budgetPeriod));
  final weekStart = ref.watch(budgetWeekStartProvider);
  final math = ref.watch(budgetMathProvider);
  final txs = ref.watch(budgetExpensesProvider);
  final currencies = ref.watch(budgetCurrenciesProvider);
  for (final a in [math, txs]) {
    if (a case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  }
  if (!math.hasValue || !txs.hasValue) return const AsyncLoading();
  final today = DateTime(now.year, now.month, now.day);
  final window = period == BudgetPeriod.weekly
      ? BudgetWindow.week(today, weekStart: weekStart)
      : BudgetWindow.month(today);
  final summary = BudgetSpending.summaryOf(math.requireValue, txs.requireValue, window);
  final format = BudgetFormat(texts.fmt, currencies: currencies.value ?? BudgetCurrencies.fallback);
  return AsyncData(
    WidgetBuild(
      BudgetWidgetBuilder.build(
        now: now,
        budget: WidgetBudget(
          period: period,
          start: window.start,
          end: window.end,
          plannedMilli: summary.plannedMilli,
          spentMilli: summary.spentMilli,
        ),
        money: format.money,
        texts: texts,
        details: details,
      ),
    ),
  );
}

// ----------------------------------------------------------------- sync ----

/// The kinds with a widget on a home screen, asked from Android at start,
/// whenever the app comes back to the foreground and when a widget is
/// added or removed.
final widgetInstalledProvider = NotifierProvider<WidgetInstalled, Set<MadarWidgetKind>>(WidgetInstalled.new);

class WidgetInstalled extends Notifier<Set<MadarWidgetKind>> {
  @override
  Set<MadarWidgetKind> build() {
    final platform = ref.watch(widgetPlatformProvider);
    final events = platform.events.listen((e) {
      if (e == WidgetPlatformEvent.changed) unawaited(refresh(rewrite: true));
    });
    final foreground = ref.watch(appForegroundProvider);
    void onForeground() {
      if (foreground.value) unawaited(refresh());
    }

    foreground.addListener(onForeground);
    ref.onDispose(() {
      unawaited(events.cancel());
      foreground.removeListener(onForeground);
    });
    unawaited(Future<void>.microtask(refresh));
    return const {};
  }

  /// Asks Android again. [rewrite]: a widget was added or removed while the
  /// app may not have been watching (Android deletes a kind's data when its
  /// last widget goes), or a widget has nothing to show (its data ran out,
  /// or the phone changed time zone), so every installed kind is built again
  /// from a fresh "now" – the app may have sat in the background since its
  /// last one – and written again.
  Future<void> refresh({bool rewrite = false}) async {
    try {
      final kinds = await ref.read(widgetPlatformProvider).installed();
      if (!ref.mounted) return;
      if (rewrite) {
        ref.read(widgetBridgeProvider).forgetAll();
        ref.invalidate(widgetNowProvider);
      }
      if (!setEquals(kinds, state)) {
        state = Set.unmodifiable(kinds);
      } else if (rewrite) {
        ref.read(widgetRewriteProvider.notifier).bump();
      }
    } catch (e) {
      _log('installed widgets', e);
    }
  }
}

/// Bumped when every installed widget must be written again although the
/// set of installed kinds is the same (see [WidgetInstalled.refresh]).
final widgetRewriteProvider = NotifierProvider<WidgetRewrite, int>(WidgetRewrite.new);

class WidgetRewrite extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// How long data changes settle before a widget is written.
final widgetSyncDebounceProvider = Provider<Duration>((ref) => const Duration(milliseconds: 800));

/// Keeps the widgets on the home screen up to date while the app runs: for
/// each kind that has a widget, its snapshot is rebuilt whenever its data,
/// the language, the digits, its details choice or the app lock changes
/// (and at start, on resume, at midnight), then written – debounced, and
/// only when it changed. Kinds without a widget are neither read nor
/// written. The state is the set of kinds written at least once this run.
final widgetSyncProvider = NotifierProvider<WidgetSync, Set<MadarWidgetKind>>(WidgetSync.new);

class WidgetSync extends Notifier<Set<MadarWidgetKind>> {
  final Map<MadarWidgetKind, Timer> _timers = {};
  final Map<MadarWidgetKind, WidgetBuild> _pending = {};
  Future<void> _queue = Future.value();

  @override
  Set<MadarWidgetKind> build() {
    final installed = ref.watch(widgetInstalledProvider);
    // A rewrite rebuilds this: every listener below fires again.
    ref.watch(widgetRewriteProvider);
    final bridge = ref.watch(widgetBridgeProvider);
    final debounce = ref.watch(widgetSyncDebounceProvider);
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
      _pending.clear();
    });
    for (final kind in MadarWidgetKind.values) {
      if (!installed.contains(kind)) {
        // Removed from the home screen: Android deleted its data.
        bridge.forget(kind);
        continue;
      }
      ref.listen<AsyncValue<WidgetBuild>>(widgetBuildProvider(kind), (_, next) {
        if (next case AsyncData(:final value)) _schedule(kind, value, bridge, debounce);
      }, fireImmediately: true);
    }
    return stateOrNull ?? const {};
  }

  void _schedule(MadarWidgetKind kind, WidgetBuild build, WidgetBridge bridge, Duration debounce) {
    _pending[kind] = build;
    _timers[kind]?.cancel();
    _timers[kind] = Timer(debounce, () {
      _timers.remove(kind);
      final b = _pending.remove(kind);
      if (b == null) return;
      _queue = _queue.then((_) async {
        try {
          await bridge.push(b);
          if (ref.mounted && !state.contains(kind)) state = {...state, kind};
        } catch (e) {
          _log('writing the ${kind.wire} widget', e);
        }
      });
    });
  }

  /// Completes when every write scheduled so far has landed (tests).
  @visibleForTesting
  Future<void> get idle => _queue;
}

// --------------------------------------------------------------- launch ----

/// Routes widget taps: the location of the tap that launched the app
/// (cold start) or reached it running, taken once from Android, checked
/// against [WidgetLinks.isAllowed] and opened – underneath the app lock,
/// like a notification tap: the lock screen stays in front when locked.
/// Before onboarding nothing opens.
class WidgetLaunchRouter {
  WidgetLaunchRouter(this._ref, this._open) {
    final platform = _ref.read(widgetPlatformProvider);
    _events = platform.events.listen((e) {
      if (e == WidgetPlatformEvent.launch) unawaited(take());
    });
    unawaited(take());
  }

  final Ref _ref;
  final void Function(String location) _open;
  late final StreamSubscription<WidgetPlatformEvent> _events;

  Future<void> take() async {
    try {
      final location = await _ref.read(widgetPlatformProvider).takeLaunch();
      if (!WidgetLinks.isAllowed(location) || !_ref.mounted) return;
      if (!_ref.read(appSettingsProvider).onboarded) return;
      _open(location!);
    } catch (e) {
      _log('widget launch', e);
    }
  }

  void dispose() => unawaited(_events.cancel());
}

void _log(String what, Object error) {
  if (kDebugMode) debugPrint('Madar widgets: $what failed: $error');
}
