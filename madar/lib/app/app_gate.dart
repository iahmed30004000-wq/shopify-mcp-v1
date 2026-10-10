import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;

import '../core/db/database.dart';
import '../core/db/db_errors.dart';
import '../core/db/encryption.dart';
import '../core/db/open.dart';
import '../core/design/tokens.dart';
import '../core/design/widgets/widgets.dart';
import '../core/i18n/gen/app_localizations.dart';
import '../core/motion/motion.dart';
import '../core/routing/router.dart';
import '../core/settings/app_settings.dart';
import '../core/sound/sound_api.dart';
import '../features/adhan/presentation/adhan_host.dart';
import '../features/orbit/presentation/orbit_ui_providers.dart' show OrbitWarmUp;
import 'app_services.dart';
import 'system_services.dart' show resetExtrasProvider;
import 'lock_gate.dart';
import 'splash.dart';

/// Opens the database for a seed language (production: reads/creates the
/// key in secure storage and opens the SQLCipher file).
typedef DatabaseOpener = Future<MadarDatabase> Function(SeedOptions seed);

final databaseOpenerProvider = Provider<DatabaseOpener>((ref) {
  final keyStore = ref.watch(databaseKeyStoreProvider);
  return (seed) => unlockMadarDatabase(keyStore: keyStore, seed: seed);
});

/// "Delete all data" used by the gate's recovery path (the database is not
/// open when it runs).
final databaseResetProvider = Provider<Future<void> Function()>((ref) {
  final keyStore = ref.watch(databaseKeyStoreProvider);
  final extras = ref.watch(resetExtrasProvider);
  return () async {
    // The encrypted file and its key first: this one must succeed.
    await deleteAllMadarData(keyStore: keyStore);
    // Then everything that lives outside the database – the AI keys, the
    // widgets' data, the games' site data, Together's online project, every
    // scheduled alarm, the safety copies and the share cache. Each step is
    // best effort, all of them run, and the first error is rethrown so the
    // gate says the reset failed and a retry repeats them.
    await extras();
  };
});

/// The unlocked database, opened once per app run.
///
/// Riverpod 3 wiring (see `madarAppOverrides`): the root scope overrides
/// `databaseProvider` with `ref.watch(databaseUnlockProvider).requireValue`,
/// and [AppGate] only builds the app once this provider has data. Everything
/// lives in the one root container – no nested scopes, so providers that
/// depend on `databaseProvider` need no `dependencies` lists. Invalidating
/// this provider (retry / start fresh) re-runs the unlock and every
/// database-backed provider follows. Automatic retries are off: a wrong key
/// does not fix itself.
final databaseUnlockProvider = FutureProvider<MadarDatabase>((ref) async {
  final open = ref.watch(databaseOpenerProvider);
  final language = ref.read(appSettingsProvider).languageCode;
  final db = await open(SeedOptions(languageCode: language));
  if (!ref.mounted) {
    await db.close();
    throw StateError('database unlock superseded');
  }
  ref.onDispose(() => unawaited(db.close()));
  return db;
}, retry: (_, _) => null);

/// The error behind an unlock failure (unwraps Riverpod and drift isolate
/// wrappers).
Object rootCauseOf(Object error) {
  var e = error;
  while (e is ProviderException) {
    e = e.exception;
  }
  return unwrapDatabaseError(e);
}

/// Whether "start fresh" (delete all data) is offered for [error]: only when
/// the existing file can never be opened again – the key is gone, wrong or
/// damaged – or when secure storage stayed unavailable after at least one
/// retry ([failedRetries]), e.g. its Keystore key was lost.
bool canResetAfter(Object error, {int failedRetries = 0}) => switch (rootCauseOf(error)) {
  DatabaseKeyException(
    problem: DatabaseKeyProblem.missing || DatabaseKeyProblem.wrongKey || DatabaseKeyProblem.malformed,
  ) =>
    true,
  DatabaseKeyException(problem: DatabaseKeyProblem.storageUnavailable) => failedRetries >= 1,
  _ => false,
};

