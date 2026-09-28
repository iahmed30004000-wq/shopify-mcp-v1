import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:hijri/hijri_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/domain/enums.dart';
import '../../prayer/domain/time_zones.dart';

/// Calculation presets. [id] is the stable storage value.
///
/// Every preset comes straight from adhan_dart's own
/// `CalculationMethodParameters` (angles, Isha intervals, Maghrib angles and
/// the method's minute offsets); [custom] uses the user's own angles. The one
/// refinement is [jordan]'s sunrise / Maghrib offsets, which follow the
/// Ministry of Awqaf's published timetable (see [jordanSunriseOffset]).
enum PrayerMethod {
  /// Ministry of Awqaf, Jordan (default): Fajr 18°, Isha 18°, Shafiʿi Asr;
  /// sunrise 7 min before and Maghrib 7 min after the astronomical sunrise /
  /// sunset, as in the Ministry's published Amman timetable.
  jordan,
  muslimWorldLeague,
  ummAlQura,
  egyptian,
  karachi,

  /// ISNA (North America).
  northAmerica,
  dubai,
  kuwait,
  qatar,
  turkiye,
  singapore,
  tehran,
  gulfRegion,
  moonsightingCommittee,
  algerian,
  morocco,
  tunisia,
  france,
  russia,
  indonesian,
  jafari,

  /// The user's own Fajr / Isha angles (or Isha a fixed time after Maghrib).
  custom;

  String get id => name;

  /// Minutes the Ministry of Awqaf's published Amman timetable differs from
  /// astronomical sunrise and sunset (fitted to the Ministry's 2026
  /// calendar within ±1 min; adhan_dart's own Jordan preset only adds
  /// Maghrib +5, which is 2 min early for Amman and 7 min late at sunrise).
  static const jordanSunriseOffset = -7;
  static const jordanMaghribOffset = 7;

  static PrayerMethod? fromId(Object? id) {
    for (final m in values) {
      if (m.name == id) return m;
    }
    return null;
  }

  /// Fresh adhan parameters of the preset ([custom] starts from 0°/0°).
  adhan.CalculationParameters parameters() => switch (this) {
    PrayerMethod.jordan =>
      adhan.CalculationMethodParameters.jordan()
        ..methodAdjustments = {adhan.Prayer.sunrise: jordanSunriseOffset, adhan.Prayer.maghrib: jordanMaghribOffset},
    PrayerMethod.muslimWorldLeague => adhan.CalculationMethodParameters.muslimWorldLeague(),
    PrayerMethod.ummAlQura => adhan.CalculationMethodParameters.ummAlQura(),
    PrayerMethod.egyptian => adhan.CalculationMethodParameters.egyptian(),
    PrayerMethod.karachi => adhan.CalculationMethodParameters.karachi(),
    PrayerMethod.northAmerica => adhan.CalculationMethodParameters.northAmerica(),
    PrayerMethod.dubai => adhan.CalculationMethodParameters.dubai(),
    PrayerMethod.kuwait => adhan.CalculationMethodParameters.kuwait(),
    PrayerMethod.qatar => adhan.CalculationMethodParameters.qatar(),
    PrayerMethod.turkiye => adhan.CalculationMethodParameters.turkiye(),
    PrayerMethod.singapore => adhan.CalculationMethodParameters.singapore(),
    PrayerMethod.tehran => adhan.CalculationMethodParameters.tehran(),
    PrayerMethod.gulfRegion => adhan.CalculationMethodParameters.gulfRegion(),
    PrayerMethod.moonsightingCommittee => adhan.CalculationMethodParameters.moonsightingCommittee(),
    PrayerMethod.algerian => adhan.CalculationMethodParameters.algerian(),
    PrayerMethod.morocco => adhan.CalculationMethodParameters.morocco(),
    PrayerMethod.tunisia => adhan.CalculationMethodParameters.tunisia(),
    PrayerMethod.france => adhan.CalculationMethodParameters.france(),
    PrayerMethod.russia => adhan.CalculationMethodParameters.russia(),
    PrayerMethod.indonesian => adhan.CalculationMethodParameters.indonesian(),
    PrayerMethod.jafari => adhan.CalculationMethodParameters.jafari(),
    PrayerMethod.custom => adhan.CalculationMethodParameters.other(),
  };
}

