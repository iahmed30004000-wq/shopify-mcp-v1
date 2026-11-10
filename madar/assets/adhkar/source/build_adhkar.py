#!/usr/bin/env python3
"""Builds assets/adhkar/hisn_al_muslim.json from openly licensed sources.

This folder is NOT bundled into the app (Flutter only bundles the files
directly inside assets/adhkar/). It documents how the bundled JSON was made
so the content can be audited and rebuilt.

Sources (see assets/licenses/adhkar_credits.txt for URLs, licences, SHAs):
  * seen   – Seen-Arabic/Morning-And-Evening-Adhkar-DB (MIT): morning and
             evening adhkar with counts, virtues, references, English.
  * ipro   – YousefAsalya/Islamic-Pro-azkar-API (MIT): the full Hisn
             al-Muslim (Arabic + English); used for waking, sleep and
             after-prayer adhkar.
  * quran  – fawazahmed0/quran-api (Unlicense): `ara-quranspelled` (imla'i
             script, fully vowelled) is the reference text for every Quran
             verse; `ara-quransimple` cross-checks it.
Verification only (never bundled): rn0x/hisn_almuslim_json (older Hisn
edition, independent typing), fitrahive/dua-dhikr (MIT, independent
compilation), osamayy/azkar-db.

Usage:
  python3 build_adhkar.py --src <dir with the clones> --out ../hisn_al_muslim.json

Every change made to the source text is explicit below (FIXES / rewrites),
then the normaliser applies the mechanical clean-ups (NFC, no tatweel,
tanween before alif, vowels moved off bare alifs, stray markers removed).

English: the datasets' English meanings and virtues are NOT used. Both
repositories say they copied them from hisnmuslim.com / sunnah.com (the
Islamic-Pro fetch script scrapes hisnmuslim.com's API), and those
translations carry no open licence of their own – an MIT file on a scrape
does not license someone else's translation. Every English meaning and
virtue below (MADAR_EN, IPRO_EN, MADAR_VIRTUE_EN and the specs' `en`) was
written for Madar from the Arabic. English references are the datasets'
bibliographic citations (book, volume, page, hadith number – facts).
"""
import argparse
import difflib
import json
import os
import re
import sys
import unicodedata

# --------------------------------------------------------------- characters --
TATWEEL = 'ـ'
FATHATAN, DAMMATAN, KASRATAN = 'ً', 'ٌ', 'ٍ'
FATHA, DAMMA, KASRA, SHADDA, SUKUN = 'َ', 'ُ', 'ِ', 'ّ', 'ْ'
HARAKAT = set('ًٌٍَُِّْٰٕٓٔ')
ALEF = 'ا'
ALEF_MAQSURA = 'ى'


def nfc(s):
    return unicodedata.normalize('NFC', s)


def is_mark(c):
    return c in HARAKAT


def normalize_arabic(s):
    """Mechanical clean-up of a dhikr text (not used on Quran verses)."""
    s = unicodedata.normalize('NFC', s)
    s = s.replace(TATWEEL, '')
    s = s.replace('‏', '').replace('‎', '').replace(' ', ' ')
    # Brackets of the printed book (( … )), [ … ] and footnote asterisks:
    # a dhikr text never contains parentheses.
    for ch in '()[]*':
        s = s.replace(ch, '')
    s = s.strip()
    # Tanween fath typed after the alif / alif maqsura → before it
    # (رَبَّاً → رَبًّا, دِيناً → دِينًا, هُدىً → هُدًى); a fatha already on
    # that letter gives way to the tanween.
    s = move_tanween(s)
    # Vowels typed on a bare alif belong to the letter before it
    # (لاَ → لَا, إِلاَّ → إِلَّا, السَّلاَمُ → السَّلَامُ).
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == ALEF and i + 1 < len(s) and s[i + 1] in (FATHA, SHADDA):
            j = i + 1
            marks = ''
            while j < len(s) and is_mark(s[j]):
                marks += s[j]
                j += 1
            # Previous base letter and its marks.
            k = len(out)
            while k > 0 and is_mark(out[k - 1]):
                k -= 1
            prev_marks = ''.join(out[k:])
            if k > 0 and prev_marks == '':
                out.extend(marks)
                out.append(ALEF)
            elif set(marks) <= set(prev_marks):
                out.append(ALEF)  # duplicate marks – drop them
            else:
                out.append(ALEF)
                out.extend(marks)
                print('WARN: unresolved marks on alif in', s[max(0, i - 8):i + 8], file=sys.stderr)
            i = j
            continue
        out.append(c)
        i += 1
    s = nfc(''.join(out))
    # "للَّه" at the start of a word is "لِلَّه" (lillāh).
    s = re.sub(r'(^|[\s،,])' + nfc('للَّه'),
               lambda m: m.group(1) + nfc('لِلَّه'), s)
    # «إلَّا» typed without the kasra under the hamza.
    s = s.replace(nfc('إلَّا'), nfc('إِلَّا'))
    # Sukun on the lam of the definite article before a "moon" letter when
    # the source left it bare (الغَيْبِ → الْغَيْبِ, الأَرْضِ → الْأَرْضِ).
    s = re.sub('(?<![ء-ْ])((?:[وفب][َِ])?)ال'
               '(?=[ءأإآبغحجكخفعقيمهو])',
               lambda m: m.group(1) + 'ال' + SUKUN, s)
    s = re.sub(r'\s+', ' ', s)
    s = re.sub(r'\s+([،,.:؛])', r'\1', s)
    s = s.strip().rstrip('.').strip()
    return unicodedata.normalize('NFC', s)


def move_tanween(s):
    s = re.sub('([' + ALEF + ALEF_MAQSURA + '])' + FATHATAN, FATHATAN + r'\1', s)
    return re.sub('([\u064b-\u0652]*)' + FATHATAN,
                  lambda m: m.group(1).replace(FATHA, '').replace(FATHATAN, '') + FATHATAN, s)


