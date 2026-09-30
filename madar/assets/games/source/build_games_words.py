#!/usr/bin/env python3
"""Builds the Madar Cinema word / quiz game content (assets/games/).

Runtime files written to assets/games/ (the only files the app bundles – this
source/ folder is not an asset folder):

  arabic_lexicon.txt        Arabic game lexicon, 3–8 letters, most frequent
                            first (rank = entry order); vowelled display form
                            where Madar authored one.
  arabic_word_filter.json   blocked (profanity / sexual / slurs) and
                            sensitive words; clitic rules for matching.
  word_guess_answers.json   curated 4/5/6-letter answers with vowelled forms.
  word_search_themes.json   themed word lists.
  crossword_clues.json      original Arabic clue bank.
  islamic_quiz.json         original Islamic quiz (ar/en) with verified
                            citations.
  countries.json            UN member / observer states: names, capitals,
                            continent and code-drawable flag specs.
  typing_passages.json      typing-race passages (original, proverbs, and
                            Quran references resolved from assets/quran/).

Usage (from the repository root):
  python3 assets/games/source/build_games_words.py [--cache DIR]

Upstream data is downloaded from raw.githubusercontent.com at pinned commits
and checked against its SHA-256; the build is deterministic. Checks are
written to assets/games/source/verification_log.txt and the build fails if
any check fails.
"""

import argparse
import collections
import hashlib
import json
import os
import random
import re
import sys
import tempfile
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from arabic_norm import LETTERS, fold, is_game_word, lookup_key, plain, skeleton  # noqa: E402
import content_words as W  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'games')
RAW = 'https://raw.githubusercontent.com'

SOURCES = {
    # Arabic Wikipedia word frequencies (dump of 2022-08-29), MIT licence.
    'arwiki': dict(
        url=f'{RAW}/IlyaSemenov/wikipedia-word-frequency/325f6696e2e4fc31aee7ebfccad7601e4ac70168/'
        'results/arwiki-2022-08-29.txt',
        sha256='c98ae500aa256bd36943677f395ae2457ea5c19576354139319db9833f74713c',
    ),
    # LDNOOBW Arabic bad-word list, CC BY 4.0.
    'ldnoobw_ar': dict(
        url=f'{RAW}/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/'
        '5faf2ba42d7b1c0977169ec3611df25a3c08eb13/ar',
        sha256='23dbd9c55257bf2a4965f46664dc7eac04b61ff4eb3571e41f7e964c7c3ed96b',
    ),
    # Hadith editions (The Unlicense) – used ONLY to verify the quiz's hadith
    # citations (collection + number + a key phrase); nothing is bundled.
    'bukhari': dict(
        url=f'{RAW}/fawazahmed0/hadith-api/df57907be35291c91ad6a6691180e22ca9920784/editions/ara-bukhari.json',
        sha256='e34a3402889ca378871da3c5984b7875c680920e93f1c8738ac7afe502179562',
    ),
    'muslim': dict(
        url=f'{RAW}/fawazahmed0/hadith-api/df57907be35291c91ad6a6691180e22ca9920784/editions/ara-muslim1.json',
        sha256='4632b3423550dd9552c6cca3e3c4fba7c535e8ff71822e2b92e82a74e5844df3',
    ),
    'tirmidhi': dict(
        url=f'{RAW}/fawazahmed0/hadith-api/df57907be35291c91ad6a6691180e22ca9920784/editions/ara-tirmidhi1.json',
        sha256='b6c8ea82786d40e4c13181fb59721dc6d6faeed9c091d8db96274473689fce20',
    ),
    'abudawud': dict(
        url=f'{RAW}/fawazahmed0/hadith-api/df57907be35291c91ad6a6691180e22ca9920784/editions/ara-abudawud1.json',
        sha256='3c9536051f8809463942b8763aa860d17a70ea72b7a90bd504750c5a803cfc50',
    ),
}

# Lexicon: Wikipedia forms seen at least this often join the lexicon.
MIN_WIKI_COUNT = 100
MIN_LEN, MAX_LEN = 3, 8

LOG = []
FAILED = []


def log(msg):
    LOG.append(msg)
    print(msg)


def check(ok, msg):
    log(('OK   ' if ok else 'FAIL ') + msg)
    if not ok:
        FAILED.append(msg)
    return ok


def fetch(name, cache):
    src = SOURCES[name]
    path = os.path.join(cache, name + '.src')
    if not os.path.exists(path):
        with urllib.request.urlopen(src['url']) as r, open(path, 'wb') as f:
            f.write(r.read())
    data = open(path, 'rb').read()
    digest = hashlib.sha256(data).hexdigest()
    if digest != src['sha256']:
        raise SystemExit(f'{name}: sha256 {digest} != pinned {src["sha256"]}')
    return data


