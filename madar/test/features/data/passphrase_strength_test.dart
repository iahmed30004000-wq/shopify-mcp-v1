import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/data/domain/passphrase_strength.dart';

PassphraseLevel level(String p) => PassphraseStrength.evaluate(p).level;

void main() {
  test('empty', () {
    final c = PassphraseStrength.evaluate('');
    expect(c.level, PassphraseLevel.empty);
    expect(c.acceptable, isFalse);
    expect(c.fill, 0);
    expect(c.hint, isNull);
  });

  test('common passwords are very weak whatever the decoration', () {
    for (final p in ['password', 'Password123!', 'qwerty', 'P@ssw0rd', 'letmein', 'madar2026', 'بسم الله', 'الحمدلله']) {
      final c = PassphraseStrength.evaluate(p);
      expect(c.level, PassphraseLevel.veryWeak, reason: p);
      expect(c.acceptable, isFalse, reason: p);
    }
    expect(PassphraseStrength.evaluate('password').hint, PassphraseHint.common);
  });

  test('short passphrases are never acceptable', () {
    final c = PassphraseStrength.evaluate('Zq!8vR#2');
    expect(c.length, 8);
    expect(c.level.index, lessThanOrEqualTo(PassphraseLevel.weak.index));
    expect(c.acceptable, isFalse);
    expect(c.hint, PassphraseHint.tooShort);
  });

  test('digits only and patterns are penalised', () {
    expect(PassphraseStrength.evaluate('1234567890123').hint, PassphraseHint.onlyDigits);
    expect(PassphraseStrength.evaluate('1234567890123').acceptable, isFalse);
    expect(PassphraseStrength.evaluate('٠١٢٣٤٥٦٧٨٩٠١').acceptable, isFalse);
    final repeated = PassphraseStrength.evaluate('aaaaaaaaaaaaaaaa');
    expect(repeated.acceptable, isFalse);
    expect(repeated.hint, PassphraseHint.pattern);
    expect(PassphraseStrength.evaluate('abcdefghijklmnop').acceptable, isFalse);
    expect(PassphraseStrength.evaluate('qwertyuiopasdfgh').acceptable, isFalse);
  });

  test('sentences are strong in Arabic and in English', () {
    for (final p in ['correct horse battery staple', 'مدار حياتي يدور حول الصلاة', 'my camel drinks tea at noon']) {
      final c = PassphraseStrength.evaluate(p);
      expect(c.level.index, greaterThanOrEqualTo(PassphraseLevel.strong.index), reason: p);
      expect(c.acceptable, isTrue, reason: p);
    }
  });

  test('a mixed 12-character password is acceptable', () {
    final c = PassphraseStrength.evaluate('Tr0ub4dor&3x');
    expect(c.acceptable, isTrue);
  });

  test('longer is monotonically not weaker', () {
    var previous = PassphraseLevel.empty;
    const phrase = 'blue lantern over the old harbour';
    for (var n = 1; n <= phrase.length; n++) {
      final l = level(phrase.substring(0, n));
      expect(l.index, greaterThanOrEqualTo(previous.index - 1), reason: phrase.substring(0, n));
      if (l.index > previous.index) previous = l;
    }
    expect(previous.index, greaterThanOrEqualTo(PassphraseLevel.strong.index));
  });

  test('meter fill grows with the level', () {
    final fills = [for (final l in PassphraseLevel.values) PassphraseCheck(level: l, bits: 0, length: 20).fill];
    for (var i = 1; i < fills.length; i++) {
      expect(fills[i], greaterThan(fills[i - 1]));
    }
  });

  test('acceptable needs fair+ and the minimum length', () {
    expect(const PassphraseCheck(level: PassphraseLevel.fair, bits: 45, length: 10).acceptable, isTrue);
    expect(const PassphraseCheck(level: PassphraseLevel.fair, bits: 45, length: 9).acceptable, isFalse);
    expect(const PassphraseCheck(level: PassphraseLevel.weak, bits: 35, length: 20).acceptable, isFalse);
  });
}
