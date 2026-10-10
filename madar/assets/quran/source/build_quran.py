#!/usr/bin/env python3
"""Builds Madar's bundled, offline Quran data from pinned, openly licensed sources.

Runtime files written to assets/quran/ (the only files the app bundles – this
source/ folder is not an asset folder):

  quran-uthmani.txt   Tanzil Quran Text (Uthmani, version 1.1), VERBATIM, in
                      Tanzil's own "text with aya numbers" format
                      (`sura|aya|text`, the basmala leading aya 1 of each sura
                      but 1 and 9) with Tanzil's copyright block at the end,
                      exactly as Tanzil distributes it. Options: pause marks,
                      sajdah signs, rub-el-hizb signs, tatweel below
                      superscript alefs.
  quran-meta.json     Structure (Tanzil Quran Metadata 1.0, CC BY 3.0): suras
                      (ayah count, Makki/Madani, revelation order), the 604
                      Madani pages, 30 juz, 240 hizb quarters, 15 sajdat;
                      Arabic / English sura names.
  quran-tajweed.txt   Tajweed annotations (cpfair/quran-tajweed, CC BY 4.0),
                      re-indexed onto the exact lines of quran-uthmani.txt:
                      `sura|aya|<code><start>.<end> ...` – Unicode code-point
                      offsets into the line's text (basmala prefix included).

Usage (from the repository root):
  python3 assets/quran/source/build_quran.py [--cache DIR] [--out assets/quran]

Every source is downloaded from raw.githubusercontent.com at a pinned commit
and checked against its SHA-256 before use; the build is deterministic. The
verification report is written to assets/quran/source/verification_log.txt.
"""

import argparse
import collections
import difflib
import hashlib
import html
import json
import os
import re
import sys
import tempfile
import unicodedata
import urllib.request

RAW = 'https://raw.githubusercontent.com'

SOURCES = {
    # Tanzil 1.1 with pause, sajdah and rub-el-hizb signs and tatweel below
    # superscript alefs (the variant we ship; the mirror dropped Tanzil's
    # copyright block, which is restored from the second copy below).
    'tanzil_full': dict(
        url=f'{RAW}/TarteelAI/quran-assets/a5284b17034d36567e4a4bac982a17ba56837448/text/quran-uthmani.txt',
        sha256='9cf746b2c7501b4497d5db95589b99feab1e641a04bf1856c55a74cba39ecbf3',
    ),
    # An independent copy of Tanzil 1.1 (no optional signs) with the official
    # copyright block: proves the shipped text is Tanzil's, letter for letter.
    'tanzil_plain': dict(
        url=f'{RAW}/luobeibei0710/quran_offline_demo/54df631cc19cf0a4e454fdcc3840e3bb41773a74/'
        'resources/broadcast_quran/tanzil_1_1/quran-uthmani.txt',
        sha256='bf4f57b968d03f4131c070b1e285da9be0e0a108a21c910e872801ca273312c8',
    ),
    # Tanzil Quran Metadata 1.0 (quran-data.js).
    'tanzil_meta': dict(
        url=f'{RAW}/TarteelAI/quran-assets/a5284b17034d36567e4a4bac982a17ba56837448/metadata/quran-data.js',
        sha256='4e6ef95731235bc5fbc5ab24090f0cf4c0c7910c380de337fc3678108d1c2af1',
    ),
    # Tanzil Uthmani 1.0.2: the text the tajweed annotations were computed on.
    'tanzil_102': dict(
        url=f'{RAW}/JQuranTree/jqurantree/09ef93e475685035575909c1e482970a89e17199/'
        'src/main/resources/tanzil/quran-uthmani.xml',
        sha256='caeeb8784961f66183efaf7ec86448c65e7a1536ca4204158a972a897b8420be',
    ),
    # Tajweed annotations, CC BY 4.0.
    'cpfair_tajweed': dict(
        url=f'{RAW}/cpfair/quran-tajweed/496f71cd191da00fa2a37ded79dbbddb033bb0ad/'
        'output/tajweed.hafs.uthmani-pause-sajdah.json',
        sha256='151d616ad37a4cc21a80f20d5e1104c5b408375107ddd4d71247dea4c05ebf67',
    ),
    # --- verification only (never bundled) ---
    # fawazahmed0/quran-api (The Unlicense): per-verse page/juz/sajda.
    'fawaz_info': dict(
        url=f'{RAW}/fawazahmed0/quran-api/47ca096b0976443ba2eab2e45cdf0fb4096a2610/info.json',
        sha256='99c654caeea7c63bf9634703167ea0f806d90c55f98d23e2e82d3e3d1b74075c',
    ),
    # King Fahd Complex Uthmani Hafs (v13) via fawazahmed0/quran-api: an
    # independent encoding of the text for letter-skeleton spot checks.
    'kfgqpc_hafs': dict(
        url=f'{RAW}/fawazahmed0/quran-api/47ca096b0976443ba2eab2e45cdf0fb4096a2610/editions/ara-quranuthmanihaf.json',
        sha256='1102ef9e0bab89a28c90b513b5281687948dddc905dcef2e1af9206bb151b91f',
    ),
    # Quran.com-derived 604-page index (TarteelAI/quran-assets): page starts.
    'qurancom_pages': dict(
        url=f'{RAW}/TarteelAI/quran-assets/a5284b17034d36567e4a4bac982a17ba56837448/metadata/page-indices-lookup.json',
        sha256='a0a98c20a4baa67782c77d231b5e520dcc8ab1c9d7f071e8449771f00de9734d',
    ),
}