/// How Fajr and Isha are bounded where twilight never ends (high latitudes).
enum HighLatitudeMode {
  /// adhan's recommendation: one seventh of the night above 48°, the middle
  /// of the night below.
  auto,
  middleOfTheNight,
  seventhOfTheNight,
  twilightAngle;

  static HighLatitudeMode fromId(Object? id) {
    for (final m in values) {
      if (m.name == id) return m;
    }
    return HighLatitudeMode.auto;
  }

  adhan.HighLatitudeRule ruleFor(double latitude) => switch (this) {
    HighLatitudeMode.auto => adhan.HighLatitudeRule.recommended(adhan.Coordinates(latitude, 0)),
    HighLatitudeMode.middleOfTheNight => adhan.HighLatitudeRule.middleOfTheNight,
    HighLatitudeMode.seventhOfTheNight => adhan.HighLatitudeRule.seventhOfTheNight,
    HighLatitudeMode.twilightAngle => adhan.HighLatitudeRule.twilightAngle,
  };
}

/// Where the stored location came from.
enum PrayerLocationSource {
  /// The generic default (Amman) – nothing chosen yet.
  defaultCity,

  /// A GPS fix, named after the nearest city of the offline list.
  gps,

  /// A city picked from the offline list.
  city;

  static PrayerLocationSource fromId(Object? id) {
    for (final s in values) {
      if (s.name == id) return s;
    }
    return PrayerLocationSource.defaultCity;
  }
}

/// Keys of [PrayerSettings.adjustmentsMin] (minutes added to each time).
abstract final class PrayerAdjustmentKeys {
  static const fajr = 'fajr';
  static const sunrise = 'sunrise';
  static const dhuhr = 'dhuhr';
  static const asr = 'asr';
  static const maghrib = 'maghrib';
  static const isha = 'isha';
  static const all = [fajr, sunrise, dhuhr, asr, maghrib, isha];
}

const _unset = Object();

/// Calculation settings (stored encrypted in KeyValues `prayer.settings`).
///
/// Every field added after Phase 1 is optional in the JSON, so older stored
/// settings decode unchanged: a missing `method` maps from the Phase 1
/// `useJordanPreset` flag, a missing `timeZone` means the device's zone.
class PrayerSettings {
  const PrayerSettings({
    this.latitude = 31.9539,
    this.longitude = 35.9106,
    this.cityName,
    this.fajrAngle = 18,
    this.ishaAngle = 18,
    this.hanafiAsr = false,
    this.adjustmentsMin = const {},
    bool useJordanPreset = true,
    PrayerMethod? method,
    this.ishaIntervalMin,
    this.customBase,
    this.highLatitude = HighLatitudeMode.auto,
    this.hijriOffsetDays = 0,
    this.hijriAtMaghrib = false,
    this.clock24h = false,
    this.timeZone,
    this.cityId,
    this.cityNameAr,
    this.cityNameEn,
    this.countryCode,
    this.locationSource = PrayerLocationSource.defaultCity,
  }) : method = method ?? (useJordanPreset ? PrayerMethod.jordan : PrayerMethod.custom);

  /// Default location: Amman (the brief's default region, Jordan). Replaced by
  /// GPS or a manually chosen city.
  final double latitude;
  final double longitude;

  /// Free-text location name (Phase 1); [cityNameAr] / [cityNameEn] win.
  final String? cityName;

  /// The angles of [PrayerMethod.custom]; for a preset they mirror the
  /// preset's own angles (informational – the preset's parameters are used).
  final double fajrAngle;
  final double ishaAngle;
  final bool hanafiAsr;

