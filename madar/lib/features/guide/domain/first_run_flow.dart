/// The first-run steps as a pure state machine. It knows the order, what was
/// done or skipped, and how to save and resume; the screens for each step are
/// built by the app from [FirstRunStep] ids.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The six steps, in order. [id] is what gets saved: never rename one.
enum FirstRunStep {
  /// Welcome (and the «do you have a backup?» offer).
  welcome('welcome'),

  /// City, which gives the prayer times.
  city('city'),

  /// Choose the planets.
  planets('planets'),

  /// The reminders permission, with why.
  reminders('reminders'),

  /// Fingerprint lock.
  lock('lock'),

  /// Ready.
  ready('ready');

  const FirstRunStep(this.id);

  final String id;

  static FirstRunStep? byId(Object? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

enum FirstRunStatus {
  /// Walking through the steps.
  inProgress,

  /// Chose «I have a backup»: the app is restoring it.
  restoringBackup,

  /// Reached the end (or a backup restore finished).
  completed,

  /// Left the whole thing with «skip all».
  skippedAll,
}

/// Immutable: every transition returns a new flow.
@immutable
class FirstRunFlow {
  const FirstRunFlow._({
    required this.current,
    required this.status,
    required this.done,
    required this.skipped,
  });

  /// A fresh first run, at the welcome step.
  const FirstRunFlow.start()
    : current = FirstRunStep.welcome,
      status = FirstRunStatus.inProgress,
      done = const {},
      skipped = const {};

  static const List<FirstRunStep> steps = FirstRunStep.values;

  /// The step on screen (the last one reached, once finished).
  final FirstRunStep current;
  final FirstRunStatus status;

  /// Steps left with «next», and steps left with «skip this step» / «skip all».
  final Set<FirstRunStep> done;
  final Set<FirstRunStep> skipped;

  int get index => current.index;
  int get total => steps.length;
  bool get isFirst => current == steps.first;
  bool get isLast => current == steps.last;
  bool get isInProgress => status == FirstRunStatus.inProgress;

  /// Whether the first run is over, by any road: the app should not show it
  /// again.
  bool get isFinished => status == FirstRunStatus.completed || status == FirstRunStatus.skippedAll;

  bool get canGoBack => isInProgress && !isFirst;

  /// «Skip this step» is offered on every step but the last (the last one
  /// only has «start»).
  bool get canSkipStep => isInProgress && !isLast;

  /// «Skip all» is offered while there is still something to skip.
  bool get canSkipAll => isInProgress && !isLast;

  /// «Do you have a backup?» is offered at step one only.
  bool get canOfferBackup => isInProgress && isFirst;

  /// 0..1 for a progress bar (step one = 1/6).
  double get progress => (index + 1) / total;

  bool wasSkipped(FirstRunStep s) => skipped.contains(s);

  /// Done this step, move on. From the last step the first run completes.
  FirstRunFlow next() {
    if (!isInProgress) return this;
    final d = {...done, current};
    final s = {...skipped}..remove(current);
    if (isLast) return _copy(status: FirstRunStatus.completed, done: d, skipped: s);
    return _copy(current: steps[index + 1], done: d, skipped: s);
  }

  /// One step back. What was done stays done; the person can redo it.
  FirstRunFlow back() => canGoBack ? _copy(current: steps[index - 1]) : this;

  /// Leave this step without doing it.
  FirstRunFlow skipStep() {
    if (!canSkipStep) return this;
    return _copy(current: steps[index + 1], skipped: {...skipped, current}, done: {...done}..remove(current));
  }

  /// Leave the whole first run: every step not yet done counts as skipped.
  FirstRunFlow skipAll() {
    if (!canSkipAll) return this;
    final rest = {for (final s in steps.skip(index)) s}.difference(done);
    return _copy(status: FirstRunStatus.skippedAll, skipped: {...skipped, ...rest});
  }

  /// «Yes, I have a backup» at step one.
  FirstRunFlow haveBackup() => canOfferBackup ? _copy(status: FirstRunStatus.restoringBackup) : this;

  /// The restore worked: it brings the settings with it, so the rest of the
  /// steps are not asked.
  FirstRunFlow backupRestored() {
    if (status != FirstRunStatus.restoringBackup) return this;
    return _copy(
      status: FirstRunStatus.completed,
      done: {...done, FirstRunStep.welcome},
      skipped: {...skipped, ...steps.skip(1)},
    );
  }

  /// The restore was cancelled or failed: back to the welcome step.
  FirstRunFlow backupCancelled() {
    if (status != FirstRunStatus.restoringBackup) return this;
    return _copy(status: FirstRunStatus.inProgress, current: FirstRunStep.welcome);
  }

  FirstRunFlow _copy({FirstRunStep? current, FirstRunStatus? status, Set<FirstRunStep>? done, Set<FirstRunStep>? skipped}) =>
      FirstRunFlow._(
        current: current ?? this.current,
        status: status ?? this.status,
        done: done ?? this.done,
        skipped: skipped ?? this.skipped,
      );

  // ---- saving and resuming ----

  static const int _version = 1;

  Map<String, Object?> toJson() => {
    'v': _version,
    'current': current.id,
    'status': status.name,
    'done': [for (final s in steps) if (done.contains(s)) s.id],
    'skipped': [for (final s in steps) if (skipped.contains(s)) s.id],
  };

  /// A short string to keep in the app's small-flag storage.
  String encode() => jsonEncode(toJson());

  /// Reads what [toJson] wrote. Anything unreadable gives a fresh start:
  /// better to ask the first-run questions again than to crash or get stuck.
  /// Unknown step ids (from a newer build) are ignored.
  factory FirstRunFlow.fromJson(Object? json) {
    if (json is! Map) return const FirstRunFlow.start();
    final current = FirstRunStep.byId(json['current']);
    final status = FirstRunStatus.values.asNameMap()[json['status']];
    if (current == null || status == null) return const FirstRunFlow.start();
    Set<FirstRunStep> read(Object? v) => {
      if (v is List)
        for (final id in v) ?FirstRunStep.byId(id),
    };
    return FirstRunFlow._(current: current, status: status, done: read(json['done']), skipped: read(json['skipped']));
  }

  /// Reads what [encode] wrote (null or garbage gives a fresh start).
  factory FirstRunFlow.decode(String? text) {
    if (text == null || text.isEmpty) return const FirstRunFlow.start();
    try {
      return FirstRunFlow.fromJson(jsonDecode(text));
    } on FormatException {
      return const FirstRunFlow.start();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FirstRunFlow &&
      other.current == current &&
      other.status == status &&
      setEquals(other.done, done) &&
      setEquals(other.skipped, skipped);

  @override
  int get hashCode => Object.hash(current, status, Object.hashAllUnordered(done), Object.hashAllUnordered(skipped));

  @override
  String toString() => 'FirstRunFlow(${current.id}, ${status.name}, done: ${done.map((s) => s.id)}, skipped: ${skipped.map((s) => s.id)})';
}
