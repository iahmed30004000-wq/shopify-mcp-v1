#!/usr/bin/env python3
"""Builds assets/geo/cities.json – Madar's offline city list.

Not part of the app or the test run: a reproducible, documented generator.

Sources (all openly licensed, credited in assets/licenses/geo_cities.txt):
  * Natural Earth 10m populated places v5 (public domain)
    https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_populated_places.geojson
  * GeoNames cities (population > 1000) via lutangar/cities.json (CC BY 4.0)
    https://raw.githubusercontent.com/lutangar/cities.json/master/cities.json
  * IANA tz database zone.tab (public domain)
    https://raw.githubusercontent.com/eggert/tz/main/zone.tab
  * Unicode CLDR territory names ar/en (Unicode License v3)
    https://raw.githubusercontent.com/unicode-org/cldr/main/common/main/{ar,en}.xml

Arab-world cities are an explicit, hand-curated list (Arabic names written
and checked by hand; coordinates from Natural Earth or GeoNames). The rest of
the world is selected from Natural Earth by rule, with hand corrections of
names and time zones (Natural Earth's TIMEZONE column has errors, so a zone is
only accepted when zone.tab lists it for the city's country; otherwise the
country's only zone, a manual override or the nearest zone.tab reference
point is used).

Usage (from the madar/ package root, with the four source files in DIR):
  python3 test/features/prayer/geo_tool/build_cities.py DIR assets/geo/cities.json
"""
import json
import math
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET

SRC = sys.argv[1]
OUT = sys.argv[2]

ne = [f['properties'] for f in json.load(open(f'{SRC}/ne_places.geojson'))['features']]
gn = json.load(open(f'{SRC}/gn_cities.json'))


def fold(s):
    s = ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')
    return re.sub('[^a-z0-9 ]', '', s.lower()).strip()


# ----------------------------------------------------------------- zones --
zones = {}  # cc -> [(zone, lat, lon)]
for line in open(f'{SRC}/zone.tab', encoding='utf-8'):
    if line.startswith('#') or not line.strip():
        continue
    parts = line.rstrip('\n').split('\t')
    cc, coord, zone = parts[0], parts[1], parts[2]
    m = re.match(r'([+-]\d+)([+-]\d+)', coord)

    def dms(v, deg_len):
        sign = -1 if v[0] == '-' else 1
        v = v[1:]
        d = int(v[:deg_len])
        rest = v[deg_len:]
        mnt = int(rest[:2]) if len(rest) >= 2 else 0
        sec = int(rest[2:4]) if len(rest) >= 4 else 0
        return sign * (d + mnt / 60 + sec / 3600)

    lat = dms(m.group(1), 2)
    lon = dms(m.group(2), 3)
    zones.setdefault(cc, []).append((zone, lat, lon))


# Kosovo has no zone.tab row of its own (it follows Belgrade's zone).
zones.setdefault('XK', [('Europe/Belgrade', 44.8333, 20.5)])


def dist_km(a_lat, a_lon, b_lat, b_lon):
    r = math.radians
    dlat = r(b_lat - a_lat)
    dlon = r(b_lon - a_lon)
    h = math.sin(dlat / 2) ** 2 + math.cos(r(a_lat)) * math.cos(r(b_lat)) * math.sin(dlon / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(h))


def zone_for(cc, lat, lon, ne_zone=None, override=None):
    if override:
        return override
    if cc == 'CN':
        return 'Asia/Shanghai'  # official time nationwide
    cands = zones.get(cc)
    if not cands:
        raise SystemExit(f'no zone for {cc}')
    if len(cands) == 1:
        return cands[0][0]
    if ne_zone and any(z == ne_zone for z, _, _ in cands):
        return ne_zone
    return min(cands, key=lambda z: dist_km(lat, lon, z[1], z[2]))[0]


# ------------------------------------------------------------- countries --
def territories(path):
    root = ET.parse(path).getroot()
    out, short = {}, {}
    for t in root.iter('territory'):
        alt = t.get('alt')
        if alt is None:
            out[t.get('type')] = t.text
        elif alt == 'short':
            short[t.get('type')] = t.text
    out.update(short)
    return out


cldr_ar = territories(f'{SRC}/cldr_ar.xml')
cldr_en = territories(f'{SRC}/cldr_en.xml')
# Plain everyday names where CLDR's short/long form reads oddly in a city row.
cldr_ar['PS'] = 'فلسطين'
cldr_en['PS'] = 'Palestine'
cldr_en['TR'] = 'Türkiye'
cldr_ar['HK'] = 'هونغ كونغ'
cldr_ar['MO'] = 'ماكاو'
cldr_en['HK'] = 'Hong Kong'
cldr_en['MO'] = 'Macao'

# ------------------------------------------------------------ lookups --
ne_by = {}
for q in ne:
    cc = q['ISO_A2'] if q['ISO_A2'] != '-99' else {'Somaliland': 'SO', 'Kosovo': 'XK', 'Northern Cyprus': 'CY'}.get(q['ADM0NAME'], '??')
    q['_cc'] = cc
    for n in {q['NAME'], q['NAMEASCII']}:
        ne_by.setdefault((cc, fold(n)), []).append(q)


def ne_lookup(cc, name):
    hits = ne_by.get((cc, fold(name)))
    if not hits:
        return None
    return max(hits, key=lambda q: q['POP_MAX'])


gn_by = {}
for c in gn:
    gn_by.setdefault((c['country'], fold(c['name'])), []).append(c)


def gn_lookup(cc, name):
    hits = gn_by.get((cc, fold(name)))
    return hits[0] if hits else None


