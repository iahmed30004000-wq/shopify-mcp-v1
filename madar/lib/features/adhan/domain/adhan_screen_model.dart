import 'package:meta/meta.dart';

import 'adhan_settings.dart';
import 'adhan_slot.dart';
import 'adhan_sound.dart';

/// What the adhan screen shows.
enum AdhanPhase {
  /// The adhan is sounding.
  calling,

  /// The adhan has ended: the supplication after it.
  after,

  /// A pre-adhan reminder (with a countdown).
  reminder,

  /// The sunrise alert.
  sunrise,

  /// "I prayed" was just logged.
  prayed,
}

/// Pure decisions of the adhan screen (widget-free, unit-tested).
@immutable
class AdhanScreenModel {
  const AdhanScreenModel({required this.kind, required this.firedAt, required this.soundLength});

  final AdhanKind kind;
  final DateTime firedAt;

  /// How long the adhan sounds (zero for a silent one).
  final Duration soundLength;

  /// A typical adhan when the recording's length is unknown.
  static const unknownRecording = Duration(minutes: 4);

  /// How long [sound] plays.
  static Duration soundLengthOf(AdhanSoundRef? sound, AdhanSettings settings) {
    if (sound == null) return TanbihTone.chime.length;
    return switch (sound.kind) {
      AdhanSoundKind.tone => sound.tone!.length,
      AdhanSoundKind.silent => Duration.zero,
      AdhanSoundKind.file => settings.muezzinById(sound.fileId)?.length ?? unknownRecording,
    };
  }

  /// The phase when the screen opens at [now]: an adhan opened after it
  /// finished (or silenced from the notification) starts at the
  /// supplication.
  AdhanPhase initialPhase(DateTime now, {bool silenced = false}) {
    switch (kind) {
      case AdhanKind.preAdhan || AdhanKind.snooze:
        return AdhanPhase.reminder;
      case AdhanKind.sunrise:
        return AdhanPhase.sunrise;
      case AdhanKind.adhan || AdhanKind.test:
        if (silenced) return AdhanPhase.after;
        return soundingLeft(now) > Duration.zero ? AdhanPhase.calling : AdhanPhase.after;
    }
  }

  /// How much longer the adhan sounds at [now].
  Duration soundingLeft(DateTime now) {
    final end = firedAt.add(soundLength);
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether "I prayed" makes sense: never before the prayer's time.
  static bool canMarkPrayed(AdhanKind kind, AdhanSlot slot, DateTime prayerAt, DateTime now) {
    if (kind == AdhanKind.test) return false;
    if (slot == AdhanSlot.sunrise) return true; // logs Fajr
    return !now.isBefore(prayerAt);
  }

  /// The prayer "I prayed" logs (Fajr for the sunrise alert).
  static AdhanSlot prayedSlot(AdhanSlot slot) => slot == AdhanSlot.sunrise ? AdhanSlot.fajr : slot;
}
