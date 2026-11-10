/// Which way a book turns, decided by the BOOK's own language and never by the
/// app's language: an Arabic book opens from the right even when Madar is
/// showing English, and an English book opens from the left in an Arabic app.
library;

enum BookDirection {
  ltr,
  rtl;

  /// An RTL book has its spine on the right: page one is on the right-hand
  /// side and the page turns right-to-left.
  bool get opensFromRight => this == rtl;
}

/// Primary language subtags written right-to-left (ISO 639-1 and the 639-2/3
/// forms a catalogue or a PDF may carry instead). `iw` is the retired code
/// for Hebrew that old files still use; `ckb`/`prs` are Sorani and Dari.
const Set<String> _rtlLanguages = {
  'ar', 'ara', 'arz', 'apc',
  'he', 'heb', 'iw',
  'fa', 'fas', 'per', 'prs',
  'ur', 'urd',
  'ps', 'pus', 'pbt',
  'sd', 'snd',
  'ug', 'uig',
  'yi', 'yid',
  'dv', 'div',
  'ckb',
};

/// Scripts that run right-to-left. A script subtag is more specific than the
/// language, so `ar-Latn` (Arabic in Latin letters) is LTR while `ku-Arab` or
/// `pa-Arab` (languages that are LTR by default) are RTL.
const Set<String> _rtlScripts = {'arab', 'hebr', 'thaa', 'syrc', 'nkoo', 'adlm', 'rohg', 'mand', 'samr'};

/// The direction of a book written in [language] (a BCP-47 tag such as `ar`,
/// `ar-EG`, `fa-Arab-IR`, or with `_` instead of `-`).
///
/// [directionOverride] wins when it is set: it is the book's own field, so
/// the reader can fix a wrongly tagged file by hand. A missing, empty or
/// unknown language is LTR (the safe default for the scripts that are not on
/// the list).
BookDirection bookDirectionOf(String? language, {BookDirection? directionOverride}) {
  if (directionOverride != null) return directionOverride;
  if (language == null) return BookDirection.ltr;
  final parts = language.trim().toLowerCase().split(RegExp(r'[-_]')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return BookDirection.ltr;
  // A script subtag is exactly four letters and comes right after the
  // language (and optional extlang), before any region.
  for (final p in parts.skip(1)) {
    if (p.length == 4 && RegExp(r'^[a-z]{4}$').hasMatch(p)) {
      return _rtlScripts.contains(p) ? BookDirection.rtl : BookDirection.ltr;
    }
    if (p.length == 1) break; // `x-` private use / `u-` extension: stop looking
  }
  return _rtlLanguages.contains(parts.first) ? BookDirection.rtl : BookDirection.ltr;
}