# ------------------------------------------------ curated Arab world --
# (cc, English, Arabic, lookup, aliases)
# lookup: 'ne:<Natural Earth NAME>' | 'gn:<GeoNames name>' ; aliases are
# extra search words (other spellings / transliterations).
ARAB = [
    # Jordan
    ('JO', 'Amman', 'عمّان', 'ne:Amman', 'Ammaan|عمان'),
    ('JO', 'Zarqa', 'الزرقاء', 'ne:Az Zarqa', 'Az Zarqa|Zarka'),
    ('JO', 'Irbid', 'إربد', 'ne:Irbid', 'Irbed'),
    ('JO', 'Russeifa', 'الرصيفة', 'gn:Ar Ruşayfah', 'Rusayfa|Ruseifa'),
    ('JO', 'Salt', 'السلط', 'ne:As Salt', 'As Salt|Al Salt'),
    ('JO', 'Aqaba', 'العقبة', 'ne:Al Aqabah', 'Al Aqabah|Akaba'),
    ('JO', 'Mafraq', 'المفرق', 'ne:Al Mafraq', 'Al Mafraq'),
    ('JO', 'Jerash', 'جرش', 'gn:Jarash', 'Jarash|Gerasa'),
    ('JO', 'Madaba', 'مادبا', 'gn:Mādabā', 'Madaba'),
    ('JO', 'Karak', 'الكرك', 'ne:Al Karak', 'Al Karak|Kerak'),
    ('JO', 'Ajloun', 'عجلون', 'gn:‘Ajlūn', 'Ajlun|Ajlon'),
    ('JO', "Ma'an", 'معان', 'ne:Ma\'an', 'Maan'),
    ('JO', 'Tafilah', 'الطفيلة', 'ne:At Tafilah', 'Tafila|At Tafilah'),
    ('JO', 'Ramtha', 'الرمثا', 'gn:Ar Ramthā', 'Ar Ramtha'),
    ('JO', 'Sahab', 'سحاب', 'gn:Saḩāb', ''),
    ('JO', 'Fuheis', 'الفحيص', 'gn:Al Fuḩayş', 'Fuhays'),
    ('JO', 'Wadi Musa (Petra)', 'وادي موسى (البتراء)', 'gn:Wādī Mūsá', 'Petra|Wadi Musa|البتراء'),
    # Palestine
    ('PS', 'Jerusalem', 'القدس', 'ne:Jerusalem', 'Al Quds|Quds|بيت المقدس|القدس الشريف'),
    ('PS', 'Gaza', 'غزة', 'ne:Gaza City', 'Gaza City|Ghazzah'),
    ('PS', 'Hebron', 'الخليل', 'ne:Al Khalil', 'Al Khalil|Khalil'),
    ('PS', 'Nablus', 'نابلس', 'ne:Nablus', ''),
    ('PS', 'Ramallah', 'رام الله', 'ne:Ramallah', ''),
    ('PS', 'Bethlehem', 'بيت لحم', 'gn:Bethlehem', 'Bayt Lahm'),
    ('PS', 'Jenin', 'جنين', 'gn:Janīn', 'Janin'),
    ('PS', 'Tulkarm', 'طولكرم', 'gn:Ţūlkarm', 'Tulkarem'),
    ('PS', 'Qalqilya', 'قلقيلية', 'gn:Qalqīlyah', 'Qalqilyah'),
    ('PS', 'Jericho', 'أريحا', 'gn:Jericho', 'Ariha'),
    ('PS', 'Khan Yunis', 'خان يونس', 'gn:Khān Yūnis', 'Khan Younis'),
    ('PS', 'Rafah', 'رفح', 'gn:Rafaḩ', ''),
    ('PS', 'Deir al-Balah', 'دير البلح', 'gn:Dayr al Balaḩ', 'Dayr al Balah'),
    # Syria
    ('SY', 'Damascus', 'دمشق', 'ne:Damascus', 'Dimashq|Sham|الشام'),
    ('SY', 'Aleppo', 'حلب', 'ne:Aleppo', 'Halab'),
    ('SY', 'Homs', 'حمص', 'ne:Homs', 'Hims'),
    ('SY', 'Hama', 'حماة', 'ne:Hamah', 'Hamah'),
    ('SY', 'Latakia', 'اللاذقية', 'ne:Latakia', 'Lattakia|Al Ladhiqiyah'),
    ('SY', 'Tartus', 'طرطوس', 'ne:Tartus', 'Tartous'),
    ('SY', 'Deir ez-Zor', 'دير الزور', 'ne:Dayr az Zawr', 'Dayr az Zawr|Deir Ezzor'),
    ('SY', 'Raqqa', 'الرقة', 'ne:Ar Raqqah', 'Ar Raqqah'),
    ('SY', 'Idlib', 'إدلب', 'ne:Idlib', ''),
    ('SY', 'Daraa', 'درعا', "ne:Dar'a", "Dar'a|Deraa"),
    ('SY', 'Al-Hasakah', 'الحسكة', 'ne:Al Hasakah', 'Hasakah|Hassakeh'),
    ('SY', 'Qamishli', 'القامشلي', 'ne:Al Qamishli', 'Al Qamishli'),
    ('SY', 'As-Suwayda', 'السويداء', 'ne:As Suwayda', 'Suwayda|Sweida'),
    ('SY', 'Douma', 'دوما', 'ne:Douma', 'Duma'),
    ('SY', 'Palmyra', 'تدمر', 'ne:Tadmur', 'Tadmur'),
    ('SY', 'Manbij', 'منبج', 'ne:Manbij', ''),
    ('SY', 'Al-Bukamal', 'البوكمال', 'ne:Abu Kamal', 'Abu Kamal|Albu Kamal'),
    ('SY', 'Jableh', 'جبلة', 'gn:Jablah', 'Jablah'),
    # Lebanon
    ('LB', 'Beirut', 'بيروت', 'ne:Beirut', 'Bayrut'),
    ('LB', 'Tripoli (Lebanon)', 'طرابلس', 'ne:Ṭarābulus', 'Tripoli|Trablous|طرابلس الشام'),
    ('LB', 'Sidon', 'صيدا', 'ne:Saida', 'Saida'),
    ('LB', 'Tyre', 'صور', 'gn:Tyre', 'Sour|Sur'),
    ('LB', 'Zahle', 'زحلة', 'ne:Zahlé', 'Zahleh'),
    ('LB', 'Nabatieh', 'النبطية', 'ne:Nabatiye et Tahta', 'Nabatiyeh'),
    ('LB', 'Baalbek', 'بعلبك', 'gn:Baalbek', ''),
    ('LB', 'Jounieh', 'جونيه', 'gn:Jounieh', ''),
    ('LB', 'Byblos', 'جبيل', 'gn:Byblos', 'Jbeil|Jbail'),
    # Iraq
    ('IQ', 'Baghdad', 'بغداد', 'ne:Baghdad', ''),
    ('IQ', 'Basra', 'البصرة', 'ne:Basra', 'Basrah'),
    ('IQ', 'Mosul', 'الموصل', 'ne:Mosul', 'Mawsil'),
    ('IQ', 'Erbil', 'أربيل', 'ne:Irbil', 'Irbil|Arbil|Hawler|هولير'),
    ('IQ', 'Sulaymaniyah', 'السليمانية', 'ne:As Sulaymaniyah', 'Sulaimaniya|Slemani'),
    ('IQ', 'Kirkuk', 'كركوك', 'ne:Kirkuk', ''),
    ('IQ', 'Najaf', 'النجف', 'ne:Najaf', 'An Najaf'),
    ('IQ', 'Karbala', 'كربلاء', 'ne:Karbala', 'Kerbala'),
    ('IQ', 'Hillah', 'الحلة', 'ne:Al Hillah', 'Al Hillah|Hilla'),
    ('IQ', 'Nasiriyah', 'الناصرية', 'ne:An Nasiriyah', 'An Nasiriyah'),
    ('IQ', 'Diwaniyah', 'الديوانية', 'ne:Ad Diwaniyah', 'Ad Diwaniyah'),
    ('IQ', 'Amarah', 'العمارة', 'ne:Al Amarah', 'Al Amarah|Amara'),
    ('IQ', 'Kut', 'الكوت', 'ne:Al Kut', 'Al Kut'),
    ('IQ', 'Baqubah', 'بعقوبة', 'ne:Baqubah', 'Baquba'),
    ('IQ', 'Ramadi', 'الرمادي', 'ne:Ar Ramadi', 'Ar Ramadi'),
    ('IQ', 'Fallujah', 'الفلوجة', 'ne:Al Fallujah', 'Falluja'),
    ('IQ', 'Samawah', 'السماوة', 'ne:As Samawah', 'As Samawah'),
    ('IQ', 'Samarra', 'سامراء', 'ne:Samarra', ''),
    ('IQ', 'Duhok', 'دهوك', 'ne:Duhok', 'Dohuk|Dahuk'),
    ('IQ', 'Zakho', 'زاخو', 'ne:Zakho', ''),
    ('IQ', 'Tikrit', 'تكريت', 'gn:Tikrīt', ''),
    ('IQ', 'Zubayr', 'الزبير', 'ne:Az Aubayr', 'Az Zubayr|Zubair'),
    ('IQ', 'Tal Afar', 'تلعفر', 'ne:Tall Afar', 'Tall Afar'),
    # Saudi Arabia
    ('SA', 'Riyadh', 'الرياض', 'ne:Riyadh', 'Ar Riyad'),
    ('SA', 'Jeddah', 'جدة', 'ne:Jeddah', 'Jiddah|Jidda'),
    ('SA', 'Makkah', 'مكة المكرمة', 'ne:Makkah', 'Mecca|Mekka|Makka|مكة|البلد الحرام'),
    ('SA', 'Madinah', 'المدينة المنورة', 'ne:Medina', 'Medina|Al Madinah|المدينة|طيبة'),
    ('SA', 'Dammam', 'الدمام', 'ne:Dammam', ''),
    ('SA', 'Khobar', 'الخبر', 'gn:Khobar', 'Al Khobar'),
    ('SA', 'Dhahran', 'الظهران', 'ne:Az Zahran', 'Az Zahran'),
    ('SA', "Ta'if", 'الطائف', 'ne:At Taif', 'Taif|At Taif'),
    ('SA', 'Tabuk', 'تبوك', 'ne:Tabuk', ''),
    ('SA', 'Buraydah', 'بريدة', 'ne:Buraydah', 'Buraidah'),
    ('SA', 'Unaizah', 'عنيزة', 'gn:Unaizah', 'Unayzah|Onaizah'),
    ('SA', 'Khamis Mushait', 'خميس مشيط', 'gn:Khamis Mushait', 'Khamis Mushayt'),
    ('SA', 'Abha', 'أبها', 'ne:Abha', ''),
    ('SA', "Ha'il", 'حائل', 'ne:Hail', 'Hail'),
    ('SA', 'Najran', 'نجران', 'ne:Najran', ''),
    ('SA', 'Jazan', 'جازان', 'ne:Jizan', 'Jizan|Gizan|جيزان'),
    ('SA', 'Hofuf', 'الهفوف', 'ne:Hofuf', 'Al Hofuf|Al Ahsa|Al-Hasa|الأحساء'),
    ('SA', 'Mubarraz', 'المبرز', 'ne:Al Mubarraz', 'Al Mubarraz'),
    ('SA', 'Qatif', 'القطيف', 'ne:Al-Qatif', 'Al Qatif'),
    ('SA', 'Jubail', 'الجبيل', 'ne:Al Jubayl', 'Al Jubayl'),
    ('SA', 'Yanbu', 'ينبع', 'ne:Yanbu al Bahr', 'Yanbu al Bahr'),
    ('SA', 'Hafar Al-Batin', 'حفر الباطن', 'ne:Hafar al Batin', 'Hafr al Batin'),
    ('SA', 'Al-Kharj', 'الخرج', 'ne:Al Kharj', 'Kharj'),
    ('SA', 'Arar', 'عرعر', 'ne:Arar', ''),
    ('SA', 'Sakaka', 'سكاكا', 'ne:Sakakah', 'Sakakah'),
    ('SA', 'Al-Bahah', 'الباحة', 'gn:Al Bahah', 'Al Baha|Baha'),
    ('SA', 'AlUla', 'العُلا', 'gn:Al-`Ula', 'Al Ula|Al-Ula|العلا'),
    ('SA', 'Bisha', 'بيشة', 'gn:Bīshah', 'Bishah'),
    ('SA', 'Al-Qurayyat', 'القريات', 'gn:Qurayyat', 'Qurayyat'),
    ('SA', 'Rafha', 'رفحاء', 'ne:Rafha', ''),
    ('SA', 'Al-Wajh', 'الوجه', 'ne:Al Wajh', 'Wajh'),
    ('SA', 'Al-Qunfudhah', 'القنفذة', 'ne:Al Qunfudhah', 'Qunfudhah'),
    ('SA', 'Dumat al-Jandal', 'دومة الجندل', 'ne:Dawmat al Jandal', 'Dawmat al Jandal'),
    # Gulf
    ('KW', 'Kuwait City', 'مدينة الكويت', 'ne:Kuwait City', 'Kuwait|الكويت'),
    ('KW', 'Jahra', 'الجهراء', 'ne:Al Jahra', 'Al Jahra'),
    ('KW', 'Hawalli', 'حولي', 'ne:Hawalli', ''),
    ('KW', 'Ahmadi', 'الأحمدي', 'ne:Al Ahmadi', 'Al Ahmadi'),
    ('KW', 'Farwaniya', 'الفروانية', 'gn:Al Farwānīyah', 'Al Farwaniyah'),
    ('BH', 'Manama', 'المنامة', 'ne:Manama', 'Bahrain|البحرين'),
    ('BH', 'Muharraq', 'المحرق', 'gn:Al Muharraq', 'Al Muharraq'),
    ('BH', 'Riffa', 'الرفاع', 'gn:Ar Rifā‘', 'Ar Rifa'),
    ('QA', 'Doha', 'الدوحة', 'ne:Doha', 'Qatar|قطر'),
    ('QA', 'Al Wakrah', 'الوكرة', 'gn:Al Wakrah', 'Wakra'),
    ('QA', 'Al Khor', 'الخور', 'gn:Al Khawr', 'Al Khawr'),
    ('AE', 'Abu Dhabi', 'أبوظبي', 'ne:Abu Dhabi', 'أبو ظبي'),
    ('AE', 'Dubai', 'دبي', 'ne:Dubai', 'Dubayy'),
    ('AE', 'Sharjah', 'الشارقة', 'ne:Sharjah', 'Ash Shariqah'),
    ('AE', 'Ajman', 'عجمان', 'gn:Ajman', ''),
    ('AE', 'Al Ain', 'العين', 'ne:Al Ayn', 'Al Ayn'),
    ('AE', 'Ras Al Khaimah', 'رأس الخيمة', 'ne:Ras al Khaymah', 'Ras al Khaymah|RAK'),
    ('AE', 'Fujairah', 'الفجيرة', 'ne:Al Fujayrah', 'Al Fujayrah'),
    ('AE', 'Umm Al Quwain', 'أم القيوين', 'ne:Umm al Qaywayn', 'Umm al Qaywayn'),
    ('OM', 'Muscat', 'مسقط', 'ne:Muscat', 'Masqat|Oman|عُمان'),
    ('OM', 'Seeb', 'السيب', 'ne:Seeb', 'As Sib'),
    ('OM', 'Salalah', 'صلالة', 'ne:Salalah', ''),
    ('OM', 'Sohar', 'صحار', 'ne:Suhar', 'Suhar'),
    ('OM', 'Nizwa', 'نزوى', 'gn:Nizwá', ''),
    ('OM', 'Sur', 'صور', 'gn:Sur', ''),
    ('OM', 'Ibri', 'عبري', 'ne:Ibri', ''),
    ('OM', 'Buraimi', 'البريمي', 'gn:Al Buraymī', 'Al Buraymi'),
    ('OM', 'Khasab', 'خصب', 'gn:Khasab', ''),
    # Yemen
    ('YE', "Sana'a", 'صنعاء', 'ne:Sanaa', 'Sanaa|Sana'),
    ('YE', 'Aden', 'عدن', 'ne:Aden', ''),
    ('YE', 'Taiz', 'تعز', 'ne:Taizz', 'Taizz|Taiz'),
    ('YE', 'Hodeidah', 'الحديدة', 'ne:Al Hudaydah', 'Al Hudaydah|Hudaydah'),
    ('YE', 'Mukalla', 'المكلا', 'ne:Al Mukalla', 'Al Mukalla'),
    ('YE', 'Ibb', 'إب', 'ne:Ibb', ''),
    ('YE', 'Hajjah', 'حجة', 'ne:Hajjah', ''),
    ('YE', 'Dhamar', 'ذمار', 'ne:Dhamar', ''),
    ('YE', "Sa'dah", 'صعدة', 'ne:Sadah', 'Saada|Sadah'),
    ('YE', 'Seiyun', 'سيئون', 'ne:Saywun', 'Saywun|Sayun'),
    ('YE', 'Tarim', 'تريم', 'gn:Tarim', ''),
    ('YE', 'Zabid', 'زبيد', 'ne:Zabīd', ''),
    ('YE', "Ma'rib", 'مأرب', 'ne:Marib', 'Marib'),
    ('YE', 'Lahij', 'لحج', 'ne:Lahij', 'Lahj'),
    ('YE', 'Al Bayda', 'البيضاء', 'ne:Al Bayda', 'Bayda'),
    ('YE', 'Ataq', 'عتق', "ne:'Ataq", ''),
    ('YE', 'Al Ghaydah', 'الغيضة', 'ne:Al Ghaydah', 'Ghaydah'),
    # Egypt
    ('EG', 'Cairo', 'القاهرة', 'ne:Cairo', 'Al Qahirah|Misr|مصر'),
    ('EG', 'Alexandria', 'الإسكندرية', 'ne:Alexandria', 'Al Iskandariyah|Iskandariya'),
    ('EG', 'Giza', 'الجيزة', 'ne:Giza', 'Al Jizah'),
    ('EG', 'Shubra El Kheima', 'شبرا الخيمة', 'gn:Shubrā al Khaymah', 'Shubra al Khaymah'),
    ('EG', 'Port Said', 'بورسعيد', 'ne:Bur Said', 'Bur Said|بور سعيد'),
    ('EG', 'Suez', 'السويس', 'ne:Suez', 'As Suways'),
    ('EG', 'Luxor', 'الأقصر', 'ne:Luxor', 'Al Uqsur'),
    ('EG', 'Aswan', 'أسوان', 'ne:Aswan', ''),
    ('EG', 'Mansoura', 'المنصورة', 'ne:El Mansura', 'El Mansura|Al Mansurah'),
    ('EG', 'Tanta', 'طنطا', 'ne:Tanta', ''),
    ('EG', 'Asyut', 'أسيوط', 'ne:Asyut', 'Assiut'),
    ('EG', 'Ismailia', 'الإسماعيلية', 'ne:Ismaïlia', 'Al Ismailiyah'),
    ('EG', 'Faiyum', 'الفيوم', 'ne:El Faiyum', 'Fayoum|El Faiyum'),
    ('EG', 'Zagazig', 'الزقازيق', 'ne:Zagazig', ''),
    ('EG', 'Damietta', 'دمياط', 'ne:Dumyat', 'Dumyat'),
    ('EG', 'Minya', 'المنيا', 'ne:El Minya', 'El Minya|Al Minya'),
    ('EG', 'Beni Suef', 'بني سويف', 'ne:Beni Suef', ''),
    ('EG', 'Qena', 'قنا', 'ne:Qena', ''),
    ('EG', 'Sohag', 'سوهاج', 'ne:Sohag', 'Suhaj'),
    ('EG', 'Hurghada', 'الغردقة', 'ne:Hurghada', 'Al Ghardaqah'),
    ('EG', 'Sharm El Sheikh', 'شرم الشيخ', 'gn:Sharm el-Sheikh', 'Sharm'),
    ('EG', 'Dahab', 'دهب', 'gn:Dahab', ''),
    ('EG', 'Damanhur', 'دمنهور', 'ne:Damanhûr', ''),
    ('EG', 'El Mahalla El Kubra', 'المحلة الكبرى', 'gn:Al Maḩallah al Kubrá', 'Mahalla'),
    ('EG', 'Kafr El Sheikh', 'كفر الشيخ', 'ne:Kafr el Sheikh', ''),
    ('EG', 'Banha', 'بنها', 'ne:Benha', 'Benha'),
    ('EG', 'Shibin El Kom', 'شبين الكوم', 'ne:Shibin el Kom', ''),
    ('EG', 'Arish', 'العريش', 'ne:El Arish', 'El Arish'),
    ('EG', 'Marsa Matruh', 'مرسى مطروح', 'ne:Matruh', 'Matruh'),
    ('EG', 'Siwa', 'سيوة', 'gn:Sīwah', 'Siwah'),
    ('EG', 'El Tor', 'الطور', 'ne:El Tur', 'Tur Sinai|El Tur'),
    ('EG', 'Kharga', 'الخارجة', 'ne:El Kharga', 'El Kharga'),
    ('EG', 'Mallawi', 'ملوي', 'ne:Mallawi', ''),
    # Sudan
    ('SD', 'Khartoum', 'الخرطوم', 'ne:Khartoum', ''),
    ('SD', 'Omdurman', 'أم درمان', 'ne:Omdurman', ''),
    ('SD', 'Khartoum North', 'الخرطوم بحري', 'gn:Khartoum North', 'Bahri|بحري'),
    ('SD', 'Port Sudan', 'بورتسودان', 'ne:Port Sudan', 'بور سودان'),
    ('SD', 'Kassala', 'كسلا', 'ne:Kassala', ''),
    ('SD', 'Wad Madani', 'ود مدني', 'ne:Medani', 'Medani'),
    ('SD', 'El Obeid', 'الأبيض', 'ne:Al-Ubayyid', 'Al Ubayyid'),
    ('SD', 'Nyala', 'نيالا', 'ne:Nyala', ''),
    ('SD', 'El Fasher', 'الفاشر', 'ne:El Fasher', 'Al Fashir'),
    ('SD', 'Gedaref', 'القضارف', 'ne:Gedaref', 'Al Qadarif'),
    ('SD', 'Kosti', 'كوستي', 'ne:Kosti', ''),
    ('SD', 'Atbara', 'عطبرة', 'ne:Atbarah', 'Atbarah'),
    ('SD', 'Dongola', 'دنقلا', 'gn:Dongola', 'Dunqulah'),
    ('SD', 'Geneina', 'الجنينة', 'ne:Geneina', 'Al Junaynah'),
    ('SD', 'Kadugli', 'كادقلي', 'ne:Kadugli', ''),
    ('SD', 'Sennar', 'سنار', 'ne:Sennar', ''),
    ('SD', 'Ad-Damazin', 'الدمازين', 'ne:Ad Damazīn', 'Damazin'),
    ('SD', 'Shendi', 'شندي', 'ne:Shendi', ''),
    ('SD', 'Wadi Halfa', 'وادي حلفا', 'gn:Wadi Halfa', ''),
    # Libya
    ('LY', 'Tripoli', 'طرابلس', 'ne:Tripoli', 'Tarabulus|طرابلس الغرب'),
    ('LY', 'Benghazi', 'بنغازي', 'ne:Banghazi', 'Banghazi'),
    ('LY', 'Misrata', 'مصراتة', 'ne:Misrata', 'Misurata'),
    ('LY', 'Tobruk', 'طبرق', 'ne:Tubruq', 'Tubruq'),
    ('LY', 'Zawiya', 'الزاوية', 'ne:Az Zawiyah', 'Az Zawiyah'),
    ('LY', 'Khoms', 'الخمس', 'ne:Al Khums', 'Al Khums'),
    ('LY', 'Zuwara', 'زوارة', 'ne:Zuwara', ''),
    ('LY', 'Bayda', 'البيضاء', 'gn:Al Bayḑā’', 'Al Bayda'),
    ('LY', 'Marj', 'المرج', 'ne:Al Marj', 'Al Marj'),
    ('LY', 'Gharyan', 'غريان', 'ne:Gharyan', ''),
    ('LY', 'Ajdabiya', 'أجدابيا', 'ne:Ajdabiya', ''),
    ('LY', 'Sirte', 'سرت', 'ne:Surt', 'Surt'),
    ('LY', 'Derna', 'درنة', 'ne:Darnah', 'Darnah'),
    ('LY', 'Sabha', 'سبها', 'ne:Sabha', 'Sebha'),
    ('LY', 'Ghadames', 'غدامس', 'gn:Ghadames', 'Ghadamis'),
    ('LY', 'Kufra', 'الكفرة', 'ne:Al Jawf', 'Al Kufrah'),
    ('LY', 'Bani Walid', 'بني وليد', 'ne:Bani Walid', ''),
    ('LY', 'Ghat', 'غات', 'ne:Ghat', ''),
    ('LY', 'Murzuq', 'مرزق', 'ne:Marzuq', 'Marzuq'),
    # Tunisia
    ('TN', 'Tunis', 'تونس', 'ne:Tunis', ''),
    ('TN', 'Sfax', 'صفاقس', 'ne:Sfax', ''),
    ('TN', 'Sousse', 'سوسة', 'ne:Sousse', 'Susah'),
    ('TN', 'Kairouan', 'القيروان', 'ne:Qairouan', 'Qairouan|Al Qayrawan'),
    ('TN', 'Bizerte', 'بنزرت', 'ne:Bizerte', 'Banzart'),
    ('TN', 'Gabès', 'قابس', 'ne:Gabès', 'Gabes'),
    ('TN', 'Ariana', 'أريانة', "ne:L'Ariana", ''),
    ('TN', 'Gafsa', 'قفصة', 'ne:Gafsa', ''),
    ('TN', 'Monastir', 'المنستير', 'ne:Monastir', ''),
    ('TN', 'Kasserine', 'القصرين', 'ne:Kasserine', ''),
    ('TN', 'Nabeul', 'نابل', 'ne:Nabeul', ''),
    ('TN', 'Mahdia', 'المهدية', 'ne:Mahdia', ''),
    ('TN', 'Medenine', 'مدنين', 'ne:Medenine', ''),
    ('TN', 'Tataouine', 'تطاوين', 'ne:Tataouine', ''),
    ('TN', 'Béja', 'باجة', 'ne:Béja', 'Beja'),
    ('TN', 'Jendouba', 'جندوبة', 'ne:Jendouba', ''),
    ('TN', 'El Kef', 'الكاف', 'ne:El Kef', 'Kef'),
    ('TN', 'Sidi Bouzid', 'سيدي بوزيد', 'ne:Sdid Bouzid', ''),
    ('TN', 'Tozeur', 'توزر', 'ne:Tozeur', ''),
    ('TN', 'Kebili', 'قبلي', 'ne:Kebili', ''),
    ('TN', 'Zarzis', 'جرجيس', 'ne:Zarzis', ''),
    ('TN', 'Djerba (Houmt Souk)', 'جربة (حومة السوق)', 'gn:Houmt Souk', 'Djerba|Jerba|Houmt Souk|جربة'),
    ('TN', 'Hammamet', 'الحمامات', 'gn:Hammamet', ''),
    ('TN', 'Siliana', 'سليانة', 'ne:Siliana', ''),
    ('TN', 'Zaghouan', 'زغوان', 'ne:Zaghouan', ''),
    # Algeria
    ('DZ', 'Algiers', 'الجزائر العاصمة', 'ne:Algiers', 'Alger|Al Jazair|الجزائر'),
    ('DZ', 'Oran', 'وهران', 'ne:Oran', 'Wahran'),
    ('DZ', 'Constantine', 'قسنطينة', 'ne:Constantine', 'Qacentina'),
    ('DZ', 'Annaba', 'عنابة', 'ne:Annaba', ''),
    ('DZ', 'Blida', 'البليدة', 'ne:Blida', ''),
    ('DZ', 'Batna', 'باتنة', 'ne:Batna', ''),
    ('DZ', 'Sétif', 'سطيف', 'ne:Sétif', 'Setif'),
    ('DZ', 'Tlemcen', 'تلمسان', 'ne:Tlimcen', ''),
    ('DZ', 'Béjaïa', 'بجاية', 'ne:Béjaïa', 'Bejaia|Bougie'),
    ('DZ', 'Biskra', 'بسكرة', 'ne:Biskra', ''),
    ('DZ', 'Chlef', 'الشلف', 'ne:Chlef', ''),
    ('DZ', 'Djelfa', 'الجلفة', 'ne:Djelfa', ''),
    ('DZ', 'Sidi Bel Abbès', 'سيدي بلعباس', 'ne:Sidi bel Abbes', 'Sidi Bel Abbes'),
    ('DZ', 'Tiaret', 'تيارت', 'ne:Tiarat', ''),
    ('DZ', 'Skikda', 'سكيكدة', 'ne:Skikda', ''),
    ('DZ', 'Mostaganem', 'مستغانم', 'ne:Mostaganem', ''),
    ('DZ', 'El Oued', 'الوادي', 'ne:El Oued', ''),
    ('DZ', 'Ouargla', 'ورقلة', 'ne:Ouargla', ''),
    ('DZ', 'Tébessa', 'تبسة', 'ne:Tébessa', 'Tebessa'),
    ('DZ', "M'Sila", 'المسيلة', "ne:M'sila", 'Msila'),
    ('DZ', 'Jijel', 'جيجل', 'ne:Jijel', ''),
    ('DZ', 'Médéa', 'المدية', 'ne:Médéa', 'Medea'),
    ('DZ', 'Tizi Ouzou', 'تيزي وزو', 'ne:Tizi-Ouzou', ''),
    ('DZ', 'Béchar', 'بشار', 'ne:Béchar', 'Bechar'),
    ('DZ', 'Saïda', 'سعيدة', 'ne:Saïda', 'Saida'),
    ('DZ', 'Bordj Bou Arréridj', 'برج بوعريريج', 'ne:Bordj Bou Arréridj', 'Bordj Bou Arreridj'),
    ('DZ', 'Souk Ahras', 'سوق أهراس', 'ne:Souk Ahras', ''),
    ('DZ', 'Touggourt', 'تقرت', 'ne:Touggourt', ''),
    ('DZ', 'Ghardaïa', 'غرداية', 'ne:Ghardaia', 'Ghardaia'),
    ('DZ', 'Guelma', 'قالمة', 'ne:Guelma', ''),
    ('DZ', 'Laghouat', 'الأغواط', 'ne:Laghouat', ''),
    ('DZ', 'Bouira', 'البويرة', 'ne:Bouïra', ''),
    ('DZ', 'Mascara', 'معسكر', 'ne:Mascara', ''),
    ('DZ', 'Oum El Bouaghi', 'أم البواقي', 'ne:Oum el Bouaghi', ''),
    ('DZ', 'Tamanrasset', 'تمنراست', 'ne:Tamanrasset', ''),
    ('DZ', 'Adrar', 'أدرار', 'ne:Adrar', ''),
    ('DZ', 'El Bayadh', 'البيض', 'ne:El Bayadh', ''),
    ('DZ', 'Tindouf', 'تندوف', 'ne:Tindouf', ''),
    ('DZ', 'Hassi Messaoud', 'حاسي مسعود', 'ne:Hassi Messaoud', ''),
    ('DZ', 'In Salah', 'عين صالح', 'gn:In Salah', 'Ain Salah'),
    ('DZ', 'Illizi', 'إليزي', 'ne:Illizi', ''),
    ('DZ', 'Timimoun', 'تيميمون', 'ne:Timimoun', ''),
    # Morocco
    ('MA', 'Rabat', 'الرباط', 'ne:Rabat', ''),
    ('MA', 'Casablanca', 'الدار البيضاء', 'ne:Casablanca', 'Dar el Beida|كازابلانكا'),
    ('MA', 'Fez', 'فاس', 'ne:Fez', 'Fes'),
    ('MA', 'Marrakesh', 'مراكش', 'ne:Marrakesh', 'Marrakech'),
    ('MA', 'Tangier', 'طنجة', 'ne:Tangier', 'Tanger'),
    ('MA', 'Agadir', 'أكادير', 'ne:Agadir', 'أغادير'),
    ('MA', 'Meknes', 'مكناس', 'ne:Meknes', 'Meknès'),
    ('MA', 'Oujda', 'وجدة', 'ne:Oujda', ''),
    ('MA', 'Kenitra', 'القنيطرة', 'ne:Kenitra', ''),
    ('MA', 'Tétouan', 'تطوان', 'gn:Tétouan', 'Tetouan|Tetuan'),
    ('MA', 'Safi', 'آسفي', 'ne:Safi', 'أسفي'),
    ('MA', 'El Jadida', 'الجديدة', 'ne:El Jadida', ''),
    ('MA', 'Nador', 'الناظور', 'gn:Nador', ''),
    ('MA', 'Beni Mellal', 'بني ملال', 'gn:Beni Mellal', ''),
    ('MA', 'Khouribga', 'خريبكة', 'gn:Khouribga', ''),
    ('MA', 'Mohammedia', 'المحمدية', 'gn:Mohammedia', ''),
    ('MA', 'Taza', 'تازة', 'ne:Taza', ''),
    ('MA', 'Settat', 'سطات', 'ne:Settat', ''),
    ('MA', 'Larache', 'العرائش', 'ne:Larache', ''),
    ('MA', 'Ksar El Kebir', 'القصر الكبير', 'ne:Ksar El Kebir', ''),
    ('MA', 'Errachidia', 'الرشيدية', 'ne:Er Rachidia', 'Er Rachidia'),
    ('MA', 'Guelmim', 'كلميم', 'ne:Goulimine', 'Goulimine'),
    ('MA', 'Essaouira', 'الصويرة', 'gn:Essaouira', 'Mogador'),
    ('MA', 'Ouarzazate', 'ورزازات', 'gn:Ouarzazate', ''),
    ('MA', 'Chefchaouen', 'شفشاون', 'gn:Chefchaouen', 'Chaouen'),
    ('MA', 'Al Hoceima', 'الحسيمة', 'gn:Al Hoceïma', 'Al Hoceima'),
    ('MA', 'Tiznit', 'تزنيت', 'gn:Tiznit', ''),
    ('MA', 'Ouezzane', 'وزان', 'gn:Ouezzane', 'Wazzan'),
    ('MA', 'Tan-Tan', 'طانطان', 'ne:Tan Tan', 'Tan Tan'),
    ('MA', 'Laayoune', 'العيون', 'ne:Laayoune', 'El Aaiun|Layoune'),
    ('MA', 'Dakhla', 'الداخلة', 'ne:Ad Dakhla', 'Ad Dakhla|Villa Cisneros'),
    ('MA', 'Smara', 'السمارة', 'ne:Smara', 'Es Semara'),
    # Mauritania
    ('MR', 'Nouakchott', 'نواكشوط', 'ne:Nouakchott', ''),
    ('MR', 'Nouadhibou', 'نواذيبو', 'ne:Nouadhibou', ''),
    ('MR', 'Kiffa', 'كيفة', 'ne:Kiffa', ''),
    ('MR', 'Rosso', 'روصو', 'ne:Rosso', ''),
    ('MR', 'Atar', 'أطار', 'ne:Atar', ''),
    ('MR', 'Zouérat', 'الزويرات', 'gn:Zouérat', 'Zouerate|Zouirat'),
    ('MR', 'Kaédi', 'كيهيدي', 'gn:Kaédi', 'Kaedi'),
    ('MR', 'Néma', 'النعمة', 'ne:Nema', 'Nema'),
    ('MR', 'Tidjikja', 'تجكجة', 'ne:Tidjikdja', ''),
    ('MR', 'Aleg', 'ألاك', 'ne:Aleg', ''),
    ('MR', 'Akjoujt', 'أكجوجت', 'ne:Akjoujt', ''),
    ('MR', 'Aioun', 'لعيون', 'ne:Ayoun el Atrous', 'Ayoun el Atrous|العيون'),
    # Horn of Africa and Comoros
    ('SO', 'Mogadishu', 'مقديشو', 'ne:Mogadishu', 'Muqdisho'),
    ('SO', 'Hargeisa', 'هرجيسا', 'ne:Hargeisa', ''),
    ('SO', 'Berbera', 'بربرة', 'ne:Berbera', ''),
    ('SO', 'Kismayo', 'كسمايو', 'ne:Kismaayo', 'Kismaayo'),
    ('SO', 'Baidoa', 'بيدوا', 'ne:Baydhabo', 'Baydhabo'),
    ('SO', 'Jowhar', 'جوهر', 'ne:Jawhar', 'Jawhar'),
    ('SO', 'Burao', 'برعو', 'gn:Burao', 'Burco'),
    ('SO', 'Beledweyne', 'بلدوين', 'ne:Beledweyne', ''),
    ('SO', 'Galkayo', 'جالكعيو', 'ne:Gaalkacyo', 'Gaalkacyo'),
    ('SO', 'Bosaso', 'بوصاصو', 'ne:Boosaaso', 'Boosaaso'),
    ('DJ', 'Djibouti', 'جيبوتي', 'ne:Djibouti', ''),
    ('DJ', 'Ali Sabieh', 'علي صبيح', 'ne:Ali Sabih', ''),
    ('DJ', 'Tadjourah', 'تاجورة', 'ne:Tadjoura', 'Tadjoura'),
    ('DJ', 'Obock', 'أوبوك', 'ne:Obock', ''),
    ('DJ', 'Dikhil', 'دخيل', 'ne:Dikhil', ''),
    ('KM', 'Moroni', 'موروني', 'ne:Moroni', 'Comoros|جزر القمر'),
    ('KM', 'Mutsamudu', 'موتسامودو', 'gn:Moutsamoudou', 'Moutsamoudou'),
    ('KM', 'Fomboni', 'فومبوني', 'gn:Fomboni', ''),
]