def clean_latin(s):
    s = unicodedata.normalize('NFC', s or '').replace('\u00a0', ' ')
    s = s.replace('\u2019', "'").replace("it's", 'its').replace('Allaah', 'Allah')
    s = s.replace('Moosa u', 'Moses').replace('Easa u', 'Jesus')
    return re.sub(r'\s+', ' ', s).strip()


def light_arabic(s):
    """Notes, virtues and references: NFC, no tatweel, tanween before alif."""
    return nfc(move_tanween(nfc(s).replace(TATWEEL, '')))


def clean_ref_ar(s):
    s = unicodedata.normalize('NFC', s or '')
    s = s.replace('‘', 'رحمه الله')  # a symbol-font glyph for «رحمه الله» in the source
    s = s.lstrip('، ,').strip()
    s = re.sub(r'\s+', ' ', s)
    s = s.replace(' ،', '،').replace('،،', '،').replace('، ،', '،').replace(',.', '.').replace('،.', '.')
    return s.strip()


def skeleton(s):
    """Letters only (no marks, unified alef/hamza/ya forms) for comparisons."""
    s = unicodedata.normalize('NFC', s)
    s = ''.join(c for c in s if not is_mark(c) and c != TATWEEL)
    for a, b in (('أ', 'ا'), ('إ', 'ا'), ('آ', 'ا'), ('ٱ', 'ا'), ('ى', 'ي'), ('ؤ', 'ء'), ('ئ', 'ء'), ('ة', 'ه')):
        s = s.replace(a, b)
    s = re.sub('[^ء-ي ]', ' ', s)
    return ' '.join(s.split())


def words(s):
    return skeleton(s).split()


# ---------------------------------------------------------------- loading --
def load_sources(src):
    j = lambda *p: json.load(open(os.path.join(src, *p), encoding='utf-8'))
    seen_ar = {x['order']: x for x in j('Seen-Arabic_Morning-And-Evening-Adhkar-DB', 'ar.json')}
    seen_en = {x['order']: x for x in j('Seen-Arabic_Morning-And-Evening-Adhkar-DB', 'en.json')}
    ipro_ar = {c['id']: c for c in j('YousefAsalya_Islamic-Pro-azkar-API', 'data', 'ar.json')}
    spelled = {(v['chapter'], v['verse']): v['text'] for v in j('quran', 'ara-quranspelled.json')['quran']}
    simple = {(v['chapter'], v['verse']): v['text'] for v in j('quran', 'ara-quransimple.json')['quran']}
    rn0x = j('rn0x_hisn_almuslim_json', 'hisn_almuslim.json')
    fitra = {}
    for cat in ('morning-dhikr', 'evening-dhikr', 'dhikr-after-salah', 'daily-dua'):
        fitra[cat] = j('fitrahive_dua-dhikr', 'data', 'dua-dhikr', cat, 'en.json')
    osamayy = j('osamayy_azkar-db', 'azkar.json')['rows']
    return dict(seen_ar=seen_ar, seen_en=seen_en, ipro_ar=ipro_ar, spelled=spelled,
                simple=simple, rn0x=rn0x, fitra=fitra, osamayy=osamayy)


# ------------------------------------------------------------- curation ----
BASMALA = 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ'
ISTIADHA = 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ'


def q(surah, first, last=None):
    return {'quran': (surah, first, last or first)}


MUAWWIDHAT = [BASMALA, q(112, 1, 4), BASMALA, q(113, 1, 5), BASMALA, q(114, 1, 6)]

# Explicit text fixes on the primary sources (old → new), per item.
SEEN_FIXES = {
    7: [('الْملْكُ', 'الْمُلْكُ'), ('وَخَيرَ', 'وَخَيْرَ')],
    11: [('الذُّنوبَ', 'الذُّنُوبَ')],
    17: [('عَلَيهِ تَوَكَّلتُ', 'عَلَيْهِ تَوَكَّلْتُ')],
    18: [('بَينِ', 'بَيْنِ')],
    19: [('وَشَرَكِهِ', 'وَشِرْكِهِ'), ('الشَّيْطانِ', 'الشَّيْطَانِ')],
    20: [('السّمَاءِ', 'السَّمَاءِ')],
    22: [('أَسْتَغيثُ', 'أَسْتَغِيثُ')],
    23: [('وَنورَهُ', 'وَنُورَهُ')],
    25: [('أَصْبَحْنا', 'أَصْبَحْنَا'), ('الْمُشرِكِينَ', 'الْمُشْرِكِينَ')],
    29: [('نَبَيِّنَا', 'نَبِيِّنَا')],
}

# Evening wordings the source typed without (or with broken) vowels, rebuilt
# from the vowelled morning wording of the same hadith (Muslim 2723, al-
# Tirmidhi 3391, Abu Dawud 5069/5073/5084, Ahmad 15360) – only the morning
# verbs/nouns change to their evening counterparts.
SEEN_REWRITES = {
    8: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، '
       'لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ '
       'وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا، رَبِّ أَعُوذُ بِكَ مِنَ '
       'الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ',
    10: 'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ',
    13: 'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ '
        'أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ',
    15: 'اللَّهُمَّ مَا أَمْسَى بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ '
        'الْحَمْدُ وَلَكَ الشُّكْرُ',
    24: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ رَبِّ الْعَالَمِينَ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذِهِ اللَّيْلَةِ: '
        'فَتْحَهَا، وَنَصْرَهَا، وَنُورَهَا، وَبَرَكَتَهَا، وَهُدَاهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِيهَا وَشَرِّ مَا بَعْدَهَا',
    26: 'أَمْسَيْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ ﷺ، '
        'وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ، حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ',
}

# English meanings of the Seen-Arabic items, written for Madar from the
# Arabic (the dataset's English is not used – see the module docstring).
_TAHLIL_EN = ('There is no god but Allah alone, with no partner. His is the dominion and His is the praise, '
              'and He has power over all things.')
_ALM_NAFI_EN = 'O Allah, I ask You for knowledge that benefits, provision that is wholesome, and deeds that are accepted.'
_ALIM_GHAYB_EN = ('O Allah, Knower of the unseen and the seen, Originator of the heavens and the earth, Lord and '
                  'Sovereign of all things: I bear witness that there is no god but You. I seek Your protection '
                  'from the evil of my own self, from the evil of Satan and his call to associate partners with '
                  'You, and from bringing wrong upon myself or drawing it upon a Muslim.')
