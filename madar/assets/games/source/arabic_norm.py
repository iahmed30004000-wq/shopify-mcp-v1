"""Arabic normalisation shared by the Madar Cinema word-game build scripts.

Mirrors lib/features/cinema/rules/words/core/arabic_text.dart – keep the two
in step (the Dart tests re-check every rule on the generated assets).
"""

import re

# Harakat, tanwin, shadda, sukun, maddah/hamza marks (U+064B–U+065F), the
# superscript alef (U+0670) and the Quranic annotation signs (U+06D6–U+06ED).
MARKS = re.compile('[\u064B-\u065F\u0670\u06D6-\u06ED]')
TATWEEL = '\u0640'
# The 36 letters a game word may contain after `plain()`.
LETTERS = set('ءآأؤإئابةتثجحخدذرزسشصضطظعغفقكلمنهوىي')


# Decomposed hamza / madda sequences composed first (NFC for these pairs).
_COMPOSE = {
    'ا\u0653': 'آ', 'ا\u0654': 'أ', 'ا\u0655': 'إ',
    'و\u0654': 'ؤ', 'ي\u0654': 'ئ', 'ى\u0654': 'ئ',
}


def compose(s: str) -> str:
    for k, v in _COMPOSE.items():
        s = s.replace(k, v)
    return s


def plain(s: str) -> str:
    """Tashkeel, tatweel and Quranic signs removed; alef wasla → alef;
    Persian look-alikes → Arabic letters. Hamza forms, ة and ى are kept."""
    s = MARKS.sub('', compose(s)).replace(TATWEEL, '')
    s = s.replace('\u0671', 'ا').replace('\u06CC', 'ي').replace('\u06A9', 'ك')
    s = s.replace('\u200c', '').replace('\u200d', '')
    return s


def fold(s: str) -> str:
    """Game-letter key: plain + alef family → ا, ى → ي, ة → ه."""
    s = plain(s)
    return (s.replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا')
             .replace('ى', 'ي').replace('ة', 'ه'))


def lookup_key(s: str) -> str:
    """Dictionary key: fold + hamza seats ؤ ئ → ء (accepts مسئول / مسؤول)."""
    return fold(s).replace('ؤ', 'ء').replace('ئ', 'ء')


def skeleton(s: str) -> str:
    """Loose letter skeleton for citation checks against Uthmani text and
    hadith editions with or without hamza: fold, ؤ → و, ئ → ي, ء dropped,
    spaces and punctuation removed."""
    s = fold(s).replace('ؤ', 'و').replace('ئ', 'ي').replace('ء', '')
    return ''.join(ch for ch in s if ch in LETTERS)


def is_game_word(s: str) -> bool:
    return bool(s) and all(ch in LETTERS for ch in s)
