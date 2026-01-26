import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod provider for [SensitiveDataDetector].
///
/// Provides a singleton instance of the sensitive data detector for
/// dependency injection throughout the application.
final sensitiveDataDetectorProvider = Provider<SensitiveDataDetector>((ref) {
  return SensitiveDataDetector();
});

/// Represents a type of sensitive information that can be detected.
enum SensitiveDataType {
  /// Social Security Number (XXX-XX-XXXX or XXXXXXXXX).
  ssn,

  /// Credit card number (13-19 digits with optional spaces/dashes).
  creditCard,

  /// Email address.
  email,

  /// Phone number (US and international formats).
  phoneNumber,

  /// Account number (8+ consecutive digits).
  accountNumber,

  /// Password indicator (text like 'password:', 'pwd:', etc.).
  password,
}

/// Result of sensitive data detection analysis.
///
/// Contains information about detected sensitive data patterns
/// and a confidence score indicating the likelihood of sensitive content.
class SensitiveDataDetectionResult {
  /// Creates a [SensitiveDataDetectionResult] with the given parameters.
  const SensitiveDataDetectionResult({
    required this.hasSensitiveData,
    required this.detectedTypes,
    required this.confidenceScore,
    this.detectionCount = 0,
  });

  /// Whether any sensitive data was detected.
  final bool hasSensitiveData;

  /// The types of sensitive data that were detected.
  final Set<SensitiveDataType> detectedTypes;

  /// Confidence score from 0.0 to 1.0 indicating the likelihood
  /// that the content contains sensitive data.
  ///
  /// Higher scores indicate stronger confidence in detection.
  final double confidenceScore;

  /// Total number of sensitive data patterns detected.
  final int detectionCount;

  /// Creates a result indicating no sensitive data was found.
  factory SensitiveDataDetectionResult.noSensitiveData() {
    return const SensitiveDataDetectionResult(
      hasSensitiveData: false,
      detectedTypes: {},
      confidenceScore: 0.0,
    );
  }

  @override
  String toString() {
    return 'SensitiveDataDetectionResult('
        'hasSensitiveData: $hasSensitiveData, '
        'detectedTypes: $detectedTypes, '
        'confidenceScore: $confidenceScore, '
        'detectionCount: $detectionCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SensitiveDataDetectionResult &&
        other.hasSensitiveData == hasSensitiveData &&
        other.detectedTypes.length == detectedTypes.length &&
        other.detectedTypes.containsAll(detectedTypes) &&
        other.confidenceScore == confidenceScore &&
        other.detectionCount == detectionCount;
  }

  @override
  int get hashCode {
    return hasSensitiveData.hashCode ^
        detectedTypes.hashCode ^
        confidenceScore.hashCode ^
        detectionCount.hashCode;
  }
}

/// Service for detecting sensitive information in text.
///
/// Provides pattern-based detection for common types of sensitive data
/// including Social Security Numbers, credit card numbers, email addresses,
/// phone numbers, account numbers, and password indicators.
///
/// ## Detection Patterns
/// - **SSN**: Matches XXX-XX-XXXX or XXXXXXXXX format
/// - **Credit Cards**: Validates 13-19 digit numbers with Luhn algorithm
/// - **Email**: Standard email format validation
/// - **Phone**: US and international phone number formats
/// - **Account Numbers**: 8+ consecutive digits
/// - **Passwords**: Common password indicators in text
///
/// ## Confidence Scoring
/// The confidence score is calculated based on:
/// - Number of different sensitive data types detected
/// - Total count of sensitive patterns found
/// - Strength of pattern matches
///
/// ## Usage
/// ```dart
/// final detector = ref.read(sensitiveDataDetectorProvider);
/// final text = 'My SSN is 123-45-6789';
/// final result = detector.detectSensitiveData(text);
///
/// if (result.hasSensitiveData) {
///   print('Found sensitive data: ${result.detectedTypes}');
///   print('Confidence: ${result.confidenceScore}');
/// }
/// ```
///
/// ## Important Notes
/// - Pattern detection may produce false positives for non-sensitive data
/// - Use confidence scoring to determine appropriate user warnings
/// - Detection is performed using regex patterns for efficiency
class SensitiveDataDetector {
  /// Creates a [SensitiveDataDetector].
  SensitiveDataDetector();