# Special time zones inside the Arab list.
ARAB_TZ = {
    ('PS', 'Jerusalem'): 'Asia/Jerusalem',
    ('MA', 'Laayoune'): 'Africa/El_Aaiun',
    ('MA', 'Dakhla'): 'Africa/El_Aaiun',
    ('MA', 'Smara'): 'Africa/El_Aaiun',
}

ARAB_CC = {cc for cc, *_ in ARAB}

# ------------------------------------------------------ rest of world --
MUSLIM_MAJORITY = set('TR IR PK AF BD ID MY BN UZ KZ KG TJ TM AZ AL BA XK SN ML NE TD GM GN SL BF MV NG'.split())

# Extra cities (Natural Earth NAME) kept regardless of population: places
# Muslims travel to, historic cities and large Muslim communities.
WORLD_EXTRA = {
    'RU': ['Kazan', 'Grozny', 'Makhachkala', 'Ufa', 'St.  Petersburg'],
    'KE': ['Mombasa', 'Lamu'],
    'TZ': ['Zanzibar'],
    'FR': ['Marseille', 'Lyon', 'Lille', 'Toulouse', 'Nice', 'Strasbourg'],
    'DE': ['Munich', 'Hamburg', 'Cologne', 'Frankfurt'],
    'ES': ['Granada‎', 'Córdoba', 'Seville', 'Barcelona'],
    'CH': ['Geneva', 'Zürich'],
    'GB': ['Birmingham', 'Manchester', 'Bradford', 'Leicester', 'Leeds', 'Glasgow', 'Liverpool', 'Sheffield', 'Edinburgh'],
    'NL': ['Rotterdam', 'Amsterdam'],
    'BE': ['Antwerpen'],
    'SE': ['Malmö', 'Gothenburg'],
    'NZ': ['Auckland'],
    'AU': ['Brisbane', 'Perth', 'Adelaide'],
    'CA': ['Calgary', 'Edmonton', 'Winnipeg', 'Québec', 'Halifax'],
    'US': ['Detroit', 'Houston', 'Minneapolis', 'Honolulu', 'Anchorage'],
    'IN': ['Srinagar', 'Hyderabad', 'Lucknow', 'Aligarh', 'Bhopal', 'Kozhikode'],
    'CN': ['Kashgar', 'Xining', 'Yinchuan', 'Ürümqi', 'Lanzhou'],
    'PH': ['Zamboanga', 'Cotabato'],
    'TH': ['Pattani'],
    'AF': ['Herat', 'Mazar-e Sharif'],
    'UZ': ['Bukhara', 'Nukus'],
    'KG': ['Osh'],
    'TJ': ['Khujand'],
    'KZ': ['Shymkent'],
    'BA': ['Mostar', 'Tuzla'],
    'AL': ['Shkodër', 'Durrës'],
    'MK': ['Tetovo'],
    'XK': ['Prizren'],
    'BD': ['Sylhet'],
    'ET': ['Harar'],
    'ML': ['Timbuktu', 'Mopti'],
    'NE': ['Agadez', 'Zinder'],
    'SN': ['Kaolack', 'Ziguinchor'],
    'GH': ['Kumasi', 'Tamale'],
    'ZA': ['Durban'],
    'CM': ['Garoua'],
}

