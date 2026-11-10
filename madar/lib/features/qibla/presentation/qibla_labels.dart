import 'dart:math' as math;

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../domain/compass_math.dart';
import '../domain/compass_quality.dart';
import '../domain/heading.dart';

/// Localised qibla labels.
extension QiblaLabels on L10n {
  /// ش / ش ق / ق … (Arabic) or N / NE / E … (English).
  String qiblaPointShort(CompassPoint p) => switch (p) {
    CompassPoint.north => qiblaPointN,
    CompassPoint.northEast => qiblaPointNE,
    CompassPoint.east => qiblaPointE,
    CompassPoint.southEast => qiblaPointSE,
    CompassPoint.south => qiblaPointS,
    CompassPoint.southWest => qiblaPointSW,
    CompassPoint.west => qiblaPointW,
    CompassPoint.northWest => qiblaPointNW,
  };

  /// Full names for screen readers.
  String qiblaPointName(CompassPoint p) => switch (p) {
    CompassPoint.north => qiblaPointNameN,
    CompassPoint.northEast => qiblaPointNameNE,
    CompassPoint.east => qiblaPointNameE,
    CompassPoint.southEast => qiblaPointNameSE,
    CompassPoint.south => qiblaPointNameS,
    CompassPoint.southWest => qiblaPointNameSW,
    CompassPoint.west => qiblaPointNameW,
    CompassPoint.northWest => qiblaPointNameNW,
  };

  /// The four cardinal letters in dial order (N, E, S, W).
  List<String> get qiblaCardinals => [qiblaPointN, qiblaPointE, qiblaPointS, qiblaPointW];

  String qiblaAccuracyName(CompassAccuracy a) => switch (a) {
    CompassAccuracy.high => qiblaAccuracyHigh,
    CompassAccuracy.medium => qiblaAccuracyMedium,
    CompassAccuracy.low => qiblaAccuracyLow,
    CompassAccuracy.unreliable => qiblaAccuracyUnreliable,
  };

  String qiblaUnavailable(HeadingUnavailableReason r) => switch (r) {
    HeadingUnavailableReason.noSensor => qiblaNoSensor,
    HeadingUnavailableReason.sensorError => qiblaSensorError,
    HeadingUnavailableReason.noReadings => qiblaNoReadings,
  };

  /// "١٦٠٫٧° ج" – a bearing with its compass point.
  String qiblaBearingText(double bearing, MadarFormatter fmt, {int decimals = 1}) =>
      '${QiblaFormat.degrees(bearing, fmt, decimals: decimals)} ${qiblaPointShort(CompassPoint.of(bearing))}';

  /// "١٬٢٣٤ كم".
  String qiblaDistanceText(double km, MadarFormatter fmt) =>
      qiblaKm(fmt.formatNumber(km >= 100 ? km.roundToDouble() : km, maxDecimals: km >= 100 ? 0 : 1));
}

/// Number formatting shared by the qibla widgets.
abstract final class QiblaFormat {
  /// "٤٥°" kept left-to-right so the degree sign stays after the number in
  /// Arabic text.
  static String degrees(double value, MadarFormatter fmt, {int decimals = 0}) {
    final factor = math.pow(10, decimals);
    var v = (value * factor).round() / factor;
    if (v >= 360) v -= 360;
    return BidiIsolate.ltr('${fmt.formatNumber(v, decimals: decimals, grouping: false)}°');
  }
}
