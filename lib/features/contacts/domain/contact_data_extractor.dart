import 'package:flutter/foundation.dart';

/// Extracted contact data from OCR text.
///
/// Contains all the contact information found in the scanned document,
/// including emails, phone numbers, addresses, websites, and a possible name.
@immutable
class ExtractedContactData {
  /// Creates an [ExtractedContactData] with the given values.
  const ExtractedContactData({
    this.emails = const [],
    this.phoneNumbers = const [],
    this.addresses = const [],
    this.websites = const [],
    this.possibleName,
    this.rawText,
  });

  /// Empty instance with no extracted data.
  static const empty = ExtractedContactData();

  /// List of email addresses found in the document.
  final List<String> emails;

  /// List of phone numbers found in the document.
  final List<String> phoneNumbers;

  /// List of addresses found in the document.
  final List<String> addresses;

  /// List of websites/URLs found in the document.
  final List<String> websites;

  /// Possible name extracted from the document.
  ///
  /// This is typically the first non-empty line that looks like a name,
  /// or null if no suitable name was found.
  final String? possibleName;

  /// The raw OCR text used for extraction.
  final String? rawText;

  /// Returns true if any contact data was found.
  bool get hasData =>
      emails.isNotEmpty ||
      phoneNumbers.isNotEmpty ||
      addresses.isNotEmpty ||
      websites.isNotEmpty;

  /// Returns true if no contact data was found.
  bool get isEmpty => !hasData;

  /// Returns the total count of extracted items.
  int get totalItems =>
      emails.length + phoneNumbers.length + addresses.length + websites.length;

  /// Creates a copy with updated values.
  ExtractedContactData copyWith({
    List<String>? emails,
    List<String>? phoneNumbers,
    List<String>? addresses,
    String? possibleName,
    String? rawText,
    bool clearName = false,
  }) {
    return ExtractedContactData(
      emails: emails ?? this.emails,
      phoneNumbers: phoneNumbers ?? this.phoneNumbers,
      addresses: addresses ?? this.addresses,
      possibleName: clearName ? null : (possibleName ?? this.possibleName),
      rawText: rawText ?? this.rawText,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExtractedContactData &&
        listEquals(other.emails, emails) &&
        listEquals(other.phoneNumbers, phoneNumbers) &&
        listEquals(other.addresses, addresses) &&
        other.possibleName == possibleName;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(emails),
        Object.hashAll(phoneNumbers),
        Object.hashAll(addresses),
        possibleName,
      );

  @override
  String toString() {
    return 'ExtractedContactData('
        'emails: $emails, '
        'phoneNumbers: $phoneNumbers, '
        'addresses: $addresses, '
        'possibleName: $possibleName)';
  }
}

/// Service for extracting contact information from OCR text.
///
/// Uses regex patterns to identify and extract:
/// - Email addresses
/// - Phone numbers (French and international formats)
/// - Postal addresses (French format)
/// - Possible contact names
///
/// ## Usage
/// ```dart
/// final extractor = ContactDataExtractor();
/// final data = extractor.extractFromText(ocrText);
///
/// if (data.hasData) {
///   // Show contact creation dialog
/// }
/// ```
class ContactDataExtractor {
  /// Creates a [ContactDataExtractor].
  const ContactDataExtractor();

  // ============================================================================
  // Email Extraction
  // ============================================================================

  /// Regex pattern for email addresses.
  ///
  /// Matches standard email formats like:
  /// - john.doe@example.com
  /// - contact@company.fr
  /// - user+tag@domain.co.uk
  static final _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  // ============================================================================
  // Phone Number Extraction
  // ============================================================================

  /// Regex pattern for French phone numbers.
  ///
  /// Matches formats like:
  /// - 06 12 34 56 78
  /// - 06.12.34.56.78
  /// - 06-12-34-56-78
  /// - +33 6 12 34 56 78
  /// - 0033 6 12 34 56 78
  /// - Tel: 03 20 60 00 01
  static final _frenchPhoneRegex = RegExp(
    r'(?:\+33|0033|0)\s*[1-9][\s.\-]*(?:\d[\s.\-]*){8}\d',
  );