  /// Per-prayer manual offsets in minutes (keys: [PrayerAdjustmentKeys]).
  final Map<String, int> adjustmentsMin;

  /// The calculation preset.
  final PrayerMethod method;

  /// [PrayerMethod.custom] only: Isha this many minutes after Maghrib
  /// instead of the Isha angle (null or 0 = use the angle).
  final int? ishaIntervalMin;

  /// [PrayerMethod.custom] only: the preset the custom angles were derived
  /// from. Its minute offsets (Jordan: sunrise −7 / Maghrib +7) and Maghrib
  /// angle (Tehran, Jafari) stay in force, so editing an angle never moves
  /// Maghrib or sunrise. Null = plain angles (older custom settings).
  final PrayerMethod? customBase;

  final HighLatitudeMode highLatitude;

  /// Days added to the Umm al-Qura Hijri date (−2…+2) to follow local
  /// moon sighting.
  final int hijriOffsetDays;

  /// Whether the Hijri day begins at Maghrib (the Islamic day) rather than at
  /// midnight.
  final bool hijriAtMaghrib;

  /// 24-hour clock for prayer times (12-hour with ص/م otherwise).
  final bool clock24h;

  /// IANA zone of the location (e.g. `Asia/Riyadh`); null = the device's.
  final String? timeZone;

  /// Offline city-list id of the chosen / nearest city.
  final String? cityId;
  final String? cityNameAr;
  final String? cityNameEn;

  /// ISO 3166 country code of the location.
  final String? countryCode;
  final PrayerLocationSource locationSource;

  /// Phase 1 flag, kept for compatibility: the Jordanian preset.
  bool get useJordanPreset => method == PrayerMethod.jordan;

  /// The location name in [languageCode] (falls back to the other language
  /// and then to [cityName]).
  String? placeName(String languageCode) =>
      (languageCode == 'ar' ? (cityNameAr ?? cityNameEn) : (cityNameEn ?? cityNameAr)) ?? cityName;

