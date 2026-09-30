import 'package:flutter/foundation.dart';

import 'widget_snapshot.dart';

/// A built widget snapshot with the images its pages name.
@immutable
class WidgetBuild {
  const WidgetBuild(this.snapshot, {this.images = const {}});

  final WidgetSnapshot snapshot;

  /// Image key → what to draw (rendered light and dark by the bridge).
  final Map<String, MiniAstrolabeSpec> images;
}

/// What the prayer widget's mini astrolabe shows: the day's six moments on
/// the 24-hour dial (noon at the top, midnight at the bottom, clockwise –
/// the orbit's own dial) and the next prayer lit, with the arc of the
/// window that leads to it.
///
/// Values are dial fractions (0 = midnight, 0.5 = noon) of the location's
/// wall clock; the drawing holds no time of its own (the widget's countdown
/// ticks in Android), so one image serves a whole window.
@immutable
class MiniAstrolabeSpec {
  const MiniAstrolabeSpec({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.next,
  });

  final double fajr, sunrise, dhuhr, asr, maghrib, isha;

  /// Index of the next prayer in `[fajr, dhuhr, asr, maghrib, isha]`.
  final int next;

  List<double> get prayers => [fajr, dhuhr, asr, maghrib, isha];

  /// The lit window: from the prayer before [next] to [next].
  (double from, double to) get window {
    final p = prayers;
    final i = next.clamp(0, 4);
    return (p[(i + 4) % 5], p[i]);
  }

  /// Rounded to minutes so a snapshot rebuilt a few seconds later draws the
  /// same image (and the bridge re-renders nothing).
  String get signature {
    String m(double f) => (f * 1440).round().toString();
    return [m(fajr), m(sunrise), m(dhuhr), m(asr), m(maghrib), m(isha), next].join('.');
  }

  @override
  bool operator ==(Object other) => other is MiniAstrolabeSpec && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;

  @override
  String toString() => 'MiniAstrolabeSpec($signature)';
}