# Sura names. Arabic: Tanzil's names with the hamza spellings of the Madani
# mushaf's sura headers restored (Madar edit, names only – never the text).
ARABIC_NAME_FIXES = {14: 'إبراهيم', 34: 'سبأ', 76: 'الإنسان', 78: 'النبأ', 82: 'الانفطار', 84: 'الانشقاق'}

# English transliterations (Madar-authored, in the common Quran.com-style
# spelling). Meanings come from Tanzil's metadata.
ENGLISH_NAMES = [
    "Al-Fatihah", "Al-Baqarah", "Ali 'Imran", "An-Nisa", "Al-Ma'idah", "Al-An'am", "Al-A'raf", "Al-Anfal",
    "At-Tawbah", "Yunus", "Hud", "Yusuf", "Ar-Ra'd", "Ibrahim", "Al-Hijr", "An-Nahl", "Al-Isra", "Al-Kahf",
    "Maryam", "Taha", "Al-Anbiya", "Al-Hajj", "Al-Mu'minun", "An-Nur", "Al-Furqan", "Ash-Shu'ara", "An-Naml",
    "Al-Qasas", "Al-'Ankabut", "Ar-Rum", "Luqman", "As-Sajdah", "Al-Ahzab", "Saba", "Fatir", "Ya-Sin",
    "As-Saffat", "Sad", "Az-Zumar", "Ghafir", "Fussilat", "Ash-Shura", "Az-Zukhruf", "Ad-Dukhan",
    "Al-Jathiyah", "Al-Ahqaf", "Muhammad", "Al-Fath", "Al-Hujurat", "Qaf", "Adh-Dhariyat", "At-Tur",
    "An-Najm", "Al-Qamar", "Ar-Rahman", "Al-Waqi'ah", "Al-Hadid", "Al-Mujadilah", "Al-Hashr",
    "Al-Mumtahanah", "As-Saff", "Al-Jumu'ah", "Al-Munafiqun", "At-Taghabun", "At-Talaq", "At-Tahrim",
    "Al-Mulk", "Al-Qalam", "Al-Haqqah", "Al-Ma'arij", "Nuh", "Al-Jinn", "Al-Muzzammil", "Al-Muddaththir",
    "Al-Qiyamah", "Al-Insan", "Al-Mursalat", "An-Naba", "An-Nazi'at", "'Abasa", "At-Takwir", "Al-Infitar",
    "Al-Mutaffifin", "Al-Inshiqaq", "Al-Buruj", "At-Tariq", "Al-A'la", "Al-Ghashiyah", "Al-Fajr",
    "Al-Balad", "Ash-Shams", "Al-Layl", "Ad-Duha", "Ash-Sharh", "At-Tin", "Al-'Alaq", "Al-Qadr",
    "Al-Bayyinah", "Az-Zalzalah", "Al-'Adiyat", "Al-Qari'ah", "At-Takathur", "Al-'Asr", "Al-Humazah",
    "Al-Fil", "Quraysh", "Al-Ma'un", "Al-Kawthar", "Al-Kafirun", "An-Nasr", "Al-Masad", "Al-Ikhlas",
    "Al-Falaq", "An-Nas",
]