  PrayerSettings copyWith({
    double? latitude,
    double? longitude,
    Object? cityName = _unset,
    double? fajrAngle,
    double? ishaAngle,
    bool? hanafiAsr,
    Map<String, int>? adjustmentsMin,
    PrayerMethod? method,
    Object? ishaIntervalMin = _unset,
    Object? customBase = _unset,
    HighLatitudeMode? highLatitude,
    int? hijriOffsetDays,
    bool? hijriAtMaghrib,
    bool? clock24h,
    Object? timeZone = _unset,
    Object? cityId = _unset,
    Object? cityNameAr = _unset,
    Object? cityNameEn = _unset,
    Object? countryCode = _unset,
    PrayerLocationSource? locationSource,
  }) {
    T? pick<T>(Object? v, T? current) => identical(v, _unset) ? current : v as T?;
    return PrayerSettings(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      cityName: pick<String>(cityName, this.cityName),
      fajrAngle: fajrAngle ?? this.fajrAngle,
      ishaAngle: ishaAngle ?? this.ishaAngle,
      hanafiAsr: hanafiAsr ?? this.hanafiAsr,
      adjustmentsMin: adjustmentsMin ?? this.adjustmentsMin,
      method: method ?? this.method,
      ishaIntervalMin: pick<int>(ishaIntervalMin, this.ishaIntervalMin),
      customBase: pick<PrayerMethod>(customBase, this.customBase),
      highLatitude: highLatitude ?? this.highLatitude,
      hijriOffsetDays: hijriOffsetDays ?? this.hijriOffsetDays,
      hijriAtMaghrib: hijriAtMaghrib ?? this.hijriAtMaghrib,
      clock24h: clock24h ?? this.clock24h,
      timeZone: pick<String>(timeZone, this.timeZone),
      cityId: pick<String>(cityId, this.cityId),
      cityNameAr: pick<String>(cityNameAr, this.cityNameAr),
      cityNameEn: pick<String>(cityNameEn, this.cityNameEn),
      countryCode: pick<String>(countryCode, this.countryCode),
      locationSource: locationSource ?? this.locationSource,
    );
  }

  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'cityName': cityName,
    'fajrAngle': fajrAngle,
    'ishaAngle': ishaAngle,
    'hanafiAsr': hanafiAsr,
    'adjustmentsMin': adjustmentsMin,
    'useJordanPreset': useJordanPreset,
    'method': method.id,
    'ishaIntervalMin': ishaIntervalMin,
    'customBase': customBase?.id,
    'highLatitude': highLatitude.name,
    'hijriOffsetDays': hijriOffsetDays,
    'hijriAtMaghrib': hijriAtMaghrib,
    'clock24h': clock24h,
    'timeZone': timeZone,
    'cityId': cityId,
    'cityNameAr': cityNameAr,
    'cityNameEn': cityNameEn,
    'countryCode': countryCode,
    'locationSource': locationSource.name,
  };

  factory PrayerSettings.fromJson(Map<String, Object?> j) {
    const d = PrayerSettings();
    double n(Object? v, double fb) => v is num && v.isFinite ? v.toDouble() : fb;
    String? s(Object? v) => v is String && v.isNotEmpty ? v : null;
    final adj = <String, int>{};
    final raw = j['adjustmentsMin'];
    if (raw is Map) {
      for (final e in raw.entries) {
        if (e.value is num) adj['${e.key}'] = (e.value as num).round();
      }
    }
    final fajrAngle = n(j['fajrAngle'], d.fajrAngle);
    final ishaAngle = n(j['ishaAngle'], d.ishaAngle);
    var method = PrayerMethod.fromId(j['method']);
    if (method == null) {
      // Phase 1 JSON: the Jordan preset overrode its angles with the stored
      // ones – custom angles on the Jordanian base keep those exact times.
      final jordan = j['useJordanPreset'] as bool? ?? true;
      if (!jordan) {
        method = PrayerMethod.custom;
      } else if (fajrAngle == 18 && ishaAngle == 18) {
        method = PrayerMethod.jordan;
      } else {
        method = PrayerMethod.custom;
        adj[PrayerAdjustmentKeys.maghrib] = (adj[PrayerAdjustmentKeys.maghrib] ?? 0) + 5;
      }
    }
    final lat = n(j['latitude'], d.latitude);
    final lon = n(j['longitude'], d.longitude);
    final interval = j['ishaIntervalMin'];
    final offset = j['hijriOffsetDays'];
    return PrayerSettings(
      latitude: lat.clamp(-90.0, 90.0),
      longitude: lon.clamp(-180.0, 180.0),
      cityName: j['cityName'] as String?,
      fajrAngle: fajrAngle,
      ishaAngle: ishaAngle,
      hanafiAsr: j['hanafiAsr'] as bool? ?? d.hanafiAsr,
      adjustmentsMin: adj,
      method: method,
      ishaIntervalMin: interval is num && interval > 0 ? interval.round() : null,
      customBase: switch (PrayerMethod.fromId(j['customBase'])) {
        PrayerMethod.custom || null => null,
        final m => m,
      },
      highLatitude: HighLatitudeMode.fromId(j['highLatitude']),
      hijriOffsetDays: offset is num ? offset.round().clamp(-2, 2) : 0,
      hijriAtMaghrib: j['hijriAtMaghrib'] as bool? ?? false,
      clock24h: j['clock24h'] as bool? ?? false,
      timeZone: s(j['timeZone']),
      cityId: s(j['cityId']),
      cityNameAr: s(j['cityNameAr']),
      cityNameEn: s(j['cityNameEn']),
      countryCode: s(j['countryCode']),
      locationSource: PrayerLocationSource.fromId(j['locationSource']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PrayerSettings) return false;
    if (other.adjustmentsMin.length != adjustmentsMin.length) return false;
    for (final e in adjustmentsMin.entries) {
      if (other.adjustmentsMin[e.key] != e.value) return false;
    }
    return other.latitude == latitude &&
        other.longitude == longitude &&
        other.cityName == cityName &&
        other.fajrAngle == fajrAngle &&
        other.ishaAngle == ishaAngle &&
        other.hanafiAsr == hanafiAsr &&
        other.method == method &&
        other.ishaIntervalMin == ishaIntervalMin &&
        other.customBase == customBase &&
        other.highLatitude == highLatitude &&
        other.hijriOffsetDays == hijriOffsetDays &&
        other.hijriAtMaghrib == hijriAtMaghrib &&
        other.clock24h == clock24h &&
        other.timeZone == timeZone &&
        other.cityId == cityId &&
        other.cityNameAr == cityNameAr &&
        other.cityNameEn == cityNameEn &&
        other.countryCode == countryCode &&
        other.locationSource == locationSource;
  }

  @override
  int get hashCode => Object.hash(
    Object.hash(latitude, longitude, cityName, fajrAngle, ishaAngle, hanafiAsr, method, ishaIntervalMin),
    Object.hashAllUnordered(adjustmentsMin.entries.map((e) => Object.hash(e.key, e.value))),
    Object.hash(highLatitude, hijriOffsetDays, hijriAtMaghrib, clock24h, timeZone, cityId),
    Object.hash(cityNameAr, cityNameEn, countryCode, locationSource, customBase),
  );
}