# Natural Earth rows that are wrong or duplicates.
WORLD_SKIP = {
    ('NE', 232555),  # a second "Niamey" row that is really Maradi
    ('NG', 554906),  # Uyo (Arabic name collides with Oyo)
    ('PK', 1860310),  # Saidu (population error)
    ('NG', 1099931),  # Ikare (population error)
    ('ID', 881801),  # duplicate Bandar Lampung
    ('CN', 3830000),  # Hechi (population error)
    ('IL', 3112000),  # Tel Aviv: outside this app's audience (Jerusalem is listed under Palestine)
    ('IL', 1029300),  # Jerusalem: listed in the curated Palestine list
    ('US', 3240),  # Glasgow, Montana
    ('GB', 39654),  # Perth, Scotland
    ('CA', 4331),  # Liverpool, Nova Scotia
    ('NI', 105219),  # Granada, Nicaragua
    ('MX', 220563),  # Córdoba, Mexico
    ('AR', 1452000),  # Córdoba, Argentina (keeps Spain's Córdoba unambiguous)
    ('SJ', 1232),  # Longyearbyen
    ('FK', 2213),
    ('AQ', 0),
}
# Countries whose second-tier cities crowd the list without serving this
# app's audience: keep capitals, whitelisted cities and cities >= 5M.
WORLD_BIG_ONLY = {'CN', 'IN', 'BR', 'JP', 'MX', 'NG', 'PH', 'ZA', 'KR', 'TW', 'VN', 'CO', 'VE'}

