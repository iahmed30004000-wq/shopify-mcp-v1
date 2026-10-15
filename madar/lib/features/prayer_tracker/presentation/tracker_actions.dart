import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../data/prayer_tracker_repository.dart';
import '../data/tracker_providers.dart';
import '../domain/tracker_prayers.dart';
import 'tracker_labels.dart';

/// Status colours of the tracker, all derived from the theme tokens: gold
/// for a prayer prayed on time, a warmer ember for late, the cool info hue
/// for a made-up prayer, danger for one still owed.
@immutable
class TrackerColors {
  const TrackerColors._(this.t);

  factory TrackerColors.of(BuildContext context) => TrackerColors._(context.tokens);

  factory TrackerColors.from(MadarTokens t) => TrackerColors._(t);

  final MadarTokens t;

  Color get onTime => t.gold;
  Color get late => Color.lerp(t.warning, t.danger, 0.45)!;
  Color get qada => t.info;
  Color get missed => t.danger;
  Color get due => t.accent;
  Color get jamaah => t.success;
  Color get mosque => t.highlight;
  Color get idle => t.textTertiary;

  Color status(PrayerStatus s) => switch (s) {
    PrayerStatus.prayed => onTime,
    PrayerStatus.late => late,
    PrayerStatus.qada => qada,
    PrayerStatus.missed => missed,
  };
}

/// Runs tracker writes from the UI with Madar's feedback: the sound and
/// haptic that fit the change, and an undo toast labelled with what
/// happened. Each method returns the [UndoableAction] (for
/// [ActionableItem], which shows the toast itself) – or shows the toast
/// directly with [toast].
class TrackerActions {
  /// Resolves everything it needs from [context] now: a row may be gone by
  /// the time its write finishes (a made-up prayer leaves the qada ledger),
  /// and its undo toast must still appear.
  TrackerActions(BuildContext context, this.ref)
    : _l = L10n.of(context),
      _fmt = MadarFormatter.of(context),
      _overlay = Overlay.maybeOf(context, rootOverlay: true);

  final WidgetRef ref;
  final L10n _l;
  final MadarFormatter _fmt;
  final OverlayState? _overlay;

  PrayerTrackerRepository get _repo => ref.read(prayerTrackerRepositoryProvider);

  String _name(Prayer p) => _l.trackerPrayerName(p);

  /// The sound of a new status (none when [feedback] is off – e.g. after a
  /// swipe, which already chimed).
  static void feedbackFor(PrayerStatus? status) => Fx.fire(switch (status) {
    PrayerStatus.prayed => Sfx.prayerLit,
    PrayerStatus.late => Sfx.toggleOn,
    PrayerStatus.qada => Sfx.complete,
    PrayerStatus.missed => Sfx.drop,
    null => Sfx.toggleOff,
  });

  UndoableAction? _statusUndo(Prayer prayer, TrackerChange c) {
    if (!c.changed) return null;
    final status = c.after?.status;
    final label = status == null
        ? _l.trackerUndoCleared(_name(prayer))
        : _l.trackerUndoStatus(_name(prayer), _l.trackerStatusName(status));
    return UndoableAction(label: label, undo: c.undo);
  }

  /// The tap on an obligatory prayer (see [StatusCycle]).
  Future<UndoableAction?> cycle(DateTime day, Prayer prayer) async {
    final c = await _repo.cycle(day, prayer);
    feedbackFor(c.after?.status);
    return _statusUndo(prayer, c);
  }

  Future<UndoableAction?> setStatus(DateTime day, Prayer prayer, PrayerStatus status, {bool feedback = true}) async {
    final c = await _repo.setStatus(day, prayer, status);
    if (feedback) feedbackFor(status);
    return _statusUndo(prayer, c);
  }

  Future<UndoableAction?> clear(DateTime day, Prayer prayer) async {
    final c = await _repo.clear(day, prayer);
    feedbackFor(null);
    return _statusUndo(prayer, c);
  }

  Future<UndoableAction?> setJamaah(DateTime day, Prayer prayer, bool value) async {
    final c = await _repo.setJamaah(day, prayer, value);
    Fx.fire(value ? Sfx.toggleOn : Sfx.toggleOff);
    if (!c.changed) return null;
    final name = _name(prayer);
    return UndoableAction(label: value ? _l.trackerUndoJamaahOn(name) : _l.trackerUndoJamaahOff(name), undo: c.undo);
  }

  Future<UndoableAction?> setMosque(DateTime day, Prayer prayer, bool value) async {
    final c = await _repo.setMosque(day, prayer, value);
    Fx.fire(value ? Sfx.toggleOn : Sfx.toggleOff);
    if (!c.changed) return null;
    final name = _name(prayer);
    return UndoableAction(label: value ? _l.trackerUndoMosqueOn(name) : _l.trackerUndoMosqueOff(name), undo: c.undo);
  }

  Future<UndoableAction?> toggleVoluntary(DateTime day, Prayer prayer) async {
    final c = await _repo.toggleVoluntary(day, prayer);
    final on = c.after != null;
    Fx.fire(on ? Sfx.toggleOn : Sfx.toggleOff);
    if (on) Fx.fire(Sfx.sparkle, volume: 0.6);
    if (!c.changed) return null;
    final name = _name(prayer);
    return UndoableAction(label: on ? _l.trackerUndoVoluntaryOn(name) : _l.trackerUndoVoluntaryOff(name), undo: c.undo);
  }

  Future<UndoableAction?> makeUp(DateTime day, Prayer prayer, {bool feedback = true}) async {
    final c = await _repo.makeUp(day, prayer);
    if (feedback) feedbackFor(PrayerStatus.qada);
    if (!c.changed) return null;
    final date = _fmt.formatDate(day, style: MadarDateStyle.dayMonth);
    return UndoableAction(label: _l.trackerUndoMadeUp(_name(prayer), date), undo: c.undo);
  }

  Future<UndoableAction?> makeUpAll(List<(DateTime, Prayer)> entries, {bool feedback = true}) async {
    if (entries.isEmpty) return null;
    final undo = await _repo.makeUpAll(entries);
    if (feedback) Fx.fire(Sfx.levelUp);
    final label = _fmt.localizeDigits(_l.trackerUndoMadeUpAll(entries.length));
    return UndoableAction(label: label, undo: undo);
  }

  /// A tap on a prayer whose time has not come: a soft "not yet".
  static void notYet() => Fx.fire(Sfx.error, volume: 0.5, haptic: Haptic.light);

  /// Shows the undo toast of [action] (the previous tracker toast gives way,
  /// so quick taps never pile up competing undos).
  void toast(UndoableAction? action) {
    final overlay = _overlay;
    if (action == null || overlay == null || !overlay.mounted) return;
    UndoToast.dismissAll(overlay);
    unawaited(UndoToast.show(overlay, action));
  }
}