  // Regular expression patterns for sensitive data detection

  /// Pattern for Social Security Numbers.
  /// Matches XXX-XX-XXXX or XXXXXXXXX format.
  static final _ssnPattern = RegExp(
    r'\b(?:\d{3}-\d{2}-\d{4}|\d{9})\b',
  );

  /// Pattern for credit card numbers.
  /// Matches 13-19 digits with optional spaces or dashes.
  static final _creditCardPattern = RegExp(
    r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4,7}\b',
  );

  /// Pattern for email addresses.
  static final _emailPattern = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
  );

  /// Pattern for US phone numbers.
  /// Matches formats like (123) 456-7890, 123-456-7890, 1234567890.
  static final _phonePattern = RegExp(
    r'\b(?:\+?1[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})\b',
  );

  /// Pattern for international phone numbers.
  /// Matches formats starting with + followed by country code and number.
  static final _internationalPhonePattern = RegExp(
    r'\b\+[1-9]\d{1,14}\b',
  );

  /// Pattern for account numbers.
  /// Matches 8 or more consecutive digits.
  static final _accountNumberPattern = RegExp(
    r'\b\d{8,}\b',
  );

  /// Pattern for password indicators.
  /// Matches common password labels in text.
  static final _passwordPattern = RegExp(
    r'\b(?:password|passwd|pwd|pass|pin)\s*[:=]\s*\S+',
    caseSensitive: false,
  );

  /// Detects sensitive data in the provided [text].
  ///
  /// Returns a [SensitiveDataDetectionResult] containing information about
  /// any sensitive data detected and a confidence score.
  ///
  /// The confidence score is calculated based on:
  /// - Base score of 0.3 per detected type
  /// - Additional 0.1 per extra detection beyond the first
  /// - Capped at 1.0
  SensitiveDataDetectionResult detectSensitiveData(String text) {
    if (text.isEmpty) {
      return SensitiveDataDetectionResult.noSensitiveData();
    }

    final detectedTypes = <SensitiveDataType>{};
    var totalDetections = 0;

    // Check for SSN
    final ssnMatches = _ssnPattern.allMatches(text);
    if (ssnMatches.isNotEmpty && _isValidSsn(text, ssnMatches)) {
      detectedTypes.add(SensitiveDataType.ssn);
      totalDetections += ssnMatches.length;
    }

    // Check for credit card numbers
    final creditCardMatches = _creditCardPattern.allMatches(text);
    if (creditCardMatches.isNotEmpty &&
        _hasValidCreditCard(text, creditCardMatches)) {
      detectedTypes.add(SensitiveDataType.creditCard);
      totalDetections += creditCardMatches.length;
    }

    // Check for email addresses
    if (_emailPattern.hasMatch(text)) {
      detectedTypes.add(SensitiveDataType.email);
      totalDetections += _emailPattern.allMatches(text).length;
    }

    // Check for phone numbers
    final phoneMatches = _phonePattern.allMatches(text).length +
        _internationalPhonePattern.allMatches(text).length;
    if (phoneMatches > 0) {
      detectedTypes.add(SensitiveDataType.phoneNumber);
      totalDetections += phoneMatches;
    }

    // Check for account numbers (exclude matches already identified as SSN/CC)
    final accountMatches = _accountNumberPattern.allMatches(text);
    if (accountMatches.isNotEmpty &&
        !detectedTypes.contains(SensitiveDataType.ssn) &&
        !detectedTypes.contains(SensitiveDataType.creditCard)) {
      detectedTypes.add(SensitiveDataType.accountNumber);
      totalDetections += accountMatches.length;
    }

    // Check for password indicators
    if (_passwordPattern.hasMatch(text)) {
      detectedTypes.add(SensitiveDataType.password);
      totalDetections += _passwordPattern.allMatches(text).length;
    }

    // Calculate confidence score
    final confidenceScore = _calculateConfidenceScore(
      detectedTypes.length,
      totalDetections,
    );

    return SensitiveDataDetectionResult(
      hasSensitiveData: detectedTypes.isNotEmpty,
      detectedTypes: detectedTypes,
      confidenceScore: confidenceScore,
      detectionCount: totalDetections,
    );
  }

  /// Validates SSN matches to reduce false positives.
  ///
  /// Filters out invalid patterns like all zeros or sequential numbers.
  bool _isValidSsn(String text, Iterable<RegExpMatch> matches) {
    for (final match in matches) {
      final ssn = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');

      // Check for invalid SSN patterns
      if (ssn == '000000000' ||
          ssn == '111111111' ||
          ssn == '123456789' ||
          ssn.startsWith('000') ||
          ssn.substring(3, 5) == '00' ||
          ssn.substring(5) == '0000') {
        continue;
      }

      return true;
    }

    return false;
  }

  /// Validates credit card numbers using the Luhn algorithm.
  ///
  /// Returns true if at least one match passes Luhn validation.
  bool _hasValidCreditCard(String text, Iterable<RegExpMatch> matches) {
    for (final match in matches) {
      final cardNumber = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');

      // Check length is valid for credit cards (13-19 digits)
      if (cardNumber.length < 13 || cardNumber.length > 19) {
        continue;
      }

      // Validate using Luhn algorithm
      if (_luhnCheck(cardNumber)) {
        return true;
      }
    }

    return false;
  }

  /// Implements the Luhn algorithm for credit card validation.
  ///
  /// Returns true if the number passes the Luhn checksum test.
  bool _luhnCheck(String cardNumber) {
    var sum = 0;
    var alternate = false;

    for (var i = cardNumber.length - 1; i >= 0; i--) {
      var digit = int.parse(cardNumber[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  /// Calculates a confidence score based on detection results.
  ///
  /// - Base score: 0.3 per detected type
  /// - Additional: 0.1 per extra detection beyond first
  /// - Maximum: 1.0
  double _calculateConfidenceScore(int typeCount, int totalDetections) {
    if (typeCount == 0) {
      return 0.0;
    }

    // Base score: 0.3 per type detected
    var score = typeCount * 0.3;

    // Additional score for multiple detections: 0.1 per extra detection
    if (totalDetections > typeCount) {
      score += (totalDetections - typeCount) * 0.1;
    }

    // Cap at 1.0
    return score > 1.0 ? 1.0 : score;
  }

  /// Checks if the provided [text] contains any sensitive data.
  ///
  /// This is a convenience method that returns true if any sensitive
  /// data patterns are detected in the text.
  bool containsSensitiveData(String text) {
    return detectSensitiveData(text).hasSensitiveData;
  }

  /// Gets a human-readable description of the detected sensitive data types.
  ///
  /// Returns a comma-separated list of detected types, e.g.,
  /// "SSN, credit card number, email address".
  String getSensitiveDataDescription(SensitiveDataDetectionResult result) {
    if (!result.hasSensitiveData) {
      return 'No sensitive data detected';
    }

    final descriptions = <String>[];

    for (final type in result.detectedTypes) {
      switch (type) {
        case SensitiveDataType.ssn:
          descriptions.add('Social Security Number');
        case SensitiveDataType.creditCard:
          descriptions.add('credit card number');
        case SensitiveDataType.email:
          descriptions.add('email address');
        case SensitiveDataType.phoneNumber:
          descriptions.add('phone number');
        case SensitiveDataType.accountNumber:
          descriptions.add('account number');
        case SensitiveDataType.password:
          descriptions.add('password');
      }
    }

    return descriptions.join(', ');
  }
}