# Corrected Arabic names (NE NAME -> Arabic).
AR_FIX = {
    'Busan': 'بوسان',
    'Arak': 'أراك',
    'Sokoto': 'سوكوتو',
    'Benin City': 'بنين سيتي',
    'Brussels': 'بروكسل',
    'Hamadan': 'همدان',
    'Malacca': 'ملقا',
    'Puebla': 'بويبلا',
    'Jilin': 'جيلين',
    'Andorra': 'أندورا لا فيلا',
    'Kelang': 'كلانغ',
    'Putrajaya': 'بوتراجايا',
    'Bandjarmasin': 'بنجرماسين',
    'Bogor': 'بوغور',
    'Palembang': 'باليمبانغ',
    'Padang': 'بادانغ',
    'Kyiv': 'كييف',
    'Zanzibar': 'زنجبار',
    'Cotabato': 'كوتاباتو',
    'Zamboanga': 'زامبوانغا',
    'Québec': 'كيبك',
    'Tarawa': 'تاراوا',
    'Luxembourg': 'لوكسمبورغ',
    'San Marino': 'سان مارينو',
    'Skopje': 'سكوبيه',
    'Durrës': 'دوريس',
    'Shkodër': 'شكودر',
    'Nukus': 'نوكوس',
    'Prizren': 'بريزرن',
    'Kozhikode': 'كاليكوت (كوزيكود)',
    'Perth': 'بيرث',
    'Guatemala City': 'مدينة غواتيمالا',
    'Maiduguri': 'مايدوغوري',
    'Quetta': 'كويتا',
    'Chattogram': 'شيتاغونغ',
    'Taichung': 'تايتشونغ',
    'Marseille': 'مرسيليا',
    'Granada‎': 'غرناطة',
    'Mazar-e Sharif': 'مزار شريف',
    'Almaty': 'ألماتي',
    'Nur-Sultan': 'أستانا',
    'Gaziantep': 'غازي عنتاب',
    'Icel': 'مرسين',
    'Antwerpen': 'أنتويرب',
    'Gothenburg': 'غوتنبرغ',
    'St.  Petersburg': 'سانت بطرسبرغ',
    'Dodoma': 'دودوما',
    'Sri Jayawardenepura Kotte': 'كوتي',
    'Grand Turk': 'كوكبيرن تاون',
    'Fargona': 'فرغانة',
    'Surakarta': 'سوراكارتا (سولو)',
    'Kaolack': 'كاولاك',
    'Awka': 'أوكا',
}
# Corrected English names (NE NAME -> English).
EN_FIX = {
    'St.  Petersburg': 'Saint Petersburg',
    'Washington,  D.C.': 'Washington, D.C.',
    'Icel': 'Mersin',
    'Nur-Sultan': 'Astana',
    'Granada‎': 'Granada',
    'Kelang': 'Klang',
    'Bandjarmasin': 'Banjarmasin',
    'Fargona': "Farg'ona",
    'Antwerpen': 'Antwerp',
    'København': 'Copenhagen',
    'Shenyeng': 'Shenyang',
    'Xian': "Xi'an",
    'Sri Jayawardenepura Kotte': 'Sri Jayawardenepura Kotte',
    'Agana': 'Hagåtña',
}
# English aliases for search.
EN_ALIAS = {
    'Istanbul': 'Constantinople|Stambul',
    'Mumbai': 'Bombay',
    'Chennai': 'Madras',
    'Kolkata': 'Calcutta',
    'Bengaluru': 'Bangalore',
    'Chattogram': 'Chittagong',
    'Kyiv': 'Kiev',
    'Beijing': 'Peking',
    'København': 'Kobenhavn',
    'Nur-Sultan': 'Nur-Sultan|Astana',
    'Almaty': 'Alma-Ata',
    'Yangon': 'Rangoon',
    'Ho Chi Minh City': 'Saigon',
    'Guangzhou': 'Canton',
    'Icel': 'Icel|Mersin',
    'Makhachkala': 'Dagestan',
    'Grozny': 'Chechnya',
    'Kazan': 'Tatarstan',
    'Bursa': 'Brusa',
    'Gaziantep': 'Antep',
}
# Time zone overrides (NE NAME -> zone) for multi-zone countries.
TZ_FIX = {
    ('US', 'Houston'): 'America/Chicago',
    ('US', 'Dallas'): 'America/Chicago',
    ('US', 'Anchorage'): 'America/Anchorage',
    ('US', 'Detroit'): 'America/Detroit',
    ('US', 'Minneapolis'): 'America/Chicago',
    ('US', 'St. Louis'): 'America/Chicago',
    ('US', 'Irvine'): 'America/Los_Angeles',
    ('US', 'Long Beach'): 'America/Los_Angeles',
    ('US', 'Fort Lauderdale'): 'America/New_York',
    ('US', 'Tampa'): 'America/New_York',
    ('US', 'Miami'): 'America/New_York',
    ('US', 'Atlanta'): 'America/New_York',
    ('US', 'Phoenix'): 'America/Phoenix',
    ('US', 'Denver'): 'America/Denver',
    ('CA', 'Montréal'): 'America/Toronto',
    ('CA', 'Ottawa'): 'America/Toronto',
    ('CA', 'Québec'): 'America/Toronto',
    ('AU', 'Sydney'): 'Australia/Sydney',
    ('AU', 'Melbourne'): 'Australia/Melbourne',
    ('AU', 'Canberra'): 'Australia/Sydney',
    ('KZ', 'Almaty'): 'Asia/Almaty',
    ('KZ', 'Nur-Sultan'): 'Asia/Almaty',
    ('KZ', 'Shymkent'): 'Asia/Almaty',
    ('RU', 'Ufa'): 'Asia/Yekaterinburg',
    ('CN', 'Ürümqi'): 'Asia/Shanghai',
    ('CN', 'Kashgar'): 'Asia/Shanghai',
    ('BR', 'Brasília'): 'America/Sao_Paulo',
    ('ES', 'Madrid'): 'Europe/Madrid',
    ('PT', 'Lisbon'): 'Europe/Lisbon',
    ('CD', 'Kinshasa'): 'Africa/Kinshasa',
    ('ID', 'Denpasar'): 'Asia/Makassar',
    ('MY', 'Kuching'): 'Asia/Kuching',
    ('MY', 'Kota Kinabalu'): 'Asia/Kuching',
    ('EC', 'Quito'): 'America/Guayaquil',
    ('CL', 'Santiago'): 'America/Santiago',
    ('CL', 'Valparaíso'): 'America/Santiago',
    ('AR', 'Buenos Aires'): 'America/Argentina/Buenos_Aires',
    ('MN', 'Ulaanbaatar'): 'Asia/Ulaanbaatar',
    ('UA', 'Kyiv'): 'Europe/Kyiv',
    ('DE', 'Berlin'): 'Europe/Berlin',
    ('CY', 'Nicosia'): 'Asia/Nicosia',
    ('UZ', 'Tashkent'): 'Asia/Tashkent',
    ('UZ', 'Samarkand'): 'Asia/Samarkand',
    ('UZ', 'Bukhara'): 'Asia/Samarkand',
    ('UZ', 'Nukus'): 'Asia/Samarkand',
    ('UZ', 'Fargona'): 'Asia/Tashkent',
    ('UZ', 'Namangan'): 'Asia/Tashkent',
    ('UZ', 'Andijan'): 'Asia/Tashkent',
}