  /// Regex pattern for phone numbers with label prefix.
  ///
  /// Matches formats like:
  /// - Tel : 03 20 60 00 01
  /// - Tél: 06 12 34 56 78
  /// - Phone: +33 6 12 34 56 78
  static final _labeledPhoneRegex = RegExp(
    r'(?:t[ée]l(?:[ée]phone)?|phone|mobile|fax)\s*[:.]\s*([\d\s.\-+()]{10,20})',
    caseSensitive: false,
  );

  /// Regex pattern for international phone numbers.
  ///
  /// Matches formats like:
  /// - +1 (555) 123-4567
  /// - +44 20 7123 4567
  /// - +49 30 12345678
  static final _internationalPhoneRegex = RegExp(
    r'\+[1-9]\d{0,2}[\s.\-]?\(?\d{1,4}\)?[\s.\-]?\d{1,4}[\s.\-]?\d{1,9}',
  );

  /// Regex pattern for simple phone numbers (digits only with separators).
  ///
  /// Matches sequences of 10 digits with optional separators.
  static final _simplePhoneRegex = RegExp(
    r'(?<!\d)(\d[\s.\-]*){9}\d(?!\d)',
  );

  // ============================================================================
  // Address Extraction
  // ============================================================================

  /// Regex pattern for French postal addresses.
  ///
  /// Matches formats like:
  /// - 123 Rue de la Paix, 75001 Paris
  /// - 45 Avenue des Champs-Elysees 75008 Paris
  /// - 12 Boulevard Saint-Michel, 75006 Paris, France
  static final _frenchAddressRegex = RegExp(
    r"\d{1,5}[\s,]*(?:rue|avenue|av\.|boulevard|bd\.|place|pl\.|allee|impasse|chemin|ch\.|cours|passage|square|voie|quai)[\s\w\-']+,?\s*\d{5}\s*[\w\-\s]+",
    caseSensitive: false,
  );

  /// Regex pattern for postal codes with city.
  ///
  /// Matches: 75001 Paris, 69000 Lyon, etc.
  static final _postalCodeCityRegex = RegExp(
    r'\b\d{5}\s+[A-Za-zÀ-ÿ\-\s]{2,30}\b',
  );

  // ============================================================================
  // Name Extraction
  // ============================================================================

  /// Regex pattern for potential names (capitalized words).
  ///
  /// Matches sequences of 2-3 capitalized words that could be names.
  static final _nameRegex = RegExp(
    r'^[A-ZÀ-Ÿ][a-zà-ÿ]+(?:\s+[A-ZÀ-Ÿ][a-zà-ÿ]+){1,2}$',
    multiLine: true,
  );

  /// Words that indicate a line is not a name.
  static const _nonNameIndicators = [
    'rue',
    'avenue',
    'boulevard',
    'place',
    'allée',
    'impasse',
    'email',
    'mail',
    'tel',
    'telephone',
    'fax',
    'mobile',
    'adresse',
    'address',
    'contact',
    'www',
    'http',
    'société',
    'company',
    'entreprise',
    'sarl',
    'sas',
    'sa',
    'eurl',
  ];

  // ============================================================================
  // Main Extraction Method
  // ============================================================================

  /// Extracts contact information from OCR text.
  ///
  /// Analyzes the given [text] and extracts all recognizable contact
  /// information including emails, phone numbers, addresses, and names.
  ///
  /// Returns an [ExtractedContactData] containing all found information.
  /// If no contact data is found, returns [ExtractedContactData.empty].
  ExtractedContactData extractFromText(String text) {
    if (text.trim().isEmpty) {
      return ExtractedContactData.empty;
    }

    final emails = _extractEmails(text);
    final phoneNumbers = _extractPhoneNumbers(text);
    final addresses = _extractAddresses(text);
    final possibleName = _extractPossibleName(text, emails, phoneNumbers);

    return ExtractedContactData(
      emails: emails,
      phoneNumbers: phoneNumbers,
      addresses: addresses,
      possibleName: possibleName,
      rawText: text,
    );
  }

  /// Extracts email addresses from text.
  List<String> _extractEmails(String text) {
    final matches = _emailRegex.allMatches(text);
    final emails = matches.map((m) => m.group(0)!.toLowerCase()).toSet();
    return emails.toList();
  }