def words_of(block):
    return [w for w in block.split() if w.strip()]


def write(name, text):
    path = os.path.join(OUT, name)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    data = text.encode('utf-8')
    log(f'WROTE {name}: {len(data)} bytes, sha256 {hashlib.sha256(data).hexdigest()}')


def write_json(name, obj):
    write(name, json.dumps(obj, ensure_ascii=False, separators=(',', ':')) + '\n')


# --------------------------------------------------------------------------
# Word filter (mirrors WordFilter in lib/features/cinema/rules/words/lexicon)
# --------------------------------------------------------------------------
PREFIXES = ['', 'و', 'ف', 'ب', 'ل', 'ك', 'ال', 'وال', 'فال', 'بال', 'كال', 'لل', 'ولل', 'فلل', 'وب', 'ول', 'فب']
SUFFIXES = ['', 'ه', 'ها', 'هم', 'هن', 'هما', 'ك', 'كم', 'كن', 'ي', 'نا', 'ات', 'ان', 'ين', 'ون', 'تي', 'ته',
            'تها', 'تك', 'تان', 'تين']


def filter_key(word):
    """Filter matching key: plain letters, alef family → ا, ى → ي. Unlike
    `fold`, ة stays distinct from ه so that the feminine ending is never
    mistaken for the clitic ـه (جماعة is not جماع + ـه)."""
    return plain(word).replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا').replace('ى', 'ي')


class WordFilter:
    def __init__(self, blocked, sensitive, allowed):
        self.blocked = {filter_key(w) for w in blocked}
        self.sensitive = {filter_key(w) for w in sensitive}
        self.allowed = {filter_key(w) for w in allowed}

    def _hits(self, word, bag):
        w = filter_key(word)
        if w in self.allowed:
            return False
        if w in bag:
            return True
        for p in PREFIXES:
            if not w.startswith(p):
                continue
            for s in SUFFIXES:
                if (p == '' and s == '') or not w.endswith(s):
                    continue
                core = w[len(p):len(w) - len(s)]
                if len(core) >= 3 and core in bag:
                    return True
        return False

    def is_blocked(self, word):
        return self._hits(word, self.blocked)

    def is_sensitive(self, word):
        return self._hits(word, self.sensitive)

    def is_unsuitable(self, word):
        return self.is_blocked(word) or self.is_sensitive(word)


def build_filter(cache):
    ld = [plain(w.strip()) for w in fetch('ldnoobw_ar', cache).decode('utf-8').splitlines() if w.strip()]
    allow = {fold(w) for w in words_of(W.LDNOOBW_ALLOW)}
    ld_kept = [w for w in ld if fold(w) not in allow]
    extra = [plain(w) for w in words_of(W.EXTRA_BLOCKED)]
    sensitive = [plain(w) for w in words_of(W.SENSITIVE)]
    blocked = sorted(set(ld_kept) | set(extra), key=lambda w: (fold(w), w))
    sensitive = sorted(set(sensitive) - set(blocked), key=lambda w: (fold(w), w))
    allowed = sorted({plain(w) for w in words_of(W.FILTER_ALLOW_WORDS)})
    check(all(is_game_word(w) for w in blocked + sensitive + allowed), 'filter words are plain Arabic letters')
    log(f'INFO filter: {len(ld)} LDNOOBW words ({len(ld) - len(ld_kept)} allowed as common words: '
        f'{sorted(set(ld) - set(ld_kept))}), {len(extra)} Madar additions, {len(sensitive)} sensitive')
    obj = {
        'version': 1,
        'about': 'Blocked words are never shown in games nor accepted as guesses; sensitive words are valid '
                 'guesses but never answers and never appear by accident in generated grids. Matching folds '
                 'the alef family and ى (ة stays distinct), strips the listed clitics around a core of at '
                 'at least 3 letters; words in "allowed" are innocent look-alikes and never match.',
        'sources': ['LDNOOBW List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words (ar), CC BY 4.0',
                    'Madar additions (self-authored)'],
        'prefixes': [p for p in PREFIXES if p],
        'suffixes': [s for s in SUFFIXES if s],
        'blocked': blocked,
        'sensitive': sensitive,
        'allowed': allowed,
    }
    return WordFilter(blocked, sensitive, allowed), obj


