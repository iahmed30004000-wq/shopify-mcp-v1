import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../../../core/db/repositories/key_value_repository.dart';
import '../../../../core/providers.dart';
import '../../core/kids_section.dart';
import '../data/rewards_store.dart';
import '../domain/rewards_ledger.dart';

/// The wall clock the day-based de-duplication reads (tests freeze it).
final kidsRewardsClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final kidsRewardsStoreProvider = Provider<RewardsStore>(
  (ref) => RewardsStore(KeyValueKidsStore(KeyValueRepository(ref.watch(databaseProvider)))),
);

/// The child's stars. State is what is already safe on the device.
final kidsRewardsProvider = NotifierProvider<KidsRewardsNotifier, RewardsLedger>(KidsRewardsNotifier.new);

class KidsRewardsNotifier extends Notifier<RewardsLedger> {
  late Future<void> _loaded;
  Future<void> _queue = Future<void>.value();

  @override
  RewardsLedger build() {
    _loaded = _load();
    return RewardsLedger.empty;
  }

  /// Completes once the stored ledger has been read (tests await it).
  Future<void> get ready => _loaded;

  Future<void> _load() async {
    try {
      final stored = await ref.read(kidsRewardsStoreProvider).load();
      if (ref.mounted) state = stored.union(state);
    } on Object catch (e) {
      // Never a crash for a child: start from what is on screen.
      debugPrint('kids rewards: cannot load: $e');
    }
  }

  /// One star for [reason], at most once per reason per day. Returns whether
  /// a star was added. The count on screen changes only after the star is
  /// written to the device.
  Future<bool> award(String reason) {
    final done = Completer<bool>();
    _queue = _queue.then((_) async {
      try {
        await _loaded;
        if (!ref.mounted) return done.complete(false);
        final next = state.award(reason, ref.read(kidsRewardsClockProvider)());
        if (next == null) return done.complete(false);
        await ref.read(kidsRewardsStoreProvider).save(next);
        if (ref.mounted) state = next;
        done.complete(true);
      } on Object catch (e) {
        debugPrint('kids rewards: cannot save a star: $e');
        done.complete(false);
      }
    });
    return done.future;
  }
}

/// What the integrator adds to the app's overrides: the kids home star count
/// and the award function every section calls.
final List<Override> kidsRewardsOverrides = [
  kidsStarCountProvider.overrideWith((ref) => ref.watch(kidsRewardsProvider).count),
  kidsStarAwardProvider.overrideWith((ref) {
    final notifier = ref.read(kidsRewardsProvider.notifier);
    return (reason) async {
      await notifier.award(reason);
    };
  }),
];