MADAR_EN = {
    7: ('Morning has come to us, and to Allah the whole dominion has come with it. Praise be to Allah. There is '
        'no god but Allah alone, with no partner; His is the dominion and His is the praise, and He has power '
        'over all things. My Lord, I ask You for the good of this day and the good of what comes after it, and '
        'I seek Your protection from the evil of this day and the evil of what comes after it. My Lord, I seek '
        'Your protection from laziness and the miseries of old age. My Lord, I seek Your protection from '
        'punishment in the Fire and punishment in the grave.'),
    8: ('Evening has come to us, and to Allah the whole dominion has come with it. Praise be to Allah. There is '
        'no god but Allah alone, with no partner; His is the dominion and His is the praise, and He has power '
        'over all things. My Lord, I ask You for the good of this night and the good of what comes after it, '
        'and I seek Your protection from the evil of this night and the evil of what comes after it. My Lord, '
        'I seek Your protection from laziness and the miseries of old age. My Lord, I seek Your protection '
        'from punishment in the Fire and punishment in the grave.'),
    9: ('O Allah, by You we have come to the morning and by You we come to the evening; by You we live and by '
        'You we die, and to You is the rising again.'),
    10: ('O Allah, by You we have come to the evening and by You we come to the morning; by You we live and by '
         'You we die, and to You is the final return.'),
    11: ('O Allah, You are my Lord; there is no god but You. You created me and I am Your servant, and I keep '
         'to Your covenant and Your promise as far as I am able. I seek Your protection from the evil of what '
         'I have done. I acknowledge before You Your favour upon me, and I acknowledge my sin, so forgive me, '
         'for none forgives sins but You.'),
    12: ('O Allah, this morning I call You to witness, and I call the bearers of Your Throne, Your angels and '
         'all Your creation to witness, that You are Allah – there is no god but You, alone, with no partner – '
         'and that Muhammad is Your servant and Your Messenger.'),
    13: ('O Allah, this evening I call You to witness, and I call the bearers of Your Throne, Your angels and '
         'all Your creation to witness, that You are Allah – there is no god but You, alone, with no partner – '
         'and that Muhammad is Your servant and Your Messenger.'),
    14: ('O Allah, whatever blessing has come to me or to any of Your creation this morning is from You alone, '
         'with no partner; so Yours is the praise and Yours is the thanks.'),
    15: ('O Allah, whatever blessing has come to me or to any of Your creation this evening is from You alone, '
         'with no partner; so Yours is the praise and Yours is the thanks.'),
    16: ('O Allah, keep my body well. O Allah, keep my hearing well. O Allah, keep my sight well. There is no '
         'god but You. O Allah, I seek Your protection from disbelief and from poverty, and I seek Your '
         'protection from the punishment of the grave. There is no god but You.'),
    17: 'Allah is enough for me; there is no god but Him. In Him I have put my trust, and He is the Lord of the mighty Throne.',
    18: ('O Allah, I ask You for pardon and well-being in this world and the Hereafter. O Allah, I ask You for '
         'pardon and well-being in my religion and my worldly life, my family and my wealth. O Allah, cover my '
         'faults and calm my fears. O Allah, guard me from in front of me and from behind me, from my right '
         'and from my left, and from above me; and I seek refuge in Your greatness from being struck down from '
         'beneath me.'),
    19: _ALIM_GHAYB_EN,
    20: ('In the name of Allah, with whose name nothing on earth or in the heavens can cause harm, and He is '
         'the All-Hearing, the All-Knowing.'),
    21: 'I am content with Allah as my Lord, with Islam as my religion, and with Muhammad ﷺ as my Prophet.',
    22: ('O Ever-Living, O Sustainer of all, in Your mercy I seek relief: set right all my affairs for me, and '
         'do not leave me to myself even for the blink of an eye.'),
    23: ('Morning has come to us, and to Allah, Lord of the worlds, the whole dominion has come with it. O '
         'Allah, I ask You for the good of this day – its openings, its help, its light, its blessing and its '
         'guidance – and I seek Your protection from the evil that is in it and the evil of what comes after it.'),
    24: ('Evening has come to us, and to Allah, Lord of the worlds, the whole dominion has come with it. O '
         'Allah, I ask You for the good of this night – its openings, its help, its light, its blessing and its '
         'guidance – and I seek Your protection from the evil that is in it and the evil of what comes after it.'),
    25: ('We have come to the morning upon the natural way of Islam, upon the word of sincere devotion, upon '
         'the religion of our Prophet Muhammad ﷺ, and upon the way of our father Ibrahim, who was upright and '
         'a Muslim, and was not one of those who associate partners with Allah.'),
    26: ('We have come to the evening upon the natural way of Islam, upon the word of sincere devotion, upon '
         'the religion of our Prophet Muhammad ﷺ, and upon the way of our father Ibrahim, who was upright and '
         'a Muslim, and was not one of those who associate partners with Allah.'),
    27: _ALM_NAFI_EN,
    28: _TAHLIL_EN,
    29: 'O Allah, send Your blessings and peace upon our Prophet Muhammad.',
    30: 'I seek refuge in the perfect words of Allah from the evil of what He has created.',
    31: ('Glory be to Allah and praise be to Him – as many times as the number of His creation, as much as '
         'pleases Him, as heavy as the weight of His Throne, and as much as the ink of His words.'),
    32: _TAHLIL_EN,
    33: 'I ask Allah\'s forgiveness and I turn to Him in repentance.',
    34: 'Glory be to Allah, and praise be to Him.',
}