def strip_prefix(ar):
    for p in ('مدينة ', 'محافظة ', 'ولاية ', 'مقاطعة '):
        keep = ('مدينة مكسيكو', 'مدينة بنما', 'مدينة هو تشي منه', 'مدينة الكويت', 'مدينة غواتيمالا')
        if ar.startswith(p) and ar not in keep:
            return ar[len(p):]
    return ar


def slug(s):
    s = fold(s).replace(' ', '-')
    return re.sub('-+', '-', s)


cities = []
used_ids = set()


def add(cc, en, ar, lat, lon, tz, pop, alias, cap):
    cid = f'{cc.lower()}-{slug(en)}'
    if cid in used_ids:
        raise SystemExit(f'duplicate id {cid}')
    used_ids.add(cid)
    cities.append({
        'id': cid, 'ar': ar, 'en': en, 'lat': round(lat, 4), 'lon': round(lon, 4),
        'tz': tz, 'cc': cc, 'pop': int(pop or 0), 'alias': alias, 'cap': cap,
    })


# Natural Earth also flags region capitals (Cardiff, Funchal…) and the seats
# of disputed or unrecognised administrations (Laayoune, Hargeisa, Sukhumi).
# The flag here means "the national capital" (it ranks suggestions and shows
# the capital icon), so these are plain cities.
NOT_CAPITAL = {
    ('MA', 'Laayoune'), ('SO', 'Hargeisa'), ('GE', 'Sukhumi'), ('GE', 'Batumi'),
    ('GB', 'Cardiff'), ('GB', 'Edinburgh'), ('GB', 'Belfast'), ('PT', 'Funchal'), ('PT', 'Ponta Delgada'),
    ('PH', 'Baguio City'), ('PH', 'Baguio'), ('RS', 'Novi Sad'), ('JP', 'Kyoto'), ('BA', 'Banja Luka'),
    ('ZA', 'Johannesburg'),
}