# --------------------------------------------------------------------------
# Lexicon, Word Guess answers, Word Search themes
# --------------------------------------------------------------------------
def load_wiki(cache):
    counts = {}
    for line in fetch('arwiki', cache).decode('utf-8').splitlines():
        word, c = line.rsplit(' ', 1)
        if is_game_word(word):
            counts[word] = int(c)
    return counts


def curated_words():
    """(plain, vowelled) for every self-authored word, first spelling wins."""
    out = collections.OrderedDict()
    for group in W.ANSWER_WORDS.values():
        for v in words_of(group):
            out.setdefault(plain(v), v)
    for _, _, _, block in W.THEMES:
        for v in words_of(block):
            out.setdefault(plain(v), v)
    return out


def build_words(cache, wf, extra_curated):
    wiki = load_wiki(cache)
    curated = curated_words()
    for p, v in extra_curated.items():
        curated.setdefault(p, v)
    check(all(is_game_word(p) for p in curated), 'every curated word is plain Arabic letters')
    bad = [p for p in curated if wf.is_blocked(p)]
    check(not bad, f'no curated word is blocked ({bad})')

    # ---- lexicon
    entries = {}
    for w, c in wiki.items():
        if MIN_LEN <= len(w) <= MAX_LEN and c >= MIN_WIKI_COUNT and not wf.is_blocked(w):
            entries[w] = c
    for p in curated:
        if MIN_LEN <= len(p) <= MAX_LEN:
            entries[p] = wiki.get(p, 0)
    ordered = sorted(entries, key=lambda w: (-entries[w], w))
    missing = [p for p in curated if MIN_LEN <= len(p) <= MAX_LEN and p not in wiki]
    log(f'INFO {len(missing)} curated words not in the Wikipedia list (ranked last): {missing[:80]}')
    lines = [
        '# Madar Cinema – Arabic game lexicon. One entry per line, most frequent first:',
        '# rank = position among the entries (1 = most frequent). Format: word[<TAB>vowelled form].',
        '# Words: plain letters (no tashkeel/tatweel), 3–8 letters, hamza forms / ة / ى as written.',
        f'# Frequencies: Arabic Wikipedia word counts (IlyaSemenov/wikipedia-word-frequency,',
        '# arwiki-2022-08-29, MIT licence), forms seen >= %d times; plus Madar\'s own curated' % MIN_WIKI_COUNT,
        '# words with vowelled forms (self-authored). Blocked words (arabic_word_filter.json) removed.',
        '# Credits: assets/licenses/games_words_credits.txt',
    ]
    for w in ordered:
        v = curated.get(w)
        lines.append(f'{w}\t{v}' if v and v != w else w)
    by_len = collections.Counter(len(w) for w in ordered)
    log(f'INFO lexicon: {len(ordered)} entries by length {sorted(by_len.items())}; '
        f'{sum(1 for w in ordered if w in curated)} with a curated vowelled form')
    check(len(ordered) == len(set(ordered)), 'lexicon has no duplicate entries')

    # ---- Word Guess answers
    answers = {4: [], 5: [], 6: []}
    seen = set()
    for group in W.ANSWER_WORDS.values():
        for v in words_of(group):
            p = plain(v)
            key = fold(p)
            if len(p) in answers and key not in seen and not wf.is_unsuitable(p):
                seen.add(key)
                answers[len(p)].append([p, v])
    for n, lst in answers.items():
        log(f'INFO word guess answers, {n} letters: {len(lst)}')
    check(len(answers[5]) >= 366, 'at least a year of distinct 5-letter daily answers')
    check(len(answers[4]) >= 150 and len(answers[6]) >= 150, 'at least 150 answers for 4 and 6 letters')
    lex_keys = {lookup_key(w) for w in ordered}
    check(all(lookup_key(p) in lex_keys for n in answers for p, _ in answers[n]),
          'every answer is in the lexicon (valid guess)')

    # ---- Word Search themes
    themes = []
    for tid, ar, en, block in W.THEMES:
        words, keys = [], set()
        for v in words_of(block):
            p = plain(v)
            if not (3 <= len(p) <= 8) or fold(p) in keys:
                continue
            keys.add(fold(p))
            words.append([p, v])
        check(len(words) >= 8, f'theme {tid} has >= 8 words ({len(words)})')
        check(not any(wf.is_unsuitable(p) for p, _ in words), f'theme {tid} has no filtered word')
        themes.append({'id': tid, 'title': {'ar': ar, 'en': en}, 'words': words})
    log(f'INFO themes: {len(themes)}, words: {sum(len(t["words"]) for t in themes)}')
    return lines, answers, themes, wiki


