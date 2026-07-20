import 'package:communityshare_app/features/auth/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('login_page.dart validation', () {
    test('TC1 blank email and blank password returns required messages', () {
      expect(validateRequiredEmail(''), 'Enter your email.');
      expect(validateRequiredPassword(''), 'Enter your password.');
    });

    test('TC2 invalid email returns valid email message', () {
      expect(
        validateRequiredEmail('invalid email'),
        'Enter a valid email address.',
      );
    });

    test('TC3 valid email and blank password returns password message', () {
      expect(validateRequiredEmail('recipient@example.com'), isNull);
      expect(validateRequiredPassword(''), 'Enter your password.');
    });

    test('valid login input passes local validation', () {
      expect(validateRequiredEmail('recipient@example.com'), isNull);
      expect(validateRequiredPassword('password123'), isNull);
    });
  });

  group('register_page.dart validation', () {
    test('empty full name returns required message', () {
      expect(validateRequiredFullName(''), 'Enter your full name.');
    });

    test('short password returns minimum length message', () {
      expect(validateRegistrationPassword('123'), 'Use at least 6 characters.');
    });

    test('mismatched confirmation returns password mismatch message', () {
      expect(
        validateConfirmPassword('password456', 'password123'),
        'Passwords do not match.',
      );
    });

    test('valid registration fields pass local validation', () {
      expect(validateRequiredFullName('Ali'), isNull);
      expect(validateRequiredEmail('ali@example.com'), isNull);
      expect(validateRegistrationPassword('password123'), isNull);
      expect(validateConfirmPassword('password123', 'password123'), isNull);
    });
  });
}