  /// Extracts phone numbers from text.
  List<String> _extractPhoneNumbers(String text) {
    final phones = <String>{};

    // Labeled phone numbers (Tel:, Tél:, Phone:, etc.)
    for (final match in _labeledPhoneRegex.allMatches(text)) {
      final phoneNumber = match.group(1);
      if (phoneNumber != null) {
        phones.add(_normalizePhoneNumber(phoneNumber));
      }
    }

    // French phone numbers
    for (final match in _frenchPhoneRegex.allMatches(text)) {
      phones.add(_normalizePhoneNumber(match.group(0)!));
    }

    // International phone numbers
    for (final match in _internationalPhoneRegex.allMatches(text)) {
      phones.add(_normalizePhoneNumber(match.group(0)!));
    }

    // Simple phone numbers (if no other phones found)
    if (phones.isEmpty) {
      for (final match in _simplePhoneRegex.allMatches(text)) {
        phones.add(_normalizePhoneNumber(match.group(0)!));
      }
    }

    return phones.toList();
  }

  /// Normalizes a phone number by formatting it consistently.
  String _normalizePhoneNumber(String phone) {
    // Remove extra whitespace and normalize separators
    var normalized = phone.trim();

    // Keep + prefix for international numbers
    final hasPlus = normalized.startsWith('+');

    // Remove all non-digit characters except +
    final digits = normalized.replaceAll(RegExp(r'[^\d]'), '');

    // Format French numbers
    if (digits.length == 10 && digits.startsWith('0')) {
      // Format as 06 12 34 56 78
      return '${digits.substring(0, 2)} ${digits.substring(2, 4)} ${digits.substring(4, 6)} ${digits.substring(6, 8)} ${digits.substring(8, 10)}';
    }

    // Format international French numbers
    if (digits.length == 11 && digits.startsWith('33')) {
      return '+33 ${digits.substring(2, 3)} ${digits.substring(3, 5)} ${digits.substring(5, 7)} ${digits.substring(7, 9)} ${digits.substring(9, 11)}';
    }

    // Return with + prefix if it had one
    if (hasPlus && !normalized.startsWith('+')) {
      return '+$digits';
    }

    return normalized;
  }

  /// Extracts addresses from text.
  List<String> _extractAddresses(String text) {
    final addresses = <String>{};

    // French addresses
    for (final match in _frenchAddressRegex.allMatches(text)) {
      addresses.add(_normalizeAddress(match.group(0)!));
    }

    // Postal code + city (fallback)
    if (addresses.isEmpty) {
      for (final match in _postalCodeCityRegex.allMatches(text)) {
        addresses.add(match.group(0)!.trim());
      }
    }

    return addresses.toList();
  }

  /// Normalizes an address by cleaning up whitespace.
  String _normalizeAddress(String address) {
    return address
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r',\s*,'), ',')
        .trim();
  }

  /// Extracts a possible name from the text.
  ///
  /// Tries to find a name by:
  /// 1. Looking for lines that match the name pattern
  /// 2. Filtering out lines that contain non-name indicators
  /// 3. Preferring lines at the beginning of the document
  String? _extractPossibleName(
    String text,
    List<String> emails,
    List<String> phones,
  ) {
    final lines =
        text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);

    for (final line in lines) {
      // Skip if line contains email or phone
      if (emails.any((e) => line.toLowerCase().contains(e.toLowerCase()))) {
        continue;
      }
      if (phones.any((p) => line.contains(RegExp(r'\d{2}[\s.\-]?\d{2}')))) {
        continue;
      }

      // Skip if line contains non-name indicators
      final lowerLine = line.toLowerCase();
      if (_nonNameIndicators.any((ind) => lowerLine.contains(ind))) {
        continue;
      }

      // Check if line looks like a name
      if (_nameRegex.hasMatch(line)) {
        return line;
      }

      // Check for all-caps name (common on business cards)
      if (line.length <= 50 &&
          line == line.toUpperCase() &&
          RegExp(r'^[A-ZÀ-Ÿ\s\-]+$').hasMatch(line) &&
          line.contains(' ')) {
        // Convert to title case
        return line
            .split(' ')
            .map((w) => w.isEmpty
                ? w
                : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
            .join(' ');
      }
    }

    return null;
  }
}