# --------------------------------------------------------------------------
# Islamic quiz
# --------------------------------------------------------------------------
QURAN_TEXT = os.path.join(ROOT, 'assets', 'quran', 'quran-uthmani.txt')
QURAN_META = os.path.join(ROOT, 'assets', 'quran', 'quran-meta.json')
AR_DIGITS = str.maketrans('0123456789', '٠١٢٣٤٥٦٧٨٩')
BOOKS = {
    'bukhari': ('صحيح البخاري', 'Sahih al-Bukhari'),
    'muslim': ('صحيح مسلم', 'Sahih Muslim'),
    'tirmidhi': ('جامع الترمذي', "Jami' at-Tirmidhi"),
    'abudawud': ('سنن أبي داود', 'Sunan Abi Dawud'),
}
CATEGORIES = ['quran', 'prophets', 'seerah', 'pillars', 'companions', 'manners']


def load_quran():
    ayat = {}
    for line in open(QURAN_TEXT, encoding='utf-8'):
        if line.startswith('#') or line.count('|') < 2:
            continue
        s, a, t = line.rstrip('\n').split('|', 2)
        ayat[(int(s), int(a))] = t
    meta = json.load(open(QURAN_META, encoding='utf-8'))
    return ayat, meta


class HadithIndex:
    def __init__(self, cache):
        self.cache = cache
        self.books = {}

    def entries(self, book, n):
        if book not in self.books:
            data = json.loads(fetch(book, self.cache).decode('utf-8'))['hadiths']
            idx = collections.defaultdict(list)
            for h in data:
                num = h.get('arabicnumber') or h['hadithnumber']
                try:
                    num = int(float(num))
                except (TypeError, ValueError):
                    continue
                idx[num].append(h)
            self.books[book] = idx
        return self.books[book].get(n, [])


def check_meta(src, ayat, meta, skel):
    suras = meta['suras']
    k = src['k']
    if k == 'sura_count':
        return len(suras) == src['v']
    if k == 'sura_at':
        return suras[src['n'] - 1][3] == src['name']
    if k == 'longest_sura':
        return max(range(114), key=lambda i: suras[i][0]) + 1 == src['n']
    if k == 'no_basmala':
        starts = {s for s in range(1, 115) if skel[(s, 1)].startswith('بسماللهالرحمنالرحيم')}
        return src['n'] not in starts and len(starts) == 113
    if k == 'ayah_count':
        return suras[src['n'] - 1][0] == src['v']
    if k == 'juz_count':
        return len(meta['juz']) == src['v']
    if k == 'juz_start':
        return meta['juz'][src['n'] - 1] == [src['sura'], src['ayah']]
    if k == 'page_count':
        return len(meta['pages']) == src['v']
    if k == 'place':
        return suras[src['n'] - 1][2] == src['v']
    if k == 'revealed_first':
        return suras[src['n'] - 1][1] == 1
    if k == 'ayat_containing':
        key = skeleton(src['key'])
        return sum(1 for t in skel.values() if key in t) == src['v']
    if k == 'most_named':
        counts = {nm: sum(1 for t in skel.values() if nm in t) for nm in src['names']}
        log(f'INFO ayat naming {counts}')
        return max(counts, key=counts.get) == src['v']
    if k == 'longest_ayah':
        return max(skel, key=lambda r: len(skel[r])) == (src['s'], src['a'])
    raise ValueError(k)


def cite(src, meta):
    t = src['t']
    if t == 'quran':
        name_ar, name_en = meta['suras'][src['s'] - 1][3], meta['suras'][src['s'] - 1][4]
        return {'ar': f'سورة {name_ar}، الآية {str(src["a"]).translate(AR_DIGITS)}',
                'en': f'Quran {src["s"]}:{src["a"]} ({name_en})'}
    if t == 'hadith':
        ar, en = BOOKS[src['b']]
        return {'ar': f'{ar}، {str(src["n"]).translate(AR_DIGITS)}', 'en': f'{en} {src["n"]}'}
    return {'ar': 'بنية المصحف الشريف (بيانات تنزيل المرفقة بالتطبيق)',
            'en': 'Structure of the mushaf (Tanzil metadata bundled with the app)'}