/// The six moments of a day (five prayers + sunrise), as instants.
///
/// The values are device-local `DateTime`s (what the orbit and home compare
/// with `DateTime.now()`); read the location's wall clock through
/// [PrayerSchedule.wallClock].
class DayTimes {
  const DayTimes({
    required this.day,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  /// The location's calendar day (midnight, as a device-local `DateTime`).
  final DateTime day;
  final DateTime fajr, sunrise, dhuhr, asr, maghrib, isha;

  List<(Prayer, DateTime)> get obligatory => [
    (Prayer.fajr, fajr),
    (Prayer.dhuhr, dhuhr),
    (Prayer.asr, asr),
    (Prayer.maghrib, maghrib),
    (Prayer.isha, isha),
  ];
}

/// Where "now" sits in the prayer-anchored day.
class WindowState {
  const WindowState({
    required this.window,
    required this.start,
    required this.end,
    required this.nextPrayer,
    required this.nextPrayerAt,
  });

  final PrayerWindow window;
  final DateTime start;
  final DateTime end;

  /// The next obligatory prayer (sunrise is not a prayer).
  final Prayer nextPrayer;
  final DateTime nextPrayerAt;

  double progressAt(DateTime now) {
    final total = end.difference(start).inMilliseconds;
    if (total <= 0) return 0;
    return (now.difference(start).inMilliseconds / total).clamp(0.0, 1.0);
  }
}

/// Offline prayer times (adhan_dart; Jordanian defaults) and the six windows
/// of the day: after Fajr (Fajr→sunrise), Duha (sunrise→Dhuhr), Dhuhr→Asr,
/// Asr→Maghrib, Maghrib→Isha, after Isha (Isha→next Fajr).
///
/// Days are the location's calendar days: with [PrayerSettings.timeZone] set,
/// [timesFor] reads its date as a date in that zone and [windowAt] /
/// [prayerDayOf] place "now" on the location's calendar. Without a zone the
/// device's zone is used (the Phase 1 behaviour).
class PrayerSchedule {
  PrayerSchedule(this.settings) : zone = MadarTimeZones.find(settings.timeZone);

  final PrayerSettings settings;

  /// The location's zone (null = the device's zone).
  final tz.Location? zone;

  final Map<DateTime, DayTimes> _cache = {};

  /// The location's wall-clock time of [instant] (a `TZDateTime` when the
  /// location has a zone of its own).
  DateTime wallClock(DateTime instant) => MadarTimeZones.wallClock(instant, zone);

  /// The location's calendar date (midnight) of [instant].
  DateTime dateOf(DateTime instant) => MadarTimeZones.dateIn(instant, zone);

  /// Whether the location's zone differs from the device's at [instant].
  bool differsFromDevice(DateTime instant) =>
      zone != null && MadarTimeZones.offsetAt(instant, zone) != instant.toLocal().timeZoneOffset;

  /// The effective adhan parameters for the location's day [y]-[m]-[d].
  adhan.CalculationParameters parametersFor(int y, int m, int d) {
    final p = settings.method.parameters();
    if (settings.method == PrayerMethod.custom) {
      final base = settings.customBase?.parameters();
      if (base != null) {
        p.methodAdjustments = Map.of(base.methodAdjustments);
        p.maghribAngle = base.maghribAngle;
        p.rounding = base.rounding;
      }
      p.fajrAngle = settings.fajrAngle;
      p.ishaAngle = settings.ishaAngle;
      final interval = settings.ishaIntervalMin ?? 0;
      if (interval > 0) p.ishaInterval = interval;
    } else if (settings.method == PrayerMethod.ummAlQura && _isRamadan(y, m, d)) {
      // Umm al-Qura: Isha is 120 minutes after Maghrib during Ramadan.
      p.ishaInterval = 120;
    }
    p.madhab = settings.hanafiAsr ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
    p.highLatitudeRule = settings.highLatitude.ruleFor(settings.latitude);
    // Inside the polar circles (no sunrise / sunset) borrow the nearest day
    // with a real sunrise instead of producing invalid times.
    p.polarCircleResolution = adhan.PolarCircleResolution.aqrabYaum;
    for (final e in settings.adjustmentsMin.entries) {
      final prayer = adhan.Prayer.values.where((pr) => pr.name == e.key).firstOrNull;
      if (prayer != null) p.adjustments[prayer] = e.value;
    }
    return p;
  }

  static bool _isRamadan(int y, int m, int d) {
    try {
      return HijriCalendar.fromDate(DateTime(y, m, d)).hMonth == 9;
    } catch (_) {
      return false;
    }
  }

  /// Times are rounded to the minute the way the method's published
  /// timetables are (nearest minute; Singapore rounds up), so an adhan fires
  /// at the minute the user reads.
  adhan.PrayerTimes _adhanTimes(int y, int m, int d) => adhan.PrayerTimes(
    date: DateTime(y, m, d, 12),
    coordinates: adhan.Coordinates(settings.latitude, settings.longitude),
    calculationParameters: parametersFor(y, m, d),
  );

  /// Times for the location's calendar day whose date is [date]'s
  /// year / month / day.
  DayTimes timesFor(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return _cache.putIfAbsent(key, () {
      var pt = _adhanTimes(key.year, key.month, key.day);
      if (zone != null) {
        // adhan computes the solar day around the longitude's noon; where a
        // zone runs far from solar time that can be the neighbouring civil
        // day – shift until Dhuhr falls on the requested date.
        final dhuhrDate = dateOf(pt.dhuhr);
        final diff = DateTime.utc(
          key.year,
          key.month,
          key.day,
        ).difference(DateTime.utc(dhuhrDate.year, dhuhrDate.month, dhuhrDate.day)).inDays;
        if (diff != 0) {
          final shifted = DateTime(key.year, key.month, key.day + diff);
          pt = _adhanTimes(shifted.year, shifted.month, shifted.day);
        }
      }
      return DayTimes(
        day: key,
        fajr: pt.fajr.toLocal(),
        sunrise: pt.sunrise.toLocal(),
        dhuhr: pt.dhuhr.toLocal(),
        asr: pt.asr.toLocal(),
        maghrib: pt.maghrib.toLocal(),
        isha: pt.isha.toLocal(),
      );
    });
  }

  /// The current window and the next obligatory prayer.
  ///
  /// The window is the one whose start (Fajr, sunrise, Dhuhr, Asr, Maghrib
  /// or Isha of yesterday, today or tomorrow) is the latest at or before
  /// [now], so it stays right where a high-latitude summer pushes yesterday's
  /// Maghrib or Isha past midnight (Reykjavik, Nuuk: sunset after 00:00).
  WindowState windowAt(DateTime now) {
    final date = dateOf(now);
    final events = <({PrayerWindow window, Prayer? prayer, DateTime at})>[
      for (final offset in const [-1, 0, 1])
        ...() {
          final t = timesFor(DateTime(date.year, date.month, date.day + offset));
          return [
            (window: PrayerWindow.fajr, prayer: Prayer.fajr, at: t.fajr),
            (window: PrayerWindow.duha, prayer: null, at: t.sunrise),
            (window: PrayerWindow.dhuhr, prayer: Prayer.dhuhr, at: t.dhuhr),
            (window: PrayerWindow.asr, prayer: Prayer.asr, at: t.asr),
            (window: PrayerWindow.maghrib, prayer: Prayer.maghrib, at: t.maghrib),
            (window: PrayerWindow.isha, prayer: Prayer.isha, at: t.isha),
          ];
        }(),
    ];
    // Each day is already in order; a stable sort only matters where two
    // days' moments interleave.
    _sortByTime(events);
    var current = 0;
    for (var i = 0; i < events.length; i++) {
      if (!events[i].at.isAfter(now)) current = i;
    }
    final start = events[current];
    final end = current + 1 < events.length ? events[current + 1].at : start.at.add(const Duration(hours: 6));
    ({PrayerWindow window, Prayer? prayer, DateTime at})? next;
    for (var i = current + 1; i < events.length; i++) {
      if (events[i].prayer != null && events[i].at.isAfter(now)) {
        next = events[i];
        break;
      }
    }
    return WindowState(
      window: start.window,
      start: start.at,
      end: end,
      nextPrayer: next?.prayer ?? Prayer.fajr,
      nextPrayerAt: next?.at ?? end,
    );
  }

  /// Stable insertion sort by time (the lists hold 18 nearly sorted items).
  static void _sortByTime(List<({PrayerWindow window, Prayer? prayer, DateTime at})> events) {
    for (var i = 1; i < events.length; i++) {
      final e = events[i];
      var j = i - 1;
      while (j >= 0 && events[j].at.isAfter(e.at)) {
        events[j + 1] = events[j];
        j--;
      }
      events[j + 1] = e;
    }
  }

  /// The prayer-anchored day of [now]: the hours before Fajr still belong to
  /// yesterday ("after Isha"). Returns local midnight of that (location)
  /// day.
  DateTime prayerDayOf(DateTime now) {
    final day = dateOf(now);
    return now.isBefore(timesFor(day).fajr) ? DateTime(day.year, day.month, day.day - 1) : day;
  }

  /// Obligatory prayers whose time started within the last [days] days up to
  /// [now] (feeds the Faith planet score).
  int obligatoryStartedInLast(DateTime now, {int days = 7}) {
    var count = 0;
    final from = now.subtract(Duration(days: days));
    final today = dateOf(now);
    for (var i = 0; i <= days; i++) {
      final t = timesFor(DateTime(today.year, today.month, today.day - i));
      for (final (_, at) in t.obligatory) {
        if (!at.isAfter(now) && at.isAfter(from)) count++;
      }
    }
    return count;
  }

  /// Fraction of the 24-hour dial (0 = local midnight, 0.5 = noon).
  static double dialFraction(DateTime t) => (t.hour * 3600 + t.minute * 60 + t.second + t.millisecond / 1000) / 86400.0;
}
