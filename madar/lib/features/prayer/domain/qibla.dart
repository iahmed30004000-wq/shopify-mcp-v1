import 'dart:math' as math;

import 'package:adhan_dart/adhan_dart.dart' as adhan;

/// The Qibla (direction of the Kaaba) from a location – pure helpers for
/// the compass of a later phase.
abstract final class QiblaMath {
  /// The Kaaba (adhan_dart's reference point).
  static const double kaabaLatitude = 21.4225241;
  static const double kaabaLongitude = 39.8261818;

  /// Initial great-circle bearing from ([latitude], [longitude]) to the
  /// Kaaba, in degrees clockwise from true north, in [0, 360).
  static double bearing(double latitude, double longitude) {
    final b = adhan.Qibla.qibla(adhan.Coordinates(latitude.clamp(-90.0, 90.0), longitude.clamp(-180.0, 180.0)));
    final wrapped = b % 360;
    return wrapped < 0 ? wrapped + 360 : wrapped;
  }

  /// Great-circle distance to the Kaaba in kilometres.
  static double distanceKm(double latitude, double longitude) =>
      greatCircleKm(latitude, longitude, kaabaLatitude, kaabaLongitude);

  /// Haversine distance between two points in kilometres.
  static double greatCircleKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0088;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final h =
        math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }

  /// The 16-point compass sector of [bearing] (0 = N, 4 = E, 8 = S, 12 = W).
  static int compassSector(double bearing) => (((bearing % 360) + 11.25) ~/ 22.5) % 16;
}
