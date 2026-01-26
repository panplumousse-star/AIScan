import 'package:flutter_test/flutter_test.dart';

import 'package:aiscan/core/security/sensitive_data_detector.dart';

void main() {
  late SensitiveDataDetector detector;

  setUp(() {
    detector = SensitiveDataDetector();
  });

  group('SensitiveDataDetector', () {
    group('detectSensitiveData', () {
      test('should return no sensitive data for empty string', () {
        // Arrange
        const text = '';

        // Act
        final result = detector.detectSensitiveData(text);

        // Assert
        expect(result.hasSensitiveData, isFalse);
        expect(result.detectedTypes, isEmpty);
        expect(result.confidenceScore, equals(0.0));
        expect(result.detectionCount, equals(0));
      });

      test('should return no sensitive data for non-sensitive text', () {
        // Arrange
        const text = 'This is just regular text without any sensitive data.';

        // Act
        final result = detector.detectSensitiveData(text);

        // Assert
        expect(result.hasSensitiveData, isFalse);
        expect(result.detectedTypes, isEmpty);
        expect(result.confidenceScore, equals(0.0));
        expect(result.detectionCount, equals(0));
      });

      group('SSN detection', () {
        test('should detect SSN in XXX-XX-XXXX format', () {
          // Arrange
          const text = 'My SSN is 234-56-7890';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.ssn));
          expect(result.detectionCount, greaterThan(0));
        });

        test('should detect SSN in XXXXXXXXX format', () {
          // Arrange
          const text = 'SSN: 234567890';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.ssn));
        });

        test('should not detect invalid SSN with all zeros', () {
          // Arrange
          const text = 'SSN: 000-00-0000';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.detectedTypes, isNot(contains(SensitiveDataType.ssn)));
        });

        test('should not detect invalid SSN starting with 000', () {
          // Arrange
          const text = 'SSN: 000-12-3456';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.detectedTypes, isNot(contains(SensitiveDataType.ssn)));
        });

        test('should not detect invalid SSN with middle 00', () {
          // Arrange
          const text = 'SSN: 123-00-4567';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.detectedTypes, isNot(contains(SensitiveDataType.ssn)));
        });

        test('should not detect invalid SSN with last 0000', () {
          // Arrange
          const text = 'SSN: 123-45-0000';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.detectedTypes, isNot(contains(SensitiveDataType.ssn)));
        });

        test('should not detect sequential SSN 123456789', () {
          // Arrange
          const text = 'SSN: 123456789';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.detectedTypes, isNot(contains(SensitiveDataType.ssn)));
        });

        test('should not detect repeating SSN 111111111', () {
          // Arrange
          const text = 'SSN: 111111111';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.detectedTypes, isNot(contains(SensitiveDataType.ssn)));
        });
      });

      group('credit card detection', () {
        test('should detect valid credit card with Luhn checksum', () {
          // Arrange - valid Visa test card
          const text = 'Card: 4532015112830366';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.creditCard));
        });

        test('should detect credit card with spaces', () {
          // Arrange
          const text = 'Card: 4532 0151 1283 0366';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.creditCard));
        });

        test('should detect credit card with dashes', () {
          // Arrange
          const text = 'Card: 4532-0151-1283-0366';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.creditCard));
        });

        test('should not detect invalid credit card (fails Luhn check)', () {
          // Arrange - fails Luhn algorithm
          const text = 'Card: 1234567890123456';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.detectedTypes, isNot(contains(SensitiveDataType.creditCard)));
        });

        test('should not detect credit card that is too short', () {
          // Arrange - 12 digits (min is 13)
          const text = 'Card: 123456789012';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.detectedTypes, isNot(contains(SensitiveDataType.creditCard)));
        });

        test('should not detect credit card that is too long', () {
          // Arrange - 20 digits (max is 19)
          const text = 'Card: 12345678901234567890';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.detectedTypes, isNot(contains(SensitiveDataType.creditCard)));
        });
      });

      group('email detection', () {
        test('should detect standard email address', () {
          // Arrange
          const text = 'Contact me at user@example.com';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.email));
        });

        test('should detect email with dots and underscores', () {
          // Arrange
          const text = 'Email: john.doe_123@company.co.uk';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.email));
        });

        test('should detect multiple email addresses', () {
          // Arrange
          const text = 'Emails: user1@example.com and user2@example.com';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.email));
          expect(result.detectionCount, equals(2));
        });
      });

      group('phone number detection', () {
        test('should detect US phone number with dashes', () {
          // Arrange
          const text = 'Call me at 123-456-7890';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.phoneNumber));
        });

        test('should detect US phone number with parentheses', () {
          // Arrange
          const text = 'Phone: (123) 456-7890';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.phoneNumber));
        });

        test('should detect US phone number without formatting', () {
          // Arrange
          const text = 'Phone: 1234567890';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.phoneNumber));
        });

        test('should detect international phone number', () {
          // Arrange - International number after word boundary (no space before +)
          const text = 'Call+1234567 for assistance';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.phoneNumber));
        });

        test('should detect phone with country code +1', () {
          // Arrange
          const text = 'Phone: +1-555-123-4567';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.phoneNumber));
        });
      });

      group('account number detection', () {
        test('should detect account number with 8 digits', () {
          // Arrange
          const text = 'Account: 12345678';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.accountNumber));
        });

        test('should detect account number with more than 8 digits', () {
          // Arrange
          const text = 'Account: 123456789012';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.accountNumber));
        });

        test('should not detect account number when SSN is detected', () {
          // Arrange - valid SSN should take precedence over account number
          const text = 'SSN: 234-56-7890';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.detectedTypes, isNot(contains(SensitiveDataType.accountNumber)));
        });

        test('should not detect account number when credit card is detected', () {
          // Arrange
          const text = 'Card: 4532015112830366';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.detectedTypes, isNot(contains(SensitiveDataType.accountNumber)));
        });
      });

      group('password detection', () {
        test('should detect password with colon separator', () {
          // Arrange
          const text = 'password: mySecretPass123';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.password));
        });

        test('should detect password with equals separator', () {
          // Arrange
          const text = 'password=mySecretPass123';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.password));
        });

        test('should detect pwd abbreviation', () {
          // Arrange
          const text = 'pwd: test123';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.password));
        });

        test('should detect passwd', () {
          // Arrange
          const text = 'passwd: test123';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.password));
        });

        test('should detect pin', () {
          // Arrange
          const text = 'pin: 1234';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.password));
        });

        test('should be case insensitive', () {
          // Arrange
          const text = 'PASSWORD: mySecretPass123';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes, contains(SensitiveDataType.password));
        });
      });

      group('multiple detections', () {
        test('should detect multiple types in one text', () {
          // Arrange
          const text = '''
            Name: John Doe
            SSN: 234-56-7890
            Email: john@example.com
            Phone: 555-123-4567
            Password: mySecret123
          ''';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectedTypes.length, greaterThanOrEqualTo(4));
          expect(result.detectedTypes, contains(SensitiveDataType.ssn));
          expect(result.detectedTypes, contains(SensitiveDataType.email));
          expect(result.detectedTypes, contains(SensitiveDataType.phoneNumber));
          expect(result.detectedTypes, contains(SensitiveDataType.password));
        });

        test('should count multiple instances of same type', () {
          // Arrange
          const text = '''
            Email 1: user1@example.com
            Email 2: user2@example.com
            Email 3: user3@example.com
          ''';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.hasSensitiveData, isTrue);
          expect(result.detectionCount, equals(3));
        });
      });

      group('confidence score calculation', () {
        test('should return 0.0 confidence for no detections', () {
          // Arrange
          const text = 'No sensitive data here';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.confidenceScore, equals(0.0));
        });

        test('should calculate confidence based on single type', () {
          // Arrange
          const text = 'Email: user@example.com';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          // 1 type * 0.3 = 0.3
          expect(result.confidenceScore, equals(0.3));
        });

        test('should calculate confidence based on multiple types', () {
          // Arrange
          const text = '''
            Email: user@example.com
            Phone: 555-123-4567
          ''';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          // 2 types * 0.3 = 0.6
          expect(result.confidenceScore, equals(0.6));
        });

        test('should add bonus for multiple detections of same type', () {
          // Arrange
          const text = '''
            Email 1: user1@example.com
            Email 2: user2@example.com
          ''';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          // 1 type * 0.3 = 0.3, plus 1 extra detection * 0.1 = 0.1, total = 0.4
          expect(result.confidenceScore, equals(0.4));
        });

        test('should cap confidence score at 1.0', () {
          // Arrange
          const text = '''
            SSN: 234-56-7890
            Card: 4532015112830366
            Email: user@example.com
            Phone: 555-123-4567
            Password: test123
            Email2: user2@example.com
            Email3: user3@example.com
            Email4: user4@example.com
          ''';

          // Act
          final result = detector.detectSensitiveData(text);

          // Assert
          expect(result.confidenceScore, equals(1.0));
          expect(result.confidenceScore, lessThanOrEqualTo(1.0));
        });
      });
    });

    group('containsSensitiveData', () {
      test('should return true when sensitive data is detected', () {
        // Arrange
        const text = 'My email is user@example.com';

        // Act
        final result = detector.containsSensitiveData(text);

        // Assert
        expect(result, isTrue);
      });

      test('should return false when no sensitive data is detected', () {
        // Arrange
        const text = 'Just regular text';

        // Act
        final result = detector.containsSensitiveData(text);

        // Assert
        expect(result, isFalse);
      });

      test('should return false for empty string', () {
        // Arrange
        const text = '';

        // Act
        final result = detector.containsSensitiveData(text);

        // Assert
        expect(result, isFalse);
      });
    });

    group('getSensitiveDataDescription', () {
      test('should return message for no sensitive data', () {
        // Arrange
        final result = SensitiveDataDetectionResult.noSensitiveData();

        // Act
        final description = detector.getSensitiveDataDescription(result);

        // Assert
        expect(description, equals('No sensitive data detected'));
      });

      test('should describe single type detected', () {
        // Arrange
        const text = 'Email: user@example.com';
        final result = detector.detectSensitiveData(text);

        // Act
        final description = detector.getSensitiveDataDescription(result);

        // Assert
        expect(description, contains('email address'));
      });

      test('should describe multiple types with comma separation', () {
        // Arrange
        const text = '''
          Email: user@example.com
          Phone: 555-123-4567
        ''';
        final result = detector.detectSensitiveData(text);

        // Act
        final description = detector.getSensitiveDataDescription(result);

        // Assert
        expect(description, contains('email address'));
        expect(description, contains('phone number'));
        expect(description, contains(', '));
      });

      test('should include SSN in description', () {
        // Arrange
        const text = 'SSN: 234-56-7890';
        final result = detector.detectSensitiveData(text);

        // Act
        final description = detector.getSensitiveDataDescription(result);

        // Assert
        expect(description, contains('Social Security Number'));
      });

      test('should include credit card in description', () {
        // Arrange
        const text = 'Card: 4532015112830366';
        final result = detector.detectSensitiveData(text);

        // Act
        final description = detector.getSensitiveDataDescription(result);

        // Assert
        expect(description, contains('credit card number'));
      });

      test('should include password in description', () {
        // Arrange
        const text = 'password: secret123';
        final result = detector.detectSensitiveData(text);

        // Act
        final description = detector.getSensitiveDataDescription(result);

        // Assert
        expect(description, contains('password'));
      });

      test('should include account number in description', () {
        // Arrange
        const text = 'Account: 12345678';
        final result = detector.detectSensitiveData(text);

        // Act
        final description = detector.getSensitiveDataDescription(result);

        // Assert
        expect(description, contains('account number'));
      });
    });
  });

  group('SensitiveDataDetectionResult', () {
    test('noSensitiveData factory should create result with no data', () {
      // Act
      final result = SensitiveDataDetectionResult.noSensitiveData();

      // Assert
      expect(result.hasSensitiveData, isFalse);
      expect(result.detectedTypes, isEmpty);
      expect(result.confidenceScore, equals(0.0));
      expect(result.detectionCount, equals(0));
    });

    test('should support equality comparison', () {
      // Arrange
      final result1 = const SensitiveDataDetectionResult(
        hasSensitiveData: true,
        detectedTypes: {SensitiveDataType.email},
        confidenceScore: 0.5,
        detectionCount: 1,
      );
      final result2 = const SensitiveDataDetectionResult(
        hasSensitiveData: true,
        detectedTypes: {SensitiveDataType.email},
        confidenceScore: 0.5,
        detectionCount: 1,
      );

      // Act & Assert
      expect(result1, equals(result2));
    });

    test('should not be equal if hasSensitiveData differs', () {
      // Arrange
      final result1 = const SensitiveDataDetectionResult(
        hasSensitiveData: true,
        detectedTypes: {},
        confidenceScore: 0.0,
      );
      final result2 = const SensitiveDataDetectionResult(
        hasSensitiveData: false,
        detectedTypes: {},
        confidenceScore: 0.0,
      );

      // Act & Assert
      expect(result1, isNot(equals(result2)));
    });

    test('should not be equal if detectedTypes differ', () {
      // Arrange
      final result1 = const SensitiveDataDetectionResult(
        hasSensitiveData: true,
        detectedTypes: {SensitiveDataType.email},
        confidenceScore: 0.5,
      );
      final result2 = const SensitiveDataDetectionResult(
        hasSensitiveData: true,
        detectedTypes: {SensitiveDataType.phoneNumber},
        confidenceScore: 0.5,
      );

      // Act & Assert
      expect(result1, isNot(equals(result2)));
    });

    test('should not be equal if confidenceScore differs', () {
      // Arrange
      final result1 = const SensitiveDataDetectionResult(
        hasSensitiveData: true,
        detectedTypes: {SensitiveDataType.email},
        confidenceScore: 0.5,
      );
      final result2 = const SensitiveDataDetectionResult(
        hasSensitiveData: true,
        detectedTypes: {SensitiveDataType.email},
        confidenceScore: 0.6,
      );

      // Act & Assert
      expect(result1, isNot(equals(result2)));
    });

    test('should not be equal if detectionCount differs', () {
      // Arrange
      final result1 = const SensitiveDataDetectionResult(
        hasSensitiveData: true,
        detectedTypes: {SensitiveDataType.email},
        confidenceScore: 0.5,
        detectionCount: 1,
      );
      final result2 = const SensitiveDataDetectionResult(
        hasSensitiveData: true,
        detectedTypes: {SensitiveDataType.email},
        confidenceScore: 0.5,
        detectionCount: 2,
      );

      // Act & Assert
      expect(result1, isNot(equals(result2)));
    });

    test('should have consistent hashCode', () {
      // Arrange
      final result1 = const SensitiveDataDetectionResult(
        hasSensitiveData: true,
        detectedTypes: {SensitiveDataType.email},
        confidenceScore: 0.5,
        detectionCount: 1,
      );
      final result2 = const SensitiveDataDetectionResult(
        hasSensitiveData: true,
        detectedTypes: {SensitiveDataType.email},
        confidenceScore: 0.5,
        detectionCount: 1,
      );

      // Act & Assert
      expect(result1.hashCode, equals(result2.hashCode));
    });

    test('should format toString correctly', () {
      // Arrange
      final result = const SensitiveDataDetectionResult(
        hasSensitiveData: true,
        detectedTypes: {SensitiveDataType.email},
        confidenceScore: 0.5,
        detectionCount: 1,
      );

      // Act
      final str = result.toString();

      // Assert
      expect(str, contains('SensitiveDataDetectionResult'));
      expect(str, contains('hasSensitiveData: true'));
      expect(str, contains('detectedTypes:'));
      expect(str, contains('confidenceScore: 0.5'));
      expect(str, contains('detectionCount: 1'));
    });
  });

  group('sensitiveDataDetectorProvider', () {
    test('should provide SensitiveDataDetector instance', () {
      // Arrange
      final detector = SensitiveDataDetector();

      // Assert
      expect(detector, isA<SensitiveDataDetector>());
    });
  });
}
