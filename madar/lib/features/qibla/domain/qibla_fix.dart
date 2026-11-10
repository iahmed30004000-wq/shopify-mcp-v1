import 'package:flutter/foundation.dart';

import '../../prayer/domain/qibla.dart';
import 'compass_math.dart';

/// A place to find the qibla from: the prayer location, or any coordinates
/// (a travel destination).
@immutable
class QiblaPlace {
  const QiblaPlace({required this.latitude, required this.longitude, this.altitudeKm = 0, this.nameAr, this.nameEn});

  final double latitude;
  final double longitude;

  /// Height above the ellipsoid (only the magnetic model uses it).
  final double altitudeKm;
  final String? nameAr;
  final String? nameEn;

  /// The name in [languageCode], falling back to the other language.
  String? name(String languageCode) => languageCode == 'ar' ? (nameAr ?? nameEn) : (nameEn ?? nameAr);

  @override
  bool operator ==(Object other) =>
      other is QiblaPlace &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.altitudeKm == altitudeKm &&
      other.nameAr == nameAr &&
      other.nameEn == nameEn;

  @override
  int get hashCode => Object.hash(latitude, longitude, altitudeKm, nameAr, nameEn);

  @override
  String toString() => 'QiblaPlace($latitude, $longitude, ${nameEn ?? nameAr})';
}

/// The qibla from one place: the initial great-circle bearing to the Kaaba
/// (degrees clockwise from true north) and the great-circle distance.
@immutable
class QiblaFix {
  const QiblaFix._(this.place, this.bearing, this.distanceKm);

  /// The qibla from [place] (delegates to the prayer package's [QiblaMath]).
  factory QiblaFix.of(QiblaPlace place) => QiblaFix._(
    place,
    QiblaMath.bearing(place.latitude, place.longitude),
    QiblaMath.distanceKm(place.latitude, place.longitude),
  );

  /// The qibla from any coordinates.
  factory QiblaFix.at(double latitude, double longitude) =>
      QiblaFix.of(QiblaPlace(latitude: latitude, longitude: longitude));

  /// Within this distance the bearing is meaningless: face the Kaaba itself.
  static const double atKaabaKm = 0.2;

  final QiblaPlace place;

  /// Degrees clockwise from true north, [0, 360).
  final double bearing;

  /// Kilometres along the great circle.
  final double distanceKm;

  bool get atKaaba => distanceKm < atKaabaKm;

  /// The nearest of the eight compass points.
  CompassPoint get point => CompassPoint.of(bearing);

  /// Signed turn (degrees, positive = clockwise / to the right) from a
  /// [heading] (true, degrees) to the qibla.
  double turnFrom(double heading) => CircularMath.delta(heading, bearing);

  @override
  bool operator ==(Object other) => other is QiblaFix && other.place == place;

  @override
  int get hashCode => place.hashCode;
}