# cpfair rule → one-letter code in quran-tajweed.txt (decoded by
# lib/features/quran/domain/tajweed.dart).
RULE_CODES = {
    'hamzat_wasl': 'w', 'lam_shamsiyyah': 'l', 'silent': 's',
    'madd_2': 'a', 'madd_246': 'b', 'madd_munfasil': 'c', 'madd_muttasil': 'd', 'madd_6': 'e',
    'qalqalah': 'q', 'ghunnah': 'g', 'ikhfa': 'i', 'ikhfa_shafawi': 'f', 'iqlab': 'p',
    'idghaam_ghunnah': 'n', 'idghaam_no_ghunnah': 'o', 'idghaam_shafawi': 'h',
    'idghaam_mutajanisayn': 'j', 'idghaam_mutaqaribayn': 'k',
}

# Letters an annotation of the rule must touch (a cheap sanity check that
# offsets land where they should).
RULE_LETTERS = {
    'qalqalah': 'قطبجد', 'ghunnah': 'نم', 'lam_shamsiyyah': 'ل', 'hamzat_wasl': 'ٱ',
    'iqlab': 'نۭۢم', 'ikhfa_shafawi': 'م', 'idghaam_shafawi': 'م',
}

# Tanzil's metadata puts the second quarter of hizb 27 at 15:50, but its own
# text (and the Madani mushaf) opens that quarter with ۞ at 15:49 «نَبِّئْ
# عِبَادِىٓ». The text is the authority; the build checks the fix against it.
QUARTER_FIXES = {(15, 50): (15, 49)}

EXPECTED = dict(ayat=6236, suras=114, pages=604, juz=30, quarters=240, sajdat=15)
PAUSE = 'ۖۗۘۙۚۛۜ'
RUB, SAJDAH, TATWEEL, SUPERSCRIPT_ALEF = '۞', '۩', 'ـ', 'ٰ'


class Log:
    def __init__(self):
        self.lines = []
        self.failures = 0

    def __call__(self, msg):
        print(msg)
        self.lines.append(msg)

    def check(self, ok, msg):
        self(('OK   ' if ok else 'FAIL ') + msg)
        if not ok:
            self.failures += 1


def fetch(name, cache):
    spec = SOURCES[name]
    path = os.path.join(cache, name)
    if not os.path.exists(path):
        with urllib.request.urlopen(spec['url'], timeout=120) as r:
            data = r.read()
        with open(path, 'wb') as f:
            f.write(data)
    data = open(path, 'rb').read()
    digest = hashlib.sha256(data).hexdigest()
    if digest != spec['sha256']:
        sys.exit(f'{name}: sha256 {digest} != pinned {spec["sha256"]} ({spec["url"]})')
    return data.decode('utf-8-sig')


def parse_lines(text):
    """`sura|aya|text` lines → {(s, a): text}; returns (dict, trailing comment block)."""
    ayat = collections.OrderedDict()
    comments = []
    for line in text.split('\n'):
        line = line.rstrip('\r')
        if line.startswith('#'):
            comments.append(line)
            continue
        parts = line.split('|')
        if len(parts) == 3:
            ayat[(int(parts[0]), int(parts[1]))] = parts[2]
    return ayat, comments


def strip_options(t):
    """Tanzil 1.1 with all signs → the same text without the optional signs."""
    t = t.replace(RUB + ' ', '')
    t = re.sub(' [' + PAUSE + ']', '', t)
    t = t.replace(' ' + SAJDAH, '')
    t = re.sub(TATWEEL + '(?=' + SUPERSCRIPT_ALEF + ')', '', t)
    return t