# English virtues, written for Madar from the Arabic virtue of each item.
MADAR_VIRTUE_EN = {
    2: ('Whoever says it in the morning is kept safe from the jinn until evening, and whoever says it in the '
        'evening is kept safe from them until morning.'),
    3: 'Whoever recites the last two verses of Surat al-Baqarah at night, they will suffice him.',
    4: 'Said three times in the morning and in the evening, they suffice you against everything.',
    5: 'Said three times in the morning and in the evening, they suffice you against everything.',
    6: 'Said three times in the morning and in the evening, they suffice you against everything.',
    11: ('Whoever says it during the day with certainty and dies that day before evening is among the people '
         'of Paradise; and whoever says it at night with certainty and dies before morning is among the people '
         'of Paradise.'),
    12: 'Whoever says it four times in the morning or in the evening, Allah frees him from the Fire.',
    13: 'Whoever says it four times in the morning or in the evening, Allah frees him from the Fire.',
    14: ('Whoever says it in the morning has given the thanks due for his day, and whoever says it in the '
         'evening has given the thanks due for his night.'),
    15: ('Whoever says it in the morning has given the thanks due for his day, and whoever says it in the '
         'evening has given the thanks due for his night.'),
    17: ('Whoever says it seven times in the morning and in the evening, Allah will suffice him in whatever '
         'concerns him of this world and the Hereafter.'),
    20: 'Whoever says it three times in the morning and three times in the evening, nothing will harm him.',
    21: ('Whoever says it three times in the morning and three times in the evening, it is a right upon Allah '
         'to please him on the Day of Resurrection.'),
    28: ('Ten times, or once when feeling lazy. Whoever says it ten times is like one who has freed four souls '
         'from the children of Isma\'il.'),
    29: ('Whoever sends blessings upon the Prophet ten times in the morning and ten times in the evening will '
         'receive his intercession on the Day of Resurrection.'),
    30: 'Whoever says it three times in the evening, no venomous sting will harm him that night.',
    32: ('Whoever says it a hundred times in a day has the reward of freeing ten slaves; a hundred good deeds '
         'are written for him and a hundred bad deeds are erased, it shields him from Satan that day until '
         'evening, and no one brings anything better except one who did more.'),
    34: ('Whoever says it a hundred times in the morning and in the evening, no one will come on the Day of '
         'Resurrection with anything better, except one who said the same or more.'),
}

# Source-field clean-ups for the Seen-Arabic references.
SEEN_REF_CUT = {32: '\n'}  # item 32's reference had item 28's text appended

# Seen items whose text is Quran: the segments replace the source text.
SEEN_QURAN = {
    2: [ISTIADHA, q(2, 255)],
    3: [ISTIADHA, q(2, 285, 286)],
    4: [BASMALA, q(112, 1, 4)],
    5: [BASMALA, q(113, 1, 5)],
    6: [BASMALA, q(114, 1, 6)],
}

# Seen morning (type 0/1) and evening (type 0/2) sets in the dataset's
# order; #1 is the book's chapter opening (a praise, not a counted dhikr).
MORNING = [2, 4, 5, 6, 7, 9, 11, 12, 14, 16, 17, 18, 19, 20, 21, 22, 23, 25, 27, 28, 29, 31, 32, 33, 34]
EVENING = [2, 3, 4, 5, 6, 8, 10, 11, 13, 15, 16, 17, 18, 19, 20, 21, 22, 24, 26, 28, 29, 30, 34]

SEEN_NOTES = {
    28: ('أو مرة واحدة عند الكسل', 'Or once when feeling lazy'),
    32: ('مئة مرة إذا أصبح', 'One hundred times in the morning'),
    33: ('مئة مرة في اليوم', 'One hundred times a day'),
}

# Virtue prefixes the source used to name the surah (the app shows the
# surah and ayah numbers from the Quran segments instead).
VIRTUE_PREFIX = [
    r'^\[سورة البقرة، الآية: 255\]\s*',
    r"^\(Ayat al-Kursi; Al-Qur'an 2:255\)\s*",
    r'^Al-Baqarah 2:285-6\.\s*',
    r'^Al-Ikhlas 112:1-4, Al-Falaq 113:1-5, An-Nas 114:1-6\.\s*',
]


def strip_virtue(s):
    for p in VIRTUE_PREFIX:
        s = re.sub(p, '', s)
    return s.strip()


def seen_item(src, order, set_id, n):
    ar, en = src['seen_ar'][order], src['seen_en'][order]
    if order in SEEN_QURAN:
        segments = SEEN_QURAN[order]
        translation = None  # Quran translations are not bundled (see credits)
    else:
        text = nfc(SEEN_REWRITES.get(order) or ar['content'])
        for old, new in SEEN_FIXES.get(order, []):
            old, new = nfc(old), nfc(new)
            assert old in text, (order, old)
            text = text.replace(old, new)
        segments = [text]
        translation = MADAR_EN[order]  # never the dataset's English (see docstring)
    ref_ar = ar['source']
    ref_en = en['source']
    if order in SEEN_REF_CUT:
        ref_ar = ref_ar.split(SEEN_REF_CUT[order])[0]
        ref_en = ref_en.split(' Ten times:')[0]
    item = {
        'id': f'{set_id}.{n:02d}',
        'segments': segments,
        'count': int(ar['count']),
        'reference': {'ar': clean_ref_ar(ref_ar), 'en': clean_latin(ref_en)},
        'origin': f'seen-arabic#{order}',
    }
    va = strip_virtue(ar.get('fadl') or '')
    if va:
        item['virtue'] = {'ar': clean_ref_ar(va).rstrip('.') + '.', 'en': MADAR_VIRTUE_EN[order]}
    if order in SEEN_NOTES:
        a, e = SEEN_NOTES[order]
        item['note'] = {'ar': a, 'en': e}
    if translation:
        item['translation'] = {'en': translation}
    return item


# Hisn al-Muslim chapters from the Islamic-Pro dataset, curated item by item.
# `text` is the dataset's Arabic after the listed `fix`es unless `segments`
# is given; English is Madar's (`en`, else IPRO_EN – never the dataset's).
# References are written out per hadith (standard numbering).
def ipro(ch, idx):
    return ('ipro', ch, idx)


