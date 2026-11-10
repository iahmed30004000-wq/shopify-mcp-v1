/// A small, offline passphrase strength estimate for the backup sheet.
///
/// It is deliberately conservative and explainable rather than exact: the
/// raw estimate is `length × log2(alphabet)`, where repeated characters and
/// runs (`aaaa`, `1234`, `qwerty`) count for a quarter of a character, and
/// well-known passwords collapse to almost nothing. Arabic letters count as
/// their own alphabet, so an Arabic sentence is as welcome as an English
/// one. Pure Dart.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

enum PassphraseLevel { empty, veryWeak, weak, fair, strong, veryStrong }

/// Advice shown under the meter (the first one that applies).
enum PassphraseHint {
  /// Shorter than [PassphraseStrength.minLength].
  tooShort,

  /// A well-known password.
  common,

  /// Repeated characters or keyboard / alphabet runs.
  pattern,

  /// Only digits.
  onlyDigits,

  /// Fine, but a few more words would make it much stronger.
  addWords,
}

@immutable
class PassphraseCheck {
  const PassphraseCheck({required this.level, required this.bits, required this.length, this.hint});

  final PassphraseLevel level;

  /// Estimated entropy in bits.
  final double bits;

  /// Characters (Unicode code points).
  final int length;
  final PassphraseHint? hint;

  /// Whether a backup may be created with it.
  bool get acceptable => length >= PassphraseStrength.minLength && level.index >= PassphraseLevel.fair.index;

  /// 0..1 fill of the meter.
  double get fill => switch (level) {
    PassphraseLevel.empty => 0,
    PassphraseLevel.veryWeak => 0.12,
    PassphraseLevel.weak => 0.32,
    PassphraseLevel.fair => 0.56,
    PassphraseLevel.strong => 0.8,
    PassphraseLevel.veryStrong => 1,
  };
}

abstract final class PassphraseStrength {
  /// Minimum length for a backup passphrase.
  static const int minLength = 10;

  /// Entropy thresholds (bits) for weak / fair / strong / very strong.
  static const double weakBits = 28, fairBits = 40, strongBits = 60, veryStrongBits = 80;

  static const _rows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm', '1234567890', 'ضصثقفغعهخحجد', 'شسيبلاتنمكط'];

  /// Lower-cased, well-known passwords (checked after removing trailing
  /// digits and symbols, so `Password123!` is caught too).
  static const Set<String> _common = {
    'password', 'passw0rd', 'p@ssw0rd', 'qwerty', 'qwertyuiop', 'letmein', 'welcome', 'admin', 'administrator',
    'iloveyou', 'monkey', 'dragon', 'football', 'baseball', 'master', 'sunshine', 'princess', 'shadow', 'superman',
    'trustno1', 'whatever', 'freedom', 'abc', 'abcdef', 'abcdefgh', 'asdfgh', 'asdfghjkl', 'zxcvbnm', 'secret',
    'changeme', 'default', 'login', 'hello', 'test', 'guest', 'root', 'madar', 'backup', 'mypassword',
    'مدار', 'كلمةالسر', 'كلمة السر', 'كلمةمرور', 'كلمة مرور', 'بسم الله', 'بسمالله', 'الحمدلله', 'الحمد لله',
    'سبحان الله', 'سبحانالله', 'الله اكبر', 'اللهاكبر', 'الله أكبر', 'لا اله الا الله', 'محمد', 'احمد', 'أحمد',
  };

  static PassphraseCheck evaluate(String input) {
    final runes = input.runes.toList();
    if (runes.isEmpty) return const PassphraseCheck(level: PassphraseLevel.empty, bits: 0, length: 0);
    final lower = input.toLowerCase();

    var lowerLatin = false, upperLatin = false, digits = false, arabic = false, symbols = false, other = false;
    for (final c in runes) {
      if (c >= 0x61 && c <= 0x7A) {
        lowerLatin = true;
      } else if (c >= 0x41 && c <= 0x5A) {
        upperLatin = true;
      } else if ((c >= 0x30 && c <= 0x39) || (c >= 0x660 && c <= 0x669) || (c >= 0x6F0 && c <= 0x6F9)) {
        digits = true;
      } else if (c >= 0x600 && c <= 0x6FF || c >= 0x750 && c <= 0x77F || c >= 0xFB50 && c <= 0xFEFF) {
        arabic = true;
      } else if (c < 0x80) {
        symbols = true;
      } else {
        other = true;
      }
    }
    final pool =
        (lowerLatin ? 26 : 0) +
        (upperLatin ? 26 : 0) +
        (digits ? 10 : 0) +
        (arabic ? 36 : 0) +
        (symbols ? 33 : 0) +
        (other ? 100 : 0);
    final perChar = math.log(math.max(pool, 2)) / math.ln2;

    // Effective length: a character that repeats the previous one or
    // continues a run (keyboard row, alphabet, digits) counts a quarter.
    final chars = lower.runes.toList();
    var effective = 0.0;
    var patterned = 0;
    for (var i = 0; i < chars.length; i++) {
      final repeat = i > 0 && chars[i] == chars[i - 1];
      final run = i > 1 && _continuesRun(chars[i - 2], chars[i - 1], chars[i]);
      if (repeat || run) {
        effective += 0.25;
        patterned++;
      } else {
        effective += 1;
      }
    }
    var bits = effective * perChar;

    final core = lower.replaceAll(RegExp(r'[\d\s!@#$%^&*()_+=\-.,?]+$'), '');
    final isCommon = _common.contains(lower.trim()) || _common.contains(core.trim());
    if (isCommon) bits = math.min(bits, 12);
    final onlyDigits = runes.every((c) => (c >= 0x30 && c <= 0x39) || (c >= 0x660 && c <= 0x669) || (c >= 0x6F0 && c <= 0x6F9));
    if (onlyDigits) bits = math.min(bits, runes.length * 3.32);

    var level = bits < weakBits
        ? PassphraseLevel.veryWeak
        : bits < fairBits
        ? PassphraseLevel.weak
        : bits < strongBits
        ? PassphraseLevel.fair
        : bits < veryStrongBits
        ? PassphraseLevel.strong
        : PassphraseLevel.veryStrong;
    final short = runes.length < minLength;
    if (short && level.index > PassphraseLevel.weak.index) level = PassphraseLevel.weak;

    final PassphraseHint? hint;
    if (isCommon) {
      hint = PassphraseHint.common;
    } else if (short) {
      hint = PassphraseHint.tooShort;
    } else if (onlyDigits) {
      hint = PassphraseHint.onlyDigits;
    } else if (patterned * 3 >= chars.length) {
      hint = PassphraseHint.pattern;
    } else if (level.index < PassphraseLevel.veryStrong.index) {
      hint = PassphraseHint.addWords;
    } else {
      hint = null;
    }
    return PassphraseCheck(level: level, bits: bits, length: runes.length, hint: hint);
  }

  static bool _continuesRun(int a, int b, int c) {
    final d1 = b - a, d2 = c - b;
    if (d1 == d2 && (d1 == 1 || d1 == -1)) return true;
    final s = String.fromCharCodes([a, b, c]);
    final r = String.fromCharCodes([c, b, a]);
    for (final row in _rows) {
      if (row.contains(s) || row.contains(r)) return true;
    }
    return false;
  }
}