def parse_meta(js):
    def block(name):
        m = re.search(r'QuranData\.' + name + r' = \[(.*?)\];', js, re.S)
        return m.group(1)

    sura = re.findall(r"\[(\d+), (\d+), (\d+), (\d+), '([^']*)', \"([^\"]*)\", '([^']*)', '(\w+)'\]", block('Sura'))

    def pairs(name):
        return [(int(a), int(b)) for a, b in re.findall(r'\[(\d+), (\d+)\]', block(name))]

    sajda = [(int(a), int(b), t) for a, b, t in re.findall(r"\[(\d+), (\d+), '(\w+)'\]", block('Sajda'))]
    return dict(sura=sura, juz=pairs('Juz'), quarters=pairs('HizbQaurter'), pages=pairs('Page'), sajda=sajda)


BISMILLAH_WORDS = 4


def split_basmala(surah, ayah, line):
    """Length of the basmala prefix Tanzil puts before aya 1 (0 when none)."""
    if ayah != 1 or surah in (1, 9):
        return 0
    words = line.split(' ')
    return len(' '.join(words[:BISMILLAH_WORDS])) + 1


def skeleton(t):
    """Letters only: every mark, sign and letter variant folded away."""
    t = unicodedata.normalize('NFKD', t)
    out = []
    for ch in t:
        cat = unicodedata.category(ch)
        if cat.startswith('M') or ch in PAUSE + RUB + SAJDAH + TATWEEL + '۝ۥۦۧۨ':
            continue
        if cat.startswith('Z') or cat.startswith('C') or ch == ' ':
            continue
        ch = {'ٱ': 'ا', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ى': 'ي', 'ی': 'ي', 'ۦ': '', 'ۥ': '', 'ؤ': 'و',
              'ئ': 'ي', 'ء': '', 'ة': 'ه', 'ك': 'ك', 'ۡ': ''}.get(ch, ch)
        out.append(ch)
    return ''.join(out)