# English meanings of the Islamic-Pro items, written for Madar from the
# Arabic (the dataset's English is not used – see the module docstring).
IPRO_EN = {
    (1, 1): 'Praise be to Allah, who gave us life after He had caused us to die, and to Him is the rising again.',
    (1, 2): ('There is no god but Allah alone, with no partner. His is the dominion and His is the praise, and He '
             'has power over all things. Glory be to Allah, praise be to Allah, there is no god but Allah, and '
             'Allah is the Greatest; there is no might and no power except by Allah, the Most High, the Most '
             'Great. My Lord, forgive me.'),
    (1, 3): 'Praise be to Allah, who kept my body well, returned my soul to me and allowed me to remember Him.',
    (28, 4): ('In Your name, my Lord, I lay down my side, and by You I raise it. If You take my soul, have mercy '
              'on it; and if You send it back, protect it as You protect Your righteous servants.'),
    (28, 5): ('O Allah, You created my soul and You take it back; its death and its life belong to You. If You '
              'keep it alive, protect it; and if You cause it to die, forgive it. O Allah, I ask You for '
              'well-being.'),
    (28, 6): 'O Allah, shield me from Your punishment on the Day You raise up Your servants.',
    (28, 7): 'In Your name, O Allah, I die and I live.',
    (28, 9): ('O Allah, Lord of the seven heavens and Lord of the earth, Lord of the mighty Throne, our Lord and '
              'Lord of all things, who splits the grain and the date-stone, who sent down the Torah, the Gospel '
              'and the Criterion: I seek Your protection from the evil of everything whose forelock You hold. O '
              'Allah, You are the First, and there is nothing before You; You are the Last, and there is nothing '
              'after You; You are the Manifest, and there is nothing above You; You are the Hidden, and there is '
              'nothing beyond You. Settle our debts for us and free us from poverty.'),
    (28, 10): ('Praise be to Allah, who has fed us and given us drink, who has sufficed us and sheltered us – for '
               'how many are there with no one to suffice them and no one to shelter them.'),
    (28, 11): _ALIM_GHAYB_EN,
    (28, 13): ('O Allah, I have surrendered myself to You, entrusted my affairs to You, turned my face to You and '
               'leaned my back on You, in hope of You and in awe of You. There is no refuge and no escape from '
               'You except in You. I believe in Your Book which You sent down, and in Your Prophet whom You '
               'sent.'),
    (25, 2): ('There is no god but Allah alone, with no partner. His is the dominion and His is the praise, and '
              'He has power over all things. O Allah, none can withhold what You give, and none can give what '
              'You withhold, and the wealth of the wealthy avails him nothing against You.'),
    (25, 3): ('There is no god but Allah alone, with no partner. His is the dominion and His is the praise, and '
              'He has power over all things. There is no might and no power except by Allah. There is no god but '
              'Allah, and we worship none but Him. His is all blessing, His is all grace, and His is the most '
              'beautiful praise. There is no god but Allah; to Him we devote our religion sincerely, even though '
              'the disbelievers dislike it.'),
    (25, 7): ('There is no god but Allah alone, with no partner. His is the dominion and His is the praise; He '
              'gives life and causes death, and He has power over all things.'),
    (25, 8): _ALM_NAFI_EN,
}

WAKING = [
    dict(src=ipro(1, 1),
         ref=('البخاري (6312)، ومسلم (2711).', 'Al-Bukhari (6312) and Muslim (2711).')),
    dict(src=ipro(1, 2), fix=[('شَريكَ', 'شَرِيكَ'), ('أَكبَرُ', 'أَكْبَرُ'), ('اغْفرْ', 'اغْفِرْ')],
         virtue=('من قالها إذا استيقظ من الليل ثم دعا استُجيب له، فإن توضأ وصلّى قُبلت صلاته.',
                 'Whoever wakes at night and says this, then asks Allah, is answered; and if he then '
                 'performs ablution and prays, his prayer is accepted.'),
         ref=('البخاري (1154)، واللفظ لابن ماجه (3878)، وانظر: صحيح ابن ماجه 2/335.',
              'Al-Bukhari (1154); this wording is Ibn Majah\'s (3878). See Sahih Ibn Majah 2/335.')),
    dict(src=ipro(1, 3), fix=[('لي بِذِكْرِهِ', 'لِي بِذِكْرِهِ')],
         ref=('الترمذي (3401)، وانظر: صحيح الترمذي 3/144.', 'At-Tirmidhi (3401). See Sahih At-Tirmidhi 3/144.')),
    dict(src=ipro(1, 4), segments=[q(3, 190, 200)],
         note=('الآيات من آخر سورة آل عمران', 'The closing verses of Surat Al Imran'),
         ref=('البخاري (4569)، ومسلم (763).', 'Al-Bukhari (4569) and Muslim (763).')),
]