/// Sits between the navigator and the rest of the shell: shows the
/// [AstrolabeSplash] while the database unlocks (at least [minSplash] once
/// the splash is on screen, so it never flashes), a recovery view when
/// unlocking fails, and otherwise the app – layered, from the outside in:
///
/// 1. [AppServices] – adhkar reminders planned, notification taps routed
///    (they run while the app is locked);
/// 2. [AdhanHost] – the adhan's alarms and prayer quiet, and the full-screen
///    adhan presented **above the app lock**: the adhan screen shows nothing
///    personal, and while one that came from a notification is up (possibly
///    over the phone's keyguard) everything beneath it – lock screen and app
///    – is not painted; after it closes the app stays veiled until the phone
///    is unlocked, and the app lock is in front again whenever it is armed;
/// 3. the [LockGate] around the navigator – nothing of the app is painted
///    before the owner unlocks, deep links (an adhkar reminder) move the
///    router underneath it.
///
/// When the database is already available on the first frame (tests,
/// previews) the app shows immediately without a splash.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key, required this.child, this.minSplash = AstrolabeSplash.assembly});

  final Widget child;
  final Duration minSplash;

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> {
  Timer? _hold;
  bool _holding = false;

  /// The orbit's shaders are still being compiled behind the splash (the
  /// first orbit frame must never compile a pipeline); capped by
  /// [maxWarmUp] so a failing shader never keeps the splash up.
  bool _warming = false;
  static const maxWarmUp = Duration(seconds: 4);

  /// Retries that ended in an error again (reset when the unlock succeeds).
  int _failedRetries = 0;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    if (!ref.read(databaseUnlockProvider).hasValue) _startHold();
  }

  void _startHold() {
    _hold?.cancel();
    if (widget.minSplash <= Duration.zero) return;
    if (OrbitWarmUp.gatesSplash && !OrbitWarmUp.isDone) {
      _warming = true;
      unawaited(
        OrbitWarmUp.start().timeout(maxWarmUp, onTimeout: () {}).whenComplete(() {
          if (mounted && _warming) setState(() => _warming = false);
        }),
      );
    }
    _holding = true;
    _hold = Timer(widget.minSplash, () {
      if (mounted) setState(() => _holding = false);
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  void _retry() {
    _retrying = true;
    _startHold();
    ref.invalidate(databaseUnlockProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(databaseUnlockProvider, (_, next) {
      if (next.isLoading) return;
      if (next.hasValue) {
        _failedRetries = 0;
      } else if (next.hasError && _retrying) {
        setState(() => _failedRetries++);
      }
      _retrying = false;
    });
    final unlock = ref.watch(databaseUnlockProvider);
    final batterySaver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    final holding = (_holding && !context.reducedMotion) || _warming;
    final Widget content;
    if (unlock.hasValue && !unlock.isLoading && !holding) {
      content = KeyedSubtree(
        key: const ValueKey('app'),
        child: AppServices(
          child: AdhanHost(
            backButtonDispatcher: ref.watch(routerProvider).backButtonDispatcher,
            child: ref.watch(lockGateProvider).wrap(context, widget.child),
          ),
        ),
      );
    } else if (unlock.hasError && !unlock.isLoading) {
      content = _GateError(
        key: const ValueKey('error'),
        error: unlock.error!,
        onRetry: _retry,
        onReset: canResetAfter(unlock.error!, failedRetries: _failedRetries)
            ? () async {
                await ref.read(databaseResetProvider)();
                _retry();
              }
            : null,
      );
    } else {
      content = AstrolabeSplash(key: const ValueKey('splash'), animateBackdrop: !batterySaver);
    }
    return AnimatedSwitcher(
      duration: context.motion(MadarMotion.long),
      switchInCurve: MadarMotion.decelerate,
      switchOutCurve: MadarMotion.accelerate,
      transitionBuilder: (child, animation) {
        final entering = child.key == const ValueKey('app');
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: entering ? 1.04 : 0.96, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: content,
    );
  }
}

/// Recovery view: what went wrong, "try again" and – when the old file can
/// never be read – "start fresh" behind an inline confirmation.
class _GateError extends StatefulWidget {
  const _GateError({super.key, required this.error, required this.onRetry, this.onReset});

  final Object error;
  final VoidCallback onRetry;
  final Future<void> Function()? onReset;

  @override
  State<_GateError> createState() => _GateErrorState();
}

class _GateErrorState extends State<_GateError> {
  bool _confirming = false;
  bool _busy = false;
  bool _failed = false;

  Future<void> _reset() async {
    setState(() => _busy = true);
    try {
      await widget.onReset!();
    } catch (_) {
      Fx.fire(Sfx.error);
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Fx.fire(Sfx.error);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final message = describeDatabaseError(l, rootCauseOf(widget.error));
    return CosmosBackdrop(
      intensity: 0.7,
      seed: 0.8,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(Space.xl),
            child: BackdropGroup(
              child: GlassPanel(
                padding: const EdgeInsetsDirectional.all(Space.xl),
                glowColor: t.danger.withValues(alpha: 0.25),
                child: AnimatedSize(
                  duration: context.motion(MadarMotion.medium),
                  curve: MadarMotion.standard,
                  alignment: AlignmentDirectional.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IslamicStar(size: 40, glow: true, color: _confirming ? t.danger : t.gold),
                      const SizedBox(height: Space.l),
                      Semantics(
                        header: true,
                        child: Text(
                          _confirming ? l.shellGateResetTitle : l.shellGateErrorTitle,
                          textAlign: TextAlign.center,
                          style: text.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: Space.s),
                      Text(
                        _failed ? l.shellGateResetFailed : (_confirming ? l.shellGateResetBody : message),
                        textAlign: TextAlign.center,
                        style: text.bodyMedium!.copyWith(color: t.textSecondary),
                      ),
                      const SizedBox(height: Space.xl),
                      if (_confirming) ...[
                        MadarButton(
                          label: l.shellGateResetConfirm,
                          icon: Icons.delete_forever_rounded,
                          variant: MadarButtonVariant.danger,
                          expand: true,
                          loading: _busy,
                          sfx: Sfx.delete,
                          onPressed: _reset,
                        ),
                        const SizedBox(height: Space.s),
                        MadarButton(
                          label: l.actionCancel,
                          variant: MadarButtonVariant.ghost,
                          expand: true,
                          sfx: Sfx.back,
                          onPressed: _busy ? null : () => setState(() => _confirming = false),
                        ),
                      ] else ...[
                        MadarButton(
                          label: l.shellGateRetry,
                          icon: Icons.refresh_rounded,
                          expand: true,
                          onPressed: widget.onRetry,
                        ),
                        if (widget.onReset != null) ...[
                          const SizedBox(height: Space.s),
                          MadarButton(
                            label: l.shellGateReset,
                            variant: MadarButtonVariant.ghost,
                            expand: true,
                            sfx: Sfx.notify,
                            onPressed: () => setState(() => _confirming = true),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
