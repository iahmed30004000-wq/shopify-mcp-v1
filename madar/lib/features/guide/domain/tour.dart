/// The coach tour's sequencing and once-only rule, without any widgets.
library;

import 'package:flutter/foundation.dart';

import 'guide_seen_store.dart';

enum TourOutcome { completed, skipped }

/// Where a tour is. Immutable; every move returns a new state.
@immutable
class TourState {
  const TourState(this.total, {this.index = 0, this.outcome}) : assert(total > 0 && index >= 0 && index < total);

  /// A tour has three or four bubbles; one is allowed, none is not a tour.
  final int total;
  final int index;

  /// Null while running.
  final TourOutcome? outcome;

  bool get isRunning => outcome == null;
  bool get isFirst => index == 0;
  bool get isLast => index == total - 1;

  TourState next() {
    if (!isRunning) return this;
    return isLast ? TourState(total, index: index, outcome: TourOutcome.completed) : TourState(total, index: index + 1);
  }

  TourState back() => isRunning && !isFirst ? TourState(total, index: index - 1) : this;

  TourState skip() => isRunning ? TourState(total, index: index, outcome: TourOutcome.skipped) : this;

  @override
  bool operator ==(Object other) =>
      other is TourState && other.total == total && other.index == index && other.outcome == outcome;

  @override
  int get hashCode => Object.hash(total, index, outcome);
}

/// "Run once" bookkeeping over a [GuideSeenStore]. Finishing a tour and
/// skipping it both count as seen; a replay from «؟» ignores the rule.
class TourGate {
  const TourGate(this.store);

  final GuideSeenStore store;

  static String _key(String tourId) => 'tour.$tourId';

  Future<bool> shouldRun(String tourId) async => !await store.isSeen(_key(tourId));

  Future<void> markSeen(String tourId) => store.markSeen(_key(tourId));

  /// Lets the tour run again on the next visit (settings › reset the guide).
  Future<void> reset(String tourId) => store.forget(_key(tourId));
}