SLEEP = [
    dict(src=ipro(28, 1), segments=MUAWWIDHAT, count=3,
         note=('اجمع كفّيك وانفث فيهما واقرأ السور الثلاث، ثم امسح بهما ما استطعت من جسدك، '
               'تبدأ برأسك ووجهك وما أقبل من جسدك.',
               'Cup your palms, blow gently into them and recite the three surahs, then wipe as much of '
               'your body as you can, starting with your head, your face and the front of your body.'),
         ref=('البخاري (5017)، ومسلم (2192).', 'Al-Bukhari (5017) and Muslim (2192).')),
    dict(src=ipro(28, 2), segments=[q(2, 255)],
         virtue=('من قرأها إذا أوى إلى فراشه لم يزل عليه من الله حافظ، ولا يقربه شيطان حتى يصبح.',
                 'Whoever recites it on going to bed remains under a guardian from Allah, and no devil '
                 'comes near him until morning.'),
         ref=('البخاري (2311).', 'Al-Bukhari (2311).')),
    dict(src=ipro(28, 3), segments=[q(2, 285, 286)],
         virtue=('من قرأ الآيتين من آخر سورة البقرة في ليلة كفتاه.',
                 'Whoever recites the last two verses of Surat al-Baqarah at night, they will suffice him.'),
         ref=('البخاري (5009)، ومسلم (807).', 'Al-Bukhari (5009) and Muslim (807).')),
    dict(src=ipro(28, 4), fix=[('فَإِن أَمْسَكْتَ', 'فَإِنْ أَمْسَكْتَ'), ('فارْحَمْهَا', 'فَارْحَمْهَا')],
         note=('انفض فراشك ثلاثًا قبل أن تضطجع، ثم قل', 'Dust off your bed three times before lying down, then say'),
         ref=('البخاري (6320)، ومسلم (2714).', 'Al-Bukhari (6320) and Muslim (2714).')),
    dict(src=ipro(28, 5), fix=[('وَمَحْياهَا', 'وَمَحْيَاهَا'), ('العَافِيَةَ', 'الْعَافِيَةَ'), ('لَهَا. اللَّهُمَّ', 'لَهَا، اللَّهُمَّ')],
         ref=('مسلم (2712).', 'Muslim (2712).')),
    dict(src=ipro(28, 6), count=3,
         note=('كان النبي ﷺ إذا أراد أن يرقد وضع يده اليمنى تحت خده ثم قالها ثلاثًا',
               'When the Prophet ﷺ wanted to sleep he placed his right hand under his cheek and said it '
               'three times'),
         ref=('أبو داود (5045)، وانظر: صحيح الترمذي 3/143.', 'Abu Dawud (5045). See Sahih At-Tirmidhi 3/143.')),
    dict(src=ipro(28, 7), ref=('البخاري (6312)، ومسلم (2711).', 'Al-Bukhari (6312) and Muslim (2711).')),
    # Split: 33 + 33 + 34, one counter each.
    dict(src=ipro(28, 8), segments=['سُبْحَانَ اللَّهِ'], count=33, en='Glory be to Allah.',
         virtue=('من قالها عندما يأوي إلى فراشه كان خيرًا له من خادم.',
                 'Saying these when going to bed is better for one than a servant.'),
         ref=('البخاري (3705)، ومسلم (2727).', 'Al-Bukhari (3705) and Muslim (2727).')),
    dict(src=ipro(28, 8), segments=['الْحَمْدُ لِلَّهِ'], count=33, en='Praise be to Allah.',
         ref=('البخاري (3705)، ومسلم (2727).', 'Al-Bukhari (3705) and Muslim (2727).')),
    dict(src=ipro(28, 8), segments=['اللَّهُ أَكْبَرُ'], count=34, en='Allah is the Greatest.',
         ref=('البخاري (3705)، ومسلم (2727).', 'Al-Bukhari (3705) and Muslim (2727).')),
    dict(src=ipro(28, 9), fix=[('فَلَيسَ', 'فَلَيْسَ')],
         ref=('مسلم (2713).', 'Muslim (2713).')),
    dict(src=ipro(28, 10), ref=('مسلم (2715).', 'Muslim (2715).')),
    dict(src=ipro(28, 11), fix=[('الشَّيْطانِ', 'الشَّيْطَانِ')],
         ref=('أبو داود (5067)، والترمذي (3392).', 'Abu Dawud (5067) and At-Tirmidhi (3392).')),
    dict(src=ipro(28, 12), kind='reading', segments=['سُورَةُ السَّجْدَةِ، وَسُورَةُ الْمُلْكِ'],
         en='Surat as-Sajdah and Surat al-Mulk.',
         note=('كان النبي ﷺ لا ينام حتى يقرأ سورتي السجدة والملك',
               'The Prophet ﷺ would not sleep until he had recited Surat as-Sajdah and Surat al-Mulk'),
         ref=('الترمذي (2892)، والنسائي في عمل اليوم والليلة (707)، وانظر: صحيح الجامع 4/255.',
              "At-Tirmidhi (2892) and An-Nasa'i in 'Amal al-Yawm wal-Laylah (707). See Sahih al-Jami' 4/255.")),
    dict(src=ipro(28, 13),
         note=('توضأ وضوءك للصلاة، ثم اضطجع على شقك الأيمن، واجعلها آخر ما تقول',
               'Perform ablution as for prayer, lie on your right side, and make these your last words'),
         virtue=('فإن مِتَّ من ليلتك مِتَّ على الفطرة.', 'If you die that night, you die upon the fitrah.'),
         ref=('البخاري (6313)، ومسلم (2710).', 'Al-Bukhari (6313) and Muslim (2710).')),
]