missing = []
for cc, en, ar, look, alias in ARAB:
    kind, name = look.split(':', 1)
    lat = lon = None
    pop = 0
    cap = False
    if kind == 'ne':
        q = ne_lookup(cc if not (cc == 'PS' and name == 'Jerusalem') else 'IL', name)
        if q:
            lat, lon, pop = q['LATITUDE'], q['LONGITUDE'], q['POP_MAX']
            cap = q['FEATURECLA'] in ('Admin-0 capital', 'Admin-0 capital alt') and (cc, en) not in NOT_CAPITAL
    else:
        g = gn_lookup(cc, name)
        if g:
            lat, lon = float(g['lat']), float(g['lng'])
    if lat is None:
        missing.append((cc, en, look))
        continue
    if cc == 'PS' and en == 'Jerusalem':
        cap = True
    tz = ARAB_TZ.get((cc, en)) or zone_for(cc, lat, lon)
    add(cc, en, ar, lat, lon, tz, pop, alias, cap)

if missing:
    print('MISSING', missing, file=sys.stderr)


def listed_capital(q):
    """Natural Earth's capital classes: such places are always listed."""
    return q['FEATURECLA'] in ('Admin-0 capital', 'Admin-0 capital alt', 'Admin-0 region capital')


def capital(q):
    """The national-capital flag stored in the list."""
    return listed_capital(q) and (q['_cc'], q['NAME']) not in NOT_CAPITAL


