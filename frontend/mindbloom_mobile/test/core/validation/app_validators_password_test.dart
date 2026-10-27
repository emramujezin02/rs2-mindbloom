import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/core/validation/app_validators.dart';

void main() {
  group('new password validation matches backend rules', () {
    final invalid = <String?>[
      null,
      '',
      'Ab1!',
      'lozinka1',
      'Lozinka1',
      'lozinka1!',
      'LOZINKA1!',
      'Lozinka!',
      'Lozinka123',
      '       ',
      'Abcd1!x',
      'Čabcdef1!',
      'ABCDEFč1!',
      'Abcdef١!',
    ];
    for (var index = 0; index < invalid.length; index++) {
      test('rejects invalid password case $index with all requirements', () {
        expect(
          AppValidators.password(invalid[index]),
          AppValidators.passwordRequirementsMessage,
        );
      });
    }
    for (final value in [
      'Lozinka1!',
      'Test1234@',
      'Sigurna#2026',
      'Abcdef1!',
    ]) {
      test('accepts $value', () {
        expect(AppValidators.password(value), isNull);
      });
    }
    // Identity's non-alphanumeric rule is not a restricted punctuation list.
    for (final symbol in [
      '!',
      '@',
      '#',
      r'$',
      '%',
      '^',
      '&',
      '*',
      '(',
      ')',
      '-',
      '_',
      '=',
      '+',
      '[',
      ']',
      '{',
      '}',
      ';',
      ':',
      "'",
      '"',
      r'\',
      '|',
      ',',
      '.',
      '<',
      '>',
      '/',
      '?',
      '`',
      '~',
      '€',
      'č',
      '😀',
      ' ',
      '\t',
      '\n',
    ]) {
      test('accepts special character code units ${symbol.codeUnits}', () {
        expect(AppValidators.password('Abcdef1$symbol'), isNull);
      });
    }
    test('accepts exactly 128 UTF-16 code units', () {
      expect(AppValidators.password('Ab1!${'a' * 124}'), isNull);
      expect(AppValidators.password('Ab1!😀${'a' * 122}'), isNull);
    });
    test('rejects more than 128 UTF-16 code units', () {
      expect(
        AppValidators.password('Ab1!${'a' * 125}'),
        'Lozinka može sadržavati najviše 128 znakova.',
      );
      expect(AppValidators.password('Ab1!😀${'a' * 123}'), isNotNull);
    });
  });
}