AFTER_PRAYER = [
    dict(src=ipro(25, 1), segments=['أَسْتَغْفِرُ اللَّهَ'], count=3, en='I ask Allah\'s forgiveness.',
         ref=('مسلم (591).', 'Muslim (591).')),
    dict(src=ipro(25, 1),
         segments=['اللَّهُمَّ أَنْتَ السَّلَامُ، وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ'],
         en='O Allah, You are Peace, and from You comes peace. Blessed are You, O Possessor of majesty and honour.',
         ref=('مسلم (591).', 'Muslim (591).')),
    # The hisnmuslim.com typing adds «[ثلاثاً]» after the first sentence; the
    # older edition (rn0x) and the hadith (al-Bukhari 844) have it once.
    dict(src=ipro(25, 2), fix=[(' [ثلاثاً]', '')],
         ref=('البخاري (844)، ومسلم (593).', 'Al-Bukhari (844) and Muslim (593).')),
    dict(src=ipro(25, 3), fix=[('الْحَمدُ', 'الْحَمْدُ'), ('قَدِيرٌ. لاَ حَوْلَ', 'قَدِيرٌ، لاَ حَوْلَ'), (',', '،'), ('الكَافِرُونَ', 'الْكَافِرُونَ')],
         ref=('مسلم (594).', 'Muslim (594).')),
    dict(src=ipro(25, 4), segments=['سُبْحَانَ اللَّهِ'], count=33, en='Glory be to Allah.',
         virtue=('من قالها دبر كل صلاة غُفرت خطاياه وإن كانت مثل زبد البحر.',
                 'Whoever says these after every prayer has his sins forgiven, even if they are like the foam '
                 'of the sea.'),
         ref=('مسلم (597).', 'Muslim (597).')),
    dict(src=ipro(25, 4), segments=['الْحَمْدُ لِلَّهِ'], count=33, en='Praise be to Allah.',
         ref=('مسلم (597).', 'Muslim (597).')),
    dict(src=ipro(25, 4), segments=['اللَّهُ أَكْبَرُ'], count=33, en='Allah is the Greatest.',
         ref=('مسلم (597).', 'Muslim (597).')),
    dict(src=ipro(25, 4),
         segments=['لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ'],
         en=_TAHLIL_EN,
         note=('تمام المئة', 'Completing the hundred'),
         ref=('مسلم (597).', 'Muslim (597).')),
    dict(src=ipro(25, 5), segments=MUAWWIDHAT, count=1, count_after={'fajr': 3, 'maghrib': 3},
         note=('مرة بعد كل صلاة، وثلاث مرات بعد صلاتي الفجر والمغرب',
               'Once after every prayer, and three times after Fajr and Maghrib'),
         ref=('أبو داود (1523)، والنسائي (1336)، وانظر: صحيح الترمذي 2/8.',
              "Abu Dawud (1523) and An-Nasa'i (1336). See Sahih At-Tirmidhi 2/8.")),
    dict(src=ipro(25, 6), segments=[q(2, 255)],
         virtue=('من قرأها دبر كل صلاة لم يمنعه من دخول الجنة إلا أن يموت.',
                 'Whoever recites it after every prayer, nothing stands between him and Paradise but death.'),
         ref=('النسائي في عمل اليوم والليلة (100)، وابن السني (121)، وصححه الألباني في السلسلة الصحيحة (972).',
              "An-Nasa'i in 'Amal al-Yawm wal-Laylah (100) and Ibn as-Sunni (121); graded authentic by "
              'al-Albani in as-Silsilah as-Sahihah (972).')),
    dict(src=ipro(25, 7), fix=[(' عَشْرَ مَرّاتٍ بَعْدَ صَلاةِ الْمَغْرِبِ وَالصُّبْحِ', ''), ('الْحَمْدُ يُحْيِي', 'الْحَمْدُ، يُحْيِي'), ('وَيُمِيتُ وَهُوَ', 'وَيُمِيتُ، وَهُوَ')],
         count=10, only_after=['fajr', 'maghrib'],
         note=('عشر مرات بعد صلاتي المغرب والفجر', 'Ten times after Maghrib and Fajr'),
         ref=('الترمذي (3474)، وأحمد (4/227).', 'At-Tirmidhi (3474) and Ahmad (4/227).')),
    dict(src=ipro(25, 8), fix=[(' بَعْدَ السّلامِ مِنْ صَلاَةِ الفَجْرِ', ''), ('نافِعاً', 'نَافِعاً')],
         only_after=['fajr'],
         note=('بعد السلام من صلاة الفجر', 'After the salam of the Fajr prayer'),
         ref=('ابن ماجه (925)، وانظر: صحيح ابن ماجه 1/152.', 'Ibn Majah (925). See Sahih Ibn Majah 1/152.')),
]


def ipro_item(src, spec, set_id, n):
    _, ch, idx = spec['src']
    ar = src['ipro_ar'][ch]['array'][idx - 1]
    if 'segments' in spec:
        segments = spec['segments']
    else:
        text = nfc(ar['text'])
        for old, new in spec.get('fix', []):
            old, new = nfc(old), nfc(new)
            assert old in text, (spec['src'], old)
            text = text.replace(old, new)
        segments = [text]
    is_quran = all(isinstance(s, dict) or s in (BASMALA, ISTIADHA) for s in segments)
    # Madar's English only (never the dataset's – see the module docstring);
    # none for Quran-only entries (no Quran translation is bundled).
    translation = None if is_quran else spec.get('en') or IPRO_EN[(ch, idx)]
    item = {
        'id': f'{set_id}.{n:02d}',
        'segments': segments,
        'count': int(spec.get('count', 1)),
        'reference': {'ar': spec['ref'][0], 'en': spec['ref'][1]},
        'origin': f'islamic-pro-azkar#{ch}.{idx}',
    }
    if 'kind' in spec:
        item['kind'] = spec['kind']
    if 'count_after' in spec:
        item['countAfter'] = spec['count_after']
    if 'only_after' in spec:
        item['onlyAfter'] = spec['only_after']
    if 'note' in spec:
        item['note'] = {'ar': spec['note'][0], 'en': spec['note'][1]}
    if 'virtue' in spec:
        item['virtue'] = {'ar': spec['virtue'][0], 'en': spec['virtue'][1]}
    if translation:
        item['translation'] = {'en': translation}
    return item


# ----------------------------------------------------------- finalising ----
def finalize_segments(src, segments):
    out = []
    for s in segments:
        if isinstance(s, dict):
            surah, a, b = s['quran']
            verses = [unicodedata.normalize('NFC', src['spelled'][(surah, v)]) for v in range(a, b + 1)]
            out.append({'surah': surah, 'ayahs': [a, b], 'verses': verses})
        else:
            out.append({'text': normalize_arabic(s)})
    return out


def check_quran_reference(src, log):
    """Cross-check every referenced verse: quranspelled vs quransimple."""
    bad = 0
    keys = set()
    for spec_list in (SEEN_QURAN.values(),):
        for segs in spec_list:
            for s in segs:
                if isinstance(s, dict):
                    su, a, b = s['quran']
                    keys.update((su, v) for v in range(a, b + 1))
    for spec in WAKING + SLEEP + AFTER_PRAYER:
        for s in spec.get('segments', []):
            if isinstance(s, dict):
                su, a, b = s['quran']
                keys.update((su, v) for v in range(a, b + 1))
    for k in sorted(keys):
        a = words(src['spelled'][k])
        b = words(src['simple'][k])
        # The alquran.cloud "quran-simple" text prefixes the basmala to the
        # first ayah of every surah but al-Fatiha and at-Tawbah.
        if k[1] == 1 and k[0] not in (1, 9) and b[:4] == words(BASMALA):
            b = b[4:]
        # Spelling differs slightly between the two editions (e.g. a hamza
        # seat); compare word counts and a letter skeleton without alifs.
        la = [w.replace('ا', '') for w in a]
        lb = [w.replace('ا', '') for w in b]
        if la != lb:
            bad += 1
            log.append(f'QURAN MISMATCH {k}: {" ".join(a)} || {" ".join(b)}')
    log.append(f'Quran reference cross-check: {len(keys)} verses, {bad} mismatches (quranspelled vs quransimple).')
    return keys, bad