for q in ne:
    cc = q['_cc']
    if cc in ARAB_CC or cc in ('EH', '??') or cc == 'PS':
        continue
    if (cc, q['POP_MAX']) in WORLD_SKIP or cc in ('AQ',):
        continue
    if q['FEATURECLA'] in ('Scientific station', 'Meteorological Station', 'Historic place'):
        continue
    extra = q['NAME'] in WORLD_EXTRA.get(cc, [])
    if cc in MUSLIM_MAJORITY:
        ok = q['POP_MAX'] >= 500000 or listed_capital(q) or extra
    elif cc in WORLD_BIG_ONLY:
        ok = q['POP_MAX'] >= 5000000 or listed_capital(q) or extra
    else:
        ok = q['POP_MAX'] >= 2000000 or listed_capital(q) or extra
    if not ok:
        continue
    if listed_capital(q) and q['POP_MAX'] < 1000 and not extra:
        continue
    en = EN_FIX.get(q['NAME'], q['NAME'])
    ar = AR_FIX.get(q['NAME']) or strip_prefix(q['NAME_AR'])
    tz = zone_for(cc, q['LATITUDE'], q['LONGITUDE'], ne_zone=q['TIMEZONE'], override=TZ_FIX.get((cc, q['NAME'])))
    alias = EN_ALIAS.get(q['NAME'], '')
    if q['NAMEASCII'] and fold(q['NAMEASCII']) != fold(en):
        alias = '|'.join(filter(None, [alias, q['NAMEASCII']]))
    if q['NAME'] != en and fold(q['NAME']) != fold(en):
        alias = '|'.join(filter(None, [alias, q['NAME']]))
    add(cc, en, ar, q['LATITUDE'], q['LONGITUDE'], tz, q['POP_MAX'], alias, capital(q))

# Dearborn (Michigan): one of the largest Arab-American communities.
g = gn_lookup('US', 'Dearborn')
add('US', 'Dearborn', 'ديربورن', float(g['lat']), float(g['lng']), 'America/Detroit', 0, '', False)

used_cc = sorted({c['cc'] for c in cities})
countries = {cc: [cldr_ar[cc], cldr_en[cc]] for cc in used_cc}

cities.sort(key=lambda c: (c['cc'] not in ARAB_CC, c['cc'], -c['pop'], c['en']))
out = {
    'version': 1,
    'fields': ['id', 'ar', 'en', 'lat', 'lon', 'tz', 'cc', 'pop', 'flags', 'aliases'],
    'source': 'Natural Earth (public domain), GeoNames via lutangar/cities.json (CC BY 4.0), IANA zone.tab (public domain), Unicode CLDR (Unicode License v3); curated for Madar',
    'countries': countries,
    'cities': [
        [c['id'], c['ar'], c['en'], c['lat'], c['lon'], c['tz'], c['cc'], c['pop'], 1 if c['cap'] else 0, c['alias']]
        for c in cities
    ],
}
with open(OUT, 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
print(f'{len(cities)} cities, {len(countries)} countries -> {OUT}', file=sys.stderr)
if len(sys.argv) > 3:
    with open(sys.argv[3], 'w', encoding='utf-8') as f:
        for c in cities:
            f.write(f"{c['cc']}|{c['en']}|{c['ar']}|{c['tz']}|{c['pop']}|{c['lat']},{c['lon']}|{c['alias']}\n")
