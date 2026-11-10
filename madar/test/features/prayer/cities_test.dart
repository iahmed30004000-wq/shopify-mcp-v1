import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/prayer/domain/cities.dart';
import 'package:madar/features/prayer/domain/time_zones.dart';

void main() {
  late CityDatabase db;

  setUpAll(() {
    MadarTimeZones.ensure();
    db = CityDatabase.parse(File('assets/geo/cities.json').readAsStringSync());
  });

  String top(String q) => db.search(q).first.city.id;

  group('the offline list', () {
    test('holds at least 400 cities with valid data', () {
      expect(db.cities.length, greaterThanOrEqualTo(400));
      final ids = <String>{};
      final arabic = RegExp('[ء-ي]');
      for (final c in db.cities) {
        expect(ids.add(c.id), isTrue, reason: 'duplicate ${c.id}');
        expect(c.latitude, inInclusiveRange(-90, 90), reason: c.id);
        expect(c.longitude, inInclusiveRange(-180, 180), reason: c.id);
        expect(c.nameEn.trim(), isNotEmpty, reason: c.id);
        expect(arabic.hasMatch(c.nameAr), isTrue, reason: '${c.id} Arabic name "${c.nameAr}"');
        expect(MadarTimeZones.isValid(c.timeZone), isTrue, reason: '${c.id} zone ${c.timeZone}');
        expect(db.countries.containsKey(c.countryCode), isTrue, reason: '${c.id} country ${c.countryCode}');
      }
    });

    test('covers every Arab capital, the holy cities and major cities', () {
      const required = [
        'jo-amman',
        'ps-jerusalem',
        'sy-damascus',
        'lb-beirut',
        'iq-baghdad',
        'sa-riyadh',
        'kw-kuwait-city', //
        'bh-manama',
        'qa-doha',
        'ae-abu-dhabi',
        'om-muscat',
        'ye-sanaa',
        'eg-cairo',
        'sd-khartoum',
        'ly-tripoli',
        'tn-tunis',
        'dz-algiers',
        'ma-rabat',
        'mr-nouakchott',
        'so-mogadishu',
        'dj-djibouti',
        'km-moroni',
        'sa-makkah',
        'sa-madinah',
        'jo-zarqa',
        'jo-irbid',
        'jo-aqaba',
        'ae-dubai',
        'eg-alexandria',
        'iq-basra',
        'tr-istanbul',
        'gb-london',
        'fr-paris',
        'us-new-york',
        'my-kuala-lumpur',
        'id-jakarta',
        'pk-karachi',
      ];
      for (final id in required) {
        expect(db.byId(id), isNotNull, reason: id);
      }
      final arabCapitals = db.cities.where((c) => c.capital && CityText.arabWorld.contains(c.countryCode));
      expect(arabCapitals.length, greaterThanOrEqualTo(21));
    });

    test('Arabic names are the established forms', () {
      expect(db.byId('jo-amman')!.nameAr, 'عمّان');
      expect(db.byId('sa-makkah')!.nameAr, 'مكة المكرمة');
      expect(db.byId('sa-madinah')!.nameAr, 'المدينة المنورة');
      expect(db.byId('ps-jerusalem')!.nameAr, 'القدس');
      expect(db.byId('eg-mansoura')!.nameAr, 'المنصورة');
      expect(db.byId('lb-tripoli-lebanon')!.timeZone, 'Asia/Beirut');
      expect(db.byId('ma-casablanca')!.nameAr, 'الدار البيضاء');
      expect(db.countryName('JO', 'ar'), 'الأردن');
      expect(db.countryName('PS', 'en'), 'Palestine');
    });

    test('time zones follow each country', () {
      expect(db.byId('jo-amman')!.timeZone, 'Asia/Amman');
      expect(db.byId('sa-makkah')!.timeZone, 'Asia/Riyadh');
      expect(db.byId('ps-gaza')!.timeZone, 'Asia/Gaza');
      expect(db.byId('ps-hebron')!.timeZone, 'Asia/Hebron');
      expect(db.byId('us-houston')!.timeZone, 'America/Chicago');
      expect(db.byId('gb-cardiff')!.timeZone, 'Europe/London');
      expect(db.byId('cz-prague')!.timeZone, 'Europe/Prague');
    });
  });

  group('search', () {
    test('Arabic with and without diacritics, hamza and teh marbuta', () {
      expect(top('عمّان'), 'jo-amman');
      expect(top('عمان'), 'jo-amman');
      expect(top('عَمّان'), 'jo-amman');
      expect(top('مكة'), 'sa-makkah');
      expect(top('مكه المكرمه'), 'sa-makkah');
      expect(top('المدينة المنورة'), 'sa-madinah');
      expect(top('المدينه'), 'sa-madinah');
      expect(top('القُدس'), 'ps-jerusalem');
      expect(top('اربد'), 'jo-irbid');
      expect(top('إربد'), 'jo-irbid');
      expect(top('القاهره'), 'eg-cairo');
      expect(top('الاسكندرية'), 'eg-alexandria');
    });

    test('the Arabic article is optional', () {
      expect(top('الزرقاء'), 'jo-zarqa');
      expect(top('زرقاء'), 'jo-zarqa');
      expect(top('رياض'), 'sa-riyadh');
      expect(top('الرياض'), 'sa-riyadh');
    });

    test('prefixes while typing', () {
      expect(top('عم'), anyOf('jo-amman', 'om-muscat'));
      expect(db.search('عم').take(3).map((m) => m.city.id), contains('jo-amman'));
      expect(top('جد'), 'sa-jeddah');
      expect(top('Amm'), 'jo-amman');
      expect(top('Jedd'), 'sa-jeddah');
    });

    test('English, transliterations and aliases', () {
      expect(top('Amman'), 'jo-amman');
      expect(top('amman'), 'jo-amman');
      expect(top('Mecca'), 'sa-makkah');
      expect(top('Makkah'), 'sa-makkah');
      expect(top('Medina'), 'sa-madinah');
      expect(top('Az Zarqa'), 'jo-zarqa');
      expect(top('al-quds'), 'ps-jerusalem');
      expect(top('Sao Paulo'), 'br-sao-paulo');
      expect(top('Bombay'), 'in-mumbai');
      expect(top('Abu Dhabi'), 'ae-abu-dhabi');
      expect(top('abudhabi'), 'ae-abu-dhabi');
    });

    test('typos are forgiven', () {
      expect(top('dubay'), 'ae-dubai');
      expect(top('istambul'), 'tr-istanbul');
      expect(top('Kuala Lumpar'), 'my-kuala-lumpur');
      expect(top('kualalumpor'), 'my-kuala-lumpur');
      expect(top('damascos'), 'sy-damascus');
      expect(top('الرياظ'), 'sa-riyadh');
    });

    test('a country name lists its cities, biggest first', () {
      final jordan = db.search('الأردن').map((m) => m.city.countryCode).toSet();
      expect(jordan, {'JO'});
      expect(db.search('Jordan').first.city.id, 'jo-amman');
    });

    test('digits of every script fold to Western digits', () {
      expect(CityText.fold('٦ أكتوبر'), '6 اكتوبر');
      expect(CityText.fold('۱۲۳'), '123');
    });

    test('an empty query suggests the holy cities, then capitals', () {
      final s = db.search('   ').map((m) => m.city.id).toList();
      expect(s.take(3), ['sa-makkah', 'sa-madinah', 'ps-jerusalem']);
      expect(s, contains('jo-amman'));
      expect(db.search('zzzzqqq'), isEmpty);
    });

    test('the capital flag means the national capital (no region or disputed seats)', () {
      // Natural Earth also marks region capitals and the seats of disputed
      // administrations; they must not be suggested as a country's capital.
      const notCapitals = [
        'ma-laayoune',
        'so-hargeisa',
        'ge-sukhumi',
        'ge-batumi',
        'gb-cardiff',
        'gb-edinburgh',
        'gb-belfast', //
        'pt-funchal',
        'pt-ponta-delgada',
        'ph-baguio',
        'rs-novi-sad',
        'jp-kyoto',
        'ba-banja-luka',
        'za-johannesburg',
      ];
      for (final id in notCapitals) {
        expect(db.byId(id), isNotNull, reason: '$id stays in the list');
        expect(db.byId(id)!.capital, isFalse, reason: id);
      }
      for (final cc in ['MA', 'SO', 'GE', 'GB', 'PT', 'PH', 'RS', 'JP', 'BA']) {
        expect(db.cities.where((c) => c.countryCode == cc && c.capital).length, 1, reason: cc);
      }
      final featured = db.featured.map((c) => c.id).toList();
      expect(featured, isNot(contains('ma-laayoune')));
      expect(featured, isNot(contains('so-hargeisa')));
      // Every Arab League capital is suggested before any other capital.
      final arab = db.featured.skip(3).takeWhile((c) => CityText.arabWorld.contains(c.countryCode)).toList();
      expect(arab.map((c) => c.countryCode).toSet().length, arab.length, reason: 'one capital per Arab country');
      expect(arab.length, 21, reason: 'the 22 Arab League capitals, Jerusalem listed first among the holy cities');
    });
  });

  group('nearest city', () {
    test('names a GPS fix after the closest city', () {
      final n = db.nearest(31.99, 35.87)!;
      expect(n.city.id, 'jo-amman');
      expect(n.distanceKm, lessThan(10));
      final makkah = db.nearest(21.42, 39.83)!;
      expect(makkah.city.id, 'sa-makkah');
      final sea = db.nearest(33.5, 30.0)!; // eastern Mediterranean
      expect(sea.distanceKm, greaterThan(100));
    });
  });
}