def best_match(candidates, text):
    t = skeleton(text)
    best = (0.0, None)
    for c in candidates:
        r = difflib.SequenceMatcher(None, t, skeleton(c)).ratio()
        if r > best[0]:
            best = (r, c)
    return best


def verification(src, library, log):
    rn = src['rn0x']
    rn_sections = {
        'morning': rn.get('أذكار الصباح والمساء', {}).get('text', []),
        'evening': rn.get('أذكار الصباح والمساء', {}).get('text', []),
        'waking': rn.get('أذكار الاستيقاظ من النوم', {}).get('text', []),
        'sleep': rn.get('أذكار النوم', {}).get('text', []),
        'afterPrayer': rn.get('الأذكار بعد السلام من الصلاة', {}).get('text', []),
    }
    rn_all = [t for sec in rn.values() for t in sec.get('text', [])]
    fitra_ar = [x['arabic'] for cat in src['fitra'].values() for x in cat]
    checked = 0
    log.append('')
    log.append('Spot-check against independent sources (letter-skeleton similarity, 1.00 = identical):')
    for cat in library['categories']:
        for item in cat['items']:
            # The whole item, verses included (the older edition prints the
            # verses inline too).
            text = ' '.join(s['text'] if 'text' in s else ' '.join(s['verses']) for s in item['segments'])
            if item.get('kind') == 'reading':
                continue
            r1, m1 = best_match(rn_sections[cat['id']] + rn_all, text)
            r2, m2 = best_match(fitra_ar, text)
            best = max(r1, r2)
            checked += 1
            flag = 'OK ' if best >= 0.9 else ('~  ' if best >= 0.75 else '?? ')
            log.append(f'{flag}{item["id"]:16s} rn0x={r1:.2f} fitrahive={r2:.2f}  {skeleton(text)[:70]}')
            if best < 0.97:
                m = m1 if r1 >= r2 else m2
                sm = difflib.SequenceMatcher(None, words(text), words(m or ''))
                for op, a1, a2, b1, b2 in sm.get_opcodes():
                    if op != 'equal':
                        log.append(f'      {op}: [{" ".join(words(text)[a1:a2])}] vs [{" ".join(words(m or "")[b1:b2])}]')
    log.append(f'{checked} adhkar spot-checked.')


def vowel_coverage(s):
    letters = [i for i, c in enumerate(s) if 'ء' <= c <= 'ي' and c not in 'اىوي']
    if not letters:
        return 1.0
    marked = sum(1 for i in letters if i + 1 < len(s) and is_mark(s[i + 1]))
    return marked / len(letters)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--log', required=True)
    ap.add_argument('--fixture', required=True, help='test fixture with the reference verses')
    args = ap.parse_args()
    src = load_sources(args.src)
    log = []

    cats = []
    for set_id, orders in (('morning', MORNING), ('evening', EVENING)):
        items = [seen_item(src, o, set_id, i + 1) for i, o in enumerate(orders)]
        cats.append({'id': set_id, 'items': items})
    for set_id, specs in (('afterPrayer', AFTER_PRAYER), ('sleep', SLEEP), ('waking', WAKING)):
        items = [ipro_item(src, s, set_id, i + 1) for i, s in enumerate(specs)]
        cats.append({'id': set_id, 'items': items})

    for c in cats:
        for it in c['items']:
            it['segments'] = finalize_segments(src, it['segments'])
            for field in ('note', 'virtue', 'reference'):
                if field in it:
                    it[field]['ar'] = light_arabic(it[field]['ar'])
            for s in it['segments']:
                if 'text' in s:
                    cov = vowel_coverage(s['text'])
                    if cov < 0.8:
                        log.append(f'LOW VOWEL COVERAGE {it["id"]}: {cov:.2f} {s["text"][:60]}')

    library = {
        'schema': 1,
        'title': {'ar': 'حصن المسلم', 'en': 'Hisn al-Muslim (Fortress of the Muslim)'},
        'author': {'ar': 'سعيد بن علي بن وهف القحطاني', 'en': "Sa'id ibn 'Ali ibn Wahf al-Qahtani"},
        'sources': [
            {'id': 'seen-arabic', 'url': 'https://github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB',
             'commit': '29d7623fede52eca835a789025dfda866e8cfe44', 'license': 'MIT'},
            {'id': 'islamic-pro-azkar', 'url': 'https://github.com/YousefAsalya/Islamic-Pro-azkar-API',
             'commit': 'd793023e3b69c91674023f692425950c8ebbb64d', 'license': 'MIT'},
            {'id': 'quran-api', 'url': 'https://github.com/fawazahmed0/quran-api',
             'commit': '47ca096b0976443ba2eab2e45cdf0fb4096a2610', 'license': 'Unlicense'},
        ],
        'categories': cats,
    }
    keys, bad = check_quran_reference(src, log)
    verification(src, library, log)

    with open(args.out, 'w', encoding='utf-8') as f:
        json.dump(library, f, ensure_ascii=False, indent=1)
        f.write('\n')
    fixture = {
        'source': 'https://github.com/fawazahmed0/quran-api @47ca096b0976443ba2eab2e45cdf0fb4096a2610 (Unlicense) editions ara-quranspelled '
                  '(reference) and ara-quransimple (cross-check)',
        'spelled': {f'{s}:{a}': unicodedata.normalize('NFC', src['spelled'][(s, a)]) for (s, a) in sorted(keys)},
        'simple': {f'{s}:{a}': unicodedata.normalize('NFC', src['simple'][(s, a)]) for (s, a) in sorted(keys)},
    }
    with open(args.fixture, 'w', encoding='utf-8') as f:
        json.dump(fixture, f, ensure_ascii=False, indent=1)
        f.write('\n')
    with open(args.log, 'w', encoding='utf-8') as f:
        f.write('\n'.join(log) + '\n')
    total = sum(len(c['items']) for c in cats)
    print(f'{total} adhkar in {len(cats)} sets; Quran mismatches: {bad}')


if __name__ == '__main__':
    main()
