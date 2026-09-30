/// Cleaning of user-written names before they go into the summary.
///
/// The summary never includes free-text notes, phone numbers, document or
/// account numbers. Names and titles are still user text, so any run of six
/// or more digits in them (a phone, IBAN, passport or card number someone
/// typed into a name) is masked as `•••` – dates such as `2026-10-01` are
/// kept – line breaks are flattened and Markdown table / heading characters
/// are neutralised. Pure Dart.
library;

abstract final class SummaryText {
  static const _d = '0-9٠-٩۰-۹';

  /// Six or more digits (any script), possibly split by single spaces,
  /// dots, dashes or slashes – `0791234567`, `079 123 4567`, `+962-79-…`.
  static final RegExp _longNumber = RegExp('[$_d](?:[ .\\-/]?[$_d]){5,}');

  /// IBAN-like account numbers (`JO94 CBJO 0010 0000 …`).
  static final RegExp _iban = RegExp(r'\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){2,}(?: ?[A-Z0-9]{1,4})?\b');

  /// Calendar dates, which are not identifiers.
  static final RegExp _date = RegExp('^(?:[$_d]{4}[-/.][$_d]{1,2}[-/.][$_d]{1,2}|[$_d]{1,2}[-/.][$_d]{1,2}[-/.][$_d]{2,4})\$');
  static final RegExp _space = RegExp(r'\s+');
  static final RegExp _controls = RegExp(
    '[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F⁦-⁩‪-‮‎‏]',
  );

  /// Masked marker for removed numbers.
  static const String mask = '•••';

  /// Maximum length of a cleaned name.
  static const int maxLength = 80;

  /// Maximum length of the user's own "about me" line.
  static const int maxNoteLength = 280;

  /// A single-line, number-free, Markdown-safe version of [raw], at most
  /// [maxLength] characters.
  static String clean(String? raw, {int maxLength = SummaryText.maxLength}) {
    if (raw == null) return '';
    var s = raw.replaceAll(_controls, '').replaceAll(_space, ' ').trim();
    s = s.replaceAll(_iban, mask);
    s = s.replaceAllMapped(_longNumber, (m) => _date.hasMatch(m[0]!) ? m[0]! : mask);
    s = s.replaceAll('|', '/');
    if (s.startsWith('#') || s.startsWith('>')) s = '\\$s';
    if (s.runes.length > maxLength) s = '${String.fromCharCodes(s.runes.take(maxLength - 1))}…';
    return s;
  }
}