def build_quiz(cache):
    import content_quiz as Qz
    ayat, meta = load_quran()
    skel = {r: skeleton(t) for r, t in ayat.items()}
    hadith = HadithIndex(cache)
    out, ids, seen_q = [], set(), set()
    per_cat = collections.Counter()
    per_lvl = collections.Counter()
    per_src = collections.Counter()
    bad = 0
    for qi, (cat, lvl, q_ar, q_en, o_ar, o_en, srcs) in enumerate(Qz.QUESTIONS):
        where = f'quiz #{qi + 1} ({q_ar[:40]})'
        ok = (cat in CATEGORIES and lvl in (1, 2, 3) and len(o_ar) == 4 and len(o_en) == 4
              and len(set(o_ar)) == 4 and len(set(o_en)) == 4 and srcs and q_ar and q_en)
        if not ok:
            check(False, f'{where}: structure')
            bad += 1
            continue
        if q_ar in seen_q:
            check(False, f'{where}: duplicate question')
            bad += 1
            continue
        seen_q.add(q_ar)
        cites = []
        for src in srcs:
            if src['t'] == 'quran':
                r = (src['s'], src['a'])
                good = r in skel and skeleton(src['k']) in skel[r]
                if not good:
                    check(False, f'{where}: Quran {r} lacks key "{src["k"]}" '
                                 f'(ayah: {skel.get(r, "missing")[:160]})')
            elif src['t'] == 'hadith':
                hs = hadith.entries(src['b'], src['n'])
                good = any(skeleton(src['k']) in skeleton(h['text']) for h in hs)
                if not good:
                    check(False, f'{where}: {src["b"]} {src["n"]} lacks key "{src["k"]}"')
                else:
                    grades = sorted({g['grade'] for h in hs for g in h.get('grades', []) if g.get('grade')})
                    if grades:
                        log(f'INFO {src["b"]} {src["n"]} grades {grades}')
            else:
                good = check_meta(src, ayat, meta, skel)
                if not good:
                    check(False, f'{where}: meta fact {src} does not hold')
            if not good:
                bad += 1
                break
            per_src[src['t']] += 1
            entry = {k: v for k, v in src.items()}
            entry['cite'] = cite(src, meta)
            cites.append(entry)
        else:
            qid = f'{cat[:3]}-{hashlib.sha1(q_ar.encode("utf-8")).hexdigest()[:8]}'
            if qid in ids:
                check(False, f'{where}: id collision {qid}')
                bad += 1
                continue
            ids.add(qid)
            order = list(range(4))
            random.Random(qid).shuffle(order)
            out.append({
                'id': qid, 'cat': cat, 'lvl': lvl,
                'q': {'ar': q_ar, 'en': q_en},
                'o': {'ar': [o_ar[i] for i in order], 'en': [o_en[i] for i in order]},
                'a': order.index(0),
                'src': cites,
            })
            per_cat[cat] += 1
            per_lvl[lvl] += 1
    check(bad == 0, f'every quiz question passed structure and citation checks ({bad} failed)')
    check(len(out) >= 300, f'at least 300 quiz questions ({len(out)})')
    log(f'INFO quiz by category {dict(per_cat)}, by level {dict(sorted(per_lvl.items()))}, '
        f'citations {dict(per_src)}')
    return {
        'version': 1,
        'about': 'Original Islamic quiz written for Madar (Arabic primary, English translation). The answer is '
                 'o.ar[a] / o.en[a]. Every question cites its source; Quran citations name ayat of the bundled '
                 'Tanzil text (assets/quran/) and hadith numbers follow: al-Bukhari – standard (Fath al-Bari) '
                 'numbering; Muslim – Muhammad Fu\'ad \'Abd al-Baqi; at-Tirmidhi and Abu Dawud – standard. '
                 'Each citation carries a key phrase "k" (a letter skeleton) that was verified to occur in the '
                 'cited text.',
        'categories': CATEGORIES,
        'questions': out,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cache', default=os.path.join(tempfile.gettempdir(), 'madar-games-cache'))
    args = ap.parse_args()
    os.makedirs(args.cache, exist_ok=True)

    wf, filter_obj = build_filter(args.cache)
    lex_lines, answers, themes, wiki = build_words(args.cache, wf, {})

    write('arabic_lexicon.txt', '\n'.join(lex_lines) + '\n')
    write_json('arabic_word_filter.json', filter_obj)
    write_json('word_guess_answers.json', {
        'version': 1,
        'about': 'Curated Word Guess answers by letter count: [plain, vowelled]. Self-authored for Madar.',
        'answers': {str(n): lst for n, lst in answers.items()},
    })
    write_json('word_search_themes.json', {'version': 1, 'themes': themes})
    write_json('islamic_quiz.json', build_quiz(args.cache))

    log(f'RESULT {"PASS" if not FAILED else "FAIL"} ({len(FAILED)} failed checks)')
    with open(os.path.join(HERE, 'verification_log.txt'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(LOG) + '\n')
    sys.exit(1 if FAILED else 0)


if __name__ == '__main__':
    main()
