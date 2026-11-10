import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/router.dart' show routerProvider;
import '../../../../core/routing/routes.dart';
import '../../../lock/application/lock_controller.dart';
import 'kids_providers.dart';

/// Moves the app in and out of kids mode (the router, the app lock and Android
/// app pinning are looked up when needed).
class KidsActions {
  KidsActions(this._ref);

  final Ref _ref;

  void _go(String location) => _ref.read(routerProvider).go(location);

  /// One tap. The caller has made sure a PIN exists (see `ensureParentPin`).
  void enter() {
    _ref.read(kidsModeProvider.notifier).enter();
    _go(AppRoutes.kids);
  }

  /// Leaves for good: the caller has just had the PIN or the fingerprint
  /// accepted. Lifts the screen pinning, tells the app lock the owner has just
  /// proved himself (so it does not ask again at the adult door) and lands on
  /// the adult home.
  Future<void> leave() async {
    try {
      await _ref.read(kidsPinningProvider).stop();
    } catch (_) {
      // Best effort: pinning is the parent's to lift with the system gesture.
    }
    if (!_ref.mounted) return;
    final lock = _ref.read(lockControllerProvider.notifier);
    lock.unlockVerified();
    lock.revealed();
    _ref.read(kidsModeProvider.notifier).leave();
    _go(AppRoutes.home);
  }
}

final kidsActionsProvider = Provider<KidsActions>(KidsActions.new);