def remap(old, new):
    """Maps code-point offsets of [old] onto [new] (per-ayah alignment)."""
    sm = difflib.SequenceMatcher(None, old, new, autojunk=False)
    start = [None] * (len(old) + 1)
    end = [None] * (len(old) + 1)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == 'equal':
            for k in range(i2 - i1):
                start[i1 + k] = j1 + k
                end[i1 + k + 1] = j1 + k + 1
        elif tag in ('replace', 'delete'):
            # A changed letter maps onto its replacement block as a whole.
            for k in range(i1, i2):
                start[k] = j1
                end[k + 1] = j2
    start[len(old)] = len(new)
    end[0] = 0
    return start, end


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cache', default=os.path.join(tempfile.gettempdir(), 'madar-quran-sources'))
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument('--out', default=os.path.dirname(here))
    ap.add_argument('--log', default=os.path.join(here, 'verification_log.txt'))
    args = ap.parse_args()
    os.makedirs(args.cache, exist_ok=True)
    log = Log()
    log('Madar Quran data build – sources pinned by commit and SHA-256')
    for k, v in SOURCES.items():
        log(f'  {k}: {v["url"]}')
        log(f'      sha256 {v["sha256"]}')

    # ---------------------------------------------------------------- text
    full, _ = parse_lines(fetch('tanzil_full', args.cache))
    plain, plain_comments = parse_lines(fetch('tanzil_plain', args.cache))
    log.check(len(full) == EXPECTED['ayat'], f'Tanzil 1.1 (shipped variant) has {len(full)} ayat')
    log.check(len(plain) == EXPECTED['ayat'], f'Tanzil 1.1 (second copy) has {len(plain)} ayat')
    mism = [k for k in full if strip_options(full[k]) != plain.get(k)]
    log.check(not mism, f'both Tanzil 1.1 copies agree letter for letter once the optional signs are removed '
                        f'({len(mism)} differing ayat)')
    block_start = next(i for i, l in enumerate(plain_comments) if 'PLEASE DO NOT REMOVE' in l)
    copyright_block = plain_comments[block_start:]
    log.check(any('Tanzil Quran Text (Uthmani, Version 1.1)' in l for l in copyright_block),
              'Tanzil copyright block found (Uthmani, Version 1.1)')

    # ------------------------------------------------------------ metadata
    meta = parse_meta(fetch('tanzil_meta', args.cache))
    suras = meta['sura']
    log.check(len(suras) == EXPECTED['suras'], f'{len(suras)} suras in the metadata')
    counts = [int(s[1]) for s in suras]
    log.check(sum(counts) == EXPECTED['ayat'], f'metadata ayah counts sum to {sum(counts)}')
    text_counts = collections.Counter(s for s, _ in full)
    log.check(all(text_counts[i + 1] == c for i, c in enumerate(counts)), 'every sura has its metadata ayah count')
    pages = meta['pages'][:EXPECTED['pages']]
    log.check(len(meta['pages']) == EXPECTED['pages'] + 1 and meta['pages'][-1] == (115, 1),
              f'{len(pages)} pages (+ the closing sentinel)')
    juz = meta['juz'][:EXPECTED['juz']]
    quarters = [QUARTER_FIXES.get(q, q) for q in meta['quarters'][:EXPECTED['quarters']]]
    log.check(len(juz) == 30 and len(quarters) == 240, f'{len(juz)} juz, {len(quarters)} hizb quarters')
    log.check(all(juz[i] == quarters[i * 8] for i in range(30)), 'every juz starts on its first hizb quarter')
    sajda = meta['sajda']
    log.check(len(sajda) == EXPECTED['sajdat'], f'{len(sajda)} sajdat')

    def ordered(seq):
        return all(seq[i] < seq[i + 1] for i in range(len(seq) - 1))

    log.check(ordered(pages) and ordered(juz) and ordered(quarters), 'page / juz / quarter starts ascend')
    for name, seq in (('page', pages), ('juz', juz), ('quarter', quarters)):
        bad = [p for p in seq if p not in full]
        log.check(not bad, f'every {name} start is a real ayah ({len(bad)} bad)')

    # Signs in the text agree with the metadata.
    sajdah_text = sorted(k for k, t in full.items() if SAJDAH in t)
    log.check(sajdah_text == sorted((s, a) for s, a, _ in sajda),
              f'the {len(sajdah_text)} ayat carrying ۩ are exactly the metadata sajdat')
    rub_text = sorted(k for k, t in full.items() if t.startswith(RUB))
    q_not_first = sorted(q for q in quarters if not (q[1] == 1))
    missing = [q for q in quarters if q not in rub_text and q[1] != 1]
    log.check(not missing and set(rub_text) <= set(quarters),
              f'۞ opens {len(rub_text)} ayat: exactly the {len(q_not_first)} hizb-quarter starts inside a sura '
              f'(after fixing {QUARTER_FIXES})')
    log.check(all(full[v].startswith(RUB) for v in QUARTER_FIXES.values()), 'the quarter fix is where the text puts ۞')

    # Second source for the structure (fawazahmed0 / Quran.com page index).
    info = json.loads(fetch('fawaz_info', args.cache))
    fpages = [(p['start']['chapter'], p['start']['verse']) for p in info['pages']['references']]
    log.check(fpages == pages, 'page starts agree with fawazahmed0/quran-api')
    fjuz = [(p['start']['chapter'], p['start']['verse']) for p in info['juzs']['references']]
    log.check(fjuz == juz, 'juz starts agree with fawazahmed0/quran-api')
    fsaj = [(r['chapter'], r['verse'], 'obligatory' if r['obligatory'] else 'recommended')
            for r in info['sajdas']['references']]
    log.check(fsaj == [(s, a, t) for s, a, t in sajda], 'sajdat (and their kind) agree with fawazahmed0/quran-api')
    qc = json.loads(fetch('qurancom_pages', args.cache))
    qpages = [(p['start']['surah'], p['start']['ayah']) for p in qc]
    diff = [i + 1 for i, (a, b) in enumerate(zip(qpages, pages)) if a != b]
    log.check(len(qpages) == 604 and not diff, f'page starts agree with the Quran.com-derived index ({diff[:8]})')

    # Letter skeletons against an independent encoding (KFGQPC Hafs v13).
    kfg = {(v['chapter'], v['verse']): v['text'] for v in json.loads(fetch('kfgqpc_hafs', args.cache))['quran']}
    same = 0
    diffs = []
    for k, t in full.items():
        body = t[split_basmala(k[0], k[1], t):]
        if skeleton(body) == skeleton(kfg[k]):
            same += 1
        else:
            diffs.append(k)
    log.check(same == len(full), f'letter skeletons equal to the independent KFGQPC Hafs text for '
                                 f'{same}/{len(full)} ayat ({diffs[:8]})')
    famous = [(1, a) for a in range(1, 8)] + [(2, 255), (2, 285), (2, 286), (18, 10), (36, 1), (36, 82),
                                              (55, 13), (67, 1), (112, 1), (112, 2), (112, 3), (112, 4),
                                              (113, 1), (114, 1), (114, 6), (3, 190), (24, 35), (59, 22)]
    bad = [k for k in famous if k in diffs]
    log.check(not bad, f'spot check: {len(famous)} well-known ayat match KFGQPC letter for letter ({bad})')

    # ------------------------------------------------------------- tajweed
    xml = fetch('tanzil_102', args.cache)
    old = {}
    for sm in re.finditer(r'<sura index="(\d+)"[^>]*>(.*?)</sura>', xml, re.S):
        s = int(sm.group(1))
        for am in re.finditer(r'<aya index="(\d+)" text="([^"]*)"(?: bismillah="([^"]*)")?', sm.group(2)):
            a = int(am.group(1))
            t = html.unescape(am.group(2))
            if am.group(3):
                bism = html.unescape(am.group(3))
                # Tanzil writes the basmala of suras 95 and 97 with a shadda on
                # the ba (as the 1.1 text still does).
                if s in (95, 97):
                    bism = bism.replace('بِسْمِ', 'بِّسْمِ', 1)
                t = bism + ' ' + t
            old[(s, a)] = t
    log.check(len(old) == EXPECTED['ayat'], f'Tanzil 1.0.2 (annotation base) has {len(old)} ayat')
    ann = {(a['surah'], a['ayah']): a['annotations'] for a in json.loads(fetch('cpfair_tajweed', args.cache))}
    log.check(len(ann) == EXPECTED['ayat'], f'cpfair annotations cover {len(ann)} ayat')

    def sanity(texts):
        bad = collections.Counter()
        oob = 0
        for k, xs in ann.items():
            t = texts[k]
            for x in xs:
                if x['end'] > len(t) or x['start'] >= x['end']:
                    oob += 1
                    continue
                letters = RULE_LETTERS.get(x['rule'])
                if letters and not any(c in letters for c in t[x['start']:x['end']]):
                    bad[x['rule']] += 1
        return oob, bad

    oob, bad = sanity(old)
    total = sum(len(v) for v in ann.values())
    log.check(oob == 0 and not bad, f'all {total} annotations land on their letters in the 1.0.2 text '
                                    f'(out of range {oob}, misplaced {dict(bad)})')

    unknown = {x['rule'] for xs in ann.values() for x in xs} - set(RULE_CODES)
    log.check(not unknown, f'every rule has a code ({unknown})')
    remapped = {}
    ops = collections.Counter()
    for k in full:
        o, n = old[k], full[k]
        start, end = remap(o, n)
        for tag, *_ in difflib.SequenceMatcher(None, o, n, autojunk=False).get_opcodes():
            ops[tag] += 1
        out = []
        for x in ann[k]:
            s, e = start[x['start']], end[x['end']]
            # A tatweel inserted right before the span carries its superscript
            # alef / small yeh / hamza: colour it with the span.
            while s > 0 and n[s - 1] == TATWEEL:
                s -= 1
            out.append(dict(rule=x['rule'], start=s, end=e))
        remapped[k] = out
    log(f'INFO 1.0.2 → 1.1 alignment edits: {dict(ops)}')
    ann_old = ann
    ann = remapped
    oob, bad = sanity(full)
    log.check(oob == 0 and not bad, f'after re-indexing, all {total} annotations land on their letters in the '
                                    f'shipped text (out of range {oob}, misplaced {dict(bad)})')
    # Where an ayah is unchanged the offsets must be untouched.
    unchanged = [k for k in full if full[k] == old[k]]
    moved = [k for k in unchanged if [(x['start'], x['end']) for x in ann[k]] !=
             [(x['start'], x['end']) for x in ann_old[k]]]
    log.check(not moved, f'{len(unchanged)} unchanged ayat keep their offsets exactly ({len(moved)} moved)')
    # Each annotation still covers the same letters (marks, signs and tatweel aside).
    # (1.1 writes the small yeh U+06E6 as tatweel + small high yeh U+06E7.)
    def letters(t):
        return ''.join(c for c in t
                       if not unicodedata.category(c).startswith('M') and c not in TATWEEL + ' \u06E6' + PAUSE)
    changed = 0
    for k in full:
        for a, b in zip(ann_old[k], ann[k]):
            if letters(old[k][a['start']:a['end']]) != letters(full[k][b['start']:b['end']]):
                changed += 1
    log.check(changed == 0, f'{total - changed}/{total} annotations cover the same letters after re-indexing '
                            f'({changed} changed)')

    # ------------------------------------------------------------- outputs
    out = args.out
    with open(os.path.join(out, 'quran-uthmani.txt'), 'w', encoding='utf-8', newline='\n') as f:
        for (s, a), t in full.items():
            f.write(f'{s}|{a}|{t}\n')
        f.write('\n\n')
        f.write('\n'.join(copyright_block) + '\n')

    meta_out = {
        'version': 1,
        'source': 'Tanzil Quran Metadata 1.0 (tanzil.net, CC BY 3.0); names: see assets/licenses/quran_credits.txt',
        # [ayahCount, revelationOrder, 'M'|'D', nameArabic, nameEnglish, meaningEnglish]
        'suras': [
            [int(s[1]), int(s[2]), 'M' if s[7] == 'Meccan' else 'D', ARABIC_NAME_FIXES.get(i + 1, s[4]),
             ENGLISH_NAMES[i], s[6]]
            for i, s in enumerate(suras)
        ],
        'pages': [list(p) for p in pages],
        'juz': [list(p) for p in juz],
        'quarters': [list(p) for p in quarters],
        'sajdat': [[s, a, 'o' if t == 'obligatory' else 'r'] for s, a, t in sajda],
    }
    with open(os.path.join(out, 'quran-meta.json'), 'w', encoding='utf-8', newline='\n') as f:
        json.dump(meta_out, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')

    with open(os.path.join(out, 'quran-tajweed.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('# Tajweed annotations for the Tanzil Uthmani 1.1 text in quran-uthmani.txt.\n')
        f.write('# Source: cpfair/quran-tajweed (https://github.com/cpfair/quran-tajweed, commit 496f71c),\n')
        f.write('# licensed under Creative Commons Attribution 4.0 International.\n')
        f.write('# Changes (Madar): offsets re-indexed from the Tanzil 1.0.2 text onto the exact\n')
        f.write('# lines of quran-uthmani.txt; rules written as one-letter codes.\n')
        f.write('# Format: sura|aya|<code><start>.<end> … (code-point offsets into the line text,\n')
        f.write('# basmala prefix included). Codes: ' +
                ' '.join(f'{c}={r}' for r, c in sorted(RULE_CODES.items(), key=lambda x: x[1])) + '\n')
        for (s, a) in full:
            xs = ' '.join(f'{RULE_CODES[x["rule"]]}{x["start"]}.{x["end"]}' for x in ann[(s, a)])
            f.write(f'{s}|{a}|{xs}\n')

    for name in ('quran-uthmani.txt', 'quran-meta.json', 'quran-tajweed.txt'):
        p = os.path.join(out, name)
        log(f'WROTE {name}: {os.path.getsize(p)} bytes, sha256 '
            f'{hashlib.sha256(open(p, "rb").read()).hexdigest()}')
    log(f'RESULT {"PASS" if log.failures == 0 else "FAIL"} ({log.failures} failed checks)')
    with open(args.log, 'w', encoding='utf-8') as f:
        f.write('\n'.join(log.lines) + '\n')
    sys.exit(1 if log.failures else 0)


if __name__ == '__main__':
    main()
